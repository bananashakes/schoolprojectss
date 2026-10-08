import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/music_service.dart';
import '../services/preview_player_service.dart';

// gives every screen the same MusicService instance
final musicServiceProvider = Provider<MusicService>((ref) {
  return MusicService();
});

// shared audio player for the song previews.
// not autoDispose - screens only read() this, so it would be disposed in
// the same frame that started playback and the audio would die.
final previewPlayerProvider = Provider<PreviewPlayerService>((ref) {
  final PreviewPlayerService player = PreviewPlayerService();

  ref.onDispose(player.dispose);

  return player;
});
