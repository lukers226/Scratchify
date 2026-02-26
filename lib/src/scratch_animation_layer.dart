import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Animation types supported by the scratch card's background layer.
enum ScratchAnimationType {
  /// No animation — renders only the child widget (default).
  none,

  /// A GIF image asset rendered as the background.
  gif,

  /// A Lottie JSON animation asset rendered as the background.
  lottie,
}

/// Internal widget that renders the animated (or static) content behind the
/// scratch overlay layer.
///
/// ### Animation Lifecycle (Lottie)
///
/// 1. Parent sets [autoPlay] = `true` → internal controller plays from frame 0.
/// 2. On `AnimationStatus.completed` with [removeAnimationOnComplete] = `true`:
///    → fades out the animation (400 ms) then removes it from the widget tree.
///    → the child widget (reward UI) remains fully visible underneath.
/// 3. On reset (autoPlay → `false`): controller resets, widget hides cleanly.
///
/// ### Performance
///
/// Wrapped in a [RepaintBoundary] inside [ScratchCard] so scratching the
/// overlay [CustomPaint] never triggers a repaint of this widget.
/// AnimationControllers are created only when an animation type is active.
class ScratchAnimationLayer extends StatefulWidget {
  final ScratchAnimationType animationType;
  final String? assetPath;
  final Widget child;

  /// Triggers the animation to start when switched to `true`.
  final bool autoPlay;

  /// Whether to remove the animation automatically after it finishes.
  final bool removeAnimationOnComplete;

  const ScratchAnimationLayer({
    Key? key,
    required this.animationType,
    required this.child,
    this.assetPath,
    this.autoPlay = false,
    this.removeAnimationOnComplete = true,
  }) : super(key: key);

  @override
  State<ScratchAnimationLayer> createState() => _ScratchAnimationLayerState();
}

class _ScratchAnimationLayerState extends State<ScratchAnimationLayer>
    with TickerProviderStateMixin {
  /// Controls the Lottie playback. Only created for Lottie type.
  AnimationController? _lottieController;

  /// Controls the fade-out of the animation after completion.
  AnimationController? _fadeController;
  Animation<double>? _fadeAnimation;

  /// Whether the animation widget is currently shown in the tree.
  bool _showAnimation = false;

  @override
  void initState() {
    super.initState();
    if (widget.animationType == ScratchAnimationType.lottie &&
        widget.assetPath != null) {
      _initControllers();
    }
  }

  void _initControllers() {
    _lottieController = AnimationController(vsync: this);
    _lottieController!.addStatusListener(_onLottieStatus);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0,
    );
    _fadeAnimation = _fadeController;
  }

  @override
  void dispose() {
    _lottieController?.removeStatusListener(_onLottieStatus);
    _lottieController?.dispose();
    _fadeController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ScratchAnimationLayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Lazily create controllers if animationType changed to lottie.
    if (widget.animationType == ScratchAnimationType.lottie &&
        widget.assetPath != null &&
        _lottieController == null) {
      _initControllers();
    }

    if (!oldWidget.autoPlay && widget.autoPlay) {
      _startAnimation();
    } else if (oldWidget.autoPlay && !widget.autoPlay) {
      _resetAnimation();
    }
  }

  void _startAnimation() {
    if (!mounted) return;
    final controller = _lottieController;
    if (controller == null) return;

    setState(() => _showAnimation = true);
    _fadeController?.value = 1.0;

    // Only call forward() if Lottie has already loaded (duration is known).
    // If not yet loaded, onLoaded will call forward() once composition is ready.
    if (controller.duration != null) {
      controller.forward(from: 0);
    }
  }

  void _resetAnimation() {
    if (!mounted) return;
    _lottieController?.reset();
    _fadeController?.value = 1.0;
    setState(() => _showAnimation = false);
  }

  void _onLottieStatus(AnimationStatus status) {
    if (!mounted) return;
    if (status != AnimationStatus.completed) return;

    if (widget.removeAnimationOnComplete) {
      _fadeController?.reverse().then((_) {
        if (mounted) setState(() => _showAnimation = false);
      });
    } else {
      // Reset to frame 0 so the first (usually empty) frame shows —
      // prevents the frozen last-frame artifact.
      _lottieController?.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    // No animation configured — render child directly (zero overhead).
    if (widget.animationType == ScratchAnimationType.none ||
        widget.assetPath == null) {
      return widget.child;
    }

    Widget? backgroundAnim;

    if (widget.animationType == ScratchAnimationType.gif) {
      if (widget.autoPlay) {
        backgroundAnim = Image.asset(widget.assetPath!, fit: BoxFit.cover);
      }
    } else if (widget.animationType == ScratchAnimationType.lottie &&
        _showAnimation &&
        _lottieController != null &&
        _fadeAnimation != null) {
      backgroundAnim = FadeTransition(
        opacity: _fadeAnimation!,
        child: Lottie.asset(
          widget.assetPath!,
          controller: _lottieController,
          fit: BoxFit.cover,
          onLoaded: (composition) {
            if (mounted && _lottieController != null) {
              _lottieController!.duration ??= composition.duration;
              if (widget.autoPlay &&
                  !_lottieController!.isAnimating &&
                  _lottieController!.value == 0) {
                _lottieController!.forward(from: 0);
              }
            }
          },
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (backgroundAnim != null) backgroundAnim,
      ],
    );
  }
}
