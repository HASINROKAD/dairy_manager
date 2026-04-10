class LedgerEntry {
  LedgerEntry({
    required this.id,
    required this.dateKey,
    required this.quantityLitres,
    required this.totalPricePaise,
    required this.delivered,
  });

  final String id;
  final String dateKey;
  final double quantityLitres;
  final int totalPricePaise;
  final bool delivered;

  double get totalPriceRupees => totalPricePaise / 100;

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    return LedgerEntry(
      id: json['_id']?.toString() ?? '',
      dateKey: json['dateKey']?.toString() ?? '',
      quantityLitres: (json['quantityLitres'] as num?)?.toDouble() ?? 0,
      totalPricePaise: (json['totalPricePaise'] as num?)?.toInt() ?? 0,
      delivered: (json['delivered'] as bool?) ?? false,
    );
  }
}
