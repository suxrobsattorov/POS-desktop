import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/network/network_info.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/remote/customer_repository.dart';
import '../../../data/remote/sale_repository.dart';
import '../../../data/remote/sync_service.dart';
import '../../../domain/models/cart_item_model.dart';
import '../../../domain/models/product_model.dart';
import '../../../domain/models/sale_model.dart' as sale_model;
import 'pos_event.dart';
import 'pos_state.dart';

class PosBloc extends Bloc<PosEvent, PosState> {
  final HiveService _hiveService;
  final SaleRepository _saleRepository;
  final SyncService _syncService;
  final CustomerRepository? _customerRepository;
  StreamSubscription<bool>? _connectivitySub;

  PosBloc({
    required HiveService hiveService,
    required SaleRepository saleRepository,
    required SyncService syncService,
    CustomerRepository? customerRepository,
  })  : _hiveService = hiveService,
        _saleRepository = saleRepository,
        _syncService = syncService,
        _customerRepository = customerRepository,
        super(const PosState()) {
    on<PosInitialized>(_onInitialized);
    on<ProductSearchChanged>(_onSearchChanged);
    on<CategorySelected>(_onCategorySelected);
    on<ProductAddedToCart>(_onProductAdded);
    on<CartItemQuantityChanged>(_onQuantityChanged);
    on<CartItemRemoved>(_onItemRemoved);
    on<CartCleared>(_onCartCleared);
    on<CustomerSelected>(_onCustomerSelected);
    on<BarcodeScanned>(_onBarcodeScanned);
    on<SaleSubmitted>(_onSaleSubmitted);
    on<DiscountApplied>(_onDiscountApplied);
    on<_ConnectivityChanged>(_onConnectivityChanged);
    on<CartAdded>(_onCartAdded);
    on<CartSwitched>(_onCartSwitched);
    on<CartRemoved>(_onCartRemoved);
    on<CustomerSearchByPhone>(_onCustomerSearchByPhone);
    on<SyncStarted>(_onSyncStarted);
    on<SyncCompleted>(_onSyncCompleted);
    on<ItemDiscountApplied>(_onItemDiscountApplied);
    on<ItemPriceChanged>(_onItemPriceChanged);
  }

  void _onInitialized(PosInitialized event, Emitter<PosState> emit) {
    final products = _hiveService.getProducts();
    final categories = _hiveService.getCategories();
    final paymentMethods = _hiveService.getPaymentMethods();
    final pending = _hiveService.pendingSalesCount;
    final initialCart = CartData(id: 'cart_1', label: 'Savat 1');
    emit(state.copyWith(
      status: PosStatus.ready,
      allProducts: products,
      filteredProducts: products,
      categories: categories,
      paymentMethods: paymentMethods,
      pendingSalesCount: pending,
      carts: [initialCart],
      activeCartIndex: 0,
    ));
    _connectivitySub = NetworkInfo.connectivityStream.listen((isOnline) {
      add(_ConnectivityChanged(isOnline));
    });
  }

  void _onConnectivityChanged(
      _ConnectivityChanged event, Emitter<PosState> emit) {
    final wasOffline = !state.isOnline;
    emit(state.copyWith(isOnline: event.isOnline));
    // Internet qayta tiklanganda pending sotuvlarni avtomatik yuborish
    if (wasOffline && event.isOnline && _hiveService.pendingSalesCount > 0) {
      add(SyncStarted());
    }
  }

  void _onSearchChanged(ProductSearchChanged event, Emitter<PosState> emit) {
    final q = event.query.toLowerCase();
    final filtered = state.allProducts.where((p) {
      final matchesQuery = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          (p.barcode?.toLowerCase().contains(q) ?? false);
      final matchesCategory = state.selectedCategoryId == null ||
          p.categoryId == state.selectedCategoryId;
      return matchesQuery && matchesCategory;
    }).toList();
    emit(state.copyWith(searchQuery: event.query, filteredProducts: filtered));
  }

  void _onCategorySelected(CategorySelected event, Emitter<PosState> emit) {
    final categoryId = event.categoryId;
    final filtered = state.allProducts.where((p) {
      final matchesQuery = state.searchQuery.isEmpty ||
          p.name.toLowerCase().contains(state.searchQuery.toLowerCase());
      final matchesCategory = categoryId == null || p.categoryId == categoryId;
      return matchesQuery && matchesCategory;
    }).toList();
    if (categoryId == null) {
      emit(state.copyWith(clearCategory: true, filteredProducts: filtered));
    } else {
      emit(state.copyWith(selectedCategoryId: categoryId, filteredProducts: filtered));
    }
  }

  void _onProductAdded(ProductAddedToCart event, Emitter<PosState> emit) {
    final product = event.product;
    final cart = state.activeCart;
    final existingIndex = cart.items.indexWhere((i) => i.product.id == product.id);
    List<CartItemModel> updated;
    if (existingIndex >= 0) {
      updated = List.from(cart.items);
      final existing = updated[existingIndex];
      updated[existingIndex] = CartItemModel(
        product: existing.product,
        quantity: existing.quantity + 1,
        discountPercent: existing.discountPercent,
      );
    } else {
      updated = [
        ...cart.items,
        CartItemModel(
          product: product,
          quantity: 1,
          discountPercent: cart.discountPercent,
        ),
      ];
    }
    emit(state.withUpdatedActiveCart(cart.copyWith(items: updated)));
  }

  void _onQuantityChanged(CartItemQuantityChanged event, Emitter<PosState> emit) {
    if (event.quantity <= 0) {
      add(CartItemRemoved(event.productId));
      return;
    }
    final cart = state.activeCart;
    final updated = cart.items.map((item) {
      if (item.product.id == event.productId) {
        return item.copyWith(quantity: event.quantity);
      }
      return item;
    }).toList();
    emit(state.withUpdatedActiveCart(cart.copyWith(items: updated)));
  }

  void _onItemRemoved(CartItemRemoved event, Emitter<PosState> emit) {
    final cart = state.activeCart;
    final updated = cart.items.where((i) => i.product.id != event.productId).toList();
    emit(state.withUpdatedActiveCart(cart.copyWith(items: updated)));
  }

  void _onCartCleared(CartCleared event, Emitter<PosState> emit) {
    final cart = state.activeCart;
    emit(state.withUpdatedActiveCart(
      cart.copyWith(items: [], clearCustomer: true, discountPercent: 0),
    ));
  }

  void _onCustomerSelected(CustomerSelected event, Emitter<PosState> emit) {
    final cart = state.activeCart;
    if (event.customer == null) {
      emit(state.withUpdatedActiveCart(
        cart.copyWith(clearCustomer: true, discountPercent: 0),
      ));
    } else {
      emit(state.withUpdatedActiveCart(cart.copyWith(
        customer: event.customer,
        discountPercent: event.customer!.discountPercent,
      )));
    }
  }

  Future<void> _onBarcodeScanned(
      BarcodeScanned event, Emitter<PosState> emit) async {
    // 1. Avval Hive-dan qidirish
    try {
      final product = _hiveService.getProductByBarcode(event.barcode);
      add(ProductAddedToCart(product));
      return;
    } catch (_) {
      // Hive-da yo'q — serverdan qidirish
    }

    // 2. Serverdan qidirish
    try {
      final isOnline = await NetworkInfo.isConnected();
      if (!isOnline) {
        emit(state.copyWith(
            errorMessage: 'Mahsulot topilmadi: ${event.barcode}'));
        return;
      }

      final response = await _syncService
          .apiClient.dio
          .get('/products/barcode/${event.barcode}');
      final product = ProductModel.fromJson(
          Map<String, dynamic>.from(response.data));
      add(ProductAddedToCart(product));
    } catch (_) {
      emit(state.copyWith(
          errorMessage: 'Mahsulot topilmadi: ${event.barcode}'));
    }
  }

  Future<void> _onSaleSubmitted(SaleSubmitted event, Emitter<PosState> emit) async {
    emit(state.copyWith(status: PosStatus.processingPayment));
    final cart = state.activeCart;
    final items = cart.items.map((item) => sale_model.SaleItemRequest(
          productId: item.product.id,
          quantity: item.quantity.toInt(),
          unitPrice: item.product.sellPrice,
          discountPercent: item.discountPercent,
        )).toList();
    final payments = event.payments.map((p) => sale_model.PaymentRequest(
          paymentMethodId: p.paymentMethodId,
          amount: p.amount,
        )).toList();
    final request = sale_model.CreateSaleRequest(
      customerId: cart.customer?.id,
      items: items,
      payments: payments,
    );
    final receiptItems = cart.items.map((item) => <String, dynamic>{
          'productName': item.product.name,
          'quantity': item.quantity,
          'unitPrice': item.product.sellPrice,
          'totalPrice': item.quantity * item.product.sellPrice,
        }).toList();

    final isOnline = await NetworkInfo.isConnected();
    if (isOnline) {
      try {
        final response = await _saleRepository.createSale(request);
        final user = _hiveService.getUser();
        final receipt = sale_model.LocalSaleReceipt(
          saleNumber: response.saleNumber,
          serverId: response.id,
          totalAmount: response.netAmount,
          paidAmount: response.paidAmount,
          changeAmount: response.changeAmount,
          cashierName: response.cashierName.isNotEmpty
              ? response.cashierName
              : (user?.fullName.isNotEmpty == true ? user!.fullName : user?.username ?? ''),
          createdAt: response.createdAt,
          items: receiptItems,
          payments: request.payments.map((p) => p.toJson()).toList(),
          syncStatus: 'SYNCED',
        );
        await _hiveService.saveReceipt(receipt);
        _removeOrClearActiveCart(
          emit,
          '✅ Sotuv muvaffaqiyatli amalga oshirildi!',
        );
      } catch (e) {
        await _saveOffline(request, receiptItems: receiptItems);
        _removeOrClearActiveCart(emit, '⚠️ Server xatosi. Lokal saqlandi.');
      }
    } else {
      await _saveOffline(request, receiptItems: receiptItems);
      _removeOrClearActiveCart(emit, '📴 Oflayn rejimda saqlandi.');
    }
  }

  void _removeOrClearActiveCart(Emitter<PosState> emit, String message) {
    final newCarts = List<CartData>.from(state.carts);
    if (newCarts.length > 1) {
      newCarts.removeAt(state.activeCartIndex);
      // Relabel remaining carts
      final relabeled = newCarts
          .asMap()
          .entries
          .map((e) => e.value.copyWith(label: 'Savat ${e.key + 1}'))
          .toList();
      final newIndex = state.activeCartIndex >= relabeled.length
          ? relabeled.length - 1
          : state.activeCartIndex;
      emit(state.copyWith(
        status: PosStatus.success,
        successMessage: message,
        carts: relabeled,
        activeCartIndex: newIndex,
        pendingSalesCount: _hiveService.pendingSalesCount,
      ));
    } else {
      // Only one cart — clear it instead of removing
      final cleared = CartData(id: 'cart_1', label: 'Savat 1');
      emit(state.copyWith(
        status: PosStatus.success,
        successMessage: message,
        carts: [cleared],
        activeCartIndex: 0,
        pendingSalesCount: _hiveService.pendingSalesCount,
      ));
    }
  }

  Future<void> _saveOffline(
    sale_model.CreateSaleRequest request, {
    List<Map<String, dynamic>> receiptItems = const [],
  }) async {
    final localId = DateTime.now().millisecondsSinceEpoch.toString();
    final pending = sale_model.PendingSale(
      localId: localId,
      saleData: request.toJson(),
      createdAt: DateTime.now(),
    );
    await _hiveService.savePendingSale(pending);
    final user = _hiveService.getUser();
    final total = receiptItems.fold<double>(
        0, (s, e) => s + ((e['totalPrice'] as num?)?.toDouble() ?? 0));
    final receipt = sale_model.LocalSaleReceipt(
      saleNumber: 'LOCAL-$localId',
      totalAmount: total,
      paidAmount: total,
      changeAmount: 0,
      cashierName: user?.fullName.isNotEmpty == true
          ? user!.fullName
          : (user?.username ?? ''),
      createdAt: DateTime.now(),
      items: receiptItems,
      payments: request.payments.map((p) => p.toJson()).toList(),
      syncStatus: 'PENDING',
    );
    await _hiveService.saveReceipt(receipt);
  }

  void _onDiscountApplied(DiscountApplied event, Emitter<PosState> emit) {
    final cart = state.activeCart;
    emit(state.withUpdatedActiveCart(cart.copyWith(discountPercent: event.percent)));
  }

  // Multi-cart handlers
  void _onCartAdded(CartAdded event, Emitter<PosState> emit) {
    final newIndex = state.carts.length;
    final newCart = CartData(
      id: 'cart_${DateTime.now().millisecondsSinceEpoch}',
      label: 'Savat ${newIndex + 1}',
    );
    emit(state.copyWith(
      carts: [...state.carts, newCart],
      activeCartIndex: newIndex,
    ));
  }

  void _onCartSwitched(CartSwitched event, Emitter<PosState> emit) {
    if (event.index >= 0 && event.index < state.carts.length) {
      emit(state.copyWith(activeCartIndex: event.index));
    }
  }

  void _onCartRemoved(CartRemoved event, Emitter<PosState> emit) {
    if (state.carts.length <= 1) return;
    final newCarts = List<CartData>.from(state.carts)..removeAt(event.index);
    // Relabel carts
    final relabeled = newCarts
        .asMap()
        .entries
        .map((e) => e.value.copyWith(label: 'Savat ${e.key + 1}'))
        .toList();
    int newActiveIndex = state.activeCartIndex;
    if (event.index < state.activeCartIndex) {
      newActiveIndex = state.activeCartIndex - 1;
    } else if (newActiveIndex >= relabeled.length) {
      newActiveIndex = relabeled.length - 1;
    }
    emit(state.copyWith(carts: relabeled, activeCartIndex: newActiveIndex));
  }

  Future<void> _onCustomerSearchByPhone(
    CustomerSearchByPhone event,
    Emitter<PosState> emit,
  ) async {
    final repo = _customerRepository;
    if (repo == null) return;
    try {
      final customer = await repo.getByPhone(event.phone);
      if (customer != null) {
        add(CustomerSelected(customer));
        emit(state.copyWith(successMessage: '${customer.name} tanlandi'));
      } else {
        emit(state.copyWith(errorMessage: 'Mijoz topilmadi: ${event.phone}'));
      }
    } catch (_) {
      emit(state.copyWith(errorMessage: 'Mijoz topilmadi: ${event.phone}'));
    }
  }

  // ── Sync handlers ─────────────────────────────────────────────────────────

  Future<void> _onSyncStarted(
      SyncStarted event, Emitter<PosState> emit) async {
    emit(state.copyWith(isSyncing: true));
    try {
      await _syncService.forceSyncPendingSales();
      final synced = state.pendingSalesCount - _hiveService.pendingSalesCount;
      final failed = _hiveService.pendingSalesCount;
      add(SyncCompleted(synced: synced > 0 ? synced : 0, failed: failed));
    } catch (_) {
      add(SyncCompleted(synced: 0, failed: state.pendingSalesCount));
    }
  }

  void _onSyncCompleted(SyncCompleted event, Emitter<PosState> emit) {
    emit(state.copyWith(
      isSyncing: false,
      pendingSalesCount: _hiveService.pendingSalesCount,
      successMessage: event.synced > 0
          ? '${event.synced} sotuv yuklandi'
          : null,
    ));
  }

  // ── Item discount & price change ──────────────────────────────────────────

  void _onItemDiscountApplied(
      ItemDiscountApplied event, Emitter<PosState> emit) {
    final cart = state.activeCart;
    final updated = cart.items.map((item) {
      if (item.product.id == event.productId) {
        return item.copyWith(discountPercent: event.percent);
      }
      return item;
    }).toList();
    emit(state.withUpdatedActiveCart(cart.copyWith(items: updated)));
  }

  void _onItemPriceChanged(ItemPriceChanged event, Emitter<PosState> emit) {
    final cart = state.activeCart;
    final updated = cart.items.map((item) {
      if (item.product.id == event.productId) {
        // customPrice uchun product ni override — CartItemModel'da yangi field
        return CartItemModel(
          product: item.product,
          quantity: item.quantity,
          discountPercent: item.discountPercent,
          customPrice: event.newPrice,
        );
      }
      return item;
    }).toList();
    emit(state.withUpdatedActiveCart(cart.copyWith(items: updated)));
  }

  // ── Connectivity handler ──────────────────────────────────────────────────

  @override
  Future<void> close() {
    _connectivitySub?.cancel();
    return super.close();
  }
}

class _ConnectivityChanged extends PosEvent {
  final bool isOnline;
  _ConnectivityChanged(this.isOnline);
}
