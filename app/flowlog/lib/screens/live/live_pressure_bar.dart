import 'package:flutter/material.dart';

/// A live horizontal deviation bar for pressure vs target.
///
/// Center (green) represents the target pressure.
/// Red on left = too low, red on right = too high.
/// The marker shows the current pressure position.
class LivePressureDeviationBar extends StatelessWidget {
  const LivePressureDeviationBar({
    required this.currentPressure,
    required this.targetPressure,
    this.range = 2.5, // ± range around target
    this.height = 10.0,
    super.key,
  });

  final double? currentPressure;
  final double? targetPressure;

  /// Deviation range shown on each side of target (in bar).
  final double range;

  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = currentPressure ?? 0.0;
    final target = targetPressure ?? 9.0;

    final deviation = current - target;
    final normalized = ((deviation + range) / (2 * range)).clamp(0.0, 1.0);

    final isDeviating = deviation.abs() > 0.5;
    final markerColor = isDeviating ? Colors.red : Colors.black;

    return SizedBox(
      height: height + 4,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background bar with gradient
          Container(
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2),
              gradient: const LinearGradient(
                colors: [
                  Colors.red,
                  Colors.orange,
                  Colors.green,
                  Colors.orange,
                  Colors.red,
                ],
                stops: [0.0, 0.35, 0.5, 0.65, 1.0],
              ),
              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
            ),
          ),
          // Center target marker (thin green line)
          Container(
            height: height,
            width: 2,
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          // Current value marker
          Align(
            alignment: Alignment((normalized * 2 - 1).toDouble(), 0),
            child: Container(
              width: 3,
              height: height + 4,
              decoration: BoxDecoration(
                color: markerColor,
                borderRadius: BorderRadius.circular(1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
