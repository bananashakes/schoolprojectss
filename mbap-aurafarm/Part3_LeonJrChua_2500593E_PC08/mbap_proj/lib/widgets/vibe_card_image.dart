import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/vibe_card.dart';
import '../utils/photo_cache.dart';

// draws a vibe card that was saved as one flat picture.
//
// this is the older format: the whole card was flattened to a JPEG when it
// was posted, so nothing on it can change afterwards. cards posted since
// then keep their parts and are drawn by VibeCardView instead, which falls
// back to this widget for anything from before.
class VibeCardImage extends StatelessWidget {
  final VibeCard card;
  final BoxFit fit;
  final Widget? fallback;

  const VibeCardImage({
    super.key,
    required this.card,
    this.fit = BoxFit.cover,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (card.imageBase64.isNotEmpty) {
      final Uint8List? bytes = PhotoCache.decode(
        '${card.postId}#flat',
        card.imageBase64,
      );

      if (bytes == null) {
        return _buildFallback();
      }

      return Image.memory(
        bytes,
        fit: fit,
        // keeps the old frame on screen while rebuilding, so the feed does
        // not flicker white every time the list updates
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          return _buildFallback();
        },
      );
    }

    if (card.imagePath.isEmpty) {
      return _buildFallback();
    }

    return Image.asset(
      card.imagePath,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        return _buildFallback();
      },
    );
  }

  Widget _buildFallback() {
    if (fallback != null) {
      return fallback!;
    }

    return Container(
      color: const Color(0xFF16102A),
      child: const Center(
        child: Icon(Icons.image_outlined, color: Colors.white24, size: 36),
      ),
    );
  }
}
