import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/auth_viewmodel.dart';
import 'msg91_otp_page.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _useEmailLogin = false;
  bool _obscurePassword = true;
  bool _openingWidget = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _normalizedPhone => '+91${_phoneController.text.trim()}';

  Future<void> _phoneLogin() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _openingWidget = true);
    final phone = _normalizedPhone;
    final accessToken = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => Msg91OtpPage(initialPhone: _phoneController.text.trim()),
      ),
    );
    if (!mounted) return;
    setState(() => _openingWidget = false);
    if (accessToken == null || accessToken.isEmpty) return;

    final viewModel = context.read<AuthViewModel>();
    final success = await viewModel.verifyMsg91WidgetToken(
      phone: phone,
      accessToken: accessToken,
    );
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone verified. You are signed in.')),
      );
    }
  }

  Future<void> _emailLogin() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final viewModel = context.read<AuthViewModel>();
    final success = await viewModel.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    if (success) {
      if (viewModel.isEmailVerified) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const _LoginSuccessPage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please verify your email before continuing.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, viewModel, _) {
        final busy = viewModel.isLoading || _openingWidget;
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.local_taxi_rounded, size: 64),
                        const SizedBox(height: 20),
                        const Text(
                          'Welcome to Nokha Ride',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _useEmailLogin
                              ? 'Login with your existing email and password'
                              : 'Login securely using MSG91 OTP',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        if (!_useEmailLogin) ...[
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            maxLength: 10,
                            autofillHints: const [AutofillHints.telephoneNumberNational],
                            onFieldSubmitted: (_) => _phoneLogin(),
                            decoration: const InputDecoration(
                              labelText: 'Mobile Number',
                              prefixText: '+91 ',
                              prefixIcon: Icon(Icons.phone_android),
                              border: OutlineInputBorder(),
                              counterText: '',
                            ),
                            validator: (value) {
                              if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(value?.trim() ?? '')) {
                                return 'Enter a valid 10-digit Indian mobile number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          if (viewModel.errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                viewModel.errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: busy ? null : _phoneLogin,
                              child: busy
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Continue with MSG91 OTP'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'OTP delivery and verification are handled by your configured MSG91 Widget.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12),
                          ),
                        ] else ...[
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty || !email.contains('@')) return 'Enter a valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _emailLogin(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                icon: Icon(_obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                              ),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Enter your password';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          if (viewModel.errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                viewModel.errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: busy ? null : _emailLogin,
                              child: busy
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Login'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const SignupPage()),
                                    ),
                            child: const Text("Don't have an account? Create one"),
                          ),
                        ],
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                    _useEmailLogin = !_useEmailLogin;
                                    viewModel.clearError();
                                  }),
                          child: Text(
                            _useEmailLogin
                                ? 'Use MSG91 phone OTP instead'
                                : 'Use existing email login instead',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LoginSuccessPage extends StatelessWidget {
  const _LoginSuccessPage();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nokha Ride')),
      body: const Center(
        child: Text('Login successful', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
