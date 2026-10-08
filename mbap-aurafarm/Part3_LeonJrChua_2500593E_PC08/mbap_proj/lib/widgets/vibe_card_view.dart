import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/vibe_card.dart';
import '../utils/meme_library.dart';
import '../utils/photo_cache.dart';
import 'vibe_card_canvas.dart';
import 'vibe_card_image.dart';

// draws a vibe card in the feed, profile grid, detail and edit screens.
// a card is composed from its parts every time it is drawn, which is why
// editing one changes how it looks. older cards saved as a flat picture
// fall back to VibeCardImage.
class VibeCardView extends StatelessWidget {
  final VibeCard card;

  // only used by the flat fallback; a composed card always fills its space
  final BoxFit fit;
  final Widget? fallback;

  const VibeCardView({
    super.key,
    required this.card,
    this.fit = BoxFit.cover,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (!card.isLiveComposed) {
      return VibeCardImage(card: card, fit: fit, fallback: fallback);
    }

    final Uint8List? outfit = PhotoCache.decode(
      '${card.postId}#outfit',
      card.outfitBase64,
    );
    final Uint8List? selfie = PhotoCache.decode(
      '${card.postId}#selfie',
      card.selfieBase64,
    );

    // a layout but no usable photo means nothing to compose
    if (outfit == null && card.imagePath.isEmpty) {
      return VibeCardImage(card: card, fit: fit, fallback: fallback);
    }

    return VibeCardCanvas(
      outfitBytes: outfit,
      selfieBytes: selfie,
      // the sample cards carry an asset path instead of stored bytes
      outfitAssetPath: outfit == null ? card.imagePath : null,
      vibe: card.displayVibe,
      auraLine: card.auraLine,
      songName: card.songName,
      songArtist: card.songArtist,
      albumArtUrl: card.albumArtUrl.isEmpty ? null : card.albumArtUrl,
      memeImagePath: MemeLibrary.imageFor(card.memeName),
      memePosition: card.memePosition,
      songPosition: card.songPosition,
      selfiePosition: card.selfiePosition,
      labelPosition: card.labelPosition,
      vibePosition: card.vibePosition,
    );
  }
}
