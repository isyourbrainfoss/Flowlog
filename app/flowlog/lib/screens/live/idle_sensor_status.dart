import 'dart:async';

import 'package:flowlog/screens/live/auto_start.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:flutter/material.dart' hide ConnectionState;

/// How long a pressure reading stays LIVE on the idle card.
///
/// Kept in sync with [kLivePressureFreshWindow], which also drops leftover
/// values after this window so idle never looks ready with a stale sample.
Duration get kIdlePressureLiveWindow => kLivePressureFreshWindow;

enum _IdleCertainty { live, linking, waiting, off }

/// Idle pressensor status above the Live chart. Hidden while brewing.
class IdleSensorStatus extends StatefulWidget {
  const IdleSensorStatus({
    super.key,
    required this.pressureBarNotifier,
    required this.lastUpdateNotifier,
    required this.pressensorPaired,
    required this.pressensorLinkState,
    required this.onReconnect,
    required this.onPair,
    required this.autoStartEnabled,
    required this.autoStartThreshold,
  });

  final ValueNotifier<double?> pressureBarNotifier;
  final ValueNotifier<DateTime?> lastUpdateNotifier;
  final bool pressensorPaired;
  final ConnectionState pressensorLinkState;
  final VoidCallback onReconnect;
  final VoidCallback onPair;
  final bool autoStartEnabled;
  final double autoStartThreshold;

  @override
  State<IdleSensorStatus> createState() => _IdleSensorStatusState();
}

class _IdleSensorStatusState extends State<IdleSensorStatus> {
  Timer? _staleTimer;

  @override
  void dispose() {
    _staleTimer?.cancel();
    super.dispose();
  }

  void _armStaleTimer(DateTime? lastUpdate) {
    _staleTimer?.cancel();
    _staleTimer = null;
    if (lastUpdate == null) {
      return;
    }
    final remaining =
        kIdlePressureLiveWindow - DateTime.now().difference(lastUpdate);
    if (remaining <= Duration.zero || remaining > kIdlePressureLiveWindow) {
      return;
    }
    _staleTimer = Timer(remaining + const Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() {});
      }
    });
  }

  bool _isLive(double? pressure, DateTime? lastUpdate) {
    if (pressure == null || lastUpdate == null) {
      return false;
    }
    return DateTime.now().difference(lastUpdate) <= kIdlePressureLiveWindow;
  }

  _IdleCertainty _certainty({
    required bool isLive,
    required bool linkConnected,
    required bool linkConnecting,
  }) {
    if (linkConnecting) {
      return _IdleCertainty.linking;
    }
    if (isLive && linkConnected) {
      return _IdleCertainty.live;
    }
    if (linkConnected) {
      return _IdleCertainty.waiting;
    }
    return _IdleCertainty.off;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final paired = widget.pressensorPaired;
    final link = widget.pressensorLinkState;
    final linkConnected = link == ConnectionState.connected;
    final linkConnecting = link == ConnectionState.connecting;

    return ValueListenableBuilder<double?>(
      valueListenable: widget.pressureBarNotifier,
      builder: (context, pressure, _) {
        return ValueListenableBuilder<DateTime?>(
          valueListenable: widget.lastUpdateNotifier,
          builder: (context, lastUpdate, _) {
            _armStaleTimer(lastUpdate);
            final isLive = _isLive(pressure, lastUpdate);
            final certainty = _certainty(
              isLive: isLive,
              linkConnected: linkConnected,
              linkConnecting: linkConnecting,
            );

            final Color color;
            final Color onColor;
            final Color chipBackground;
            final Color chipForeground;
            switch (certainty) {
              case _IdleCertainty.live:
                color = cs.primaryContainer;
                onColor = cs.onPrimaryContainer;
                chipBackground = cs.primary;
                chipForeground = cs.onPrimary;
              case _IdleCertainty.linking:
              case _IdleCertainty.waiting:
                color = cs.secondaryContainer;
                onColor = cs.onSecondaryContainer;
                chipBackground = cs.secondary;
                chipForeground = cs.onSecondary;
              case _IdleCertainty.off:
                color = cs.errorContainer;
                onColor = cs.onErrorContainer;
                chipBackground = cs.error;
                chipForeground = cs.onError;
            }

            final String chipLabel;
            final String digit;
            final String semanticsLabel;
            final String subtitle;
            switch (certainty) {
              case _IdleCertainty.live:
                chipLabel = 'LIVE';
                digit = pressure!.toStringAsFixed(2);
                semanticsLabel = 'Live pressure $digit bar';
                subtitle = widget.autoStartEnabled
                    ? 'Auto-start at ${widget.autoStartThreshold.toStringAsFixed(1)} bar · ready for new shot'
                    : 'ready for new shot';
              case _IdleCertainty.linking:
                chipLabel = 'LINKING';
                digit = '—';
                semanticsLabel = 'waiting for live pressure';
                subtitle = 'Waiting for live pressure';
              case _IdleCertainty.waiting:
                chipLabel = 'WAITING';
                digit = '—';
                semanticsLabel = 'waiting for live pressure';
                subtitle = 'Pressensor connected · Waiting for live pressure';
              case _IdleCertainty.off:
                chipLabel = 'OFF';
                digit = '—';
                semanticsLabel = 'pressensor off';
                subtitle = paired
                    ? 'Pressensor not connected. Reconnect to start recording.'
                    : 'No pressensor paired';
            }

            final showAction = !linkConnecting;
            final actionLabel = paired
                ? (linkConnected ? 'Refresh' : 'Reconnect')
                : 'Pair sensor';
            final actionKey = paired
                ? const Key('idle_sensor_reconnect')
                : const Key('idle_sensor_pair');

            final digitStyle =
                (theme.textTheme.headlineLarge ??
                        theme.textTheme.headlineMedium)
                    ?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      height: 1.0,
                      color: onColor,
                    );

            return Material(
              key: const Key('idle_sensor_status'),
              color: color,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Flexible(
                                child: Semantics(
                                  label: semanticsLabel,
                                  child: Text(
                                    digit,
                                    key: const Key('idle_live_pressure_digit'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: digitStyle,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              ExcludeSemantics(
                                child: Text(
                                  'bar',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: onColor.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: onColor.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ExcludeSemantics(
                          child: Container(
                            key: const Key('idle_sensor_certainty_chip'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: chipBackground,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              chipLabel,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: chipForeground,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ),
                        if (showAction) ...[
                          const SizedBox(height: 6),
                          OutlinedButton(
                            key: actionKey,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: onColor,
                              side: BorderSide(
                                color: onColor.withValues(alpha: 0.5),
                              ),
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            onPressed: paired
                                ? widget.onReconnect
                                : widget.onPair,
                            child: Text(actionLabel),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
