import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../providers/firebase_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/aura_snack_bar.dart';
import 'home_screen.dart';
import 'reset_password_screen.dart';
import 'signup_screen.dart';
import '../widgets/validators.dart';

// screen for logging into aurafarm
class LoginScreen extends ConsumerStatefulWidget {
  static const String routeName = '/login';

  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // form key validates email and password before firebase is called
  final _formKey = GlobalKey<FormState>();

  // stores the email and password after the form is saved
  String? _email;
  String? _password;

  // local ui states for password visibility and remember me checkbox
  bool _obscurePassword = true;
  bool _rememberMe = true;

  static const _fieldBg = Color(0xFF1E1535);
  static const _purple = Color(0xFF8B5CF6);
  static const _darkPurple = Color(0xFF6D28D9);
  static const _pink = Color(0xFFFF2D78);

  // shows styled login messages using the reusable aura snackbar
  void _showLoginSnackBar(
    String message, {
    IconData icon = Icons.check_circle_outline_rounded,
    Color color = _purple,
  }) {
    showAuraSnackBar(
      context,
      message,
      icon: icon,
      backgroundColor: _fieldBg,
      iconColor: color,
      borderColor: color,
      textColor: Colors.white,
      borderOpacity: 0.45,
      shadowColor: color,
      shadowOpacity: 0.22,
      blurRadius: 18,
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 20),
    );
  }

  // clears all auth pages and opens the home screen
  void _goToHome() {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(HomeScreen.routeName, (route) => false);
  }

  // runs when user presses the login button
  Future<void> _login() async {
    // input errors appear under the text fields
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _formKey.currentState!.save();
    FocusScope.of(context).unfocus();

    try {
      // gets firebase service using riverpod
      final firebaseService = ref.read(firebaseServiceProvider);

      // logs in using email and password
      await firebaseService.login(_email!, _password!);

      if (mounted) {
        _showLoginSnackBar(
          'Logged in successfully!',
          icon: Icons.check_circle_rounded,
          color: _purple,
        );

        _goToHome();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        // firebase errors happen after submit, so they use snackbar
        _showLoginSnackBar(
          _friendlyError(e.code),
          icon: Icons.error_outline_rounded,
          color: _pink,
        );
      }
    } catch (e) {
      if (mounted) {
        _showLoginSnackBar(
          'Login failed. Please try again.',
          icon: Icons.error_outline_rounded,
          color: _pink,
        );
      }
    }
  }

  // runs when user presses google sign in
  Future<void> _loginWithGoogle() async {
    FocusScope.of(context).unfocus();

    try {
      // gets firebase service using riverpod
      final firebaseService = ref.read(firebaseServiceProvider);

      // opens google sign in flow
      final result = await firebaseService.signInWithGoogle();

      // result is null if user closes the popup
      if (result == null) {
        if (mounted) {
          _showLoginSnackBar(
            'Google sign-in cancelled.',
            icon: Icons.info_outline_rounded,
            color: _purple,
          );
        }
        return;
      }

      // first google sign-in also creates the users collection document
      if (result.user != null) {
        await ref.read(userServiceProvider).ensureProfile(result.user!);
      }

      if (mounted) {
        _showLoginSnackBar(
          'Signed in with Google successfully!',
          icon: Icons.check_circle_rounded,
          color: _purple,
        );

        _goToHome();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showLoginSnackBar(
          _friendlyError(e.code),
          icon: Icons.error_outline_rounded,
          color: _pink,
        );
      }
    } catch (e) {
      if (mounted) {
        _showLoginSnackBar(
          'Google sign-in failed. Please try again.',
          icon: Icons.error_outline_rounded,
          color: _pink,
        );
      }
    }
  }

  // runs when user presses github sign in
  Future<void> _loginWithGitHub() async {
    FocusScope.of(context).unfocus();

    try {
      // gets firebase service using riverpod
      final firebaseService = ref.read(firebaseServiceProvider);

      // opens github sign in flow
      final result = await firebaseService.signInWithGitHub();

      // result is null if user closes the popup
      if (result == null) {
        if (mounted) {
          _showLoginSnackBar(
            'GitHub sign-in cancelled.',
            icon: Icons.info_outline_rounded,
            color: _purple,
          );
        }
        return;
      }

      // first github sign-in also creates the users collection document
      if (result.user != null) {
        await ref.read(userServiceProvider).ensureProfile(result.user!);
      }

      if (mounted) {
        _showLoginSnackBar(
          'Signed in with GitHub successfully!',
          icon: Icons.check_circle_rounded,
          color: _purple,
        );

        _goToHome();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showLoginSnackBar(
          _friendlyError(e.code),
          icon: Icons.error_outline_rounded,
          color: _pink,
        );
      }
    } catch (e) {
      if (mounted) {
        _showLoginSnackBar(
          'GitHub sign-in failed. Please try again.',
          icon: Icons.error_outline_rounded,
          color: _pink,
        );
      }
    }
  }

  // changes firebase error codes into simpler messages
  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'popup-closed-by-user':
        return 'Sign-in was cancelled.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase.';
      case 'account-exists-with-different-credential':
        return 'This email is already linked to another sign-in method.';
      case 'credential-already-in-use':
        return 'This account is already linked to another user.';
      default:
        return 'Login failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),

                _buildBranding(
                  title: 'AuraFarm',
                  subtitle: 'Post your vibe. Own your aura.',
                ),
                const SizedBox(height: 28),

                _buildLabel('Email'),
                const SizedBox(height: 8),
                _buildTextField(
                  hint: 'you@example.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  onSaved: (value) {
                    _email = value!.trim();
                  },
                  validator: Validation.email,
                ),
                const SizedBox(height: 20),

                _buildLabel('Password'),
                const SizedBox(height: 8),
                _buildTextField(
                  hint: '••••••••',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.white38,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  onSaved: (value) {
                    _password = value;
                  },
                  validator: Validation.password,
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _rememberMe,
                        activeColor: _purple,
                        checkColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        onChanged: (value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Remember me',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(
                          context,
                        ).pushNamed(ResetPasswordScreen.routeName);
                      },
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(
                          color: _purple,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                _buildPrimaryButton(label: 'Login', onPressed: _login),
                const SizedBox(height: 24),

                _buildDivider(),
                const SizedBox(height: 20),

                _buildSocialButton(
                  label: 'Sign in with Google',
                  imagePath: 'images/google_logo.png',
                  onPressed: _loginWithGoogle,
                ),
                const SizedBox(height: 12),

                _buildSocialButton(
                  label: 'Sign in with GitHub',
                  imagePath: 'images/github_logo2.png',
                  onPressed: _loginWithGitHub,
                ),
                const SizedBox(height: 26),

                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushNamed(SignupScreen.routeName);
                    },
                    child: RichText(
                      text: const TextSpan(
                        text: "Don't have an account? ",
                        style: TextStyle(color: Colors.white38, fontSize: 14),
                        children: [
                          TextSpan(
                            text: 'Sign up',
                            style: TextStyle(
                              color: _purple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // top branding area with title, subtitle and small neon icons
  Widget _buildBranding({required String title, required String subtitle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _purple,
                  boxShadow: [
                    BoxShadow(color: _purple, blurRadius: 12, spreadRadius: 2),
                  ],
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontFamily: 'CaveatBrush',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 4.5,
                  height: 0.95,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 14,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 105,
          height: 90,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                right: 8,
                child: _buildDoodleIcon(
                  icon: Icons.star_rounded,
                  size: 48,
                  rotation: -0.25,
                ),
              ),
              Positioned(
                top: 20,
                left: 8,
                child: _buildDoodleIcon(
                  icon: Icons.favorite_border_rounded,
                  size: 46,
                  rotation: 0.18,
                ),
              ),
              Positioned(
                bottom: 8,
                right: 4,
                child: _buildDoodleIcon(
                  icon: Icons.auto_awesome_rounded,
                  size: 32,
                  rotation: -0.10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // small rotated neon icon used in the branding section
  Widget _buildDoodleIcon({
    required IconData icon,
    required double size,
    required double rotation,
  }) {
    return Transform.rotate(
      angle: rotation,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: _purple.withValues(alpha: 0.45),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(icon, color: _purple, size: size),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      ),
    );
  }

  // reusable text field so email and password fields look consistent
  Widget _buildTextField({
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    required void Function(String?) onSaved,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 15),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: _fieldBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _purple, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _pink),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _pink, width: 1.5),
        ),
        errorStyle: const TextStyle(color: _pink, fontSize: 12),
      ),
      onSaved: onSaved,
      validator: validator,
    );
  }

  // main gradient button used for email/password login
  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_purple, _darkPurple],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }

  // reusable button for google and github sign in
  Widget _buildSocialButton({
    required String label,
    required String imagePath,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(imagePath, width: 22, height: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // visual divider between email login and social login
  Widget _buildDivider() {
    return Row(
      children: const [
        Expanded(child: Divider(color: Colors.white12, thickness: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or',
            style: TextStyle(color: Colors.white30, fontSize: 13),
          ),
        ),
        Expanded(child: Divider(color: Colors.white12, thickness: 1)),
      ],
    );
  }
}
