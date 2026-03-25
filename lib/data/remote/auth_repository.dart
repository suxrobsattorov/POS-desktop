import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../../domain/models/user_model.dart';

class AuthResult {
  final String accessToken;
  final String refreshToken;
  final UserModel user;

  AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });
}

class AuthRepository {
  final ApiClient _apiClient;
  AuthRepository(this._apiClient);

  Future<AuthResult> login(String username, String password) async {
    final response = await _apiClient.dio.post(
      ApiConfig.login,
      data: {'username': username, 'password': password},
    );
    final data = response.data;
    return AuthResult(
      accessToken: data['accessToken'],
      refreshToken: data['refreshToken'],
      user: UserModel.fromJson(data['user']),
    );
  }

  Future<AuthResult> loginWithPin(String username, String pin) async {
    final response = await _apiClient.dio.post(
      ApiConfig.pinLogin,
      data: {'username': username, 'pin': pin},
    );
    final data = response.data;
    return AuthResult(
      accessToken: data['accessToken'],
      refreshToken: data['refreshToken'],
      user: UserModel.fromJson(data['user']),
    );
  }

  Future<void> logout() async {
    try {
      await _apiClient.dio.post(ApiConfig.logout);
    } catch (_) {}
  }
}
