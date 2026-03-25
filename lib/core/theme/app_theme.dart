import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppTheme {
  // ── DARK THEME ─────────────────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.surface,
          error: AppColors.error,
          onPrimary: Colors.white,
          onSurface: AppColors.textPrimary,
        ),
        cardColor: AppColors.surface,
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
          labelStyle: TextStyle(color: AppColors.textSecondary),
          hintStyle: TextStyle(color: AppColors.textSecondary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? AppColors.primary : Colors.grey),
          trackColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? AppColors.primary.withValues(alpha:0.4) : Colors.grey.withValues(alpha:0.3)),
        ),
        textTheme: TextTheme(
          displayLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          headlineLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: AppColors.textPrimary),
          bodyLarge: TextStyle(color: AppColors.textPrimary),
          bodyMedium: TextStyle(color: AppColors.textSecondary),
          labelLarge: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconTheme: IconThemeData(color: AppColors.textSecondary),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.surface,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        dividerTheme: DividerThemeData(color: AppColors.border),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surfaceVariant,
          selectedColor: AppColors.primary,
          labelStyle: TextStyle(color: AppColors.textPrimary),
        ),
        listTileTheme: ListTileThemeData(
          iconColor: AppColors.textSecondary,
          textColor: AppColors.textPrimary,
        ),
      );

  // ── LIGHT THEME ────────────────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF0F2F5),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1976D2),
          secondary: Color(0xFF03A9F4),
          surface: Colors.white,
          error: Color(0xFFD32F2F),
          onPrimary: Colors.white,
          onSurface: Color(0xFF1A1A2E),
        ),
        cardColor: Colors.white,
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFF757575)),
          hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF1976D2)),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? const Color(0xFF1976D2) : Colors.grey),
          trackColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? const Color(0xFF1976D2).withValues(alpha:0.4) : Colors.grey.withValues(alpha:0.3)),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.bold),
          headlineLarge: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: Color(0xFF1A1A2E)),
          bodyLarge: TextStyle(color: Color(0xFF1A1A2E)),
          bodyMedium: TextStyle(color: Color(0xFF616161)),
          labelLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF616161)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.black12,
          iconTheme: IconThemeData(color: Color(0xFF1A1A2E)),
          titleTextStyle: TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFFE0E0E0)),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFEEEEEE),
          selectedColor: const Color(0xFF1976D2),
          labelStyle: const TextStyle(color: Color(0xFF1A1A2E)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: Color(0xFF616161),
          textColor: Color(0xFF1A1A2E),
        ),
      );
}
