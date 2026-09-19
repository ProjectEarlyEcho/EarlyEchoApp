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
  test('splits PCM into even 40 ms binary chunks', () async {
    final socket = FakeEsp32Socket();
    final streamer = Esp32AudioStreamer(
      endpoint: Uri.parse('ws://10.2.0.19:81'),
      connector: (_) async => socket,
      maxLead: const Duration(days: 1),
    );

    await streamer.connect();
    streamer.enqueue(Uint8List(4001));
    await Future<void>.delayed(Duration.zero);

    final binary = socket.sent.whereType<Uint8List>().toList();
    expect(binary.map((chunk) => chunk.length), [1920, 1920, 160]);
    expect(binary.expand((chunk) => chunk).length, 4000);
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
}
