import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// reusable heart button used by the feed, the profile grid and the card
// detail screen. it plays a short bounce and a haptic tap so liking feels
// responsive even while the firestore write is still in flight.
class LikeButton extends StatefulWidget {
  final bool liked;
  final int likeCount;
  final VoidCallback onTap;

  // sizes differ between the feed cards and the small profile grid tiles
  final double iconSize;
  final double fontSize;
  final Color likedColor;
  final Color idleColor;
  final Color textColor;

  const LikeButton({
    super.key,
    required this.liked,
    required this.likeCount,
    required this.onTap,
    this.iconSize = 20,
    this.fontSize = 12,
    this.likedColor = const Color(0xFFFF2D78),
    this.idleColor = Colors.white54,
    this.textColor = Colors.white70,
  });

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    // grows past full size then settles back, like a pop
    _scale =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 45),
          TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 55),
        ]).animate(
          // must stay within 0..1: TweenSequence asserts on t, and curves
          // like easeOutBack deliberately overshoot past 1.0
          CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    // only bounce when liking, un-liking should feel quieter
    if (!widget.liked) {
      _controller.forward(from: 0);
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.selectionClick();
    }

    widget.onTap();
  }

  String _formatCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }

    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scale,
            child: Icon(
              widget.liked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: widget.liked ? widget.likedColor : widget.idleColor,
              size: widget.iconSize,
            ),
          ),
          SizedBox(width: widget.iconSize * 0.25),
          Text(
            _formatCount(widget.likeCount),
            style: TextStyle(
              color: widget.textColor,
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
