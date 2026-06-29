/// Adaptive layout breakpoints from docs/PLAN.md.
abstract final class ShellBreakpoints {
  /// Below this width: bottom navigation bar (phone / narrow).
  static const double sidebar = 600;

  /// Below this height: bottom bar even if wide (avoids rail overflow).
  static const double minRailHeight = 320;

  /// Body must be at least this tall before showing an [AppBar] above content.
  static const double minHeightForAppBar = 88;

  /// Split panels + keyboard shortcuts (future slices).
  static const double splitPanels = 900;
}