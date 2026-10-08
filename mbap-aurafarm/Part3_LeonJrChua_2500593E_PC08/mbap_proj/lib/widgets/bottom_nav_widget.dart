import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/user_provider.dart';
import '../theme/aura_theme.dart';

// bottom nav used across the main app pages.
// reads the chosen Aura palette so switching it recolours the whole app.
class BottomNavWidget extends ConsumerWidget {
  final int selectedIndex;

  const BottomNavWidget({super.key, required this.selectedIndex});

  // dark glass colour scheme
  static const Color _navBackground = Color(0xF2140B1F);
  static const Color _activePink = Color(0xFFFF4FD8);
  static const Color _inactive = Color(0xFFBBA8C9);
  static const Color _border = Color(0x26FFFFFF);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // App Personalisation - the live accent for the selected palette
    final Color accent = AuraTheme.seed(ref.watch(auraPaletteProvider));

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            color: _navBackground,
            borderRadius: BorderRadius.circular(38),
            border: Border.all(color: _border, width: 1.1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.40),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: accent.withValues(alpha: 0.22),
                blurRadius: 30,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              _navItem(
                accent,
                context,
                icon: Icons.home_rounded,
                label: 'Home',
                index: 0,
                routeName: '/home',
              ),
              _navCreate(context, accent),
              _navItem(
                accent,
                context,
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                index: 2,
                routeName: '/profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // normal nav items for home and profile
  Widget _navItem(
    Color accent,
    BuildContext context, {
    required IconData icon,
    required String label,
    required int index,
    required String routeName,
  }) {
    final bool isSelected = selectedIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (isSelected) {
            return;
          }

          Navigator.of(context).pushReplacementNamed(routeName);
        },
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: isSelected ? 84 : 74,
            height: 58,
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.transparent,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_activePink, accent],
                    ).createShader(bounds);
                  },
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : _inactive,
                    size: isSelected ? 28 : 25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : _inactive.withValues(alpha: 0.78),
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // middle create button since it is the main action  // middle create button since it is the main action
  Widget _navCreate(BuildContext context, Color accent) {
    final bool isSelected = selectedIndex == 1;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (isSelected) {
            return;
          }

          Navigator.of(context).pushReplacementNamed('/create');
        },
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: 84,
            height: 60,
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  width: isSelected ? 42 : 40,
                  height: isSelected ? 42 : 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isSelected
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_activePink, accent],
                          )
                        : null,
                    color: isSelected
                        ? null
                        : Colors.white.withValues(alpha: 0.08),
                    border: Border.all(
                      color: isSelected
                          ? Colors.white
                          : _inactive.withValues(alpha: 0.65),
                      width: isSelected ? 2.0 : 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: _activePink.withValues(alpha: 0.30),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: accent.withValues(alpha: 0.28),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : [],
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: isSelected ? Colors.white : _inactive,
                    size: isSelected ? 28 : 26,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Create',
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : _inactive.withValues(alpha: 0.78),
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: 0.1,
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
