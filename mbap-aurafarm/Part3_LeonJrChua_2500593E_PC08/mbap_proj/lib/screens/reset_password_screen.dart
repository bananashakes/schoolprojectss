import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/firebase_provider.dart';
import '../widgets/aura_snack_bar.dart';
import '../widgets/validators.dart';
import 'login_screen.dart';

// screen for sending a firebase password reset email // class is a blueprint for creating a widget or object
class ResetPasswordScreen extends ConsumerStatefulWidget {
  static const String routeName = '/reset';

  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

// ConsumerStatefulWidget means this page has changing state and can use Riverpod
class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  // form key lets the email field validate before firebase is called
  final _formKey = GlobalKey<FormState>();

  String? _email;
  bool _isLoading = false;

  static const _fieldBg = Color(0xFF1E1535);
  static const _purple = Color(0xFF8B5CF6);
  static const _darkPurple = Color(0xFF6D28D9);
  static const _pink = Color(0xFFFF2D78);

  // reusable styled snackbar for firebase results
  void _showResetSnackBar(
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

  // runs when user presses send reset email
  // Future<void> means it completes later but does not return any value async means this function can wait for tasks that take time
  Future<void> _resetPassword() async {
    // email format errors appear under the text field
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _formKey.currentState!.save();
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      // gets firebase service using riverpod
      final firebaseService = ref.read(firebaseServiceProvider);

      // asks firebase to send reset password link to the email  await pauses this function until the Future finishes
      await firebaseService.forgotPassword(_email!);

      if (!mounted) {
        return;
      }

      _showResetSnackBar(
        'Password reset email sent. Check your inbox.',
        icon: Icons.mark_email_read_outlined,
        color: _purple,
      );

      // small delay so the user can see the success message
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) {
        return;
      }

      _goBackToLogin();
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      // firebase errors happen after submit, so they use snackbar
      _showResetSnackBar(
        _friendlyError(e.code),
        icon: Icons.error_outline_rounded,
        color: _pink,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showResetSnackBar(
        'Reset failed. Please try again.',
        icon: Icons.error_outline_rounded,
        color: _pink,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // returns to login screen void means this function performs an action but does not return any value
  void _goBackToLogin() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
    }
  }

  // changes firebase error codes into simpler messages String means this value stores text
  String _friendlyError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Reset failed. Please try again.';
    }
  }

  // @override means this method replaces a method from the parent class
  @override
  Widget build(BuildContext context) {
    // BuildContext tells Flutter where this widget is in the widget tree
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
                const SizedBox(height: 42),

                _buildBackButton(),
                const SizedBox(height: 32),

                _buildBranding(
                  title: 'Reset Password',
                  subtitle: 'Enter your email and we will send a reset link.',
                ),
                const SizedBox(height: 44),

                _buildInfoBox(),
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
                const SizedBox(height: 32),

                _buildPrimaryButton(
                  label: 'Send Reset Email',
                  isLoading: _isLoading,
                  onPressed: _resetPassword,
                ),
                const SizedBox(height: 24),

                Center(
                  child: GestureDetector(
                    onTap: _goBackToLogin,
                    child: const Text(
                      'Back to login',
                      style: TextStyle(
                        color: _purple,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: _goBackToLogin,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white54,
            size: 16,
          ),
          SizedBox(width: 6),
          Text('Back', style: TextStyle(color: Colors.white54, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildBranding({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(bottom: 10),
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
            fontSize: 34,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 14,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _fieldBg.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: _purple, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Use the same email you used to create your AuraFarm account.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
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

  // reusable text field so auth screens look consistent
  Widget _buildTextField({
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    required void Function(String?) onSaved,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 15),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
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

  Widget _buildPrimaryButton({
    required String label,
    required bool isLoading,
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
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
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
}
