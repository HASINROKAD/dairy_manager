import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dairy_manager/core/utility/network/api_base_url.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
       _baseUrl = ApiBaseUrl.resolve(override: baseUrl);

  final http.Client _client;
  final FirebaseAuth _firebaseAuth;
  final String _baseUrl;
  static const Duration _readTimeout = Duration(seconds: 6);
  static const Duration _writeTimeout = Duration(seconds: 8);

  Future<Map<String, String>> _headers() async {
    final token = await _firebaseAuth.currentUser?.getIdToken();

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

  Uri? _androidLoopbackFallbackUri(Uri primaryUri) {
    if (!Platform.isAndroid) {
      return null;
    }

    if (primaryUri.host != '10.0.2.2') {
      return null;
    }

    return primaryUri.replace(host: '127.0.0.1');
  }

  Future<http.Response> _sendWithFallback(
    Future<http.Response> Function(Uri uri) request,
    Uri primaryUri,
    Duration timeout,
  ) async {
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

  Future<http.Response> _get(
    String path, {
    Map<String, dynamic>? query,
    required Map<String, String> headers,
  }) {
    final uri = _uri(path, query);
    return _sendWithFallback(
      (resolved) => _client.get(resolved, headers: headers),
      uri,
      _readTimeout,
    );
  }

  Future<http.Response> _post(
    String path, {
    Map<String, dynamic>? query,
    required Map<String, String> headers,
    Object? body,
  }) {
    final uri = _uri(path, query);
    return _sendWithFallback(
      (resolved) => _client.post(resolved, headers: headers, body: body),
      uri,
      _writeTimeout,
    );
  }

  Future<http.Response> _patch(
    String path, {
    Map<String, dynamic>? query,
    required Map<String, String> headers,
    Object? body,
  }) {
    final uri = _uri(path, query);
    return _sendWithFallback(
      (resolved) => _client.patch(resolved, headers: headers, body: body),
      uri,
      _writeTimeout,
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
    final response = await _get(
      '/v1/sellers/nearby',
      query: {'lat': latitude, 'lng': longitude, 'radiusKm': radiusKm},
      headers: await _headers(),
    );
    final data = _parse(response);
    final sellers = (data['data'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();

    return sellers.map(NearbySeller.fromJson).toList(growable: false);
  }

  Future<JoinRequestItem> sendJoinRequest(String sellerUserId) async {
    final response = await _post(
      '/v1/customer/join-requests',
      headers: await _headers(),
      body: jsonEncode({'sellerUserId': sellerUserId}),
    );

    final data = _parse(response);
    return JoinRequestItem.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<List<JoinRequestItem>> fetchMyJoinRequests() async {
    final response = await _get(
      '/v1/customer/join-requests',
      headers: await _headers(),
    );

    final data = _parse(response);
    final items = (data['data'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();

    return items.map(JoinRequestItem.fromJson).toList(growable: false);
  }

  Future<List<JoinRequestItem>> fetchSellerJoinRequests({
    String? status,
    String? sortBy,
    String? area,
    double? minQuantityLitres,
    double? maxDistanceKm,
  }) async {
    final response = await _get(
      '/v1/seller/join-requests',
      query: {
        if (status != null && status.trim().isNotEmpty) 'status': status,
        if (sortBy != null && sortBy.trim().isNotEmpty) 'sortBy': sortBy,
        if (area != null && area.trim().isNotEmpty) 'area': area,
        ...?(minQuantityLitres == null
            ? null
            : <String, dynamic>{'minQuantityLitres': minQuantityLitres}),
        ...?(maxDistanceKm == null
            ? null
            : <String, dynamic>{'maxDistanceKm': maxDistanceKm}),
      },
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
    final response = await _patch(
      '/v1/seller/join-requests/$requestId',
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
    final response = await _get(
      '/v1/notifications',
      query: {'unreadOnly': unreadOnly, 'limit': limit},
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
    final response = await _patch(
      '/v1/notifications/$notificationId/read',
      headers: await _headers(),
    );

    _parse(response);
  }

  Future<void> markAllNotificationsRead() async {
    final response = await _patch(
      '/v1/notifications/read-all',
      headers: await _headers(),
    );

    _parse(response);
  }

  Future<List<Map<String, dynamic>>> fetchSellerCustomers() async {
    final response = await _get(
      '/v1/seller/customers',
      headers: await _headers(),
    );

    final data = _parse(response);
    return (data['data'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> fetchCustomerOrganization() async {
    final response = await _get(
      '/v1/customer/organization',
      headers: await _headers(),
    );

    final data = _parse(response);
    final payload = data['data'];
    if (payload is Map<String, dynamic>) {
      return payload;
    }

    return null;
  }

  Future<Map<String, dynamic>> leaveCustomerOrganization() async {
    final response = await _post(
      '/v1/customer/organization/leave',
      headers: await _headers(),
    );

    final data = _parse(response);
    return (data['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
  }

  Future<Map<String, dynamic>> fetchLeaveCustomerOrganizationPreview() async {
    final response = await _get(
      '/v1/customer/organization/leave-preview',
      headers: await _headers(),
    );

    final data = _parse(response);
    return (data['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
  }

  Future<Map<String, dynamic>> reportDeliveryIssue({
    required String issueType,
    String? dateKey,
    String? description,
  }) async {
    final response = await _post(
      '/v1/customer/delivery-issues',
      headers: await _headers(),
      body: jsonEncode({
        'issueType': issueType,
        if (dateKey != null && dateKey.trim().isNotEmpty) 'dateKey': dateKey,
        if (description != null && description.trim().isNotEmpty)
          'description': description,
      }),
    );

    final data = _parse(response);
    return (data['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
  }

  Future<List<Map<String, dynamic>>> fetchMyDeliveryIssues() async {
    final response = await _get(
      '/v1/customer/delivery-issues',
      headers: await _headers(),
    );

    final data = _parse(response);
    return (data['data'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchSellerDeliveryIssues({
    String? status,
  }) async {
    final response = await _get(
      '/v1/seller/delivery-issues',
      query: {if (status != null && status.trim().isNotEmpty) 'status': status},
      headers: await _headers(),
    );

    final data = _parse(response);
    return (data['data'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> resolveSellerDeliveryIssue({
    required String issueId,
    String? resolutionNote,
  }) async {
    final response = await _patch(
      '/v1/seller/delivery-issues/$issueId/resolve',
      headers: await _headers(),
      body: jsonEncode({
        if (resolutionNote != null && resolutionNote.trim().isNotEmpty)
          'resolutionNote': resolutionNote,
      }),
    );

    final data = _parse(response);
    return (data['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
  }

  Future<Map<String, dynamic>> createDeliveryPause({
    required String startDateKey,
    required String endDateKey,
  }) async {
    final response = await _post(
      '/v1/customer/delivery-pauses',
      headers: await _headers(),
      body: jsonEncode({
        'startDateKey': startDateKey,
        'endDateKey': endDateKey,
      }),
    );

    final data = _parse(response);
    return (data['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
  }

  Future<List<Map<String, dynamic>>> fetchMyDeliveryPauses() async {
    final response = await _get(
      '/v1/customer/delivery-pauses',
      headers: await _headers(),
    );

    final data = _parse(response);
    return (data['data'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> resumeMyDeliveryPause(String pauseId) async {
    final response = await _patch(
      '/v1/customer/delivery-pauses/$pauseId/resume',
      headers: await _headers(),
    );

    final data = _parse(response);
    return (data['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
  }

  Future<List<Map<String, dynamic>>> fetchSellerDeliveryPauses() async {
    final response = await _get(
      '/v1/seller/delivery-pauses',
      headers: await _headers(),
    );

    final data = _parse(response);
    return (data['data'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> resumeSellerDeliveryPause(String pauseId) async {
    final response = await _patch(
      '/v1/seller/delivery-pauses/$pauseId/resume',
      headers: await _headers(),
    );

    final data = _parse(response);
    return (data['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
  }
}
