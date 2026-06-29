import 'dart:math' as math;

import 'package:flowlog/screens/live/controls.dart';
import 'package:flowlog/screens/live/metrics_row.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// Default target yield used to normalize bean fill progress.
const double kDefaultTargetYieldG = 36.0;

/// Returns bean fill progress in `[0, 1]` from current yield and elapsed time.
///
/// Progress is the average of normalized yield and elapsed time against their
/// respective targets.
double beanFillProgress({
  required double? yieldG,
  required int elapsedMs,
  double targetYieldG = kDefaultTargetYieldG,
  int targetDurationMs = LiveMetrics.defaultTargetDurationMs,
}) {
  if (targetYieldG <= 0 || targetDurationMs <= 0) {
    return 0;
  }

  final yieldProgress = ((yieldG ?? 0) / targetYieldG).clamp(0.0, 1.0);
  final timeProgress = (elapsedMs / targetDurationMs).clamp(0.0, 1.0);
  return ((yieldProgress + timeProgress) / 2).clamp(0.0, 1.0);
}

/// Returns the highest recorded taste score, or `null` when none exist.
Future<int?> fetchBestTasteScore(ShotRepository repository) async {
  final shots = await repository.listShots();
  int? best;

  for (final shot in shots) {
    final score = shot.tasteScore;
    if (score == null) {
      continue;
    }
    if (best == null || score > best) {
      best = score;
    }
  }

  return best;
}

/// Whether [tasteScore] beats the previous personal best.
bool isPersonalBestTasteScore({
  required int? tasteScore,
  required int? previousBest,
}) {
  if (tasteScore == null) {
    return false;
  }
  return previousBest == null || tasteScore > previousBest;
}

/// Coffee bean icon that fills from the bottom as [progress] approaches 1.
class BeanFillIcon extends StatelessWidget {
  const BeanFillIcon({
    required this.progress,
    this.size = 40,
    super.key,
  });

  final double progress;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final clamped = progress.clamp(0.0, 1.0);

    return Semantics(
      label: 'Bean fill ${(clamped * 100).round()} percent',
      child: SizedBox(
        key: const Key('bean_fill_icon'),
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.coffee_outlined,
              size: size,
              color: scheme.onSurfaceVariant,
            ),
            ClipRect(
              child: Align(
                alignment: Alignment.bottomCenter,
                heightFactor: clamped,
                child: Icon(
                  Icons.coffee,
                  size: size,
                  color: scheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bean fill indicator driven by a live [LiveShotController] session.
class RecordingBeanFillIndicator extends StatelessWidget {
  const RecordingBeanFillIndicator({
    required this.controller,
    this.targetYieldG = kDefaultTargetYieldG,
    this.targetDurationMs = LiveMetrics.defaultTargetDurationMs,
    super.key,
  });

  final LiveShotController controller;
  final double targetYieldG;
  final int targetDurationMs;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.sessionState;
        final isActive = state == ShotSessionState.recording ||
            state == ShotSessionState.paused;

        if (!isActive) {
          return const SizedBox.shrink();
        }

        final samples = controller.samples;
        final latest = samples.isEmpty ? null : samples.last;
        final progress = beanFillProgress(
          yieldG: latest?.weightG,
          elapsedMs: latest?.elapsedMs ?? 0,
          targetYieldG: targetYieldG,
          targetDurationMs: targetDurationMs,
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BeanFillIcon(progress: progress),
              const SizedBox(width: 8),
              Text(
                '${(progress * 100).round()}%',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Triggers a short confetti burst via [burst].
class ConfettiController extends ChangeNotifier {
  int _burstGeneration = 0;

  int get burstGeneration => _burstGeneration;

  void burst() {
    _burstGeneration++;
    notifyListeners();
  }
}

/// Full-screen confetti overlay that listens to [controller].
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({
    required this.child,
    this.controller,
    super.key,
  });

  final Widget child;
  final ConfettiController? controller;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  ConfettiController? _controller;
  int _lastBurstGeneration = 0;
  List<_ConfettiParticle> _particles = const [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _particles = const []);
        }
      });
    _attachController(widget.controller);
  }

  @override
  void didUpdateWidget(ConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detachController(oldWidget.controller);
      _attachController(widget.controller);
    }
  }

  void _attachController(ConfettiController? controller) {
    _controller = controller;
    _lastBurstGeneration = controller?.burstGeneration ?? 0;
    controller?.addListener(_onBurstRequested);
  }

  void _detachController(ConfettiController? controller) {
    controller?.removeListener(_onBurstRequested);
  }

  void _onBurstRequested() {
    final controller = _controller;
    if (controller == null ||
        controller.burstGeneration == _lastBurstGeneration) {
      return;
    }

    _lastBurstGeneration = controller.burstGeneration;
    _startBurst();
  }

  void _startBurst() {
    final random = math.Random();
    final colors = <Color>[
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.tertiary,
      Colors.amber,
      Colors.orange,
    ];

    setState(() {
      _particles = List.generate(28, (index) {
        final color = colors[index % colors.length];
        final startX = random.nextDouble();
        final startY = -0.05 - random.nextDouble() * 0.1;
        final dx = (random.nextDouble() - 0.5) * 0.35;
        final dy = 0.55 + random.nextDouble() * 0.45;
        final size = 6 + random.nextDouble() * 6;
        return _ConfettiParticle(
          color: color,
          startX: startX,
          startY: startY,
          dx: dx,
          dy: dy,
          size: size,
          rotation: random.nextDouble() * math.pi,
        );
      });
    });

    _animationController
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _detachController(_controller);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_particles.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, _) {
                  return CustomPaint(
                    key: const Key('confetti_overlay'),
                    painter: _ConfettiPainter(
                      particles: _particles,
                      progress: _animationController.value,
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

@immutable
class _ConfettiParticle {
  const _ConfettiParticle({
    required this.color,
    required this.startX,
    required this.startY,
    required this.dx,
    required this.dy,
    required this.size,
    required this.rotation,
  });

  final Color color;
  final double startX;
  final double startY;
  final double dx;
  final double dy;
  final double size;
  final double rotation;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({
    required this.particles,
    required this.progress,
  });

  final List<_ConfettiParticle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final x = (particle.startX + particle.dx * progress) * size.width;
      final y = (particle.startY + particle.dy * progress) * size.height;
      final paint = Paint()..color = particle.color.withValues(alpha: 1 - progress);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(particle.rotation + progress * math.pi * 2);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: particle.size,
          height: particle.size * 0.6,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.particles != particles;
  }
}

/// Bursts confetti when [shot] sets a new personal-best taste score.
Future<void> celebratePersonalBestTasteScore({
  required ShotRepository repository,
  required Shot? shot,
  required ConfettiController confettiController,
}) async {
  if (shot == null) {
    return;
  }

  final contenders = await repository.listShots();
  final previousBest = _bestTasteScore(
    contenders.where((candidate) => candidate.id != shot.id),
  );

  if (isPersonalBestTasteScore(
    tasteScore: shot.tasteScore,
    previousBest: previousBest,
  )) {
    confettiController.burst();
  }
}

int? _bestTasteScore(Iterable<Shot> shots) {
  int? best;
  for (final shot in shots) {
    final score = shot.tasteScore;
    if (score == null) {
      continue;
    }
    if (best == null || score > best) {
      best = score;
    }
  }
  return best;
}