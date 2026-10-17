import 'package:flutter/material.dart';

/// "Clear Skies" — PilotEnRoute's design language.
///
/// A calm, airy palette: a pale-sky canvas, white cards with soft shadows,
/// a deep-teal primary for actions and a navy ink for text. Hand-built — no
/// `fromSeed`. Status always pairs a colour with a word and an icon, never
/// colour alone.
class Sky {
  const Sky._();

  // ── Light ────────────────────────────────────────────────────────────────
  /// Page background: a pale morning sky.
  static const canvas = Color(0xFFF2F7FB);

  /// Cards, sheets, inputs.
  static const card = Color(0xFFFFFFFF);

  /// Primary text — deep navy.
  static const ink = Color(0xFF0E2235);

  /// Secondary text.
  static const inkSoft = Color(0xFF33475B);

  /// Captions, hints, meta.
  static const muted = Color(0xFF5D7083);

  /// Disabled / placeholder.
  static const faint = Color(0xFF8A9BAB);

  /// Hairlines and card borders.
  static const line = Color(0xFFE2EBF2);

  /// Stronger dividers and outlined-button borders.
  static const lineStrong = Color(0xFFC9D7E3);

  /// Primary action colour (buttons, progress, active tab).
  static const teal = Color(0xFF0A7887);

  /// Pressed / emphasised primary.
  static const tealDeep = Color(0xFF07606C);

  /// Tinted container behind a selected chip or nav item.
  static const tealSoft = Color(0xFFDDF1F3);

  /// Background of the rounded icon tiles.
  static const tile = Color(0xFFE8F1F8);

  /// Icon colour inside a tile.
  static const tileInk = Color(0xFF1D4E78);

  /// Status colours — text-safe on white (≥ 4.5:1).
  static const go = Color(0xFF18773F);
  static const goSoft = Color(0xFFE2F4E9);
  static const caution = Color(0xFF9A5E00);
  static const cautionFill = Color(0xFFE09F00);
  static const cautionSoft = Color(0xFFFCF0DA);
  static const stop = Color(0xFFC0343A);
  static const stopSoft = Color(0xFFFBE6E6);

  // ── Dark ─────────────────────────────────────────────────────────────────
  static const nightCanvas = Color(0xFF0B1621);
  static const nightCard = Color(0xFF132331);
  static const nightInk = Color(0xFFE6EEF5);
  static const nightMuted = Color(0xFF9DB0C2);
  static const nightLine = Color(0xFF223547);
  static const nightTeal = Color(0xFF4CC3D0);
  static const nightGo = Color(0xFF5CC98A);
  static const nightCaution = Color(0xFFF2B84B);
  static const nightStop = Color(0xFFFF7B7F);

  // ── Shape ────────────────────────────────────────────────────────────────
  /// Cards and hero panels.
  static const double radius = 16;

  /// Buttons, inputs, tiles.
  static const double radiusM = 12;

  /// Large hero panels and sheets.
  static const double radiusL = 22;

  static const BorderRadius corners = BorderRadius.all(Radius.circular(radius));
  static const BorderRadius cornersM = BorderRadius.all(
    Radius.circular(radiusM),
  );
  static const BorderRadius cornersL = BorderRadius.all(
    Radius.circular(radiusL),
  );

  /// The soft shadow under every card.
  static const List<BoxShadow> shadow = [
    BoxShadow(color: Color(0x140E2235), blurRadius: 18, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x0A0E2235), blurRadius: 3, offset: Offset(0, 1)),
  ];

  /// Card colour for the current brightness.
  static Color cardOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? nightCard : card;

  /// Tile background for the current brightness.
  static Color tileOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF1B3144)
      : tile;

  /// Tile icon colour for the current brightness.
  static Color tileInkOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF9CC9EE)
      : tileInk;
}

/// Bundled font families (assets/fonts, SIL OFL 1.1).
class AppFonts {
  const AppFonts._();

  /// Titles and headings — the full-width Sofia Sans, bold.
  static const heading = 'SofiaSans';

  /// Body copy.
  static const body = 'SofiaSans';

  /// Compact numerals and instrument read-outs.
  static const condensed = 'SofiaSansCondensed';

  /// METAR/TAF, times, hours, ICAO.
  static const mono = 'FiraMono';
}

/// Text styles with the GoogleFonts-style named arguments the tool screens
/// were written against, on the bundled families.
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
  }) => TextStyle(
    fontFamily: AppFonts.condensed,
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
  }) => TextStyle(
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
  }) => TextStyle(
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

const ColorScheme skyLightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Sky.teal,
  onPrimary: Colors.white,
  primaryContainer: Sky.tealSoft,
  onPrimaryContainer: Color(0xFF04414A),
  secondary: Sky.tileInk,
  onSecondary: Colors.white,
  secondaryContainer: Sky.tile,
  onSecondaryContainer: Sky.tileInk,
  tertiary: Sky.go,
  onTertiary: Colors.white,
  error: Sky.stop,
  onError: Colors.white,
  surface: Sky.canvas,
  onSurface: Sky.ink,
  onSurfaceVariant: Sky.muted,
  surfaceContainerLowest: Sky.card,
  surfaceContainerLow: Color(0xFFF8FBFD),
  surfaceContainer: Color(0xFFEEF4F9),
  surfaceContainerHigh: Color(0xFFE8F0F6),
  surfaceContainerHighest: Color(0xFFE1EAF2),
  outline: Color(0xFF8395A6),
  outlineVariant: Sky.line,
  inverseSurface: Sky.ink,
  onInverseSurface: Sky.canvas,
  inversePrimary: Sky.nightTeal,
  shadow: Sky.ink,
  scrim: Colors.black,
);

const ColorScheme skyDarkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Sky.nightTeal,
  onPrimary: Color(0xFF032A30),
  primaryContainer: Color(0xFF0E4A53),
  onPrimaryContainer: Color(0xFFCFF3F7),
  secondary: Color(0xFF9CC9EE),
  onSecondary: Sky.nightCanvas,
  secondaryContainer: Color(0xFF1B3144),
  onSecondaryContainer: Sky.nightInk,
  tertiary: Sky.nightGo,
  onTertiary: Sky.nightCanvas,
  error: Sky.nightStop,
  onError: Sky.nightCanvas,
  surface: Sky.nightCanvas,
  onSurface: Sky.nightInk,
  onSurfaceVariant: Sky.nightMuted,
  surfaceContainerLowest: Sky.nightCard,
  surfaceContainerLow: Color(0xFF101E2B),
  surfaceContainer: Color(0xFF172938),
  surfaceContainerHigh: Color(0xFF1C2F40),
  surfaceContainerHighest: Color(0xFF223648),
  outline: Color(0xFF7D90A2),
  outlineVariant: Sky.nightLine,
  inverseSurface: Sky.nightInk,
  onInverseSurface: Sky.nightCanvas,
  inversePrimary: Sky.teal,
  shadow: Colors.black,
  scrim: Colors.black,
);

ThemeData buildSkyTheme(Brightness brightness, {TargetPlatform? platform}) {
  final light = brightness == Brightness.light;
  final scheme = light ? skyLightScheme : skyDarkScheme;
  const shapeM = RoundedRectangleBorder(borderRadius: Sky.cornersM);
  const pill = StadiumBorder();
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    platform: platform,
    fontFamily: AppFonts.body,
    scaffoldBackgroundColor: scheme.surface,
    splashFactory: InkSparkle.splashFactory,
  );
  TextStyle h(TextStyle? s, {FontWeight w = FontWeight.w800, double? ls}) =>
      (s ?? const TextStyle()).copyWith(
        fontFamily: AppFonts.heading,
        fontWeight: w,
        letterSpacing: ls ?? -0.2,
        color: scheme.onSurface,
      );
  final t = base.textTheme;
  const buttonText = TextStyle(
    fontFamily: AppFonts.heading,
    fontWeight: FontWeight.w700,
    fontSize: 16,
    letterSpacing: 0.1,
  );
  return base.copyWith(
    textTheme: t.copyWith(
      displayLarge: h(t.displayLarge),
      displayMedium: h(t.displayMedium),
      displaySmall: h(t.displaySmall),
      headlineLarge: h(t.headlineLarge),
      headlineMedium: h(t.headlineMedium),
      headlineSmall: h(t.headlineSmall),
      titleLarge: h(t.titleLarge, w: FontWeight.w700),
      titleMedium: h(t.titleMedium, w: FontWeight.w700, ls: 0),
      titleSmall: h(t.titleSmall, w: FontWeight.w600, ls: 0),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 64,
      titleTextStyle: TextStyle(
        fontFamily: AppFonts.heading,
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: scheme.onSurface,
        letterSpacing: -0.4,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLowest,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: Sky.corners,
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      floatingLabelStyle: TextStyle(color: scheme.primary),
      prefixIconColor: scheme.onSurfaceVariant,
      border: OutlineInputBorder(
        borderRadius: Sky.cornersM,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: Sky.cornersM,
        borderSide: BorderSide(
          color: light ? Sky.lineStrong : scheme.outlineVariant,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: Sky.cornersM,
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: Sky.cornersM,
        borderSide: BorderSide(color: scheme.error),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        textStyle: buttonText,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        elevation: 0,
        minimumSize: const Size(64, 48),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        minimumSize: const Size(64, 48),
        foregroundColor: scheme.primary,
        backgroundColor: scheme.surfaceContainerLowest,
        side: BorderSide(color: light ? Sky.lineStrong : scheme.outlineVariant),
        textStyle: buttonText.copyWith(fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: shapeM,
        foregroundColor: scheme.primary,
        textStyle: buttonText.copyWith(fontSize: 15),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: scheme.onSurface),
    ),
    // Only shape, colours and padding change: replacing labelStyle wholesale
    // dropped its colour once, and chip labels rendered white on white.
    chipTheme: base.chipTheme.copyWith(
      shape: pill,
      side: BorderSide(color: light ? Sky.lineStrong : scheme.outlineVariant),
      backgroundColor: scheme.surfaceContainerLowest,
      selectedColor: scheme.primaryContainer,
      checkmarkColor: scheme.primary,
      iconTheme: IconThemeData(color: scheme.primary, size: 18),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      highlightElevation: 4,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shadowColor: scheme.shadow,
      elevation: 0,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: pill,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
          size: 24,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: AppFonts.heading,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          fontSize: 12.5,
          color: s.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    // Tabs read as a segmented control: a teal pill slides under the
    // selected label. Wrap a TabBar in `SegmentedTabBar` for the track.
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.onPrimary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      dividerHeight: 0,
      splashBorderRadius: const BorderRadius.all(Radius.circular(999)),
      indicator: BoxDecoration(
        color: scheme.primary,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 16),
      labelStyle: const TextStyle(
        fontFamily: AppFonts.heading,
        fontWeight: FontWeight.w700,
        fontSize: 14.5,
      ),
      unselectedLabelStyle: const TextStyle(
        fontFamily: AppFonts.heading,
        fontWeight: FontWeight.w500,
        fontSize: 14.5,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? scheme.primary : null,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? scheme.primary : null,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      borderRadius: const BorderRadius.all(Radius.circular(999)),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: scheme.primary,
      thumbColor: scheme.primary,
      inactiveTrackColor: scheme.surfaceContainerHighest,
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: shapeM,
      backgroundColor: scheme.inverseSurface,
      actionTextColor: light ? Sky.nightTeal : Sky.teal,
      contentTextStyle: TextStyle(
        fontFamily: AppFonts.body,
        color: scheme.onInverseSurface,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: Sky.cornersL),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Sky.radiusL)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: Sky.cornersM),
    ),
    listTileTheme: ListTileThemeData(
      shape: shapeM,
      iconColor: scheme.secondary,
      titleTextStyle: TextStyle(
        fontFamily: AppFonts.heading,
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: scheme.onSurface,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 13,
        color: scheme.onSurfaceVariant,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: scheme.primary,
        selectedForegroundColor: scheme.onPrimary,
        side: BorderSide(color: light ? Sky.lineStrong : scheme.outlineVariant),
        shape: pill,
      ),
    ),
    badgeTheme: BadgeThemeData(
      backgroundColor: scheme.primary,
      textColor: scheme.onPrimary,
    ),
  );
}

/// The kit tools (E6B, W&B, fuel, planner, checklists, documents, charts)
/// were written against light-sky colours: they always render on the light
/// theme, whatever the system brightness, so their fixed tints stay legible.
class PanelTheme extends StatelessWidget {
  const PanelTheme({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildSkyTheme(
        Brightness.light,
        platform: Theme.of(context).platform,
      ),
      child: child,
    );
  }
}

/// Legacy names from the "Remove Before Flight" theme, kept so code written
/// against it (open branches, local work) still compiles. New code uses
/// [Sky] and [buildSkyTheme].
class Rbf {
  const Rbf._();
  static const double radius = Sky.radiusM;
  static const BorderRadius corners = Sky.cornersM;
}

/// Legacy name for [buildSkyTheme].
ThemeData buildRbfTheme(Brightness brightness, {TargetPlatform? platform}) =>
    buildSkyTheme(brightness, platform: platform);
