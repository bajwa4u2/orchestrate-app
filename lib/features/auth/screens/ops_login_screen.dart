import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/data/repositories/auth_repository.dart';

class OpsLoginScreen extends StatefulWidget {
  const OpsLoginScreen({super.key, this.createMode = false});

  final bool createMode;

  @override
  State<OpsLoginScreen> createState() => _OpsLoginScreenState();
}

class _OpsLoginScreenState extends State<OpsLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _workspace = TextEditingController(text: 'Orchestrate Operations');
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  bool _trustDevice = true;
  String? _error;
  Map<String, dynamic>? _pendingChallenge;

  @override
  void initState() {
    super.initState();
    final notice = AuthSessionController.instance.authNotice;
    if (notice.isNotEmpty) {
      _error = notice;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _workspace.dispose();
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final createMode = widget.createMode;
    final pendingChallenge = _pendingChallenge;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            pendingChallenge != null
                                ? 'Enter email code'
                                : createMode
                                ? 'Create operator access'
                                : 'Operator sign in',
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 12),
                        if (_error != null)
                          Text(_error!,
                              style: const TextStyle(color: Colors.red)),
                        if (pendingChallenge != null) ...[
                          Text(
                            'We sent a code to ${pendingChallenge['email'] ?? 'your email'}.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                              controller: _code,
                              decoration:
                                  const InputDecoration(labelText: 'Email code'),
                              validator: _required),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _trustDevice,
                            onChanged: (value) => setState(
                                () => _trustDevice = value == true),
                            controlAffinity: ListTileControlAffinity.leading,
                            title: const Text('Trust this device for 60 days'),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                              onPressed: _busy ? null : _verifyCode,
                              child: Text(
                                  _busy ? 'Verifying...' : 'Verify code')),
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                        _pendingChallenge = null;
                                        _password.clear();
                                        _code.clear();
                                      }),
                              child: const Text('Back to sign in')),
                        ] else ...[
                        if (createMode) ...[
                          TextFormField(
                              controller: _name,
                              decoration:
                                  const InputDecoration(labelText: 'Full name'),
                              validator: _required),
                          const SizedBox(height: 12),
                          TextFormField(
                              controller: _workspace,
                              decoration: const InputDecoration(
                                  labelText: 'Workspace name'),
                              validator: _required),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                            controller: _email,
                            decoration:
                                const InputDecoration(labelText: 'Email'),
                            validator: _required),
                        const SizedBox(height: 12),
                        TextFormField(
                            controller: _password,
                            decoration:
                                const InputDecoration(labelText: 'Password'),
                            obscureText: true,
                            validator: _required),
                        const SizedBox(height: 20),
                        FilledButton(
                            onPressed: _busy
                                ? null
                                : () => createMode ? _bootstrap() : _login(),
                            child: Text(_busy
                                ? 'Working...'
                                : (createMode
                                    ? 'Create operator account'
                                    : 'Sign in'))),
                        const SizedBox(height: 12),
                        TextButton(
                            onPressed: () => context
                                .go(createMode ? '/ops/login' : '/ops/join'),
                            child: Text(createMode
                                ? 'Use existing operator account'
                                : 'Create operator access')),
                        ],
                      ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  Future<void> _bootstrap() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await AuthRepository().bootstrapOperator(
        fullName: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        workspaceName: _workspace.text.trim(),
      );
      if (mounted) context.go('/ops/overview');
    } catch (error) {
      setState(() => _error = 'We could not create operator access.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await AuthRepository()
          .loginOperator(email: _email.text.trim(), password: _password.text);
      if (response['requiresEmailCodeChallenge'] == true) {
        setState(() {
          _pendingChallenge = Map<String, dynamic>.from(
              (response['challenge'] as Map?) ?? const {});
        });
        return;
      }
      if (mounted) context.go('/ops/overview');
    } catch (error) {
      setState(() => _error = 'That operator login did not work.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;
    final challengeId = _pendingChallenge?['id']?.toString() ?? '';
    if (challengeId.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthRepository().verifyOperatorLoginCode(
        challengeId: challengeId,
        code: _code.text.trim(),
        trustDevice: _trustDevice,
      );
      if (mounted) context.go('/ops/overview');
    } catch (error) {
      setState(() => _error = 'That code did not work.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
