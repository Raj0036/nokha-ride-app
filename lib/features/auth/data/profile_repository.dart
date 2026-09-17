import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';

abstract class ProfileRepository {
  Future<UserProfile?> getCurrentProfile();

  Future<UserProfile> updateProfile({
    required String fullName,
    required String phone,
    required String address,
    required String city,
    required String state,
    required String pincode,
    DateTime? dateOfBirth,
    String? gender,
  });
}

class SupabaseProfileRepository implements ProfileRepository {
  final SupabaseClient _supabase;

  SupabaseProfileRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  @override
  Future<UserProfile?> getCurrentProfile() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      return null;
    }

    final response = await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return UserProfile.fromMap(response);
  }

  @override
  Future<UserProfile> updateProfile({
    required String fullName,
    required String phone,
    required String address,
    required String city,
    required String state,
    required String pincode,
    DateTime? dateOfBirth,
    String? gender,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw const AuthException('You must be logged in.');
    }

    final response = await _supabase
        .from('profiles')
        .update({
          'full_name': fullName.trim(),
          'phone': phone.trim(),
          'email': user.email,
          'address': address.trim(),
          'city': city.trim(),
          'state': state.trim(),
          'pincode': pincode.trim(),
          'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
          'gender': gender,
        })
        .eq('id', user.id)
        .select()
        .single();

    return UserProfile.fromMap(response);
  }
}
