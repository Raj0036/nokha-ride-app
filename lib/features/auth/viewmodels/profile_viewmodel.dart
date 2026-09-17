import 'package:flutter/foundation.dart';

import '../data/profile_repository.dart';
import '../models/user_profile.dart';

class ProfileViewModel extends ChangeNotifier {
  final ProfileRepository _repository;

  ProfileViewModel({ProfileRepository? repository})
      : _repository = repository ?? SupabaseProfileRepository();

  UserProfile? _profile;
  bool _isLoading = false;
  String? _errorMessage;

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isProfileComplete => _profile?.isComplete ?? false;

  Future<void> loadProfile() async {
    _setLoading(true);
    _clearError();

    try {
      _profile = await _repository.getCurrentProfile();
    } catch (_) {
      _setError('Unable to load your profile. Please try again.');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> saveProfile({
    required String fullName,
    required String phone,
    required String address,
    required String city,
    required String state,
    required String pincode,
    DateTime? dateOfBirth,
    String? gender,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      _profile = await _repository.updateProfile(
        fullName: fullName,
        phone: phone,
        address: address,
        city: city,
        state: state,
        pincode: pincode,
        dateOfBirth: dateOfBirth,
        gender: gender,
      );

      notifyListeners();
      return true;
    } catch (_) {
      _setError('Unable to save your profile. Please try again.');
      return false;
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
}
