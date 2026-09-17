import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../data/location_service.dart';
import '../models/location_model.dart';

class LocationViewModel extends ChangeNotifier {
  final LocationService _locationService;

  LocationViewModel({LocationService? locationService})
      : _locationService = locationService ?? LocationService();

  bool _isLoading = false;
  LocationModel? _currentLocation;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  LocationModel? get currentLocation => _currentLocation;
  String? get errorMessage => _errorMessage;
  bool get hasLocation => _currentLocation != null;

  Future<bool> getCurrentLocation() async {
    _setLoading(true);
    _clearError();

    try {
      final position = await _locationService.getCurrentPosition();

      _currentLocation = LocationModel(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      return true;
    } on LocationServiceDisabledException {
      _setError(
        'Location services are disabled. Please enable GPS.',
      );
      return false;
    } on PermissionDeniedException catch (error) {
      _setError(error.message ?? 'Location permission denied.');
      return false;
    } catch (_) {
      _setError(
        'Unable to get your current location. Please try again.',
      );
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
