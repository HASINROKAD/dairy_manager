import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dairy_manager/core/utility/network/api_base_url.dart';

import '../models/user_model.dart';

class AuthApiService {
  static const Duration _readTimeout = Duration(seconds: 6);
  static const Duration _writeTimeout = Duration(seconds: 8);

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

  Future<http.Response> _authorizedGet(String path, String token) {
    return _withNetworkHandling(() {
      return _requestWithAndroidFallback(
        path,
        (uri) => _client.get(uri, headers: _headers(token)),
        timeout: _readTimeout,
      );
    });
  }

  Future<http.Response> _authorizedPost(
    String path,
    String token,
    Map<String, dynamic> payload,
  ) {
    return _withNetworkHandling(() {
      return _requestWithAndroidFallback(
        path,
        (uri) => _client.post(
          uri,
          headers: _headers(token),
          body: jsonEncode(payload),
        ),
        timeout: _writeTimeout,
      );
    });
  }

  Future<http.Response> _authorizedPatch(
    String path,
    String token,
    Map<String, dynamic> payload,
  ) {
    return _withNetworkHandling(() {
      return _requestWithAndroidFallback(
        path,
        (uri) => _client.patch(
          uri,
          headers: _headers(token),
          body: jsonEncode(payload),
        ),
        timeout: _writeTimeout,
      );
    });
  }

  Future<http.Response> _authorizedPut(
    String path,
    String token,
    Map<String, dynamic> payload,
  ) {
    return _withNetworkHandling(() {
      return _requestWithAndroidFallback(
        path,
        (uri) => _client.put(
          uri,
          headers: _headers(token),
          body: jsonEncode(payload),
        ),
        timeout: _writeTimeout,
      );
    });
  }

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Uri? _androidLoopbackFallbackUri(Uri primaryUri) {
    if (!Platform.isAndroid) {
      return null;
    }

    if (primaryUri.host != '10.0.2.2') {
      return null;
    }

    return primaryUri.replace(host: '127.0.0.1');
  }

  Future<http.Response> _requestWithAndroidFallback(
    String path,
    Future<http.Response> Function(Uri uri) request, {
    required Duration timeout,
  }) async {
    final primaryUri = _uri(path);
    final fallbackUri = _androidLoopbackFallbackUri(primaryUri);

    Future<http.Response> send(Uri uri) {
      return request(uri).timeout(timeout);
    }

    try {
      return await send(primaryUri);
    } on SocketException {
      if (fallbackUri == null) {
        rethrow;
      }
      return send(fallbackUri);
    }
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
