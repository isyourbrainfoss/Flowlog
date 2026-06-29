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