import 'package:flutter/material.dart';

/// Represents a single scratch point or a line segment.
class ScratchPoint {
  /// The position of the point.
  final Offset offset;

  /// Whether this point starts a new line segment.
  final bool isNewPath;

  const ScratchPoint(this.offset, {this.isNewPath = false});
}

/// Internal state for the scratch card.
class ScratchState extends ChangeNotifier {
  final List<ScratchPoint> _points = [];
  bool _isRevealed = false;
  double _progress = 0.0;

  /// List of points that have been scratched.
  List<ScratchPoint> get points => List.unmodifiable(_points);

  /// Whether the card has been fully revealed.
  bool get isRevealed => _isRevealed;

  /// Current scratch progress (0.0 to 1.0).
  double get progress => _progress;

  /// Adds a new point to the scratch path.
  void addPoint(Offset offset, {bool isNewPath = false}) {
    if (_isRevealed) return;
    _points.add(ScratchPoint(offset, isNewPath: isNewPath));
    notifyListeners();
  }

  /// Updates the scratch progress.
  void updateProgress(double progress) {
    if (_progress != progress) {
      _progress = progress;
      notifyListeners();
    }
  }

  /// Sets the revealed state.
  void setRevealed(bool revealed) {
    if (_isRevealed != revealed) {
      _isRevealed = revealed;
      if (revealed) {
        _progress = 1.0;
      }
      notifyListeners();
    }
  }

  /// Resets the scratch state.
  void reset() {
    _points.clear();
    _isRevealed = false;
    _progress = 0.0;
    notifyListeners();
  }
}
