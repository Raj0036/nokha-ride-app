class AuthUser {
  final String id;
  final String? email;
  final String? phone;
  final bool emailVerified;

  const AuthUser({
    required this.id,
    this.email,
    this.phone,
    required this.emailVerified,
  });
}