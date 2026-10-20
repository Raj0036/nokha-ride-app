import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyRidesPage extends StatefulWidget {
  const MyRidesPage({super.key});

  @override
  State<MyRidesPage> createState() => _MyRidesPageState();
}

class _MyRidesPageState extends State<MyRidesPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _rides = const [];
  bool _loading = true;
  String? _error;
  String? _cancellingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Please sign in again.');
      final rows = await _supabase.from('bookings').select(
        'id, booking_number, booking_type, booking_status, pickup_address, destination_address, quoted_fare, final_fare, scheduled_at, created_at, passenger_count, payment_status'
      ).eq('customer_id', user.id).order('created_at', ascending: false).limit(100);
      if (!mounted) return;
      setState(() => _rides = (rows as List).map((e) => Map<String, dynamic>.from(e)).toList());
    } catch (_) {
      if (mounted) setState(() => _error = 'Your rides could not be loaded. Please check your connection and retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel(Map<String, dynamic> ride) async {
    final status = ride['booking_status']?.toString() ?? '';
    if (!['REQUESTED', 'SEARCHING'].contains(status)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This ride can no longer be cancelled from the app.')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel ride?'),
        content: const Text('Do you want to cancel this booking request?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep ride')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel ride')),
        ],
      ),
    );
    if (ok != true) return;
    final id = ride['id'].toString();
    setState(() => _cancellingId = id);
    try {
      await _supabase.functions.invoke('cancel-booking', body: {
        'booking_id': id,
        'reason': 'Cancelled by customer',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cancellation request submitted.')));
      await _load();
    } on FunctionException catch (e) {
      if (mounted) {
        final details = e.details;
        final message = details is Map ? details['message']?.toString() : null;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message ?? 'Could not cancel this ride. Please try again.')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not cancel this ride. Please try again.')));
    } finally {
      if (mounted) setState(() => _cancellingId = null);
    }
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Date unavailable';
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} · ${TimeOfDay.fromDateTime(local).format(context)}';
  }

  String _title(String type) {
    switch (type) {
      case 'SCHEDULED': return 'Scheduled ride';
      case 'OUTSTATION': return 'Outstation ride';
      case 'EVENT': return 'Event booking';
      default: return 'Ride now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Rides'), actions: [
        IconButton(onPressed: _loading ? null : _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
      ]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(children: [SizedBox(height: 300, child: Center(child: CircularProgressIndicator()))])
            : _error != null
                ? ListView(children: [
                    const SizedBox(height: 100),
                    Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))),
                    Center(child: FilledButton(onPressed: _load, child: const Text('Retry'))),
                  ])
                : _rides.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 110),
                        Icon(Icons.directions_car_outlined, size: 58),
                        SizedBox(height: 12),
                        Center(child: Text('No rides yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                        SizedBox(height: 6),
                        Center(child: Text('Your booking history will appear here.')),
                      ])
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        itemCount: _rides.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final ride = _rides[index];
                          final status = ride['booking_status']?.toString() ?? 'UNKNOWN';
                          final id = ride['id'].toString();
                          final fare = ride['final_fare'] ?? ride['quoted_fare'];
                          final fareAmount = num.tryParse(fare?.toString() ?? '');
                          final canCancel = ['REQUESTED', 'SEARCHING'].contains(status);
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(child: Text(_title(ride['booking_type']?.toString() ?? ''), style: Theme.of(context).textTheme.titleMedium)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(20)),
                                    child: Text(status.replaceAll('_', ' '), style: Theme.of(context).textTheme.labelSmall),
                                  ),
                                ]),
                                const SizedBox(height: 5),
                                Text(ride['booking_number']?.toString() ?? 'Booking reference pending'),
                                Text(_date(ride['scheduled_at'] ?? ride['created_at']), style: Theme.of(context).textTheme.bodySmall),
                                const Divider(height: 22),
                                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Icon(Icons.trip_origin, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(ride['pickup_address']?.toString() ?? 'Pickup address unavailable')),
                                ]),
                                const SizedBox(height: 10),
                                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Icon(Icons.location_on_outlined, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(ride['destination_address']?.toString() ?? 'Destination unavailable')),
                                ]),
                                const SizedBox(height: 10),
                                Row(children: [
                                  const Icon(Icons.people_outline, size: 18),
                                  const SizedBox(width: 6),
                                  Text("${ride['passenger_count'] ?? 1} passenger(s)"),
                                  const Spacer(),
                                  Text(fareAmount == null ? 'Fare pending' : '₹${fareAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ]),
                                if (canCancel) ...[
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: _cancellingId == id ? null : () => _cancel(ride),
                                      icon: _cancellingId == id
                                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                          : const Icon(Icons.cancel_outlined),
                                      label: const Text('Cancel request'),
                                    ),
                                  ),
                                ],
                              ]),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
