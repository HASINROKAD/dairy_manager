import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/app_notification_item.dart';
import '../models/join_request_item.dart';
import '../models/nearby_seller.dart';
import '../models/notification_feed.dart';

class HomeRepository {
  HomeRepository({
    http.Client? client,
    FirebaseAuth? firebaseAuth,
    String? baseUrl,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? _defaultBaseUrl;

  static const String _baseUrlFromEnv = String.fromEnvironment('API_BASE_URL');

  static String get _defaultBaseUrl {
    if (_baseUrlFromEnv.trim().isNotEmpty) {
      return _baseUrlFromEnv.trim();
    }

    if (kIsWeb) {
      return 'http://localhost:5000';
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000';
    }

    return 'http://127.0.0.1:5000';
  }

  final http.Client _client;
  final FirebaseAuth _firebaseAuth;
  final String _baseUrl;

  Future<Map<String, String>> _headers() async {
    final token = await _firebaseAuth.currentUser?.getIdToken(true);

    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final uri = Uri.parse('$_baseUrl$path');
    if (query == null || query.isEmpty) {
      return uri;
    }

    return uri.replace(
      queryParameters: query.map((key, value) => MapEntry(key, '$value')),
    );
  }

  Map<String, dynamic> _parse(http.Response response) {
    final body = response.body.trim();
    final json = body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json;
    }

    final error = json['error'] as Map<String, dynamic>?;
    throw Exception(
      (error?['message'] as String?) ??
          'Request failed with status ${response.statusCode}',
    );
  }

  Future<List<NearbySeller>> fetchNearbySellers({
    required double latitude,
    required double longitude,
    double radiusKm = 5,
  }) async {
    final response = await _client.get(
      _uri('/v1/sellers/nearby', {
        'lat': latitude,
        'lng': longitude,
        'radiusKm': radiusKm,
      }),
      headers: await _headers(),
    );
    final data = _parse(response);
    final sellers = (data['data'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();

    return sellers.map(NearbySeller.fromJson).toList(growable: false);
  }

  Future<JoinRequestItem> sendJoinRequest(String sellerUserId) async {
    final response = await _client.post(
      _uri('/v1/customer/join-requests'),
      headers: await _headers(),
      body: jsonEncode({'sellerUserId': sellerUserId}),
    );

    final data = _parse(response);
    return JoinRequestItem.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<List<JoinRequestItem>> fetchMyJoinRequests() async {
    final response = await _client.get(
      _uri('/v1/customer/join-requests'),
      headers: await _headers(),
    );

    final data = _parse(response);
    final items = (data['data'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();

    return items.map(JoinRequestItem.fromJson).toList(growable: false);
  }

  Future<List<JoinRequestItem>> fetchSellerJoinRequests({
    String? status,
  }) async {
    final response = await _client.get(
      _uri('/v1/seller/join-requests', {
        if (status != null && status.trim().isNotEmpty) 'status': status,
      }),
      headers: await _headers(),
    );

    final data = _parse(response);
    final items = (data['data'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();

    return items.map(JoinRequestItem.fromJson).toList(growable: false);
  }

  Future<JoinRequestItem> reviewJoinRequest({
    required String requestId,
    required String action,
    String? rejectionReason,
  }) async {
    final response = await _client.patch(
      _uri('/v1/seller/join-requests/$requestId'),
      headers: await _headers(),
      body: jsonEncode({
        'action': action,
        if (rejectionReason != null && rejectionReason.trim().isNotEmpty)
          'rejectionReason': rejectionReason.trim(),
      }),
    );

    final data = _parse(response);
    return JoinRequestItem.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<NotificationFeed> fetchNotifications({
    bool unreadOnly = false,
    int limit = 50,
  }) async {
    final response = await _client.get(
      _uri('/v1/notifications', {'unreadOnly': unreadOnly, 'limit': limit}),
      headers: await _headers(),
    );

    final data = _parse(response);
    final payload =
        data['data'] as Map<String, dynamic>? ??
        <String, dynamic>{'items': <dynamic>[], 'unreadCount': 0};

    final items = (payload['items'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();

    return NotificationFeed(
      items: items.map(AppNotificationItem.fromJson).toList(growable: false),
      unreadCount: (payload['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> markNotificationRead(String notificationId) async {
    final response = await _client.patch(
      _uri('/v1/notifications/$notificationId/read'),
      headers: await _headers(),
    );

    _parse(response);
  }

  Future<void> markAllNotificationsRead() async {
    final response = await _client.patch(
      _uri('/v1/notifications/read-all'),
      headers: await _headers(),
    );

    _parse(response);
  }
}
