import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/vehicle_category_repository.dart';
import '../models/vehicle_category.dart';
import '../../location/models/location_model.dart';

class BookingPage extends StatefulWidget {
  final String bookingType;
  final VehicleCategory? initialCategory;
  final LocationModel? initialPickup;

  const BookingPage({
    super.key,
    this.bookingType = 'RIDE_NOW',
    this.initialCategory,
    this.initialPickup,
  });

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final _formKey = GlobalKey<FormState>();
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  final _notesController = TextEditingController();
  final _supabase = Supabase.instance.client;

  List<VehicleCategory> _categories = const [];
  VehicleCategory? _category;
  bool _loadingCategories = true;
  bool _busy = false;
  String? _error;
  double? _pickupLat;
  double? _pickupLng;
  double? _destinationLat;
  double? _destinationLng;
  String? _serviceAreaId;
  String? _quoteId;
  num? _fare;
  DateTime? _scheduledAt;
  int _passengers = 1;

  bool get _isScheduled => widget.bookingType == 'SCHEDULED';

  String get _title {
    switch (widget.bookingType) {
      case 'SCHEDULED':
        return 'Schedule a ride';
      case 'OUTSTATION':
        return 'Outstation ride';
      case 'EVENT':
        return 'Event vehicle booking';
      default:
        return 'Book a ride';
    }
  }

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    final pickup = widget.initialPickup;
    if (pickup != null) {
      _pickupLat = pickup.latitude;
      _pickupLng = pickup.longitude;
      _pickupController.text =
          '${pickup.latitude.toStringAsFixed(5)}, ${pickup.longitude.toStringAsFixed(5)}';
      _resolveAddress(pickup.latitude, pickup.longitude, pickup: true);
    }
    _loadCategoriesAndArea();
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCategoriesAndArea() async {
    try {
      final categories =
          await SupabaseVehicleCategoryRepository(supabase: _supabase)
              .getActiveCategories();
      final area = await _supabase
          .from('service_areas')
          .select('id')
          .eq('slug', 'nokha')
          .eq('is_active', true)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _category ??= categories.isNotEmpty ? categories.first : null;
        _serviceAreaId = area?['id']?.toString();
        _loadingCategories = false;
      });
      if (_serviceAreaId == null && mounted) {
        setState(() => _error = 'Nokha service area is not active yet.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingCategories = false;
        _error = 'Vehicle categories could not be loaded. Check your connection.';
      });
    }
  }

  Future<void> _resolveAddress(
    double latitude,
    double longitude, {
    required bool pickup,
  }) async {
    try {
      final places = await placemarkFromCoordinates(latitude, longitude);
      if (places.isEmpty || !mounted) return;
      final p = places.first;
      final parts = [
        p.name,
        p.subLocality,
        p.locality,
        p.administrativeArea,
      ].whereType<String>().where((v) => v.trim().isNotEmpty).toSet().toList();
      if (parts.isEmpty) return;
      final address = parts.join(', ');
      setState(() {
        if (pickup) {
          _pickupController.text = address;
        } else {
          _destinationController.text = address;
        }
      });
    } catch (_) {
      // Coordinates remain usable even when reverse geocoding is unavailable.
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final position = await GeolocatorFallback.currentPosition();
      if (!mounted) return;
      setState(() {
        _pickupLat = position.$1;
        _pickupLng = position.$2;
        _pickupController.text =
            '${position.$1.toStringAsFixed(5)}, ${position.$2.toStringAsFixed(5)}';
      });
      await _resolveAddress(position.$1, position.$2, pickup: true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not get GPS location. Enable location permission and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<(double, double)> _geocode(String address) async {
    final matches = await locationFromAddress(address);
    if (matches.isEmpty) throw Exception('Address not found');
    return (matches.first.latitude, matches.first.longitude);
  }

  Future<void> _prepareQuote() async {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null || _serviceAreaId == null) {
      setState(() => _error = 'Vehicle category or service area is unavailable.');
      return;
    }
    if (_isScheduled && _scheduledAt == null) {
      setState(() => _error = 'Please select the scheduled date and time.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _quoteId = null;
      _fare = null;
    });
    try {
      final pickup = (_pickupLat != null && _pickupLng != null)
          ? (_pickupLat!, _pickupLng!)
          : await _geocode(_pickupController.text.trim());
      final destination = (_destinationLat != null && _destinationLng != null)
          ? (_destinationLat!, _destinationLng!)
          : await _geocode(_destinationController.text.trim());

      final response = await _supabase.functions.invoke(
        'create-fare-quote',
        body: {
          'service_area_id': _serviceAreaId,
          'vehicle_category_id': _category!.id,
          'booking_type': widget.bookingType,
          'pickup_latitude': pickup.$1,
          'pickup_longitude': pickup.$2,
          'destination_latitude': destination.$1,
          'destination_longitude': destination.$2,
        },
      );
      final data = _asMap(response.data);
      final quote = _asMap(data['quote'] ?? data['fare_quote'] ?? data['data']);
      final quoteId = _firstValue([data, quote], ['fare_quote_id', 'quote_id', 'id']);
      final fareValue = _firstValue([data, quote], ['total_fare', 'estimated_fare', 'fare']);
      if (quoteId == null) {
        throw Exception(_messageFrom(data) ?? 'Fare service did not return a quote ID.');
      }
      if (!mounted) return;
      setState(() {
        _pickupLat = pickup.$1;
        _pickupLng = pickup.$2;
        _destinationLat = destination.$1;
        _destinationLng = destination.$2;
        _quoteId = quoteId;
        _fare = num.tryParse(fareValue ?? '');
      });
    } on FunctionException catch (e) {
      if (mounted) setState(() => _error = _messageFrom(_asMap(e.details)) ??
          'Fare quote failed. Please verify the addresses and try again.');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmBooking() async {
    final quoteId = _quoteId;
    if (quoteId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final body = <String, dynamic>{
        'fare_quote_id': quoteId,
        'booking_type': widget.bookingType,
        'trip_type': 'ONE_WAY',
        'pickup_address': _pickupController.text.trim(),
        'pickup_latitude': _pickupLat,
        'pickup_longitude': _pickupLng,
        'destination_address': _destinationController.text.trim(),
        'destination_latitude': _destinationLat,
        'destination_longitude': _destinationLng,
        'passenger_count': _passengers,
        'customer_notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        if (_isScheduled) 'scheduled_at': _scheduledAt!.toUtc().toIso8601String(),
      };
      final response = await _supabase.functions.invoke(
        'create-booking',
        body: body,
      );
      final data = _asMap(response.data);
      final booking = _asMap(data['booking'] ?? data['data']);
      final bookingNumber =
          _firstValue([data, booking], ['booking_number', 'bookingNumber']) ??
              'created successfully';
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 42),
          title: const Text('Booking request submitted'),
          content: Text('Your ride was $bookingNumber. You can track its status in My Rides.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on FunctionException catch (e) {
      if (mounted) setState(() => _error = _messageFrom(_asMap(e.details)) ??
          'Booking could not be created. Your fare quote may have expired; request a new quote.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Booking could not be created. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String? _firstValue(List<Map<String, dynamic>> maps, List<String> keys) {
    for (final map in maps) {
      for (final key in keys) {
        final value = map[key];
        if (value != null && value.toString().trim().isNotEmpty) return value.toString();
      }
    }
    return null;
  }

  String? _messageFrom(Map<String, dynamic> map) =>
      _firstValue([map, _asMap(map['error'])], ['message', 'error', 'details']);

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now.add(const Duration(hours: 2)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt ?? now.add(const Duration(hours: 2))),
    );
    if (time == null || !mounted) return;
    final value = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (value.isBefore(DateTime.now().add(const Duration(minutes: 15)))) {
      setState(() => _error = 'Choose a time at least 15 minutes from now.');
      return;
    }
    setState(() {
      _scheduledAt = value;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: SafeArea(
        child: _loadingCategories
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text('Journey details', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<VehicleCategory>(
                      value: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle type',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.directions_car_outlined),
                      ),
                      items: _categories.map((category) => DropdownMenuItem(
                        value: category,
                        child: Text(category.name),
                      )).toList(),
                      onChanged: _busy ? null : (value) => setState(() {
                        _category = value;
                        _quoteId = null;
                      }),
                      validator: (value) => value == null ? 'Choose a vehicle type' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _pickupController,
                      decoration: InputDecoration(
                        labelText: 'Pickup address',
                        hintText: 'Enter pickup location in Nokha',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.my_location),
                        suffixIcon: IconButton(
                          tooltip: 'Use current location',
                          onPressed: _busy ? null : _useCurrentLocation,
                          icon: const Icon(Icons.gps_fixed),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? 'Enter a pickup address'
                          : null,
                      onChanged: (_) => setState(() {
                        _pickupLat = null;
                        _pickupLng = null;
                        _quoteId = null;
                      }),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _destinationController,
                      decoration: const InputDecoration(
                        labelText: 'Destination',
                        hintText: 'Enter destination address',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? 'Enter a destination address'
                          : null,
                      onChanged: (_) => setState(() {
                        _destinationLat = null;
                        _destinationLng = null;
                        _quoteId = null;
                      }),
                    ),
                    const SizedBox(height: 16),
                    if (_isScheduled)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.calendar_month_outlined),
                          title: const Text('Pickup date and time'),
                          subtitle: Text(_scheduledAt == null
                              ? 'Choose when you need the ride'
                              : MaterialLocalizations.of(context).formatFullDate(_scheduledAt!) +
                                  ' · ' + TimeOfDay.fromDateTime(_scheduledAt!).format(context)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _busy ? null : _pickSchedule,
                        ),
                      ),
                    Row(
                      children: [
                        const Expanded(child: Text('Passengers')),
                        IconButton(
                          onPressed: _busy || _passengers <= 1
                              ? null
                              : () => setState(() => _passengers--),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('$_passengers', style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          onPressed: _busy || _passengers >= (_category?.maxSeats ?? 12)
                              ? null
                              : () => setState(() => _passengers++),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    TextField(
                      controller: _notesController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes for driver (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ),
                    if (_quoteId != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Estimated fare', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Text(
                                _fare == null ? 'Quote received' : '₹${_fare!.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 4),
                              const Text('Final fare may change according to the confirmed trip details.'),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _busy
                            ? null
                            : _quoteId == null
                                ? _prepareQuote
                                : _confirmBooking,
                        child: _busy
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(_quoteId == null ? 'Get Fare Estimate' : 'Confirm Booking'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class GeolocatorFallback {
  static Future<(double, double)> currentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw Exception('GPS is disabled');
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied');
    }
    final position = await Geolocator.getCurrentPosition();
    return (position.latitude, position.longitude);
  }
}
