import '../../../domain/models/product_model.dart';
import '../../../domain/models/cart_item_model.dart';
import '../../../domain/models/category_model.dart';
import '../../../domain/models/payment_method_model.dart';
import '../../../domain/models/customer_model.dart';
import '../../../domain/models/cart_data_model.dart';

export '../../../domain/models/cart_data_model.dart';

enum PosStatus { initial, loading, ready, processingPayment, success, error }

class PosState {
  final PosStatus status;
  final List<ProductModel> allProducts;
  final List<ProductModel> filteredProducts;
  final List<CategoryModel> categories;
  final List<PaymentMethodModel> paymentMethods;
  final int? selectedCategoryId;
  final String searchQuery;
  final String? errorMessage;
  final String? successMessage;
  final int pendingSalesCount;
  final bool isOnline;
  final bool isSyncing;

  // Multi-cart
  final List<CartData> carts;
  final int activeCartIndex;

  const PosState({
    this.status = PosStatus.initial,
    this.allProducts = const [],
    this.filteredProducts = const [],
    this.categories = const [],
    this.paymentMethods = const [],
    this.selectedCategoryId,
    this.searchQuery = '',
    this.errorMessage,
    this.successMessage,
    this.pendingSalesCount = 0,
    this.isOnline = true,
    this.isSyncing = false,
    this.carts = const [],
    this.activeCartIndex = 0,
  });

  CartData get activeCart =>
      carts.isNotEmpty ? carts[activeCartIndex] : CartData(id: 'default', label: 'Savat 1');
  List<CartItemModel> get cartItems => activeCart.items;
  CustomerModel? get selectedCustomer => activeCart.customer;
  double get discountPercent => activeCart.discountPercent;
  double get subtotal => activeCart.subtotal;
  double get discountAmount => activeCart.discountAmount;
  double get netAmount => activeCart.netAmount;
  int get cartItemCount => activeCart.itemCount;
  bool get hasItems => activeCart.hasItems;

  PosState copyWith({
    PosStatus? status,
    List<ProductModel>? allProducts,
    List<ProductModel>? filteredProducts,
    List<CategoryModel>? categories,
    List<PaymentMethodModel>? paymentMethods,
    int? selectedCategoryId,
    bool clearCategory = false,
    String? searchQuery,
    String? errorMessage,
    String? successMessage,
    int? pendingSalesCount,
    bool? isOnline,
    bool? isSyncing,
    List<CartData>? carts,
    int? activeCartIndex,
  }) {
    return PosState(
      status: status ?? this.status,
      allProducts: allProducts ?? this.allProducts,
      filteredProducts: filteredProducts ?? this.filteredProducts,
      categories: categories ?? this.categories,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      selectedCategoryId: clearCategory ? null : (selectedCategoryId ?? this.selectedCategoryId),
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
      successMessage: successMessage,
      pendingSalesCount: pendingSalesCount ?? this.pendingSalesCount,
      isOnline: isOnline ?? this.isOnline,
      isSyncing: isSyncing ?? this.isSyncing,
      carts: carts ?? this.carts,
      activeCartIndex: activeCartIndex ?? this.activeCartIndex,
    );
  }

  // Helper: update active cart and return new state
  PosState withUpdatedActiveCart(CartData updatedCart) {
    final newCarts = List<CartData>.from(carts);
    newCarts[activeCartIndex] = updatedCart;
    return copyWith(carts: newCarts);
  }
}
