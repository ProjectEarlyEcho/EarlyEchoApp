import 'dart:async';
import 'dart:typed_data';

import 'package:earlyecho/services/esp32_audio_streamer.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeEsp32Socket implements Esp32AudioSocket {
  final List<Object> sent = [];
  final Completer<void> _done = Completer<void>();

  @override
  void add(Object data) => sent.add(data);

  @override
  Future<void> close() async {
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> get done => _done.future;
}

void main() {
  test('preserves a PCM sample split across Gemini messages', () async {
    final socket = FakeEsp32Socket();
    final streamer = Esp32AudioStreamer(
      endpoint: Uri.parse('ws://10.2.0.19:81'),
      connector: (_) async => socket,
      maxLead: const Duration(days: 1),
    );

    await streamer.connect();
    final first = Uint8List.fromList(
      List<int>.generate(4001, (index) => index & 0xff),
    );
    final second = Uint8List.fromList([0xa1, 0xa2, 0xa3]);
    streamer.enqueue(first);
    await Future<void>.delayed(Duration.zero);
    streamer.enqueue(second);
    await Future<void>.delayed(Duration.zero);

    final binary = socket.sent.whereType<Uint8List>().toList();
    expect(binary.map((chunk) => chunk.length), [1920, 1920, 160, 4]);
    expect(binary.expand((chunk) => chunk), [...first, ...second]);
  });

  test('flush cancels paced queued audio and resets the ESP32', () async {
    final socket = FakeEsp32Socket();
    final streamer = Esp32AudioStreamer(
      endpoint: Uri.parse('ws://10.2.0.19:81'),
      connector: (_) async => socket,
      maxLead: Duration.zero,
    );

    await streamer.connect();
    streamer.enqueue(Uint8List(1920 * 5));
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await streamer.flush();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(socket.sent.whereType<String>(), ['flush']);
    expect(socket.sent.whereType<Uint8List>().length, 1);
    expect(streamer.queuedBytes, 0);
  });

  test('reports when the paced playback queue has drained', () async {
    final socket = FakeEsp32Socket();
    final drained = Completer<void>();
    final streamer = Esp32AudioStreamer(
      endpoint: Uri.parse('ws://10.2.0.19:81'),
      connector: (_) async => socket,
      onPlaybackDrained: drained.complete,
      maxLead: const Duration(days: 1),
    );

    await streamer.connect();
    streamer.enqueue(Uint8List(1920 * 2));

    await drained.future.timeout(const Duration(seconds: 1));
    expect(socket.sent.whereType<Uint8List>().length, 2);
    expect(streamer.queuedBytes, 0);
  });

  test('sends end marker after the final queued PCM packet', () async {
    final socket = FakeEsp32Socket();
    final streamer = Esp32AudioStreamer(
      endpoint: Uri.parse('ws://10.2.0.19:81'),
      connector: (_) async => socket,
      maxLead: const Duration(days: 1),
    );

    await streamer.connect();
    streamer.enqueue(Uint8List(1920 * 2));
    streamer.finishTurn();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(socket.sent.whereType<Uint8List>().length, 2);
    expect(socket.sent.last, 'end');
  });
}
