import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nokha_ride/features/auth/data/auth_repository.dart';
import 'package:nokha_ride/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:nokha_ride/features/auth/views/login_page.dart';

class TestAuthRepository implements AuthRepository {
  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  User? get currentUser => null;

  @override
  Session? get currentSession => null;

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    throw UnsupportedError('Not used by this widget test.');
  }

  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    throw UnsupportedError('Not used by this widget test.');
  }

  @override
  Future<void> signOut() async {
    throw UnsupportedError('Not used by this widget test.');
  }

  @override
  Future<void> resendConfirmationEmail(String email) async {
    throw UnsupportedError('Not used by this widget test.');
  }

  @override
  Future<void> resetPassword(String email) async {
    throw UnsupportedError('Not used by this widget test.');
  }
}

void main() {
  testWidgets('Nokha Ride login page renders', (
    WidgetTester tester,
  ) async {
    final authViewModel = AuthViewModel(
      repository: TestAuthRepository(),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: authViewModel,
        child: const MaterialApp(
          home: LoginPage(),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Welcome to Nokha Ride'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(
      find.text("Don't have an account? Create one"),
      findsOneWidget,
    );

    authViewModel.dispose();
  });
}
