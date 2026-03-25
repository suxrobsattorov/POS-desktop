import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../config/hive_config.dart';

class AppSettingsProvider extends ChangeNotifier {
  static const _themeKey = 'ui_theme_mode';
  static const _langKey = 'ui_language';
  static const _printerKey = 'printer_enabled';
  static const _pdfKey = 'pdf_enabled';
  static const _autoPrintKey = 'auto_print';

  ThemeMode _themeMode = ThemeMode.dark;
  String _language = 'uz';
  bool _printerEnabled = false;
  bool _pdfEnabled = true;
  bool _autoPrint = false;

  ThemeMode get themeMode => _themeMode;
  String get language => _language;
  bool get printerEnabled => _printerEnabled;
  bool get pdfEnabled => _pdfEnabled;
  bool get autoPrint => _autoPrint;

  void load() {
    try {
      final box = Hive.box(HiveConfig.settingsBox);
      final theme = box.get(_themeKey, defaultValue: 'dark') as String;
      _themeMode = theme == 'light' ? ThemeMode.light : ThemeMode.dark;
      _language = (box.get(_langKey, defaultValue: 'uz') as String?) ?? 'uz';
      _printerEnabled = (box.get(_printerKey, defaultValue: false) as bool?) ?? false;
      _pdfEnabled = (box.get(_pdfKey, defaultValue: true) as bool?) ?? true;
      _autoPrint = (box.get(_autoPrintKey, defaultValue: false) as bool?) ?? false;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setTheme(ThemeMode mode) async {
    _themeMode = mode;
    await Hive.box(HiveConfig.settingsBox)
        .put(_themeKey, mode == ThemeMode.light ? 'light' : 'dark');
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    await Hive.box(HiveConfig.settingsBox).put(_langKey, lang);
    notifyListeners();
  }

  Future<void> setPrinterEnabled(bool v) async {
    _printerEnabled = v;
    await Hive.box(HiveConfig.settingsBox).put(_printerKey, v);
    notifyListeners();
  }

  Future<void> setPdfEnabled(bool v) async {
    _pdfEnabled = v;
    await Hive.box(HiveConfig.settingsBox).put(_pdfKey, v);
    notifyListeners();
  }

  Future<void> setAutoPrint(bool v) async {
    _autoPrint = v;
    await Hive.box(HiveConfig.settingsBox).put(_autoPrintKey, v);
    notifyListeners();
  }
}
