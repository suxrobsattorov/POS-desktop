class ShiftModel {
  final int id;
  final String status; // OPEN, CLOSED
  final DateTime openedAt;
  final DateTime? closedAt;
  final double openingBalance;
  final double? closingBalance;
  final int totalSales;
  final double totalRevenue;
  final String? notes;

  const ShiftModel({
    required this.id,
    required this.status,
    required this.openedAt,
    this.closedAt,
    required this.openingBalance,
    this.closingBalance,
    required this.totalSales,
    required this.totalRevenue,
    this.notes,
  });

  bool get isOpen => status == 'OPEN';

  Duration get duration {
    final end = closedAt ?? DateTime.now();
    return end.difference(openedAt);
  }

  factory ShiftModel.fromJson(Map<String, dynamic> j) => ShiftModel(
        id: (j['id'] as num).toInt(),
        status: j['status'] as String? ?? 'OPEN',
        openedAt: DateTime.parse(j['openedAt'] as String),
        closedAt:
            j['closedAt'] != null ? DateTime.parse(j['closedAt'] as String) : null,
        openingBalance: ((j['openAmount'] ?? 0) as num).toDouble(),
        closingBalance: j['closeAmount'] != null
            ? (j['closeAmount'] as num).toDouble()
            : null,
        totalSales: (j['salesCount'] ?? 0) as int,
        totalRevenue: ((j['totalCash'] ?? j['totalSales'] ?? 0) as num).toDouble(),
        notes: j['notes'] as String?,
      );
}
