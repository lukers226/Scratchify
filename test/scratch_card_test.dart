import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_scratch_card/flutter_scratch_card.dart';

void main() {
  group('ScratchCard Widget Tests', () {
    testWidgets('ScratchCard renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ScratchCard(
              width: 200,
              height: 200,
              child: Text('Hidden Text'),
            ),
          ),
        ),
      );

      // Verify the child widget exists but might be covered
      expect(find.text('Hidden Text'), findsOneWidget);
    });

    testWidgets('ScratchCard updates progress on drag', (WidgetTester tester) async {
      double? progressValue;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScratchCard(
              width: 100,
              height: 100,
              onProgress: (v) => progressValue = v,
              child: const SizedBox(width: 50, height: 50),
            ),
          ),
        ),
      );

      // Perform a drag from (10, 10) to (50, 50)
      final gesture = await tester.startGesture(const Offset(10, 10));
      await gesture.moveTo(const Offset(50, 50));
      await tester.pump();

      expect(progressValue, isNotNull);
      expect(progressValue!, greaterThan(0.0));
      
      await gesture.up();
    });

    testWidgets('onThreshold fires when reached', (WidgetTester tester) async {
      bool thresholdReached = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScratchCard(
              width: 100,
              height: 100,
              threshold: 0.1, // Small threshold for easy testing
              autoReveal: true,
              onThreshold: () => thresholdReached = true,
              child: const SizedBox(width: 50, height: 50),
            ),
          ),
        ),
      );

      // Perform enough scratching to cross the small threshold
      final gesture = await tester.startGesture(const Offset(0, 0));
      for (double i = 0; i <= 100; i += 10) {
        await gesture.moveTo(Offset(i, 10));
        await tester.pumpAndSettle();
      }
      expect(thresholdReached, isTrue);
      await gesture.up();
    });

    testWidgets('progressTriggers fire once', (WidgetTester tester) async {
      List<double> firedTriggers = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScratchCard(
              width: 100,
              height: 100,
              progressTriggers: const [0.25, 0.5], // Higher triggers
              onProgressTrigger: (v) => firedTriggers.add(v),
              child: const SizedBox(width: 50, height: 50),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(0, 0));
      // Scratch across the top
      for (double i = 0; i <= 100; i += 10) {
        await gesture.moveTo(Offset(i, 10));
        await tester.pumpAndSettle();
      }
      expect(firedTriggers.length, greaterThanOrEqualTo(1));
      
      // Scratch across the middle
      for (double i = 0; i <= 100; i += 10) {
        await gesture.moveTo(Offset(i, 50));
        await tester.pumpAndSettle();
      }
      expect(firedTriggers.length, greaterThanOrEqualTo(2));
      
      await gesture.up();
    });
  });
}
