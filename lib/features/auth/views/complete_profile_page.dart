import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/profile_viewmodel.dart';

class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();

  DateTime? _dateOfBirth;
  String? _gender;

  @override
  void initState() {
    super.initState();

    final profile = context.read<ProfileViewModel>().profile;

    if (profile != null) {
      _nameController.text = profile.fullName ?? '';
      _phoneController.text = profile.phone ?? '';
      _addressController.text = profile.address ?? '';
      _cityController.text = profile.city ?? '';
      _stateController.text = profile.state ?? '';
      _pincodeController.text = profile.pincode ?? '';
      _dateOfBirth = profile.dateOfBirth;
      _gender = profile.gender;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();

    final initialDate = _dateOfBirth ??
        DateTime(
          now.year - 18,
          now.month,
          now.day,
        );

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(
        now.year - 13,
        now.month,
        now.day,
      ),
      helpText: 'Select your date of birth',
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _dateOfBirth = selected;
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your date of birth.'),
        ),
      );
      return;
    }

    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your gender.'),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    final viewModel = context.read<ProfileViewModel>();

    final success = await viewModel.saveProfile(
      fullName: _nameController.text,
      phone: _phoneController.text,
      address: _addressController.text,
      city: _cityController.text,
      state: _stateController.text,
      pincode: _pincodeController.text,
      dateOfBirth: _dateOfBirth,
      gender: _gender,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileViewModel>(
      builder: (context, viewModel, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Complete Profile'),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Complete your Nokha Ride profile',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Please enter your real details to continue.',
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 28),

                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.trim().length < 2) {
                          return 'Enter your full name';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      maxLength: 10,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Number',
                        prefixIcon: Icon(Icons.phone_outlined),
                        prefixText: '+91 ',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      validator: (value) {
                        final phone = value?.trim() ?? '';

                        if (!RegExp(r'^[6-9][0-9]{9}$')
                            .hasMatch(phone)) {
                          return 'Enter a valid 10-digit mobile number';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    InkWell(
                      onTap: viewModel.isLoading
                          ? null
                          : _selectDateOfBirth,
                      borderRadius: BorderRadius.circular(4),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date of Birth',
                          prefixIcon: Icon(
                            Icons.calendar_today_outlined,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _dateOfBirth == null
                              ? 'Select date'
                              : _formatDate(_dateOfBirth!),
                          style: TextStyle(
                            color: _dateOfBirth == null
                                ? Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                : null,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Male',
                          child: Text('Male'),
                        ),
                        DropdownMenuItem(
                          value: 'Female',
                          child: Text('Female'),
                        ),
                        DropdownMenuItem(
                          value: 'Other',
                          child: Text('Other'),
                        ),
                      ],
                      onChanged: viewModel.isLoading
                          ? null
                          : (value) {
                              setState(() {
                                _gender = value;
                              });
                            },
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        prefixIcon: Icon(Icons.home_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.trim().length < 5) {
                          return 'Enter your address';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _cityController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        prefixIcon: Icon(Icons.location_city_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Enter your city';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _stateController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'State',
                        prefixIcon: Icon(Icons.map_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Enter your state';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _pincodeController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: 'Pincode',
                        prefixIcon: Icon(Icons.pin_drop_outlined),
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      validator: (value) {
                        final pincode = value?.trim() ?? '';

                        if (!RegExp(r'^[1-9][0-9]{5}$')
                            .hasMatch(pincode)) {
                          return 'Enter a valid 6-digit pincode';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    if (viewModel.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: 12,
                        ),
                        child: Text(
                          viewModel.errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .error,
                          ),
                        ),
                      ),

                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: viewModel.isLoading
                            ? null
                            : _saveProfile,
                        child: viewModel.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save & Continue'),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
