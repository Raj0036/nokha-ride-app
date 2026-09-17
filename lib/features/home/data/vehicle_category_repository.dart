import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/vehicle_category.dart';

abstract class VehicleCategoryRepository {
  Future<List<VehicleCategory>> getActiveCategories();
}

class SupabaseVehicleCategoryRepository
    implements VehicleCategoryRepository {
  final SupabaseClient _supabase;

  SupabaseVehicleCategoryRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  @override
  Future<List<VehicleCategory>> getActiveCategories() async {
    final response = await _supabase
        .from('vehicle_categories')
        .select()
        .eq('is_active', true)
        .eq('is_bike', false)
        .order('sort_order', ascending: true)
        .order('name', ascending: true);

    return (response as List)
        .map(
          (row) => VehicleCategory.fromMap(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList();
  }
}
