import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

// plays the 30 second song previews that come back from the iTunes lookup.
// one shared player, so selecting a new song replaces whatever is playing
// instead of stacking clips on top of each other.
class PreviewPlayerService {
  final AudioPlayer _player = AudioPlayer();

  // the url currently loaded, used to toggle the same song off
  String? _currentUrl;

  String? get currentUrl => _currentUrl;

  bool get isPlaying => _player.playing;

  // emits whenever playback starts, stops or finishes
  Stream<PlayerState> get stateStream => _player.playerStateStream;

  // starts a clip. passing the url that is already playing stops it,
  // so tapping the same song twice acts as play/pause.
  Future<void> play(String url) async {
    if (_currentUrl == url && _player.playing) {
      await stop();
      return;
    }

    try {
      await _player.stop();
      await _player.setUrl(url);

      _currentUrl = url;

      // previews are short, so do not loop them
      await _player.play();
      _lastError = null;
    } catch (error) {
      // keep the message so the UI can explain why nothing played, and
      // log it so the cause is visible while developing
      _lastError = error.toString();
      debugPrint('AuraFarm preview playback failed: $error');
      _currentUrl = null;
    }
  }

  // why the last play attempt failed, if it did
  String? _lastError;
  String? get lastError => _lastError;

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (error) {
      // already stopped
    }

    _currentUrl = null;
  }

  // must be called when the screen is disposed, otherwise audio keeps
  // playing after the user navigates away
  Future<void> dispose() async {
    await _player.dispose();
  }
}
