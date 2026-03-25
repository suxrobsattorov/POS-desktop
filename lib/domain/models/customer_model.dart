class CustomerModel {
  final int id;
  final String name;
  final String? phone;
  final double discountPercent;
  final double bonusPoints;
  final double totalPurchases;

  CustomerModel({
    required this.id,
    required this.name,
    this.phone,
    required this.discountPercent,
    required this.bonusPoints,
    required this.totalPurchases,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) => CustomerModel(
        id: json['id'],
        name: json['name'],
        phone: json['phone'],
        discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0,
        bonusPoints: (json['bonusPoints'] as num?)?.toDouble() ?? 0,
        totalPurchases: (json['totalPurchases'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'discountPercent': discountPercent,
        'bonusPoints': bonusPoints,
        'totalPurchases': totalPurchases,
      };
}
