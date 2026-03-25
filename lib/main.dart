import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'core/config/hive_config.dart';
import 'core/di/injection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Initialize Hive (closes all open boxes first, then reopens as dynamic)
  await HiveConfig.init();

  // Setup dependency injection
  await setupDependencies();

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('uz'),
        Locale('en'),
        Locale('ru'),
        Locale('uz', 'CY'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('uz'),
      child: const PosApp(),
    ),
  );
}
