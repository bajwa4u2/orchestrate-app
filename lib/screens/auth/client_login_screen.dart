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
  bool _requestingReset = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

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
  Widget build(BuildContext context) {
    if (_isVerification) {
      return _buildVerificationView(context);
    }

    if (_isReset) {
      return _buildResetView(context);
    }

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: wide ? 32 : 20,
                    vertical: wide ? 28 : 20,
                  ),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _buildContextPanel(context, wide: true),
                            ),
                            const SizedBox(width: 24),
                            SizedBox(
                              width: 500,
                              child: _buildFormCard(context),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildContextPanel(context, wide: false),
                            const SizedBox(height: 20),
                            _buildFormCard(context),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContextPanel(BuildContext context, {required bool wide}) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(wide ? 40 : 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppTheme.publicLine),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.publicLine),
            ),
            child: Icon(
              _isJoin ? Icons.north_east : Icons.arrow_outward,
              size: 22,
            ),
          ),
          const SizedBox(height: 28),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              _isJoin ? 'Start your client workspace' : 'Welcome back',
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.02,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Text(
              _isJoin
                  ? 'A measured entry into outreach, meetings, and revenue visibility.'
                  : 'Continue into your client workspace with the account already tied to your company access.',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.publicMuted,
                height: 1.45,
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.publicLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isJoin ? 'Email verification required' : 'Account access remains controlled',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isJoin
                      ? 'We send a verification link before workspace access so the account begins on the right footing.'
                      : 'If your email is not yet verified, the system routes you back into verification before workspace entry.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.publicMuted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
        side: const BorderSide(color: AppTheme.publicLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: _isJoin ? _buildJoinForm(context) : _buildLoginForm(context),
        ),
      ),
    );
  }

  Widget _buildJoinForm(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create account',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          'Set up your client access. We’ll send a verification email before workspace entry.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppTheme.publicMuted,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        if (_message != null) _Banner(message: _message!, error: false),
        if (_error != null) _Banner(message: _error!, error: true),
        _SectionLabel(
          eyebrow: 'Identity',
          title: 'Who is opening this account?',
        ),
        const SizedBox(height: 12),
        _field(_fullName, 'Full name'),
        const SizedBox(height: 14),
        _field(
          _email,
          'Work email',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 24),
        _SectionLabel(
          eyebrow: 'Organization',
          title: 'What business should this workspace represent?',
        ),
        const SizedBox(height: 12),
        _field(_company, 'Company name'),
        const SizedBox(height: 14),
        _field(
          _website,
          'Website',
          required: false,
          keyboardType: TextInputType.url,
          hintText: 'https://yourcompany.com',
        ),
        const SizedBox(height: 24),
        _SectionLabel(
          eyebrow: 'Access',
          title: 'Create secure sign-in details',
        ),
        const SizedBox(height: 12),
        _field(
          _password,
          'Password',
          obscure: _obscurePassword,
          suffixIcon: IconButton(
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          ),
        ),
        const SizedBox(height: 14),
        _field(
          _confirmPassword,
          'Confirm password',
          obscure: _obscureConfirmPassword,
          suffixIcon: IconButton(
            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            icon: Icon(
              _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'You’ll verify your email before entering the workspace.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.publicMuted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy ? null : _register,
            child: Text(_busy ? 'Creating account...' : 'Create account'),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              Text(
                'Already have an account?',
                style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.publicMuted),
              ),
              TextButton(
                onPressed: () => context.go('/client/login'),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Client sign in',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          'Use your account credentials to return to the client workspace.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppTheme.publicMuted,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        if (_message != null) _Banner(message: _message!, error: false),
        if (_error != null) _Banner(message: _error!, error: true),
        _field(
          _email,
          'Work email',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _field(
          _password,
          'Password',
          obscure: _obscurePassword,
          suffixIcon: IconButton(
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _requestingReset ? null : _sendPasswordReset,
            child: Text(_requestingReset ? 'Sending reset email...' : 'Forgot password?'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy ? null : _login,
            child: Text(_busy ? 'Signing in...' : 'Sign in'),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              Text(
                'Need an account?',
                style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.publicMuted),
              ),
              TextButton(
                onPressed: () => context.go('/client/join'),
                child: const Text('Create account'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationView(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    final hasToken = (uri.queryParameters['token'] ?? '').trim().isNotEmpty;
    final hasEmail = _verificationEmail != null && _verificationEmail!.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                  side: const BorderSide(color: AppTheme.publicLine),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verify your email',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        hasToken
                            ? 'We are checking your verification link now.'
                            : 'Open the verification email we sent you, then come back here after confirming your address.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.publicMuted,
                              height: 1.45,
                            ),
                      ),
                      const SizedBox(height: 24),
                      if (_message != null) _Banner(message: _message!, error: false),
                      if (_error != null) _Banner(message: _error!, error: true),
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
        ),
      ),
    );
  }

  Widget _buildResetView(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                  side: const BorderSide(color: AppTheme.publicLine),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reset password',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Use the secure reset link from your email to set a new password.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.publicMuted,
                              height: 1.45,
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
    String? hintText,
    Widget? suffixIcon,
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
              if (label == 'Work email' && value.trim().isNotEmpty && !value.contains('@')) {
                return 'Enter a valid email address.';
              }
              return null;
            }
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: const OutlineInputBorder(),
        suffixIcon: suffixIcon,
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

  Future<void> _sendPasswordReset() async {
    if (_email.text.trim().isEmpty) {
      setState(() {
        _error = 'Enter your work email first, then request a reset link.';
        _message = null;
      });
      return;
    }

    setState(() {
      _requestingReset = true;
      _error = null;
      _message = null;
    });

    try {
      await AuthRepository().requestPasswordReset(_email.text.trim());
      if (!mounted) return;
      setState(() {
        _message = 'A secure password reset email has been sent if the account exists.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _humanize(error));
    } finally {
      if (mounted) {
        setState(() => _requestingReset = false);
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
    final text = error.toString().toLowerCase();
    if (text.contains('incorrect')) return 'That email or password did not work.';
    if (text.contains('already exists')) return 'An account with this email already exists.';
    if (text.contains('expired')) return 'That link has expired. Request a fresh one and try again.';
    if (text.contains('invalid')) return 'That link is not valid anymore.';
    return 'We could not complete that request.';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.eyebrow,
    required this.title,
  });

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: theme.textTheme.labelLarge?.copyWith(
            color: AppTheme.publicMuted,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.message,
    required this.error,
  });

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: error ? Colors.red.shade100 : Colors.green.shade100,
        ),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
