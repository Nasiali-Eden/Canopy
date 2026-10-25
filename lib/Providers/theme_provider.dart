import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  // The app always opens in light mode, whatever the phone is set to. Dark is
  // still available from Settings for the current session.
  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;

  void setMode(ThemeMode mode) {
    _mode = mode;
    notifyListeners();
  }

  void toggleDarkMode() {
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  Future<void> load() async {
    _mode = ThemeMode.light;
    notifyListeners();
  }
}
