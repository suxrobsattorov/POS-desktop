class SaleItemRequest {
  final int productId;
  final int quantity;
  final double unitPrice;
  final double discountPercent;

  SaleItemRequest({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    this.discountPercent = 0,
  });

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'discountPercent': discountPercent,
      };
}

class PaymentRequest {
  final int paymentMethodId;
  final double amount;

  PaymentRequest({required this.paymentMethodId, required this.amount});

  Map<String, dynamic> toJson() => {
        'paymentMethodId': paymentMethodId,
        'amount': amount,
      };
}

class CreateSaleRequest {
  final int? customerId;
  final List<SaleItemRequest> items;
  final List<PaymentRequest> payments;
  final String? notes;

  CreateSaleRequest({
    this.customerId,
    required this.items,
    required this.payments,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        if (customerId != null) 'customerId': customerId,
        'items': items.map((e) => e.toJson()).toList(),
        'payments': payments.map((e) => e.toJson()).toList(),
        if (notes != null) 'notes': notes,
      };
}

class SaleResponse {
  final int id;
  final String saleNumber;
  final String status;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double netAmount;
  final double paidAmount;
  final double changeAmount;
  final String cashierName;
  final DateTime createdAt;

  SaleResponse({
    required this.id,
    required this.saleNumber,
    required this.status,
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.netAmount,
    required this.paidAmount,
    required this.changeAmount,
    required this.cashierName,
    required this.createdAt,
  });

  factory SaleResponse.fromJson(Map<String, dynamic> json) => SaleResponse(
        id: json['id'],
        saleNumber: json['saleNumber'],
        status: json['status'],
        subtotal: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
        discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
        taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0.0,
        netAmount: (json['netAmount'] as num?)?.toDouble() ?? 0.0,
        paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0.0,
        changeAmount: (json['changeAmount'] as num?)?.toDouble() ?? 0.0,
        cashierName: json['cashierName'] ?? '',
        createdAt: DateTime.parse(json['createdAt']),
      );
}

/// Local receipt saved after every completed sale (online + offline)
class LocalSaleReceipt {
  final String saleNumber;
  final int? serverId;
  final double totalAmount;
  final double paidAmount;
  final double changeAmount;
  final String cashierName;
  final DateTime createdAt;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> payments;
  final String syncStatus;

  LocalSaleReceipt({
    required this.saleNumber,
    this.serverId,
    required this.totalAmount,
    required this.paidAmount,
    required this.changeAmount,
    required this.cashierName,
    required this.createdAt,
    required this.items,
    required this.payments,
    this.syncStatus = 'SYNCED',
  });

  Map<String, dynamic> toHive() => {
        'saleNumber': saleNumber,
        'serverId': serverId,
        'totalAmount': totalAmount,
        'paidAmount': paidAmount,
        'changeAmount': changeAmount,
        'cashierName': cashierName,
        'createdAt': createdAt.toIso8601String(),
        'items': items,
        'payments': payments,
        'syncStatus': syncStatus,
      };

  factory LocalSaleReceipt.fromHive(Map<dynamic, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);
    return LocalSaleReceipt(
      saleNumber: map['saleNumber'] ?? '',
      serverId: map['serverId'] as int?,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0,
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0,
      changeAmount: (map['changeAmount'] as num?)?.toDouble() ?? 0,
      cashierName: map['cashierName'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      items: (map['items'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      payments: (map['payments'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      syncStatus: map['syncStatus'] ?? 'SYNCED',
    );
  }

  Map<String, dynamic> toHistoryMap() => {
        'id': serverId,
        'saleNumber': saleNumber,
        'totalAmount': totalAmount,
        'paidAmount': paidAmount,
        'changeAmount': changeAmount,
        'cashierName': cashierName,
        'createdAt': createdAt.toIso8601String(),
        'items': items,
        'syncStatus': syncStatus,
      };
}

class PendingSale {
  final String localId;
  final Map<String, dynamic> saleData;
  final DateTime createdAt;
  bool synced;

  PendingSale({
    required this.localId,
    required this.saleData,
    required this.createdAt,
    this.synced = false,
  });

  Map<String, dynamic> toHive() => {
        'localId': localId,
        'saleData': saleData,
        'createdAt': createdAt.toIso8601String(),
        'synced': synced,
      };

  factory PendingSale.fromHive(Map<dynamic, dynamic> map) => PendingSale(
        localId: map['localId'],
        saleData: Map<String, dynamic>.from(map['saleData']),
        createdAt: DateTime.parse(map['createdAt']),
        synced: map['synced'] ?? false,
      );
}
