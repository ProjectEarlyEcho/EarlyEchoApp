import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// Bundled Hindi consent statement played on the consent screen.
///
/// Placeholder clip — the production asset is a real AI4Bharat TTS recording
/// of the translated consent script.
const consentAudioAssetPath = 'assets/audio/consent_hi.mp3';

/// Thin playback port for the consent statement.
///
/// `just_audio` needs a platform channel that widget tests do not provide
/// (it throws `MissingPluginException` off-device), so tests substitute a
/// fake [ConsentAudioPlayer] through [consentAudioPlayerProvider].
abstract class ConsentAudioPlayer {
  /// Plays the consent clip to completion. Throws when playback is
  /// unavailable on this device.
  Future<void> play();

  /// Best-effort stop of any in-progress playback; never throws.
  Future<void> stop();
}

/// [ConsentAudioPlayer] backed by `just_audio` and the bundled asset.
class JustAudioConsentPlayer implements ConsentAudioPlayer {
  JustAudioConsentPlayer({this.assetPath = consentAudioAssetPath});

  final String assetPath;
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> play() async {
    await _player.setAsset(assetPath);
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

/// Player used by the consent screen; overridden in widget tests.
final consentAudioPlayerProvider = Provider<ConsentAudioPlayer>((ref) {
  final player = JustAudioConsentPlayer();
  ref.onDispose(player.dispose);
  return player;
});
