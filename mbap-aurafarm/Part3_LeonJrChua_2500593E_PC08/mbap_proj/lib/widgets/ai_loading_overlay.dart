import 'package:flutter/material.dart';

// full screen state shown while Gemini reads the two photos.
// the AI takes a few seconds, so a spinner on a button is not enough
// feedback: this explains what is happening step by step.
class AiLoadingOverlay extends StatefulWidget {
  const AiLoadingOverlay({super.key});

  @override
  State<AiLoadingOverlay> createState() => _AiLoadingOverlayState();
}

class _AiLoadingOverlayState extends State<AiLoadingOverlay>
    with SingleTickerProviderStateMixin {
  static const Color _neonPurple = Color(0xFFBB86FC);
  static const Color _neonPink = Color(0xFFFF6EC7);
  static const Color _textPrimary = Color(0xFFF4F1FF);
  static const Color _textSecondary = Color(0xFF9B95B8);

  // the steps cycle while the request is in flight
  static const List<String> _steps = [
    'Reading your expression...',
    'Checking out the fit...',
    'Matching a meme...',
    'Finding your sound...',
    'Generating your aura...',
  ];

  late final AnimationController _controller;
  int _stepIndex = 0;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _cycleSteps();
  }

  // advances the caption roughly every 1.6s while mounted
  Future<void> _cycleSteps() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 1600));

      if (!mounted) return;

      setState(() {
        _stepIndex = (_stepIndex + 1) % _steps.length;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xEE050509),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // pulsing aura ring
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final double t = _controller.value;

                return Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: const [
                        _neonPurple,
                        _neonPink,
                        Color(0xFF03DAC6),
                        _neonPurple,
                      ],
                      transform: GradientRotation(t * 6.28318),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _neonPurple.withValues(alpha: 0.35 + t * 0.2),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 92,
                      height: 92,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF0B0912),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: _neonPurple,
                        size: 34,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 26),
            const Text(
              'Farming your aura',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 22,
                fontFamily: 'CaveatBrush',
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              child: Text(
                _steps[_stepIndex],
                key: ValueKey<int>(_stepIndex),
                style: const TextStyle(color: _textSecondary, fontSize: 13.5),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: const LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: Color(0xFF241A3A),
                  valueColor: AlwaysStoppedAnimation<Color>(_neonPurple),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
