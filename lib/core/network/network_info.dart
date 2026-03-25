import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkInfo {
  static Future<bool> isConnected() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  static Stream<bool> get connectivityStream {
    return Connectivity().onConnectivityChanged.map(
      (results) => !results.contains(ConnectivityResult.none),
    );
  }
}
