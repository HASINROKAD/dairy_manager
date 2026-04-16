class LedgerEntry {
  LedgerEntry({
    required this.id,
    required this.dateKey,
    required this.quantityLitres,
    required this.totalPriceRupees,
    required this.delivered,
  });

  final String id;
  final String dateKey;
  final double quantityLitres;
  final double totalPriceRupees;
  final bool delivered;

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    return LedgerEntry(
      id: json['_id']?.toString() ?? '',
      dateKey: json['dateKey']?.toString() ?? '',
      quantityLitres: (json['quantityLitres'] as num?)?.toDouble() ?? 0,
      totalPriceRupees: (json['totalPriceRupees'] as num?)?.toDouble() ?? 0,
      delivered: (json['delivered'] as bool?) ?? false,
    );
  }
}
