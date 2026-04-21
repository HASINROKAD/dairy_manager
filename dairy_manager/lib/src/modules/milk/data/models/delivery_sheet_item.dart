class DeliverySheetItem {
  DeliverySheetItem({
    required this.customerId,
    required this.customerName,
    required this.dateKey,
    required this.defaultQuantityLitres,
    required this.quantityLitres,
    required this.basePricePerLitreRupees,
    required this.delivered,
    required this.totalPriceRupees,
    this.customerDisplayAddress,
    this.routeDistanceKm,
    this.routeDistanceMeters,
    this.routeDistanceLabel,
    this.routeDistanceReason,
    this.routeBucket,
    this.mobileNumber,
    this.email,
    this.organizationJoinedAt,
    this.logId,
  });

  final String customerId;
  final String customerName;
  final String dateKey;
  final double defaultQuantityLitres;
  final double quantityLitres;
  final double basePricePerLitreRupees;
  final bool delivered;
  final double totalPriceRupees;
  final String? customerDisplayAddress;
  final double? routeDistanceKm;
  final int? routeDistanceMeters;
  final String? routeDistanceLabel;
  final String? routeDistanceReason;
  final String? routeBucket;
  final String? mobileNumber;
  final String? email;
  final String? organizationJoinedAt;
  final String? logId;

  factory DeliverySheetItem.fromJson(Map<String, dynamic> json) {
    return DeliverySheetItem(
      customerId: json['customerId']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? 'Customer',
      dateKey: json['dateKey']?.toString() ?? '',
      defaultQuantityLitres:
          (json['defaultQuantityLitres'] as num?)?.toDouble() ?? 1,
      quantityLitres: (json['quantityLitres'] as num?)?.toDouble() ?? 1,
      basePricePerLitreRupees:
          (json['basePricePerLitreRupees'] as num?)?.toDouble() ?? 60,
      delivered: (json['delivered'] as bool?) ?? false,
      totalPriceRupees: (json['totalPriceRupees'] as num?)?.toDouble() ?? 0,
      customerDisplayAddress: json['customerDisplayAddress']?.toString(),
      routeDistanceKm: (json['routeDistanceKm'] as num?)?.toDouble(),
      routeDistanceMeters: (json['routeDistanceMeters'] as num?)?.toInt(),
      routeDistanceLabel: json['routeDistanceLabel']?.toString(),
      routeDistanceReason: json['routeDistanceReason']?.toString(),
      routeBucket: json['routeBucket']?.toString(),
      mobileNumber: json['mobileNumber']?.toString(),
      email: json['email']?.toString(),
      organizationJoinedAt: json['organizationJoinedAt']?.toString(),
      logId: json['logId']?.toString(),
    );
  }

  DeliverySheetItem copyWith({
    double? quantityLitres,
    double? basePricePerLitreRupees,
    bool? delivered,
    double? totalPriceRupees,
    String? dateKey,
    String? customerDisplayAddress,
    double? routeDistanceKm,
    int? routeDistanceMeters,
    String? routeDistanceLabel,
    String? routeDistanceReason,
    String? routeBucket,
    String? mobileNumber,
    String? email,
    String? organizationJoinedAt,
    String? logId,
  }) {
    return DeliverySheetItem(
      customerId: customerId,
      customerName: customerName,
      dateKey: dateKey ?? this.dateKey,
      defaultQuantityLitres: defaultQuantityLitres,
      quantityLitres: quantityLitres ?? this.quantityLitres,
      basePricePerLitreRupees:
          basePricePerLitreRupees ?? this.basePricePerLitreRupees,
      delivered: delivered ?? this.delivered,
      totalPriceRupees: totalPriceRupees ?? this.totalPriceRupees,
      customerDisplayAddress:
          customerDisplayAddress ?? this.customerDisplayAddress,
      routeDistanceKm: routeDistanceKm ?? this.routeDistanceKm,
      routeDistanceMeters: routeDistanceMeters ?? this.routeDistanceMeters,
      routeDistanceLabel: routeDistanceLabel ?? this.routeDistanceLabel,
      routeDistanceReason: routeDistanceReason ?? this.routeDistanceReason,
      routeBucket: routeBucket ?? this.routeBucket,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      email: email ?? this.email,
      organizationJoinedAt: organizationJoinedAt ?? this.organizationJoinedAt,
      logId: logId ?? this.logId,
    );
  }
}
