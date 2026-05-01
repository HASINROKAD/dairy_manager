import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../../../core/constant/constant_barrel.dart';
import '../../../../../core/utility/network/connectivity_recovery_bus.dart';
import '../../../auth/auth_barrel.dart';
import '../../data/models/nearby_seller.dart';
import '../bloc/home_feature_ui_cubit.dart';
import '../../data/repositories/home_repository.dart';
import '../../../milk/data/repositories/milk_repository.dart';
import '../../../payment/data/services/payment_api_service.dart';

class HomeFeaturePage extends StatefulWidget {
  const HomeFeaturePage({
    super.key,
    required this.featureKey,
    required this.role,
    required this.homeRepository,
    required this.milkRepository,
    this.onSellerJoinRequestAccepted,
    this.userLatitude,
    this.userLongitude,
  });

  final String featureKey;
  final String role;
  final HomeRepository homeRepository;
  final MilkRepository milkRepository;
  final Future<void> Function()? onSellerJoinRequestAccepted;
  final double? userLatitude;
  final double? userLongitude;

  @override
  State<HomeFeaturePage> createState() => _HomeFeaturePageState();
}

class _HomeFeaturePageState extends State<HomeFeaturePage> {
  late final HomeFeatureUiCubit _uiCubit;
  late final Razorpay _razorpay;
  final PaymentApiService _paymentApiService = PaymentApiService();

  final _issueDescriptionController = TextEditingController();
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  final _sellerCustomerSearchController = TextEditingController();
  final _sellerMilkPriceController = TextEditingController();
  String _sellerCustomerSearchQuery = '';
  late DateTime _sellerBillingSelectedMonth;
  Completer<void>? _activePaymentCompleter;
  String? _activeOrderId;
  String? _activePaymentMonthKey;
  String? _recentlyPaidCustomerMonthKey;
  final Set<String> _sendingJoinSellerUserIds = <String>{};
  String? _actingSellerRequestId;
  String? _actingSellerRequestAction;
  String? _savingSellerRouteDeliveryCustomerId;
  String? _savingSellerCustomerQuantityId;
  bool _savingSellerMilkPrice = false;
  bool _leavingOrganization = false;
  StreamSubscription<int>? _connectivityRecoverySubscription;

  @override
  void initState() {
    super.initState();
    _uiCubit = HomeFeatureUiCubit();
    final now = DateTime.now();
    _sellerBillingSelectedMonth = DateTime(now.year, now.month);
    _sellerCustomerSearchController.addListener(() {
      final nextQuery = _sellerCustomerSearchController.text.trim();
      if (nextQuery == _sellerCustomerSearchQuery || !mounted) {
        return;
      }
      setState(() {
        _sellerCustomerSearchQuery = nextQuery;
      });
    });
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
    _connectivityRecoverySubscription = ConnectivityRecoveryBus.stream.listen((
      _,
    ) {
      if (!mounted || _uiCubit.state.loading) {
        return;
      }
      _load();
    });
    _load();
  }

  @override
  void dispose() {
    _activePaymentCompleter = null;
    _activeOrderId = null;
    _activePaymentMonthKey = null;
    _sendingJoinSellerUserIds.clear();
    _actingSellerRequestId = null;
    _actingSellerRequestAction = null;
    _savingSellerRouteDeliveryCustomerId = null;
    _savingSellerCustomerQuantityId = null;
    _connectivityRecoverySubscription?.cancel();
    _razorpay.clear();
    _uiCubit.close();
    _issueDescriptionController.dispose();
    _sellerCustomerSearchController.dispose();
    _sellerMilkPriceController.dispose();
    super.dispose();
  }

  String get _title {
    switch (widget.featureKey) {
      case 'seller_requests':
        return 'Pending Join Requests';
      case 'seller_issues':
        return 'Delivery Issues';
      case 'seller_pauses':
        return 'Active Delivery Pauses';
      case 'seller_billing':
        return 'Seller Billing';
      case 'seller_routes':
        return 'Delivery Routes';
      case 'seller_customers':
        return 'Organization Customers';
      case 'seller_milk_settings':
        return 'Milk Settings';
      case 'customer_join':
        return 'My Join Requests';
      case 'customer_issues':
        return 'Report Delivery Issue';
      case 'customer_pauses':
        return 'Pause / Resume Delivery';
      case 'customer_billing':
        return 'Customer Billing';
      case 'notifications':
        return 'Notifications';
      default:
        return 'Feature';
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted || message.trim().isEmpty) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _load() async {
    _uiCubit.setLoading(true);

    try {
      List<Map<String, dynamic>> nextItems = const <Map<String, dynamic>>[];
      Map<String, dynamic> nextSummary = <String, dynamic>{};

      switch (widget.featureKey) {
        case 'seller_requests':
          final requests = await widget.homeRepository.fetchSellerJoinRequests(
            status: 'pending',
            sortBy: 'newest',
          );
          nextItems = requests
              .map(
                (item) => <String, dynamic>{
                  'id': item.id,
                  'title': item.customerName ?? 'Customer',
                  'status': item.status,
                  'distanceKm': item.distanceKm,
                  'requestedQuantityLitres': item.requestedQuantityLitres,
                  'customerArea': item.customerArea,
                  'createdAt': item.createdAt.toIso8601String(),
                },
              )
              .toList(growable: false);
          break;
        case 'seller_issues':
          nextItems = await widget.homeRepository.fetchSellerDeliveryIssues(
            status: 'open',
          );
          break;
        case 'seller_pauses':
          nextItems = await widget.homeRepository.fetchSellerDeliveryPauses();
          break;
        case 'seller_billing':
          final responses = await Future.wait<dynamic>([
            widget.milkRepository.fetchSellerMonthlySummary(
              month: _monthKey(_sellerBillingSelectedMonth),
            ),
            widget.homeRepository.fetchSellerCustomers(),
          ]);

          nextSummary =
              (responses[0] as Map<String, dynamic>? ?? <String, dynamic>{});
          nextSummary['organizationCustomers'] =
              (responses[1] as List<dynamic>? ?? <dynamic>[])
                  .whereType<Map<String, dynamic>>()
                  .toList(growable: false);
          break;
        case 'seller_routes':
          final sheet = await widget.milkRepository.fetchDailySheet();
          nextItems = sheet
              .map(
                (item) => <String, dynamic>{
                  'customerId': item.customerId,
                  'customerName': item.customerName,
                  'dateKey': item.dateKey,
                  'customerDisplayAddress': item.customerDisplayAddress,
                  'defaultQuantityLitres': item.defaultQuantityLitres,
                  'quantityLitres': item.quantityLitres,
                  'basePricePerLitreRupees': item.basePricePerLitreRupees,
                  'totalPriceRupees': item.totalPriceRupees,
                  'routeDistanceKm': item.routeDistanceKm,
                  'routeDistanceMeters': item.routeDistanceMeters,
                  'routeDistanceLabel': item.routeDistanceLabel,
                  'routeDistanceReason': item.routeDistanceReason,
                  'routeBucket': item.routeBucket,
                  'delivered': item.delivered,
                },
              )
              .toList(growable: false);
          nextSummary = <String, dynamic>{'count': nextItems.length};
          break;
        case 'seller_milk_settings':
          final settings = await widget.milkRepository
              .fetchSellerMilkSettings();
          final customers =
              (settings['customers'] as List<dynamic>? ?? <dynamic>[])
                  .whereType<Map<String, dynamic>>()
                  .toList(growable: false);
          final basePrice =
              (settings['basePricePerLitreRupees'] as num?)?.toDouble() ?? 60;

          nextItems = customers;
          nextSummary = <String, dynamic>{
            'basePricePerLitreRupees': basePrice,
            'count': customers.length,
          };
          break;
        case 'seller_customers':
          final customers = await widget.homeRepository.fetchSellerCustomers();
          nextItems = customers
              .map(
                (item) => <String, dynamic>{
                  'customerUserId': item['customerUserId'],
                  'name': item['name'],
                  'phone': item['phone'],
                  'email': item['email'],
                  'displayAddress': item['displayAddress'],
                  'defaultQuantityLitres': item['defaultQuantityLitres'],
                  'linkedAt': item['linkedAt'],
                  'pauseStatus': item['pauseStatus'],
                  'isPausedToday': item['isPausedToday'],
                  'pauseStartDateKey': item['pauseStartDateKey'],
                  'pauseEndDateKey': item['pauseEndDateKey'],
                },
              )
              .toList(growable: false);
          nextSummary = <String, dynamic>{'count': nextItems.length};
          break;
        case 'customer_join':
          final hasSavedLocation =
              widget.userLatitude != null && widget.userLongitude != null;
          List<Map<String, dynamic>> nearbySellers =
              const <Map<String, dynamic>>[];
          const double nearbyRadiusKm = 10;

          final nearbyFuture = hasSavedLocation
              ? widget.homeRepository.fetchNearbySellers(
                  latitude: widget.userLatitude!,
                  longitude: widget.userLongitude!,
                  radiusKm: nearbyRadiusKm,
                )
              : Future.value(const <NearbySeller>[]);

          final responses = await Future.wait<dynamic>([
            widget.homeRepository.fetchMyJoinRequests(),
            widget.homeRepository.fetchCustomerOrganization(),
            nearbyFuture,
          ]);

          final requests = responses[0] as List<dynamic>? ?? const <dynamic>[];
          final organization = responses[1] as Map<String, dynamic>?;
          final hasActiveOrganization =
              (organization?['sellerUserId']?.toString().trim().isNotEmpty ??
              false);

          if (!hasActiveOrganization && hasSavedLocation) {
            final sellers =
                (responses[2] as List<dynamic>? ?? const <dynamic>[])
                    .whereType<NearbySeller>()
                    .toList(growable: false);

            nearbySellers = sellers
                .map(
                  (seller) => <String, dynamic>{
                    'sellerUserId': seller.sellerUserId,
                    'name': seller.name,
                    'shopName': seller.shopName,
                    'displayAddress': seller.displayAddress,
                    'distanceKm': seller.distanceKm,
                    'basePricePerLitreRupees': seller.basePricePerLitreRupees,
                    'isServiceAvailable': seller.isServiceAvailable,
                  },
                )
                .toList(growable: false);
          }

          nextItems = requests
              .whereType<dynamic>()
              .map(
                (item) => <String, dynamic>{
                  'id': item.id,
                  'sellerUserId': item.sellerUserId,
                  'title': item.sellerName ?? 'Seller',
                  'status': item.status,
                  'respondedAt': item.respondedAt?.toIso8601String(),
                  'rejectionReason': item.rejectionReason,
                  'createdAt': item.createdAt.toIso8601String(),
                },
              )
              .toList(growable: false);
          nextSummary = <String, dynamic>{
            'hasSavedLocation': hasSavedLocation,
            'hasActiveOrganization': hasActiveOrganization,
            'organization': organization,
            'nearbySellers': nearbySellers,
            'nearbyRadiusKm': nearbyRadiusKm,
          };
          break;
        case 'customer_issues':
          nextItems = await widget.homeRepository.fetchMyDeliveryIssues();
          break;
        case 'customer_pauses':
          nextItems = await widget.homeRepository.fetchMyDeliveryPauses();
          break;
        case 'customer_billing':
          nextSummary = await widget.milkRepository.fetchMyMonthlySummary();
          break;
        case 'notifications':
          final feed = await widget.homeRepository.fetchNotifications();
          nextItems = feed.items
              .map(
                (item) => <String, dynamic>{
                  'id': item.id,
                  'title': item.title,
                  'message': item.message,
                  'isRead': item.isRead,
                  'createdAt': item.createdAt.toIso8601String(),
                },
              )
              .toList(growable: false);
          nextSummary = <String, dynamic>{'unreadCount': feed.unreadCount};
          break;
      }

      if (mounted) {
        _uiCubit.replaceData(items: nextItems, summary: nextSummary);
        _uiCubit.setLoading(false);
      }
    } catch (error) {
      if (mounted) {
        _uiCubit.setLoading(false);
      }
      _showMessage(error.toString(), error: true);
    }
  }

  Future<void> _resolveIssue(String issueId) async {
    try {
      await widget.homeRepository.resolveSellerDeliveryIssue(issueId: issueId);
      await _load();
      _showMessage('Issue resolved.');
    } catch (error) {
      _showMessage(error.toString(), error: true);
    }
  }

  Future<void> _resumePause(String pauseId) async {
    try {
      await widget.homeRepository.resumeMyDeliveryPause(pauseId);
      await _load();
      _showMessage('Pause resumed.');
    } catch (error) {
      _showMessage(error.toString(), error: true);
    }
  }

  Future<void> _sendJoinRequest(String sellerUserId) async {
    final normalizedSellerUserId = sellerUserId.trim();
    if (normalizedSellerUserId.isEmpty) {
      return;
    }

    if (_sendingJoinSellerUserIds.contains(normalizedSellerUserId)) {
      return;
    }

    if (mounted) {
      setState(() {
        _sendingJoinSellerUserIds.add(normalizedSellerUserId);
      });
    }
    try {
      await widget.homeRepository.sendJoinRequest(normalizedSellerUserId);
      await _load();
      _showMessage('Join request sent successfully.');
    } catch (error) {
      _showMessage(error.toString(), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _sendingJoinSellerUserIds.remove(normalizedSellerUserId);
        });
      }
    }
  }

  Future<void> _reviewSellerJoinRequest({
    required String requestId,
    required String action,
    String? rejectionReason,
  }) async {
    final normalizedRequestId = requestId.trim();
    final normalizedAction = action.trim().toLowerCase();
    if (normalizedRequestId.isEmpty ||
        !(normalizedAction == 'accept' || normalizedAction == 'reject')) {
      return;
    }

    if ((_actingSellerRequestId ?? '').trim().isNotEmpty) {
      return;
    }

    if (mounted) {
      setState(() {
        _actingSellerRequestId = normalizedRequestId;
        _actingSellerRequestAction = normalizedAction;
      });
    }

    try {
      await widget.homeRepository.reviewJoinRequest(
        requestId: normalizedRequestId,
        action: normalizedAction,
        rejectionReason: rejectionReason,
      );

      if (normalizedAction == 'accept') {
        await widget.onSellerJoinRequestAccepted?.call();
      }

      await _load();
      _showMessage(
        normalizedAction == 'accept'
            ? 'Join request accepted successfully.'
            : 'Join request rejected successfully.',
      );
    } catch (error) {
      await _load();
      _showMessage(error.toString(), error: true);
    } finally {
      if (mounted && _actingSellerRequestId == normalizedRequestId) {
        setState(() {
          _actingSellerRequestId = null;
          _actingSellerRequestAction = null;
        });
      }
    }
  }

  Future<void> _promptRejectSellerJoinRequest(String requestId) async {
    final reasonController = TextEditingController();

    try {
      final result = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Reject Join Request'),
            content: TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'Enter reason to help customer understand',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(reasonController.text.trim()),
                child: const Text('Reject'),
              ),
            ],
          );
        },
      );

      if (!mounted || result == null) {
        return;
      }

      await _reviewSellerJoinRequest(
        requestId: requestId,
        action: 'reject',
        rejectionReason: result,
      );
    } finally {
      reasonController.dispose();
    }
  }

  Future<void> _confirmAndLeaveCurrentOrganization() async {
    if (_leavingOrganization) {
      return;
    }

    final authCubit = context.read<AuthCubit>();
    final navigator = Navigator.of(context);

    if (mounted) {
      setState(() {
        _leavingOrganization = true;
      });
    }

    try {
      final preview = await widget.homeRepository
          .fetchLeaveCustomerOrganizationPreview();
      final pendingRupees = (preview['pendingRupees'] as num?)?.toDouble() ?? 0;
      final canLeave = preview['canLeave'] == true;
      final organization = preview['organization'] as Map<String, dynamic>?;
      final shopName = (organization?['shopName']?.toString() ?? '').trim();
      final sellerName =
          (organization?['sellerName']?.toString() ?? 'your organization')
              .trim();
      final organizationName = shopName.isNotEmpty ? shopName : sellerName;

      if (!mounted) {
        return;
      }

      if (pendingRupees > 0 || !canLeave) {
        _showMessage(
          'Please clear pending dues of ₹${pendingRupees.toStringAsFixed(2)} before leaving your organization.',
          error: true,
        );
        return;
      }

      final shouldLeave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Leave Organization?'),
            content: Text(
              'Organization: $organizationName\nPending dues: ₹${pendingRupees.toStringAsFixed(2)}\n\nDo you want to continue and leave this organization?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Leave'),
              ),
            ],
          );
        },
      );

      if (shouldLeave != true) {
        return;
      }

      await widget.homeRepository.leaveCustomerOrganization();
      await authCubit.refreshSessionUser();
      _showMessage('You have left the organization successfully.');
      if (mounted) {
        navigator.pop();
      }
    } catch (error) {
      _showMessage(error.toString(), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _leavingOrganization = false;
        });
      }
    }
  }

  Future<void> _reportIssue() async {
    try {
      await widget.homeRepository.reportDeliveryIssue(
        issueType: _uiCubit.state.issueType,
        description: _issueDescriptionController.text,
      );
      _issueDescriptionController.clear();
      await _load();
      _showMessage('Issue submitted.');
    } catch (error) {
      _showMessage(error.toString(), error: true);
    }
  }

  Future<void> _createPause() async {
    try {
      if (_selectedStartDate == null || _selectedEndDate == null) {
        _showMessage('Please select both start and end dates.', error: true);
        return;
      }

      final normalizedStartDate = DateUtils.dateOnly(_selectedStartDate!);
      final normalizedEndDate = DateUtils.dateOnly(_selectedEndDate!);
      if (normalizedEndDate.isBefore(normalizedStartDate)) {
        _showMessage('End date cannot be before start date.', error: true);
        return;
      }

      String toDateKey(DateTime date) {
        return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      }

      await widget.homeRepository.createDeliveryPause(
        startDateKey: toDateKey(normalizedStartDate),
        endDateKey: toDateKey(normalizedEndDate),
      );

      await _load();
      _showMessage('Pause created.');
      if (mounted) {
        setState(() {
          _selectedStartDate = null;
          _selectedEndDate = null;
        });
      }
    } catch (error) {
      _showMessage(error.toString(), error: true);
    }
  }

  double _pendingRupeesFromSummary(Map<String, dynamic> summaryMap) {
    final pendingRupees = summaryMap['pendingRupees'];
    if (pendingRupees is num) {
      return pendingRupees.toDouble();
    }

    final pendingPaise = summaryMap['pendingPaise'];
    if (pendingPaise is num) {
      return pendingPaise.toDouble() / 100;
    }

    return 0;
  }

  Future<void> _payPendingDues(Map<String, dynamic> summaryMap) async {
    if (_uiCubit.state.processingPayment) {
      return;
    }

    final pendingRupees = _pendingRupeesFromSummary(summaryMap);
    if (pendingRupees < 1) {
      _showMessage('No payable pending amount found for this month.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('Session expired. Please log in again.', error: true);
      return;
    }

    _uiCubit.setProcessingPayment(true);

    try {
      final idToken = (await user.getIdToken() ?? '').trim();
      if (idToken.isEmpty) {
        throw Exception('Unable to fetch auth token. Please login again.');
      }

      final keyId = await _paymentApiService.getRazorpayKeyId(idToken);
      final order = await _paymentApiService.createOrder(
        idToken: idToken,
        amountInRupees: pendingRupees,
        source: 'customer_monthly_due',
        notes: {
          'month': statefulMonthFromSummary(summaryMap),
          'userUid': user.uid,
        },
      );

      _activeOrderId = order.orderId;
      _activePaymentMonthKey = statefulMonthFromSummary(summaryMap);
      _activePaymentCompleter = Completer<void>();

      _razorpay.open({
        'key': keyId,
        'amount': order.amountInPaise,
        'currency': order.currency,
        'name': 'Dairy Manager',
        'description': 'Monthly milk bill payment',
        'order_id': order.orderId,
        'prefill': {
          'email': user.email ?? '',
          'contact': user.phoneNumber ?? '',
        },
        'theme': {'color': '#2E7D32'},
      });

      await _activePaymentCompleter!.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw TimeoutException('Payment confirmation timed out.');
        },
      );
    } catch (error) {
      _showMessage(error.toString(), error: true);
    } finally {
      _activeOrderId = null;
      _activePaymentCompleter = null;
      _activePaymentMonthKey = null;
      if (mounted) {
        _uiCubit.setProcessingPayment(false);
      }
    }
  }

  String statefulMonthFromSummary(Map<String, dynamic> summaryMap) {
    final month = summaryMap['month']?.toString();
    if (month != null && month.trim().isNotEmpty) {
      return month;
    }

    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    return '${now.year}-$mm';
  }

  void _completePaymentFlow([String? message]) {
    if (message != null && message.trim().isNotEmpty) {
      _showMessage(message);
    }

    final completer = _activePaymentCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    final completer = _activePaymentCompleter;
    if (completer == null || completer.isCompleted) {
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Session expired after payment. Please log in again.');
      }

      final idToken = (await user.getIdToken() ?? '').trim();
      if (idToken.isEmpty) {
        throw Exception('Unable to fetch auth token. Please login again.');
      }
      final orderId = _activeOrderId ?? response.orderId ?? '';
      final paymentId = response.paymentId ?? '';
      final signature = response.signature ?? '';

      if (orderId.trim().isEmpty ||
          paymentId.trim().isEmpty ||
          signature.trim().isEmpty) {
        throw Exception('Missing payment verification details from gateway.');
      }

      await _paymentApiService.verifyPayment(
        idToken: idToken,
        razorpayOrderId: orderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: signature,
      );

      final paidMonthKey = _activePaymentMonthKey;
      if (mounted && paidMonthKey != null && paidMonthKey.trim().isNotEmpty) {
        setState(() {
          _recentlyPaidCustomerMonthKey = paidMonthKey;
        });
      }

      await _load();
      _completePaymentFlow('Payment successful and verified.');
    } catch (error) {
      _showMessage(error.toString(), error: true);
      _completePaymentFlow();
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    final message = response.message?.trim();
    if (message != null && message.isNotEmpty) {
      _showMessage('Payment failed: $message', error: true);
    } else {
      _showMessage('Payment failed or cancelled.', error: true);
    }
    _completePaymentFlow();
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    final walletName = response.walletName?.trim();
    if (walletName != null && walletName.isNotEmpty) {
      _showMessage('External wallet selected: $walletName');
    }
  }

  String _prettyDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return '-';
    }

    try {
      final parsed = DateTime.parse(raw).toLocal();
      final mm = parsed.month.toString().padLeft(2, '0');
      final dd = parsed.day.toString().padLeft(2, '0');
      final hh = parsed.hour.toString().padLeft(2, '0');
      final min = parsed.minute.toString().padLeft(2, '0');
      return '${parsed.year}-$mm-$dd  $hh:$min';
    } catch (_) {
      return raw;
    }
  }

  DateTime? _parseDateKey(String? raw) {
    final value = (raw ?? '').trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return null;
    }

    return DateTime.tryParse(value);
  }

  String _formatDateKeyLabel(String? raw) {
    final parsed = _parseDateKey(raw);
    if (parsed == null) {
      return (raw ?? '-').trim().isEmpty ? '-' : raw!.trim();
    }

    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final month = months[parsed.month - 1];
    final day = parsed.day.toString().padLeft(2, '0');
    return '$day $month ${parsed.year}';
  }

  int? _pauseDurationDays(String? startDateKey, String? endDateKey) {
    final start = _parseDateKey(startDateKey);
    final end = _parseDateKey(endDateKey);
    if (start == null || end == null) {
      return null;
    }

    final duration = end.difference(start).inDays + 1;
    if (duration <= 0) {
      return null;
    }

    return duration;
  }

  String _customerPauseSummary({
    required String status,
    required String? startDateKey,
    required String? endDateKey,
  }) {
    final normalizedStatus = status.trim().toLowerCase();
    if (normalizedStatus == 'resumed') {
      return 'Resumed by you';
    }

    if (normalizedStatus != 'active') {
      return status.toUpperCase();
    }

    final now = DateUtils.dateOnly(DateTime.now());
    final start = _parseDateKey(startDateKey);
    final end = _parseDateKey(endDateKey);
    if (start == null || end == null) {
      return 'Active pause';
    }

    if (now.isBefore(start)) {
      return 'Scheduled';
    }

    if (now.isAfter(end)) {
      return 'Ended';
    }

    return 'Active now';
  }

  Color _statusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'approved':
      case 'accepted':
      case 'resolved':
      case 'active':
        return AppColors.success;
      case 'pending':
      case 'open':
        return AppColors.warning;
      case 'rejected':
      case 'paused':
      case 'expired':
        return AppColors.danger;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _sectionTitle(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        if (subtitle != null && subtitle.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(description),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricChip(String label, Object? value, {IconData? icon}) {
    final display = _formatMetricValue(label, value);
    return Chip(
      avatar: icon == null ? null : Icon(icon, size: 16),
      label: Text('${_formatMetricLabel(label)}: $display'),
      visualDensity: VisualDensity.compact,
    );
  }

  String _formatMetricLabel(String label) {
    return label;
  }

  String _formatMetricValue(String label, Object? value) {
    if (value == null) {
      return '-';
    }

    final lower = label.toLowerCase();
    if (lower.contains('rupees') ||
        lower.contains('payment') ||
        lower == 'pending') {
      final numValue = value as num?;
      if (numValue == null) {
        return value.toString();
      }
      return '₹${numValue.toStringAsFixed(2)}';
    }

    if (lower.contains('quantity') || lower.contains('litres')) {
      final numValue = value as num?;
      if (numValue == null) {
        return value.toString();
      }
      return '${numValue.toStringAsFixed(2)} L';
    }

    return value.toString();
  }

  Widget _buildSellerRequests() {
    final state = _uiCubit.state;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _sectionTitle(
          'Pending Requests',
          subtitle:
              'Newest requests first. Open full request flow from dashboard.',
        ),
        const SizedBox(height: 8),
        if (state.items.isEmpty)
          _emptyState(
            icon: Icons.inbox_outlined,
            title: 'No pending requests',
            description: 'New customer requests will appear here.',
          ),
        ...state.items.map((item) {
          final status = item['status']?.toString() ?? 'pending';
          final requestId = item['id']?.toString() ?? '';
          final isPending = status.trim().toLowerCase() == 'pending';
          final isActing = _actingSellerRequestId == requestId;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['title']?.toString() ?? 'Customer',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Chip(
                        label: Text(status.toUpperCase()),
                        backgroundColor: _statusColor(
                          status,
                        ).withValues(alpha: 0.14),
                        side: BorderSide(
                          color: _statusColor(status).withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _metricChip(
                        'Litres',
                        item['requestedQuantityLitres'],
                        icon: Icons.opacity_outlined,
                      ),
                      _metricChip(
                        'Distance',
                        '${item['distanceKm'] ?? '-'} km',
                        icon: Icons.route_outlined,
                      ),
                      _metricChip(
                        'Area',
                        item['customerArea'] ?? '-',
                        icon: Icons.place_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Requested: ${_prettyDate(item['createdAt']?.toString())}',
                  ),
                  if (isPending) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isActing || requestId.trim().isEmpty
                                ? null
                                : () =>
                                      _promptRejectSellerJoinRequest(requestId),
                            icon: const Icon(Icons.close_rounded),
                            label: Text(
                              isActing && _actingSellerRequestAction == 'reject'
                                  ? 'Rejecting...'
                                  : 'Reject',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: isActing || requestId.trim().isEmpty
                                ? null
                                : () => _reviewSellerJoinRequest(
                                    requestId: requestId,
                                    action: 'accept',
                                  ),
                            icon: const Icon(Icons.check_rounded),
                            label: Text(
                              isActing && _actingSellerRequestAction == 'accept'
                                  ? 'Accepting...'
                                  : 'Accept',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSellerIssues() {
    final state = _uiCubit.state;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _sectionTitle(
          'Open Delivery Issues',
          subtitle:
              'Resolve complaints to keep trust and delivery quality high.',
        ),
        const SizedBox(height: 8),
        if (state.items.isEmpty)
          _emptyState(
            icon: Icons.task_alt_rounded,
            title: 'No open issues',
            description: 'You are all clear for now.',
          ),
        ...state.items.map((issue) {
          final issueId = issue['id']?.toString() ?? '';
          final status = issue['status']?.toString() ?? 'open';
          final issueType = issue['issueType']?.toString() ?? '-';
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          issue['customerName']?.toString() ?? 'Customer',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Chip(
                        label: Text(issueType.replaceAll('_', ' ')),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 6),
                      Chip(
                        label: Text(status.toUpperCase()),
                        backgroundColor: _statusColor(
                          status,
                        ).withValues(alpha: 0.14),
                        side: BorderSide(
                          color: _statusColor(status).withValues(alpha: 0.4),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(issue['description']?.toString() ?? '-'),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: issueId.trim().isEmpty
                          ? null
                          : () => _resolveIssue(issueId),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Mark resolved'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _saveSellerMilkBasePrice() async {
    final raw = _sellerMilkPriceController.text.trim();
    final parsed = double.tryParse(raw);
    if (parsed == null || parsed <= 0) {
      _showMessage(
        'Enter a valid milk price per litre in rupees.',
        error: true,
      );
      return;
    }

    if (_savingSellerMilkPrice) {
      return;
    }

    if (mounted) {
      setState(() {
        _savingSellerMilkPrice = true;
      });
    }

    try {
      await widget.milkRepository.updateSellerMilkBasePrice(
        basePricePerLitreRupees: parsed,
      );
      await _load();
      _showMessage('Milk price updated successfully.');
    } catch (error) {
      _showMessage(error.toString(), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _savingSellerMilkPrice = false;
        });
      }
    }
  }

  Future<void> _updateSellerCustomerDefaultQuantity({
    required String customerUserId,
    required double currentQuantity,
  }) async {
    final qtyController = TextEditingController(
      text: currentQuantity.toStringAsFixed(2),
    );

    try {
      final value = await showDialog<double>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Update Default Quantity'),
            content: TextField(
              controller: qtyController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Quantity (litres)',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final parsed = double.tryParse(qtyController.text.trim());
                  if (parsed == null || parsed <= 0) {
                    return;
                  }
                  Navigator.of(dialogContext).pop(parsed);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      if (value == null) {
        return;
      }

      if ((_savingSellerCustomerQuantityId ?? '').trim().isNotEmpty) {
        return;
      }

      if (mounted) {
        setState(() {
          _savingSellerCustomerQuantityId = customerUserId;
        });
      }

      await widget.milkRepository.updateSellerCustomerDefaultQuantity(
        customerUserId: customerUserId,
        defaultQuantityLitres: value,
      );
      await _load();
      _showMessage('Customer default quantity updated.');
    } catch (error) {
      _showMessage(error.toString(), error: true);
    } finally {
      qtyController.dispose();
      if (mounted && _savingSellerCustomerQuantityId == customerUserId) {
        setState(() {
          _savingSellerCustomerQuantityId = null;
        });
      }
    }
  }

  void _showSellerRouteCustomerBottomSheet(Map<String, dynamic> item) {
    final customerName = item['customerName']?.toString() ?? 'Customer';
    final customerId = item['customerId']?.toString() ?? '';
    final dateKey = (item['dateKey']?.toString() ?? '').trim();
    final todayQuantity = (item['quantityLitres'] as num?)?.toDouble() ?? 0;
    final basePrice =
        (item['basePricePerLitreRupees'] as num?)?.toDouble() ?? 0;
    final totalRupees = (item['totalPriceRupees'] as num?)?.toDouble() ?? 0;
    final quantityController = TextEditingController(
      text: todayQuantity > 0 ? todayQuantity.toStringAsFixed(2) : '1.00',
    );
    final bool isAlreadyDelivered = item['delivered'] == true;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final sheetNavigator = Navigator.of(sheetContext);

        return SafeArea(
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customerName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Date: ${dateKey.isEmpty ? _monthKey(DateTime.now()) : dateKey}',
                          ),
                          Text(
                            'Milk taken today: ${todayQuantity.toStringAsFixed(2)} L',
                          ),
                          Text(
                            'Delivery status: ${isAlreadyDelivered ? 'Delivered' : 'Pending'}',
                          ),
                          Text(
                            'Rate: ₹${basePrice.toStringAsFixed(2)} per litre',
                          ),
                          Text(
                            'Today\'s total: ₹${totalRupees.toStringAsFixed(2)}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Add milk for today (litres)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: customerId.trim().isEmpty
                          ? null
                          : () async {
                              final quantity = double.tryParse(
                                quantityController.text.trim(),
                              );
                              if (quantity == null || quantity <= 0) {
                                _showMessage(
                                  'Enter a valid milk quantity in litres.',
                                  error: true,
                                );
                                return;
                              }

                              if ((_savingSellerRouteDeliveryCustomerId ?? '')
                                  .trim()
                                  .isNotEmpty) {
                                return;
                              }

                              if (mounted) {
                                setState(() {
                                  _savingSellerRouteDeliveryCustomerId =
                                      customerId;
                                });
                              }

                              try {
                                await widget.milkRepository.deliverCustomer(
                                  customerId: customerId,
                                  quantityLitres: quantity,
                                );
                                if (!mounted) {
                                  return;
                                }
                                sheetNavigator.pop();
                                await _load();
                                _showMessage(
                                  'Customer marked delivered for today.',
                                );
                              } catch (error) {
                                _showMessage(error.toString(), error: true);
                              } finally {
                                if (mounted &&
                                    _savingSellerRouteDeliveryCustomerId ==
                                        customerId) {
                                  setState(() {
                                    _savingSellerRouteDeliveryCustomerId = null;
                                  });
                                }
                              }
                            },
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(
                        _savingSellerRouteDeliveryCustomerId == customerId
                            ? 'Saving...'
                            : 'Mark Delivered for Today',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _sellerRouteDistanceText(Map<String, dynamic> item) {
    final routeDistanceKm = (item['routeDistanceKm'] as num?)?.toDouble();
    final routeDistanceMeters = (item['routeDistanceMeters'] as num?)?.toInt();
    final routeDistanceLabel =
        (item['routeDistanceLabel']?.toString() ?? 'Route').trim();
    final routeReason = (item['routeDistanceReason']?.toString() ?? '').trim();
    final reasonSuffix = routeReason.isEmpty ? '' : ' ($routeReason)';

    if (routeDistanceMeters != null && routeDistanceMeters < 1000) {
      final distanceText = '$routeDistanceMeters m';
      return 'Distance: $distanceText ($routeDistanceLabel)$reasonSuffix';
    }

    if (routeDistanceKm == null) {
      return routeDistanceLabel.isEmpty
          ? 'Route pending$reasonSuffix'
          : '$routeDistanceLabel$reasonSuffix';
    }

    final distanceText = '${routeDistanceKm.toStringAsFixed(2)} km';
    return 'Distance: $distanceText ($routeDistanceLabel)$reasonSuffix';
  }

  Widget _buildSellerRoutes() {
    final state = _uiCubit.state;
    final totalCount =
        (state.summary['count'] as num?)?.toInt() ?? state.items.length;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          'Today: ${_monthKey(DateTime.now())}-${DateTime.now().day.toString().padLeft(2, '0')}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        _sectionTitle(
          'Delivery Routes',
          subtitle: 'Today\'s route plan for $totalCount customers.',
        ),
        const SizedBox(height: 8),
        ...state.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final address = (item['customerDisplayAddress']?.toString() ?? '')
              .trim();
          final distanceLabel = _sellerRouteDistanceText(item);

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                _showSellerRouteCustomerBottomSheet(item);
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(radius: 14, child: Text('${index + 1}')),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item['customerName']?.toString() ?? 'Customer',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (item['delivered'] == true)
                          const Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (address.isNotEmpty) Text(address),
                    Text(distanceLabel),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Tap to view milk requirement details.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSellerMilkSettings() {
    final state = _uiCubit.state;
    final basePrice =
        (state.summary['basePricePerLitreRupees'] as num?)?.toDouble() ?? 60;
    final totalCustomers =
        (state.summary['count'] as num?)?.toInt() ?? state.items.length;

    if (_sellerMilkPriceController.text.trim().isEmpty &&
        !_savingSellerMilkPrice) {
      _sellerMilkPriceController.text = basePrice.toStringAsFixed(2);
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _sectionTitle(
          'Milk Settings',
          subtitle:
              'Set default price per litre in rupees and default quantity per customer.',
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _sellerMilkPriceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Milk price per litre (₹)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _savingSellerMilkPrice
                        ? null
                        : _saveSellerMilkBasePrice,
                    icon: const Icon(Icons.save_rounded),
                    label: Text(
                      _savingSellerMilkPrice ? 'Saving...' : 'Save Milk Price',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _sectionTitle(
          'Customer Default Quantity',
          subtitle: 'Total linked customers: $totalCustomers',
        ),
        const SizedBox(height: 8),
        ...state.items.map((item) {
          final customerUserId = item['customerUserId']?.toString() ?? '';
          final qty = (item['defaultQuantityLitres'] as num?)?.toDouble() ?? 1;
          final isSavingQty = _savingSellerCustomerQuantityId == customerUserId;

          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              title: Text(
                item['name']?.toString().trim().isNotEmpty == true
                    ? item['name'].toString()
                    : 'Customer',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'Default: ${qty.toStringAsFixed(2)} L • Phone: ${item['phone'] ?? '-'}',
              ),
              trailing: OutlinedButton.icon(
                onPressed: isSavingQty || customerUserId.trim().isEmpty
                    ? null
                    : () => _updateSellerCustomerDefaultQuantity(
                        customerUserId: customerUserId,
                        currentQuantity: qty,
                      ),
                icon: const Icon(Icons.edit_rounded),
                label: Text(isSavingQty ? 'Saving...' : 'Edit'),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSellerCustomers() {
    final state = _uiCubit.state;
    final totalCount =
        (state.summary['count'] as num?)?.toInt() ?? state.items.length;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _sectionTitle(
          'Joined Customers',
          subtitle: 'Total joined customers: $totalCount',
        ),
        const SizedBox(height: 8),
        if (state.items.isEmpty)
          _emptyState(
            icon: Icons.groups_2_outlined,
            title: 'No joined customers yet',
            description:
                'Approved customers linked to your organization will appear here.',
          ),
        ...state.items.map((item) {
          final name = (item['name']?.toString() ?? '').trim();
          final quantity = (item['defaultQuantityLitres'] as num?)?.toDouble();
          final isPausedToday = item['isPausedToday'] == true;
          final pauseStart = (item['pauseStartDateKey']?.toString() ?? '')
              .trim();
          final pauseEnd = (item['pauseEndDateKey']?.toString() ?? '').trim();

          return Card(
            color: isPausedToday
                ? Theme.of(context).colorScheme.surfaceContainerLow
                : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name.isEmpty ? 'Customer' : name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Chip(
                        label: Text(isPausedToday ? 'Paused' : 'Active'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: _statusColor(
                          isPausedToday ? 'paused' : 'active',
                        ).withValues(alpha: 0.14),
                        side: BorderSide(
                          color: _statusColor(
                            isPausedToday ? 'paused' : 'active',
                          ).withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Phone: ${item['phone'] ?? '-'}'),
                  Text('Email: ${item['email'] ?? '-'}'),
                  Text('Address: ${item['displayAddress'] ?? '-'}'),
                  Text(
                    quantity == null
                        ? 'Default Quantity: -'
                        : 'Default Quantity: ${quantity.toStringAsFixed(2)} L',
                  ),
                  Text(
                    'Linked At: ${_prettyDate(item['linkedAt']?.toString())}',
                  ),
                  if (isPausedToday)
                    Text(
                      pauseStart.isNotEmpty && pauseEnd.isNotEmpty
                          ? 'Current Pause: $pauseStart to $pauseEnd'
                          : 'Current Pause: Active',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPauses({required bool customerMode}) {
    final state = _uiCubit.state;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _sectionTitle(
          customerMode ? 'Pause Planner' : 'Customer Delivery Pauses',
          subtitle: customerMode
              ? 'Select a start and end date for your pause period.'
              : 'Track active and historical customer pauses.',
        ),
        const SizedBox(height: 8),
        if (customerMode)
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Pause Dates',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedStartDate ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked != null) {
                              setState(() {
                                _selectedStartDate = picked;
                                if (_selectedEndDate != null &&
                                    _selectedEndDate!.isBefore(picked)) {
                                  _selectedEndDate = null;
                                }
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Start Date',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              _selectedStartDate == null
                                  ? 'Select date'
                                  : '${_selectedStartDate!.year}-${_selectedStartDate!.month.toString().padLeft(2, '0')}-${_selectedStartDate!.day.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: _selectedStartDate == null
                                    ? Colors.grey
                                    : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _selectedStartDate == null
                              ? null
                              : () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate:
                                        _selectedEndDate ??
                                        _selectedStartDate!.add(
                                          const Duration(days: 1),
                                        ),
                                    firstDate: _selectedStartDate!,
                                    lastDate: DateTime.now().add(
                                      const Duration(days: 365),
                                    ),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _selectedEndDate = picked;
                                    });
                                  }
                                },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'End Date',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              _selectedEndDate == null
                                  ? 'Select date'
                                  : '${_selectedEndDate!.year}-${_selectedEndDate!.month.toString().padLeft(2, '0')}-${_selectedEndDate!.day.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: _selectedEndDate == null
                                    ? Colors.grey
                                    : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed:
                          (_selectedStartDate != null &&
                              _selectedEndDate != null)
                          ? () => _createPause()
                          : null,
                      icon: const Icon(Icons.pause_circle_outline),
                      label: const Text('Create pause'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (state.items.isEmpty)
          _emptyState(
            icon: Icons.event_available_outlined,
            title: 'No pauses found',
            description: customerMode
                ? 'Your created pauses will appear here.'
                : 'Customer pauses will appear here when active or scheduled.',
          ),
        ...state.items.map((pause) {
          final status = pause['status']?.toString() ?? '-';
          final pauseId = pause['id']?.toString() ?? '';
          final startDateKey = pause['startDateKey']?.toString();
          final endDateKey = pause['endDateKey']?.toString();
          final customerName = (pause['customerName']?.toString() ?? '').trim();
          final customerPhone = (pause['customerPhone']?.toString() ?? '')
              .trim();
          final customerAddress =
              (pause['customerDisplayAddress']?.toString() ?? '').trim();
          final customerQuantity =
              (pause['customerDefaultQuantityLitres'] as num?)?.toDouble();
          final isActive = status.trim().toLowerCase() == 'active';
          final showCustomerResume = customerMode && isActive;
          final durationDays = _pauseDurationDays(startDateKey, endDateKey);
          final customerPauseSummary = _customerPauseSummary(
            status: status,
            startDateKey: startDateKey,
            endDateKey: endDateKey,
          );

          final titleText = customerMode
              ? 'Delivery Pause'
              : (customerName.isEmpty ? 'Customer' : customerName);

          final pausePeriodText =
              'Pause: ${pause['startDateKey'] ?? '-'} to ${pause['endDateKey'] ?? '-'}';

          if (customerMode) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            titleText,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (showCustomerResume)
                          OutlinedButton(
                            onPressed: pauseId.trim().isEmpty
                                ? null
                                : () => _resumePause(pauseId),
                            child: const Text('Resume'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.event_available_outlined, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'From ${_formatDateKeyLabel(startDateKey)} to ${_formatDateKeyLabel(endDateKey)}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.timelapse_rounded, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          durationDays == null
                              ? 'Duration unavailable'
                              : 'Duration: $durationDays day${durationDays == 1 ? '' : 's'}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.history_rounded, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Requested: ${_prettyDate(pause['createdAt']?.toString())}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(customerPauseSummary.toUpperCase()),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: _statusColor(
                            isActive ? 'active' : status,
                          ).withValues(alpha: 0.14),
                          side: BorderSide(
                            color: _statusColor(
                              isActive ? 'active' : status,
                            ).withValues(alpha: 0.4),
                          ),
                        ),
                        Chip(
                          label: Text(status.toUpperCase()),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: _statusColor(
                            status,
                          ).withValues(alpha: 0.14),
                          side: BorderSide(
                            color: _statusColor(status).withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              title: Text(titleText),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!customerMode) ...[
                      Text(pausePeriodText),
                      if (customerPhone.isNotEmpty)
                        Text('Phone: $customerPhone'),
                      if (customerAddress.isNotEmpty)
                        Text('Address: $customerAddress'),
                      if (customerQuantity != null)
                        Text(
                          'Daily Quantity Impact: ${customerQuantity.toStringAsFixed(2)} L',
                        ),
                      if (isActive)
                        Text(
                          'Paused by Customer',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      const SizedBox(height: 6),
                    ],
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(
                          label: Text(status.toUpperCase()),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: _statusColor(
                            status,
                          ).withValues(alpha: 0.14),
                          side: BorderSide(
                            color: _statusColor(status).withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              trailing: showCustomerResume
                  ? OutlinedButton(
                      onPressed: pauseId.trim().isEmpty
                          ? null
                          : () => _resumePause(pauseId),
                      child: const Text('Resume'),
                    )
                  : null,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBilling() {
    final state = _uiCubit.state;
    if (widget.featureKey == 'seller_billing') {
      return _buildSellerBilling(state.summary);
    }

    final month = state.summary['month']?.toString();
    final summaryMap = state.summary['summary'] is Map<String, dynamic>
        ? state.summary['summary'] as Map<String, dynamic>
        : state.summary;
    final activeMonthKey = statefulMonthFromSummary(<String, dynamic>{
      ...summaryMap,
      'month': ?month,
    });
    final pendingRupees = _pendingRupeesFromSummary(summaryMap);
    final isBillPaid =
        pendingRupees < 1 || _recentlyPaidCustomerMonthKey == activeMonthKey;

    final customerRows =
        (state.summary['customers'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .toList(growable: false) ??
        const <Map<String, dynamic>>[];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _sectionTitle(
          'Monthly Summary',
          subtitle: month == null || month.trim().isEmpty
              ? 'Current cycle overview'
              : 'Month: $month',
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: summaryMap.entries
                  .map((entry) => _metricChip(entry.key, entry.value))
                  .toList(growable: false),
            ),
          ),
        ),
        if (widget.featureKey == 'customer_billing') ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pay Pending Dues',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isBillPaid
                        ? 'Your bill for this month is settled.'
                        : 'Pending amount: ₹${pendingRupees.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: state.processingPayment || isBillPaid
                          ? null
                          : () => _payPendingDues(summaryMap),
                      icon: Icon(
                        isBillPaid
                            ? Icons.verified_rounded
                            : Icons.payments_rounded,
                      ),
                      label: Text(
                        isBillPaid
                            ? 'Bill Paid'
                            : state.processingPayment
                            ? 'Opening Razorpay...'
                            : 'Pay Now',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (customerRows.isNotEmpty) ...[
          const SizedBox(height: 12),
          _sectionTitle('Customer Breakdown'),
          const SizedBox(height: 8),
          ...customerRows.map(
            (item) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['customerName']?.toString() ??
                          item['title']?.toString() ??
                          'Customer',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: item.entries
                          .where(
                            (entry) =>
                                entry.key != 'customerName' &&
                                entry.key != 'title' &&
                                entry.key != 'id',
                          )
                          .map((entry) => _metricChip(entry.key, entry.value))
                          .toList(growable: false),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _normalizeNameKey(String? value) {
    return (value ?? '').trim().toLowerCase();
  }

  String _monthKey(DateTime value) {
    final mm = value.month.toString().padLeft(2, '0');
    return '${value.year}-$mm';
  }

  String _monthLabel(DateTime value) {
    const monthNames = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final monthName = monthNames[value.month - 1];
    return '$monthName ${value.year}';
  }

  Future<void> _selectSellerBillingMonth(DateTime month) async {
    final normalizedMonth = DateTime(month.year, month.month);
    if (_monthKey(normalizedMonth) == _monthKey(_sellerBillingSelectedMonth)) {
      return;
    }

    if (mounted) {
      setState(() {
        _sellerBillingSelectedMonth = normalizedMonth;
      });
    }

    await _load();
  }

  int _dateKeySortValue(String? rawDateKey) {
    final digitsOnly = (rawDateKey ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digitsOnly) ?? 0;
  }

  String _milkEntryStatus(Map<String, dynamic> entry) {
    if (entry['adjustedManually'] == true) {
      return 'Adjusted';
    }
    if (entry['delivered'] == true) {
      return 'Delivered';
    }
    return 'Pending';
  }

  Color _milkEntryStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'adjusted':
        return Colors.deepPurple;
      case 'delivered':
        return AppColors.success;
      case 'pending':
      default:
        return AppColors.warning;
    }
  }

  Map<String, dynamic>? _findOrganizationCustomer({
    required Map<String, dynamic> customerRow,
    required List<Map<String, dynamic>> organizationCustomers,
  }) {
    final rowNameKey = _normalizeNameKey(
      customerRow['customerName']?.toString(),
    );
    if (rowNameKey.isEmpty) {
      return null;
    }

    for (final item in organizationCustomers) {
      if (_normalizeNameKey(item['name']?.toString()) == rowNameKey) {
        return item;
      }
    }

    return null;
  }

  void _showSellerCustomerDetails({
    required Map<String, dynamic> customer,
    required Map<String, dynamic>? organizationInfo,
  }) {
    final milkCard = (customer['milkCard'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    final sortedMilkCard = <Map<String, dynamic>>[...milkCard]
      ..sort(
        (a, b) => _dateKeySortValue(
          a['dateKey']?.toString(),
        ).compareTo(_dateKeySortValue(b['dateKey']?.toString())),
      );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        String statusFilter = 'All';

        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return StatefulBuilder(
                builder: (context, setSheetState) {
                  final visibleMilkCard = sortedMilkCard
                      .where((entry) {
                        if (statusFilter == 'All') {
                          return true;
                        }
                        return _milkEntryStatus(entry) == statusFilter;
                      })
                      .toList(growable: false);

                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(12),
                    children: [
                      Text(
                        customer['customerName']?.toString() ?? 'Customer',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _metricChip(
                            'Total Quantity',
                            customer['totalQuantityLitres'],
                          ),
                          _metricChip('Total Payment', customer['totalRupees']),
                          _metricChip(
                            'Delivered Days',
                            customer['deliveredDays'],
                          ),
                          _metricChip('Pending', customer['pendingRupees']),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _sectionTitle(
                        'Organization Details',
                        subtitle:
                            'Relevant info for this seller-customer organization',
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Phone: ${organizationInfo?['phone'] ?? '-'}',
                              ),
                              Text(
                                'Email: ${organizationInfo?['email'] ?? '-'}',
                              ),
                              Text(
                                'Daily Default Qty: ${organizationInfo?['defaultQuantityLitres'] ?? '-'} L',
                              ),
                              Text(
                                'Address: ${organizationInfo?['displayAddress'] ?? '-'}',
                              ),
                              Text(
                                'Linked At: ${_prettyDate(organizationInfo?['linkedAt']?.toString())}',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _sectionTitle(
                        'Milk Card',
                        subtitle: 'Calendar-style table for this month',
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: DropdownButtonFormField<String>(
                            initialValue: statusFilter,
                            decoration: const InputDecoration(
                              labelText: 'Status filter',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'All',
                                child: Text('All'),
                              ),
                              DropdownMenuItem(
                                value: 'Delivered',
                                child: Text('Delivered'),
                              ),
                              DropdownMenuItem(
                                value: 'Pending',
                                child: Text('Pending'),
                              ),
                              DropdownMenuItem(
                                value: 'Adjusted',
                                child: Text('Adjusted'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setSheetState(() {
                                statusFilter = value;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (sortedMilkCard.isEmpty)
                        _emptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No milk card entries',
                          description:
                              'No delivery records found for this customer in this month.',
                        )
                      else if (visibleMilkCard.isEmpty)
                        _emptyState(
                          icon: Icons.filter_alt_off_outlined,
                          title: 'No entries for selected status',
                          description: 'Try another status filter.',
                        )
                      else
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_month_outlined),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Daily Milk Ledger',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columns: const [
                                      DataColumn(label: Text('Date')),
                                      DataColumn(label: Text('Qty (L)')),
                                      DataColumn(label: Text('Amount (₹)')),
                                      DataColumn(label: Text('Status')),
                                    ],
                                    rows: visibleMilkCard
                                        .map((entry) {
                                          final quantityLitres =
                                              (entry['quantityLitres'] as num?)
                                                  ?.toDouble() ??
                                              0;
                                          final totalRupees =
                                              (entry['totalRupees'] as num?)
                                                  ?.toDouble() ??
                                              0;
                                          final status = _milkEntryStatus(
                                            entry,
                                          );
                                          final statusColor =
                                              _milkEntryStatusColor(status);

                                          return DataRow(
                                            cells: [
                                              DataCell(
                                                Text(
                                                  entry['dateKey']
                                                          ?.toString() ??
                                                      '-',
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  quantityLitres
                                                      .toStringAsFixed(2),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  totalRupees.toStringAsFixed(
                                                    2,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Chip(
                                                  label: Text(status),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  backgroundColor: statusColor
                                                      .withValues(alpha: 0.14),
                                                  side: BorderSide(
                                                    color: statusColor
                                                        .withValues(alpha: 0.4),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        })
                                        .toList(growable: false),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSellerBilling(Map<String, dynamic> payload) {
    final month = payload['month']?.toString();
    final selectedMonthKey = _monthKey(_sellerBillingSelectedMonth);
    final currentMonth = DateTime.now();
    final currentMonthKey = _monthKey(currentMonth);
    final previousMonth = DateTime(currentMonth.year, currentMonth.month - 1);
    final previousMonthKey = _monthKey(previousMonth);
    final summaryMap = payload['summary'] is Map<String, dynamic>
        ? payload['summary'] as Map<String, dynamic>
        : payload;
    final customerRows = (payload['customers'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    final normalizedQuery = _normalizeNameKey(_sellerCustomerSearchQuery);
    final filteredCustomerRows = customerRows
        .where((customer) {
          if (normalizedQuery.isEmpty) {
            return true;
          }
          final name = customer['customerName']?.toString();
          return _normalizeNameKey(name).contains(normalizedQuery);
        })
        .toList(growable: false);
    final organizationCustomers =
        (payload['organizationCustomers'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _sectionTitle(
          'Seller Billing',
          subtitle:
              'Month: ${month?.trim().isNotEmpty == true ? month : selectedMonthKey}',
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text('Current (${_monthLabel(currentMonth)})'),
                  selected: selectedMonthKey == currentMonthKey,
                  onSelected: (_) {
                    _selectSellerBillingMonth(currentMonth);
                  },
                ),
                ChoiceChip(
                  label: Text('Previous (${_monthLabel(previousMonth)})'),
                  selected: selectedMonthKey == previousMonthKey,
                  onSelected: (_) {
                    _selectSellerBillingMonth(previousMonth);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metricChip(
                  'Total Quantity',
                  summaryMap['totalQuantityLitres'],
                ),
                _metricChip('Total Payment', summaryMap['totalRupees']),
                _metricChip('Pending', summaryMap['pendingRupees']),
                _metricChip('Delivery Entries', summaryMap['deliveredLogs']),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _sectionTitle('Customers'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _sellerCustomerSearchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Search customer name',
                hintText: 'Type to filter list',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: normalizedQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _sellerCustomerSearchController.clear();
                        },
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          normalizedQuery.isEmpty
              ? 'Showing ${customerRows.length} customers'
              : 'Showing ${filteredCustomerRows.length} of ${customerRows.length} customers',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (customerRows.isEmpty)
          _emptyState(
            icon: Icons.groups_2_outlined,
            title: 'No customer billing data',
            description: 'Monthly customer billing records will appear here.',
          )
        else if (filteredCustomerRows.isEmpty)
          _emptyState(
            icon: Icons.search_off_outlined,
            title: 'No customer found',
            description: 'Try another name or clear the search filter.',
          )
        else
          ...filteredCustomerRows.map((customer) {
            final name = customer['customerName']?.toString().trim();
            final totalRupees =
                (customer['totalRupees'] as num?)?.toDouble() ?? 0;
            final totalQuantityLitres =
                (customer['totalQuantityLitres'] as num?)?.toDouble() ?? 0;
            final orgInfo = _findOrganizationCustomer(
              customerRow: customer,
              organizationCustomers: organizationCustomers,
            );

            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                title: Text(
                  name == null || name.isEmpty ? 'Customer' : name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  'Payment: ₹${totalRupees.toStringAsFixed(2)} • Quantity: ${totalQuantityLitres.toStringAsFixed(2)} L',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  _showSellerCustomerDetails(
                    customer: customer,
                    organizationInfo: orgInfo,
                  );
                },
              ),
            );
          }),
      ],
    );
  }

  Widget _buildCustomerIssues() {
    final state = _uiCubit.state;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _sectionTitle(
          'Report an Issue',
          subtitle:
              'Share what happened so your seller can resolve it quickly.',
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: state.issueType,
                  decoration: const InputDecoration(
                    labelText: 'Issue type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'not_delivered',
                      child: Text('Not Delivered'),
                    ),
                    DropdownMenuItem(
                      value: 'late_delivery',
                      child: Text('Late Delivery'),
                    ),
                    DropdownMenuItem(
                      value: 'wrong_quantity',
                      child: Text('Wrong Quantity'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _uiCubit.setIssueType(value);
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _issueDescriptionController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _reportIssue,
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Submit issue'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _sectionTitle('Recent Reports'),
        const SizedBox(height: 8),
        if (state.items.isEmpty)
          _emptyState(
            icon: Icons.mark_chat_unread_outlined,
            title: 'No issues reported yet',
            description: 'Your issue history will appear here.',
          ),
        ...state.items.map((item) {
          final status = item['status']?.toString() ?? '-';
          final issueType = item['issueType']?.toString() ?? '-';
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          issueType.replaceAll('_', ' '),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Chip(
                        label: Text(status.toUpperCase()),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: _statusColor(
                          status,
                        ).withValues(alpha: 0.14),
                        side: BorderSide(
                          color: _statusColor(status).withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(item['description']?.toString() ?? '-'),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNotifications() {
    final state = _uiCubit.state;
    final unreadCount = state.summary['unreadCount'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _sectionTitle(
          'Notification Feed',
          subtitle: 'Recent platform and delivery updates.',
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_outlined),
                const SizedBox(width: 10),
                Expanded(child: Text('Unread notifications: $unreadCount')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (state.items.isEmpty)
          _emptyState(
            icon: Icons.notifications_off_outlined,
            title: 'No notifications yet',
            description: 'You are up to date.',
          ),
        ...state.items.map((item) {
          final isRead = item['isRead'] == true;
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              leading: Icon(
                isRead
                    ? Icons.mark_email_read_outlined
                    : Icons.mark_email_unread_outlined,
              ),
              title: Text(item['title']?.toString() ?? 'Notification'),
              subtitle: Text(
                '${item['message'] ?? ''}\n${_prettyDate(item['createdAt']?.toString())}',
              ),
              isThreeLine: true,
              trailing: Chip(
                label: Text(isRead ? 'READ' : 'NEW'),
                visualDensity: VisualDensity.compact,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCustomerJoinRequests() {
    final state = _uiCubit.state;
    final hasActiveOrganization =
        state.summary['hasActiveOrganization'] == true;
    final organization = state.summary['organization'] as Map<String, dynamic>?;
    final nearbySellers =
        (state.summary['nearbySellers'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
    final hasSavedLocation = state.summary['hasSavedLocation'] == true;
    final nearbyRadiusKm =
        (state.summary['nearbyRadiusKm'] as num?)?.toDouble() ?? 5;
    final pendingSellerIds = state.items
        .where(
          (item) =>
              (item['status']?.toString() ?? '').toLowerCase() == 'pending',
        )
        .map((item) => item['sellerUserId']?.toString() ?? '')
        .where((item) => item.trim().isNotEmpty)
        .toSet();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (hasActiveOrganization) ...[
          _sectionTitle(
            'My Organization',
            subtitle:
                'You can only be linked to one organization at a time. Clear pending dues to leave.',
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    organization?['shopName']?.toString().trim().isNotEmpty ==
                            true
                        ? organization!['shopName'].toString()
                        : (organization?['sellerName']?.toString() ??
                              'Seller Organization'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text('Seller: ${organization?['sellerName'] ?? '-'}'),
                  Text('Phone: ${organization?['phone'] ?? '-'}'),
                  Text('Email: ${organization?['email'] ?? '-'}'),
                  Text('Address: ${organization?['displayAddress'] ?? '-'}'),
                  Text(
                    'Linked At: ${_prettyDate(organization?['linkedAt']?.toString())}',
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _leavingOrganization
                          ? null
                          : _confirmAndLeaveCurrentOrganization,
                      icon: const Icon(Icons.exit_to_app_rounded),
                      label: Text(
                        _leavingOrganization
                            ? 'Checking dues...'
                            : 'Leave Organization',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _emptyState(
            icon: Icons.lock_outline_rounded,
            title: 'Join requests locked while linked',
            description:
                'Nearby sellers and new join requests are hidden until you leave your current organization.',
          ),
          const SizedBox(height: 12),
        ] else ...[
          _sectionTitle(
            'Nearby Sellers',
            subtitle: hasSavedLocation
                ? 'Based on your saved profile location within ${nearbyRadiusKm.toStringAsFixed(0)} km.'
                : 'Add your location in profile to discover nearby sellers.',
          ),
          const SizedBox(height: 8),
          if (!hasSavedLocation)
            _emptyState(
              icon: Icons.location_off_outlined,
              title: 'Saved location not found',
              description:
                  'Update your profile location to discover nearby sellers.',
            )
          else if (nearbySellers.isEmpty)
            _emptyState(
              icon: Icons.store_mall_directory_outlined,
              title: 'No nearby sellers found',
              description:
                  'No active sellers were found near your saved address right now.',
            )
          else
            ...nearbySellers.map((seller) {
              final sellerUserId = seller['sellerUserId']?.toString() ?? '';
              final shopName = (seller['shopName']?.toString() ?? '').trim();
              final sellerTitle = shopName.isNotEmpty
                  ? shopName
                  : (seller['name']?.toString() ?? 'Seller');
              final distanceKm =
                  (seller['distanceKm'] as num?)?.toDouble() ?? 0;
              final price =
                  (seller['basePricePerLitreRupees'] as num?)?.toDouble() ?? 60;
              final hasPendingRequest = pendingSellerIds.contains(sellerUserId);
              final isSendingRequest = _sendingJoinSellerUserIds.contains(
                sellerUserId,
              );

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sellerTitle,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Distance: ${distanceKm.toStringAsFixed(2)} km • Price: ₹${price.toStringAsFixed(2)}/L',
                      ),
                      if ((seller['displayAddress']?.toString() ?? '')
                          .trim()
                          .isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            seller['displayAddress']!.toString(),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: hasPendingRequest || isSendingRequest
                              ? null
                              : () => _sendJoinRequest(sellerUserId),
                          icon: const Icon(Icons.group_add_rounded),
                          label: Text(
                            hasPendingRequest
                                ? 'Requested'
                                : isSendingRequest
                                ? 'Sending...'
                                : 'Send Request',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 12),
        ],
        _sectionTitle(
          'My Join Requests',
          subtitle: 'Track request status across sellers.',
        ),
        const SizedBox(height: 8),
        if (state.items.isEmpty)
          _emptyState(
            icon: Icons.storefront_outlined,
            title: 'No join requests yet',
            description: 'Start by exploring nearby sellers on home.',
          ),
        ...state.items.map((item) {
          final status = item['status']?.toString() ?? '-';
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['title']?.toString() ?? 'Seller',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Chip(
                        label: Text(status.toUpperCase()),
                        backgroundColor: _statusColor(
                          status,
                        ).withValues(alpha: 0.14),
                        side: BorderSide(
                          color: _statusColor(status).withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Created: ${_prettyDate(item['createdAt']?.toString())}',
                  ),
                  if ((item['respondedAt']?.toString() ?? '').trim().isNotEmpty)
                    Text(
                      'Responded: ${_prettyDate(item['respondedAt']?.toString())}',
                    ),
                  if ((item['rejectionReason']?.toString() ?? '')
                      .trim()
                      .isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Reason: ${item['rejectionReason']}',
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildGenericList() {
    final state = _uiCubit.state;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (state.items.isEmpty)
          _emptyState(
            icon: Icons.inbox_outlined,
            title: 'Nothing to show',
            description: 'This section will update when data is available.',
          ),
        ...state.items.map(
          (item) => Card(
            child: ListTile(
              title: Text(
                item['title']?.toString() ??
                    item['customerName']?.toString() ??
                    item['sellerName']?.toString() ??
                    item['id']?.toString() ??
                    'Item',
              ),
              subtitle: Text(
                item.entries
                    .where((entry) => entry.key != 'title' && entry.key != 'id')
                    .take(3)
                    .map((entry) => '${entry.key}: ${entry.value}')
                    .join('  |  '),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_uiCubit.state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (widget.featureKey) {
      case 'seller_requests':
        return _buildSellerRequests();

      case 'seller_issues':
        return _buildSellerIssues();

      case 'seller_routes':
        return _buildSellerRoutes();

      case 'seller_customers':
        return _buildSellerCustomers();

      case 'seller_milk_settings':
        return _buildSellerMilkSettings();

      case 'seller_pauses':
        return _buildPauses(customerMode: false);

      case 'customer_pauses':
        return _buildPauses(customerMode: true);

      case 'seller_billing':
      case 'customer_billing':
        return _buildBilling();

      case 'customer_issues':
        return _buildCustomerIssues();

      case 'customer_join':
        return _buildCustomerJoinRequests();

      case 'notifications':
        return _buildNotifications();

      default:
        return _buildGenericList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _uiCubit,
      child: BlocBuilder<HomeFeatureUiCubit, HomeFeatureUiState>(
        builder: (context, _) {
          return Scaffold(
            appBar: AppBar(title: Text(_title)),
            body: _buildBody(),
          );
        },
      ),
    );
  }
}
