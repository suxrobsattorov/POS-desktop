import 'cart_item_model.dart';
import 'customer_model.dart';

class CartData {
  final String id;
  final String label;
  final List<CartItemModel> items;
  final CustomerModel? customer;
  final double discountPercent;

  const CartData({
    required this.id,
    required this.label,
    this.items = const [],
    this.customer,
    this.discountPercent = 0,
  });

  double get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);
  double get discountAmount => subtotal * discountPercent / 100;
  double get netAmount => subtotal - discountAmount;
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity.toInt());
  bool get hasItems => items.isNotEmpty;

  CartData copyWith({
    String? id,
    String? label,
    List<CartItemModel>? items,
    CustomerModel? customer,
    bool clearCustomer = false,
    double? discountPercent,
  }) {
    return CartData(
      id: id ?? this.id,
      label: label ?? this.label,
      items: items ?? this.items,
      customer: clearCustomer ? null : (customer ?? this.customer),
      discountPercent: discountPercent ?? this.discountPercent,
    );
  }
}
