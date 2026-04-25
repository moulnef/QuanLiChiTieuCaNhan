import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../services/auth_service.dart';

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

  Future<void> _handleAuthStateChanged(User? user) async {
    _currentUser = user;

    if (user == null) {
      _role = 'guest';
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    _role = await _authService.getUserRole(user.uid);
    _isLoading = false;
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    final result = await _authService.login(email, password);

    if (result == null) {
      _isLoading = false;
      notifyListeners();
      return null;
    }

    if (result != 'admin' && result != 'user') {
      _isLoading = false;
      notifyListeners();
      return result;
    }

    _role = result;
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
