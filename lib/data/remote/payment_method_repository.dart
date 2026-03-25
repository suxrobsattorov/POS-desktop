import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../../domain/models/payment_method_model.dart';

class PaymentMethodRepository {
  final ApiClient _apiClient;

  PaymentMethodRepository(this._apiClient);

  /// GET /api/v1/payment-methods/active — faol to'lov usullarini olish
  Future<List<PaymentMethodModel>> getActive() async {
    try {
      final response = await _apiClient.dio.get(
        '/payment-methods/active',
      );
      final List data = response.data is List
          ? response.data
          : (response.data['content'] ?? []);
      return data
          .map((j) =>
              PaymentMethodModel.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    } catch (_) {
      // Fallback: barcha payment methods
      final response = await _apiClient.dio.get(ApiConfig.paymentMethods);
      final List data = response.data is List
          ? response.data
          : (response.data['content'] ?? []);
      return data
          .map((j) =>
              PaymentMethodModel.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    }
  }
}
