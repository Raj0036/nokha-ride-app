import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'features/auth/viewmodels/auth_viewmodel.dart';
import 'features/auth/viewmodels/profile_viewmodel.dart';
import 'features/auth/views/complete_profile_page.dart';
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
  const NokhaRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthViewModel()..initialize(),
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

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final ProfileViewModel _profileViewModel;

  String? _loadedUserId;
  bool _loadingStarted = false;

  @override
  void initState() {
    super.initState();

    _profileViewModel = ProfileViewModel();
    _profileViewModel.addListener(_profileChanged);
  }

  void _profileChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _loadProfileForUser(String userId) {
    if (_loadedUserId == userId && _loadingStarted) {
      return;
    }

    _loadedUserId = userId;
    _loadingStarted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      await _profileViewModel.loadProfile();
    });
  }

  void _resetProfileState() {
    if (_loadedUserId == null && !_loadingStarted) {
      return;
    }

    _loadedUserId = null;
    _loadingStarted = false;
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final user = authViewModel.user;

    if (!authViewModel.isAuthenticated) {
      _resetProfileState();
      return const LoginPage();
    }

    if (!authViewModel.isEmailVerified) {
      return const LoginPage();
    }

    _loadProfileForUser(user!.id);

    if (_profileViewModel.isLoading &&
        _profileViewModel.profile == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_profileViewModel.errorMessage != null &&
        _profileViewModel.profile == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 56,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Unable to load your profile.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    _profileViewModel.loadProfile();
                  },
                  child: const Text('Try Again'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    authViewModel.signOut();
                  },
                  child: const Text('Logout'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ChangeNotifierProvider.value(
      value: _profileViewModel,
      child: _profileViewModel.isProfileComplete
          ? const AuthenticatedHomePage()
          : const CompleteProfilePage(),
    );
  }

  @override
  void dispose() {
    _profileViewModel.removeListener(_profileChanged);
    _profileViewModel.dispose();
    super.dispose();
  }
}

class AuthenticatedHomePage extends StatelessWidget {
  const AuthenticatedHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.read<AuthViewModel>();
    final profile = context.watch<ProfileViewModel>().profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nokha Ride'),
        actions: [
          IconButton(
            onPressed: authViewModel.isLoading
                ? null
                : () => authViewModel.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.local_taxi_rounded,
                size: 72,
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome, ${profile?.fullName ?? 'Customer'}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                profile?.email ?? '',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
