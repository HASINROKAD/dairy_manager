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

    // Default to laptop IP for physical devices
    return 'http://192.168.29.26:5000';
  }

  static String networkDebugHint(String baseUrl) {
    if (kReleaseMode) {
      return '';
    }

    return '\n\n📡 Current Backend: $baseUrl\n'
        '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
        'Physical Device on WiFi Setup:\n'
        '\n✅ Your Laptop IP: 192.168.29.26\n'
        '\n🚀 Run app with:\n'
        '   flutter run --dart-define=API_BASE_URL=http://192.168.29.26:5000\n'
        '\n✓ Make sure:\n'
        '   1. Backend is running: npm start\n'
        '   2. Device & laptop on same WiFi\n'
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
