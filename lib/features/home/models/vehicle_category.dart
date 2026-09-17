class VehicleCategory {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? iconUrl;
  final int? minSeats;
  final int? maxSeats;
  final bool isPassengerVehicle;
  final bool isCommercialVehicle;
  final bool isActive;

  const VehicleCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.iconUrl,
    this.minSeats,
    this.maxSeats,
    required this.isPassengerVehicle,
    required this.isCommercialVehicle,
    required this.isActive,
  });

  factory VehicleCategory.fromMap(Map<String, dynamic> map) {
    return VehicleCategory(
      id: map['id'] as String,
      name: map['name'] as String,
      slug: map['slug'] as String,
      description: map['description'] as String?,
      iconUrl: map['icon_url'] as String?,
      minSeats: map['min_seats'] as int?,
      maxSeats: map['max_seats'] as int?,
      isPassengerVehicle:
          map['is_passenger_vehicle'] as bool? ?? true,
      isCommercialVehicle:
          map['is_commercial_vehicle'] as bool? ?? true,
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}
