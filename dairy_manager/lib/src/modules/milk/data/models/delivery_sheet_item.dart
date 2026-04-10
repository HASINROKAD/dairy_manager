class DeliverySheetItem {
  DeliverySheetItem({
    required this.customerId,
    required this.customerName,
    required this.defaultQuantityLitres,
    required this.quantityLitres,
    required this.delivered,
    required this.totalPricePaise,
    this.logId,
  });

  final String customerId;
  final String customerName;
  final double defaultQuantityLitres;
  final double quantityLitres;
  final bool delivered;
  final int totalPricePaise;
  final String? logId;

  double get totalPriceRupees => totalPricePaise / 100;

  factory DeliverySheetItem.fromJson(Map<String, dynamic> json) {
    return DeliverySheetItem(
      customerId: json['customerId']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? 'Customer',
      defaultQuantityLitres:
          (json['defaultQuantityLitres'] as num?)?.toDouble() ?? 1,
      quantityLitres: (json['quantityLitres'] as num?)?.toDouble() ?? 1,
      delivered: (json['delivered'] as bool?) ?? false,
      totalPricePaise: (json['totalPricePaise'] as num?)?.toInt() ?? 0,
      logId: json['logId']?.toString(),
    );
  }

  DeliverySheetItem copyWith({
    double? quantityLitres,
    bool? delivered,
    int? totalPricePaise,
    String? logId,
  }) {
    return DeliverySheetItem(
      customerId: customerId,
      customerName: customerName,
      defaultQuantityLitres: defaultQuantityLitres,
      quantityLitres: quantityLitres ?? this.quantityLitres,
      delivered: delivered ?? this.delivered,
      totalPricePaise: totalPricePaise ?? this.totalPricePaise,
      logId: logId ?? this.logId,
    );
  }
}
