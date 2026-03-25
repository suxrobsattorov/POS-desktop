class ProductModel {
  final int id;
  final String name;
  final String? barcode;
  final int? categoryId;
  final String? categoryName;
  final String unit;
  final double buyPrice;
  final double sellPrice;
  final double stockQuantity;
  final double minStock;
  final String? imageUrl;
  final String? description;
  final bool isActive;
  final bool isLowStock;

  const ProductModel({
    required this.id,
    required this.name,
    this.barcode,
    this.categoryId,
    this.categoryName,
    this.unit = 'piece',
    this.buyPrice = 0,
    required this.sellPrice,
    this.stockQuantity = 0,
    this.minStock = 0,
    this.imageUrl,
    this.description,
    this.isActive = true,
    this.isLowStock = false,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as int,
      name: json['name'] as String,
      barcode: json['barcode'] as String?,
      categoryId: json['categoryId'] as int?,
      categoryName: json['categoryName'] as String?,
      unit: json['unit'] as String? ?? 'piece',
      buyPrice: (json['buyPrice'] as num?)?.toDouble() ?? 0,
      sellPrice: (json['sellPrice'] as num?)?.toDouble() ?? 0,
      stockQuantity: (json['stockQuantity'] as num?)?.toDouble() ?? 0,
      minStock: (json['minStock'] as num?)?.toDouble() ?? 0,
      imageUrl: json['imageUrl'] as String?,
      description: json['description'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      isLowStock: json['isLowStock'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'barcode': barcode,
    'categoryId': categoryId,
    'categoryName': categoryName,
    'unit': unit,
    'buyPrice': buyPrice,
    'sellPrice': sellPrice,
    'stockQuantity': stockQuantity,
    'minStock': minStock,
    'imageUrl': imageUrl,
    'description': description,
    'isActive': isActive,
    'isLowStock': isLowStock,
  };
}
