import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/di/injection.dart';
import 'core/providers/app_settings_provider.dart';
import 'core/providers/shift_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class PosApp extends StatelessWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettingsProvider>.value(
            value: sl<AppSettingsProvider>()),
        ChangeNotifierProvider<ShiftProvider>.value(
            value: sl<ShiftProvider>()),
      ],
      child: Consumer<AppSettingsProvider>(
        builder: (ctx, settings, _) {
          return MaterialApp.router(
            title: 'POS Kassa',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: settings.themeMode,
            routerConfig: appRouter,
            localizationsDelegates: ctx.localizationDelegates,
            supportedLocales: ctx.supportedLocales,
            locale: ctx.locale,
            builder: (context, child) => child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}

