import 'package:flutter/material.dart';
import '../../data/remote/shift_service.dart';
import '../../domain/models/shift_model.dart';

class ShiftProvider extends ChangeNotifier {
  final ShiftService _shiftService;
  ShiftProvider(this._shiftService);

  ShiftModel? _currentShift;
  bool _loading = false;
  String? _error;

  ShiftModel? get currentShift => _currentShift;
  bool get isShiftOpen => _currentShift != null && _currentShift!.isOpen;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadCurrentShift() async {
    try {
      _currentShift = await _shiftService.getCurrentShift();
      notifyListeners();
    } catch (_) {
      _currentShift = null;
      notifyListeners();
    }
  }

  Future<bool> openShift(double openingBalance) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _currentShift = await _shiftService.openShift(openingBalance);
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> closeShift(double closingBalance, String notes) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _currentShift = await _shiftService.closeShift(closingBalance, notes);
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }
}
