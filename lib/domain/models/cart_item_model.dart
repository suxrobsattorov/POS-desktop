import 'product_model.dart';

class CartItemModel {
  final ProductModel product;
  double quantity;
  double discountPercent;
  /// MANAGER va undan yuqori rollar uchun narxni o'zgartirish imkoniyati
  double? customPrice;

  CartItemModel({
    required this.product,
    this.quantity = 1,
    this.discountPercent = 0,
    this.customPrice,
  });

  /// Asl narx (customPrice bo'lsa — customPrice, aks holda product.sellPrice)
  double get unitPrice => customPrice ?? product.sellPrice;

  double get discountedPrice => unitPrice * (1 - discountPercent / 100);

  double get subtotal => discountedPrice * quantity;

  CartItemModel copyWith({
    double? quantity,
    double? discountPercent,
    double? customPrice,
  }) {
    return CartItemModel(
      product: product,
      quantity: quantity ?? this.quantity,
      discountPercent: discountPercent ?? this.discountPercent,
      customPrice: customPrice ?? this.customPrice,
    );
  }
}
