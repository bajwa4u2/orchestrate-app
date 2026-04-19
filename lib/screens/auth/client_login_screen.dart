import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/auth/auth_session.dart';
import '../../core/brand/brand_assets.dart';
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
  static const String _googleClientId =
      '383877062897-5f4f2vlrts0bdv0pv2p7m057v744bh7s.apps.googleusercontent.com';

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: _googleClientId,
    scopes: const ['email', 'profile'],
  );

  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _company = TextEditingController();
  final _email = TextEditingController();
  final _website = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _resetPassword = TextEditingController();

  bool _busy = false;
  bool _googleBusy = false;
  bool _requestingReset = false;
  bool _resendingVerification = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _obscureResetPassword = true;

  String? _message;
  String? _error;
  String? _selectedPlan;
  String? _selectedTier;
  String? _selectedTrial;
  String? _verificationEmail;
  bool _verificationComplete = false;

  bool get _isJoin => widget.createMode;
  bool get _isVerification => widget.verificationMode;
  bool get _isReset => widget.resetMode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _readRouteContext());
  }

  @override
  void dispose() {
    _fullName.dispose();
    _company.dispose();
    _email.dispose();
    _website.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _resetPassword.dispose();
    super.dispose();
  }

  Future<void> _readRouteContext() async {
    final uri = GoRouterState.of(context).uri;
    _selectedPlan =
        _normalized(uri.queryParameters['plan']) ??
        AuthSessionController.instance.selectedPlan;
    _selectedTier =
        _normalized(uri.queryParameters['tier']) ??
        AuthSessionController.instance.selectedTier;
    _selectedTrial = _normalized(uri.queryParameters['trial']);

    if (_selectedPlan != null || _selectedTier != null) {
      await AuthSessionController.instance.rememberSelection(
        plan: _selectedPlan,
        tier: _selectedTier,
      );
    }

    if (_isVerification) {
      await _handleVerification(uri);
    }
  }

  Future<void> _handleVerification(Uri uri) async {
    final token = uri.queryParameters['token']?.trim();
    final sent = uri.queryParameters['sent']?.trim();
    final email = uri.queryParameters['email']?.trim();
    if (email != null && email.isNotEmpty) _verificationEmail = email;

    if (token != null && token.isNotEmpty) {
      setState(() {
        _busy = true;
        _error = null;
        _message = 'Checking your confirmation link now.';
      });
      try {
        await AuthRepository().verifyEmail(token);
        if (!mounted) return;
        setState(() {
          _busy = false;
          _verificationComplete = true;
          _message = 'Your email is verified. You can sign in now.';
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = _humanize(error);
          _message = null;
        });
      }
      return;
    }

    if (sent == '1') {
      setState(() {
        _message = 'Check your inbox and confirm your email to continue.';
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isVerification) return _VerificationView(state: this);
    if (_isReset) return _ResetView(state: this);

    return Scaffold(
      backgroundColor: AppTheme.publicBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 940;
                  final intro = _AuthIntro(
                    isJoin: _isJoin,
                    plan: _selectedPlan,
                    tier: _selectedTier,
                    trial: _selectedTrial,
                  );
                  final form = _AuthCard(state: this);

                  if (stacked) {
                    return Column(
                      children: [intro, const SizedBox(height: 18), form],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: intro),
                      const SizedBox(width: 18),
                      Expanded(flex: 4, child: form),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> register() async {
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
        websiteUrl:
            _website.text.trim().isEmpty ? null : _website.text.trim(),
      );

      await AuthSessionController.instance.clear();
      await AuthSessionController.instance.rememberSelection(
        plan: _selectedPlan,
        tier: _selectedTier,
      );

      if (!mounted) return;
      final email = response['email']?.toString().trim();
      context.go(_route('/client/verify-email', sent: true, email: email));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _humanize(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> login() async {
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
      await _completeClientAccess(response);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _humanize(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> loginWithGoogle() async {
    if (_busy || _googleBusy) return;
    if (_googleClientId.isEmpty) {
      setState(() {
        _error = 'Google sign-in is not configured yet.';
        _message = null;
      });
      return;
    }

    setState(() {
      _googleBusy = true;
      _error = null;
      _message = null;
    });

    try {
      await _googleSignIn.signOut();
      final account = await _googleSignIn.signIn();
      if (account == null) {
        if (!mounted) return;
        setState(() {
          _message = 'Google sign-in was cancelled.';
        });
        return;
      }

      final googleAuth = await account.authentication;
      final idToken = googleAuth.idToken?.trim();
      final accessToken = googleAuth.accessToken?.trim();
      final email = account.email.trim();
      final fullName = account.displayName?.trim();

      debugPrint('Google account email: $email');
      debugPrint('Google accessToken present: ${accessToken != null && accessToken.isNotEmpty}');
      debugPrint('Google idToken present: ${idToken != null && idToken.isNotEmpty}');
      debugPrint('Google idToken length: ${idToken?.length ?? 0}');

      if ((idToken == null || idToken.isEmpty) &&
          (accessToken == null || accessToken.isEmpty)) {
        throw Exception(
          'Google sign-in completed, but no usable Google token came back for this domain.',
        );
      }

      final response = await AuthRepository().loginClientWithGoogle(
        idToken: idToken,
        accessToken: accessToken,
        email: email.isEmpty ? null : email,
        fullName: fullName == null || fullName.isEmpty ? null : fullName,
      );
      await _completeClientAccess(response);
    } catch (error, stackTrace) {
      debugPrint('Google login failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;
      setState(() => _error = _humanize(error));
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  Future<void> _completeClientAccess(Map<String, dynamic> response) async {
    await AuthSessionController.instance.applyAuthResponse(response);

    final session = AuthSessionController.instance;

    debugPrint('AFTER LOGIN token: ${session.token}');
    debugPrint('AFTER LOGIN clientId: ${session.clientId}');

    await AuthSessionController.instance.rememberSelection(
      plan: _selectedPlan,
      tier: _selectedTier,
    );
    if (!mounted) return;
    
    if (!session.emailVerified) {
      context.go(_route('/client/verify-email', email: session.email));
      return;
    }
    if (!session.hasSetupCompleted) {
      context.go(_route('/client/setup'));
      return;
    }
    if (session.normalizedSubscriptionStatus != 'active') {
      context.go(_route('/client/subscribe'));
      return;
    }
    context.go('/client/workspace');
  }

  Future<void> requestPasswordReset() async {
    if (_email.text.trim().isEmpty) {
      setState(() {
        _error = 'Enter your work email first.';
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
        _message =
            'If this email is in the system, a password reset link is on the way.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _humanize(error));
    } finally {
      if (mounted) setState(() => _requestingReset = false);
    }
  }

  Future<void> submitReset() async {
    final uri = GoRouterState.of(context).uri;
    final token = uri.queryParameters['token']?.trim();
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'That reset link is not valid anymore.';
        _message = null;
      });
      return;
    }
    if (_resetPassword.text.trim().length < 8) {
      setState(() {
        _error = 'Use at least 8 characters for your new password.';
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
      await AuthRepository().resetPassword(
        token: token,
        password: _resetPassword.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message =
            'Your password has been updated. Sign in with your new password.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _humanize(error);
      });
    }
  }

  Future<void> resendVerification() async {
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
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _humanize(error));
    } finally {
      if (mounted) setState(() => _resendingVerification = false);
    }
  }

  String _route(String path, {bool sent = false, String? email}) {
    return Uri(
      path: path,
      queryParameters: {
        if (_selectedPlan != null && _selectedPlan!.isNotEmpty)
          'plan': _selectedPlan!,
        if (_selectedTier != null && _selectedTier!.isNotEmpty)
          'tier': _selectedTier!,
        if (_selectedTrial != null && _selectedTrial!.isNotEmpty)
          'trial': _selectedTrial!,
        if (sent) 'sent': '1',
        if (email != null && email.isNotEmpty) 'email': email,
      },
    ).toString();
  }

  String _humanize(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('popup_closed') || text.contains('popup closed')) {
      return 'Google sign-in was closed before it finished.';
    }
    if (text.contains('google sign-in is not configured')) {
      return 'Google sign-in is not configured yet.';
    }
    if (text.contains('no id token')) {
      return 'Google signed in, but no ID token came back for this domain.';
    }
    if (text.contains('did not return a valid sign-in token')) {
      return 'Google signed in, but no valid ID token came back.';
    }
    if (text.contains('incorrect')) {
      return 'That email or password did not match our records.';
    }
    if (text.contains('already exists')) {
      return 'An account with this email already exists.';
    }
    if (text.contains('expired')) {
      return 'That link has expired. Request a fresh one and try again.';
    }
    if (text.contains('invalid')) {
      return 'That link is not valid anymore.';
    }
    return 'We could not complete that request.';
  }
}

class _AuthIntro extends StatelessWidget {
  const _AuthIntro({required this.isJoin, this.plan, this.tier, this.trial});

  final bool isJoin;
  final String? plan;
  final String? tier;
  final String? trial;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (plan != null && plan!.isNotEmpty) 'Plan: ${_label(plan!)}',
      if (tier != null && tier!.isNotEmpty) 'Tier: ${_label(tier!)}',
      if (trial == '15d') '15-day trial request selected',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BrandAssets.logo(context, height: 28),
          const SizedBox(height: 24),
          Text(
            isJoin
                ? 'Create your workspace and move straight into setup.'
                : 'Return to your client workspace.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            isJoin
                ? 'Create your workspace, confirm your email, define your operating scope, and continue to checkout.'
                : 'Sign in to continue where you left off, review your account, and get back to work.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppTheme.publicMuted),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [for (final item in details) _Pill(label: item)],
            ),
          ],
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.publicSurfaceSoft,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.publicLine),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IntroPoint(
                  title: 'Verification',
                  body:
                      'Email confirmation stays in the main flow so setup does not get lost.',
                ),
                SizedBox(height: 12),
                _IntroPoint(
                  title: 'Setup continuity',
                  body:
                      'Plan and tier choices can carry directly into setup and subscription flow.',
                ),
                SizedBox(height: 12),
                _IntroPoint(
                  title: 'Access choices',
                  body:
                      'Email and Google can sit side by side without disrupting your existing sign-in path.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroPoint extends StatelessWidget {
  const _IntroPoint({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(body, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({required this.state});
  final _ClientLoginScreenState state;

  @override
  Widget build(BuildContext context) {
    final canUseGoogle = _ClientLoginScreenState._googleClientId.isNotEmpty;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
        side: const BorderSide(color: AppTheme.publicLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: state._formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state._isJoin
                    ? 'Create your workspace'
                    : 'Sign in to your workspace',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                state._isJoin
                    ? 'Use your work details so setup can continue cleanly after verification.'
                    : 'Use your work email to continue.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppTheme.publicMuted),
              ),
              const SizedBox(height: 20),
              if (state._message != null)
                _Banner(message: state._message!, error: false),
              if (state._error != null)
                _Banner(message: state._error!, error: true),
              if (canUseGoogle) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                        (state._busy || state._googleBusy)
                            ? null
                            : state.loginWithGoogle,
                    icon:
                        state._googleBusy
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.login_outlined),
                    label: Text(
                      state._googleBusy
                          ? 'Opening Google...'
                          : 'Continue with Google',
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(child: Divider(height: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.publicMuted,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(height: 1)),
                  ],
                ),
                const SizedBox(height: 18),
              ],
              if (state._isJoin) ...[
                _Field(controller: state._fullName, label: 'Full name'),
                const SizedBox(height: 14),
                _Field(
                  controller: state._email,
                  label: 'Work email',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                _Field(controller: state._company, label: 'Company name'),
                const SizedBox(height: 14),
                _Field(
                  controller: state._website,
                  label: 'Website',
                  keyboardType: TextInputType.url,
                  required: false,
                  hintText: 'https://yourcompany.com',
                ),
                const SizedBox(height: 14),
                _Field(
                  controller: state._password,
                  label: 'Password',
                  obscure: state._obscurePassword,
                  suffixIcon: IconButton(
                    onPressed:
                        () => state.setState(
                          () =>
                              state._obscurePassword = !state._obscurePassword,
                        ),
                    icon: Icon(
                      state._obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _Field(
                  controller: state._confirmPassword,
                  label: 'Confirm password',
                  obscure: state._obscureConfirmPassword,
                  suffixIcon: IconButton(
                    onPressed:
                        () => state.setState(
                          () =>
                              state._obscureConfirmPassword =
                                  !state._obscureConfirmPassword,
                        ),
                    icon: Icon(
                      state._obscureConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: state._busy ? null : state.register,
                    child: Text(
                      state._busy ? 'Creating workspace...' : 'Continue',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Already have access?',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () => context.go(state._route('/client/login')),
                        child: const Text('Sign in'),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                _Field(
                  controller: state._email,
                  label: 'Work email',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                _Field(
                  controller: state._password,
                  label: 'Password',
                  obscure: state._obscurePassword,
                  suffixIcon: IconButton(
                    onPressed:
                        () => state.setState(
                          () =>
                              state._obscurePassword = !state._obscurePassword,
                        ),
                    icon: Icon(
                      state._obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed:
                        state._requestingReset
                            ? null
                            : state.requestPasswordReset,
                    child: Text(
                      state._requestingReset
                          ? 'Sending reset email...'
                          : 'Send reset link',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: state._busy ? null : state.login,
                    child: Text(
                      state._busy ? 'Opening workspace...' : 'Sign in',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'New here?',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () => context.go(state._route('/client/join')),
                        child: const Text('Create workspace'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _VerificationView extends StatelessWidget {
  const _VerificationView({required this.state});
  final _ClientLoginScreenState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.publicBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                  side: const BorderSide(color: AppTheme.publicLine),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BrandAssets.logo(context, height: 28),
                      const SizedBox(height: 20),
                      Text(
                        'Confirm your email',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        state._verificationComplete
                            ? 'Your email is confirmed. Sign in to continue.'
                            : 'Open the email we sent and confirm the address tied to this workspace.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.publicMuted,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (state._message != null)
                        _Banner(message: state._message!, error: false),
                      if (state._error != null)
                        _Banner(message: state._error!, error: true),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton(
                            onPressed:
                                () => context.go(state._route('/client/login')),
                            child: const Text('Go to sign in'),
                          ),
                          OutlinedButton(
                            onPressed:
                                state._verificationEmail == null ||
                                        state._resendingVerification ||
                                        state._busy
                                    ? null
                                    : state.resendVerification,
                            child: Text(
                              state._resendingVerification
                                  ? 'Sending...'
                                  : 'Resend verification',
                            ),
                          ),
                          TextButton(
                            onPressed:
                                () => context.go(state._route('/client/join')),
                            child: const Text('Use another email'),
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
}

class _ResetView extends StatelessWidget {
  const _ResetView({required this.state});
  final _ClientLoginScreenState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.publicBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                  side: const BorderSide(color: AppTheme.publicLine),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BrandAssets.logo(context, height: 28),
                      const SizedBox(height: 20),
                      Text(
                        'Create a new password',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Use the secure link from your email to set a new password for this workspace.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.publicMuted,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (state._message != null)
                        _Banner(message: state._message!, error: false),
                      if (state._error != null)
                        _Banner(message: state._error!, error: true),
                      _Field(
                        controller: state._resetPassword,
                        label: 'New password',
                        obscure: state._obscureResetPassword,
                        suffixIcon: IconButton(
                          onPressed:
                              () => state.setState(
                                () => state._obscureResetPassword =
                                    !state._obscureResetPassword,
                              ),
                          icon: Icon(
                            state._obscureResetPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton(
                            onPressed: state._busy ? null : state.submitReset,
                            child: Text(
                              state._busy
                                  ? 'Updating password...'
                                  : 'Update password',
                            ),
                          ),
                          OutlinedButton(
                            onPressed:
                                () => context.go(state._route('/client/login')),
                            child: const Text('Back to sign in'),
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
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.required = true,
    this.hintText,
    this.obscure = false,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool required;
  final String? hintText;
  final bool obscure;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      validator:
          required
              ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return '$label is required.';
                }
                if (label.toLowerCase().contains('email') &&
                    !value.contains('@')) {
                  return 'Enter a valid email address.';
                }
                return null;
              }
              : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.error});
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
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

String _label(String input) {
  return input
      .replaceAll('-', ' ')
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

String? _normalized(String? value) {
  final text = value?.trim().toLowerCase();
  if (text == null || text.isEmpty) return null;
  return text;
}
