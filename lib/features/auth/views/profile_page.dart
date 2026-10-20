import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/profile_viewmodel.dart';
import 'complete_profile_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileViewModel>().profile;
    final auth = context.watch<AuthViewModel>();
    final email = Supabase.instance.client.auth.currentUser?.email ?? profile?.email ?? '—';
    final address = [profile?.address, profile?.city, profile?.state, profile?.pincode]
        .whereType<String>().where((v) => v.trim().isNotEmpty).join(', ');

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(
            radius: 42,
            backgroundImage: profile?.profilePhotoUrl != null ? NetworkImage(profile!.profilePhotoUrl!) : null,
            child: profile?.profilePhotoUrl == null ? const Icon(Icons.person_outline, size: 42) : null,
          ),
          const SizedBox(height: 14),
          Center(child: Text(profile?.fullName?.trim().isNotEmpty == true ? profile!.fullName! : 'Nokha Ride user', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center)),
          Center(child: Text(email)),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                _ProfileRow(icon: Icons.phone_outlined, label: 'Mobile', value: profile?.phone ?? 'Not added'),
                const Divider(height: 1),
                _ProfileRow(icon: Icons.cake_outlined, label: 'Date of birth', value: profile?.dateOfBirth?.toLocal().toString().split(' ').first ?? 'Not added'),
                const Divider(height: 1),
                _ProfileRow(icon: Icons.location_on_outlined, label: 'Address', value: address.isEmpty ? 'Not added' : address),
                const Divider(height: 1),
                _ProfileRow(icon: Icons.verified_user_outlined, label: 'Account status', value: profile?.accountStatus ?? 'Unknown'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CompleteProfilePage(popOnSuccess: true)));
              if (context.mounted) await context.read<ProfileViewModel>().loadProfile();
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit profile'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: auth.isLoading ? null : () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Log out?'),
                  content: const Text('You will need to sign in again to book a ride.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Stay signed in')),
                    FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Log out')),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) await context.read<AuthViewModel>().signOut();
            },
            icon: const Icon(Icons.logout),
            label: Text(auth.isLoading ? 'Please wait…' : 'Log out'),
          ),
          if (context.watch<ProfileViewModel>().errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(context.watch<ProfileViewModel>().errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(label),
    subtitle: Text(value.isEmpty ? 'Not added' : value),
  );
}
