import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/views/profile_page.dart';
import '../../location/viewmodels/location_viewmodel.dart';
import '../models/vehicle_category.dart';
import '../viewmodels/home_viewmodel.dart';
import 'booking_page.dart';
import 'my_rides_page.dart';
import 'notifications_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeViewModel()..loadCategories()),
        ChangeNotifierProvider(create: (_) => LocationViewModel()),
      ],
      child: const _HomePageContent(),
    );
  }
}

class _HomePageContent extends StatelessWidget {
  const _HomePageContent();

  Future<void> _getPickupLocation(BuildContext context, LocationViewModel vm) async {
    final success = await vm.getCurrentLocation();
    if (!context.mounted) return;
    final message = success
        ? 'Current location detected successfully.'
        : vm.errorMessage ?? 'Unable to get your location.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openBooking(
    BuildContext context, {
    String bookingType = 'RIDE_NOW',
    VehicleCategory? category,
  }) async {
    final location = context.read<LocationViewModel>().currentLocation;
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BookingPage(
          bookingType: bookingType,
          initialCategory: category,
          initialPickup: location,
        ),
      ),
    );
    if (!context.mounted) return;
    if (created == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking submitted. Check My Rides for updates.')),
      );
    }
  }

  Future<void> _openPage(BuildContext context, Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HomeViewModel>();
    final locationViewModel = context.watch<LocationViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nokha Ride'),
        actions: [
          IconButton(
            onPressed: () => _openPage(context, const MyRidesPage()),
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'My Rides',
          ),
          IconButton(
            onPressed: () => _openPage(context, const NotificationsPage()),
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: 'Notifications',
          ),
          IconButton(
            onPressed: () => _openPage(context, const ProfilePage()),
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'Profile',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: viewModel.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Where do you want to go?', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Book a verified vehicle for your journey.'),
            const SizedBox(height: 24),
            _LocationCard(
              icon: Icons.my_location_rounded,
              title: 'Pickup location',
              subtitle: locationViewModel.isLoading
                  ? 'Getting your current location...'
                  : locationViewModel.hasLocation
                      ? 'Current location detected'
                      : 'Tap to use your current GPS location',
              onTap: locationViewModel.isLoading
                  ? null
                  : () => _getPickupLocation(context, locationViewModel),
            ),
            const SizedBox(height: 12),
            _LocationCard(
              icon: Icons.location_on_outlined,
              title: 'Destination',
              subtitle: 'Tap to enter your destination and book',
              onTap: () => _openBooking(context),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _ActionCard(
                  icon: Icons.local_taxi_rounded,
                  title: 'Ride Now',
                  onTap: () => _openBooking(context),
                )),
                const SizedBox(width: 12),
                Expanded(child: _ActionCard(
                  icon: Icons.calendar_month_rounded,
                  title: 'Schedule',
                  onTap: () => _openBooking(context, bookingType: 'SCHEDULED'),
                )),
              ],
            ),
            const SizedBox(height: 28),
            const Text('Available vehicle types', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (viewModel.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (viewModel.errorMessage != null)
              _ErrorCard(message: viewModel.errorMessage!, onRetry: viewModel.loadCategories)
            else if (viewModel.categories.isEmpty)
              const _EmptyCategoriesCard()
            else
              ...viewModel.categories.map((category) => _VehicleCategoryCard(
                category: category,
                onTap: () => _openBooking(context, category: category),
              )),
            const SizedBox(height: 28),
            const Text('More services', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _ServiceTile(
              icon: Icons.route_rounded,
              title: 'Outstation',
              subtitle: 'Plan an intercity journey',
              onTap: () => _openBooking(context, bookingType: 'OUTSTATION'),
            ),
            _ServiceTile(
              icon: Icons.event_available_rounded,
              title: 'Event Booking',
              subtitle: 'Request a vehicle for an event',
              onTap: () => _openBooking(context, bookingType: 'EVENT'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _LocationCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
    ),
  );
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Column(children: [
          Icon(icon, size: 32),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      ),
    ),
  );
}

class _VehicleCategoryCard extends StatelessWidget {
  final VehicleCategory category;
  final VoidCallback onTap;
  const _VehicleCategoryCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final seats = category.maxSeats != null ? '${category.maxSeats} seats' : 'Passenger vehicle';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.directions_car_rounded)),
        title: Text(category.name),
        subtitle: Text(category.description?.trim().isNotEmpty == true ? category.description! : seats),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _EmptyCategoriesCard extends StatelessWidget {
  const _EmptyCategoriesCard();
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: const [
        Icon(Icons.directions_car_outlined, size: 42),
        SizedBox(height: 12),
        Text('No vehicle categories are available yet.', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600)),
        SizedBox(height: 6),
        Text('Vehicle categories will appear here after they are configured by the Nokha Ride admin.', textAlign: TextAlign.center),
      ]),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const Icon(Icons.error_outline_rounded, size: 42),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
      ]),
    ),
  );
}

class _ServiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ServiceTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      onTap: onTap,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
    ),
  );
}
