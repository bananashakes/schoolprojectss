import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/firebase_provider.dart';
import '../widgets/aura_snack_bar.dart';
import '../widgets/validators.dart';

// screen for changing email/password account password
class ChangePasswordScreen extends ConsumerStatefulWidget {
  static const String routeName = '/change-password';

  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  // form key validates all password fields together
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;

  static const _cardDark = Color(0xFF12121A);
  static const _surface = Color(0xFF1A1A26);
  static const _neonPurple = Color(0xFFBB86FC);
  static const _textPrimary = Color(0xFFF0F0FF);
  static const _textSecondary = Color(0xFF9090AA);
  static const _divider = Color(0xFF2A2A3A);
  static const _danger = Color(0xFFCF6679);

  @override
  void dispose() {
    // dispose controllers to prevent memory leaks
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // firebase error messages for this screen only
  String _changePasswordError(String code) {
    if (code == 'wrong-password' || code == 'invalid-credential') {
      return 'Current password is incorrect.';
    }

    if (code == 'weak-password') {
      return 'New password is too weak.';
    }

    if (code == 'not-password-user') {
      return 'Password can only be changed for email/password accounts.';
    }

    return 'Password change failed. Please try again.';
  }

  // reusable styled snackbar for firebase results
  void _showPasswordSnackBar(
    String message, {
    IconData icon = Icons.check_circle_outline_rounded,
    Color color = _neonPurple,
  }) {
    showAuraSnackBar(
      context,
      message,
      icon: icon,
      backgroundColor: _cardDark,
      iconColor: color,
      borderColor: color,
      textColor: _textPrimary,
      borderOpacity: 0.45,
      shadowColor: color,
      shadowOpacity: 0.22,
      blurRadius: 18,
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 20),
    );
  }

  // submits the change password form
  Future<void> _submitChangePassword() async {
    FocusScope.of(context).unfocus();

    // input errors appear under the text fields
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // gets firebase service using riverpod
      final firebaseService = ref.read(firebaseServiceProvider);

      // firebase checks current password first, then updates to new password
      await firebaseService.changePassword(
        _currentPasswordController.text,
        _newPasswordController.text,
      );

      if (!mounted) {
        return;
      }

      _showPasswordSnackBar(
        'Password changed successfully.',
        icon: Icons.lock_reset_rounded,
        color: _neonPurple,
      );

      // small delay so the success message can be seen before going back
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      _showPasswordSnackBar(
        _changePasswordError(e.code),
        icon: Icons.error_outline_rounded,
        color: _danger,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showPasswordSnackBar(
        'Password change failed. Please try again.',
        icon: Icons.error_outline_rounded,
        color: _danger,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _textSecondary),
      filled: true,
      fillColor: _surface,
      errorMaxLines: 2,
      errorStyle: const TextStyle(color: _danger, fontSize: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _neonPurple),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _danger),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        iconTheme: const IconThemeData(color: _textPrimary),
        title: const Text(
          'Change Password',
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _cardDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _divider),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    color: _neonPurple,
                    size: 42,
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    'Update your password',
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),

                  const Text(
                    'Enter your current password first so Firebase can confirm it is you.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),

                  TextFormField(
                    controller: _currentPasswordController,
                    obscureText: true,
                    keyboardType: TextInputType.visiblePassword,
                    style: const TextStyle(color: _textPrimary),
                    decoration: _buildInputDecoration('Current password'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter your current password.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: true,
                    keyboardType: TextInputType.visiblePassword,
                    style: const TextStyle(color: _textPrimary),
                    decoration: _buildInputDecoration('New password'),
                    validator: Validation.password,
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    keyboardType: TextInputType.visiblePassword,
                    style: const TextStyle(color: _textPrimary),
                    decoration: _buildInputDecoration('Confirm new password'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Confirm your new password.';
                      }

                      if (value.length < 6) {
                        return 'Password must be at least 6 characters.';
                      }

                      // shows mismatch error under confirm password field
                      if (value != _newPasswordController.text) {
                        return 'Passwords do not match.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 22),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitChangePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _neonPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _isLoading ? 'Updating...' : 'Update Password',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
