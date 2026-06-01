import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../services/auth_service.dart';
import '../../services/sync_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService})
    : _authService = authService ?? AuthService.instance {
    _subscription = _authService.authStateChanges().listen(
      _handleAuthStateChanged,
    );
  }

  final AuthService _authService;
  StreamSubscription<User?>? _subscription;

  User? _currentUser;
  String _role = 'guest';
  bool _isLoading = true;

  User? get currentUser => _currentUser;
  String get role => _role;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _role == 'admin';

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('--- [AUTH PROVIDER] $message');
    }
  }

  Future<void> _handleAuthStateChanged(User? user) async {
    _log(
      'authStateChanges callback: ${DateTime.now()} user=${user?.uid ?? 'null'}',
    );
    _currentUser = user;

    if (user == null) {
      _role = 'guest';
      _isLoading = false;
      SyncService().stopAutoSync();
      notifyListeners();
      return;
    }

    _isLoading = false;
    notifyListeners();

    // Start auto sync on login
    SyncService().startAutoSync(user.uid);

    _log('Bắt đầu gọi getUserRole: ${DateTime.now()}');
    _role = await _authService.getUserRole(user.uid);
    _log('getUserRole xong, role=$_role tại ${DateTime.now()}');
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    _log('login() được gọi: ${DateTime.now()}');
    _isLoading = true;
    notifyListeners();

    final result = await _authService.login(email, password);
    _log('login() trả về: ${result ?? 'success'} tại ${DateTime.now()}');

    if (result == null) {
      _isLoading = false;
      notifyListeners();
      return null;
    }
    _isLoading = false;
    notifyListeners();
    return result;
  }

  Future<void> signOut() => _authService.signOut();

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
