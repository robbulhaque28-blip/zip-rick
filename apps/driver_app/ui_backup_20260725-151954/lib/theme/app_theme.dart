import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Vybe design system. Use these instead of hardcoding hex values.
class AppColors {
  static const primary      = Color(0xFF4F46E5);
  static const primaryDark  = Color(0xFF4338CA);
  static const primarySoft  = Color(0xFFEEF0FF);

  static const accent  = Color(0xFF10B981);
  static const success  = Color(0xFF10B981);
  static const warning  = Color(0xFFF59E0B);
  static const danger   = Color(0xFFEF4444);

  static const ink    = Color(0xFF0B1120);
  static const body   = Color(0xFF475569);
  static const muted  = Color(0xFF94A3B8);
  static const line   = Color(0xFFE7ECF3);
  static const surface= Color(0xFFFFFFFF);
  static const canvas = Color(0xFFF7F9FC);
}

class AppRadius {
  static const sm = 11.0;
  static const md = 15.0;
  static const lg = 20.0;
  static const xl = 26.0;
}

class AppShadow {
  static List<BoxShadow> get soft => [
    BoxShadow(color: const Color(0xFF0B1120).withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 2)),
  ];
  static List<BoxShadow> get card => [
    BoxShadow(color: const Color(0xFF0B1120).withOpacity(0.07), blurRadius: 20, offset: const Offset(0, 4)),
  ];
  static List<BoxShadow> get lifted => [
    BoxShadow(color: const Color(0xFF0B1120).withOpacity(0.12), blurRadius: 30, offset: const Offset(0, 8)),
  ];
}

class AppText {
  static TextStyle get h1    => GoogleFonts.plusJakartaSans(fontSize: 27, fontWeight: FontWeight.w700, color: AppColors.ink, letterSpacing: -0.6);
  static TextStyle get h2    => GoogleFonts.plusJakartaSans(fontSize: 21, fontWeight: FontWeight.w700, color: AppColors.ink, letterSpacing: -0.4);
  static TextStyle get h3    => GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.ink, letterSpacing: -0.2);
  static TextStyle get body  => GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.body, height: 1.45);
  static TextStyle get bodyStrong => GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink);
  static TextStyle get label => GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.muted);
  static TextStyle get tiny  => GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.6);
  static TextStyle get button=> GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1);
  static TextStyle get price => GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink, letterSpacing: -0.4);
}

ThemeData buildVybeTheme() {
  final base = ThemeData(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.canvas,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      error: AppColors.danger,
      surface: AppColors.surface,
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme),
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.ink,
      titleTextStyle: AppText.h3,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    // Deliberately NO infinite minimumSize - that caused the payment sheet crash.
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        textStyle: AppText.button,
        disabledBackgroundColor: AppColors.muted.withOpacity(0.35),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.line),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        textStyle: AppText.button,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.primary, textStyle: AppText.button),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.canvas,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.primary, width: 1.6)),
      labelStyle: AppText.label,
      hintStyle: AppText.label,
      prefixIconColor: AppColors.muted,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: Colors.white, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      insetPadding: const EdgeInsets.all(14),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.muted,
      selectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w500),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
  );
}
