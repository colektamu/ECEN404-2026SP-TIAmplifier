import 'package:shared_preferences/shared_preferences.dart';

class LoginStorage {
  static const _keyRememberEmail = 'remember_email';
  static const _keySavedEmail = 'saved_email';

  static Future<void> setRememberEmail(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRememberEmail, value);
    if (!value) {
      await prefs.remove(_keySavedEmail);
    }
  }

  static Future<bool> getRememberEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRememberEmail) ?? false;
  }

  static Future<void> saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySavedEmail, email);
  }

  static Future<String?> loadEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySavedEmail);
  }
}
