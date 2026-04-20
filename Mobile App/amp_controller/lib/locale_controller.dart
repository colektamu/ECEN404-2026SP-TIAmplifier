// lib/locale_controller.dart
import 'package:flutter/material.dart';


/// Simple global locale controller for manual language switching.
class LocaleController extends ChangeNotifier {
  static final LocaleController instance = LocaleController._internal();
  LocaleController._internal();

  Locale _locale = const Locale('en'); // default English
  Locale get locale => _locale;

  void setLocale(Locale locale) {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
  }
}
