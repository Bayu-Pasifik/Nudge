import 'package:material_ui/material_ui.dart';

/// Design tokens from docs/STYLE.md. Single source of truth for colors,
/// spacing, radius and text styles.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.bgApp,
    required this.bgSurface,
    required this.bgList,
    required this.bgHover,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.border,
    required this.accent,
    required this.accentHover,
    required this.accentSoft,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final Color bgApp;
  final Color bgSurface;
  final Color bgList;
  final Color bgHover;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color border;
  final Color accent;
  final Color accentHover;
  final Color accentSoft;
  final Color success;
  final Color warning;
  final Color danger;

  static const light = AppTokens(
    bgApp: Color(0xFFF6F3EE),
    bgSurface: Color(0xFFFFFFFF),
    bgList: Color(0xFFEDE9E1),
    bgHover: Color(0xFFE4DFD5),
    textPrimary: Color(0xFF1E1B16),
    textSecondary: Color(0xFF6B655A),
    textDisabled: Color(0xFFA8A196),
    border: Color(0xFFDDD7CB),
    accent: Color(0xFF3B5BDB),
    accentHover: Color(0xFF2F49B5),
    accentSoft: Color(0xFFE3E9FD),
    success: Color(0xFF2F9E62),
    warning: Color(0xFFD98A0B),
    danger: Color(0xFFD63C3C),
  );

  static const dark = AppTokens(
    bgApp: Color(0xFF141310),
    bgSurface: Color(0xFF1F1D19),
    bgList: Color(0xFF191814),
    bgHover: Color(0xFF2A2823),
    textPrimary: Color(0xFFF2EEE6),
    textSecondary: Color(0xFFA9A294),
    textDisabled: Color(0xFF6B655A),
    border: Color(0xFF33302A),
    accent: Color(0xFF7C97FF),
    accentHover: Color(0xFF9DB1FF),
    accentSoft: Color(0xFF22294A),
    success: Color(0xFF4CC38A),
    warning: Color(0xFFF0A93A),
    danger: Color(0xFFFF6B6B),
  );

  @override
  AppTokens copyWith() => this;

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppTokens(
      bgApp: l(bgApp, other.bgApp),
      bgSurface: l(bgSurface, other.bgSurface),
      bgList: l(bgList, other.bgList),
      bgHover: l(bgHover, other.bgHover),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textDisabled: l(textDisabled, other.textDisabled),
      border: l(border, other.border),
      accent: l(accent, other.accent),
      accentHover: l(accentHover, other.accentHover),
      accentSoft: l(accentSoft, other.accentSoft),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      danger: l(danger, other.danger),
    );
  }
}

extension AppTokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadius {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
}

/// Sticky note palette (STYLE.md §11).
class StickyColors {
  const StickyColors(this.name, this.fill, this.edge);
  final String name;
  final Color fill;
  final Color edge;

  static const all = [
    StickyColors('yellow', Color(0xFFFFF3B0), Color(0xFFE8D35F)),
    StickyColors('peach', Color(0xFFFFD9C2), Color(0xFFE9A988)),
    StickyColors('mint', Color(0xFFD3F1DE), Color(0xFF8CCBA6)),
    StickyColors('sky', Color(0xFFD6E6FF), Color(0xFF8FB3EE)),
    StickyColors('lavender', Color(0xFFE6DCFA), Color(0xFFB6A2E3)),
  ];

  static StickyColors byName(String? name) =>
      all.firstWhere((c) => c.name == name, orElse: () => all.first);
}

/// Label colors (STYLE.md §2).
const labelColors = <Color>[
  Color(0xFFE5484D),
  Color(0xFFF76B15),
  Color(0xFFF5C400),
  Color(0xFF30A46C),
  Color(0xFF12A594),
  Color(0xFF3E63DD),
  Color(0xFF8E4EC6),
  Color(0xFFE93D82),
];
