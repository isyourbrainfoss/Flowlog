import 'package:flutter/material.dart';

/// Opens a fullscreen dialog route for inspecting a plot in detail.
Future<void> openFullscreenPlot(
  BuildContext context, {
  required WidgetBuilder builder,
  Key? scaffoldKey,
  Key? closeButtonKey,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => FullscreenPlotScaffold(
        scaffoldKey: scaffoldKey,
        closeButtonKey: closeButtonKey,
        child: Builder(builder: builder),
      ),
    ),
  );
}

/// Fullscreen scaffold with a floating minimize control.
class FullscreenPlotScaffold extends StatelessWidget {
  const FullscreenPlotScaffold({
    required this.child,
    this.scaffoldKey,
    this.closeButtonKey,
    this.bottomPadding = 8,
    super.key,
  });

  final Widget child;
  final Key? scaffoldKey;
  final Key? closeButtonKey;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      key: scaffoldKey ?? const Key('fullscreen_plot'),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, bottomPadding),
              child: child,
            ),
            Positioned(
              top: 4,
              left: 4,
              child: Material(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.92),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  key: closeButtonKey ?? const Key('fullscreen_plot_close'),
                  tooltip: 'Minimize chart',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.fullscreen_exit),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Expand control for an embedded plot (often overlaid on the chart corner).
class FullscreenPlotButton extends StatelessWidget {
  const FullscreenPlotButton({
    required this.onPressed,
    this.buttonKey = const Key('fullscreen_plot_open'),
    this.compact = true,
    super.key,
  });

  final VoidCallback? onPressed;
  final Key buttonKey;

  /// When true, paints a compact surface chip suitable for overlay on a chart.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final button = IconButton(
      key: buttonKey,
      tooltip: 'Fullscreen chart',
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.fullscreen),
    );

    if (!compact) {
      return Align(alignment: Alignment.centerRight, child: button);
    }

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      child: button,
    );
  }
}