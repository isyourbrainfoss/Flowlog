import 'dart:convert';

import 'package:meta/meta.dart';

import '../models/bean.dart';
import '../models/brew_summary.dart';
import '../models/brew_temp.dart';
import '../models/shot.dart';
import '../models/shot_annotation.dart';
import '../models/shot_sample.dart';

/// Optional bean context included in shot AI feedback exports.
@immutable
class ShotAiBeanContext {
  const ShotAiBeanContext({
    this.label,
    this.bean,
  });

  final String? label;
  final Bean? bean;
}

/// Builds clipboard text with brewing instructions plus shot metadata and curve.
String buildShotAiFeedbackClipboardText({
  required Shot shot,
  ShotAiBeanContext? beanContext,
  String? desiredFlavorGoal,
  int maxCurvePoints = 40,
}) {
  final payload = buildShotAiFeedbackPayload(
    shot: shot,
    beanContext: beanContext,
    desiredFlavorGoal: desiredFlavorGoal,
    maxCurvePoints: maxCurvePoints,
  );

  final goalLine = desiredFlavorGoal == null || desiredFlavorGoal.trim().isEmpty
      ? 'My taste goal: (not specified — ask what I am aiming for)'
      : 'My taste goal: ${desiredFlavorGoal.trim()}';

  final encoder = const JsonEncoder.withIndent('  ');
  final jsonBlock = encoder.convert(payload);

  return '''
Here is an espresso shot from Flowlog with brew metadata and a downsampled pressure/weight/flow curve. Please analyze the extraction and suggest specific, practical tweaks to move toward my taste goal.

$goalLine

Focus on dial-in advice tied to the data: dose, yield, ratio, grind, temperature, pressure profile shape, flow behavior, and anything suggested by the curve or notes. Be concise and actionable. If important context is missing, say what you would need.

Answer format:
Reply in plain, readable text (short paragraphs and bullet points are fine). Do not wrap your answer in a code block or JSON.

Structure your reply roughly as:
1. Summary — how the shot likely tasted and extracted
2. Observations — what the curve or metadata suggests
3. Suggested tweaks — specific changes (grind, dose, yield, temp, pressure, pre-infusion, etc.) and why each helps my taste goal
4. Questions — only if you need more context

Shot data (from Flowlog):

```json
$jsonBlock
```
'''.trim();
}

/// Structured shot payload for AI feedback (metadata + downsampled curve).
Map<String, dynamic> buildShotAiFeedbackPayload({
  required Shot shot,
  ShotAiBeanContext? beanContext,
  String? desiredFlavorGoal,
  int maxCurvePoints = 40,
}) {
  final summary = BrewSummary.fromShot(shot);
  final brewTemp = brewTempRangeFromSamples(shot.samples);
  final sortedSamples = List<ShotSample>.from(shot.samples)
    ..sort((a, b) => a.elapsedMs.compareTo(b.elapsedMs));

  return {
    'format': 'flowlog-shot-ai-feedback-v1',
    if (desiredFlavorGoal != null && desiredFlavorGoal.trim().isNotEmpty)
      'desiredFlavorGoal': desiredFlavorGoal.trim(),
    'metadata': _metadataMap(shot),
    'brewSummary': {
      'durationMs': summary.durationMs,
      'durationSec': summary.durationMs / 1000,
      'peakPressureBar': summary.peakPressureBar,
      if (brewTemp.startTempC != null) 'brewStartTempC': brewTemp.startTempC,
      if (brewTemp.endTempC != null) 'brewEndTempC': brewTemp.endTempC,
      if (shot.doseG != null && shot.yieldG != null && shot.doseG! > 0)
        'brewRatio': shot.yieldG! / shot.doseG!,
    },
    if (beanContext != null) 'bean': _beanMap(beanContext),
    if (shot.annotations.isNotEmpty)
      'annotations': shot.annotations.map(_annotationMap).toList(),
    'curve': downsampleShotSamples(sortedSamples, maxPoints: maxCurvePoints),
    'curveLegend': {
      'elapsedMs': 'milliseconds from shot start',
      'pressureBar': 'pressure in bar',
      'weightG': 'scale weight in grams',
      'flowGs': 'flow in g/s when present',
      'tempC': 'temperature in °C when present',
    },
  };
}

Map<String, dynamic> _metadataMap(Shot shot) {
  return {
    'startedAt': shot.startedAt.toUtc().toIso8601String(),
    if (shot.endedAt != null)
      'endedAt': shot.endedAt!.toUtc().toIso8601String(),
    if (shot.doseG != null) 'doseG': shot.doseG,
    if (shot.yieldG != null) 'yieldG': shot.yieldG,
    if (shot.grindSetting != null) 'grindSetting': shot.grindSetting,
    if (shot.waterTempC != null) 'waterTempC': shot.waterTempC,
    if (shot.beanId != null) 'beanId': shot.beanId,
    if (shot.tasteScore != null) 'tasteScore': shot.tasteScore,
    if (shot.flavourTags.isNotEmpty) 'flavourTags': shot.flavourTags,
    if (shot.flavourIntensities.isNotEmpty)
      'flavourIntensities': shot.flavourIntensities,
    if (shot.notes != null && shot.notes!.trim().isNotEmpty) 'notes': shot.notes,
    if (shot.location != null) 'location': shot.location,
    if (shot.coffeejackRewindTurns != null)
      'coffeejackRewindTurns': shot.coffeejackRewindTurns,
    if (shot.coffeejackPreinfusionTurns != null)
      'coffeejackPreinfusionTurns': shot.coffeejackPreinfusionTurns,
  };
}

Map<String, dynamic>? _beanMap(ShotAiBeanContext context) {
  final bean = context.bean;
  final label = context.label;
  if (bean == null && (label == null || label.trim().isEmpty)) {
    return null;
  }

  return {
    if (label != null && label.trim().isNotEmpty) 'displayName': label.trim(),
    if (bean != null) ...{
      'name': bean.name,
      if (bean.brand != null) 'brand': bean.brand,
      if (bean.origin != null) 'origin': bean.origin,
      if (bean.variety != null) 'variety': bean.variety,
      if (bean.process != null) 'process': bean.process,
      if (bean.roastLevel != null) 'roastLevel': bean.roastLevel,
      if (bean.roastDate != null)
        'roastDate': bean.roastDate!.toUtc().toIso8601String().split('T').first,
      if (bean.notes != null) 'beanNotes': bean.notes,
    },
  };
}

Map<String, dynamic> _annotationMap(ShotAnnotation annotation) {
  return {
    'elapsedMs': annotation.elapsedMs,
    'label': annotation.label,
    'type': switch (annotation.type) {
      ShotAnnotationType.channel => 'channel',
      ShotAnnotationType.note => 'note',
    },
  };
}

/// Downsamples [samples] to at most [maxPoints] evenly spaced points.
List<Map<String, dynamic>> downsampleShotSamples(
  List<ShotSample> samples, {
  int maxPoints = 40,
}) {
  if (samples.isEmpty) {
    return const [];
  }
  if (samples.length <= maxPoints) {
    return samples.map(_sampleMap).toList();
  }

  final lastIndex = samples.length - 1;
  final picked = <int>{0, lastIndex};
  final step = lastIndex / (maxPoints - 1);
  for (var i = 1; i < maxPoints - 1; i++) {
    picked.add((step * i).round().clamp(0, lastIndex));
  }

  final indices = picked.toList()..sort();
  return [for (final index in indices) _sampleMap(samples[index])];
}

Map<String, dynamic> _sampleMap(ShotSample sample) {
  return {
    'elapsedMs': sample.elapsedMs,
    if (sample.pressureBar != null) 'pressureBar': sample.pressureBar,
    if (sample.weightG != null) 'weightG': sample.weightG,
    if (sample.flowGs != null) 'flowGs': sample.flowGs,
    if (sample.tempC != null) 'tempC': sample.tempC,
  };
}