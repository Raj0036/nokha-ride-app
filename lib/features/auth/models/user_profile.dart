class UserProfile {
  final String id;
  final String? fullName;
  final String? phone;
  final String? email;
  final String? profilePhotoUrl;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String accountStatus;
  final String preferredLanguage;

  const UserProfile({
    required this.id,
    this.fullName,
    this.phone,
    this.email,
    this.profilePhotoUrl,
    this.dateOfBirth,
    this.gender,
    this.address,
    this.city,
    this.state,
    this.pincode,
    required this.accountStatus,
    required this.preferredLanguage,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      fullName: map['full_name'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      profilePhotoUrl: map['profile_photo_url'] as String?,
      dateOfBirth: map['date_of_birth'] != null
          ? DateTime.tryParse(map['date_of_birth'].toString())
          : null,
      gender: map['gender'] as String?,
      address: map['address'] as String?,
      city: map['city'] as String?,
      state: map['state'] as String?,
      pincode: map['pincode'] as String?,
      accountStatus: map['account_status']?.toString() ?? 'ACTIVE',
      preferredLanguage:
          map['preferred_language']?.toString() ?? 'hi',
    );
  }

  bool get isComplete {
    return _hasValue(fullName) &&
        _hasValue(phone) &&
        dateOfBirth != null &&
        _hasValue(gender) &&
        _hasValue(address) &&
        _hasValue(city) &&
        _hasValue(state) &&
        _hasValue(pincode);
  }

  static bool _hasValue(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}
