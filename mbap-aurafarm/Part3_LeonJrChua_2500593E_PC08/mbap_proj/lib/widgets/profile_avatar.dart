import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

// shows a user's profile picture.
// pictures are stored as base64 on the user document, so decoded bytes are
// cached here the same way vibe card images are, otherwise the feed would
// re-decode the same photo on every rebuild.
class ProfileAvatar extends StatelessWidget {
  final String photoBase64;
  final String username;
  final double size;

  // fallback asset used when the user has not set a picture
  final String? assetFallback;

  // circular by default, which is what every avatar in the app wants.
  // the polaroid on the profile screen sets this false: it has a
  // rectangular window, and clipping to a circle there meant the picture
  // had to be scaled up past the frame to hide the curved edges, which
  // cropped most of it away.
  final bool circle;

  const ProfileAvatar({
    super.key,
    required this.photoBase64,
    required this.username,
    this.size = 40,
    this.assetFallback,
    this.circle = true,
  });

  static final Map<String, Uint8List> _cache = <String, Uint8List>{};

  static Uint8List? _decode(String base64Text) {
    if (base64Text.isEmpty) {
      return null;
    }

    // key on length + a prefix so different photos never collide
    final String key =
        '${base64Text.length}:${base64Text.substring(0, base64Text.length.clamp(0, 24))}';

    final Uint8List? cached = _cache[key];

    if (cached != null) {
      return cached;
    }

    try {
      final Uint8List bytes = base64Decode(base64Text);

      if (_cache.length >= 20) {
        _cache.remove(_cache.keys.first);
      }

      _cache[key] = bytes;

      return bytes;
    } catch (error) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Uint8List? bytes = _decode(photoBase64);

    final Widget picture = bytes != null
        ? Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
        : _buildFallback();

    // rectangular form fills whatever box it is given, so the photo is
    // cropped to that frame rather than shrunk into a circle inside it
    if (!circle) {
      return SizedBox.expand(child: picture);
    }

    return ClipOval(
      child: SizedBox(width: size, height: size, child: picture),
    );
  }

  Widget _buildFallback() {
    if (assetFallback != null) {
      return Image.asset(
        assetFallback!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildInitial(),
      );
    }

    return _buildInitial();
  }

  // coloured initial, stable per username
  Widget _buildInitial() {
    const List<Color> palette = [
      Color(0xFF8B5CF6),
      Color(0xFFFF2D78),
      Color(0xFF03DAC6),
      Color(0xFFFFAA00),
      Color(0xFF2D7DFF),
    ];

    final int seed = username.isEmpty
        ? 0
        : username.codeUnits.fold<int>(0, (a, c) => a + c);
    final Color tint = palette[seed % palette.length];

    return Container(
      color: tint.withValues(alpha: 0.25),
      child: Center(
        child: Text(
          username.isEmpty ? '?' : username[0].toUpperCase(),
          style: TextStyle(
            color: tint,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
