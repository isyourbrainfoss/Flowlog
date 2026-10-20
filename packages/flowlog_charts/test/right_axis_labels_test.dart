import 'package:flowlog_charts/src/dual_curve_chart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('layoutRightAxisLabels', () {
    test('tall chart keeps every tick label', () {
      final labels = layoutRightAxisLabels(
        plotTop: 16,
        plotBottom: 216,
        maxValue: 50,
        step: 10,
        reservedLabelTops: const [2],
      );
      expect(labels.map((l) => l.value), [10, 20, 30, 40]);
    });

    test('short chart drops labels that would overlap', () {
      // 40 px plot: 10 g steps are 8 px apart, less than a 9 pt label.
      final labels = layoutRightAxisLabels(
        plotTop: 16,
        plotBottom: 56,
        maxValue: 50,
        step: 10,
        reservedLabelTops: const [2],
      );
      expect(labels, isNotEmpty);
      for (var i = 1; i < labels.length; i++) {
        expect(
          (labels[i].top - labels[i - 1].top).abs(),
          greaterThanOrEqualTo(11),
        );
      }
      // Never collides with the "g" unit caption at the top.
      for (final label in labels) {
        expect((label.top - 2).abs(), greaterThanOrEqualTo(11));
      }
      // Lowest value wins.
      expect(labels.first.value, 10);
    });

    test('skips the label under the mid-plot g/s caption', () {
      const top = 16.0;
      const bottom = 116.0;
      const center = (top + bottom) / 2;
      final labels = layoutRightAxisLabels(
        plotTop: top,
        plotBottom: bottom,
        maxValue: 40,
        step: 10,
        reservedLabelTops: const [2, center],
      );
      for (final label in labels) {
        expect((label.top - center).abs(), greaterThanOrEqualTo(11));
      }
      expect(labels.map((l) => l.value), isNot(contains(20)));
    });

    test('degenerate inputs give no labels', () {
      expect(
        layoutRightAxisLabels(plotTop: 0, plotBottom: 0, maxValue: 10, step: 1),
        isEmpty,
      );
      expect(
        layoutRightAxisLabels(
          plotTop: 0,
          plotBottom: 100,
          maxValue: 0,
          step: 1,
        ),
        isEmpty,
      );
    });
  });
}
