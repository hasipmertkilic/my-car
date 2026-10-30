import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData build(Brightness brightness) {
    final light = brightness == Brightness.light;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFFF97316),
          brightness: brightness,
        ).copyWith(
          surface: light ? Colors.white : const Color(0xFF1E293B),
          surfaceContainerLowest: light
              ? Colors.white
              : const Color(0xFF0B1220),
          surfaceContainerHigh: light
              ? const Color(0xFFF1F5F9)
              : const Color(0xFF273449),
          surfaceContainerHighest: light
              ? const Color(0xFFE2E8F0)
              : const Color(0xFF334155),
          error: light ? const Color(0xFFB91C1C) : const Color(0xFFEF4444),
          onError: light ? Colors.white : const Color(0xFF0F172A),
          errorContainer: light
              ? const Color(0xFFFEE2E2)
              : const Color(0xFF451F2A),
          onErrorContainer: light
              ? const Color(0xFF7F1D1D)
              : const Color(0xFFFECACA),
          tertiary: light ? const Color(0xFF047857) : const Color(0xFF10B981),
          onTertiary: light ? Colors.white : const Color(0xFF0F172A),
          tertiaryContainer: light
              ? const Color(0xFFD1FAE5)
              : const Color(0xFF123D35),
          onTertiaryContainer: light
              ? const Color(0xFF064E3B)
              : const Color(0xFFA7F3D0),
          surfaceContainerLow: light
              ? const Color(0xFFF5F8FC)
              : const Color(0xFF162033),
          surfaceContainer: light
              ? const Color(0xFFEDF3FA)
              : const Color(0xFF263247),
          primary: light ? const Color(0xFFF97316) : const Color(0xFFF97316),
          onPrimary: const Color(0xFF0F172A),
          primaryContainer: light
              ? const Color(0xFFFFEDD5)
              : const Color(0xFF43291D),
          onPrimaryContainer: light
              ? const Color(0xFF7C2D12)
              : const Color(0xFFFDBA74),
          secondary: light ? const Color(0xFFA16207) : const Color(0xFFEAB308),
          secondaryContainer: light
              ? const Color(0xFFFEF9C3)
              : const Color(0xFF3C341A),
          onSecondaryContainer: light
              ? const Color(0xFF713F12)
              : const Color(0xFFFEF08A),
          onSurface: light ? const Color(0xFF23324A) : const Color(0xFFF8FAFC),
          onSurfaceVariant: light
              ? const Color(0xFF53647B)
              : const Color(0xFFCBD5E1),
          outlineVariant: light
              ? const Color(0xFFDEE7F1)
              : const Color(0xFF334155),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: light
          ? const Color(0xFFF5F8FC)
          : const Color(0xFF0F172A),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        selectedColor: scheme.primary,
        selectedTileColor: scheme.primaryContainer,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
    );
  }
}
