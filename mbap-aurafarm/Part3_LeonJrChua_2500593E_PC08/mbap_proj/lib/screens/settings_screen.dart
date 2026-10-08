import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/biometric_provider.dart';
import '../providers/firebase_provider.dart';
import '../providers/user_provider.dart';
import '../theme/aura_theme.dart';
import '../services/firebase_service.dart';
import '../widgets/aura_snack_bar.dart';
import 'change_password_screen.dart';
import 'email_verification_screen.dart';

// settings page for account, privacy, notifications and logout
class SettingsScreen extends ConsumerStatefulWidget {
  static const String routeName = '/settings';

  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _cardDark = Color(0xFF12121A);
  static const _surface = Color(0xFF1A1A26);
  static const _neonPurple = Color(0xFFBB86FC);

  // App Personalisation - live accent for the chosen Aura palette
  Color get _accent => AuraTheme.seed(ref.watch(auraPaletteProvider));
  static const _textPrimary = Color(0xFFF0F0FF);
  static const _textSecondary = Color(0xFF9090AA);
  static const _divider = Color(0xFF2A2A3A);
  static const _danger = Color(0xFFCF6679);

  // toggle states, loaded from and saved to the user's firestore profile
  bool _notificationsEnabled = true;
  bool _privateAccount = false;
  bool _showAuraLevel = true;
  bool _didSyncToggles = false;

  // writes one toggle to the users collection so it survives restarts
  Future<void> _saveToggle(String field, bool value) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    try {
      await ref.read(userServiceProvider).updateSetting(user.uid, field, value);
    } catch (error) {
      if (!mounted) return;

      _showMessage(ref.read(userServiceProvider).getErrorMessage(error));
    }
  }

  bool _isLoggingOut = false;

  // biometric lock state (additional feature, mobile only)
  bool _biometricSupported = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  // finds out whether this device has a fingerprint sensor and
  // whether the user already switched the lock on
  Future<void> _loadBiometricState() async {
    final service = ref.read(biometricServiceProvider);

    final bool supported = await service.isSupported();
    final bool enabled = await service.isLockEnabled();

    if (!mounted) return;

    setState(() {
      _biometricSupported = supported;
      _biometricEnabled = enabled;
    });
  }

  // turns the biometric lock on or off.
  // enabling requires one successful scan first, so the user cannot lock
  // themselves out with a sensor that does not work.
  Future<void> _toggleBiometricLock(bool value) async {
    final service = ref.read(biometricServiceProvider);

    if (value) {
      final bool passed = await service.authenticate(
        'Confirm your fingerprint to enable the biometric lock',
      );

      if (!mounted) return;

      if (!passed) {
        _showMessage('Scan failed. Biometric lock stays off.');
        return;
      }
    }

    await service.setLockEnabled(value);

    // the auth gate in main.dart watches this provider
    ref.invalidate(biometricLockEnabledProvider);

    if (!mounted) return;

    setState(() {
      _biometricEnabled = value;
    });

    _showMessage(
      value ? 'Biometric lock enabled 🔒' : 'Biometric lock disabled',
    );
  }

  // logs out the current user
  Future<void> _logout() async {
    if (_isLoggingOut) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      final FirebaseService firebaseService = ref.read(firebaseServiceProvider);

      await firebaseService.logOut();

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoggingOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logout failed. Please try again.')),
      );
    }
  }

  // opens the logout confirmation dialog
  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _danger.withValues(alpha: 0.3)),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: _danger, size: 22),
            SizedBox(width: 10),
            Text(
              'Log Out?',
              style: TextStyle(
                color: _textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: const Text(
          'You\'ll need to log back in to access your Vibe Cards and Aura Feed.',
          style: TextStyle(color: _textSecondary, fontSize: 13, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: _textPrimary,
                side: const BorderSide(color: _divider),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Stay Logged In'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _logout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
              child: const Text(
                'Log Out',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // shows a temporary placeholder message for unfinished features
  // App Personalisation - row of palette swatches.
  // tapping one saves it to the user's firestore profile, which recolours
  // the whole app live through the theme in main.dart.
  Widget _buildThemePicker() {
    final AuraPalette current = ref.watch(auraPaletteProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aura Palette',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Recolours the whole app. Saved to your account.',
            style: TextStyle(color: _textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 14),
          // Wrap so the swatches drop to a second line on narrow phones
          Wrap(
            spacing: 8,
            runSpacing: 12,
            children: AuraPalette.values.map((palette) {
              final Color color = AuraTheme.seed(palette);
              final bool selected = palette == current;

              return GestureDetector(
                onTap: () => _pickTheme(palette),
                child: SizedBox(
                  width: 56,
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(
                                alpha: selected ? 0.55 : 0.2,
                              ),
                              blurRadius: selected ? 16 : 8,
                            ),
                          ],
                        ),
                        child: selected
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 24,
                              )
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AuraTheme.label(palette),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                          color: selected ? _textPrimary : _textSecondary,
                          fontSize: 10,
                          height: 1.25,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // writes the picked palette to the users collection
  Future<void> _pickTheme(AuraPalette palette) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('Please log in first.');
      return;
    }

    try {
      await ref
          .read(userServiceProvider)
          .setThemePalette(user.uid, palette.name);

      if (!mounted) return;

      _showMessage('${AuraTheme.label(palette)} aura equipped ✨');
    } catch (error) {
      if (!mounted) return;

      _showMessage(ref.read(userServiceProvider).getErrorMessage(error));
    }
  }

  // generic styled snackbar used by the database actions
  void _showMessage(String message) {
    showAuraSnackBar(
      context,
      message,
      icon: Icons.storage_rounded,
      backgroundColor: _cardDark,
      iconColor: _accent,
      borderColor: _accent,
      textColor: _textPrimary,
      borderOpacity: 0.4,
      shadowColor: _accent,
      shadowOpacity: 0.15,
      blurRadius: 18,
      spreadRadius: 1,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
    );
  }

  void _showComingSoon(String feature) {
    showAuraSnackBar(
      context,
      '$feature coming soon ✦',
      icon: Icons.construction_rounded,
      backgroundColor: _cardDark,
      iconColor: _accent,
      borderColor: _accent,
      textColor: _textPrimary,
      borderOpacity: 0.4,
      shadowColor: _accent,
      shadowOpacity: 0.15,
      blurRadius: 18,
      spreadRadius: 1,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
    );
  }

  @override
  Widget build(BuildContext context) {
    // loads the saved toggle values once when the profile arrives
    final profile = ref.watch(currentUserProfileProvider).value;

    if (!_didSyncToggles && profile != null) {
      _didSyncToggles = true;
      _notificationsEnabled = profile.notificationsEnabled;
      _privateAccount = profile.privateAccount;
      _showAuraLevel = profile.showAuraLevel;
    }

    return Scaffold(
      appBar: _buildAppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          _buildSectionLabel('Account'),
          _buildSettingsGroup([
            _buildNavTile(
              icon: Icons.person_outline_rounded,
              iconColor: _accent,
              title: 'Edit Profile',
              onTap: () {
                // the working edit form lives on the profile screen
                Navigator.of(context).pushNamed('/profile');
              },
            ),
            _buildDivider(),
            _buildNavTile(
              icon: Icons.lock_outline_rounded,
              iconColor: _accent,
              title: 'Change Password',
              onTap: () {
                Navigator.of(context).pushNamed(ChangePasswordScreen.routeName);
              },
            ),
            _buildDivider(),
            _buildNavTile(
              icon: Icons.verified_user_outlined,
              iconColor: _accent,
              title: 'Email Verification',
              onTap: () {
                Navigator.of(
                  context,
                ).pushNamed(EmailVerificationScreen.routeName);
              },
            ),
          ]),
          const SizedBox(height: 24),
          _buildSectionLabel('App Theme'),
          _buildSettingsGroup([_buildThemePicker()]),
          const SizedBox(height: 24),
          _buildSectionLabel('Privacy'),
          _buildSettingsGroup([
            // only devices with a sensor see this toggle; web never does
            if (_biometricSupported) ...[
              _buildToggleTile(
                icon: Icons.fingerprint_rounded,
                iconColor: _accent,
                title: 'Biometric Lock',
                subtitle: 'Require your fingerprint to open the app',
                value: _biometricEnabled,
                onChanged: _toggleBiometricLock,
              ),
              _buildDivider(),
            ],
            _buildToggleTile(
              icon: Icons.lock_person_outlined,
              iconColor: _accent,
              title: 'Private Account',
              subtitle: 'Only followers can see your Vibe Cards',
              value: _privateAccount,
              onChanged: (val) {
                setState(() {
                  _privateAccount = val;
                });
                _saveToggle('privateAccount', val);
              },
            ),
            _buildDivider(),
            _buildToggleTile(
              icon: Icons.trending_up_rounded,
              iconColor: _accent,
              title: 'Show Aura Level',
              subtitle: 'Display your Aura Level on your profile',
              value: _showAuraLevel,
              onChanged: (val) {
                setState(() {
                  _showAuraLevel = val;
                });
                _saveToggle('showAuraLevel', val);
              },
            ),
            _buildDivider(),
            _buildNavTile(
              icon: Icons.block_rounded,
              iconColor: _accent,
              title: 'Blocked Users',
              onTap: () => _showComingSoon('Blocked Users'),
            ),
          ]),
          const SizedBox(height: 24),
          _buildSectionLabel('Notifications'),
          _buildSettingsGroup([
            _buildToggleTile(
              icon: Icons.notifications_outlined,
              iconColor: _accent,
              title: 'Push Notifications',
              subtitle: 'Likes, comments and new followers',
              value: _notificationsEnabled,
              onChanged: (val) {
                setState(() {
                  _notificationsEnabled = val;
                });
                _saveToggle('notificationsEnabled', val);
              },
            ),
          ]),
          const SizedBox(height: 24),
          _buildSectionLabel('About'),
          _buildSettingsGroup([
            _buildNavTile(
              icon: Icons.info_outline_rounded,
              iconColor: _textSecondary,
              title: 'App Version',
              trailing: const Text(
                'v1.0.0',
                style: TextStyle(color: _textSecondary, fontSize: 13),
              ),
              onTap: null,
            ),
            _buildDivider(),
            _buildNavTile(
              icon: Icons.shield_outlined,
              iconColor: _textSecondary,
              title: 'Privacy Policy',
              onTap: () => _showComingSoon('Privacy Policy'),
            ),
            _buildDivider(),
            _buildNavTile(
              icon: Icons.description_outlined,
              iconColor: _textSecondary,
              title: 'Terms of Service',
              onTap: () => _showComingSoon('Terms of Service'),
            ),
          ]),
          const SizedBox(height: 32),
          _buildLogoutButton(),
          const SizedBox(height: 16),
          _buildDeleteAccountButton(),
        ],
      ),
    );
  }

  // builds the top app bar with back navigation
  AppBar _buildAppBar() {
    return AppBar(
      elevation: 0,
      iconTheme: const IconThemeData(color: _textPrimary),
      title: const Text(
        'Settings',
        style: TextStyle(
          color: _textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  // builds the uppercase section title for each settings group
  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: _textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // builds a styled card container for related settings rows
  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _divider),
      ),
      child: Column(children: children),
    );
  }

  // builds a divider between settings rows
  Widget _buildDivider() {
    return const Divider(height: 1, color: Color(0xFF2A2A3A), indent: 52);
  }

  // builds a navigation row with icon, title and optional subtitle
  Widget _buildNavTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 17),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing ??
                (onTap != null
                    ? const Icon(
                        Icons.chevron_right_rounded,
                        color: _textSecondary,
                        size: 20,
                      )
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  // builds a toggle row with switch control
  Widget _buildToggleTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: _textSecondary, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: _neonPurple,
            activeTrackColor: _neonPurple.withValues(alpha: 0.3),
            inactiveThumbColor: _textSecondary,
            inactiveTrackColor: _surface,
          ),
        ],
      ),
    );
  }

  // builds the logout action button
  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _isLoggingOut ? null : _showLogoutConfirmation,
        style: OutlinedButton.styleFrom(
          foregroundColor: _danger,
          side: BorderSide(color: _danger.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: _isLoggingOut
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: _danger,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.logout_rounded, size: 20),
        label: Text(
          _isLoggingOut ? 'Logging out...' : 'Log Out',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // builds the delete account action link
  Widget _buildDeleteAccountButton() {
    return Center(
      child: GestureDetector(
        onTap: () => _showComingSoon('Delete Account'),
        child: const Text(
          'Delete Account',
          style: TextStyle(
            color: _textSecondary,
            fontSize: 12,
            decoration: TextDecoration.underline,
            decorationColor: Color(0xFF9090AA),
          ),
        ),
      ),
    );
  }
}
