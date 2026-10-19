import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/auth_viewmodel.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _otpSent = false;
  bool _useEmailLogin = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _normalizedPhone => '+91${_phoneController.text.trim()}';

  Future<void> _sendOtp() async {
    // Validate the phone independently so resend works even when the OTP
    // field is empty or contains an earlier incorrect code.
    if (!RegExp(r'^[6-9][0-9]{9}

    final viewModel = context.read<AuthViewModel>();
    final success = await viewModel.sendPhoneOtp(phone: _normalizedPhone);

    if (!mounted) return;
    if (success) {
      setState(() {
        _otpSent = true;
        _otpController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP sent. Please check your phone.')),
      );
    }
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final viewModel = context.read<AuthViewModel>();
    final success = await viewModel.verifyPhoneOtp(
      phone: _normalizedPhone,
      token: _otpController.text.trim(),
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone verified successfully.')),
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
          const SnackBar(
            content: Text('Please verify your email before continuing.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, viewModel, _) {
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
                          _useEmailLogin ? 'Login with email and password' : 'Login securely with phone OTP',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        if (!_useEmailLogin) ...[
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            maxLength: 10,
                            autofillHints: const [AutofillHints.telephoneNumberNational],
                            decoration: const InputDecoration(
                              labelText: 'Mobile Number',
                              prefixText: '+91 ',
                              prefixIcon: Icon(Icons.phone_android),
                              border: OutlineInputBorder(),
                              counterText: '',
                            ),
                            validator: (value) {
                              final phone = value?.trim() ?? '';
                              if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(phone)) {
                                return 'Enter a valid 10-digit Indian mobile number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          if (_otpSent) ...[
                            TextFormField(
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              maxLength: 6,
                              autofillHints: const [AutofillHints.oneTimeCode],
                              decoration: const InputDecoration(
                                labelText: '6-digit OTP',
                                prefixIcon: Icon(Icons.password),
                                border: OutlineInputBorder(),
                                counterText: '',
                              ),
                              validator: (value) {
                                if (!_otpSent) return null;
                                if (!RegExp(r'^[0-9]{6}$').hasMatch(value?.trim() ?? '')) {
                                  return 'Enter the 6-digit OTP';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: viewModel.isLoading ? null : _sendOtp,
                              child: const Text('Resend OTP'),
                            ),
                          ],
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
                              onPressed: viewModel.isLoading
                                  ? null
                                  : (_otpSent ? _verifyOtp : _sendOtp),
                              child: viewModel.isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(_otpSent ? 'Verify OTP & Login' : 'Send OTP'),
                            ),
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
                              if (email.isEmpty || !email.contains('@')) {
                                return 'Enter a valid email';
                              }
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
                                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
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
                              onPressed: viewModel.isLoading ? null : _emailLogin,
                              child: viewModel.isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Login'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: viewModel.isLoading
                              ? null
                              : () => setState(() {
                                    _useEmailLogin = !_useEmailLogin;
                                    _otpSent = false;
                                    _otpController.clear();
                                    viewModel.clearError();
                                  }),
                          child: Text(
                            _useEmailLogin ? 'Use phone OTP instead' : 'Use existing email login instead',
                          ),
                        ),
                        if (_useEmailLogin)
                          TextButton(
                            onPressed: viewModel.isLoading
                                ? null
                                : () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const SignupPage()),
                                    );
                                  },
                            child: const Text("Don't have an account? Create one"),
                          ),
                        if (!_useEmailLogin)
                          const Text(
                            'By continuing, you agree to receive a one-time verification SMS.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12),
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
        child: Text(
          'Login successful',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}).hasMatch(_phoneController.text.trim())) {
      _formKey.currentState!.validate();
      return;
    }
    FocusScope.of(context).unfocus();

    final viewModel = context.read<AuthViewModel>();
    final success = await viewModel.sendPhoneOtp(phone: _normalizedPhone);

    if (!mounted) return;
    if (success) {
      setState(() {
        _otpSent = true;
        _otpController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP sent. Please check your phone.')),
      );
    }
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final viewModel = context.read<AuthViewModel>();
    final success = await viewModel.verifyPhoneOtp(
      phone: _normalizedPhone,
      token: _otpController.text.trim(),
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone verified successfully.')),
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
          const SnackBar(
            content: Text('Please verify your email before continuing.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, viewModel, _) {
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
                          _useEmailLogin ? 'Login with email and password' : 'Login securely with phone OTP',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        if (!_useEmailLogin) ...[
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            maxLength: 10,
                            autofillHints: const [AutofillHints.telephoneNumberNational],
                            decoration: const InputDecoration(
                              labelText: 'Mobile Number',
                              prefixText: '+91 ',
                              prefixIcon: Icon(Icons.phone_android),
                              border: OutlineInputBorder(),
                              counterText: '',
                            ),
                            validator: (value) {
                              final phone = value?.trim() ?? '';
                              if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(phone)) {
                                return 'Enter a valid 10-digit Indian mobile number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          if (_otpSent) ...[
                            TextFormField(
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              maxLength: 6,
                              autofillHints: const [AutofillHints.oneTimeCode],
                              decoration: const InputDecoration(
                                labelText: '6-digit OTP',
                                prefixIcon: Icon(Icons.password),
                                border: OutlineInputBorder(),
                                counterText: '',
                              ),
                              validator: (value) {
                                if (!_otpSent) return null;
                                if (!RegExp(r'^[0-9]{6}$').hasMatch(value?.trim() ?? '')) {
                                  return 'Enter the 6-digit OTP';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: viewModel.isLoading ? null : _sendOtp,
                              child: const Text('Resend OTP'),
                            ),
                          ],
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
                              onPressed: viewModel.isLoading
                                  ? null
                                  : (_otpSent ? _verifyOtp : _sendOtp),
                              child: viewModel.isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(_otpSent ? 'Verify OTP & Login' : 'Send OTP'),
                            ),
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
                              if (email.isEmpty || !email.contains('@')) {
                                return 'Enter a valid email';
                              }
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
                                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
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
                              onPressed: viewModel.isLoading ? null : _emailLogin,
                              child: viewModel.isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Login'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: viewModel.isLoading
                              ? null
                              : () => setState(() {
                                    _useEmailLogin = !_useEmailLogin;
                                    _otpSent = false;
                                    _otpController.clear();
                                    viewModel.clearError();
                                  }),
                          child: Text(
                            _useEmailLogin ? 'Use phone OTP instead' : 'Use existing email login instead',
                          ),
                        ),
                        if (_useEmailLogin)
                          TextButton(
                            onPressed: viewModel.isLoading
                                ? null
                                : () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const SignupPage()),
                                    );
                                  },
                            child: const Text("Don't have an account? Create one"),
                          ),
                        if (!_useEmailLogin)
                          const Text(
                            'By continuing, you agree to receive a one-time verification SMS.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12),
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
        child: Text(
          'Login successful',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}