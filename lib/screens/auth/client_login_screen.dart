import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/auth_repository.dart';

class ClientLoginScreen extends StatefulWidget {
  const ClientLoginScreen({super.key, this.createMode = false, this.verificationMode = false, this.resetMode = false});

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
  final _website = TextEditingController();
  final _resetPassword = TextEditingController();
  bool _busy = false;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.verificationMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _verifyFromLink());
    }
  }

  Future<void> _verifyFromLink() async {
    final token = GoRouterState.of(context).uri.queryParameters['token'];
    if (token == null || token.isEmpty) return;
    setState(() => _busy = true);
    try {
      await AuthRepository().verifyEmail(token);
      setState(() => _message = 'Email verified. You can sign in now.');
    } catch (error) {
      setState(() => _error = _humanize(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _fullName.dispose();
    _company.dispose();
    _email.dispose();
    _password.dispose();
    _website.dispose();
    _resetPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final join = widget.createMode;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: AppTheme.publicLine)),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(join ? 'Join Orchestrate' : 'Client sign in', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 10),
                  Text(join ? 'Create a client account and enter your workspace.' : 'Continue into your client workspace.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.publicMuted)),
                  const SizedBox(height: 24),
                  if (_message != null) _Banner(message: _message!, error: false),
                  if (_error != null) _Banner(message: _error!, error: true),
                  if (join) ...[
                    _field(_fullName, 'Full name'),
                    const SizedBox(height: 14),
                    _field(_company, 'Company name'),
                    const SizedBox(height: 14),
                    _field(_website, 'Website', required: false),
                    const SizedBox(height: 14),
                  ],
                  _field(_email, 'Email', keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 14),
                  _field(_password, join ? 'Create password' : 'Password', obscure: true),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : () => join ? _register() : _login(),
                    child: Text(_busy ? 'Working...' : (join ? 'Create account' : 'Sign in')),
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Text(join ? 'Already have an account?' : 'Need an account?'),
                    TextButton(onPressed: () => context.go(join ? '/client/login' : '/client/join'), child: Text(join ? 'Sign in' : 'Create account')),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, {bool obscure = false, bool required = true, TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: required ? (value) => (value == null || value.trim().isEmpty) ? '$label is required.' : null : null,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; _message = null; });
    try {
      final response = await AuthRepository().registerClient(
        fullName: _fullName.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        companyName: _company.text.trim(),
        websiteUrl: _website.text.trim().isEmpty ? null : _website.text.trim(),
      );
      await AuthSessionController.instance.applyAuthResponse(response);
      if (mounted) context.go('/client/workspace');
    } catch (error) {
      setState(() => _error = _humanize(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; _message = null; });
    try {
      final response = await AuthRepository().loginClient(email: _email.text.trim(), password: _password.text);
      await AuthSessionController.instance.applyAuthResponse(response);
      if (mounted) context.go('/client/workspace');
    } catch (error) {
      setState(() => _error = _humanize(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _humanize(Object error) {
    final text = error.toString();
    if (text.contains('incorrect')) return 'That email or password did not work.';
    if (text.contains('already exists')) return 'An account with this email already exists.';
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
      decoration: BoxDecoration(color: error ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
      child: Text(message),
    );
  }
}
