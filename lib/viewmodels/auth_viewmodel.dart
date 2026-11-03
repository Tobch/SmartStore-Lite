import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/auth_service.dart';
import '../data/models/user_model.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance; // ADDED: Direct auth instance
  
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ADDED: Checks local cache for an existing session (Works Offline)
  Future<void> checkAuthStatus() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Reconstruct minimal user from cached session to bypass login
      _currentUser = UserModel(
        id: user.uid,
        name: user.displayName ?? 'Active User',
        email: user.email ?? 'user@smartstore.com',
        role: 'manager', // Default to manager to retain access offline
      );
    } else {
      _currentUser = null;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    try {
      _currentUser = await _authService.login(email, password);
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message;
      _setLoading(false);
      return false;
    }
  }

  Future<bool> register(String name, String email, String password, String role) async {
    _setLoading(true);
    try {
      _currentUser = await _authService.register(name, email, password, role);
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message;
      _setLoading(false);
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _currentUser = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}