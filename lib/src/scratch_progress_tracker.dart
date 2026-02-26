import 'dart:ui';
import 'dart:math' as math;

/// Tracks the progress of the scratch card using a grid-based approach.
class ScratchProgressTracker {
  final int rows;
  final int cols;
  late List<bool> _grid;
  int _scratchedCount = 0;

  ScratchProgressTracker({this.rows = 20, this.cols = 20}) {
    _grid = List.filled(rows * cols, false);
  }

  /// Calculates the current progress (0.0 to 1.0).
  double get progress => _scratchedCount / (rows * cols);

  /// Resets the tracker.
  void reset() {
    _grid.fillRange(0, _grid.length, false);
    _scratchedCount = 0;
  }

  /// Marks cells as scratched based on the brush position and size.
  void addPoint(Offset point, double brushSize, Size widgetSize) {
    if (widgetSize.width == 0 || widgetSize.height == 0) return;

    final cellWidth = widgetSize.width / cols;
    final cellHeight = widgetSize.height / rows;
    final radius = brushSize / 2;

    // Calculate the bounding box of the brush in grid coordinates
    final startCol = math.max(0, ((point.dx - radius) / cellWidth).floor());
    final endCol = math.min(cols - 1, ((point.dx + radius) / cellWidth).floor());
    final startRow = math.max(0, ((point.dy - radius) / cellHeight).floor());
    final endRow = math.min(rows - 1, ((point.dy + radius) / cellHeight).floor());

    for (int r = startRow; r <= endRow; r++) {
      for (int c = startCol; c <= endCol; c++) {
        final index = r * cols + c;
        if (!_grid[index]) {
          // Check if the center of the cell is within the brush radius
          final cellCenterX = (c + 0.5) * cellWidth;
          final cellCenterY = (r + 0.5) * cellHeight;
          final distance = (point - Offset(cellCenterX, cellCenterY)).distance;

          if (distance <= radius) {
            _grid[index] = true;
            _scratchedCount++;
          }
        }
      }
    }
  }

  /// Marks all cells as scratched.
  void revealAll() {
    _grid.fillRange(0, _grid.length, true);
    _scratchedCount = rows * cols;
  }
}
