import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:orchestrate_app/core/theme/ob.dart';
import 'package:orchestrate_app/core/ui/ob_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:orchestrate_app/core/auth/return_path.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:orchestrate_app/app/shell/auth_shell.dart';
import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/brand/brand_assets.dart';
import 'package:orchestrate_app/core/network/api_client.dart';
import 'package:orchestrate_app/core/platform/billing_gate.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/auth_repository.dart';

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

  // Google sign-in shows on Android, Web and desktop, but is hidden on
  // iOS for the v1 App Store submission: the iOS OAuth client is not
  // configured, and offering a third-party login on iOS would also
  // require Sign in with Apple (App Store Guideline 4.8). iOS keeps the
  // email/password path. kIsWeb + defaultTargetPlatform are used (not
  // dart:io) so the Web build still compiles.
  static bool get _googleSignInAvailable =>
      _googleClientId.isNotEmpty &&
      (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS);

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: _googleClientId,
    scopes: const ['email', 'profile'],
  );

  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _company = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  /// Named so NEXT from the email field lands here and nowhere else.
  final _passwordFocus = FocusNode();
  final _resetPassword = TextEditingController();
  final _loginCode = TextEditingController();

  bool _busy = false;
  bool _googleBusy = false;
  bool _requestingReset = false;
  bool _resendingVerification = false;
  bool _obscurePassword = true;
  bool _obscureResetPassword = true;
  bool _rememberEmail = false;
  bool _trustDevice = true;

  String? _message;
  String? _error;
  String? _verificationEmail;
  Map<String, dynamic>? _pendingChallenge;

  /// The pending code confirms a new sign-up rather than a sign-in.
  bool _signupCode = false;
  bool _verificationComplete = false;

  bool get _isJoin => widget.createMode;
  bool get _isVerification => widget.verificationMode;
  bool get _isReset => widget.resetMode;

  @override
  void initState() {
    super.initState();
    final notice = AuthSessionController.instance.authNotice;
    if (notice.isNotEmpty) {
      _error = notice;
    }
    _loadSavedEmail();
    WidgetsBinding.instance.addPostFrameCallback((_) => _readRouteContext());
  }

  @override
  void dispose() {
    _fullName.dispose();
    _company.dispose();
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    _resetPassword.dispose();
    _loginCode.dispose();
    super.dispose();
  }

  Future<void> _loadSavedEmail() async {
    final saved = await AuthSessionController.instance.savedLoginEmail();
    if (!mounted || saved.isEmpty) return;
    setState(() {
      _email.text = saved;
      _rememberEmail = true;
    });
  }

  Future<void> _readRouteContext() async {
    // NOTHING COMMERCIAL IS CARRIED IN.
    //
    // A plan, a tier and a trial flag used to be read off the URL here and
    // remembered on the session, so a package chosen on the marketing site
    // arrived preselected in setup and was shown back as though the business
    // held it. None of those exist any more, and a remembered click was never
    // a commercial fact in the first place.
    final uri = GoRouterState.of(context).uri;

    if (_isVerification) {
      await _handleVerification(uri);
      return;
    }

    // DELETION IS SAID, NOT IMPLIED.
    //
    // Deleting the account ended on this screen with nothing on it, identical
    // to an ordinary sign-out — the one moment a person most needs to know the
    // act went through. What it says is what deletion does (verified end to
    // end 2026-09-18): the login is erased, nothing can restore it, and the
    // same email can start a new workspace, which will be a new one.
    if (!_isJoin && uri.queryParameters['deleted'] == '1') {
      setState(() {
        _message = 'Your account was deleted. Its sign-in and profile were '
            'erased, and it cannot be restored. You can use the same email to '
            'create a new workspace, which starts from nothing.';
        _error = null;
      });
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
    if (_pendingChallenge != null) return _EmailCodeView(state: this);

    return AuthShell(
      maxContentWidth: 1120,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 940;
          final intro = _AuthIntro(isJoin: _isJoin);
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
    );
  }

  Future<void> register() async {
    if (!_formKey.currentState!.validate()) return;

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
      );

      await AuthSessionController.instance.clear();

      if (!mounted) return;
      // ONE TRIP TO THE INBOX: the email carries a code, typed here, which
      // confirms the address and signs straight in. The link page is only
      // for a server that sent a link alone.
      if (response['requiresEmailCodeChallenge'] == true) {
        setState(() {
          _signupCode = true;
          _trustDevice = true;
          _pendingChallenge = Map<String, dynamic>.from(
              (response['challenge'] as Map?) ?? const {});
          _message = null;
        });
        return;
      }
      final email = response['email']?.toString().trim();
      context.go(_route('/auth/verify-email', sent: true, email: email));
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
      if (response['requiresEmailCodeChallenge'] == true) {
        if (_rememberEmail) {
          await AuthSessionController.instance.saveLoginEmail(_email.text);
        } else {
          await AuthSessionController.instance.clearSavedLoginEmail();
        }
        if (!mounted) return;
        setState(() {
          _pendingChallenge = Map<String, dynamic>.from(
              (response['challenge'] as Map?) ?? const {});
          _message = 'We sent a code to your email.';
        });
        return;
      }
      await _persistEmailPreference();
      await _completeClientAccess(response);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _humanize(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> verifyLoginCode() async {
    final challengeId = _pendingChallenge?['id']?.toString() ?? '';
    final code = _loginCode.text.trim();
    if (challengeId.isEmpty || code.isEmpty) {
      setState(() => _error = 'Enter the code from your email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final response = await AuthRepository().verifyClientLoginCode(
        challengeId: challengeId,
        code: code,
        trustDevice: _trustDevice,
      );
      await _persistEmailPreference();
      await _completeClientAccess(response);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _humanizeCodeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> resendLoginCode() async {
    final challengeId = _pendingChallenge?['id']?.toString() ?? '';
    if (challengeId.isEmpty) return;
    setState(() {
      _resendingVerification = true;
      _error = null;
    });
    try {
      final response =
          await AuthRepository().resendClientLoginCode(challengeId);
      if (!mounted) return;
      setState(() {
        _pendingChallenge = Map<String, dynamic>.from(
            (response['challenge'] as Map?) ?? _pendingChallenge ?? const {});
        _message = 'A fresh code has been sent.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _humanizeCodeError(error));
    } finally {
      if (mounted) setState(() => _resendingVerification = false);
    }
  }

  Future<void> _persistEmailPreference() async {
    if (_rememberEmail) {
      await AuthSessionController.instance.saveLoginEmail(_email.text);
    } else {
      await AuthSessionController.instance.clearSavedLoginEmail();
    }
  }

  void changeLoginEmail() {
    setState(() {
      _pendingChallenge = null;
      _loginCode.clear();
      _password.clear();
      _error = null;
      _message = null;
    });
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
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _humanize(error));
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  Future<void> _completeClientAccess(Map<String, dynamic> response) async {
    final session = AuthSessionController.instance;
    if (!mounted) return;

    // WHERE THEY WERE TRYING TO GO.
    //
    // Signing in is rarely the thing someone came to do. They followed a link
    // to a specific page and were interrupted by authentication; discarding
    // that destination here is what made emailed links land nowhere.
    final returnTo = readReturnTo(GoRouterState.of(context).uri.queryParameters);

    if (!session.emailVerified) {
      // Carried across the hop, not dropped at it.
      context.go(withReturnTo(
          _route('/auth/verify-email', email: session.email), returnTo));
      return;
    }

    // The account layer is deliberately reachable before setup and
    // subscription are settled — establishing authority is a precondition for
    // consequential work, not a reward for finishing onboarding.
    final destinationIsAccountLayer =
        returnTo != null && returnTo.startsWith('/account');

    if (!session.hasSetupCompleted && !destinationIsAccountLayer) {
      // /client/setup is the canonical spelling. This screen said
      // /app/setup while Today said /client/setup, so two halves of the
      // product sent people to the same screen under different names.
      context.go(withReturnTo(_route('/client/setup'), returnTo));
      return;
    }
    // NOT A SUBSCRIPTION GATE, AND NOT THE LEGACY HOME.
    //
    // The router's own gate was corrected so that a business without a plan
    // reaches its workspace — and this branch, in the screen, kept overruling
    // it at the one moment that matters. Everybody who signed in without an
    // active subscription was sent to checkout; a workspace that requires
    // payment to enter was never theirs to begin with. Setup still gates
    // above, because Orchestrate genuinely cannot present a coherent workspace
    // before it knows what the business is. Money is a different authority.
    //
    // And the landing is Today. /app/home is the pre-reconstruction home: it
    // renders inside the new shell with none of the four destinations
    // selected, so a person lands somewhere that cannot say where it is, and
    // the only way onward is to notice the rail.
    context.go(returnTo ?? '/client/today');
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
        if (sent) 'sent': '1',
        if (email != null && email.isNotEmpty) 'email': email,
      },
    ).toString();
  }

  String _humanize(Object error) {
    final text = error.toString().toLowerCase();
    final api = error is ApiException ? error : null;

    // Transport problems never reach the server — surface them as such
    // rather than collapsing into a generic "request failed" message.
    if (api == null &&
        (text.contains('socketexception') ||
            text.contains('clientexception') ||
            text.contains('failed host lookup') ||
            text.contains('connection refused') ||
            text.contains('connection closed') ||
            text.contains('network is unreachable') ||
            text.contains('xmlhttprequest'))) {
      return 'We could not reach Orchestrate. Check your internet connection and try again.';
    }
    if (text.contains('timeout') || text.contains('timed out')) {
      return 'The request timed out. Check your connection and try again.';
    }

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

    // Account exists but email is not yet confirmed — the most common
    // new-account dead end. Point the reviewer/user at the next step.
    if (text.contains('verify your email') ||
        text.contains('email not verified') ||
        text.contains('not verified') ||
        text.contains('email_not_verified')) {
      return 'Please verify your email first. Open the confirmation link we '
          'emailed you, then sign in. You can request a fresh link from the '
          'verify-email screen.';
    }
    if (text.contains('incorrect') || text.contains('did not match')) {
      return 'That email or password did not match our records.';
    }
    if (text.contains('already exists')) {
      return 'An account with this email already exists. Try signing in instead.';
    }
    if (text.contains('too many') ||
        text.contains('rate limit') ||
        api?.statusCode == 429) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (text.contains('expired')) {
      return 'That link has expired. Request a fresh one and try again.';
    }
    if (text.contains('invalid')) {
      return 'That link is not valid anymore.';
    }

    // Known server responses: prefer the backend's own actionable message;
    // 5xx gets a calm retry message carrying a support reference.
    if (api != null) {
      if (api.statusCode >= 500) {
        final ref = api.displayId;
        return 'Something went wrong on our end. Please try again in a moment.'
            '${ref.isNotEmpty ? ' Reference: $ref' : ''}';
      }
      final msg = api.message.trim();
      if (msg.isNotEmpty &&
          msg.toLowerCase() != 'request failed' &&
          msg.length <= 160) {
        return msg;
      }
    }
    return 'We could not complete that request. Please try again, or contact '
        'support if it keeps happening.';
  }

  String _humanizeCodeError(Object error) {
    final text = error.toString().toLowerCase();
    final api = error is ApiException ? error : null;
    if (api == null &&
        (text.contains('socketexception') ||
            text.contains('clientexception') ||
            text.contains('failed host lookup') ||
            text.contains('connection refused') ||
            text.contains('network is unreachable') ||
            text.contains('xmlhttprequest'))) {
      return 'We could not reach Orchestrate. Check your connection and try again.';
    }
    if (text.contains('timeout') || text.contains('timed out')) {
      return 'The request timed out. Check your connection and try again.';
    }
    // The server answers "Invalid or expired" for any refused code, so a
    // mistyped code must not be told it expired.
    if (text.contains('invalid') || text.contains('expired')) {
      return 'That code did not work. Check it, or send a fresh one.';
    }
    if (text.contains('too many') ||
        text.contains('wait') ||
        api?.statusCode == 429) {
      return 'Please wait before requesting another code.';
    }
    if (api != null && api.statusCode >= 500) {
      final ref = api.displayId;
      return 'Something went wrong on our end. Please try again in a moment.'
          '${ref.isNotEmpty ? ' Reference: $ref' : ''}';
    }
    return 'We could not verify that code. Please try again.';
  }
}

class _AuthIntro extends StatelessWidget {
  const _AuthIntro({required this.isJoin});

  final bool isJoin;

  // DD-26 (board S05): what happens next, in three steps, and what it costs
  // to start: nothing.
  @override
  Widget build(BuildContext context) {
    Widget step(String n, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  color: Ob.ink, shape: BoxShape.circle),
              child: Text(n, style: Ob.figure(13, color: Ob.onInk)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Ob.strong(16)),
                  const SizedBox(height: 3),
                  Text(body, style: Ob.body(14.5)),
                ],
              ),
            ),
          ]),
        );
    if (!isJoin) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ObHeadline('Welcome back.', size: 48),
          const SizedBox(height: 14),
          Text('Whatever is waiting for your yes is on the first screen.',
              style: Ob.body(17)),
          const SizedBox(height: 22),
          _IntroPoint(
            title: 'Access choices',
            body: _ClientLoginScreenState._googleSignInAvailable
                ? 'Sign in with your email or with Google. Either one reaches '
                    'the same workspace.'
                : 'Sign in with your work email.',
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ObHeadline('Six minutes to set up. Then Orchestrate starts looking.',
            size: 48),
        const SizedBox(height: 26),
        step('1', 'Create your workspace', 'Free. No card needed.'),
        step('2', 'Say what you sell and who buys it',
            'That is the market Orchestrate searches.'),
        step('3', 'Connect your email',
            'Notes go out from your address. Replies land in your inbox.'),
      ],
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
        Text(title, style: Ob.strong(16)),
        const SizedBox(height: 4),
        Text(body, style: Ob.body(14.5)),
      ],
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({required this.state});
  final _ClientLoginScreenState state;

  @override
  Widget build(BuildContext context) {
    final canUseGoogle = _ClientLoginScreenState._googleSignInAvailable;
    return Container(
      decoration: BoxDecoration(
        color: Ob.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Ob.liftHigh,
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Form(
          key: state._formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state._isJoin
                    ? 'Create your workspace'
                    : 'Sign in to your workspace',
                style: Ob.name(26),
              ),
              const SizedBox(height: 10),
              Text(
                state._isJoin
                    ? 'Setting up is free. You choose a plan when you want '
                        'Orchestrate to start finding businesses and sending '
                        'notes; cancel any time.'
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
                    onPressed: (state._busy || state._googleBusy)
                        ? null
                        : state.loginWithGoogle,
                    icon: state._googleBusy
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
                _Field(controller: state._company, label: 'Business name'),
                const SizedBox(height: 14),
                _Field(
                  controller: state._password,
                  label: 'Password',
                  obscure: state._obscurePassword,
                  onSubmitted: state._busy ? null : state.register,
                  suffixIcon: IconButton(
                    onPressed: () => state.setState(
                      () => state._obscurePassword = !state._obscurePassword,
                    ),
                    icon: Icon(
                      state._obscurePassword
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
                      state._busy
                          ? 'Creating workspace...'
                          : 'Create workspace, free',
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
                        onPressed: () =>
                            context.go(state._route('/auth/login')),
                        child: const Text('Sign in'),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // TYPING WAS BEING THROWN AWAY HERE, ON THE SIGN IN PATH.
                //
                // Found on a physical Pixel, not in the code. The remember
                // email checkbox used to sit between these two fields. Typing
                // an email and pressing the keyboard's NEXT key — which is
                // what the keyboard offers, and what people press — moved
                // focus to the CHECKBOX, so the password typed after it went
                // nowhere and the field stayed empty. No error, nothing to
                // explain it, on the way into the product.
                //
                // Every handler here was non-null and every field had a
                // controller, so no amount of reading this file would have
                // shown it. It took using the form on a phone.
                //
                // Two things were wrong and both are fixed. The option no
                // longer interrupts the credential pair — it is about what
                // happens after signing in, so it belongs beside the act, not
                // inside it. And NEXT now names its destination rather than
                // trusting whatever happens to be rendered next.
                _Field(
                  controller: state._email,
                  label: 'Work email',
                  keyboardType: TextInputType.emailAddress,
                  nextFocus: state._passwordFocus,
                ),
                const SizedBox(height: 14),
                _Field(
                  controller: state._password,
                  focusNode: state._passwordFocus,
                  label: 'Password',
                  obscure: state._obscurePassword,
                  onSubmitted: state._busy ? null : state.login,
                  suffixIcon: IconButton(
                    onPressed: () => state.setState(
                      () => state._obscurePassword = !state._obscurePassword,
                    ),
                    icon: Icon(
                      state._obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: state._rememberEmail,
                  onChanged: (value) => state.setState(
                    () => state._rememberEmail = value == true,
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Save email on this device'),
                  subtitle: const Text('Your password is never saved.'),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: state._requestingReset
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
                // A person can create a workspace here, on every platform.
                //
                // iOS used to get a note saying accounts are set up on the web
                // instead. That was written for §3.1.1 when the app could not
                // take a payment, so signup led to a web checkout. In-app
                // purchase is wired now, so the restriction buys nothing and
                // costs the obvious thing: nobody could start on an iPhone,
                // App Review included.
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
                        onPressed: () =>
                            context.go(state._route('/auth/join')),
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

class _EmailCodeView extends StatelessWidget {
  const _EmailCodeView({required this.state});
  final _ClientLoginScreenState state;

  @override
  Widget build(BuildContext context) {
    final challenge = state._pendingChallenge ?? const {};
    final email = challenge['email']?.toString() ?? 'your email';
    final signup = state._signupCode;
    return AuthShell(
      maxContentWidth: 520,
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
        decoration: BoxDecoration(
          color: Ob.card,
          borderRadius: BorderRadius.circular(Ob.radiusPanel),
          boxShadow: Ob.liftLow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ObHeadline(signup ? 'Confirm your email.' : 'Check your email.',
                size: 32),
            const SizedBox(height: 10),
            Text(
              signup
                  ? 'We sent a 6-digit code to $email. Type it here and you are in.'
                  : 'We sent a 6-digit code to $email. Type it here to sign in.',
              style: Ob.body(16),
            ),
            const SizedBox(height: 22),
            if (state._error != null)
              _Banner(message: state._error!, error: true)
            else if (state._message != null)
              _Banner(message: state._message!, error: false),
            _Field(
              controller: state._loginCode,
              label: 'Code',
              autofocus: true,
              keyboardType: TextInputType.number,
              onSubmitted: state._busy ? null : state.verifyLoginCode,
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: state._trustDevice,
              onChanged: (value) => state.setState(
                () => state._trustDevice = value == true,
              ),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('Remember this device for 60 days',
                  style: Ob.body(14.5, color: Ob.ink)),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: state._busy ? null : state.verifyLoginCode,
              child: Text(state._busy
                  ? 'Checking…'
                  : signup
                      ? 'Confirm and continue'
                      : 'Sign in'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed: state._resendingVerification
                      ? null
                      : state.resendLoginCode,
                  child: Text(state._resendingVerification
                      ? 'Sending…'
                      : 'Send a new code'),
                ),
                TextButton(
                  onPressed: state._busy ? null : state.changeLoginEmail,
                  child: const Text('Use another email'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One focused card on paper, the same for every step that is not the
/// sign-in form itself (DD-27). The header already carries the brand, so the
/// card does not repeat the logo.
class _AuthPanel extends StatelessWidget {
  const _AuthPanel({required this.title, required this.lead, required this.children});
  final String title;
  final String lead;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      maxContentWidth: 520,
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
        decoration: BoxDecoration(
          color: Ob.card,
          borderRadius: BorderRadius.circular(Ob.radiusPanel),
          boxShadow: Ob.liftLow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ObHeadline(title, size: 32),
            const SizedBox(height: 10),
            Text(lead, style: Ob.body(16)),
            const SizedBox(height: 22),
            ...children,
          ],
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
    final done = state._verificationComplete;
    final canResend = state._verificationEmail != null;
    return _AuthPanel(
      title: done ? 'Your email is confirmed.' : 'Confirm your email.',
      lead: done
          ? 'Sign in to carry on where you left off.'
          : canResend
              ? 'Open the email we sent to ${state._verificationEmail} and type the '
                  'code, or open its link.'
              : 'Open the email we sent and type the code, or open its link. If it '
                  'has expired, sign in and we will send a new one.',
      children: [
        if (state._error != null)
          _Banner(message: state._error!, error: true)
        else if (state._message != null)
          _Banner(message: state._message!, error: false),
        FilledButton(
          onPressed: () => context.go(state._route('/auth/login')),
          child: const Text('Sign in'),
        ),
        if (!done) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 4, children: [
            if (canResend)
              TextButton(
                onPressed: state._resendingVerification || state._busy
                    ? null
                    : state.resendVerification,
                child: Text(state._resendingVerification ? 'Sending…' : 'Send a new email'),
              ),
            TextButton(
              onPressed: () => context.go(state._route('/auth/register')),
              child: const Text('Use another email'),
            ),
          ]),
        ],
      ],
    );
  }
}

class _ResetView extends StatelessWidget {
  const _ResetView({required this.state});
  final _ClientLoginScreenState state;

  @override
  Widget build(BuildContext context) {
    return _AuthPanel(
      title: 'Choose a new password.',
      lead: 'At least 8 characters. Then sign in with it.',
      children: [
        if (state._error != null)
          _Banner(message: state._error!, error: true)
        else if (state._message != null)
          _Banner(message: state._message!, error: false),
        _Field(
          controller: state._resetPassword,
          label: 'New password',
          autofocus: true,
          obscure: state._obscureResetPassword,
          onSubmitted: state._busy ? null : state.submitReset,
          suffixIcon: IconButton(
            onPressed: () => state.setState(
              () => state._obscureResetPassword = !state._obscureResetPassword,
            ),
            icon: Icon(
              state._obscureResetPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: state._busy ? null : state.submitReset,
          child: Text(state._busy ? 'Saving…' : 'Save new password'),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => context.go(state._route('/auth/login')),
            child: const Text('Back to sign in'),
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.obscure = false,
    this.suffixIcon,
    this.onSubmitted,
    this.focusNode,
    this.nextFocus,
    this.autofocus = false,
  });

  /// Takes the cursor when it appears: the one field a screen is for.
  final bool autofocus;

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffixIcon;

  /// What Enter does. Absent on a field that is not the last one in its form.
  final VoidCallback? onSubmitted;

  final FocusNode? focusNode;

  /// Where NEXT goes, named rather than left to ambient traversal.
  ///
  /// Traversal hands focus to whatever is next in the tree, which on the sign
  /// in form was a checkbox — see the note at the remember-email option. A
  /// field that knows its successor cannot be broken by something rendered
  /// between them.
  final FocusNode? nextFocus;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      keyboardType: keyboardType,
      obscureText: obscure,
      // ENTER SUBMITS.
      //
      // Nothing in this form handled it, on any screen: sign in, create a
      // workspace, or reset a password. A person typed their password, pressed
      // Enter, and the page sat there — no request, no error, nothing to
      // explain it. Signing in with the keyboard is how most people sign in.
      textInputAction:
          onSubmitted != null ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: onSubmitted != null
          ? (_) => onSubmitted!()
          : nextFocus != null
          ? (_) => nextFocus!.requestFocus()
          : null,
      validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '$label is required.';
              }
              if (label.toLowerCase().contains('email') &&
                  !value.contains('@')) {
                return 'Enter a valid email address.';
              }
              return null;
            },
      decoration: InputDecoration(
        suffixIcon: suffixIcon,
      ),
    );
    // The label sits above the field, so it is still there once something
    // is typed (the theme never floats labels).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Ob.strong(14.5)),
        const SizedBox(height: 6),
        field,
      ],
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
        color: error ? Ob.refusedSoft : Ob.track,
        borderRadius: BorderRadius.circular(14),
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
