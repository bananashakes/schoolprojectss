import 'package:flutter/material.dart';

// App Personalisation - the AuraFarm theme system.
// each palette recolours the whole app through MaterialApp's ThemeData,
// and the user's choice is stored in their firestore profile so it
// follows the account across devices.
enum AuraPalette { neonPurple, hotPink, cyberCyan, goldenHour, iceBlue }

class AuraTheme {
  // display names shown in the settings picker
  static String label(AuraPalette palette) {
    switch (palette) {
      case AuraPalette.neonPurple:
        return 'Neon Purple';
      case AuraPalette.hotPink:
        return 'Hot Pink';
      case AuraPalette.cyberCyan:
        return 'Cyber Cyan';
      case AuraPalette.goldenHour:
        return 'Golden Hour';
      case AuraPalette.iceBlue:
        return 'Ice Blue';
    }
  }

  // the accent colour that defines each palette
  static Color seed(AuraPalette palette) {
    switch (palette) {
      case AuraPalette.neonPurple:
        return const Color(0xFF8B5CF6);
      case AuraPalette.hotPink:
        return const Color(0xFFFF2D78);
      case AuraPalette.cyberCyan:
        return const Color(0xFF03DAC6);
      case AuraPalette.goldenHour:
        return const Color(0xFFFFAA00);
      case AuraPalette.iceBlue:
        // pale enough to read as ice, dark enough that the white button
        // labels sitting on it stay legible
        return const Color(0xFF7EB0E0);
    }
  }

  // page background for each palette, kept dark enough for the white
  // body text used across the app
  static Color background(AuraPalette palette) {
    switch (palette) {
      case AuraPalette.neonPurple:
        return const Color(0xFF0B0714);
      case AuraPalette.hotPink:
        return const Color(0xFF150710);
      case AuraPalette.cyberCyan:
        return const Color(0xFF03130F);
      case AuraPalette.goldenHour:
        return const Color(0xFF150F04);
      case AuraPalette.iceBlue:
        // the lightest of the five, a cool slate rather than near-black
        return const Color(0xFF141C28);
    }
  }

  // finds the palette saved in firestore by its name, falling back to
  // the default when the stored value is missing or unknown
  static AuraPalette fromName(String? name) {
    for (final AuraPalette palette in AuraPalette.values) {
      if (palette.name == name) {
        return palette;
      }
    }

    return AuraPalette.neonPurple;
  }

  // builds the dark ThemeData used by MaterialApp for this palette
  static ThemeData build(AuraPalette palette) {
    final Color accent = seed(palette);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        primary: accent,
      ),
      // every screen leaves its Scaffold background unset so it inherits
      // this, which is what lets one setting recolour the whole app
      scaffoldBackgroundColor: background(palette),

      // shared component styling so the accent shows up everywhere
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1B1224),
        contentTextStyle: const TextStyle(color: Colors.white),
        actionTextColor: accent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent;
          }
          return const Color(0xFF9090AA);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent.withValues(alpha: 0.45);
          }
          return const Color(0xFF2A2A3A);
        }),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: 0.35),
        selectionHandleColor: accent,
      ),
    );
  }
}
