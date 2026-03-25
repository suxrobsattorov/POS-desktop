import 'package:hive_flutter/hive_flutter.dart';
import '../../core/config/hive_config.dart';
import '../../domain/models/product_model.dart';
import '../../domain/models/category_model.dart';
import '../../domain/models/payment_method_model.dart';
import '../../domain/models/customer_model.dart';
import '../../domain/models/sale_model.dart';
import '../../domain/models/user_model.dart';

class HiveService {
  // ── Auth ───────────────────────────────────────────────────────────────────

  Future<void> saveAuthData({
    required String accessToken,
    required String refreshToken,
    required UserModel user,
  }) async {
    final box = Hive.box(HiveConfig.authBox);
    await box.put('accessToken', accessToken);
    await box.put('refreshToken', refreshToken);
    await box.put('user', user.toJson());
  }

  String? getAccessToken() => Hive.box(HiveConfig.authBox).get('accessToken');
  String? getRefreshToken() =>
      Hive.box(HiveConfig.authBox).get('refreshToken');

  UserModel? getUser() {
    final data = Hive.box(HiveConfig.authBox).get('user');
    if (data == null) return null;
    return UserModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> clearAuth() async {
    final box = Hive.box(HiveConfig.authBox);
    // Preserve known users list so the login screen can still show avatars
    final knownUsers = box.get('knownUsers');
    await box.clear();
    if (knownUsers != null) {
      await box.put('knownUsers', knownUsers);
    }
  }

  bool get isLoggedIn => getAccessToken() != null;

  // ── Known users (for PIN login user selector) ─────────────────────────────

  /// Call this after every successful login to keep the local users list fresh.
  Future<void> saveKnownUser(UserModel user) async {
    final box = Hive.box(HiveConfig.authBox);
    final raw = box.get('knownUsers');
    final List<Map<String, dynamic>> list = raw == null
        ? []
        : (raw as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
    // Replace existing entry for the same username or append
    final idx = list.indexWhere((u) => u['username'] == user.username);
    if (idx >= 0) {
      list[idx] = user.toJson();
    } else {
      list.add(user.toJson());
    }
    await box.put('knownUsers', list.map((e) => Map<dynamic, dynamic>.from(e)).toList());
  }

  List<UserModel> getKnownUsers() {
    final box = Hive.box(HiveConfig.authBox);
    final raw = box.get('knownUsers');
    if (raw == null) return [];
    return (raw as List)
        .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ── Products ──────────────────────────────────────────────────────────────

  Future<void> saveProducts(List<ProductModel> products) async {
    final box = Hive.box(HiveConfig.productsBox);
    await box.clear();
    final map = {
      for (final p in products) p.id.toString(): p.toJson(),
    };
    await box.putAll(map);
  }

  List<ProductModel> getProducts() {
    final box = Hive.box(HiveConfig.productsBox);
    return box.values
        .map((v) => ProductModel.fromJson(Map<String, dynamic>.from(v)))
        .toList();
  }

  List<ProductModel> searchProducts(String query) {
    final q = query.toLowerCase();
    return getProducts().where((p) {
      return p.name.toLowerCase().contains(q) ||
          (p.barcode?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  ProductModel getProductByBarcode(String barcode) {
    return getProducts().firstWhere(
      (p) => p.barcode == barcode,
      orElse: () => throw Exception('Product not found'),
    );
  }

  // ── Categories ────────────────────────────────────────────────────────────

  Future<void> saveCategories(List<CategoryModel> categories) async {
    final box = Hive.box(HiveConfig.categoriesBox);
    await box.clear();
    final map = {
      for (final c in categories) c.id.toString(): c.toJson(),
    };
    await box.putAll(map);
  }

  List<CategoryModel> getCategories() {
    final box = Hive.box(HiveConfig.categoriesBox);
    return box.values
        .map((v) => CategoryModel.fromJson(Map<String, dynamic>.from(v)))
        .toList();
  }

  // ── Payment Methods ───────────────────────────────────────────────────────

  Future<void> savePaymentMethods(List<PaymentMethodModel> methods) async {
    final box = Hive.box(HiveConfig.paymentMethodsBox);
    await box.clear();
    final map = {
      for (final m in methods) m.id.toString(): m.toJson(),
    };
    await box.putAll(map);
  }

  List<PaymentMethodModel> getPaymentMethods() {
    final box = Hive.box(HiveConfig.paymentMethodsBox);
    return box.values
        .map((v) =>
            PaymentMethodModel.fromJson(Map<String, dynamic>.from(v)))
        .toList();
  }

  // ── Customers ─────────────────────────────────────────────────────────────

  Future<void> saveCustomers(List<CustomerModel> customers) async {
    final box = Hive.box(HiveConfig.customersBox);
    await box.clear();
    final map = {
      for (final c in customers) c.id.toString(): c.toJson(),
    };
    await box.putAll(map);
  }

  List<CustomerModel> getCustomers() {
    final box = Hive.box(HiveConfig.customersBox);
    return box.values
        .map((v) => CustomerModel.fromJson(Map<String, dynamic>.from(v)))
        .toList();
  }

  // ── Completed Receipts (local cache) ─────────────────────────────────────

  Future<void> saveReceipt(LocalSaleReceipt receipt) async {
    final box = Hive.box(HiveConfig.receiptsBox);
    await box.put(receipt.saleNumber, receipt.toHive());
  }

  List<Map<String, dynamic>> getLocalReceipts() {
    final box = Hive.box(HiveConfig.receiptsBox);
    final list = box.values
        .map((v) => LocalSaleReceipt.fromHive(v).toHistoryMap())
        .toList();
    list.sort((a, b) {
      final da = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime(2000);
      final db = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime(2000);
      return db.compareTo(da);
    });
    return list;
  }

  // ── Pending Sales ─────────────────────────────────────────────────────────

  Future<void> savePendingSale(PendingSale sale) async {
    final box = Hive.box(HiveConfig.pendingSalesBox);
    await box.put(sale.localId, sale.toHive());
  }

  List<PendingSale> getPendingSales() {
    final box = Hive.box(HiveConfig.pendingSalesBox);
    return box.values
        .map((v) => PendingSale.fromHive(v))
        .where((s) => !s.synced)
        .toList();
  }

  Future<void> markSaleSynced(String localId) async {
    final box = Hive.box(HiveConfig.pendingSalesBox);
    await box.delete(localId);
  }

  int get pendingSalesCount => getPendingSales().length;

  // ── Settings ──────────────────────────────────────────────────────────────

  Future<void> saveSetting(String key, String value) async {
    await Hive.box(HiveConfig.settingsBox).put(key, value);
  }

  String? getSetting(String key) =>
      Hive.box(HiveConfig.settingsBox).get(key);

  Future<void> saveSettings(Map<String, String> settings) async {
    final box = Hive.box(HiveConfig.settingsBox);
    await box.putAll(settings);
  }

  String getShopName() => getSetting('shop_name') ?? 'POS Kassa';
  String getShopAddress() => getSetting('shop_address') ?? '';
  String getShopPhone() => getSetting('shop_phone') ?? '';
  String getReceiptHeader() => getSetting('receipt_header') ?? '';
  String getCurrency() => getSetting('currency') ?? 'UZS';
  String getTaxRate() => getSetting('tax_rate') ?? '0';
  String getReceiptFooter() => getSetting('receipt_footer') ?? '';

  /// LocalSaleReceipt -> getLocalReceipts alias (HistoryScreen uchun)
  List<Map<String, dynamic>> getReceipts() => getLocalReceipts();
}
