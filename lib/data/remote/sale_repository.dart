import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../../domain/models/sale_model.dart';

class SaleRepository {
  final ApiClient _apiClient;
  SaleRepository(this._apiClient);

  Future<SaleResponse> createSale(CreateSaleRequest request) async {
    final response =
        await _apiClient.dio.post(ApiConfig.sales, data: request.toJson());
    return SaleResponse.fromJson(response.data);
  }

  Future<List<Map<String, dynamic>>> getSales({
    int page = 0,
    int size = 50,
    String? search,
  }) async {
    final resp = await _apiClient.dio.get(
      ApiConfig.sales,
      queryParameters: {
        'page': page,
        'size': size,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final data = resp.data['data'];
    if (data == null) return [];
    final content = data['content'] as List? ?? (data as List? ?? []);
    return content.map((e) => e as Map<String, dynamic>).toList();
  }
}
