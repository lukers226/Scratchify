import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_scratch_card/src/scratch_progress_tracker.dart';
import 'dart:ui';

void main() {
  group('ScratchProgressTracker Tests', () {
    test('Initial progress should be 0.0', () {
      final tracker = ScratchProgressTracker(rows: 10, cols: 10);
      expect(tracker.progress, 0.0);
    }
    );

    test('Progress increases after adding points', () {
      final tracker = ScratchProgressTracker(rows: 10, cols: 10);
      const widgetSize = Size(100, 100);
      
      // Scratch the top-left corner
      tracker.addPoint(const Offset(5, 5), 20.0, widgetSize);
      
      expect(tracker.progress, greaterThan(0.0));
      expect(tracker.progress, lessThan(1.0));
    });

    test('revealAll sets progress to 1.0', () {
      final tracker = ScratchProgressTracker(rows: 10, cols: 10);
      tracker.revealAll();
      expect(tracker.progress, 1.0);
    });

    test('reset sets progress back to 0.0', () {
      final tracker = ScratchProgressTracker(rows: 10, cols: 10);
      tracker.revealAll();
      tracker.reset();
      expect(tracker.progress, 0.0);
    });
  });
}
