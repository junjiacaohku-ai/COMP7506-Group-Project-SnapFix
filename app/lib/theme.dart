import 'package:flutter/material.dart';

import 'settings.dart';

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.primary,
    required this.primaryDark,
    required this.accent,
    required this.text,
    required this.secondary,
    required this.muted,
    required this.green,
    required this.red,
    required this.amber,
    required this.onPrimary,
    required this.primaryGradient,
    required this.heroGradient,
  });

  static const dark = AppPalette(
    background: Color(0xFF090B10),
    surface: Color(0xFF12151D),
    surfaceRaised: Color(0xFF191D28),
    border: Color(0xFF272D3A),
    primary: Color(0xFFA895FF),
    primaryDark: Color(0xFF7968E8),
    accent: Color(0xFF67E8F9),
    text: Color(0xFFF6F7FB),
    secondary: Color(0xFF9AA3B5),
    muted: Color(0xFF697386),
    green: Color(0xFF73DFB2),
    red: Color(0xFFFF7D92),
    amber: Color(0xFFF4C77A),
    onPrimary: Colors.white,
    primaryGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFB8A5FF), Color(0xFF8170F0)],
    ),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF211C38), Color(0xFF111D27)],
    ),
  );

  static const light = AppPalette(
    background: Color(0xFFF5F6FA),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFEEEFF5),
    border: Color(0xFFDDE1E9),
    primary: Color(0xFF6E56CF),
    primaryDark: Color(0xFF5844BC),
    accent: Color(0xFF007F91),
    text: Color(0xFF171923),
    secondary: Color(0xFF525C6E),
    muted: Color(0xFF707A8B),
    green: Color(0xFF157A56),
    red: Color(0xFFC73850),
    amber: Color(0xFF8A5A0B),
    onPrimary: Colors.white,
    primaryGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF806CE0), Color(0xFF624AC3)],
    ),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEAE4FF), Color(0xFFE3F1F5)],
    ),
  );

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color border;
  final Color primary;
  final Color primaryDark;
  final Color accent;
  final Color text;
  final Color secondary;
  final Color muted;
  final Color green;
  final Color red;
  final Color amber;
  final Color onPrimary;
  final LinearGradient primaryGradient;
  final LinearGradient heroGradient;

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? border,
    Color? primary,
    Color? primaryDark,
    Color? accent,
    Color? text,
    Color? secondary,
    Color? muted,
    Color? green,
    Color? red,
    Color? amber,
    Color? onPrimary,
    LinearGradient? primaryGradient,
    LinearGradient? heroGradient,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      accent: accent ?? this.accent,
      text: text ?? this.text,
      secondary: secondary ?? this.secondary,
      muted: muted ?? this.muted,
      green: green ?? this.green,
      red: red ?? this.red,
      amber: amber ?? this.amber,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryGradient: primaryGradient ?? this.primaryGradient,
      heroGradient: heroGradient ?? this.heroGradient,
    );
  }

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      text: Color.lerp(text, other.text, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      green: Color.lerp(green, other.green, t)!,
      red: Color.lerp(red, other.red, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primaryGradient: LinearGradient.lerp(
        primaryGradient,
        other.primaryGradient,
        t,
      )!,
      heroGradient: LinearGradient.lerp(heroGradient, other.heroGradient, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppPalette get colors => Theme.of(this).extension<AppPalette>()!;
}

ThemeData buildAppTheme(
  Brightness brightness, {
  AppAccent accent = AppAccent.purple,
}) {
  final base = brightness == Brightness.dark
      ? AppPalette.dark
      : AppPalette.light;
  final dark = brightness == Brightness.dark;
  final tint = switch (accent) {
    AppAccent.purple => (
      base.primary,
      base.primaryDark,
      base.accent,
      base.primaryGradient.colors,
    ),
    AppAccent.teal =>
      dark
          ? (
              const Color(0xFF67E8F9),
              const Color(0xFF289FB3),
              const Color(0xFF67E8F9),
              const [Color(0xFF8AEAF5), Color(0xFF38AFC5)],
            )
          : (
              const Color(0xFF007F91),
              const Color(0xFF005C6A),
              const Color(0xFF008CA2),
              const [Color(0xFF249FB0), Color(0xFF007185)],
            ),
    AppAccent.blue =>
      dark
          ? (
              const Color(0xFF8AB4FF),
              const Color(0xFF5B82E0),
              const Color(0xFF8AB4FF),
              const [Color(0xFFA5C4FF), Color(0xFF648DEB)],
            )
          : (
              const Color(0xFF3568D4),
              const Color(0xFF254EAA),
              const Color(0xFF3568D4),
              const [Color(0xFF5D86DF), Color(0xFF315BBD)],
            ),
    AppAccent.amber =>
      dark
          ? (
              const Color(0xFFF4C77A),
              const Color(0xFFC28B36),
              const Color(0xFFF4C77A),
              const [Color(0xFFF5D491), Color(0xFFD19B42)],
            )
          : (
              const Color(0xFF8A5A0B),
              const Color(0xFF674205),
              const Color(0xFF9A680D),
              const [Color(0xFFD5A94F), Color(0xFFAD7718)],
            ),
  };
  final palette = base.copyWith(
    primary: tint.$1,
    primaryDark: tint.$2,
    accent: tint.$3,
    onPrimary: accent == AppAccent.amber && dark
        ? const Color(0xFF241A05)
        : Colors.white,
    primaryGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: tint.$4,
    ),
    heroGradient: accent == AppAccent.purple
        ? base.heroGradient
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tint.$1.withValues(alpha: dark ? 0.17 : 0.13),
              tint.$3.withValues(alpha: dark ? 0.07 : 0.05),
            ],
          ),
  );
  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: palette.primary,
    onPrimary: palette.onPrimary,
    secondary: palette.accent,
    onSecondary: palette.background,
    surface: palette.surface,
    onSurface: palette.text,
    surfaceContainerHighest: palette.surfaceRaised,
    error: palette.red,
    onError: Colors.white,
    outline: palette.border,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    extensions: [palette],
    scaffoldBackgroundColor: palette.background,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: palette.background,
      foregroundColor: palette.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: palette.text,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
    ),
    cardTheme: CardThemeData(
      color: palette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: palette.border),
      ),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        minimumSize: const Size.fromHeight(56),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.text,
        backgroundColor: palette.surface,
        minimumSize: const Size.fromHeight(56),
        side: BorderSide(color: palette.border),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: palette.primary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      hintStyle: TextStyle(color: palette.muted, fontSize: 15),
      labelStyle: TextStyle(color: palette.secondary, fontSize: 14),
      floatingLabelStyle: TextStyle(color: palette.primary, fontSize: 13),
      prefixIconColor: palette.secondary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.red, width: 1.4),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.surfaceRaised,
      contentTextStyle: TextStyle(color: palette.text, fontSize: 15),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: palette.border),
      ),
      titleTextStyle: TextStyle(
        color: palette.text,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: TextStyle(
        color: palette.secondary,
        fontSize: 15,
        height: 1.55,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.surface,
      indicatorColor: palette.primary.withValues(alpha: 0.13),
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: palette.text)),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(color: palette.text, fontSize: 12),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: palette.primary,
      linearTrackColor: palette.border,
      circularTrackColor: palette.border,
    ),
    dividerTheme: DividerThemeData(color: palette.border, thickness: 1),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: palette.primary,
      selectionColor: palette.primary.withValues(alpha: 0.28),
      selectionHandleColor: palette.primary,
    ),
  );
}
