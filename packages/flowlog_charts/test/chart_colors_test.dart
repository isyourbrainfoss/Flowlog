import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlowlogChartColors', () {
    tearDown(() {
      FlowlogChartColors.palette = FlowlogChartPalette.coffee;
    });

    test('coffee palette exposes warm line colors', () {
      FlowlogChartColors.palette = FlowlogChartPalette.coffee;

      expect(FlowlogChartColors.pressureLine, FlowlogChartColors.coffeePressureLine);
      expect(FlowlogChartColors.weightLine, FlowlogChartColors.coffeeWeightLine);
      expect(FlowlogChartColors.flowLine, FlowlogChartColors.coffeeFlowLine);
    });

    test('colorblind-safe palette exposes distinct line colors', () {
      FlowlogChartColors.palette = FlowlogChartPalette.colorblindSafe;

      expect(
        FlowlogChartColors.pressureLine,
        FlowlogChartColors.colorblindPressureLine,
      );
      expect(
        FlowlogChartColors.weightLine,
        FlowlogChartColors.colorblindWeightLine,
      );
      expect(
        FlowlogChartColors.flowLine,
        FlowlogChartColors.colorblindFlowLine,
      );

      final lineColors = {
        FlowlogChartColors.pressureLine,
        FlowlogChartColors.weightLine,
        FlowlogChartColors.flowLine,
      };
      expect(lineColors.length, 3);
    });

    test('ChartSurfaceStyle uses light theme surface in café mode', () {
      final scheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF6F4E37),
        brightness: Brightness.light,
        surface: const Color(0xFFEDE6DC),
        outline: const Color(0xFF8A7B6E),
      );

      final style = ChartSurfaceStyle.fromColorScheme(scheme);

      expect(style.background, scheme.surface);
      expect(style.grid, scheme.outline);
      expect(style.axisLabel, scheme.onSurfaceVariant);
      expect(style.background, isNot(FlowlogChartColors.background));
    });

    test('palette switch updates active getters', () {
      FlowlogChartColors.palette = FlowlogChartPalette.coffee;
      final coffeePressure = FlowlogChartColors.pressureLine;

      FlowlogChartColors.palette = FlowlogChartPalette.colorblindSafe;
      final colorblindPressure = FlowlogChartColors.pressureLine;

      expect(coffeePressure, isNot(colorblindPressure));
      expect(coffeePressure, const Color(0xFFD4923A));
      expect(colorblindPressure, const Color(0xFFD55E00));
    });
  });
}