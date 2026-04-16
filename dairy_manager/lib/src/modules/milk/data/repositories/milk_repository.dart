import 'dart:io';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

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

  Future<List<DeliverySheetItem>> fetchDailySheet() async {
    final response = await _client.get(
      _uri('/api/seller/daily-sheet'),
      headers: await _headers(),
    );
    final data = _parse(response);
    final sheet = (data['data']?['sheet'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();

    return sheet.map(DeliverySheetItem.fromJson).toList(growable: false);
  }

  Future<void> confirmBulkDelivery(List<String> customerIds) async {
    final response = await _client.post(
      _uri('/api/seller/bulk-deliver'),
      headers: await _headers(),
      body: jsonEncode({'customerIds': customerIds}),
    );
    _parse(response);
  }

  Future<void> adjustLog({
    required String logId,
    required double quantityLitres,
  }) async {
    final response = await _client.patch(
      _uri('/api/seller/adjust-log'),
      headers: await _headers(),
      body: jsonEncode({'logId': logId, 'quantityLitres': quantityLitres}),
    );
    _parse(response);
  }

  Future<void> deliverCustomer({
    required String customerId,
    required double quantityLitres,
  }) async {
    final response = await _client.post(
      _uri('/api/seller/deliver-customer'),
      headers: await _headers(),
      body: jsonEncode({
        'customerId': customerId,
        'quantityLitres': quantityLitres,
      }),
    );
    _parse(response);
  }

  Future<List<LedgerEntry>> fetchMyLedger() async {
    final response = await _client.get(
      _uri('/api/customer/my-ledger'),
      headers: await _headers(),
    );
    final data = _parse(response);
    final logs = (data['data']?['logs'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();

    return logs.map(LedgerEntry.fromJson).toList(growable: false);
  }

  Future<Map<String, dynamic>> fetchMyMonthlySummary({String? month}) async {
    final response = await _client.get(
      _uri(
        month == null || month.trim().isEmpty
            ? '/api/customer/my-ledger/summary'
            : '/api/customer/my-ledger/summary?month=$month',
      ),
      headers: await _headers(),
    );

    final data = _parse(response);
    return (data['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
  }

  Future<Map<String, dynamic>> fetchSellerMonthlySummary({
    String? month,
  }) async {
    final response = await _client.get(
      _uri(
        month == null || month.trim().isEmpty
            ? '/api/seller/monthly-summary'
            : '/api/seller/monthly-summary?month=$month',
      ),
      headers: await _headers(),
    );

    final data = _parse(response);
    return (data['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
  }

  Future<Map<String, dynamic>> fetchSellerMilkSettings() async {
    final response = await _client.get(
      _uri('/api/seller/settings/milk'),
      headers: await _headers(),
    );

    final data = _parse(response);
    return (data['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
  }

  Future<Map<String, dynamic>> updateSellerMilkBasePrice({
    required double basePricePerLitreRupees,
  }) async {
    final response = await _client.patch(
      _uri('/api/seller/settings/milk/price'),
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
    final response = await _client.patch(
      _uri('/api/seller/settings/milk/customer-default-quantity'),
      headers: await _headers(),
      body: jsonEncode({
        'customerUserId': customerUserId,
        'defaultQuantityLitres': defaultQuantityLitres,
      }),
    );

    final data = _parse(response);
    return (data['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
  }
}
