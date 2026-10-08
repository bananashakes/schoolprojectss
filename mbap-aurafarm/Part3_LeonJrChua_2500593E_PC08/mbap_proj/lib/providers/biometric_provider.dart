import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/biometric_service.dart';

// gives every screen the same BiometricService instance
final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

// whether the biometric lock is switched on for this device.
// the auth gate in main.dart watches this to decide if the fingerprint
// screen should appear before the home screen.
final biometricLockEnabledProvider = FutureProvider<bool>((ref) {
  return ref.watch(biometricServiceProvider).isLockEnabled();
});
