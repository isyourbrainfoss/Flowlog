import 'package:flowlog/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Flowlog home page renders', (tester) async {
    await tester.pumpWidget(const FlowlogApp());

    expect(find.text('Flowlog'), findsOneWidget);
    expect(find.text('Coffee intelligence hub'), findsOneWidget);
    expect(find.byIcon(Icons.coffee), findsOneWidget);
  });
}