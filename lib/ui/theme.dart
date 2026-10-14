import 'package:flutter/material.dart';

/// "Remove Before Flight" placard palette. Hand-built — no `fromSeed`.
///
/// Light: placard white surface, panel-black text, RBF-tag red primary,
/// panel grey secondary. Dark: panel #15181B, text #ECEDEE, red #FF5A5F.
/// Status always pairs a colour with text and an icon, never colour alone.
class Rbf {
  const Rbf._();

  static const placardWhite = Color(0xFFF7F7F4);
  static const panelBlack = Color(0xFF1B1D1F);
  static const tagRed = Color(0xFFC1121F);
  static const panelGrey = Color(0xFF3A3F44);
  static const goGreen = Color(0xFF2B8A3E);
  static const caution = Color(0xFFE09F00);

  static const darkPanel = Color(0xFF15181B);
  static const darkText = Color(0xFFECEDEE);
  static const darkRed = Color(0xFFFF5A5F);

  /// The one corner radius used everywhere.
  static const double radius = 6;
  static const BorderRadius corners = BorderRadius.all(Radius.circular(radius));
}

/// Bundled font families (assets/fonts, SIL OFL 1.1).
class AppFonts {
  const AppFonts._();
  static const heading = 'SofiaSansCondensed';
  static const body = 'SofiaSans';
  static const mono = 'FiraMono';
}

/// Text styles with the GoogleFonts-style named arguments the tool screens
/// were written against, now on the bundled families.
class AppType {
  const AppType._();

  static TextStyle condensed({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    TextDecoration? decoration,
  }) =>
      TextStyle(
        fontFamily: AppFonts.heading,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        fontStyle: fontStyle,
        decoration: decoration,
      );

  static TextStyle sans({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    TextDecoration? decoration,
  }) =>
      TextStyle(
        fontFamily: AppFonts.body,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        fontStyle: fontStyle,
        decoration: decoration,
      );

  static TextStyle mono({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    TextDecoration? decoration,
  }) =>
      TextStyle(
        fontFamily: AppFonts.mono,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        fontStyle: fontStyle,
        decoration: decoration,
      );
}

const ColorScheme rbfLightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Rbf.tagRed,
  onPrimary: Colors.white,
  primaryContainer: Color(0xFFF6D9DB),
  onPrimaryContainer: Color(0xFF5A0A10),
  secondary: Rbf.panelGrey,
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFDFE1E3),
  onSecondaryContainer: Rbf.panelBlack,
  tertiary: Rbf.goGreen,
  onTertiary: Colors.white,
  error: Rbf.tagRed,
  onError: Colors.white,
  surface: Rbf.placardWhite,
  onSurface: Rbf.panelBlack,
  onSurfaceVariant: Color(0xFF4A4F54),
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: Color(0xFFF1F1EE),
  surfaceContainer: Color(0xFFEBEBE7),
  surfaceContainerHigh: Color(0xFFE4E4E0),
  surfaceContainerHighest: Color(0xFFDDDDD8),
  outline: Color(0xFF7C8186),
  outlineVariant: Color(0xFFCFD0CC),
  inverseSurface: Rbf.panelBlack,
  onInverseSurface: Rbf.placardWhite,
  inversePrimary: Rbf.darkRed,
  shadow: Colors.black,
  scrim: Colors.black,
);

const ColorScheme rbfDarkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Rbf.darkRed,
  onPrimary: Rbf.panelBlack,
  primaryContainer: Color(0xFF5A1418),
  onPrimaryContainer: Color(0xFFFFD9DA),
  secondary: Color(0xFFB9BEC3),
  onSecondary: Rbf.panelBlack,
  secondaryContainer: Rbf.panelGrey,
  onSecondaryContainer: Rbf.darkText,
  tertiary: Color(0xFF5CC277),
  onTertiary: Rbf.panelBlack,
  error: Rbf.darkRed,
  onError: Rbf.panelBlack,
  surface: Rbf.darkPanel,
  onSurface: Rbf.darkText,
  onSurfaceVariant: Color(0xFFB9BEC3),
  surfaceContainerLowest: Color(0xFF101315),
  surfaceContainerLow: Rbf.panelBlack,
  surfaceContainer: Color(0xFF202326),
  surfaceContainerHigh: Color(0xFF272B2F),
  surfaceContainerHighest: Color(0xFF2F3337),
  outline: Color(0xFF8B9096),
  outlineVariant: Color(0xFF3A3F44),
  inverseSurface: Rbf.darkText,
  onInverseSurface: Rbf.panelBlack,
  inversePrimary: Rbf.tagRed,
  shadow: Colors.black,
  scrim: Colors.black,
);

ThemeData buildRbfTheme(Brightness brightness, {TargetPlatform? platform}) {
  final scheme = brightness == Brightness.light ? rbfLightScheme : rbfDarkScheme;
  const shape = RoundedRectangleBorder(borderRadius: Rbf.corners);
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    platform: platform,
    fontFamily: AppFonts.body,
    scaffoldBackgroundColor: scheme.surface,
  );
  TextStyle h(TextStyle? s, {FontWeight w = FontWeight.w700}) =>
      (s ?? const TextStyle()).copyWith(fontFamily: AppFonts.heading, fontWeight: w);
  final t = base.textTheme;
  return base.copyWith(
    textTheme: t.copyWith(
      displayLarge: h(t.displayLarge),
      displayMedium: h(t.displayMedium),
      displaySmall: h(t.displaySmall),
      headlineLarge: h(t.headlineLarge),
      headlineMedium: h(t.headlineMedium),
      headlineSmall: h(t.headlineSmall),
      titleLarge: h(t.titleLarge),
      titleMedium: h(t.titleMedium, w: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: AppFonts.heading,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
        letterSpacing: 0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLowest,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: Rbf.corners,
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: Rbf.corners,
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: Rbf.corners,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: Rbf.corners,
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: shape,
        textStyle: const TextStyle(
            fontFamily: AppFonts.heading,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 0.4),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: shape,
        elevation: 0,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: shape),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: shape),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: shape,
      labelStyle: const TextStyle(fontFamily: AppFonts.body),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: shape,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: shape,
      labelTextStyle: const WidgetStatePropertyAll(TextStyle(
          fontFamily: AppFonts.heading,
          fontWeight: FontWeight.w600,
          fontSize: 13)),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorColor: scheme.primary,
      labelStyle: const TextStyle(
          fontFamily: AppFonts.heading,
          fontWeight: FontWeight.w700,
          fontSize: 15),
      unselectedLabelStyle:
          const TextStyle(fontFamily: AppFonts.heading, fontSize: 15),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: shape,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(
          fontFamily: AppFonts.body, color: scheme.onInverseSurface),
    ),
    dialogTheme: const DialogThemeData(shape: shape),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Rbf.radius))),
    ),
    listTileTheme: const ListTileThemeData(shape: shape),
  );
}

/// The kit tools (E6B, W&B, fuel, planner, checklists, documents, charts)
/// keep their instrument-panel look: they always render on the dark panel.
class PanelTheme extends StatelessWidget {
  const PanelTheme({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildRbfTheme(Brightness.dark, platform: Theme.of(context).platform),
      child: child,
    );
  }
}
