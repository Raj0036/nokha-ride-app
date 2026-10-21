import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Please sign in again to view notifications.');
      final response = await _supabase.from('notifications')
          .select('id, type, title, body, booking_id, is_read, created_at')
          .eq('user_id', user.id).order('created_at', ascending: false).limit(100);
      if (!mounted) return;
      setState(() => _items = (response as List).map((e) => Map<String, dynamic>.from(e)).toList());
    } catch (_) {
      if (mounted) setState(() => _error = 'Notifications could not be loaded. Pull down to retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    if (item['is_read'] == true) return;
    try {
      await _supabase.from('notifications').update({
        'is_read': true,
        'read_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', item['id'].toString());
      if (!mounted) return;
      setState(() {
        final index = _items.indexWhere((e) => e['id'] == item['id']);
        if (index >= 0) _items[index] = {..._items[index], 'is_read': true};
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not mark this notification as read.')));
    }
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '';
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} · ${TimeOfDay.fromDateTime(local).format(context)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications'), actions: [
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
                : _items.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 100),
                        Icon(Icons.notifications_none, size: 54),
                        SizedBox(height: 12),
                        Center(child: Text('You are all caught up')),
                        SizedBox(height: 6),
                        Center(child: Text('New ride updates will appear here.')),
                      ])
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final read = item['is_read'] == true;
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: read ? null : Theme.of(context).colorScheme.primaryContainer,
                                child: Icon(_iconFor(item['type']?.toString() ?? 'SYSTEM')),
                              ),
                              title: Text(item['title']?.toString() ?? 'Nokha Ride update', style: TextStyle(fontWeight: read ? FontWeight.normal : FontWeight.bold)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(item['body']?.toString() ?? ''),
                                  const SizedBox(height: 6),
                                  Text(_date(item['created_at']), style: Theme.of(context).textTheme.bodySmall),
                                ]),
                              ),
                              trailing: read ? null : const Icon(Icons.circle, size: 9, color: Colors.blue),
                              onTap: () => _markRead(item),
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  IconData _iconFor(String type) {
    if (type.contains('DRIVER')) return Icons.directions_car_outlined;
    if (type.contains('PAYMENT')) return Icons.payments_outlined;
    if (type.contains('CANCEL')) return Icons.cancel_outlined;
    if (type.contains('SUPPORT')) return Icons.support_agent_outlined;
    return Icons.notifications_active_outlined;
  }
}
