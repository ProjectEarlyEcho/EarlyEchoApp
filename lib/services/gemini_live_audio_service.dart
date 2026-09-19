import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import 'esp32_audio_streamer.dart';

/// Maintains a Gemini Live microphone session and sends model audio to an
/// ESP32-S3 WebSocket speaker as 24 kHz, signed 16-bit mono PCM.
final geminiLiveAudioServiceProvider =
    ChangeNotifierProvider.autoDispose<GeminiLiveAudioService>((ref) {
      final service = GeminiLiveAudioService(
        apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
        esp32Endpoint: Uri.parse(
          const String.fromEnvironment(
            'ESP32_AUDIO_WS_URL',
            defaultValue: 'ws://10.2.0.19:81',
          ),
        ),
      );
      ref.onDispose(service.dispose);
      return service;
    });

class GeminiLiveAudioService extends ChangeNotifier {
  GeminiLiveAudioService({
    required String apiKey,
    required Uri esp32Endpoint,
    Esp32AudioStreamer? esp32Audio,
  }) : _apiKey = apiKey,
       _esp32Endpoint = esp32Endpoint {
    _esp32Audio =
        esp32Audio ??
        Esp32AudioStreamer(
          endpoint: esp32Endpoint,
          onError: _handleEsp32Error,
          onDisconnected: _handleEsp32Disconnected,
          onPlaybackDrained: _handleEsp32PlaybackDrained,
        );
  }

  static const _inputSampleRate = 16000;
  static const _model = 'gemini-3.8-live';

  final String _apiKey;
  final Uri _esp32Endpoint;
  final AudioRecorder _recorder = AudioRecorder();
  late final Esp32AudioStreamer _esp32Audio;

  WebSocket? _geminiSocket;
  StreamSubscription<dynamic>? _geminiSubscription;
  StreamSubscription<Uint8List>? _microphoneSubscription;
  bool _disposed = false;
  bool _outputFormatLogged = false;
  bool _microphoneUplinkMuted = false;
  Timer? _microphoneResumeTimer;
  DateTime? _microphoneMutedUntil;

  bool isConnecting = false;
  bool isRunning = false;
  String? statusMessage;

  Future<void> toggle() => isRunning ? stop() : start();

  Future<void> start() async {
    if (isConnecting || isRunning) return;
    if (_apiKey.isEmpty) {
      _setStatus('Missing GEMINI_API_KEY. Start with --dart-define-from-file.');
      return;
    }

    isConnecting = true;
    statusMessage = 'Connecting to ESP32 speaker…';
    notifyListeners();
    try {
      await _esp32Audio.connect().timeout(const Duration(seconds: 8));
      statusMessage = 'Connecting to Gemini Live…';
      notifyListeners();
      await _connectGemini();
      if (!_esp32Audio.isConnected) {
        throw StateError('ESP32 speaker disconnected during startup.');
      }
      await _startMicrophone();
      isRunning = true;
      statusMessage = 'Listening — responses stream to ${_esp32Endpoint.host}.';
    } catch (error) {
      await _stopInternal();
      statusMessage = 'Gemini Live could not start: $error';
    } finally {
      isConnecting = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> stop() async {
    await _stopInternal();
    if (!_disposed) {
      statusMessage = 'Gemini Live stopped.';
      notifyListeners();
    }
  }

  Future<void> _connectGemini() async {
    final endpoint = Uri.parse(
      'wss://generativelanguage.googleapis.com/ws/'
      'google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent',
    ).replace(queryParameters: {'key': _apiKey});
    final socket = await WebSocket.connect(endpoint.toString());
    _geminiSocket = socket;
    final setupComplete = Completer<void>();
    _geminiSubscription = socket.listen(
      (message) => _handleServerMessage(message, setupComplete),
      onDone: () => _handleGeminiClosed(setupComplete),
      onError: (Object error) => _handleGeminiError(error, setupComplete),
      cancelOnError: false,
    );
    socket.add(
      jsonEncode({
        'setup': {
          'model': 'models/$_model',
          'generationConfig': {
            'responseModalities': ['AUDIO'],
          },
          'realtimeInputConfig': {
            'automaticActivityDetection': {
              'disabled': false,
              'startOfSpeechSensitivity': 'START_SENSITIVITY_HIGH',
              'endOfSpeechSensitivity': 'END_SENSITIVITY_HIGH',
              'prefixPaddingMs': 100,
              'silenceDurationMs': 700,
            },
            'turnCoverage': 'TURN_INCLUDES_ONLY_ACTIVITY',
          },
          'inputAudioTranscription': {},
          'systemInstruction': {
            'parts': [
              {
                'text':
                    'Always respond when the user speaks, including to short greetings. Respond conversationally and briefly. Your audio is played on an external ESP32 speaker.',
              },
            ],
          },
        },
      }),
    );
    await setupComplete.future.timeout(const Duration(seconds: 15));
  }

  Future<void> _startMicrophone() async {
    if (!await _recorder.hasPermission()) {
      throw StateError('Microphone permission was not granted.');
    }
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _inputSampleRate,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.mic,
          manageBluetooth: false,
        ),
        iosConfig: IosRecordConfig(
          categoryOptions: [
            IosAudioCategoryOption.defaultToSpeaker,
            IosAudioCategoryOption.allowBluetoothA2DP,
          ],
        ),
      ),
    );
    _microphoneSubscription = stream.listen(_sendMicrophoneChunk);
  }

  void _sendMicrophoneChunk(Uint8List bytes) {
    final socket = _geminiSocket;
    if (socket == null || _microphoneUplinkMuted) return;
    socket.add(
      jsonEncode({
        'realtimeInput': {
          'audio': {
            'data': base64Encode(bytes),
            'mimeType': 'audio/pcm;rate=$_inputSampleRate',
          },
        },
      }),
    );
  }

  void _handleServerMessage(dynamic message, Completer<void> setupComplete) {
    final messageText = switch (message) {
      String text => text,
      List<int> bytes => utf8.decode(bytes),
      _ => null,
    };
    if (messageText == null) return;
    final payload = jsonDecode(messageText) as Map<String, dynamic>;
    if (payload.containsKey('setupComplete') && !setupComplete.isCompleted) {
      setupComplete.complete();
      return;
    }
    final error = payload['error'];
    if (error != null) {
      if (!setupComplete.isCompleted) {
        setupComplete.completeError(StateError(error.toString()));
      } else {
        _setStatus('Gemini Live error: $error');
      }
      return;
    }

    final serverContent = payload['serverContent'] as Map<String, dynamic>?;
    if (serverContent?['interrupted'] == true) {
      unawaited(_esp32Audio.flush());
      _keepMicrophoneMutedFor(const Duration(seconds: 5));
      statusMessage = 'Interrupted — flushing ESP32 audio…';
      notifyListeners();
    }

    final transcription =
        (serverContent?['interimInputTranscription'] ??
                serverContent?['inputTranscription'])
            as Map<String, dynamic>?;
    final transcriptText = (transcription?['text'] as String?)?.trim();
    if (transcriptText != null && transcriptText.isNotEmpty) {
      statusMessage = 'Gemini heard: “$transcriptText”';
      notifyListeners();
    }
    final turnComplete = serverContent?['turnComplete'] == true;
    if (turnComplete || serverContent?['waitingForInput'] == true) {
      statusMessage = _microphoneUplinkMuted
          ? 'Finishing response — microphone paused to prevent echo…'
          : 'Listening — responses stream to ${_esp32Endpoint.host}.';
      notifyListeners();
    }

    final modelTurn = serverContent?['modelTurn'] as Map<String, dynamic>?;
    final modelParts = modelTurn?['parts'] as List<dynamic>?;
    if (modelParts != null) {
      for (final part in modelParts) {
        final inlineData =
            (part as Map<String, dynamic>)['inlineData']
                as Map<String, dynamic>?;
        final encoded = inlineData?['data'] as String?;
        if (encoded == null) continue;
        final mimeType = inlineData?['mimeType'] as String?;
        if (!_isExpectedOutputFormat(mimeType)) {
          _setStatus(
            'Unsupported Gemini audio format: ${mimeType ?? 'not reported'}. '
            'Expected 24 kHz PCM16 mono.',
          );
          continue;
        }
        if (!_outputFormatLogged) {
          debugPrint(
            'Gemini Live output: ${mimeType ?? 'audio/pcm;rate=24000'}; '
            'streaming PCM16 mono little-endian to $_esp32Endpoint',
          );
          _outputFormatLogged = true;
        }
        _sendModelAudioToEsp32(base64Decode(encoded));
      }
    }
    if (turnComplete) _esp32Audio.finishTurn();
  }

  bool _isExpectedOutputFormat(String? mimeType) {
    if (mimeType == null) return true;
    final normalized = mimeType.toLowerCase().replaceAll(' ', '');
    if (!normalized.startsWith('audio/pcm')) return false;
    final rate = RegExp(r'rate=(\d+)').firstMatch(normalized)?.group(1);
    return rate == null || rate == '24000';
  }

  void _sendModelAudioToEsp32(Uint8List bytes) {
    if (bytes.isEmpty) return;
    _keepMicrophoneMutedFor(const Duration(seconds: 5));
    if (statusMessage != 'Gemini is responding through ESP32…') {
      statusMessage = 'Gemini is responding through ESP32…';
      notifyListeners();
    }
    _esp32Audio.enqueue(bytes);
  }

  void _handleEsp32PlaybackDrained() {
    // Demo mode deliberately sacrifices barge-in so the phone cannot feed the
    // external speaker back into Gemini as a new user utterance.
    _keepMicrophoneMutedFor(const Duration(seconds: 5));
  }

  void _keepMicrophoneMutedFor(Duration duration) {
    _microphoneUplinkMuted = true;
    final requestedDeadline = DateTime.now().add(duration);
    final currentDeadline = _microphoneMutedUntil;
    if (currentDeadline == null || requestedDeadline.isAfter(currentDeadline)) {
      _microphoneMutedUntil = requestedDeadline;
    }
    _microphoneResumeTimer?.cancel();
    final remaining = _microphoneMutedUntil!.difference(DateTime.now());
    _microphoneResumeTimer = Timer(remaining, () {
      _microphoneUplinkMuted = false;
      _microphoneMutedUntil = null;
      _microphoneResumeTimer = null;
      if (isRunning && !_disposed) {
        statusMessage =
            'Listening — responses stream to ${_esp32Endpoint.host}.';
        notifyListeners();
      }
    });
  }

  void _handleGeminiClosed(Completer<void> setupComplete) {
    if (!setupComplete.isCompleted) {
      setupComplete.completeError(
        StateError('Gemini closed the connection before setup completed.'),
      );
    }
    if (isRunning) {
      isRunning = false;
      statusMessage = 'Gemini Live connection closed.';
      notifyListeners();
    }
  }

  void _handleGeminiError(Object error, Completer<void> setupComplete) {
    if (!setupComplete.isCompleted) setupComplete.completeError(error);
    statusMessage = 'Gemini Live connection error: $error';
    if (!_disposed) notifyListeners();
  }

  void _handleEsp32Error(Object error) {
    if (isRunning) {
      unawaited(
        _shutdownAfterEsp32Failure('ESP32 audio connection error: $error'),
      );
    } else {
      _setStatus('ESP32 audio connection error: $error');
    }
  }

  void _handleEsp32Disconnected() {
    if (!isRunning) return;
    unawaited(
      _shutdownAfterEsp32Failure(
        'ESP32 speaker disconnected. Start again to reconnect.',
      ),
    );
  }

  Future<void> _shutdownAfterEsp32Failure(String message) async {
    isRunning = false;
    isConnecting = true;
    statusMessage = message;
    if (!_disposed) notifyListeners();
    await _stopInternal();
    isConnecting = false;
    if (!_disposed) notifyListeners();
  }

  void _setStatus(String message) {
    statusMessage = message;
    if (!_disposed) notifyListeners();
  }

  Future<void> _stopInternal() async {
    _microphoneResumeTimer?.cancel();
    _microphoneResumeTimer = null;
    _microphoneMutedUntil = null;
    _microphoneUplinkMuted = false;
    await _microphoneSubscription?.cancel();
    _microphoneSubscription = null;
    if (await _recorder.isRecording()) await _recorder.stop();
    await _geminiSubscription?.cancel();
    _geminiSubscription = null;
    await _geminiSocket?.close();
    _geminiSocket = null;
    await _esp32Audio.close();
    _outputFormatLogged = false;
    isRunning = false;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_stopInternal());
    unawaited(_recorder.dispose());
    super.dispose();
  }
}
