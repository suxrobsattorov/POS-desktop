import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/config/hive_config.dart';

class PinService {
  static const _pinKey = 'user_pin_hash';

  bool get hasPin {
    try {
      return Hive.box(HiveConfig.authBox).get(_pinKey) != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> setPin(String pin) async {
    final hash = _hashPin(pin);
    await Hive.box(HiveConfig.authBox).put(_pinKey, hash);
  }

  bool verifyPin(String pin) {
    try {
      final stored = Hive.box(HiveConfig.authBox).get(_pinKey) as String?;
      if (stored == null) return false;
      return _hashPin(pin) == stored;
    } catch (_) {
      return false;
    }
  }

  Future<void> clearPin() async {
    await Hive.box(HiveConfig.authBox).delete(_pinKey);
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode('${pin}_pos_kassa_salt_v1');
    return sha256.convert(bytes).toString();
  }
}
