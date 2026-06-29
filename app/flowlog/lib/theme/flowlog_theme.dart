import 'package:flutter/material.dart';

/// Warm coffee palette tokens (libadwaita-inspired).
abstract final class FlowlogColors {
  // Shared accents
  static const crema = Color(0xFFC4A574);
  static const espresso = Color(0xFF6F4E37);

  // coffeeDark
  static const backgroundDark = Color(0xFF1A140F);
  static const surfaceDark = Color(0xFF241C16);
  static const onBackgroundDark = Color(0xFFF5F0E8);

  // cafeLight
  static const backgroundLight = Color(0xFFF5F0E8);
  static const surfaceLight = Color(0xFFEDE6DC);
  static const onBackgroundLight = Color(0xFF1A140F);

  // Shape tokens
  static const cardRadius = 12.0;
  static const cardElevation = 1.0;
}

/// Flowlog light/dark themes.
abstract final class FlowlogTheme {
  static ThemeData get coffeeDark => _buildTheme(
        brightness: Brightness.dark,
        background: FlowlogColors.backgroundDark,
        surface: FlowlogColors.surfaceDark,
        onBackground: FlowlogColors.onBackgroundDark,
        primary: FlowlogColors.crema,
        onPrimary: FlowlogColors.backgroundDark,
        secondary: FlowlogColors.espresso,
        onSecondary: FlowlogColors.onBackgroundDark,
        primaryContainer: FlowlogColors.espresso,
        onPrimaryContainer: FlowlogColors.onBackgroundDark,
        secondaryContainer: const Color(0xFF3D2E24),
        onSecondaryContainer: FlowlogColors.crema,
        outline: const Color(0xFF8A7B6E),
        onSurfaceVariant: const Color(0xFFD4C9BC),
      );

  static ThemeData get cafeLight => _buildTheme(
        brightness: Brightness.light,
        background: FlowlogColors.backgroundLight,
        surface: FlowlogColors.surfaceLight,
        onBackground: FlowlogColors.onBackgroundLight,
        primary: FlowlogColors.espresso,
        onPrimary: FlowlogColors.backgroundLight,
        secondary: FlowlogColors.crema,
        onSecondary: FlowlogColors.onBackgroundLight,
        primaryContainer: const Color(0xFFE8D9C4),
        onPrimaryContainer: FlowlogColors.onBackgroundLight,
        secondaryContainer: const Color(0xFFF0E6D6),
        onSecondaryContainer: FlowlogColors.espresso,
        outline: const Color(0xFF8A7B6E),
        onSurfaceVariant: const Color(0xFF5C4A3A),
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color onBackground,
    required Color primary,
    required Color onPrimary,
    required Color secondary,
    required Color onSecondary,
    required Color primaryContainer,
    required Color onPrimaryContainer,
    required Color secondaryContainer,
    required Color onSecondaryContainer,
    required Color outline,
    required Color onSurfaceVariant,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: secondary,
      onSecondary: onSecondary,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: onSecondaryContainer,
      tertiary: FlowlogColors.crema,
      onTertiary: FlowlogColors.backgroundDark,
      error: const Color(0xFFCF6679),
      onError: Colors.black,
      surface: surface,
      onSurface: onBackground,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      outlineVariant: outline.withValues(alpha: 0.4),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: onBackground,
      onInverseSurface: background,
      inversePrimary: secondary,
      surfaceTint: primary,
    );

    final baseTextTheme = Typography.material2021(
      platform: TargetPlatform.linux,
    ).black;

    final textTheme = brightness == Brightness.dark
        ? baseTextTheme.apply(
            bodyColor: onBackground,
            displayColor: onBackground,
          )
        : baseTextTheme.apply(
            bodyColor: onBackground,
            displayColor: onBackground,
          );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onBackground,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: FlowlogColors.cardElevation,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FlowlogColors.cardRadius),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.24),
        selectedIconTheme: IconThemeData(color: primary),
        unselectedIconTheme: IconThemeData(
          color: onSurfaceVariant,
        ),
        selectedLabelTextStyle: TextStyle(color: primary),
        unselectedLabelTextStyle: TextStyle(color: onSurfaceVariant),
      ),
    );
  }
}

/// Notifies listeners when the user switches between coffee dark and café light.
class FlowlogThemeController extends ChangeNotifier {
  FlowlogThemeController({
    ThemeMode themeMode = ThemeMode.dark,
    bool highContrast = false,
  })  : _themeMode = themeMode,
        _highContrast = highContrast;

  ThemeMode _themeMode;
  bool _highContrast;

  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;

  /// Stub flag for a future high-contrast theme; toggled from the More tab.
  bool get highContrast => _highContrast;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) {
      return;
    }
    _themeMode = mode;
    notifyListeners();
  }

  void setHighContrast(bool enabled) {
    if (_highContrast == enabled) {
      return;
    }
    _highContrast = enabled;
    notifyListeners();
  }
}

/// Provides [FlowlogThemeController] to descendants (e.g. More tab appearance toggle).
class FlowlogThemeScope extends InheritedNotifier<FlowlogThemeController> {
  const FlowlogThemeScope({
    super.key,
    required FlowlogThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static FlowlogThemeController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<FlowlogThemeScope>();
    assert(scope != null, 'FlowlogThemeScope not found in widget tree');
    return scope!.notifier!;
  }
}