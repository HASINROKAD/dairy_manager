import 'dart:async';

class ConnectivityRecoveryBus {
  ConnectivityRecoveryBus._();

  static final StreamController<int> _controller =
      StreamController<int>.broadcast();
  static int _version = 0;

  static Stream<int> get stream => _controller.stream;

  static void emitRecovery() {
    if (_controller.isClosed) {
      return;
    }

    _version += 1;
    _controller.add(_version);
  }
}
