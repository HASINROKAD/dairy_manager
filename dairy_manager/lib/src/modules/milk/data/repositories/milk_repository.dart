import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dairy_manager/core/utility/network/api_base_url.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/delivery_sheet_item.dart';
import '../models/ledger_entry.dart';

class MilkRepository {
  MilkRepository({
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

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Uri? _androidLoopbackFallbackUri(Uri primaryUri) {
    if (!Platform.isAndroid) {
      return null;
    }

    if (primaryUri.host == '127.0.0.1') {
      return primaryUri.replace(host: 'localhost');
    }

    if (primaryUri.host == 'localhost') {
      return primaryUri.replace(host: '127.0.0.1');
    }

    return null;
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
    required Map<String, String> headers,
  }) {
    final primaryUri = _uri(path);
    return _sendWithFallback(
      (resolvedUri) => _client.get(resolvedUri, headers: headers),
      primaryUri,
      _readTimeout,
    );
  }

  Future<http.Response> _post(
    String path, {
    required Map<String, String> headers,
    Object? body,
  }) {
    final primaryUri = _uri(path);
    return _sendWithFallback(
      (resolvedUri) => _client.post(resolvedUri, headers: headers, body: body),
      primaryUri,
      _writeTimeout,
    );
  }

  Future<http.Response> _patch(
    String path, {
    required Map<String, String> headers,
    Object? body,
  }) {
    final primaryUri = _uri(path);
    return _sendWithFallback(
      (resolvedUri) => _client.patch(resolvedUri, headers: headers, body: body),
      primaryUri,
      _writeTimeout,
    );
  }

  Map<String, dynamic> _parse(http.Response response) {
    final body = response.body.trim();
    Map<String, dynamic> json;
    if (body.isEmpty) {
      json = <String, dynamic>{};
    } else {
      try {
        json = jsonDecode(body) as Map<String, dynamic>;
      } on FormatException {
        throw Exception(
          'Server returned an invalid response with status ${response.statusCode}.',
        );
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json;
    }

    final error = json['error'] as Map<String, dynamic>?;
    throw Exception(
      (error?['message'] as String?) ??
          'Request failed with status ${response.statusCode}',
    );
  }

  Future<List<DeliverySheetItem>> fetchDailySheet() async {
    final response = await _get(
      '/api/seller/daily-sheet',
      headers: await _headers(),
    );
    final data = _parse(response);
    final sheet = (data['data']?['sheet'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();

    return sheet.map(DeliverySheetItem.fromJson).toList(growable: false);
  }

  Future<void> confirmBulkDelivery(List<String> customerIds) async {
    final response = await _post(
      '/api/seller/bulk-deliver',
      headers: await _headers(),
      body: jsonEncode({'customerIds': customerIds}),
    );
    _parse(response);
  }

  Future<void> adjustLog({
    required String logId,
    required double quantityLitres,
  }) async {
    final response = await _patch(
      '/api/seller/adjust-log',
      headers: await _headers(),
      body: jsonEncode({'logId': logId, 'quantityLitres': quantityLitres}),
    );
    _parse(response);
  }

  Future<void> deliverCustomer({
    required String customerId,
    required double quantityLitres,
  }) async {
    final response = await _post(
      '/api/seller/deliver-customer',
      headers: await _headers(),
      body: jsonEncode({
        'customerId': customerId,
        'quantityLitres': quantityLitres,
      }),
    );
    _parse(response);
  }

  Future<List<LedgerEntry>> fetchMyLedger() async {
    final response = await _get(
      '/api/customer/my-ledger',
      headers: await _headers(),
    );
    final data = _parse(response);
    final logs = (data['data']?['logs'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();

    return logs.map(LedgerEntry.fromJson).toList(growable: false);
  }

  Future<Map<String, dynamic>> fetchMyMonthlySummary({String? month}) async {
    final response = await _get(
      month == null || month.trim().isEmpty
          ? '/api/customer/my-ledger/summary'
          : '/api/customer/my-ledger/summary?month=$month',
      headers: await _headers(),
    );

    final data = _parse(response);
    return (data['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
  }

  Future<Map<String, dynamic>> fetchSellerMonthlySummary({
    String? month,
  }) async {
    final response = await _get(
      month == null || month.trim().isEmpty
          ? '/api/seller/monthly-summary'
          : '/api/seller/monthly-summary?month=$month',
      headers: await _headers(),
    );

    final data = _parse(response);
    return (data['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
  }

  Future<Map<String, dynamic>> fetchSellerLedgerLogs({String? month}) async {
    final response = await _get(
      month == null || month.trim().isEmpty
          ? '/api/seller/ledger-logs'
          : '/api/seller/ledger-logs?month=$month',
      headers: await _headers(),
    );

    final data = _parse(response);
    return (data['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
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

  Future<Map<String, dynamic>> fetchSellerMilkSettings() async {
    final response = await _get(
      '/api/seller/settings/milk',
      headers: await _headers(),
    );

    final data = _parse(response);
    return (data['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
  }

  Future<Map<String, dynamic>> updateSellerMilkBasePrice({
    required double basePricePerLitreRupees,
  }) async {
    final response = await _patch(
      '/api/seller/settings/milk/price',
      headers: await _headers(),
      body: jsonEncode({'basePricePerLitreRupees': basePricePerLitreRupees}),
    );

    final data = _parse(response);
    return (data['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
  }

  Future<Map<String, dynamic>> updateSellerCustomerDefaultQuantity({
    required String customerUserId,
    required double defaultQuantityLitres,
  }) async {
    final response = await _patch(
      '/api/seller/settings/milk/customer-default-quantity',
      headers: await _headers(),
      body: jsonEncode({
        'customerUserId': customerUserId,
        'defaultQuantityLitres': defaultQuantityLitres,
      }),
    );

    final data = _parse(response);
    return (data['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
  }

  Future<Map<String, dynamic>> fetchMyLedgerAudit({String? logId}) async {
    final response = await _get(
      logId == null || logId.trim().isEmpty
          ? '/api/customer/my-ledger/audit'
          : '/api/customer/my-ledger/audit?logId=$logId',
      headers: await _headers(),
    );

    final data = _parse(response);
    return (data['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
  }

  Future<Map<String, dynamic>> createMyLedgerDispute({
    required String logId,
    required String message,
    String disputeType = 'other',
  }) async {
    final response = await _post(
      '/api/customer/my-ledger/disputes',
      headers: await _headers(),
      body: jsonEncode({
        'logId': logId,
        'message': message,
        'disputeType': disputeType,
      }),
    );

    final data = _parse(response);
    return (data['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
  }

  Future<Map<String, dynamic>> fetchMyLedgerDisputes({String? status}) async {
    final response = await _get(
      status == null || status.trim().isEmpty
          ? '/api/customer/my-ledger/disputes'
          : '/api/customer/my-ledger/disputes?status=$status',
      headers: await _headers(),
    );

    final data = _parse(response);
    return (data['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
  }

  Future<Map<String, dynamic>> fetchMyCorrectionRequests({
    String? status,
  }) async {
    final response = await _get(
      status == null || status.trim().isEmpty
          ? '/api/customer/my-ledger/correction-requests'
          : '/api/customer/my-ledger/correction-requests?status=$status',
      headers: await _headers(),
    );

    final data = _parse(response);
    return (data['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
  }

  Future<Map<String, dynamic>> approveMyCorrectionRequest({
    required String requestId,
    String? reviewNote,
  }) async {
    final response = await _post(
      '/api/customer/my-ledger/correction-requests/$requestId/approve',
      headers: await _headers(),
      body: jsonEncode({'reviewNote': reviewNote}),
    );

    final data = _parse(response);
    return (data['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
  }

  Future<Map<String, dynamic>> rejectMyCorrectionRequest({
    required String requestId,
    String? reviewNote,
  }) async {
    final response = await _post(
      '/api/customer/my-ledger/correction-requests/$requestId/reject',
      headers: await _headers(),
      body: jsonEncode({'reviewNote': reviewNote}),
    );

    final data = _parse(response);
    return (data['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
  }

  Future<Map<String, dynamic>> fetchSellerDeliveryAudit({
    String? logId,
    String? customerFirebaseUid,
  }) async {
    final query = <String>[];
    if (logId != null && logId.trim().isNotEmpty) {
      query.add('logId=$logId');
    }
    if (customerFirebaseUid != null && customerFirebaseUid.trim().isNotEmpty) {
      query.add('customerFirebaseUid=$customerFirebaseUid');
    }

    final path = query.isEmpty
        ? '/api/seller/delivery-audit'
        : '/api/seller/delivery-audit?${query.join('&')}';

    final response = await _get(path, headers: await _headers());

    final data = _parse(response);
    return (data['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
  }

  Future<Map<String, dynamic>> createSellerCorrectionRequest({
    required String logId,
    required String requestedSlot,
    required double requestedQuantityLitres,
    required String reason,
  }) async {
    final response = await _post(
      '/api/seller/correction-requests',
      headers: await _headers(),
      body: jsonEncode({
        'logId': logId,
        'requestedSlot': requestedSlot,
        'requestedQuantityLitres': requestedQuantityLitres,
        'reason': reason,
      }),
    );

    final data = _parse(response);
    return (data['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
  }

  Future<Map<String, dynamic>> fetchSellerCorrectionRequests({
    String? status,
  }) async {
    final response = await _get(
      status == null || status.trim().isEmpty
          ? '/api/seller/correction-requests'
          : '/api/seller/correction-requests?status=$status',
      headers: await _headers(),
    );

    final data = _parse(response);
    return (data['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
  }

  Future<Map<String, dynamic>> fetchSellerDeliveryDisputes({
    String? status,
  }) async {
    final response = await _get(
      status == null || status.trim().isEmpty
          ? '/api/seller/delivery-disputes'
          : '/api/seller/delivery-disputes?status=$status',
      headers: await _headers(),
    );

    final data = _parse(response);
    return (data['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
  }

  Future<Map<String, dynamic>> resolveSellerDeliveryDispute({
    required String disputeId,
    required String status,
    String? resolutionNote,
  }) async {
    final response = await _patch(
      '/api/seller/delivery-disputes/$disputeId/resolve',
      headers: await _headers(),
      body: jsonEncode({'status': status, 'resolutionNote': resolutionNote}),
    );

    final data = _parse(response);
    return (data['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
  }
}
