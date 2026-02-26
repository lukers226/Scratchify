import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'scratch_painter.dart';
import 'scratch_state.dart';
import 'scratch_controller.dart';
import 'scratch_progress_tracker.dart';
import 'scratch_animation_layer.dart';
import 'utils.dart';

/// A customizable scratch card widget.
///
/// ### Architecture Overview
///
/// The widget uses a three-layer [Stack]:
///
/// ```
///  Layer 3 (top)    ─ [GestureDetector] + [RepaintBoundary] + [CustomPaint]
///                      Scratch overlay drawn here. BlendMode.clear punches
///                      holes only within canvas.saveLayer(), never touching
///                      layers below.
///
///  Layer 2 (middle) ─ [RepaintBoundary] → [ScratchAnimationLayer]
///                      Lottie / GIF + child widget. Isolated in its own
///                      flutter compositing layer so scratching the top layer
///                      NEVER triggers a repaint here. Animation stays at 60fps.
/// ```
///
/// ### Why the child background must be transparent
///
/// When [animationType] is enabled, the animation renders at the bottom of
/// [ScratchAnimationLayer]'s internal [Stack]. The `child` widget floats on
/// top. If the child has an **opaque** background (e.g. `Colors.white`), it
/// blocks the animation. [ScratchCard] wraps the child in a [ColoredBox] check
/// to prevent this — see [_safeChild].
class ScratchCard extends StatefulWidget {
  /// The widget revealed when the scratch overlay is removed.
  final Widget child;

  /// Width of the scratch card.
  final double? width;

  /// Height of the scratch card.
  final double? height;

  /// Diameter of the scratch brush in logical pixels.
  final double brushSize;

  /// Fraction of the card (0.0–1.0) that must be scratched to fire [onThreshold].
  final double threshold;

  /// Solid color of the scratch overlay.
  final Color scratchColor;

  /// Optional raw image used as the scratch overlay instead of [scratchColor].
  ///
  /// Prefer [overlayImageAsset] for a simpler API — pass an asset path string
  /// and the package loads it automatically.
  final ui.Image? overlayImage;

  /// Asset path of an image to use as the scratch overlay texture.
  ///
  /// Example:
  /// ```dart
  /// ScratchCard(
  ///   overlayImageAsset: 'assets/scratch_texture.png',
  ///   child: Text('Prize!'),
  /// )
  /// ```
  ///
  /// The image is loaded asynchronously on init. Until it loads, [scratchColor]
  /// is used as a fallback. If both [overlayImage] and [overlayImageAsset] are
  /// provided, [overlayImage] takes priority.
  final String? overlayImageAsset;

  /// Optional gradient used as the scratch overlay.
  final Gradient? gradient;

  /// Optional controller for programmatic [reveal] / [reset].
  final ScratchController? controller;

  /// If `true`, the card auto-reveals when [threshold] is reached.
  final bool autoReveal;

  /// If `true`, the card auto-reveals when progress exceeds the maximum of [progressTriggers].
  final bool autoRevealOnComplete;

  /// Milestones that fire [onProgressTrigger] once each (e.g. `[0.25, 0.5, 0.75]`).
  final List<double> progressTriggers;

  /// Fired on every progress update with the current progress value (0.0–1.0).
  final ValueChanged<double>? onProgress;

  /// Fired once each time a [progressTriggers] milestone is crossed.
  final ValueChanged<double>? onProgressTrigger;

  /// Fired once when [threshold] is reached.
  final VoidCallback? onThreshold;

  /// Enables haptic feedback during scratching.
  final bool enableHaptics;

  /// Background animation type shown under the scratch layer.
  final ScratchAnimationType animationType;

  /// Asset path for the GIF or Lottie file.
  final String? animationAsset;

  /// Whether the background animation should repeat.
  final bool animationRepeat;

  /// If `true` (default), the background animation widget is removed from the
  /// tree automatically after it finishes playing, preventing the frozen
  /// last-frame artifact. Set to `false` to keep the animation visible.
  final bool removeAnimationOnComplete;

  /// Duration of the final fade-out reveal animation (scratch overlay fade).
  final Duration revealDuration;

  const ScratchCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.brushSize = 30.0,
    this.threshold = 0.5,
    this.scratchColor = Colors.grey,
    this.overlayImage,
    this.overlayImageAsset,
    this.gradient,
    this.controller,
    this.autoReveal = true,
    this.autoRevealOnComplete = true,
    this.progressTriggers = const [],
    this.onProgress,
    this.onProgressTrigger,
    this.onThreshold,
    this.enableHaptics = true,
    this.animationType = ScratchAnimationType.none,
    this.animationAsset,
    this.animationRepeat = true,
    this.removeAnimationOnComplete = true,
    this.revealDuration = const Duration(milliseconds: 500),
  });

  @override
  State<ScratchCard> createState() => _ScratchCardState();
}

class _ScratchCardState extends State<ScratchCard>
    with SingleTickerProviderStateMixin {
  late final ScratchState _state;
  late final ScratchProgressTracker _tracker;

  final Set<double> _firedTriggers = {};
  bool _thresholdFired = false;

  /// True while the background animation (Lottie/GIF) should be playing.
  bool _animationPlaying = false;

  /// Loaded image from [widget.overlayImageAsset]. Null until async load finishes.
  ui.Image? _loadedOverlayImage;

  late final AnimationController _revealController;
  late final Animation<double> _revealAnimation;

  @override
  void initState() {
    super.initState();
    _state = ScratchState();
    _tracker = ScratchProgressTracker();
    widget.controller?.attach(_state);
    _state.addListener(_onStateChange);

    _revealController = AnimationController(
      vsync: this,
      duration: widget.revealDuration,
    );

    // Overlay fades from fully visible (1.0) to invisible (0.0).
    _revealAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _revealController, curve: Curves.easeInOut),
    );

    // Load overlay image from asset path if provided.
    if (widget.overlayImage == null && widget.overlayImageAsset != null) {
      _loadOverlayImage(widget.overlayImageAsset!);
    }
  }

  /// Loads a [ui.Image] from an asset path and triggers a rebuild.
  Future<void> _loadOverlayImage(String assetPath) async {
    try {
      final bytes = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() => _loadedOverlayImage = frame.image);
      }
    } catch (e) {
      // Asset not found or failed to decode — fall back to scratchColor.
      debugPrint('[ScratchCard] Failed to load overlayImageAsset "$assetPath": $e');
    }
  }

  @override
  void dispose() {
    widget.controller?.detach();
    _state.removeListener(_onStateChange);
    _state.dispose();
    _revealController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ScratchCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach();
      widget.controller?.attach(_state);
    }
    // Reload overlay image if the asset path changed.
    if (oldWidget.overlayImageAsset != widget.overlayImageAsset &&
        widget.overlayImage == null &&
        widget.overlayImageAsset != null) {
      _loadedOverlayImage = null;
      _loadOverlayImage(widget.overlayImageAsset!);
    }
  }

  /// Returns the overlay image to use: widget.overlayImage takes priority,
  /// otherwise the asynchronously loaded [_loadedOverlayImage].
  ui.Image? get _resolvedOverlayImage =>
      widget.overlayImage ?? _loadedOverlayImage;

  // ─── State change handler ────────────────────────────────────────────────

  void _onStateChange() {
    if (!mounted) return;

    final progress = _state.progress;

    // ── Forward / reverse the fade-out overlay animation ──────────────────
    if (_state.isRevealed) {
      if (!_revealController.isAnimating && _revealController.value == 0) {
        _revealController.forward();

        // Kick-off background animation — ScratchAnimationLayer self-manages
        // completion/removal via its own AnimationController and status listener.
        if (!_animationPlaying) {
          setState(() => _animationPlaying = true);
        }
      }
    } else {
      if (_revealController.value > 0) {
        _revealController.reverse();
      }
      if (_animationPlaying) {
        setState(() => _animationPlaying = false);
      }
      // Reset local tracking if the state itself was reset to 0 progress.
      if (progress == 0) {
        _firedTriggers.clear();
        _thresholdFired = false;
        _tracker.reset();
      }
    }

    // ── Callbacks ──────────────────────────────────────────────────────────
    widget.onProgress?.call(progress);

    final double maxTrigger = widget.progressTriggers.isNotEmpty
        ? widget.progressTriggers.reduce((a, b) => a > b ? a : b)
        : -1.0;

    for (final trigger in widget.progressTriggers) {
      if (progress >= trigger && !_firedTriggers.contains(trigger)) {
        _firedTriggers.add(trigger);
        widget.onProgressTrigger?.call(trigger);

        // Start background animation when the FINAL trigger milestone is hit.
        if (trigger == maxTrigger && !_animationPlaying) {
          setState(() => _animationPlaying = true);
        }
      }
    }

    if (progress >= widget.threshold && !_thresholdFired) {
      _thresholdFired = true;
      widget.onThreshold?.call();
      if (widget.autoReveal) _state.setRevealed(true);
    }

    if (widget.autoRevealOnComplete && widget.progressTriggers.isNotEmpty) {
      final maxTrigger =
          widget.progressTriggers.reduce((a, b) => a > b ? a : b);
      if (progress >= maxTrigger && !_state.isRevealed) {
        _state.setRevealed(true);
      }
    }
  }

  // ─── Gesture handlers ────────────────────────────────────────────────────

  void _handleDragStart(DragStartDetails details) {
    if (_state.isRevealed) return;

    final box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(details.globalPosition);
    _state.addPoint(local, isNewPath: true);
    _tracker.addPoint(local, widget.brushSize, box.size);
    _state.updateProgress(_tracker.progress);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_state.isRevealed) return;
    final box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(details.globalPosition);
    _state.addPoint(local);
    _tracker.addPoint(local, widget.brushSize, box.size);
    _state.updateProgress(_tracker.progress);
    if (widget.enableHaptics) ScratchUtils.triggerHaptic();
  }


  // ─── Safe child: force transparent background when animation is active ───

  /// When an animation is active, wraps the child in a [ColoredBox] with a
  /// fully transparent color.  This prevents an opaque child background from
  /// hiding the animation behind it.
  ///
  /// If the developer already provided a transparent child, this is a no-op.
  Widget get _safeChild {
    if (widget.animationType == ScratchAnimationType.none ||
        widget.animationAsset == null) {
      return widget.child;
    }
    // Wrap in a transparent container so the underlying animation shows through.
    return ColoredBox(color: Colors.transparent, child: widget.child);
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Layer 1: Animation / child (isolated repaint boundary) ────────
          // RepaintBoundary gives this its own Flutter compositing layer.
          // Scratching marks only the CustomPaint dirty, never this widget.
          RepaintBoundary(
            child: ScratchAnimationLayer(
              animationType: widget.animationType,
              assetPath: widget.animationAsset,
              autoPlay: _animationPlaying,
              removeAnimationOnComplete: widget.removeAnimationOnComplete,
              child: _safeChild,
            ),
          ),

          // ── Layer 2: Scratch overlay (isolated repaint boundary) ───────────
          AnimatedBuilder(
            animation: Listenable.merge([_state, _revealAnimation]),
            builder: (context, _) {
              return IgnorePointer(
                // Once fully revealed, disable pointer so child is tappable.
                ignoring: _revealAnimation.value == 0,
                child: Opacity(
                  opacity: _revealAnimation.value,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: _handleDragStart,
                    onPanUpdate: _handleDragUpdate,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: ScratchPainter(
                          points: _state.points,
                          brushSize: widget.brushSize,
                          color: widget.scratchColor,
                          overlayImage: _resolvedOverlayImage,
                          gradient: widget.gradient,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
