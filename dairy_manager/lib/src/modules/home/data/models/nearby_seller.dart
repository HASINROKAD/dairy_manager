class NearbySeller {
  NearbySeller({
    required this.sellerUserId,
    required this.name,
    required this.displayAddress,
    required this.distanceKm,
  });

  final String sellerUserId;
  final String name;
  final String displayAddress;
  final double distanceKm;

  factory NearbySeller.fromJson(Map<String, dynamic> json) {
    return NearbySeller(
      sellerUserId: json['sellerUserId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Seller',
      displayAddress: json['displayAddress']?.toString() ?? '',
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
    );
  }
}
