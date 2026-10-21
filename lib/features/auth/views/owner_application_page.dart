import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OwnerApplicationPage extends StatefulWidget {
  const OwnerApplicationPage({super.key});

  @override
  State<OwnerApplicationPage> createState() => _OwnerApplicationPageState();
}

class _OwnerApplicationPageState extends State<OwnerApplicationPage> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  Map<String, dynamic>? _application;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = _supabase.auth.currentUser;
    _name.text = user?.userMetadata?['full_name']?.toString() ?? '';
    _phone.text = user?.phone?.replaceFirst(RegExp(r'^\+91'), '') ?? '';
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw StateError('Please sign in again.');
      final row = await _supabase
          .from('owner_applications')
          .select('id, full_name, phone, address, status, rejection_reason, created_at, reviewed_at')
          .eq('user_id', user.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _application = row;
        if (row != null) {
          _name.text = row['full_name']?.toString() ?? _name.text;
          _phone.text = row['phone']?.toString() ?? _phone.text;
          _address.text = row['address']?.toString() ?? _address.text;
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Owner application status could not be loaded. Please retry.';
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _error = 'Your session expired. Please sign in again.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _supabase.from('owner_applications').insert({
        'user_id': user.id,
        'full_name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'status': 'PENDING',
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Owner application submitted for admin review.')),
        );
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() => _error = error.code == '23505'
            ? 'An owner application already exists for this account. Refresh its status below.'
            : error.message);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Application could not be submitted. Check your connection and retry.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reloadOwnerAccess() async {
    await _supabase.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Date unavailable';
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final status = _application?['status']?.toString().toUpperCase();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Become a vehicle owner'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh status',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Icon(Icons.directions_car_filled_outlined, size: 52),
                const SizedBox(height: 12),
                Text(
                  'Owner onboarding',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Submit your details for admin review. Owner access is granted only after an administrator approves your application.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (_error != null) ...[
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  const SizedBox(height: 12),
                ],
                if (_application != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.assignment_turned_in_outlined),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Application status: ${status ?? 'UNKNOWN'}',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Submitted: ${_date(_application!['created_at'])}'),
                          if (status == 'PENDING')
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text('Your application is waiting for admin review. You do not need to submit it again.'),
                            ),
                          if (status == 'REJECTED' && _application!['rejection_reason'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('Reason: ${_application!['rejection_reason']}'),
                            ),
                          if (status == 'APPROVED') ...[
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text('Your owner role has been approved. Sign in again to load your Owner workspace. Vehicle and KYC verification may still be required before rides can be dispatched.'),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _reloadOwnerAccess,
                              icon: const Icon(Icons.login),
                              label: const Text('Reload Owner access'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value == null || value.trim().length < 2
                              ? 'Enter your full name'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          decoration: const InputDecoration(
                            labelText: '10-digit mobile number',
                            prefixText: '+91 ',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value == null || !RegExp(r'^[6-9][0-9]{9}$').hasMatch(value.trim())
                              ? 'Enter a valid Indian mobile number'
                              : null,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _address,
                          minLines: 2,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Full address',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value == null || value.trim().length < 8
                              ? 'Enter your full address'
                              : null,
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _submit,
                            icon: _saving
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.send_outlined),
                            label: Text(_saving ? 'Submitting…' : 'Submit owner application'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
