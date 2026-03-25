class ApiConfig {
  ApiConfig._();

  static const String baseUrl = 'http://localhost:8080/api/v1';
  static const int connectTimeout = 10000;
  static const int receiveTimeout = 10000;

  // Endpoints
  static const String login = '/auth/login';
  static const String pinLogin = '/auth/pin-login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';

  static const String products = '/products';
  static const String productSync = '/products/sync';
  static const String productSearch = '/products/search';
  static const String barcode = '/products/barcode';

  static const String categories = '/categories';

  static const String sales = '/sales';
  static const String saleSync = '/sales/sync';

  static const String customers = '/customers';
  static const String customerSync = '/customers/sync';

  static const String paymentMethods = '/payment-methods';
  static const String paymentMethodsSync = '/payment-methods/sync';

  static const String settings = '/settings';
  static const String printers = '/printers';

  static const String reportsDaily = '/reports/daily';

  // Shared Prefs Keys
  static const String tokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user_data';
  static const String lastSyncKey = 'last_sync';
}
