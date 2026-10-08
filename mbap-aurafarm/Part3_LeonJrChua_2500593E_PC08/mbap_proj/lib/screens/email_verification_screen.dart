import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/firebase_provider.dart';
import '../services/firebase_service.dart';
import '../widgets/aura_snack_bar.dart';

// screen for sending and checking email verification
class EmailVerificationScreen extends ConsumerStatefulWidget {
  static const String routeName = '/email-verification';

  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  bool _isVerified = false;
  bool _isLoading = true;
  bool _isSending = false;

  static const _cardDark = Color(0xFF12121A);
  static const _neonPurple = Color(0xFFBB86FC);
  static const _textPrimary = Color(0xFFF0F0FF);
  static const _textSecondary = Color(0xFF9090AA);
  static const _divider = Color(0xFF2A2A3A);
  static const _success = Color(0xFF4ADE80);
  static const _danger = Color(0xFFCF6679);

  @override
  void initState() {
    super.initState();

    // checks verification status when the screen first opens
    _checkVerificationStatus();
  }

  // reusable styled snackbar for firebase results
  void _showVerifySnackBar(
    String message, {
    IconData icon = Icons.info_outline_rounded,
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

  // checks if the current user's email has been verified
  Future<void> _checkVerificationStatus() async {
    final FirebaseService firebaseService = ref.read(firebaseServiceProvider);

    try {
      bool verified = await firebaseService.isEmailVerified();

      if (!mounted) {
        return;
      }

      setState(() {
        _isVerified = verified;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      _showVerifySnackBar(
        'Could not check email status.',
        icon: Icons.error_outline_rounded,
        color: _danger,
      );
    }
  }

  // sends verification email to the current user
  Future<void> _sendVerificationEmail() async {
    setState(() {
      _isSending = true;
    });

    try {
      final FirebaseService firebaseService = ref.read(firebaseServiceProvider);

      await firebaseService.sendEmailVerification();

      if (!mounted) {
        return;
      }

      _showVerifySnackBar(
        'Verification email sent. Check your inbox.',
        icon: Icons.mark_email_read_outlined,
        color: _neonPurple,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      _showVerifySnackBar(
        _verificationError(e.code),
        icon: Icons.error_outline_rounded,
        color: _danger,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showVerifySnackBar(
        'Verification email could not be sent.',
        icon: Icons.error_outline_rounded,
        color: _danger,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  // user presses this after clicking the email link
  Future<void> _refreshStatus() async {
    setState(() {
      _isLoading = true;
    });

    await _checkVerificationStatus();

    if (!mounted) {
      return;
    }

    if (_isVerified) {
      _showVerifySnackBar(
        'Email verified successfully.',
        icon: Icons.verified_rounded,
        color: _success,
      );
    } else {
      _showVerifySnackBar(
        'Email is not verified yet. Try again after clicking the link.',
        icon: Icons.info_outline_rounded,
        color: _neonPurple,
      );
    }
  }

  // firebase error messages for this screen only
  String _verificationError(String code) {
    if (code == 'too-many-requests') {
      return 'Too many attempts. Please try again later.';
    }

    if (code == 'no-current-user') {
      return 'No user is currently logged in.';
    }

    if (code == 'user-token-expired') {
      return 'Session expired. Please log in again.';
    }

    return 'Verification email could not be sent.';
  }

  @override
  Widget build(BuildContext context) {
    final FirebaseService firebaseService = ref.read(firebaseServiceProvider);
    final String email = firebaseService.getCurrentUserEmail();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        iconTheme: const IconThemeData(color: _textPrimary),
        title: const Text(
          'Email Verification',
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _cardDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _divider),
              ),
              child: Column(
                children: [
                  Icon(
                    _isVerified
                        ? Icons.verified_rounded
                        : Icons.mark_email_unread_outlined,
                    color: _isVerified ? _success : _neonPurple,
                    size: 50,
                  ),
                  const SizedBox(height: 14),

                  Text(
                    _isVerified ? 'Email Verified' : 'Verify Your Email',
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    email,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _neonPurple,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    _isVerified
                        ? 'Your account email has already been verified.'
                        : 'We will send a verification link to your email. After clicking the link, come back and press Check Status.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_isLoading)
                    const CircularProgressIndicator(color: _neonPurple)
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isVerified || _isSending
                            ? null
                            : _sendVerificationEmail,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _neonPurple,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _divider,
                          disabledForegroundColor: _textSecondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: _isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(
                          _isSending
                              ? 'Sending...'
                              : _isVerified
                              ? 'Already Verified'
                              : 'Send Verification Email',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _refreshStatus,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _textPrimary,
                          side: const BorderSide(color: _divider),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text(
                          'Check Status',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 18),

            // small info card so the page does not feel too empty
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardDark,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _divider),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, color: _neonPurple, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Why verify?',
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Email verification helps protect your AuraFarm account and confirms that the email can be used for account recovery.',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
