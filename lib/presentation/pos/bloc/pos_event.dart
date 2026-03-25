import '../../../domain/models/product_model.dart';
import '../../../domain/models/customer_model.dart';

abstract class PosEvent {}

class PosInitialized extends PosEvent {}

class ProductSearchChanged extends PosEvent {
  final String query;
  ProductSearchChanged(this.query);
}

class CategorySelected extends PosEvent {
  final int? categoryId;
  CategorySelected(this.categoryId);
}

class ProductAddedToCart extends PosEvent {
  final ProductModel product;
  ProductAddedToCart(this.product);
}

class CartItemQuantityChanged extends PosEvent {
  final int productId;
  final double quantity;
  CartItemQuantityChanged(this.productId, this.quantity);
}

class CartItemRemoved extends PosEvent {
  final int productId;
  CartItemRemoved(this.productId);
}

class CartCleared extends PosEvent {}

class CustomerSelected extends PosEvent {
  final CustomerModel? customer;
  CustomerSelected(this.customer);
}

class BarcodeScanned extends PosEvent {
  final String barcode;
  BarcodeScanned(this.barcode);
}

class SaleSubmitted extends PosEvent {
  final List<SalePaymentEntry> payments;
  SaleSubmitted(this.payments);
}

class SalePaymentEntry {
  final int paymentMethodId;
  final double amount;
  SalePaymentEntry(this.paymentMethodId, this.amount);
}

class DiscountApplied extends PosEvent {
  final double percent;
  DiscountApplied(this.percent);
}

// Multi-cart events
class CartAdded extends PosEvent {}

class CartSwitched extends PosEvent {
  final int index;
  CartSwitched(this.index);
}

class CartRemoved extends PosEvent {
  final int index;
  CartRemoved(this.index);
}

// Customer by phone
class CustomerSearchByPhone extends PosEvent {
  final String phone;
  CustomerSearchByPhone(this.phone);
}

// Sync events
class SyncStarted extends PosEvent {}

class SyncCompleted extends PosEvent {
  final int synced;
  final int failed;
  SyncCompleted({required this.synced, required this.failed});
}

// Discount per item
class ItemDiscountApplied extends PosEvent {
  final int productId;
  final double percent;
  ItemDiscountApplied(this.productId, this.percent);
}

// Price override per item (MANAGER+ only)
class ItemPriceChanged extends PosEvent {
  final int productId;
  final double newPrice;
  ItemPriceChanged(this.productId, this.newPrice);
}
