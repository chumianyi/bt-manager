import 'package:flutter/material.dart';
import '../utils/storage_service.dart';

class AppProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  int _refreshInterval = 5;
  bool _isInitialized = false;

  ThemeMode get themeMode => _themeMode;
  int get refreshInterval => _refreshInterval;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    final themeStr = await StorageService.getThemeMode();
    if (themeStr != null) {
      _themeMode = themeStr == 'dark' ? ThemeMode.dark : ThemeMode.light;
    }
    _refreshInterval = await StorageService.getRefreshInterval();
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await StorageService.setThemeMode(_themeMode == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }

  Future<void> setRefreshInterval(int seconds) async {
    _refreshInterval = seconds;
    await StorageService.setRefreshInterval(seconds);
    notifyListeners();
  }
}
