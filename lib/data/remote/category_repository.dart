import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../../domain/models/category_model.dart';

class CategoryRepository {
  final ApiClient _apiClient;

  CategoryRepository(this._apiClient);

  /// GET /api/v1/categories — barcha kategoriyalarni olish
  Future<List<CategoryModel>> getAll() async {
    final response = await _apiClient.dio.get(ApiConfig.categories);
    final List data = response.data is List
        ? response.data
        : (response.data['content'] ?? []);
    return data
        .map((j) => CategoryModel.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }
}
