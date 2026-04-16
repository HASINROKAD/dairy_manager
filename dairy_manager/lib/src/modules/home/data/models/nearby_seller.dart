class NearbySeller {
  NearbySeller({
    required this.sellerUserId,
    required this.name,
    required this.shopName,
    required this.displayAddress,
    required this.distanceKm,
    required this.basePricePerLitreRupees,
    required this.isServiceAvailable,
  });

  final String sellerUserId;
  final String name;
  final String shopName;
  final String displayAddress;
  final double distanceKm;
  final double basePricePerLitreRupees;
  final bool isServiceAvailable;

  double get basePricePerLitre => basePricePerLitreRupees;

  String get displayTitle => shopName.trim().isEmpty ? name : shopName;

  factory NearbySeller.fromJson(Map<String, dynamic> json) {
    return NearbySeller(
      sellerUserId: json['sellerUserId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Seller',
      shopName: json['shopName']?.toString() ?? '',
      displayAddress: json['displayAddress']?.toString() ?? '',
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      basePricePerLitreRupees:
          (json['basePricePerLitreRupees'] as num?)?.toDouble() ?? 60,
      isServiceAvailable: (json['isServiceAvailable'] as bool?) ?? true,
    );
  }
}
