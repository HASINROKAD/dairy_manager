import 'dart:io';

import 'package:flutter/foundation.dart';

class ApiBaseUrl {
  ApiBaseUrl._();

  static const String _baseUrlFromEnv = String.fromEnvironment('API_BASE_URL');
  static const String _targetFromEnv = String.fromEnvironment('API_TARGET');

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

    final target = _targetFromEnv.trim().toLowerCase();

    // Prefer explicit target profiles to avoid slow first-hop failures.
    if (Platform.isAndroid) {
      switch (target) {
        case 'emulator':
          return 'http://10.0.2.2:5000';
        case 'lan':
          return 'http://192.168.1.100:5000';
        case 'adb':
        case 'device':
        case '':
        default:
          return 'http://127.0.0.1:5000';
      }
    }

    return 'http://127.0.0.1:5000';
  }

  static String networkDebugHint(String baseUrl) {
    if (kReleaseMode) {
      return '';
    }

    return ' Debug: active API base URL is $baseUrl. Set --dart-define=API_BASE_URL=<url> for explicit backend, or --dart-define=API_TARGET=emulator|device|adb|lan when testing Android dev targets.';
  }

  static String _normalize(String url) {
    final trimmed = url.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }

    return trimmed;
  }
}
