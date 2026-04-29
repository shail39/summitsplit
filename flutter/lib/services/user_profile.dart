import 'package:shared_preferences/shared_preferences.dart';

class UserProfile {
  static const _keyName = 'user_profile_name';
  static const _keyEmail = 'user_profile_email';

  final String name;
  final String email;

  UserProfile({required this.name, required this.email});

  static Future<UserProfile?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_keyName);
    final email = prefs.getString(_keyEmail);
    if (name == null || email == null || name.isEmpty || email.isEmpty) {
      return null;
    }
    return UserProfile(name: name, email: email);
  }

  static Future<void> save(String name, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, name);
    await prefs.setString(_keyEmail, email);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyName);
    await prefs.remove(_keyEmail);
  }
}
