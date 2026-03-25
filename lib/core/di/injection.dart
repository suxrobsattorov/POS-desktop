import 'package:alice/alice.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../network/api_client.dart';
import '../providers/app_settings_provider.dart';
import '../providers/shift_provider.dart';
import '../services/receipt_service.dart';
import '../../data/local/hive_service.dart';
import '../../data/local/pin_service.dart';
import '../../data/remote/auth_repository.dart';
import '../../data/remote/category_repository.dart';
import '../../data/remote/payment_method_repository.dart';
import '../../data/remote/product_repository.dart';
import '../../data/remote/sale_repository.dart';
import '../../data/remote/sync_service.dart';
import '../../data/remote/shift_service.dart';

final GetIt sl = GetIt.instance;

/// Navigator key — shared between GoRouter and Alice
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Alice HTTP Inspector — global instance
final Alice alice = Alice(
  showNotification: false, // macOS da notification ishlamaydi
  showInspectorOnShake: false,
  navigatorKey: navigatorKey,
);

Future<void> setupDependencies() async {
  // Core
  sl.registerLazySingleton<HiveService>(() => HiveService());
  sl.registerLazySingleton<PinService>(() => PinService());
  sl.registerLazySingleton<ReceiptService>(() => ReceiptService());
  sl.registerLazySingleton<ApiClient>(() => ApiClient(sl<HiveService>()));

  // Settings Provider (loaded eagerly)
  final settingsProvider = AppSettingsProvider()..load();
  sl.registerSingleton<AppSettingsProvider>(settingsProvider);

  // Repositories
  sl.registerLazySingleton<AuthRepository>(
      () => AuthRepository(sl<ApiClient>()));
  sl.registerLazySingleton<SaleRepository>(
      () => SaleRepository(sl<ApiClient>()));
  sl.registerLazySingleton<ProductRepository>(
      () => ProductRepository(sl<ApiClient>(), sl<HiveService>()));
  sl.registerLazySingleton<CategoryRepository>(
      () => CategoryRepository(sl<ApiClient>()));
  sl.registerLazySingleton<PaymentMethodRepository>(
      () => PaymentMethodRepository(sl<ApiClient>()));

  // Remote services
  sl.registerLazySingleton<ShiftService>(
      () => ShiftService(sl<ApiClient>()));

  // Providers
  sl.registerLazySingleton<ShiftProvider>(
      () => ShiftProvider(sl<ShiftService>()));

  // Sync service
  sl.registerLazySingleton<SyncService>(
      () => SyncService(sl<ApiClient>(), sl<HiveService>()));
}
