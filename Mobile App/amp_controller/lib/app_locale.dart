// lib/app_locale.dart
import 'locale_controller.dart';

/// Simple helper: choose string based on current language.
/// Usage: t('Amp Controller', '功放控制器', 'Controlador de amplificador')
String t(String en, String zh, String es) {
  final code = LocaleController.instance.locale.languageCode;
  switch (code) {
    case 'zh':
      return zh;
    case 'es':
      return es;
    default:
      return en;
  }
}
