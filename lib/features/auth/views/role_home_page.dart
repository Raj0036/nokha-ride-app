import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../home/views/home_page.dart';

/// Resolves the authenticated user's server-assigned roles. This widget never
/// creates roles or treats a client-selected role as authorization.
class RoleHomePage extends StatefulWidget {
  const RoleHomePage({super.key});

  @override
  State<RoleHomePage> createState() => _RoleHomePageState();
}

class _RoleHomePageState extends State<RoleHomePage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<String> _roles = const [];
  bool _ownerApproved = false;
  bool _driverApproved = false;

  @override
  void initState() {
    super.initState();
    _loadAccess();
  }

  Future<void> _loadAccess() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw StateError('Your session has expired. Please sign in again.');
      }
      final rows = await _supabase
          .from('user_roles')
          .select('role')
          .eq('user_id', user.id);
      final roles = rows
          .map<String>((row) => row['role'].toString().toUpperCase())
          .toSet()
          .toList()
        ..sort();

      var ownerApproved = false;
      var driverApproved = false;
      if (roles.contains('OWNER')) {
        final vehicle = await _supabase
            .from('vehicles')
            .select('id, vehicle_categories!inner(is_bike, is_passenger_vehicle, is_active)')
            .eq('owner_id', user.id)
            .eq('verification_status', 'APPROVED')
            .eq('is_active', true)
            .eq('vehicle_categories.is_bike', false)
            .eq('vehicle_categories.is_passenger_vehicle', true)
            .eq('vehicle_categories.is_active', true)
            .limit(1);
        ownerApproved = vehicle.isNotEmpty;
      }
      if (roles.contains('DRIVER')) {
        final driver = await _supabase
            .from('drivers')
            .select('id')
            .eq('profile_id', user.id)
            .eq('verification_status', 'APPROVED')
            .maybeSingle();
        driverApproved = driver != null;
      }

      if (!mounted) return;
      setState(() {
        _roles = roles;
        _ownerApproved = ownerApproved;
        _driverApproved = driverApproved;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not verify your account permissions. Please retry.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return _message(
        icon: Icons.cloud_off_outlined,
        title: 'Access check failed',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _loadAccess,
      );
    }

    // A normal customer never sees a role picker and cannot self-promote.
    if (_roles.length == 1 && _roles.single == 'CUSTOMER') {
      return const HomePage();
    }

    // Customer cannot switch into another role. Multiple roles are only
    // selectable when OWNER and DRIVER are both approved by the server.
    if (_roles.contains('CUSTOMER')) {
      return _message(
        icon: Icons.shield_outlined,
        title: 'Account role needs review',
        message:
            'Your account has more than one assigned role. For your security, role switching is disabled. Please contact support or an administrator.',
        actionLabel: 'Refresh access',
        onAction: _loadAccess,
      );
    }

    final hasOwner = _roles.contains('OWNER');
    final hasDriver = _roles.contains('DRIVER');
    if (hasOwner && hasDriver) {
      if (_ownerApproved && _driverApproved) {
        return _message(
          icon: Icons.verified_user_outlined,
          title: 'Choose your workspace',
          message:
              'Both Owner and Driver access are approved. Select the workspace you want to open.',
          actionLabel: 'Owner workspace',
          onAction: () => _openWorkspace('OWNER'),
          secondaryLabel: 'Driver workspace',
          onSecondary: () => _openWorkspace('DRIVER'),
        );
      }
      return _message(
        icon: Icons.pending_actions_outlined,
        title: 'Approval pending',
        message:
            'Owner and Driver workspace switching is available only after both roles are approved. Owner approved: ${_ownerApproved ? 'Yes' : 'No'}. Driver approved: ${_driverApproved ? 'Yes' : 'No'}.',
        actionLabel: 'Refresh status',
        onAction: _loadAccess,
      );
    }

    if (hasOwner) {
      return const OwnerWorkspacePage();
    }
    if (hasDriver) {
      return const DriverWorkspacePage();
    }

    return _message(
      icon: Icons.lock_outline,
      title: 'No app role assigned',
      message:
          'Your account is authenticated, but no supported app role is assigned. For security, the app will not assign a role automatically. Contact an administrator.',
      actionLabel: 'Refresh access',
      onAction: _loadAccess,
    );
  }

  void _openWorkspace(String role) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => role == 'OWNER'
            ? const OwnerWorkspacePage()
            : const DriverWorkspacePage(),
      ),
    );
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nokha Ride'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => _supabase.auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 58),
                const SizedBox(height: 16),
                Text(title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onAction,
                    child: Text(actionLabel),
                  ),
                ),
                if (secondaryLabel != null && onSecondary != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onSecondary,
                      child: Text(secondaryLabel),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OwnerWorkspacePage extends StatefulWidget {
  const OwnerWorkspacePage({super.key});

  @override
  State<OwnerWorkspacePage> createState() => _OwnerWorkspacePageState();
}

class _OwnerWorkspacePageState extends State<OwnerWorkspacePage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _vehicles = const [];
  List<Map<String, dynamic>> _categories = const [];
  List<Map<String, dynamic>> _models = const [];
  List<Map<String, dynamic>> _requiredDocuments = const [];
  bool _loading = true;
  bool _saving = false;
  bool _approved = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = _supabase.auth.currentUser!;
      final results = await Future.wait<dynamic>([
        _supabase
            .from('vehicles')
            .select('id, category_id, registration_number, brand, model, verification_status, availability_status, is_active, vehicle_categories(name, is_bike, is_passenger_vehicle, is_active)')
            .eq('owner_id', user.id)
            .order('created_at', ascending: false),
        _supabase.functions.invoke('owner-vehicle-catalog'),
      ]);
      final vehicles = List<Map<String, dynamic>>.from(results[0] as List);
      final catalogResponse = results[1];
      final catalog = catalogResponse.data;
      if (catalog is! Map ||
          catalog['categories'] is! List ||
          catalog['models'] is! List ||
          catalog['required_documents'] is! List) {
        throw StateError('Owner vehicle catalog response is invalid.');
      }
      final categories = List<Map<String, dynamic>>.from(catalog['categories'] as List);
      final models = List<Map<String, dynamic>>.from(catalog['models'] as List);
      final requiredDocuments =
          List<Map<String, dynamic>>.from(catalog['required_documents'] as List);
      final ownerApproved = vehicles.any((vehicle) {
        final category = vehicle['vehicle_categories'];
        return vehicle['verification_status']?.toString().toUpperCase() == 'APPROVED' &&
            vehicle['is_active'] == true &&
            category is Map &&
            category['is_bike'] == false &&
            category['is_passenger_vehicle'] == true &&
            category['is_active'] == true;
      });
      if (!mounted) return;
      setState(() {
        _vehicles = vehicles;
        _categories = categories;
        _models = models;
        _requiredDocuments = requiredDocuments;
        _approved = ownerApproved;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Vehicle data could not be loaded. Check connection and access.';
        _loading = false;
      });
    }
  }

  Future<void> _registerVehicle() async {
    final formKey = GlobalKey<FormState>();
    final registration = TextEditingController();
    final year = TextEditingController();
    String? categoryId = _models.isEmpty
        ? null
        : _models.first['vehicle_category_id'].toString();
    String? modelId = _models.isEmpty ? null : _models.first['id'].toString();
    final firstModel = _models.isEmpty
        ? null
        : _models.firstWhere((m) => m['id'].toString() == modelId);
    final seats = TextEditingController(text: (firstModel?['default_seats'] ?? 4).toString());
    String fuel = 'Petrol';
    bool ac = firstModel?['default_ac'] == true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Register a vehicle'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: categoryId,
                      items: _categories
                          .where((category) => _models.any((m) =>
                              m['vehicle_category_id'].toString() == category['id'].toString()))
                          .map((c) => DropdownMenuItem<String>(
                                value: c['id'].toString(),
                                child: Text(c['name'].toString()),
                              ))
                          .toList(),
                      onChanged: (v) => setDialogState(() {
                        categoryId = v;
                        final options = _models.where((m) =>
                            m['vehicle_category_id'].toString() == v).toList();
                        modelId = options.isEmpty ? null : options.first['id'].toString();
                        if (options.isNotEmpty) {
                          seats.text = (options.first['default_seats'] ?? 4).toString();
                          ac = options.first['default_ac'] == true;
                        }
                      }),
                      decoration: const InputDecoration(labelText: 'Vehicle category'),
                      validator: (v) => v == null ? 'Choose a category' : null,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: ValueKey('vehicle-model-$categoryId'),
                      initialValue: modelId,
                      isExpanded: true,
                      items: _models
                          .where((m) => m['vehicle_category_id'].toString() == categoryId)
                          .map((m) => DropdownMenuItem<String>(
                                value: m['id'].toString(),
                                child: Text('${m['brand']} ${m['model_name']}${m['variant'] == null ? '' : ' ${m['variant']}'}'),
                              ))
                          .toList(),
                      onChanged: (v) => setDialogState(() {
                        modelId = v;
                        final matches = _models.where((m) => m['id'].toString() == v);
                        if (matches.isNotEmpty) {
                          seats.text = (matches.first['default_seats'] ?? 4).toString();
                          ac = matches.first['default_ac'] == true;
                        }
                      }),
                      decoration: const InputDecoration(labelText: 'Vehicle make and model'),
                      validator: (v) => v == null ? 'Choose a vehicle model' : null,
                    ),
                    TextFormField(
                      controller: registration,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Registration number'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: year,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Manufacturing year'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final n = int.tryParse(v);
                        final maxYear = DateTime.now().year + 1;
                        return n == null || n < 1900 || n > maxYear ? 'Enter a valid year' : null;
                      },
                    ),
                    TextFormField(
                      controller: seats,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Seat capacity'),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        return n == null || n < 1 ? 'Enter valid seats' : null;
                      },
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: fuel,
                      items: const ['Petrol', 'Diesel', 'CNG', 'Electric', 'Hybrid', 'Other']
                          .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                      onChanged: (v) => setDialogState(() => fuel = v ?? 'Petrol'),
                      decoration: const InputDecoration(labelText: 'Fuel type'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: ac,
                      onChanged: (v) => setDialogState(() => ac = v),
                      title: const Text('Air conditioning'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(dialogContext, true);
              },
              child: const Text('Submit for review'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || categoryId == null || modelId == null) {
      registration.dispose();
      year.dispose();
      seats.dispose();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final user = _supabase.auth.currentUser!;
      final selectedModel = _models.firstWhere((m) => m['id'].toString() == modelId);
      if (selectedModel['vehicle_category_id'].toString() != categoryId) {
        throw StateError('Selected model does not match the vehicle category.');
      }
      await _supabase.from('vehicles').insert({
        'owner_id': user.id,
        'category_id': categoryId,
        'vehicle_model_id': modelId,
        'registration_number': registration.text.trim().toUpperCase(),
        'manufacturing_year': year.text.trim().isEmpty ? null : int.parse(year.text.trim()),
        'seat_capacity': int.parse(seats.text.trim()),
        'fuel_type': fuel,
        'ac_available': ac,
        'verification_status': 'PENDING',
        'availability_status': 'UNAVAILABLE',
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle submitted for admin verification.')),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Vehicle could not be submitted. Check the registration number, selected model, and permissions.');
    } finally {
      registration.dispose();
      year.dispose();
      seats.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }


  Future<void> _uploadVehicleDocument(Map<String, dynamic> vehicle) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final vehicleId = vehicle['id'].toString();
    final categoryId = vehicle['category_id']?.toString();
    final requiredForVehicle = _requiredDocuments
        .where((item) => item['vehicle_category_id'].toString() == categoryId)
        .toList();
    if (requiredForVehicle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Required document rules are not configured for this vehicle category.')),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final numberController = TextEditingController();
    final documentTypes = requiredForVehicle
        .map((item) => item['document_type'].toString())
        .toSet()
        .toList();
    String? selectedType = documentTypes.first;
    PlatformFile? selectedFile;
    List<int>? selectedFileBytes;
    DateTime? expiresAt;
    String? formError;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedRequirement = requiredForVehicle.firstWhere(
            (item) => item['document_type'].toString() == selectedType,
          );
          final expiryRequired = selectedRequirement['expiry_required'] == true;
          return AlertDialog(
            title: const Text('Upload vehicle document'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        items: documentTypes.map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.replaceAll('_', ' ')),
                        )).toList(),
                        onChanged: (value) => setDialogState(() {
                          selectedType = value;
                          formError = null;
                        }),
                        decoration: const InputDecoration(labelText: 'Document type'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final file = await FilePicker.pickFile(
                            type: FileType.custom,
                            allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
                          );
                          if (file == null) return;
                          final fileLength = await file.length();
                          if (fileLength == null || fileLength > 10 * 1024 * 1024) {
                            setDialogState(() => formError = 'File must be readable and 10 MB or smaller.');
                            return;
                          }
                          final bytes = await file.readAsBytes();
                          setDialogState(() {
                            selectedFile = file;
                            selectedFileBytes = bytes;
                            formError = null;
                          });
                        },
                        icon: const Icon(Icons.attach_file),
                        label: Text(selectedFile?.name ?? 'Choose PDF or image (max 10 MB)'),
                      ),
                      TextFormField(
                        controller: numberController,
                        decoration: const InputDecoration(labelText: 'Document number (optional)'),
                      ),
                      if (expiryRequired) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: expiresAt ?? now.add(const Duration(days: 365)),
                              firstDate: DateTime(now.year, now.month, now.day),
                              lastDate: DateTime(now.year + 25),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                expiresAt = picked;
                                formError = null;
                              });
                            }
                          },
                          icon: const Icon(Icons.calendar_month),
                          label: Text(expiresAt == null
                              ? 'Select expiry date'
                              : 'Expires ${expiresAt!.day.toString().padLeft(2, '0')}/${expiresAt!.month.toString().padLeft(2, '0')}/${expiresAt!.year}'),
                        ),
                      ],
                      if (formError != null) ...[
                        const SizedBox(height: 8),
                        Text(formError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ],
                      const SizedBox(height: 8),
                      const Text('Documents are private and will remain pending until an administrator verifies them.'),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  if (selectedFile == null) {
                    setDialogState(() => formError = 'Choose a file before submitting.');
                    return;
                  }
                  if (expiryRequired && expiresAt == null) {
                    setDialogState(() => formError = 'Select the document expiry date.');
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Upload document'),
              ),
            ],
          );
        },
      ),
    );

    if (submitted != true || selectedFile == null || selectedFileBytes == null || selectedType == null) {
      numberController.dispose();
      return;
    }

    String? uploadedPath;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final file = selectedFile!;
      final extension = (file.extension ?? 'bin').toLowerCase();
      final contentType = switch (extension) {
        'pdf' => 'application/pdf',
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        _ => 'application/octet-stream',
      };
      uploadedPath = '${user.id}/$vehicleId/${selectedType!.toLowerCase()}-${DateTime.now().millisecondsSinceEpoch}.$extension';
      await _supabase.storage.from('vehicle-documents').uploadBinary(
        uploadedPath!,
        selectedFileBytes!,
        fileOptions: FileOptions(contentType: contentType, upsert: false),
      );
      await _supabase.from('vehicle_documents').insert({
        'vehicle_id': vehicleId,
        'document_type': selectedType,
        'document_number': numberController.text.trim().isEmpty ? null : numberController.text.trim(),
        'storage_path': uploadedPath,
        'expires_at': expiresAt?.toIso8601String().split('T').first,
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded for admin verification.')),
        );
      }
    } catch (error) {
      if (uploadedPath != null) {
        try {
          await _supabase.storage.from('vehicle-documents').remove([uploadedPath]);
        } catch (_) {
          // Keep the original error visible; the orphaned object can be cleaned up by admin.
        }
      }
      if (mounted) {
        setState(() => _error = error is PostgrestException
            ? error.message
            : 'Document upload failed. Check your connection and permissions.');
      }
    } finally {
      numberController.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Owner workspace'),
      actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
        IconButton(onPressed: () => _supabase.auth.signOut(), icon: const Icon(Icons.logout), tooltip: 'Sign out'),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _saving || _categories.isEmpty || _models.isEmpty ? null : _registerVehicle,
      icon: const Icon(Icons.add),
      label: const Text('Add vehicle'),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!_approved)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.pending_actions_outlined),
                    title: Text('Owner verification pending'),
                    subtitle: Text('You can submit vehicles for review. A vehicle becomes eligible for rides only after admin approval.'),
                  ),
                ),
              if (_error != null) Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
              Text('Your vehicles', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (_vehicles.isEmpty)
                const Card(child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No vehicles registered yet. Add your first vehicle for admin verification.'),
                )),
              ..._vehicles.map((v) => Card(
                child: ListTile(
                  leading: const Icon(Icons.directions_car_outlined),
                  title: Text('${v['brand'] ?? ''} ${v['model'] ?? ''}'.trim().isEmpty ? v['registration_number'].toString() : '${v['brand'] ?? ''} ${v['model'] ?? ''}'),
                  subtitle: Text('${v['registration_number']} • ${(v['vehicle_categories'] as Map?)?['name'] ?? 'Vehicle'}\nVerification: ${v['verification_status']} • Availability: ${v['availability_status']}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'Upload required documents',
                    onPressed: _saving ? null : () => _uploadVehicleDocument(v),
                    icon: const Icon(Icons.upload_file_outlined),
                  ),
                ),
              )),
            ],
          ),
  );
}

class DriverWorkspacePage extends StatefulWidget {
  const DriverWorkspacePage({super.key});

  @override
  State<DriverWorkspacePage> createState() => _DriverWorkspacePageState();
}

class _DriverWorkspacePageState extends State<DriverWorkspacePage> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _driver;
  List<Map<String, dynamic>> _assignedRides = const [];
  bool _online = false;
  bool _approved = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = _supabase.auth.currentUser!;
      final row = await _supabase
          .from('drivers')
          .select('id, license_number, license_expiry, verification_status, online_status, rating_average, completed_rides')
          .eq('profile_id', user.id)
          .maybeSingle();
      final expiryDate = DateTime.tryParse(row?['license_expiry']?.toString() ?? '');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final normalizedExpiry = expiryDate == null
          ? null
          : DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
      final isApproved =
          row?['verification_status']?.toString().toUpperCase() == 'APPROVED' &&
          normalizedExpiry != null &&
          !normalizedExpiry.isBefore(today);
      final rides = isApproved
          ? await _supabase
              .from('bookings')
              .select('id, booking_number, booking_status, pickup_address, destination_address, scheduled_at, quoted_fare, passenger_count, booking_type, created_at')
              .eq('driver_id', row!['id'])
              .order('created_at', ascending: false)
          : <dynamic>[];
      if (!mounted) return;
      setState(() {
        _driver = row;
        _approved = isApproved;
        _online = row?['online_status'] == true;
        _assignedRides = List<Map<String, dynamic>>.from(rides);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Driver profile could not be loaded.';
        _loading = false;
      });
    }
  }

  Future<void> _setOnline(bool value) async {
    final driver = _driver;
    final user = _supabase.auth.currentUser;
    if (driver == null ||
        user == null ||
        !_approved ||
        driver['verification_status']?.toString().toUpperCase() != 'APPROVED') {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // The database intentionally blocks direct online_status writes.
      // Use the trusted RPC so licence, approval, assigned vehicle, and
      // active-ride constraints remain enforced server-side.
      final response = await _supabase.rpc(
        'set_driver_online_status',
        params: {'p_online': value},
      );
      if (response is! Map ||
          response['success'] != true ||
          response['online_status'] != value) {
        throw StateError('Driver availability update was not confirmed by the server.');
      }
      if (!mounted) return;
      setState(() => _online = value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value ? 'You are now available.' : 'You are now offline.')),
      );
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Availability could not be updated. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _registerDriver() async {
    final formKey = GlobalKey<FormState>();
    final license = TextEditingController();
    DateTime? expiry;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Driver registration'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: license,
                  decoration: const InputDecoration(labelText: 'Driving licence number'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: now.add(const Duration(days: 365)),
                      firstDate: now,
                      lastDate: DateTime(now.year + 30),
                    );
                    if (picked != null) setDialogState(() => expiry = picked);
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: Text(expiry == null ? 'Select licence expiry' : '${expiry!.day.toString().padLeft(2, '0')}-${expiry!.month.toString().padLeft(2, '0')}-${expiry!.year}'),
                ),
                if (expiry == null) const Text('Licence expiry date is required', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate() && expiry != null) Navigator.pop(dialogContext, true);
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || expiry == null) {
      license.dispose();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final user = _supabase.auth.currentUser!;
      await _supabase.from('drivers').insert({
        'profile_id': user.id,
        'license_number': license.text.trim().toUpperCase(),
        'license_expiry': expiry!.toIso8601String().split('T').first,
        'verification_status': 'PENDING',
        'online_status': false,
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver profile submitted for admin verification.')),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Driver profile could not be submitted. Check licence details and permissions.');
    } finally {
      license.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }


  Future<void> _uploadDriverLicenceDocument() async {
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Driver workspace'),
      actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
        IconButton(onPressed: () => _supabase.auth.signOut(), icon: const Icon(Icons.logout), tooltip: 'Sign out'),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
              if (_driver == null) ...[
                const Card(child: ListTile(
                  leading: Icon(Icons.badge_outlined),
                  title: Text('Complete driver registration'),
                  subtitle: Text('Submit your driving licence details. You cannot accept rides until an administrator approves your profile.'),
                )),
                FilledButton.icon(
                  onPressed: _saving ? null : _registerDriver,
                  icon: const Icon(Icons.assignment_ind_outlined),
                  label: Text(_saving ? 'Submitting…' : 'Register as driver'),
                ),
              ] else ...[
                Card(child: ListTile(
                  leading: Icon(_approved ? Icons.verified_outlined : Icons.pending_actions_outlined),
                  title: Text('Verification: ${_driver!['verification_status']}'),
                  subtitle: Text('Licence: ${_driver!['license_number'] ?? 'Not provided'}\nExpiry: ${_driver!['license_expiry'] ?? 'Not provided'}'),
                  isThreeLine: true,
                )),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _saving ? null : _uploadDriverLicenceDocument,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Upload driving licence document'),
                  ),
                ),
                Card(
                  child: SwitchListTile(
                    title: const Text('Available for rides'),
                    subtitle: Text(_online ? 'You are online' : 'You are offline'),
                    value: _online,
                    onChanged: _saving ||
                            !_approved ||
                            _driver!['verification_status']?.toString().toUpperCase() != 'APPROVED'
                        ? null
                        : _setOnline,
                  ),
                ),
                const SizedBox(height: 12),
                Text('Assigned rides', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (_assignedRides.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('No rides are assigned to you yet. Assigned trips will appear here after dispatch.'),
                    ),
                  ),
                ..._assignedRides.map((ride) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.route_outlined),
                    title: Text((ride['booking_number'] ?? 'Ride').toString()),
                    subtitle: Text(
                      '${ride['pickup_address'] ?? 'Pickup not available'} → ${ride['destination_address'] ?? 'Destination not available'}\n'
                      'Status: ${ride['booking_status'] ?? 'Unknown'} • Passengers: ${ride['passenger_count'] ?? '-'}\n'
                      'Type: ${ride['booking_type'] ?? '-'} • Fare: ₹${ride['quoted_fare'] ?? '-'}',
                    ),
                    isThreeLine: true,
                  ),
                )),
              ],
            ],
          ),
  );
}
