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

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://192.168.29.26:5000';
    }

    // Default local backend for non-Android desktop clients.
    return 'http://127.0.0.1:5000';
  }

  static String networkDebugHint(String baseUrl) {
    if (kReleaseMode) {
      return '';
    }

    return '\n\n📡 Current Backend: $baseUrl\n'
        '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
      'Android physical device setup:\n'
      '\n1) Default on Android now uses your LAN backend:\n'
      '   http://192.168.29.26:5000\n'
      '\n2) Optional: if you want USB reverse instead, reverse port 5000 on the connected device:\n'
        "   for /f \"tokens=1\" %d in ('adb devices ^| findstr /R /C:\"device\"') do adb -s %d reverse tcp:5000 tcp:5000\n"
      '\n3) USB reverse fallback run command:\n'
        '   flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5000\n'
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
