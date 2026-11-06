import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData build(Brightness brightness) {
    final light = brightness == Brightness.light;
    final colors =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF3458DB),
          brightness: brightness,
        ).copyWith(
          primary: light ? const Color(0xFF3458DB) : const Color(0xFFB2C1FF),
          onPrimary: light ? Colors.white : const Color(0xFF172652),
          primaryContainer: light
              ? const Color(0xFFE9EDFF)
              : const Color(0xFF29365B),
          onPrimaryContainer: light
              ? const Color(0xFF2A46B4)
              : const Color(0xFFDDE4FF),
          secondary: light ? const Color(0xFF547362) : const Color(0xFFA7D3B6),
          secondaryContainer: light
              ? const Color(0xFFEAF2E8)
              : const Color(0xFF273C32),
          onSecondaryContainer: light
              ? const Color(0xFF314F3E)
              : const Color(0xFFD1EFDA),
          surface: light ? Colors.white : const Color(0xFF1D2028),
          onSurface: light ? const Color(0xFF1C202A) : const Color(0xFFF4F5F9),
          onSurfaceVariant: light
              ? const Color(0xFF6F7480)
              : const Color(0xFFADB1BE),
          surfaceContainerLowest: light
              ? Colors.white
              : const Color(0xFF13151B),
          surfaceContainerLow: light
              ? const Color(0xFFFAFAF7)
              : const Color(0xFF191C23),
          surfaceContainer: light
              ? const Color(0xFFF2F3EF)
              : const Color(0xFF272B35),
          surfaceContainerHigh: light
              ? const Color(0xFFECEEE8)
              : const Color(0xFF303540),
          surfaceContainerHighest: light
              ? const Color(0xFFE4E7E0)
              : const Color(0xFF3A404D),
          outline: light ? const Color(0xFF8E949E) : const Color(0xFF8E95A4),
          outlineVariant: light
              ? const Color(0xFFE7E9E3)
              : const Color(0xFF343945),
          tertiary: light ? const Color(0xFF087B59) : const Color(0xFF77DAAA),
          tertiaryContainer: light
              ? const Color(0xFFE6F5EC)
              : const Color(0xFF203F32),
          onTertiaryContainer: light
              ? const Color(0xFF155C3E)
              : const Color(0xFFB3F2CF),
          error: light ? const Color(0xFFBC343E) : const Color(0xFFFF9BA3),
          errorContainer: light
              ? const Color(0xFFFFEDEF)
              : const Color(0xFF472832),
          onErrorContainer: light
              ? const Color(0xFF8E2435)
              : const Color(0xFFFFCED4),
        );
    final base = ThemeData(useMaterial3: true, colorScheme: colors);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.outlineVariant),
    );
    return base.copyWith(
      scaffoldBackgroundColor: light
          ? const Color(0xFFF7F8F4)
          : const Color(0xFF14171D),
      textTheme: base.textTheme.copyWith(
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.6,
          height: 1.1,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -.8,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontSize: 21,
          fontWeight: FontWeight.w600,
          letterSpacing: -.5,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -.25,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.5),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: light
            ? const Color(0xFFF7F8F4)
            : const Color(0xFF14171D),
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 68,
        titleTextStyle: TextStyle(
          color: colors.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.8,
        ),
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: colors.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 10,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? colors.primary
                : colors.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.primaryContainer,
        selectedIconTheme: IconThemeData(color: colors.primary),
        selectedLabelTextStyle: TextStyle(
          color: colors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: light
            ? const Color(0xFFF7F8F4)
            : const Color(0xFF14171D),
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(30)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        selectedColor: colors.primary,
        selectedTileColor: colors.primaryContainer,
        iconColor: colors.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamily: 'Roboto',
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          side: BorderSide(color: colors.outlineVariant),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: colors.surface,
        selectedColor: colors.primaryContainer,
        side: BorderSide(color: colors.outlineVariant),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
