import 'dart:ui' show Offset;

import 'vibe_card.dart';

// where the five draggable overlays sit, as fractions of the card size.
// held in a ValueNotifier while editing: a drag fires many times a second
// and setState would rebuild every panel on the screen.
class CardLayout {
  final Offset meme;
  final Offset song;
  final Offset selfie;
  final Offset label;
  final Offset vibe;

  const CardLayout({
    required this.meme,
    required this.song,
    required this.selfie,
    required this.label,
    required this.vibe,
  });

  // a brand new card starts arranged the way the model describes
  static const CardLayout initial = CardLayout(
    meme: VibeCard.defaultMemePosition,
    song: VibeCard.defaultSongPosition,
    selfie: VibeCard.defaultSelfiePosition,
    label: VibeCard.defaultLabelPosition,
    vibe: VibeCard.defaultVibePosition,
  );

  // moves one overlay, named by the id the canvas reports when dragging
  CardLayout moved(String id, Offset to) {
    return CardLayout(
      meme: id == 'meme' ? to : meme,
      song: id == 'song' ? to : song,
      selfie: id == 'selfie' ? to : selfie,
      vibe: id == 'vibe' ? to : vibe,
      label: id == 'label' ? to : label,
    );
  }
}
