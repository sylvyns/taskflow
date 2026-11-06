import 'package:flutter/material.dart';

import '../../models/enums.dart';

/// Нежная пастельная палитра TaskFlow:
/// лаванда (основной), мята, персик, пудровая роза, небесный, сливочный.
class Pastel {
  Pastel._();

  static const lavender = Color(0xFF8E7CC3);
  static const lavenderLight = Color(0xFFEDE7FB);
  static const lavenderDeep = Color(0xFF4A3B7A);

  static const mint = Color(0xFF7DB9A5);
  static const mintLight = Color(0xFFDDF2EA);
  static const mintDeep = Color(0xFF2E6352);

  static const peach = Color(0xFFE9A28F);
  static const peachLight = Color(0xFFFDE6DD);
  static const peachDeep = Color(0xFF8A4A36);

  static const rose = Color(0xFFE08DA2);
  static const roseLight = Color(0xFFFCE3EA);
  static const roseDeep = Color(0xFF94405A);

  static const sky = Color(0xFF7FA7D9);
  static const skyLight = Color(0xFFE3EEFB);
  static const skyDeep = Color(0xFF3E5F8C);

  static const butter = Color(0xFFE3BE68);
  static const butterLight = Color(0xFFFBF1D6);
  static const butterDeep = Color(0xFF85661E);

  static const mauveLight = Color(0xFFEFE8EE);
  static const mauveDeep = Color(0xFF7D6E7B);

  static const background = Color(0xFFF8F5FC);
  static const card = Colors.white;
  static const ink = Color(0xFF3D3550);
  static const inkSoft = Color(0xFF7D7392);
  static const outline = Color(0xFFEAE3F4);

  static const avatarColors = [
    Color(0xFFE6DDFB),
    Color(0xFFDDF2EA),
    Color(0xFFFDE6DD),
    Color(0xFFFCE3EA),
    Color(0xFFE3EEFB),
    Color(0xFFFBF1D6),
  ];

  static const heroGradient = LinearGradient(
    colors: [Color(0xFFE9E1FB), Color(0xFFFBE3EC), Color(0xFFFDEBDF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class ChipColors {
  const ChipColors(this.background, this.foreground);

  final Color background;
  final Color foreground;
}

extension TaskStatusStyle on TaskStatus {
  ChipColors get colors => switch (this) {
        TaskStatus.todo => const ChipColors(Pastel.skyLight, Pastel.skyDeep),
        TaskStatus.inProgress => const ChipColors(Pastel.peachLight, Pastel.peachDeep),
        TaskStatus.done => const ChipColors(Pastel.mintLight, Pastel.mintDeep),
        TaskStatus.cancelled => const ChipColors(Pastel.mauveLight, Pastel.mauveDeep),
      };

  IconData get icon => switch (this) {
        TaskStatus.todo => Icons.radio_button_unchecked_rounded,
        TaskStatus.inProgress => Icons.timelapse_rounded,
        TaskStatus.done => Icons.check_circle_outline_rounded,
        TaskStatus.cancelled => Icons.block_rounded,
      };
}

extension TaskPriorityStyle on TaskPriority {
  ChipColors get colors => switch (this) {
        TaskPriority.low => const ChipColors(Pastel.mintLight, Pastel.mintDeep),
        TaskPriority.medium => const ChipColors(Pastel.skyLight, Pastel.skyDeep),
        TaskPriority.high => const ChipColors(Pastel.butterLight, Pastel.butterDeep),
        TaskPriority.critical => const ChipColors(Pastel.roseLight, Pastel.roseDeep),
      };

  /// Насыщенный (но всё ещё мягкий) цвет для полос графиков.
  Color get barColor => switch (this) {
        TaskPriority.low => Pastel.mint,
        TaskPriority.medium => Pastel.sky,
        TaskPriority.high => Pastel.butter,
        TaskPriority.critical => Pastel.rose,
      };

  IconData get icon => switch (this) {
        TaskPriority.low => Icons.keyboard_double_arrow_down_rounded,
        TaskPriority.medium => Icons.drag_handle_rounded,
        TaskPriority.high => Icons.keyboard_arrow_up_rounded,
        TaskPriority.critical => Icons.priority_high_rounded,
      };
}

extension ProjectStatusStyle on ProjectStatus {
  ChipColors get colors => switch (this) {
        ProjectStatus.active => const ChipColors(Pastel.lavenderLight, Pastel.lavenderDeep),
        ProjectStatus.completed => const ChipColors(Pastel.mintLight, Pastel.mintDeep),
        ProjectStatus.archived => const ChipColors(Pastel.mauveLight, Pastel.mauveDeep),
      };
}

extension ProjectRoleStyle on ProjectRole {
  ChipColors get colors => switch (this) {
        ProjectRole.owner => const ChipColors(Pastel.roseLight, Pastel.roseDeep),
        ProjectRole.admin => const ChipColors(Pastel.peachLight, Pastel.peachDeep),
        ProjectRole.member => const ChipColors(Pastel.skyLight, Pastel.skyDeep),
      };
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: Pastel.lavender).copyWith(
      primary: Pastel.lavender,
      onPrimary: Colors.white,
      primaryContainer: Pastel.lavenderLight,
      onPrimaryContainer: Pastel.lavenderDeep,
      secondary: Pastel.mint,
      onSecondary: Colors.white,
      secondaryContainer: Pastel.mintLight,
      onSecondaryContainer: Pastel.mintDeep,
      tertiary: Pastel.peach,
      onTertiary: Colors.white,
      tertiaryContainer: Pastel.peachLight,
      onTertiaryContainer: Pastel.peachDeep,
      error: const Color(0xFFD06A7C),
      onError: Colors.white,
      errorContainer: Pastel.roseLight,
      onErrorContainer: Pastel.roseDeep,
      surface: Pastel.background,
      onSurface: Pastel.ink,
      onSurfaceVariant: Pastel.inkSoft,
      outline: const Color(0xFFD9CFE8),
      outlineVariant: Pastel.outline,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFFBF9FE),
      surfaceContainer: const Color(0xFFF5F1FB),
      surfaceContainerHigh: const Color(0xFFF2EDF9),
      surfaceContainerHighest: const Color(0xFFECE6F5),
    );

    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Pastel.background,
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: Pastel.lavenderLight,
        side: const BorderSide(color: Pastel.outline),
        shape: const StadiumBorder(),
        labelStyle: const TextStyle(color: Pastel.ink, fontWeight: FontWeight.w500),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Pastel.lavenderLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Pastel.ink),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Pastel.lavenderLight,
        foregroundColor: Pastel.lavenderDeep,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: rounded,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: rounded,
          side: const BorderSide(color: Pastel.outline),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: rounded, foregroundColor: Pastel.lavenderDeep),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Pastel.lavenderDeep,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: const DividerThemeData(color: Pastel.outline, space: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: Pastel.lavender),
    );
  }
}
