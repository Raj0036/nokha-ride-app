import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriverApplicationPage extends StatefulWidget {
  const DriverApplicationPage({super.key});

  @override
  State<DriverApplicationPage> createState() => _DriverApplicationPageState();
}

class _DriverApplicationPageState extends State<DriverApplicationPage> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _licenceNumber = TextEditingController();
  DateTime? _licenceExpiry;
  Map<String, dynamic>? _driver;
  List<Map<String, dynamic>> _documents = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _licenceNumber.dispose();
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
      final driver = await _supabase
          .from('drivers')
          .select('id, license_number, license_expiry, verification_status, online_status')
          .eq('profile_id', user.id)
          .maybeSingle();
      List<Map<String, dynamic>> documents = const [];
      if (driver != null) {
        final rows = await _supabase
            .from('driver_documents')
            .select('id, document_type, verification_status, expires_at, rejection_reason, created_at')
            .eq('driver_id', driver['id'])
            .order('created_at', ascending: false);
        documents = List<Map<String, dynamic>>.from(rows);
      }
      if (!mounted) return;
      setState(() {
        _driver = driver;
        _documents = documents;
        if (driver != null) {
          _licenceNumber.text = driver['license_number']?.toString() ?? '';
          _licenceExpiry = DateTime.tryParse(driver['license_expiry']?.toString() ?? '');
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Driver application status could not be loaded. Please retry.';
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_licenceExpiry == null) {
      setState(() => _error = 'Select your driving licence expiry date.');
      return;
    }
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
      await _supabase.from('drivers').insert({
        'profile_id': user.id,
        'license_number': _licenceNumber.text.trim().toUpperCase(),
        'license_expiry': _licenceExpiry!.toIso8601String().split('T').first,
        'verification_status': 'PENDING',
        'online_status': false,
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver application submitted. Upload the licence document for verification.')),
        );
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() => _error = error.code == '23505'
            ? 'A driver application already exists for this account. Refresh its status.'
            : error.message);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Driver application could not be submitted. Please retry.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uploadLicence() async {
    final driver = _driver;
    final user = _supabase.auth.currentUser;
    if (driver == null || user == null) return;

    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (file == null || !mounted) return;
    final fileLength = await file.length();
    if (fileLength == null || fileLength > 10 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a readable PDF or image of 10 MB or smaller.')),
      );
      return;
    }
    final fileBytes = await file.readAsBytes();
    if (!mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    String? uploadedPath;
    try {
      final extension = (file.extension ?? 'bin').toLowerCase();
      final contentType = switch (extension) {
        'pdf' => 'application/pdf',
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        _ => 'application/octet-stream',
      };
      uploadedPath = '${user.id}/${driver['id']}/DL-${DateTime.now().millisecondsSinceEpoch}.$extension';
      await _supabase.storage.from('driver-documents').uploadBinary(
        uploadedPath,
        fileBytes,
        fileOptions: FileOptions(contentType: contentType, upsert: false),
      );
      await _supabase.from('driver_documents').insert({
        'driver_id': driver['id'],
        'document_type': 'DL',
        'document_number': driver['license_number'],
        'storage_path': uploadedPath,
        'expires_at': driver['license_expiry'],
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driving licence uploaded for admin verification.')),
        );
      }
    } catch (error) {
      if (uploadedPath != null) {
        try {
          await _supabase.storage.from('driver-documents').remove([uploadedPath]);
        } catch (_) {
          // Preserve the primary upload error.
        }
      }
      if (mounted) {
        setState(() => _error = error is PostgrestException
            ? error.message
            : 'Driving licence upload failed. Check your connection and permissions.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _licenceExpiry ?? now.add(const Duration(days: 365)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 30),
    );
    if (picked != null && mounted) {
      setState(() {
        _licenceExpiry = picked;
        _error = null;
      });
    }
  }

  Future<void> _reloadAccess() async {
    await _supabase.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Date unavailable';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final status = _driver?['verification_status']?.toString().toUpperCase();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver onboarding'),
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
                const Icon(Icons.badge_outlined, size: 52),
                const SizedBox(height: 12),
                Text(
                  'Apply to drive with Nokha Ride',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your details and licence document must be verified by an administrator. This application does not grant Driver permissions by itself.',
                  textAlign: TextAlign.center,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 20),
                if (_driver == null) ...[
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _licenceNumber,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Driving licence number',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value == null || value.trim().length < 5
                              ? 'Enter your driving licence number'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: _pickExpiry,
                          icon: const Icon(Icons.calendar_month),
                          label: Text(_licenceExpiry == null
                              ? 'Select licence expiry date'
                              : 'Licence expires ${_date(_licenceExpiry!.toIso8601String())}'),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _saving ? null : _submit,
                          icon: _saving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.send_outlined),
                          label: Text(_saving ? 'Submitting…' : 'Submit driver application'),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.pending_actions_outlined),
                      title: Text('Verification: ${status ?? 'UNKNOWN'}'),
                      subtitle: Text('Licence: ${_driver!['license_number']}\nExpiry: ${_date(_driver!['license_expiry'])}'),
                      isThreeLine: true,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _uploadLicence,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Upload / replace driving licence scan'),
                  ),
                  const SizedBox(height: 12),
                  Text('Documents', style: Theme.of(context).textTheme.titleLarge),
                  if (_documents.isEmpty)
                    const Card(child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No licence document uploaded yet. Upload a clear PDF or image so the admin can verify your application.'),
                    )),
                  ..._documents.map((document) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(document['document_type'].toString()),
                      subtitle: Text('Status: ${document['verification_status']} • Expires: ${_date(document['expires_at'])}${document['rejection_reason'] == null ? '' : '\nReason: ${document['rejection_reason']}'}'),
                    ),
                  )),
                  if (status == 'APPROVED') ...[
                    const SizedBox(height: 12),
                    const Text('Your driver profile is approved. If Driver workspace is not available yet, ask the admin to enable the DRIVER role, then sign in again.'),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _reloadAccess,
                      icon: const Icon(Icons.login),
                      label: const Text('Reload access'),
                    ),
                  ],
                ],
              ],
            ),
    );
  }
}
