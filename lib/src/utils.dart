import 'package:flutter/services.dart';

/// Utility class for haptic feedback and other helper functions.
class ScratchUtils {
  /// Triggers a light impact haptic feedback.
  static Future<void> triggerHaptic() async {
    await HapticFeedback.lightImpact();
  }
}
