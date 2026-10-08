import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/biometric_provider.dart';
import '../providers/firebase_provider.dart';

// shown between login and the home screen when the biometric lock is on.
// the user must pass a fingerprint scan to continue, or log out.
class BiometricGateScreen extends ConsumerStatefulWidget {
  const BiometricGateScreen({super.key});

  @override
  ConsumerState<BiometricGateScreen> createState() =>
      _BiometricGateScreenState();
}

class _BiometricGateScreenState extends ConsumerState<BiometricGateScreen> {
  static const Color _neonPurple = Color(0xFFBB86FC);
  static const Color _textPrimary = Color(0xFFF0F0FF);
  static const Color _textSecondary = Color(0xFF9090AA);

  bool _isChecking = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();

    // asks for the scan as soon as the screen appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runScan();
    });
  }

  // runs one biometric attempt and unlocks the app on success
  Future<void> _runScan() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
      _failed = false;
    });

    final bool passed = await ref
        .read(biometricServiceProvider)
        .authenticate('Unlock AuraFarm');

    if (!mounted) return;

    if (passed) {
      // the gate flag lives in this session only; passing the scan simply
      // replaces this screen with home
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      setState(() {
        _isChecking = false;
        _failed = true;
      });
    }
  }

  // signing out is the escape hatch when the scan keeps failing
  Future<void> _logout() async {
    await ref.read(firebaseServiceProvider).logOut();

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _neonPurple.withValues(alpha: 0.12),
                    border: Border.all(
                      color: _neonPurple.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    color: _neonPurple,
                    size: 52,
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'Unlock AuraFarm',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _failed
                      ? 'Scan failed or was cancelled. Try again.'
                      : 'Use your fingerprint to continue.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: 240,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isChecking ? null : _runScan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neonPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isChecking
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Scan again',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: _logout,
                  child: const Text(
                    'Log out instead',
                    style: TextStyle(color: _textSecondary, fontSize: 13.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
