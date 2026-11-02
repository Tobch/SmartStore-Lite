import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsViewModel extends ChangeNotifier {
  bool _isDarkMode = false;
  int _globalLowStockThreshold = 5;

  bool get isDarkMode => _isDarkMode;
  int get globalLowStockThreshold => _globalLowStockThreshold;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
    _globalLowStockThreshold = prefs.getInt('low_stock_threshold') ?? 5;
    notifyListeners();
  }

  Future<void> toggleTheme(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', value);
    notifyListeners();
  }

  Future<void> updateThreshold(int value) async {
    _globalLowStockThreshold = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('low_stock_threshold', value);
    notifyListeners();
  }
}