import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'features/auth/viewmodels/auth_viewmodel.dart';
import 'features/auth/views/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SupabaseConfig.validate();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  runApp(const NokhaRideApp());
}

class NokhaRideApp extends StatelessWidget {
  final AuthViewModel? authViewModel;

  const NokhaRideApp({
    super.key,
    this.authViewModel,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => authViewModel ?? (AuthViewModel()..initialize()),
      child: MaterialApp(
        title: 'Nokha Ride',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
        ),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, viewModel, _) {
        if (viewModel.isAuthenticated &&
            viewModel.isEmailVerified) {
          return const AuthenticatedHomePage();
        }

        return const LoginPage();
      },
    );
  }
}

class AuthenticatedHomePage extends StatelessWidget {
  const AuthenticatedHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<AuthViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nokha Ride'),
        actions: [
          IconButton(
            onPressed: viewModel.isLoading
                ? null
                : () => viewModel.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 72,
            ),
            const SizedBox(height: 20),
            const Text(
              'Welcome to Nokha Ride',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              viewModel.user?.email ?? '',
            ),
          ],
        ),
      ),
    );
  }
}