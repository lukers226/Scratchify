import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'scratch_state.dart';

/// Painter for the scratch card overlay.
///
/// Rendering order inside the [Canvas.saveLayer]:
///   1. Draw the full overlay rect (color / image / gradient).
///   2. Erase scratched regions with [BlendMode.clear].
///
/// Because [BlendMode.clear] operates only within the saveLayer, the animation
/// widget below the [CustomPaint] is never touched — it is a completely
/// separate Flutter render object.
class ScratchPainter extends CustomPainter {
  final List<ScratchPoint> points;
  final Color color;
  final ui.Image? overlayImage;
  final double brushSize;
  final Gradient? gradient;

  ScratchPainter({
    required this.points,
    required this.brushSize,
    this.color = Colors.grey,
    this.overlayImage,
    this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // ── Open an isolated compositing layer ──────────────────────────────────
    // Everything drawn inside saveLayer→restore is composited separately, so
    // BlendMode.clear only erases pixels within THIS layer, never affecting the
    // widgets drawn below (animation / child).
    canvas.saveLayer(rect, Paint());

    // ── Step 1: Draw the scratch overlay ────────────────────────────────────
    if (gradient != null) {
      canvas.drawRect(
        rect,
        Paint()..shader = gradient!.createShader(rect),
      );
    } else if (overlayImage != null) {
      final src = Rect.fromLTWH(
        0,
        0,
        overlayImage!.width.toDouble(),
        overlayImage!.height.toDouble(),
      );
      canvas.drawImageRect(overlayImage!, src, rect, Paint());
    } else {
      canvas.drawRect(rect, Paint()..color = color);
    }

    // ── Step 2: Punch holes with BlendMode.clear ────────────────────────────
    final erasePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = brushSize
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..blendMode = BlendMode.clear;

    Path? currentPath;

    for (final point in points) {
      if (point.isNewPath) {
        // Flush the previous path before starting a new one
        if (currentPath != null) {
          canvas.drawPath(currentPath, erasePaint);
        }
        currentPath = Path()..moveTo(point.offset.dx, point.offset.dy);
      } else {
        currentPath ??= Path()..moveTo(point.offset.dx, point.offset.dy);
        currentPath.lineTo(point.offset.dx, point.offset.dy);
      }
    }

    if (currentPath != null) {
      canvas.drawPath(currentPath, erasePaint);
    }

    canvas.restore(); // Merge composited layer back
  }

  @override
  bool shouldRepaint(covariant ScratchPainter oldDelegate) {
    // Only repaint when the number of points changes — avoids full repaints.
    return oldDelegate.points.length != points.length ||
        oldDelegate.brushSize != brushSize ||
        oldDelegate.color != color ||
        oldDelegate.gradient != gradient ||
        oldDelegate.overlayImage != overlayImage;
  }

  /// No need for a semantics builder on this painter.
  @override
  bool shouldRebuildSemantics(covariant ScratchPainter oldDelegate) => false;
}
