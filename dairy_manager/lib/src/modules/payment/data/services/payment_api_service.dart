import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dairy_manager/core/utility/network/api_base_url.dart';
import 'package:http/http.dart' as http;

class PaymentApiService {
  PaymentApiService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = ApiBaseUrl.resolve(override: baseUrl);

  final http.Client _client;
  final String _baseUrl;

  Future<String> getRazorpayKeyId(String idToken) async {
    final response = await _authorizedGet('/v1/payments/config', idToken);
    final json = _ensureSuccess(response);

    final data = json['data'] as Map<String, dynamic>?;
    final keyId = data?['razorpayKeyId'] as String?;

    if (keyId == null || keyId.trim().isEmpty) {
      throw PaymentApiException('Razorpay key id not returned by backend.');
    }

    return keyId;
  }

  Future<PaymentOrder> createOrder({
    required String idToken,
    required double amountInRupees,
    String currency = 'INR',
    String? receipt,
    String? source,
    Map<String, dynamic>? notes,
  }) async {
    final response = await _authorizedPost('/v1/payments/orders', idToken, {
      'amountInRupees': amountInRupees,
      'currency': currency,
      if (receipt != null && receipt.trim().isNotEmpty) 'receipt': receipt,
      if (source != null && source.trim().isNotEmpty) 'source': source,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });

    final json = _ensureSuccess(response);
    final data = json['data'] as Map<String, dynamic>?;

    if (data == null) {
      throw PaymentApiException('Invalid payment order response.');
    }

    return PaymentOrder.fromJson(data);
  }

  Future<void> verifyPayment({
    required String idToken,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final response = await _authorizedPost('/v1/payments/verify', idToken, {
      'razorpayOrderId': razorpayOrderId,
      'razorpayPaymentId': razorpayPaymentId,
      'razorpaySignature': razorpaySignature,
    });

    _ensureSuccess(response);
  }

  Future<http.Response> _authorizedGet(String path, String token) {
    return _withNetworkHandling(() {
      return _client
          .get(_uri(path), headers: _headers(token))
          .timeout(const Duration(seconds: 15));
    });
  }

  Future<http.Response> _authorizedPost(
    String path,
    String token,
    Map<String, dynamic> payload,
  ) {
    return _withNetworkHandling(() {
      return _client
          .post(_uri(path), headers: _headers(token), body: jsonEncode(payload))
          .timeout(const Duration(seconds: 15));
    });
  }

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<http.Response> _withNetworkHandling(
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request();
    } on SocketException {
      throw PaymentApiException(
        'Unable to connect to server.${ApiBaseUrl.networkDebugHint(_baseUrl)}',
      );
    } on TimeoutException {
      throw PaymentApiException(
        'Payment request timed out.${ApiBaseUrl.networkDebugHint(_baseUrl)}',
      );
    } on http.ClientException catch (e) {
      throw PaymentApiException(e.message);
    }
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

    throw PaymentApiException(message);
  }
}

class PaymentOrder {
  const PaymentOrder({
    required this.orderId,
    required this.amountInPaise,
    required this.amountInRupees,
    required this.currency,
  });

  final String orderId;
  final int amountInPaise;
  final double amountInRupees;
  final String currency;

  factory PaymentOrder.fromJson(Map<String, dynamic> json) {
    return PaymentOrder(
      orderId: json['orderId'] as String? ?? '',
      amountInPaise: (json['amountInPaise'] as num?)?.toInt() ?? 0,
      amountInRupees: (json['amountInRupees'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'INR',
    );
  }
}

class PaymentApiException implements Exception {
  PaymentApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
