import 'scratch_state.dart';

/// Controller for the [ScratchCard] widget.
class ScratchController {
  ScratchState? _state;

  /// Attaches the controller to a state.
  void attach(ScratchState state) {
    _state = state;
  }

  /// Detaches the controller from a state.
  void detach() {
    _state = null;
  }

  /// Manually reveals the entire scratch card.
  void reveal() {
    _state?.setRevealed(true);
  }

  /// Resets the scratch card to its initial state.
  void reset() {
    _state?.reset();
  }

  /// Returns the current scratch progress (0.0 to 1.0).
  double get progress => _state?.progress ?? 0.0;

  /// Returns whether the card is fully revealed.
  bool get isRevealed => _state?.isRevealed ?? false;
}
