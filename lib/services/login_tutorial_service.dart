import 'package:shared_preferences/shared_preferences.dart';

class LoginTutorialService {
  LoginTutorialService._();

  static const String _seenKeyPrefix = 'login_tutorial_seen_';

  static Future<bool> shouldShowForUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('$_seenKeyPrefix$userId') ?? false);
  }

  static Future<void> markSeenForUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_seenKeyPrefix$userId', true);
  }

  static Future<void> resetForUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_seenKeyPrefix$userId');
  }
}
