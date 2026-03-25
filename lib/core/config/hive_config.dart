import 'package:hive_flutter/hive_flutter.dart';

class HiveConfig {
  HiveConfig._();

  static const String productsBox = 'products_box';
  static const String categoriesBox = 'categories_box';
  static const String customersBox = 'customers_box';
  static const String paymentMethodsBox = 'payment_methods_box';
  static const String pendingSalesBox = 'pending_sales_box';
  static const String receiptsBox = 'receipts_box';
  static const String settingsBox = 'settings_box';
  static const String authBox = 'auth_box';

  static Future<void> init() async {
    await Hive.initFlutter();

    // Close all open boxes first (handles hot restart type conflicts)
    await Hive.close();

    // Open all as dynamic — consistent with HiveService.Hive.box() calls
    await Hive.openBox(productsBox);
    await Hive.openBox(categoriesBox);
    await Hive.openBox(customersBox);
    await Hive.openBox(paymentMethodsBox);
    await Hive.openBox(pendingSalesBox);
    await Hive.openBox(receiptsBox);
    await Hive.openBox(settingsBox);
    await Hive.openBox(authBox);
  }

  static Future<void> clearAll() async {
    await Hive.box(productsBox).clear();
    await Hive.box(categoriesBox).clear();
    await Hive.box(customersBox).clear();
    await Hive.box(paymentMethodsBox).clear();
    await Hive.box(pendingSalesBox).clear();
    await Hive.box(receiptsBox).clear();
    await Hive.box(settingsBox).clear();
    await Hive.box(authBox).clear();
  }
}
