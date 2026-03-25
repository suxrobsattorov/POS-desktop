import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../di/injection.dart';
import '../../data/local/hive_service.dart';

class ApiClient {
  late final Dio _dio;
  final HiveService _hiveService;

  ApiClient(this._hiveService) {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(milliseconds: ApiConfig.connectTimeout),
      receiveTimeout: const Duration(milliseconds: ApiConfig.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = _hiveService.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          try {
            final refreshToken = _hiveService.getRefreshToken();
            if (refreshToken != null) {
              final response = await Dio().post(
                '${ApiConfig.baseUrl}${ApiConfig.refresh}',
                data: {'refreshToken': refreshToken},
              );
              final newToken = response.data['accessToken'];
              // Update token in Hive
              final user = _hiveService.getUser();
              if (user != null) {
                await _hiveService.saveAuthData(
                  accessToken: newToken,
                  refreshToken: response.data['refreshToken'] ?? refreshToken,
                  user: user,
                );
              }
              // Retry
              error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
              final retryResponse = await _dio.fetch(error.requestOptions);
              handler.resolve(retryResponse);
              return;
            }
          } catch (_) {}
        }
        handler.next(error);
      },
    ));

    // Alice HTTP Inspector interceptor
    _dio.interceptors.add(alice.getDioInterceptor());
  }

  Dio get dio => _dio;
}
