import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkConfig {
  static const Duration _readTimeoutDefault = Duration(seconds: 20);
  static const Duration _writeTimeoutDefault = Duration(seconds: 30);

  // For slow networks (2G/3G)
  static const Duration _readTimeoutSlow = Duration(seconds: 45);
  static const Duration _writeTimeoutSlow = Duration(seconds: 60);

  // For fast networks (WiFi/4G+)
  static const Duration _readTimeoutFast = Duration(seconds: 15);
  static const Duration _writeTimeoutFast = Duration(seconds: 25);

  static const String _readTimeoutEnv = String.fromEnvironment(
    'API_READ_TIMEOUT_SECONDS',
  );
  static const String _writeTimeoutEnv = String.fromEnvironment(
    'API_WRITE_TIMEOUT_SECONDS',
  );

  static Duration getReadTimeout() {
    // Check environment override first
    if (_readTimeoutEnv.isNotEmpty) {
      final seconds = int.tryParse(_readTimeoutEnv);
      if (seconds != null && seconds > 0) {
        return Duration(seconds: seconds);
      }
    }
    return _readTimeoutDefault;
  }

  static Duration getWriteTimeout() {
    // Check environment override first
    if (_writeTimeoutEnv.isNotEmpty) {
      final seconds = int.tryParse(_writeTimeoutEnv);
      if (seconds != null && seconds > 0) {
        return Duration(seconds: seconds);
      }
    }
    return _writeTimeoutDefault;
  }

  static Future<Duration> getAdaptiveReadTimeout() async {
    try {
      final connectivity = Connectivity();
      final result = await connectivity.checkConnectivity();

      // Use faster timeouts for WiFi, slower for mobile data
      if (result.contains(ConnectivityResult.wifi)) {
        return _readTimeoutFast;
      } else if (result.contains(ConnectivityResult.mobile)) {
        return _readTimeoutSlow;
      }
    } catch (_) {
      // Fallback to default if connectivity check fails
    }
    return _readTimeoutDefault;
  }

  static Future<Duration> getAdaptiveWriteTimeout() async {
    try {
      final connectivity = Connectivity();
      final result = await connectivity.checkConnectivity();

      // Use faster timeouts for WiFi, slower for mobile data
      if (result.contains(ConnectivityResult.wifi)) {
        return _writeTimeoutFast;
      } else if (result.contains(ConnectivityResult.mobile)) {
        return _writeTimeoutSlow;
      }
    } catch (_) {
      // Fallback to default if connectivity check fails
    }
    return _writeTimeoutDefault;
  }
}
