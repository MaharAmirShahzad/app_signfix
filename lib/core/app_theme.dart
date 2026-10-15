import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SignFix Brand Colors  (extracted from logo.jpeg + banner images)
//  Primary palette:  Dark Navy + Gold/Amber
// ─────────────────────────────────────────────────────────────────────────────
abstract final class AppColors {
  // ── Dark Navy (background family) ────────────────────────────────────────
  static const navyDeep = Color(0xFF080D24); // deepest bg
  static const navyDark = Color(0xFF0D1B4B); // card / surface
  static const navyMid = Color(0xFF132057); // elevated surfaces
  static const navyLight = Color(0xFF1E3175); // borders / dividers

  // ── Gold / Amber (primary accent from logo + banners) ───────────────────
  static const gold = Color(0xFFF5A623); // primary CTA, highlights
  static const goldLight = Color(0xFFFFCC47); // lighter variant
  static const goldDark = Color(0xFFD4840A); // pressed / shadow

  // ── White / Text ─────────────────────────────────────────────────────────
  static const white = Color(0xFFFFFFFF);
  static const whiteSmoke = Color(0xFFF0F4FF);
  static const textLight = Color(0xFFB8C6E8); // secondary text on dark
  static const textMuted = Color(0xFF6B80B3); // muted text

  // ── Status colors ────────────────────────────────────────────────────────
  static const success = Color(0xFF1DB97A);
  static const warning = Color(0xFFF5A623); // same as gold
  static const danger = Color(0xFFE53E3E);
  static const info = Color(0xFF4299E1);

  // ── Job Workflow Step Colors (app-harmonious) ────────────────────────────
  static const stepAssigned        = Color(0xFFF5A623); // Gold — matches brand
  static const stepAccepted        = Color(0xFFFFCC47); // Gold Light — progression
  static const stepOnTheWay        = Color(0xFF4299E1); // Blue — movement/info
  static const stepReachedLocation = Color(0xFF38B2AC); // Teal — arrival
  static const stepInspection      = Color(0xFF9F7AEA); // Purple — inspection
  static const stepWorkInProgress  = Color(0xFFED64A6); // Pink/Magenta — active work
  static const stepCompleted       = Color(0xFF1DB97A); // Green — success/done

  // ── Legacy aliases (keep existing code working) ─────────────────────────
  static const primary = navyMid; // used as primary in Material
  static const primaryDark = navyDark;
  static const accent = gold;
  static const ink = white;
  static const background = navyDeep;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Material 3 Theme
// ─────────────────────────────────────────────────────────────────────────────
ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.gold,
    onPrimary: AppColors.navyDeep,
    secondary: AppColors.goldLight,
    onSecondary: AppColors.navyDeep,
    surface: AppColors.navyDark,
    onSurface: AppColors.white,
    surfaceContainerHighest: AppColors.navyMid,
    error: AppColors.danger,
    onError: AppColors.white,
    outline: AppColors.navyLight,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.navyDeep,
    canvasColor: AppColors.navyDark,

    // ── AppBar ──────────────────────────────────────────────────────────────
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.navyDark,
      foregroundColor: AppColors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.white,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
      iconTheme: IconThemeData(color: AppColors.gold),
    ),

    // ── Bottom Navigation ───────────────────────────────────────────────────
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.navyDark,
      indicatorColor: AppColors.gold.withValues(alpha: .2),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.gold, size: 24);
        }
        return const IconThemeData(color: AppColors.textMuted, size: 22);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            color: AppColors.gold,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          );
        }
        return const TextStyle(color: AppColors.textMuted, fontSize: 11);
      }),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),

    // ── Cards ───────────────────────────────────────────────────────────────
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: AppColors.navyDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: AppColors.navyLight.withValues(alpha: .6), width: 1),
      ),
    ),

    // ── Input Fields ────────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.navyMid,
      labelStyle: const TextStyle(color: AppColors.textLight),
      hintStyle: const TextStyle(color: AppColors.textMuted),
      prefixIconColor: AppColors.gold,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.navyLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.navyLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    ),

    // ── Filled Button (Gold CTA) ─────────────────────────────────────────────
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.navyDeep,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 15,
          letterSpacing: 0.4,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    ),

    // ── Outlined Button ──────────────────────────────────────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gold,
        side: const BorderSide(color: AppColors.gold, width: 1.5),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    ),

    // ── Text Button ──────────────────────────────────────────────────────────
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.gold),
    ),

    // ── Chip ─────────────────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.navyMid,
      selectedColor: AppColors.gold.withValues(alpha: .2),
      labelStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
      side: const BorderSide(color: AppColors.navyLight),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),

    // ── ChoiceChip selected ───────────────────────────────────────────────────
    // (handled via ChipTheme selectedColor above)

    // ── Divider ───────────────────────────────────────────────────────────────
    dividerTheme: DividerThemeData(
      color: AppColors.navyLight.withValues(alpha: .6),
      thickness: 1,
    ),

    // ── SnackBar ──────────────────────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.navyMid,
      contentTextStyle: const TextStyle(color: AppColors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    // ── Drawer ────────────────────────────────────────────────────────────────
    drawerTheme: const DrawerThemeData(
      backgroundColor: AppColors.navyDark,
    ),

    // ── Icon ──────────────────────────────────────────────────────────────────
    iconTheme: const IconThemeData(color: AppColors.gold),

    // ── ListTile ──────────────────────────────────────────────────────────────
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.gold,
      textColor: AppColors.white,
    ),

    // ── Text ──────────────────────────────────────────────────────────────────
    textTheme: const TextTheme(
      displayLarge:
          TextStyle(color: AppColors.white, fontWeight: FontWeight.w900),
      displayMedium:
          TextStyle(color: AppColors.white, fontWeight: FontWeight.w800),
      headlineLarge:
          TextStyle(color: AppColors.white, fontWeight: FontWeight.w800),
      headlineMedium:
          TextStyle(color: AppColors.white, fontWeight: FontWeight.w700),
      titleLarge:
          TextStyle(color: AppColors.white, fontWeight: FontWeight.w700),
      titleMedium:
          TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: AppColors.textLight),
      bodyMedium: TextStyle(color: AppColors.textLight),
      bodySmall: TextStyle(color: AppColors.textMuted),
      labelLarge: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700),
    ),

    // ── Progress Indicator ────────────────────────────────────────────────────
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.gold,
      linearTrackColor: AppColors.navyLight,
    ),

    // ── Switch ───────────────────────────────────────────────────────────────
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? AppColors.gold
              : AppColors.textMuted),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? AppColors.gold.withValues(alpha: .3)
              : AppColors.navyLight),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Technician theme  (same dark palette, blue accent instead of gold)
// ─────────────────────────────────────────────────────────────────────────────
ThemeData buildTechnicianTheme() => buildAppTheme().copyWith(
      colorScheme: buildAppTheme().colorScheme.copyWith(
            primary: AppColors.info,
            onPrimary: AppColors.white,
            secondary: AppColors.info,
          ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.info,
          foregroundColor: AppColors.white,
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
