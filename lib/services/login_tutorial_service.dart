import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginTutorialService {
  LoginTutorialService._();

  static const String _seenKeyPrefix = 'login_tutorial_seen_';

  static Future<bool> shouldShowForUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('$_seenKeyPrefix$userId') ?? false) {
      return false;
    }

    final user = FirebaseAuth.instance.currentUser;
    final creationTime = user?.metadata.creationTime;
    final lastSignInTime = user?.metadata.lastSignInTime;
    final isFreshAccount =
        creationTime != null &&
        lastSignInTime != null &&
        lastSignInTime.difference(creationTime).abs() <=
            const Duration(minutes: 2) &&
        DateTime.now().difference(creationTime).abs() <=
            const Duration(minutes: 15);

    if (!isFreshAccount) {
      await markSeenForUser(userId);
      return false;
    }

    return true;
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
