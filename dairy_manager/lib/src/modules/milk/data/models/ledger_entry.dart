class LedgerEntry {
  LedgerEntry({
    required this.id,
    required this.dateKey,
    required this.morningQuantityLitres,
    required this.eveningQuantityLitres,
    required this.deliverySlot,
    required this.quantityLitres,
    required this.totalPriceRupees,
    required this.basePricePerLitreRupees,
    required this.delivered,
  });

  final String id;
  final String dateKey;
  final double morningQuantityLitres;
  final double eveningQuantityLitres;
  final String deliverySlot;
  final double quantityLitres;
  final double totalPriceRupees;
  final double basePricePerLitreRupees;
  final bool delivered;

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    final rawMorning = (json['morningQuantityLitres'] as num?)?.toDouble();
    final rawEvening = (json['eveningQuantityLitres'] as num?)?.toDouble();
    final quantity = (json['quantityLitres'] as num?)?.toDouble() ?? 0;

    final hasSlotBreakdown =
        (rawMorning != null && rawMorning > 0) ||
        (rawEvening != null && rawEvening > 0);

    final double morning = hasSlotBreakdown ? (rawMorning ?? 0.0) : quantity;
    final double evening = hasSlotBreakdown ? (rawEvening ?? 0.0) : 0.0;

    return LedgerEntry(
      id: json['_id']?.toString() ?? '',
      dateKey: json['dateKey']?.toString() ?? '',
      morningQuantityLitres: morning,
      eveningQuantityLitres: evening,
      deliverySlot: json['deliverySlot']?.toString() ?? 'morning',
      quantityLitres: quantity,
      totalPriceRupees: (json['totalPriceRupees'] as num?)?.toDouble() ?? 0,
      basePricePerLitreRupees:
          (json['basePricePerLitreRupees'] as num?)?.toDouble() ?? 0,
      delivered: (json['delivered'] as bool?) ?? false,
    );
  }
}
