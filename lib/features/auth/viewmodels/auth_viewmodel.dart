import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository _repository;

  AuthViewModel({AuthRepository? repository})
    : _repository = repository ?? SupabaseAuthRepository();

  StreamSubscription<AuthState>? _authSubscription;

  bool _isLoading = false;
  String? _errorMessage;
  User? _user;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  User? get user => _user;

  bool get isAuthenticated => _user != null;

  bool get isEmailVerified => _user?.emailConfirmedAt != null;

  void initialize() {
    _user = _repository.currentUser;

    _authSubscription ??= _repository.authStateChanges.listen(
      (authState) {
        _user = authState.session?.user;
        notifyListeners();
      },
    );

    notifyListeners();
  }

  Future<bool> signUp({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _repository.signUp(
        email: email,
        password: password,
      );

      _user = response.user;

      return response.user != null;
    } on AuthException catch (error) {
      _setError(error.message);
      return false;
    } catch (_) {
      _setError('Unable to create your account. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _repository.signIn(
        email: email,
        password: password,
      );

      _user = response.user;

      return response.user != null;
    } on AuthException catch (error) {
      _setError(error.message);
      return false;
    } catch (_) {
      _setError('Unable to sign in. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> resendConfirmationEmail(String email) async {
    _setLoading(true);
    _clearError();

    try {
      await _repository.resendConfirmationEmail(email);
      return true;
    } on AuthException catch (error) {
      _setError(error.message);
      return false;
    } catch (_) {
      _setError('Unable to resend the confirmation email.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    _clearError();

    try {
      await _repository.resetPassword(email);
      return true;
    } on AuthException catch (error) {
      _setError(error.message);
      return false;
    } catch (_) {
      _setError('Unable to send the password reset email.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    _clearError();

    try {
      await _repository.signOut();
      _user = null;
    } on AuthException catch (error) {
      _setError(error.message);
    } catch (_) {
      _setError('Unable to sign out. Please try again.');
    } finally {
      _setLoading(false);
    }
  }

  void clearError() {
    _clearError();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}