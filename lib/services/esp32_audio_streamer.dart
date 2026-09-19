import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

abstract interface class Esp32AudioSocket {
  void add(Object data);

  Future<void> close();

  Future<void> get done;
}

class IoEsp32AudioSocket implements Esp32AudioSocket {
  IoEsp32AudioSocket(this._socket);

  final WebSocket _socket;

  @override
  void add(Object data) => _socket.add(data);

  @override
  Future<void> close() async {
    await _socket.close();
  }

  @override
  Future<void> get done async {
    await _socket.done;
  }
}

typedef Esp32SocketConnector = Future<Esp32AudioSocket> Function(Uri endpoint);

/// Sends Gemini's 24 kHz, signed 16-bit mono PCM to an ESP32 WebSocket.
///
/// Incoming model chunks are queued immediately so the Gemini receive loop is
/// never blocked. A separate drain loop splits them into 40 ms packets and
/// limits how far transmission can run ahead of real time. The ESP32 can then
/// maintain a small jitter buffer without receiving the whole response burst.
class Esp32AudioStreamer {
  Esp32AudioStreamer({
    required this.endpoint,
    Esp32SocketConnector? connector,
    this.onError,
    this.onDisconnected,
    this.onPlaybackDrained,
    this.chunkBytes = 1920,
    this.bytesPerSecond = 48000,
    this.maxLead = const Duration(milliseconds: 1000),
  }) : _connector = connector ?? _connectIoSocket;

  final Uri endpoint;
  final Esp32SocketConnector _connector;
  final void Function(Object error)? onError;
  final void Function()? onDisconnected;
  final void Function()? onPlaybackDrained;
  final int chunkBytes;
  final int bytesPerSecond;
  final Duration maxLead;

  final Queue<Uint8List> _queue = Queue<Uint8List>();
  Esp32AudioSocket? _socket;
  Stopwatch? _pacerClock;
  double _scheduledAudioSeconds = 0;
  int _generation = 0;
  bool _draining = false;
  bool _closing = false;
  bool _finishTurnWhenDrained = false;
  int? _pendingByte;

  bool get isConnected => _socket != null && !_closing;

  int get queuedBytes => _queue.fold(0, (total, chunk) => total + chunk.length);

  Future<void> connect() async {
    if (isConnected) return;
    if (endpoint.scheme != 'ws' && endpoint.scheme != 'wss') {
      throw ArgumentError.value(
        endpoint,
        'endpoint',
        'Must use ws:// or wss://',
      );
    }
    _closing = false;
    final socket = await _connector(endpoint);
    _socket = socket;
    unawaited(
      socket.done
          .then((_) {
            if (_socket != socket) return;
            _socket = null;
            if (!_closing) onDisconnected?.call();
          })
          .catchError((Object error) {
            if (!_closing) onError?.call(error);
          }),
    );
  }

  void enqueue(Uint8List pcm) {
    if (!isConnected || pcm.isEmpty) return;

    final pendingByte = _pendingByte;
    final combined = pendingByte == null
        ? pcm
        : (Uint8List(pcm.length + 1)
            ..[0] = pendingByte
            ..setRange(1, pcm.length + 1, pcm));
    final evenLength = combined.length & ~1;
    _pendingByte = evenLength == combined.length ? null : combined.last;

    for (var offset = 0; offset < evenLength; offset += chunkBytes) {
      final end = (offset + chunkBytes).clamp(0, evenLength);
      _queue.add(Uint8List.fromList(combined.sublist(offset, end)));
    }
    if (!_draining) unawaited(_drain());
  }

  /// Cancels queued/in-flight generation audio and resets the ESP32 jitter
  /// buffer. The generation check prevents a delayed packet from being sent
  /// after a barge-in flush.
  Future<void> flush() async {
    _generation++;
    _queue.clear();
    _finishTurnWhenDrained = false;
    _pendingByte = null;
    _resetPacer();
    _socket?.add('flush');
  }

  /// Marks the final PCM packet in the current Gemini response.
  ///
  /// WebSocket frames are ordered, so sending this only after the local queue
  /// drains lets the ESP32 play a final tail smaller than its prime threshold.
  void finishTurn() {
    if (!isConnected) return;
    _finishTurnWhenDrained = true;
    if (!_draining && _queue.isEmpty) _sendEndOfTurn();
  }

  Future<void> close() async {
    _closing = true;
    await flush();
    final socket = _socket;
    _socket = null;
    if (socket != null) await socket.close();
  }

  Future<void> _drain() async {
    _draining = true;
    final generation = _generation;
    try {
      while (isConnected && generation == _generation && _queue.isNotEmpty) {
        final chunk = _queue.removeFirst();
        await _pace(generation);
        if (!isConnected || generation != _generation) return;
        _socket!.add(chunk);
        _scheduledAudioSeconds += chunk.length / bytesPerSecond;
      }
    } catch (error) {
      if (!_closing && generation == _generation) onError?.call(error);
    } finally {
      _draining = false;
      if (isConnected && _queue.isNotEmpty) {
        unawaited(_drain());
      } else if (isConnected && generation == _generation) {
        if (_finishTurnWhenDrained) _sendEndOfTurn();
        onPlaybackDrained?.call();
      }
    }
  }

  Future<void> _pace(int generation) async {
    var clock = _pacerClock;
    if (clock == null ||
        clock.elapsed.inMicroseconds / 1000000 > _scheduledAudioSeconds) {
      clock = Stopwatch()..start();
      _pacerClock = clock;
      _scheduledAudioSeconds = 0;
    }

    final elapsedSeconds = clock.elapsed.inMicroseconds / 1000000;
    final aheadSeconds = _scheduledAudioSeconds - elapsedSeconds;
    final leadSeconds = maxLead.inMicroseconds / 1000000;
    if (aheadSeconds > leadSeconds) {
      await Future<void>.delayed(
        Duration(
          microseconds: ((aheadSeconds - leadSeconds) * 1000000).round(),
        ),
      );
    }
    if (generation != _generation) return;
  }

  void _resetPacer() {
    _pacerClock?.stop();
    _pacerClock = null;
    _scheduledAudioSeconds = 0;
  }

  void _sendEndOfTurn() {
    _finishTurnWhenDrained = false;
    _socket?.add('end');
  }

  static Future<Esp32AudioSocket> _connectIoSocket(Uri endpoint) async {
    final socket = await WebSocket.connect(endpoint.toString());
    return IoEsp32AudioSocket(socket);
  }
}
