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
  bool get isPhoneVerified => _user?.phoneConfirmedAt != null;
  bool get isIdentityVerified => isEmailVerified || isPhoneVerified;

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

  Future<bool> sendPhoneOtp({required String phone}) async {
    _setLoading(true);
    _clearError();

    try {
      await _repository.sendPhoneOtp(phone: phone);
      return true;
    } on AuthException catch (error) {
      _setError(_friendlyAuthError(error.message));
      return false;
    } catch (_) {
      _setError('OTP could not be sent. Check your connection and try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _repository.verifyPhoneOtp(
        phone: phone,
        token: token,
      );

      _user = response.user;
      notifyListeners();
      return response.user != null && response.session != null;
    } on AuthException catch (error) {
      _setError(_friendlyAuthError(error.message));
      return false;
    } catch (_) {
      _setError('OTP verification failed. Check the code and try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> verifyMsg91WidgetToken({
    required String phone,
    required String accessToken,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _repository.verifyMsg91WidgetToken(
        phone: phone,
        accessToken: accessToken,
      );
      _user = response.user;
      notifyListeners();
      return response.user != null && response.session != null;
    } on AuthException catch (error) {
      _setError(_friendlyAuthError(error.message));
      return false;
    } catch (_) {
      _setError('Phone login failed. Please retry or use your existing email login.');
      return false;
    } finally {
      _setLoading(false);
    }
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

  String _friendlyAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('rate limit') || lower.contains('too many')) {
      return 'Too many OTP attempts. Please wait before trying again.';
    }
    if (lower.contains('phone') && lower.contains('disabled')) {
      return 'Phone login is not enabled for this project yet.';
    }
    return message;
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