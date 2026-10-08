import 'dart:typed_data';

import 'package:flutter/material.dart';

// the composed vibe card from the Part 1 proposal: the outfit photo fills
// the card, the selfie sits on top like a BeReal inset, and the album art
// and meme sticker can be dragged anywhere.
class VibeCardCanvas extends StatelessWidget {
  // every surface that shows a vibe card uses this shape, so the composed
  // image is never cropped differently to how it was designed
  static const double aspect = 0.8; // 4:5 portrait

  final Uint8List? outfitBytes;
  final Uint8List? selfieBytes;

  // sample cards ship their outfit photo as a bundled asset rather than as
  // base64 in the document, so they pass a path here instead of bytes
  final String? outfitAssetPath;

  final String vibe;
  final String auraLine;
  final String songName;
  final String songArtist;
  final String? albumArtUrl;
  final String memeImagePath;

  // positions are fractions of the card size (0..1) so the layout survives
  // being rendered at a different scale during export
  final Offset memePosition;
  final Offset songPosition;
  final Offset selfiePosition;
  final Offset labelPosition;

  // the vibe chip moves on its own, separately from the aura line
  final Offset vibePosition;

  // null while exporting, so the drag handles do not appear in the PNG
  final void Function(String element, Offset newPosition)? onDrag;

  // tapping the aura line opens the text editor
  final VoidCallback? onLabelTap;

  const VibeCardCanvas({
    super.key,
    required this.outfitBytes,
    required this.selfieBytes,
    this.outfitAssetPath,
    required this.vibe,
    required this.auraLine,
    required this.songName,
    required this.songArtist,
    required this.albumArtUrl,
    required this.memeImagePath,
    required this.memePosition,
    required this.songPosition,
    required this.selfiePosition,
    required this.labelPosition,
    required this.vibePosition,
    this.onDrag,
    this.onLabelTap,
  });

  bool get _isInteractive => onDrag != null;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;

        // not clipped: JPEG has no alpha, so rounded corners come out
        // black on export. the display surfaces round it instead.
        return Stack(
          fit: StackFit.expand,
          children: [
            // the photo never moves, so it gets its own layer instead
            // of being re-rasterised on every frame of a drag
            RepaintBoundary(
              child: Stack(
                fit: StackFit.expand,
                children: [_buildOutfitLayer(), _buildVignette()],
              ),
            ),
            // size fractions keep each element inside the card. heights
            // divide by (h / w) because they are relative to the width.
            // the aura line stays in the editor when empty so it can be
            // tapped to write one.
            if (auraLine.isNotEmpty || _isInteractive)
              _buildDraggable(
                id: 'label',
                position: labelPosition,
                width: w,
                height: h,
                sizeFraction: Size(0.72, 0.72 * 0.26 * w / h),
                onTap: onLabelTap,
                child: _buildAuraLine(w),
              ),
            // the vibe chip is its own element so it can sit anywhere on
            // the card rather than being stuck under the aura line
            if (vibe.isNotEmpty)
              _buildDraggable(
                id: 'vibe',
                position: vibePosition,
                width: w,
                height: h,
                sizeFraction: Size(0.52, 0.075 * w / h),
                child: _buildVibeChip(w),
              ),
            // sample cards have no selfie, so the inset is left out.
            // the editor always shows it so the slot is visible.
            if (selfieBytes != null || _isInteractive)
              _buildDraggable(
                id: 'selfie',
                position: selfiePosition,
                width: w,
                height: h,
                sizeFraction: Size(0.30, 0.30 * 1.32 * w / h),
                child: _buildSelfieInset(w),
              ),
            _buildDraggable(
              id: 'song',
              position: songPosition,
              width: w,
              height: h,
              sizeFraction: Size(0.64, 0.20 * w / h),
              child: _buildSongChip(w),
            ),
            _buildDraggable(
              id: 'meme',
              position: memePosition,
              width: w,
              height: h,
              sizeFraction: Size(0.26, 0.26 * w / h),
              child: _buildMemeSticker(w),
            ),
          ],
        );
      },
    );
  }

  // the outfit photo fills the whole card
  Widget _buildOutfitLayer() {
    if (outfitBytes != null) {
      return Image.memory(
        outfitBytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _buildEmptyOutfit(),
      );
    }

    final String? assetPath = outfitAssetPath;

    if (assetPath != null && assetPath.isNotEmpty) {
      return Image.asset(
        assetPath,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _buildEmptyOutfit(),
      );
    }

    return _buildEmptyOutfit();
  }

  Widget _buildEmptyOutfit() {
    return Container(color: const Color(0xFF16102A));
  }

  // keeps the overlays readable over a bright photo
  Widget _buildVignette() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.35),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.45),
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
    );
  }

  // sizes below scale with the card width: it is drawn full width in the
  // feed and half that in the profile grid. 360 is the design width.
  static double _scale(double cardWidth) => cardWidth / 360;

  // the AI's aura line, the thing the card is really about
  Widget _buildAuraLine(double cardWidth) {
    final double s = _scale(cardWidth);

    return SizedBox(
      width: cardWidth * 0.72,
      child: Text(
        auraLine,
        maxLines: 2,
        style: TextStyle(
          color: Colors.white,
          fontSize: 30 * s,
          height: 1.05,
          fontFamily: 'CaveatBrush',
          letterSpacing: 0.6 * s,
          shadows: [
            Shadow(color: Colors.black87, blurRadius: 12 * s),
            Shadow(color: Colors.black54, blurRadius: 4 * s),
          ],
        ),
      ),
    );
  }

  // the vibe wording, on its own so it can be placed anywhere
  Widget _buildVibeChip(double cardWidth) {
    final double s = _scale(cardWidth);

    // needs a bounded width: it sits in a Positioned, and the Flexible
    // below cannot lay out against unbounded constraints
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: cardWidth * 0.52),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 4 * s),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20 * s),
          border: Border.all(
            color: const Color(0xFFBB86FC).withValues(alpha: 0.8),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color: const Color(0xFFBB86FC),
              size: 11 * s,
            ),
            SizedBox(width: 5 * s),
            // the AI writes this wording itself, so it can run long
            Flexible(
              child: Text(
                vibe,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11 * s,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // the BeReal style selfie inset
  Widget _buildSelfieInset(double cardWidth) {
    final double s = _scale(cardWidth);
    final double size = cardWidth * 0.30;

    return Container(
      width: size,
      height: size * 1.32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14 * s),
        border: Border.all(color: Colors.black, width: 3 * s),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 12 * s,
            offset: Offset(0, 4 * s),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11 * s),
        child: selfieBytes == null
            ? Container(
                color: const Color(0xFF241a3a),
                child: Center(
                  child: Icon(
                    Icons.face_retouching_natural_rounded,
                    color: Colors.white30,
                    size: 28 * s,
                  ),
                ),
              )
            : Image.memory(
                selfieBytes!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
      ),
    );
  }

  // album art + track name, the "song widget" from the proposal
  Widget _buildSongChip(double cardWidth) {
    final double s = _scale(cardWidth);
    final double art = cardWidth * 0.13;

    return Container(
      padding: EdgeInsets.all(7 * s),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14 * s),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8 * s),
            child: SizedBox(
              width: art,
              height: art,
              child: albumArtUrl == null
                  ? Container(
                      color: const Color(0xFF8B5CF6),
                      child: Center(
                        child: Text(
                          songName.isEmpty ? '?' : songName[0].toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14 * s,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  : Image.network(
                      albumArtUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(color: const Color(0xFF8B5CF6));
                      },
                    ),
            ),
          ),
          SizedBox(width: 8 * s),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: cardWidth * 0.42),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  songName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12 * s,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  songArtist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white70, fontSize: 10.5 * s),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemeSticker(double cardWidth) {
    final double s = _scale(cardWidth);
    final double size = cardWidth * 0.26;

    // square artwork on white, so a pale sticker needs a frame or it
    // dissolves into a pale photo
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16 * s),
        border: Border.all(color: Colors.black, width: 3 * s),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 10 * s,
            offset: Offset(0, 3 * s),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13 * s),
        child: Image.asset(
          memeImagePath,
          // the artwork is already square, so this fills the frame exactly
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  // wraps an overlay so it can be dragged while editing.
  // sizeFraction is how much of the card it occupies, used to clamp the
  // drag so the whole element stays inside.
  Widget _buildDraggable({
    required String id,
    required Offset position,
    required double width,
    required double height,
    required Size sizeFraction,
    required Widget child,
    VoidCallback? onTap,
  }) {
    final double maxX = (1.0 - sizeFraction.width).clamp(0.0, 1.0);
    final double maxY = (1.0 - sizeFraction.height).clamp(0.0, 1.0);

    final Widget content = _isInteractive
        ? GestureDetector(
            onTap: onTap,
            onPanUpdate: (details) {
              final double nx = (position.dx + details.delta.dx / width).clamp(
                0.0,
                maxX,
              );
              final double ny = (position.dy + details.delta.dy / height).clamp(
                0.0,
                maxY,
              );

              onDrag!(id, Offset(nx, ny));
            },
            child: child,
          )
        : child;

    return Positioned(
      left: position.dx * width,
      top: position.dy * height,
      // each overlay gets its own layer, so moving one just shifts that
      // layer instead of repainting the others alongside it
      child: RepaintBoundary(child: content),
    );
  }
}
