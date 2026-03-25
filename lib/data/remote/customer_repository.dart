import '../../core/network/api_client.dart';
import '../../domain/models/customer_model.dart';

class CustomerRepository {
  final ApiClient _apiClient;

  CustomerRepository(this._apiClient);

  Future<CustomerModel?> getByPhone(String phone) async {
    try {
      final response = await _apiClient.dio.get(
        '/customers/phone/${Uri.encodeComponent(phone)}',
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        return CustomerModel(
          id: data['id'] as int,
          name: (data['fullName'] as String?)?.isNotEmpty == true
              ? data['fullName'] as String
              : (data['name'] as String? ?? ''),
          phone: data['phone'] as String?,
          discountPercent: (data['discountPercent'] as num?)?.toDouble() ?? 0,
          bonusPoints: (data['bonusPoints'] as num?)?.toDouble() ?? 0,
          totalPurchases: (data['totalPurchases'] as num?)?.toDouble() ?? 0,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<CustomerModel?> createCustomer({
    required String fullName,
    required String phone,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/customers',
        data: {
          'fullName': fullName,
          'phone': phone,
        },
      );
      if (response.statusCode == 201 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        return CustomerModel(
          id: data['id'] as int,
          name: (data['fullName'] as String?)?.isNotEmpty == true
              ? data['fullName'] as String
              : fullName,
          phone: data['phone'] as String?,
          discountPercent: 0,
          bonusPoints: 0,
          totalPurchases: 0,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
