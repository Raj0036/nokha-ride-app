import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AuthRepository {
  Stream<AuthState> get authStateChanges;

  User? get currentUser;

  Session? get currentSession;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  });

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<void> resendConfirmationEmail(String email);

  Future<void> resetPassword(String email);
}

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _supabase;

  SupabaseAuthRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  @override
  Stream<AuthState> get authStateChanges {
    return _supabase.auth.onAuthStateChange;
  }

  @override
  User? get currentUser {
    return _supabase.auth.currentUser;
  }

  @override
  Session? get currentSession {
    return _supabase.auth.currentSession;
  }

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return _supabase.auth.signUp(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  @override
  Future<void> resendConfirmationEmail(String email) async {
    await _supabase.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
    );
  }

  @override
  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(
      email.trim(),
    );
  }
}