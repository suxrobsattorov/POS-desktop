import '../../core/network/api_client.dart';
import '../../domain/models/shift_model.dart';

class ShiftService {
  final ApiClient _apiClient;
  ShiftService(this._apiClient);

  Future<ShiftModel?> getCurrentShift() async {
    try {
      final resp = await _apiClient.dio.get('/shifts/current');
      if (resp.statusCode == 204 || resp.data == null) return null;
      return ShiftModel.fromJson(resp.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<ShiftModel> openShift(double openingBalance) async {
    final resp = await _apiClient.dio.post('/shifts/open', data: {
      'openAmount': openingBalance,
    });
    return ShiftModel.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<ShiftModel> closeShift(double closingBalance, String notes) async {
    final resp = await _apiClient.dio.post('/shifts/close', data: {
      'closeAmount': closingBalance,
      'notes': notes,
    });
    return ShiftModel.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<List<ShiftModel>> getShiftHistory({int page = 0}) async {
    final resp = await _apiClient.dio.get('/shifts/history',
        queryParameters: {'page': page, 'size': 20});
    final content = resp.data['content'] as List;
    return content
        .map((e) => ShiftModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
