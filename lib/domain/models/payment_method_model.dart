class PaymentMethodModel {
  final int id;
  final String name;
  final String type;
  final String? icon;
  final bool isActive;
  final int sortOrder;

  const PaymentMethodModel({
    required this.id,
    required this.name,
    required this.type,
    this.icon,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodModel(
      id: json['id'] as int,
      name: json['name'] as String,
      type: json['type'] as String,
      icon: json['icon'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'icon': icon,
    'isActive': isActive,
    'sortOrder': sortOrder,
  };
}
