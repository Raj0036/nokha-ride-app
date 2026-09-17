import 'package:flutter/foundation.dart';

import '../data/vehicle_category_repository.dart';
import '../models/vehicle_category.dart';

class HomeViewModel extends ChangeNotifier {
  final VehicleCategoryRepository _repository;

  HomeViewModel({VehicleCategoryRepository? repository})
      : _repository =
            repository ?? SupabaseVehicleCategoryRepository();

  bool _isLoading = false;
  String? _errorMessage;
  List<VehicleCategory> _categories = const [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<VehicleCategory> get categories => _categories;

  Future<void> loadCategories() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _categories = await _repository.getActiveCategories();
    } catch (_) {
      _errorMessage =
          'Unable to load vehicle categories. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadCategories();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
