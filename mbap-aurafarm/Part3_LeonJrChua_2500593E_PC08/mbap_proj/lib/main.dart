import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'providers/biometric_provider.dart';
import 'providers/firebase_provider.dart';
import 'providers/user_provider.dart';
import 'theme/aura_theme.dart';

import 'screens/biometric_gate_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/card_detail_screen.dart';
import 'screens/create_upload_screen.dart';
import 'screens/create_editor_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/edit_screen.dart';
import 'screens/change_password_screen.dart';

import 'screens/email_verification_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Keeps user signed in when testing on Flutter Web
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    // App Personalisation - the theme follows the palette saved in the
    // user's firestore profile, so picking a new one recolours the app live
    final AuraPalette palette = ref.watch(auraPaletteProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AuraFarm',

      theme: AuraTheme.build(palette),

      // This decides the first screen based on Firebase login state.
      home: authState.when(
        data: (user) {
          if (user == null) {
            return LoginScreen();
          }

          // when the biometric lock is enabled on this device, the user
          // must pass a fingerprint scan before reaching the home screen
          final lockEnabled = ref.watch(biometricLockEnabledProvider);

          return lockEnabled.when(
            data: (enabled) {
              if (enabled) {
                return const BiometricGateScreen();
              }

              return HomeScreen();
            },
            loading: () {
              return const Scaffold(
                backgroundColor: Color(0xFF0A0A0F),
                body: Center(
                  child: CircularProgressIndicator(color: Color(0xFFBB86FC)),
                ),
              );
            },
            // if the preference cannot be read, fail open to home so the
            // user is never locked out by a settings error
            error: (err, stack) => HomeScreen(),
          );
        },
        loading: () {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0A0F),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFBB86FC)),
            ),
          );
        },
        error: (err, stack) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0A0F),
            body: Center(
              child: Text(
                'Something went wrong. Please restart the app.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        },
      ),

      // These are still needed for Navigator.pushNamed(...)
      routes: {
        LoginScreen.routeName: (context) => LoginScreen(),
        SignupScreen.routeName: (context) => SignupScreen(),
        ResetPasswordScreen.routeName: (context) => ResetPasswordScreen(),
        HomeScreen.routeName: (context) => HomeScreen(),
        ProfileScreen.routeName: (context) => ProfileScreen(),
        CardDetailScreen.routeName: (context) => const CardDetailScreen(),
        CreateUploadScreen.routeName: (context) => const CreateUploadScreen(),
        CreateEditorScreen.routeName: (context) => const CreateEditorScreen(),
        SettingsScreen.routeName: (context) => const SettingsScreen(),
        EditScreen.routeName: (context) => const EditScreen(),
        ChangePasswordScreen.routeName: (context) =>
            const ChangePasswordScreen(),
        EmailVerificationScreen.routeName: (context) =>
            const EmailVerificationScreen(),
      },
    );
  }
}
