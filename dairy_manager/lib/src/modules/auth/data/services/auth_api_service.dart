import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dairy_manager/core/utility/network/api_base_url.dart';

import '../models/user_model.dart';

class AuthApiService {
  AuthApiService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = ApiBaseUrl.resolve(override: baseUrl);

  final http.Client _client;
  final String _baseUrl;

  Future<void> syncAuth(String idToken) async {
    final response = await _authorizedPost(
      '/v1/auth/sync',
      idToken,
      const <String, dynamic>{},
    );
    _ensureSuccess(response);
  }

  Future<UserModel> getMe(String idToken) async {
    final response = await _authorizedGet('/v1/me', idToken);
    final json = _ensureSuccess(response);

    final data = json['data'] as Map<String, dynamic>;
    return UserModel.fromBackend(data);
  }

  Future<UserModel> completeOnboarding({
    required String idToken,
    required String name,
    required String mobileNumber,
    required String role,
  }) async {
    final response = await _authorizedPatch('/v1/me/onboarding', idToken, {
      'name': name,
      'mobileNumber': mobileNumber,
      'role': role,
    });

    final json = _ensureSuccess(response);
    final data = json['data'] as Map<String, dynamic>;
    return UserModel.fromBackend(data);
  }

  Future<void> upsertLocation({
    required String idToken,
    required String displayAddress,
    required double latitude,
    required double longitude,
    required String role,
    String? shopName,
  }) async {
    final payload = <String, dynamic>{
      'displayAddress': displayAddress,
      'latitude': latitude,
      'longitude': longitude,
      'locationSource': 'typed',
      'geocodeProvider': 'osm',
    };

    if (role == 'seller' && shopName != null && shopName.trim().isNotEmpty) {
      payload['shopName'] = shopName.trim();
    }

    final response = await _authorizedPut('/v1/me/location', idToken, payload);
    _ensureSuccess(response);
  }

  Future<UserModel> updateProfile({
    required String idToken,
    required String name,
    required String mobileNumber,
    required String displayAddress,
    required double latitude,
    required double longitude,
    String? shopName,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'mobileNumber': mobileNumber,
      'displayAddress': displayAddress,
      'latitude': latitude,
      'longitude': longitude,
    };

    if (shopName != null && shopName.trim().isNotEmpty) {
      payload['shopName'] = shopName.trim();
    }

    final response = await _authorizedPatch(
      '/v1/me/profile-update',
      idToken,
      payload,
    );
    final json = _ensureSuccess(response);

    final data = json['data'] as Map<String, dynamic>;
    final userData = data['user'] as Map<String, dynamic>;
    final locationData = data['location'] as Map<String, dynamic>?;

    return UserModel.fromBackend(userData).mergeLocation(locationData);
  }

  Future<Map<String, dynamic>?> getLocation(String idToken) async {
    final response = await _authorizedGet('/v1/me/location', idToken);
    final json = _ensureSuccess(response);

    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }

    return null;
  }

  Future<http.Response> _authorizedGet(String path, String token) async {
    return _withNetworkHandling(() {
      return _requestWithAndroidFallback(
        path,
        (uri) => _client.get(uri, headers: _headers(token)),
      );
    });
  }

  Future<http.Response> _authorizedPost(
    String path,
    String token,
    Map<String, dynamic> payload,
  ) async {
    return _withNetworkHandling(() {
      return _requestWithAndroidFallback(
        path,
        (uri) => _client.post(
          uri,
          headers: _headers(token),
          body: jsonEncode(payload),
        ),
      );
    });
  }

  Future<http.Response> _authorizedPatch(
    String path,
    String token,
    Map<String, dynamic> payload,
  ) async {
    return _withNetworkHandling(() {
      return _requestWithAndroidFallback(
        path,
        (uri) => _client.patch(
          uri,
          headers: _headers(token),
          body: jsonEncode(payload),
        ),
      );
    });
  }

  Future<http.Response> _authorizedPut(
    String path,
    String token,
    Map<String, dynamic> payload,
  ) async {
    return _withNetworkHandling(() {
      return _requestWithAndroidFallback(
        path,
        (uri) => _client.put(
          uri,
          headers: _headers(token),
          body: jsonEncode(payload),
        ),
      );
    });
  }

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  List<Uri> _androidFallbackUris(Uri primaryUri) {
    if (!Platform.isAndroid) {
      return const <Uri>[];
    }

    final host = primaryUri.host.toLowerCase();
    final fallbackHosts = <String>[];

    if (host == '127.0.0.1') {
      fallbackHosts.add('localhost');
    } else if (host == 'localhost') {
      fallbackHosts.add('127.0.0.1');
    } else {
      // If LAN URL is unreachable, try USB reverse/local loopback hosts.
      fallbackHosts.addAll(<String>['127.0.0.1', 'localhost']);
    }

    final seen = <String>{};
    final fallbacks = <Uri>[];
    for (final fallbackHost in fallbackHosts) {
      if (!seen.add(fallbackHost)) {
        continue;
      }
      fallbacks.add(primaryUri.replace(host: fallbackHost));
    }

    return fallbacks;
  }

  bool _isSocketLikeError(Object error) {
    if (error is SocketException) {
      return true;
    }

    if (error is http.ClientException) {
      final lower = error.message.toLowerCase();
      return lower.contains('socketexception') ||
          lower.contains('failed host lookup') ||
          lower.contains('no route to host') ||
          lower.contains('connection refused');
    }

    return false;
  }

  Future<http.Response> _requestWithAndroidFallback(
    String path,
    Future<http.Response> Function(Uri uri) request,
  ) async {
    final primaryUri = _uri(path);
    final fallbackUris = _androidFallbackUris(primaryUri);
    Object? lastError;

    try {
      return await request(primaryUri);
    } catch (error) {
      if (!_isSocketLikeError(error)) {
        rethrow;
      }

      lastError = error;
    }

    for (final fallbackUri in fallbackUris) {
      try {
        return await request(fallbackUri);
      } catch (error) {
        if (!_isSocketLikeError(error)) {
          rethrow;
        }
        lastError = error;
      }
    }

    if (lastError is SocketException) {
      throw lastError;
    }
    if (lastError is http.ClientException) {
      throw lastError;
    }

    throw const SocketException('Unable to connect to backend host.');
  }

  Future<http.Response> _withNetworkHandling(
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request();
    } on SocketException {
      throw AuthApiException(_networkMessage(onTimeout: false));
    } on TimeoutException {
      throw AuthApiException(_networkMessage(onTimeout: true));
    } on http.ClientException catch (e) {
      if (_isSocketLikeError(e)) {
        throw AuthApiException(_networkMessage(onTimeout: false));
      }
      throw AuthApiException(e.message);
    }
  }

  String _networkMessage({required bool onTimeout}) {
    final short = onTimeout
        ? 'Request timed out. Please try again.'
        : 'Unable to connect to server. Please try again.';

    if (kReleaseMode) {
      return short;
    }

    return '$short${ApiBaseUrl.networkDebugHint(_baseUrl)}';
  }

  Map<String, String> _headers(String idToken) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
    };
  }

  Map<String, dynamic> _ensureSuccess(http.Response response) {
    Map<String, dynamic>? json;
    final trimmedBody = response.body.trim();
    if (trimmedBody.isNotEmpty) {
      try {
        json = jsonDecode(trimmedBody) as Map<String, dynamic>;
      } on FormatException {
        json = null;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json ?? <String, dynamic>{'success': true};
    }

    final error = json?['error'] as Map<String, dynamic>?;
    final message =
        (error?['message'] as String?) ??
        'Request failed with status ${response.statusCode}';
    throw AuthApiException(message);
  }
}

class AuthApiException implements Exception {
  AuthApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
