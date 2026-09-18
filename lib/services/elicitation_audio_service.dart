import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// Bundled Hindi instruction clips, one per elicitation protocol.
///
/// All three are silent placeholders standing in for real recordings of
/// the worker-facing instruction for each activity, keyed with the same
/// strings the `protocol_timings` contract uses.
const elicitationAudioAssetPaths = <String, String>{
  'rattle': 'assets/audio/elicit_rattle_hi.mp3',
  'toy_hide': 'assets/audio/elicit_toy_hi.mp3',
  'imitate': 'assets/audio/elicit_imitate_hi.mp3',
};

/// Thin playback port for the per-protocol instruction clips.
///
/// `just_audio` needs a platform channel that widget tests do not provide
/// (it throws `MissingPluginException` off-device), so tests substitute a
/// fake [ElicitationAudioPlayer] through [elicitationAudioPlayerProvider].
abstract class ElicitationAudioPlayer {
  /// Plays the instruction clip for [protocolKey] (`rattle`, `toy_hide`,
  /// `imitate`) to completion. Throws when playback is unavailable.
  Future<void> playFor(String protocolKey);

  /// Best-effort stop of any in-progress playback; never throws.
  Future<void> stop();
}

/// [ElicitationAudioPlayer] backed by `just_audio` and the bundled assets.
class JustAudioElicitationPlayer implements ElicitationAudioPlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> playFor(String protocolKey) async {
    final asset = elicitationAudioAssetPaths[protocolKey];
    if (asset == null) return;
    await _player.setAsset(asset);
    await _player.play();
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {
      // Stopping is cleanup — a failure leaves nothing worth reporting.
    }
  }

  Future<void> dispose() => _player.dispose();
}

/// Player used by the elicitation screen; overridden in widget tests.
final elicitationAudioPlayerProvider = Provider<ElicitationAudioPlayer>((ref) {
  final player = JustAudioElicitationPlayer();
  ref.onDispose(player.dispose);
  return player;
});
