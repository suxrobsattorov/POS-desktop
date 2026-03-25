import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../../data/local/hive_service.dart';
import '../../domain/models/category_model.dart';
import '../../domain/models/payment_method_model.dart';
import '../../domain/models/product_model.dart';

/// ProductRepository — remote + local (Hive) birlashtiradi.
///
/// Offline-first strategiyasi:
///   1. Avval Hive dan ma'lumot qaytariladi (darhol)
///   2. Keyin server dan yangilanadi va Hive ga saqlanadi
class ProductRepository {
  final ApiClient _apiClient;
  final HiveService _hiveService;

  ProductRepository(this._apiClient, this._hiveService);

  // ── Remote ──────────────────────────────────────────────────────────────────

  /// GET /api/v1/products/all-active — serverdan barcha faol mahsulotlar
  Future<List<ProductModel>> fetchAllFromServer() async {
    try {
      final response = await _apiClient.dio.get('/products/all-active');
      final List data = response.data is List
          ? response.data
          : (response.data['content'] ?? []);
      return data
          .map((j) => ProductModel.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    } catch (_) {
      // Fallback — paginated endpoint
      final response = await _apiClient.dio.get(
        ApiConfig.products,
        queryParameters: {'page': 0, 'size': 10000, 'active': true},
      );
      final List data = response.data is List
          ? response.data
          : (response.data['content'] ?? []);
      return data
          .map((j) => ProductModel.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    }
  }

  /// GET /api/v1/products/barcode/{barcode} — serverdan barcode orqali qidirish
  Future<ProductModel?> findByBarcode(String barcode) async {
    try {
      final response =
          await _apiClient.dio.get('${ApiConfig.barcode}/$barcode');
      return ProductModel.fromJson(
          Map<String, dynamic>.from(response.data));
    } catch (_) {
      return null;
    }
  }

  // ── Local (Hive) ─────────────────────────────────────────────────────────────

  /// Hive dan barcha mahsulotlar (sync bo'lmasa bo'sh qaytishi mumkin)
  List<ProductModel> getAllLocal() => _hiveService.getProducts();

  /// Hive dan barcode orqali mahsulot qidirish
  ProductModel? findByBarcodeLocal(String barcode) {
    try {
      return _hiveService.getProductByBarcode(barcode);
    } catch (_) {
      return null;
    }
  }

  /// Hive ga mahsulotlarni saqlash (upsert — avvalgisini to'liq almashtiradi)
  Future<void> saveAllLocal(List<ProductModel> products) async {
    await _hiveService.saveProducts(products);
  }

  // ── Sync ─────────────────────────────────────────────────────────────────────

  /// Server → Hive: mahsulotlarni yangilash
  ///
  /// Avval local ma'lumotni qaytarish uchun Stream emas — caller offline-first
  /// pattern ni o'zi implements qiladi (hivedan ol, keyin bu ni chaqir).
  Future<void> syncProducts() async {
    try {
      final products = await fetchAllFromServer();
      await saveAllLocal(products);
    } catch (_) {
      // Server mavjud bo'lmasa — Hive dagi ma'lumot saqlanadi
    }
  }

  /// Server → Hive: kategoriyalarni yangilash
  Future<void> syncCategories() async {
    try {
      final response = await _apiClient.dio.get(ApiConfig.categories);
      final List data = response.data is List
          ? response.data
          : (response.data['content'] ?? response.data);
      final categories = data
          .map((j) => CategoryModel.fromJson(Map<String, dynamic>.from(j)))
          .toList();
      await _hiveService.saveCategories(categories);
    } catch (_) {}
  }

  /// Server → Hive: to'lov usullarini yangilash
  Future<void> syncPaymentMethods() async {
    try {
      // Avval /payment-methods/active sinab ko'ramiz
      final response = await () async {
        try {
          return await _apiClient.dio.get('/payment-methods/active');
        } catch (_) {
          return await _apiClient.dio.get(ApiConfig.paymentMethods);
        }
      }();
      final List data = response.data is List
          ? response.data
          : (response.data['content'] ?? response.data);
      final methods = data
          .map((j) =>
              PaymentMethodModel.fromJson(Map<String, dynamic>.from(j)))
          .toList();
      await _hiveService.savePaymentMethods(methods);
    } catch (_) {}
  }
}
