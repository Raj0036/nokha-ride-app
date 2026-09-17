import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/home_viewmodel.dart';
import '../models/vehicle_category.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HomeViewModel()..loadCategories(),
      child: const _HomePageContent(),
    );
  }
}

class _HomePageContent extends StatelessWidget {
  const _HomePageContent();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HomeViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nokha Ride'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: 'Notifications',
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'Profile',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: viewModel.refresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Where do you want to go?',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Book a verified vehicle for your journey.',
            ),
            const SizedBox(height: 24),

            _LocationCard(
              icon: Icons.my_location_rounded,
              title: 'Pickup location',
              subtitle: 'Choose your pickup point',
              onTap: () {},
            ),

            const SizedBox(height: 12),

            _LocationCard(
              icon: Icons.location_on_outlined,
              title: 'Destination',
              subtitle: 'Where are you going?',
              onTap: () {},
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    icon: Icons.local_taxi_rounded,
                    title: 'Ride Now',
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.calendar_month_rounded,
                    title: 'Schedule',
                    onTap: () {},
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            const Text(
              'Available vehicle types',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            if (viewModel.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (viewModel.errorMessage != null)
              _ErrorCard(
                message: viewModel.errorMessage!,
                onRetry: viewModel.loadCategories,
              )
            else if (viewModel.categories.isEmpty)
              const _EmptyCategoriesCard()
            else
              ...viewModel.categories.map(
                (category) => _VehicleCategoryCard(
                  category: category,
                ),
              ),

            const SizedBox(height: 28),

            const Text(
              'More services',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            _ServiceTile(
              icon: Icons.route_rounded,
              title: 'Outstation',
              subtitle: 'Plan an intercity journey',
              onTap: () {},
            ),

            _ServiceTile(
              icon: Icons.event_available_rounded,
              title: 'Event Booking',
              subtitle: 'Book multiple vehicles for an event',
              onTap: () {},
            ),
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
  final VoidCallback onTap;

  const _LocationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 20,
            horizontal: 12,
          ),
          child: Column(
            children: [
              Icon(icon, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleCategoryCard extends StatelessWidget {
  final VehicleCategory category;

  const _VehicleCategoryCard({
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final seats = category.maxSeats != null
        ? '${category.maxSeats} seats'
        : 'Passenger vehicle';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.directions_car_rounded),
        ),
        title: Text(category.name),
        subtitle: Text(
          category.description?.trim().isNotEmpty == true
              ? category.description!
              : seats,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {},
      ),
    );
  }
}

class _EmptyCategoriesCard extends StatelessWidget {
  const _EmptyCategoriesCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: const [
            Icon(
              Icons.directions_car_outlined,
              size: 42,
            ),
            SizedBox(height: 12),
            Text(
              'No vehicle categories are available yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Vehicle categories will appear here after they are configured by the Nokha Ride admin.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ServiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
}
