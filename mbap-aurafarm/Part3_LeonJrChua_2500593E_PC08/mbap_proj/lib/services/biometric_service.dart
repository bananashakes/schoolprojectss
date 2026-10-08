import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ADDITIONAL FEATURE - Biometric login (local_auth)
// adds a fingerprint unlock step on top of Firebase authentication.
// when the user enables it in settings, the app asks for a biometric scan
// before showing the home screen, even though Firebase still remembers the
// session. browsers have no fingerprint API, so everything is disabled on
// web with kIsWeb checks.
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  // key used to remember the toggle on this device
  static const String _enabledKey = 'biometric_lock_enabled';

  // whether this device is capable of biometric checks at all
  Future<bool> isSupported() async {
    if (kIsWeb) {
      return false;
    }

    try {
      final bool supported = await _auth.isDeviceSupported();
      final bool canCheck = await _auth.canCheckBiometrics;

      return supported && canCheck;
    } on PlatformException {
      return false;
    }
  }

  // asks the user to scan their fingerprint.
  // returns true when the scan succeeds.
  Future<bool> authenticate(String reason) async {
    if (kIsWeb) {
      return false;
    }

    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false, // falls back to device PIN if needed
        persistAcrossBackgrounding: true, // survives app switch mid-scan
      );
    } on PlatformException {
      return false;
    }
  }

  // reads whether the user turned the biometric lock on for this device
  Future<bool> isLockEnabled() async {
    if (kIsWeb) {
      return false;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();

    return prefs.getBool(_enabledKey) ?? false;
  }

  // saves the toggle. the choice is stored per device (not per account)
  // because fingerprints belong to the device, not the Firebase user.
  Future<void> setLockEnabled(bool enabled) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_enabledKey, enabled);
  }
}
