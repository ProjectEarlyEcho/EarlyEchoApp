import 'package:flutter/material.dart';

/// Visual foundation for the EarlyEcho worker app.
///
/// The palette takes its cues from India — warm saffron for the primary
/// actions and a deep teal accent for supporting information. Text sizes and
/// tap targets are deliberately generous: the app is operated one-handed by
/// Anganwadi workers, often outdoors in bright sunlight.
class EarlyEchoTheme {
  EarlyEchoTheme._();

  // ── Light palette ──
  static const warmIvory = Color(0xFFFFF8F0);
  static const ink = Color(0xFF2B211A);
  static const deepSaffron = Color(0xFFB94615);
  static const saffronCream = Color(0xFFFFDCC2);
  static const deepTeal = Color(0xFF0F6E64);
  static const tealMist = Color(0xFFC7EFE8);
  static const leafGreen = Color(0xFF2E6B34);
  static const leafMist = Color(0xFFCDEDD0);
  static const warmLine = Color(0xFFEDDFCE);

  // ── Dark palette ──
  static const nightInk = Color(0xFF1A1512);
  static const nightSurface = Color(0xFF241E19);
  static const nightSurfaceHigh = Color(0xFF2E2721);
  static const nightText = Color(0xFFF6EFE8);
  static const nightMuted = Color(0xFFD2C4B6);
  static const darkSaffron = Color(0xFFFFB68C);
  static const darkTeal = Color(0xFF86D7C8);
  static const darkGreen = Color(0xFFA6D8AB);

  // ── Risk colours (result bands) ──
  static const riskGreen = Color(0xFF2E7D32);
  static const riskYellow = Color(0xFF9A6700);
  static const riskRed = Color(0xFFC0392B);

  /// Scales every text style up so instructions stay readable at arm's length.
  static const double _fontScaleFactor = 1.12;

  /// All tappable controls must clear this height (48dp minimum, rounded up).
  static const double _minTapTargetHeight = 52;

  static ThemeData get lightTheme => _buildTheme(
    scheme: const ColorScheme.light(
      primary: deepSaffron,
      onPrimary: Colors.white,
      primaryContainer: saffronCream,
      onPrimaryContainer: Color(0xFF562300),
      secondary: deepTeal,
      onSecondary: Colors.white,
      secondaryContainer: tealMist,
      onSecondaryContainer: Color(0xFF003731),
      tertiary: leafGreen,
      onTertiary: Colors.white,
      tertiaryContainer: leafMist,
      onTertiaryContainer: Color(0xFF0B3B14),
      error: Color(0xFFB3261E),
      onError: Colors.white,
      surface: Colors.white,
      onSurface: ink,
      surfaceContainerHighest: Color(0xFFFFF1E4),
      outline: Color(0xFFBCA795),
      outlineVariant: warmLine,
    ),
    scaffold: warmIvory,
    card: Colors.white,
    mutedText: const Color(0xFF7A6A5D),
  );

  static ThemeData get darkTheme => _buildTheme(
    scheme: const ColorScheme.dark(
      primary: darkSaffron,
      onPrimary: Color(0xFF562300),
      primaryContainer: Color(0xFF8A3A0F),
      onPrimaryContainer: Color(0xFFFFE0CC),
      secondary: darkTeal,
      onSecondary: Color(0xFF003731),
      secondaryContainer: Color(0xFF1F5A50),
      onSecondaryContainer: Color(0xFFD7F7F0),
      tertiary: darkGreen,
      onTertiary: Color(0xFF0B3B14),
      tertiaryContainer: Color(0xFF3B5E3F),
      onTertiaryContainer: Color(0xFFD9F2DC),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      surface: nightSurface,
      onSurface: nightText,
      surfaceContainerHighest: nightSurfaceHigh,
      outline: Color(0xFFB3A396),
      outlineVariant: Color(0xFF4A3F36),
    ),
    scaffold: nightInk,
    card: nightSurface,
    mutedText: nightMuted,
  );

  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required Color scaffold,
    required Color card,
    required Color mutedText,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      // Expands hit areas of small controls (chips, checkboxes) to 48dp.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
    );

    // Material's default text theme only carries colours — font sizes are
    // resolved later from a script-category geometry, which makes
    // TextTheme.apply(fontSizeFactor:) assert on the null sizes. Scaling the
    // 2021 geometry directly and merging it back over the colour styles (the
    // same merge ThemeData.localize performs) pins deterministic,
    // worker-readable sizes for every style.
    final geometry = Typography.englishLike2021.apply(
      fontSizeFactor: _fontScaleFactor,
    );
    final merged = geometry.merge(base.textTheme);
    final textTheme = merged.copyWith(
      displaySmall: merged.displaySmall?.copyWith(fontWeight: FontWeight.w800),
      headlineSmall: merged.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
      ),
      headlineMedium: merged.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
      ),
      titleLarge: merged.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      titleMedium: merged.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: merged.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: merged.bodyLarge?.copyWith(height: 1.4),
      bodyMedium: merged.bodyMedium?.copyWith(height: 1.4),
      bodySmall: merged.bodySmall?.copyWith(color: mutedText, height: 1.35),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 68,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        labelStyle: TextStyle(color: mutedText),
        hintStyle: TextStyle(color: mutedText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.7),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(_minTapTargetHeight),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(_minTapTargetHeight),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(_minTapTargetHeight, _minTapTargetHeight),
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(_minTapTargetHeight, _minTapTargetHeight),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 0,
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.surface,
        labelStyle: textTheme.labelLarge,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primaryContainer,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.onSurface,
        contentTextStyle: TextStyle(color: scheme.surface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        modalBackgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}
