import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/firebase_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/aura_snack_bar.dart';
import '../widgets/validators.dart';
import 'home_screen.dart';
import 'login_screen.dart';

// screen for creating a new aurafarm account
class SignupScreen extends ConsumerStatefulWidget {
  static const String routeName = '/signup';

  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  // form key lets all fields validate together
  final _formKey = GlobalKey<FormState>();

  // controller is needed so confirm password can compare with password
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String? _username;
  String? _email;
  String? _password;

  // local ui states for password visibility and loading button
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  static const _fieldBg = Color(0xFF1E1535);
  static const _purple = Color(0xFF8B5CF6);
  static const _darkPurple = Color(0xFF6D28D9);
  static const _pink = Color(0xFFFF2D78);

  @override
  void dispose() {
    // dispose controllers to prevent memory leaks
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // reusable styled snackbar for firebase results
  void _showSignupSnackBar(
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

  // runs when user presses sign up
  Future<void> _register() async {
    // input errors appear under the text fields
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

      // creates account in firebase authentication
      await firebaseService.register(_email!, _password!);

      // saves username into the firebase user profile
      await FirebaseAuth.instance.currentUser?.updateDisplayName(
        _username!.trim(),
      );

      // creates this user's document in the "users" collection
      // (the Users table from the Part 1 database design)
      final User? newUser = FirebaseAuth.instance.currentUser;

      if (newUser != null) {
        await ref
            .read(userServiceProvider)
            .ensureProfile(newUser, username: _username!.trim());
      }

      if (!mounted) {
        return;
      }

      _showSignupSnackBar(
        'Account created successfully!',
        icon: Icons.check_circle_rounded,
        color: _purple,
      );

      // firebase signs the user in after account creation
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(HomeScreen.routeName, (route) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      // firebase errors happen after submit, so they use snackbar
      _showSignupSnackBar(
        _friendlyError(e.code),
        icon: Icons.error_outline_rounded,
        color: _pink,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showSignupSnackBar(
        'Registration failed. Please try again.',
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

  // returns to login screen
  void _goBackToLogin() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
    }
  }

  // changes firebase error codes into simpler messages
  String _friendlyError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'operation-not-allowed':
        return 'Email/password sign up is not enabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Registration failed. Please try again.';
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
                const SizedBox(height: 42),

                _buildBackButton(),
                const SizedBox(height: 28),

                _buildBranding(
                  title: 'Create Aura',
                  subtitle: 'Join AuraFarm and start posting your vibe.',
                ),
                const SizedBox(height: 40),

                _buildLabel('Username'),
                const SizedBox(height: 8),
                _buildTextField(
                  hint: 'vibe.with.me',
                  icon: Icons.person_outline_rounded,
                  keyboardType: TextInputType.text,
                  onSaved: (value) {
                    _username = value!.trim();
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a username.';
                    }

                    if (value.trim().length < 3) {
                      return 'Username must be at least 3 characters.';
                    }

                    if (value.contains(' ')) {
                      return 'Username cannot contain spaces.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 20),

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
                  controller: _passwordController,
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
                const SizedBox(height: 20),

                _buildLabel('Confirm Password'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _confirmPasswordController,
                  hint: '••••••••',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscureConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.white38,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                  onSaved: (value) {},
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password.';
                    }

                    if (value.length < 6) {
                      return 'Password must be at least 6 characters.';
                    }

                    // shows mismatch error under confirm password field
                    if (value != _passwordController.text) {
                      return 'Passwords do not match.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 32),

                _buildPrimaryButton(
                  label: 'Sign Up',
                  isLoading: _isLoading,
                  onPressed: _register,
                ),
                const SizedBox(height: 24),

                Center(
                  child: GestureDetector(
                    onTap: _goBackToLogin,
                    child: RichText(
                      text: const TextSpan(
                        text: 'Already have an account? ',
                        style: TextStyle(color: Colors.white38, fontSize: 14),
                        children: [
                          TextSpan(
                            text: 'Login',
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

  // reusable text field so all signup fields look consistent
  Widget _buildTextField({
    TextEditingController? controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    required void Function(String?) onSaved,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
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
