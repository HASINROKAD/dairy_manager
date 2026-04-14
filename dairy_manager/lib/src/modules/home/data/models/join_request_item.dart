class JoinRequestItem {
  JoinRequestItem({
    required this.id,
    required this.customerUserId,
    required this.customerName,
    required this.sellerUserId,
    required this.sellerName,
    required this.status,
    required this.createdAt,
    this.rejectionReason,
    this.respondedAt,
    this.requestedQuantityLitres,
    this.distanceKm,
    this.customerArea,
    this.customerDisplayAddress,
  });

  final String id;
  final String customerUserId;
  final String? customerName;
  final String sellerUserId;
  final String? sellerName;
  final String status;
  final DateTime createdAt;
  final String? rejectionReason;
  final DateTime? respondedAt;
  final double? requestedQuantityLitres;
  final double? distanceKm;
  final String? customerArea;
  final String? customerDisplayAddress;

  bool get isPending => status == 'pending';

  factory JoinRequestItem.fromJson(Map<String, dynamic> json) {
    return JoinRequestItem(
      id: json['id']?.toString() ?? '',
      customerUserId: json['customerUserId']?.toString() ?? '',
      customerName: json['customerName']?.toString(),
      sellerUserId: json['sellerUserId']?.toString() ?? '',
      sellerName: json['sellerName']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      rejectionReason: json['rejectionReason']?.toString(),
      respondedAt: DateTime.tryParse(json['respondedAt']?.toString() ?? ''),
      requestedQuantityLitres: (json['requestedQuantityLitres'] as num?)
          ?.toDouble(),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      customerArea: json['customerArea']?.toString(),
      customerDisplayAddress: json['customerDisplayAddress']?.toString(),
    );
  }
}
