import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/auth_repository.dart';

class ClientLoginScreen extends StatefulWidget {
  const ClientLoginScreen({
    super.key,
    this.createMode = false,
    this.verificationMode = false,
    this.resetMode = false,
  });

  final bool createMode;
  final bool verificationMode;
  final bool resetMode;

  @override
  State<ClientLoginScreen> createState() => _ClientLoginScreenState();
}

class _ClientLoginScreenState extends State<ClientLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _company = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _website = TextEditingController();
  final _resetPassword = TextEditingController();

  bool _busy = false;
  bool _resendingVerification = false;
  String? _message;
  String? _error;
  String? _verificationEmail;

  bool get _isJoin => widget.createMode;
  bool get _isVerification => widget.verificationMode;
  bool get _isReset => widget.resetMode;

  @override
  void initState() {
    super.initState();
    if (_isVerification) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleVerificationScreen());
    }
  }

  Future<void> _handleVerificationScreen() async {
    final uri = GoRouterState.of(context).uri;
    final token = uri.queryParameters['token'];
    final email = uri.queryParameters['email'];
    final sent = uri.queryParameters['sent'];

    if (email != null && email.trim().isNotEmpty) {
      _verificationEmail = email.trim();
    }

    if (token != null && token.isNotEmpty) {
      setState(() {
        _busy = true;
        _error = null;
        _message = 'Verifying your email...';
      });

      try {
        await AuthRepository().verifyEmail(token);
        if (!mounted) return;
        setState(() {
          _message = 'Your email has been verified. You can sign in now.';
          _error = null;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _error = _humanize(error);
          _message = null;
        });
      } finally {
        if (mounted) {
          setState(() => _busy = false);
        }
      }

      return;
    }

    if (sent == '1') {
      final emailText = (email != null && email.trim().isNotEmpty) ? email.trim() : 'your inbox';
      setState(() {
        _message =
            'Check $emailText and open the verification link to continue. Your workspace will unlock after email verification.';
        _error = null;
      });
    }
  }

  @override
  void dispose() {
    _fullName.dispose();
    _company.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _website.dispose();
    _resetPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isVerification) {
      return _buildVerificationView(context);
    }

    if (_isReset) {
      return _buildResetView(context);
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: AppTheme.publicLine),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isJoin ? 'Join Orchestrate' : 'Client sign in',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isJoin
                          ? 'Create your client account. We’ll email you a verification link before workspace access.'
                          : 'Continue into your client workspace.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppTheme.publicMuted,
                          ),
                    ),
                    const SizedBox(height: 24),
                    if (_message != null) _Banner(message: _message!, error: false),
                    if (_error != null) _Banner(message: _error!, error: true),
                    if (_isJoin) ...[
                      _field(_fullName, 'Full name'),
                      const SizedBox(height: 14),
                      _field(_company, 'Company name'),
                      const SizedBox(height: 14),
                      _field(_website, 'Website', required: false),
                      const SizedBox(height: 14),
                    ],
                    _field(
                      _email,
                      'Email',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      _password,
                      _isJoin ? 'Create password' : 'Password',
                      obscure: true,
                    ),
                    if (_isJoin) ...[
                      const SizedBox(height: 14),
                      _field(
                        _confirmPassword,
                        'Confirm password',
                        obscure: true,
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : () => _isJoin ? _register() : _login(),
                      child: Text(
                        _busy ? 'Working...' : (_isJoin ? 'Create account' : 'Sign in'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(_isJoin ? 'Already have an account?' : 'Need an account?'),
                        TextButton(
                          onPressed: () => context.go(_isJoin ? '/client/login' : '/client/join'),
                          child: Text(_isJoin ? 'Sign in' : 'Create account'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationView(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    final hasToken = (uri.queryParameters['token'] ?? '').trim().isNotEmpty;
    final hasEmail = _verificationEmail != null && _verificationEmail!.isNotEmpty;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: AppTheme.publicLine),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verify your email',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    hasToken
                        ? 'We are checking your verification link now.'
                        : 'Open the verification email we sent you, then come back here after confirming your address.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.publicMuted,
                        ),
                  ),
                  const SizedBox(height: 24),
                  if (_message != null) _Banner(message: _message!, error: false),
                  if (_error != null) _Banner(message: _error!, error: true),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton(
                        onPressed: _busy ? null : () => context.go('/client/login'),
                        child: const Text('Go to sign in'),
                      ),
                      OutlinedButton(
                        onPressed: (!hasEmail || _busy || _resendingVerification)
                            ? null
                            : _resendVerification,
                        child: Text(
                          _resendingVerification ? 'Sending...' : 'Resend verification',
                        ),
                      ),
                      TextButton(
                        onPressed: _busy ? null : () => context.go('/client/join'),
                        child: const Text('Create another account'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResetView(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: AppTheme.publicLine),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reset password',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Password reset is available through the secure reset link we email to your account.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.publicMuted,
                        ),
                  ),
                  const SizedBox(height: 24),
                  if (_message != null) _Banner(message: _message!, error: false),
                  if (_error != null) _Banner(message: _error!, error: true),
                  FilledButton(
                    onPressed: () => context.go('/client/login'),
                    child: const Text('Back to sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool obscure = false,
    bool required = true,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return '$label is required.';
              }
              return null;
            }
          : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_password.text != _confirmPassword.text) {
      setState(() {
        _error = 'Passwords do not match.';
        _message = null;
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });

    try {
      final response = await AuthRepository().registerClient(
        fullName: _fullName.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        companyName: _company.text.trim(),
        websiteUrl: _website.text.trim().isEmpty ? null : _website.text.trim(),
      );

      final requiresVerification = response['requiresVerification'] == true;
      final email = response['email']?.toString().trim();

      await AuthSessionController.instance.clear();

      if (!mounted) return;

      if (requiresVerification) {
        final query = <String, String>{'sent': '1'};
        if (email != null && email.isNotEmpty) {
          query['email'] = email;
        }
        context.go(Uri(path: '/client/verify-email', queryParameters: query).toString());
        return;
      }

      setState(() {
        _message = 'Your account was created. Please sign in.';
      });
    } catch (error) {
      setState(() => _error = _humanize(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });

    try {
      final response = await AuthRepository().loginClient(
        email: _email.text.trim(),
        password: _password.text,
      );
      await AuthSessionController.instance.applyAuthResponse(response);
      if (mounted) context.go('/client/workspace');
    } catch (error) {
      setState(() => _error = _humanize(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _resendVerification() async {
    final email = _verificationEmail;
    if (email == null || email.isEmpty) return;

    setState(() {
      _resendingVerification = true;
      _error = null;
    });

    try {
      await AuthRepository().requestEmailVerification(email);
      if (!mounted) return;
      setState(() {
        _message = 'A fresh verification email has been sent to $email.';
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _humanize(error);
      });
    } finally {
      if (mounted) {
        setState(() => _resendingVerification = false);
      }
    }
  }

  String _humanize(Object error) {
    final text = error.toString();
    if (text.contains('incorrect')) return 'That email or password did not work.';
    if (text.contains('already exists')) return 'An account with this email already exists.';
    if (text.contains('expired')) return 'That link has expired. Request a fresh one and try again.';
    if (text.contains('invalid')) return 'That link is not valid anymore.';
    return 'We could not complete that request.';
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.error});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message),
    );
  }
}
