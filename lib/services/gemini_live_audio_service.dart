import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:record/record.dart';

/// Maintains a Gemini Live audio session whose output follows the operating
/// system audio route. Pair the ESP32 A2DP sink as a Bluetooth speaker; no
/// Bluetooth transport is implemented in Flutter.
final geminiLiveAudioServiceProvider =
    ChangeNotifierProvider.autoDispose<GeminiLiveAudioService>((ref) {
      final service = GeminiLiveAudioService(
        apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
      );
      ref.onDispose(service.dispose);
      return service;
    });

class GeminiLiveAudioService extends ChangeNotifier {
  GeminiLiveAudioService({required String apiKey}) : _apiKey = apiKey;

  static const _inputSampleRate = 16000;
  static const _outputSampleRate = 24000;
  static const _bytesPerSample = 2;
  static const _model = 'gemini-3.8-live';

  final String _apiKey;
  final AudioRecorder _recorder = AudioRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();

  WebSocket? _socket;
  StreamSubscription<dynamic>? _socketSubscription;
  StreamSubscription<Uint8List>? _microphoneSubscription;
  Timer? _silenceTimer;
  final Queue<Uint8List> _outputQueue = Queue<Uint8List>();
  bool _isDrainingOutput = false;
  int _playbackGeneration = 0;
  bool _playerReady = false;
  bool _disposed = false;
  DateTime _microphoneMutedUntil = DateTime.fromMillisecondsSinceEpoch(0);

  bool isConnecting = false;
  bool isRunning = false;
  String? statusMessage;

  Future<void> toggle() => isRunning ? stop() : start();

  Future<void> start() async {
    if (isConnecting || isRunning) return;
    if (_apiKey.isEmpty) {
      _setStatus('Missing GEMINI_API_KEY. Start with --dart-define.');
      return;
    }

    isConnecting = true;
    statusMessage = 'Connecting to Gemini Live…';
    notifyListeners();
    try {
      await _openPlayer();
      final endpoint = Uri.parse(
        'wss://generativelanguage.googleapis.com/ws/'
        'google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent',
      ).replace(queryParameters: {'key': _apiKey});
      final socket = await WebSocket.connect(endpoint.toString());
      _socket = socket;
      final setupComplete = Completer<void>();
      _socketSubscription = socket.listen(
        (message) => _handleServerMessage(message, setupComplete),
        onDone: () => _handleSocketClosed(setupComplete),
        onError: (Object error) => _handleSocketError(error, setupComplete),
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
                      'Always respond when the user speaks, including to short greetings. Respond conversationally and briefly. Your audio is played on a paired Bluetooth speaker.',
                },
              ],
            },
          },
        }),
      );
      await setupComplete.future.timeout(const Duration(seconds: 15));
      await _startMicrophone();
      _startSilenceFeed();
      isRunning = true;
      statusMessage = 'Listening — audio plays through the selected speaker.';
    } catch (error) {
      await _stopInternal(closePlayer: true);
      statusMessage = 'Gemini Live could not start: $error';
    } finally {
      isConnecting = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> stop() async {
    await _stopInternal(closePlayer: true);
    if (!_disposed) {
      statusMessage = 'Gemini Live stopped.';
      notifyListeners();
    }
  }

  Future<void> _openPlayer() async {
    if (_playerReady) return;
    await _player.openPlayer();
    await _player.startPlayerFromStream(
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: _outputSampleRate,
      interleaved: true,
      bufferSize: 8192,
    );
    _playerReady = true;
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
    if (_socket == null || DateTime.now().isBefore(_microphoneMutedUntil)) {
      return;
    }
    _socket!.add(
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
    if (error != null && !setupComplete.isCompleted) {
      setupComplete.completeError(StateError(error.toString()));
      return;
    }
    final serverContent = payload['serverContent'] as Map<String, dynamic>?;
    final transcription =
        (serverContent?['interimInputTranscription'] ??
                serverContent?['inputTranscription'])
            as Map<String, dynamic>?;
    final transcriptText = (transcription?['text'] as String?)?.trim();
    if (transcriptText != null && transcriptText.isNotEmpty) {
      statusMessage = 'Gemini heard: “$transcriptText”';
      notifyListeners();
    }
    if (serverContent?['turnComplete'] == true ||
        serverContent?['waitingForInput'] == true) {
      statusMessage = 'Listening — audio plays through the selected speaker.';
      notifyListeners();
    }
    final modelTurn = serverContent?['modelTurn'] as Map<String, dynamic>?;
    final modelParts = modelTurn?['parts'] as List<dynamic>?;
    if (modelParts == null) return;
    for (final part in modelParts) {
      final inlineData =
          (part as Map<String, dynamic>)['inlineData'] as Map<String, dynamic>?;
      final encoded = inlineData?['data'] as String?;
      if (encoded != null) _playModelAudio(base64Decode(encoded));
    }
  }

  void _playModelAudio(Uint8List bytes) {
    if (!_playerReady || bytes.isEmpty) return;
    if (statusMessage != 'Gemini is responding…') {
      statusMessage = 'Gemini is responding…';
      notifyListeners();
    }
    _feedOutput(bytes);
    final milliseconds =
        (bytes.length * 1000 ~/ (_outputSampleRate * _bytesPerSample)) + 200;
    final now = DateTime.now();
    final queueEnd = _microphoneMutedUntil.isAfter(now)
        ? _microphoneMutedUntil
        : now;
    _microphoneMutedUntil = queueEnd.add(Duration(milliseconds: milliseconds));
  }

  void _startSilenceFeed() {
    final silence = Uint8List(_outputSampleRate ~/ 10 * _bytesPerSample);
    _silenceTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_playerReady && DateTime.now().isAfter(_microphoneMutedUntil)) {
        // Never queue idle audio behind a model response. One small silence
        // buffer keeps the A2DP media stream alive while waiting for speech.
        if (_outputQueue.isEmpty) _feedOutput(silence);
      }
    });
  }

  void _feedOutput(Uint8List bytes) {
    _outputQueue.add(bytes);
    if (!_isDrainingOutput) unawaited(_drainOutputQueue());
  }

  Future<void> _drainOutputQueue() async {
    _isDrainingOutput = true;
    final generation = _playbackGeneration;
    try {
      while (_playerReady &&
          generation == _playbackGeneration &&
          _outputQueue.isNotEmpty) {
        await _player.feedUint8FromStream(_outputQueue.removeFirst());
      }
    } catch (error) {
      if (!_disposed && generation == _playbackGeneration) {
        statusMessage = 'Audio playback error: $error';
        notifyListeners();
      }
    } finally {
      _isDrainingOutput = false;
      if (_playerReady &&
          generation == _playbackGeneration &&
          _outputQueue.isNotEmpty) {
        unawaited(_drainOutputQueue());
      }
    }
  }

  void _handleSocketClosed(Completer<void> setupComplete) {
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

  void _handleSocketError(Object error, Completer<void> setupComplete) {
    if (!setupComplete.isCompleted) setupComplete.completeError(error);
    statusMessage = 'Gemini Live connection error: $error';
    if (!_disposed) notifyListeners();
  }

  void _setStatus(String message) {
    statusMessage = message;
    if (!_disposed) notifyListeners();
  }

  Future<void> _stopInternal({required bool closePlayer}) async {
    _playbackGeneration++;
    _outputQueue.clear();
    _silenceTimer?.cancel();
    _silenceTimer = null;
    await _microphoneSubscription?.cancel();
    _microphoneSubscription = null;
    if (await _recorder.isRecording()) await _recorder.stop();
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await _socket?.close();
    _socket = null;
    if (closePlayer && _playerReady) {
      await _player.stopPlayer();
      await _player.closePlayer();
      _playerReady = false;
    }
    isRunning = false;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_stopInternal(closePlayer: true));
    unawaited(_recorder.dispose());
    super.dispose();
  }
}
