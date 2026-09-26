import 'dart:async';

enum CellularState {
  online,
  subterraneanDeadzone,
}

class HeartbeatEvent {
  final CellularState state;
  final DateTime timestamp;
  final String? signalNote;

  const HeartbeatEvent({
    required this.state,
    required this.timestamp,
    this.signalNote,
  });

  bool get isRestored => state == CellularState.online;
}

class HeartbeatDetector {
  CellularState _currentState = CellularState.online;
  final _controller = StreamController<HeartbeatEvent>.broadcast();

  CellularState get currentState => _currentState;
  bool get isInDeadzone => _currentState == CellularState.subterraneanDeadzone;
  Stream<HeartbeatEvent> get onHeartbeat => _controller.stream;

  Stream<HeartbeatEvent> get onSignalRestored =>
      _controller.stream.where((event) => event.isRestored);

  /// Called when the device drops into a deep station or tunnel
  void enterDeadzone({String note = 'Subterranean signal loss'}) {
    if (_currentState != CellularState.subterraneanDeadzone) {
      _currentState = CellularState.subterraneanDeadzone;
      _controller.add(HeartbeatEvent(
        state: CellularState.subterraneanDeadzone,
        timestamp: DateTime.now(),
        signalNote: note,
      ));
    }
  }

  /// Triggered when cellular signal returns (e.g., train surfaces at an elevated station)
  void triggerHeartbeat({String note = 'Cellular heartbeat pulse detected'}) {
    final wasInDeadzone = _currentState == CellularState.subterraneanDeadzone;
    _currentState = CellularState.online;
    _controller.add(HeartbeatEvent(
      state: CellularState.online,
      timestamp: DateTime.now(),
      signalNote: wasInDeadzone ? 'Surfaced from deadzone - signal restored' : note,
    ));
  }

  void dispose() {
    _controller.close();
  }
}
