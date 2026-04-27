import 'package:flutter/foundation.dart';

class ApiBaseUrl {
  ApiBaseUrl._();

  static const String _baseUrlFromEnv = String.fromEnvironment('API_BASE_URL');

  static String resolve({String? override}) {
    final explicit = override?.trim() ?? '';
    if (explicit.isNotEmpty) {
      return _normalize(explicit);
    }

    final fromEnv = _baseUrlFromEnv.trim();
    if (fromEnv.isNotEmpty) {
      return _normalize(fromEnv);
    }

    if (kIsWeb) {
      return 'http://localhost:5000';
    }

    // Default local backend for mobile/desktop. For Android physical devices,
    // this requires adb reverse so 127.0.0.1 maps to your laptop backend.
    return 'http://127.0.0.1:5000';
  }

  static String networkDebugHint(String baseUrl) {
    if (kReleaseMode) {
      return '';
    }

    return '\n\n📡 Current Backend: $baseUrl\n'
        '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
        'Android physical device setup:\n'
        '\n1) Reverse port on all connected Android devices:\n'
        "   for /f \"tokens=1\" %d in ('adb devices ^| findstr /R /C:\"device\"') do adb -s %d reverse tcp:5000 tcp:5000\n"
        '\n2) Run app against localhost backend:\n'
        '   flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5000\n'
        '\n3) If not using USB reverse, use Wi-Fi host:\n'
        '   flutter run --dart-define=API_BASE_URL=http://<YOUR_LAPTOP_IP>:5000\n'
        '\n✓ Make sure:\n'
        '   1. Backend is running: npm start\n'
        '   2. If using Wi-Fi, device & laptop are on same network\n'
        '   3. Firewall allows port 5000';
  }

  static String _normalize(String url) {
    final trimmed = url.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }

    return trimmed;
  }
}
