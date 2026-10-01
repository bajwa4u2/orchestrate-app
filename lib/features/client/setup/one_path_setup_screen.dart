import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/ob.dart';
import '../../../core/ui/ob_widgets.dart';
import '../../../core/ui/screen_memory.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../core/commercial/commercial_model.dart';
import '../../../core/platform/billing_gate.dart';
import '../../../data/repositories/client/client_billing_repository.dart';
import '../../../data/repositories/client/client_business_identity_repository.dart';
import '../../../data/repositories/client/client_campaign_repository.dart';
import '../../../data/repositories/client/client_mailbox_repository.dart';
import '../../../data/repositories/client/client_outreach_repository.dart';
import '../../../data/repositories/client/client_representative_repository.dart';
import '../../../data/setup/buyer_suggestions.dart';
import '../../../data/setup/global_setup_options.dart';
import '../screens/client_setup_screen.dart' show metroSuggestionsFor;
import '../widgets/smtp_connect_dialog.dart';

/// GETTING READY: ONE PATH (DD-26, founder, 2026-09-30).
///
/// A customer spent a week unable to finish setup. What stopped people was
/// never one bug but the shape of the thing:
///
///   * the same facts were asked twice, on two screens, in two formats;
///   * the order changed depending on which screen was asking;
///   * every refusal read "We could not save your setup at the moment", while
///     the server had said exactly what was wrong;
///   * saving one section silently threw away what was typed in the others;
///   * the domain check waited on a button nobody knew to press.
///
/// So this is one path in one order, and it follows five rules:
///
///   1. A fact is asked once, and wherever the product needs it is filled
///      from that one answer.
///   2. Continue saves the step, and nothing typed is ever lost. A draft of
///      every field is kept on the device until the server has it.
///   3. A refusal shows the server's own reason, beside the field.
///   4. Waiting is never a wall. The domain check runs on its own, and the
///      plan comes last.
///   5. What the step means is said in plain words, next to it.
///
/// Every state shown here is read from the server: the business identity,
/// the setup record, the mailbox snapshot, the sending domain and execution
/// eligibility. Nothing is inferred to look finished.
// DD-27: "permission" is now the last step, "Who acts for this business"; the
// name stays so older links and drafts keep working.
enum SetupStep { business, want, offer, email, plan, permission, ready }

extension on SetupStep {
  String get key => name;
  int get number => index + 1;
  String get title => const [
        'Your business',
        'Who you want',
        'What you offer',
        'Your email',
        'Your plan',
        'Who acts for it',
        'Ready',
      ][index];
  String get subtitle => const [
        'Name, website, address',
        'Buyers and where they are',
        'One sentence, in your words',
        'Where notes are sent from',
        'Only when you want to send',
        'You, your document, your yes',
        '',
      ][index];
}

SetupStep? _stepFromKey(String? key) {
  if (key == 'act') return SetupStep.permission;
  for (final s in SetupStep.values) {
    if (s.key == key) return s;
  }
  return null;
}

/// Where a step stands, according to the server.
enum StepState { todo, done, waiting }

class OnePathSetupScreen extends StatefulWidget {
  const OnePathSetupScreen(
      {super.key, this.initialStep, this.oauthStatus, this.oauthReason, this.checkoutStatus});

  /// From `?step=`; when absent the first unfinished step opens.
  final String? initialStep;

  /// Set when a mailbox sign-in started here has just come back.
  final String? oauthStatus;
  final String? oauthReason;

  /// `success` or `canceled`, set by Stripe's return to the plan step.
  final String? checkoutStatus;

  /// A test seam, so every step can be rendered and read as a person would
  /// see it: the seven answers `_load` would otherwise fetch, in its order
  /// (profile, setup, mailbox snapshot, domain, eligibility, providers,
  /// pricing). Nothing in the app sets it.
  @visibleForTesting
  static List<dynamic>? debugSeed;

  @override
  State<OnePathSetupScreen> createState() => _OnePathSetupScreenState();
}

class _OnePathSetupScreenState extends State<OnePathSetupScreen> {
  final _identity = ClientBusinessIdentityRepository();
  final _auth = AuthRepository();
  final _mailbox = ClientMailboxRepository();
  final _outreach = ClientOutreachRepository();
  final _campaign = ClientCampaignRepository();
  final _representative = ClientRepresentativeRepository();

  bool _loading = true;
  String? _loadFailure;
  SetupStep _step = SetupStep.business;
  bool _busy = false;
  DateTime? _savedAt;

  // Step 1
  final _name = TextEditingController();
  final _website = TextEditingController();
  final _line1 = TextEditingController();
  final _city = TextEditingController();
  final _postcode = TextEditingController();
  String? _industryCode;
  String _addressCountry = '';
  Map<String, String> _fieldErrors = {};
  String? _stepError;

  // Step 2
  final List<String> _buyerKinds = [];
  final Set<String> _countries = {};
  final Set<String> _regions = {};
  final List<String> _towns = [];

  // Step 4: one address; a password only where the provider needs one.
  final _address = TextEditingController();
  final _appPassword = TextEditingController();
  final _server = TextEditingController();
  Map<String, dynamic>? _recognised;

  // Step 3
  final _offer = TextEditingController();
  String _lane = 'opportunity';

  // Server truth
  Map<String, dynamic> _profile = const {};
  Map<String, dynamic> _snapshot = const {};
  Map<String, dynamic> _domain = const {};
  Map<String, dynamic> _eligibility = const {};
  List<Map<String, dynamic>> _providers = const [];
  CommercialModel? _pricing;

  // Last step: who acts for this business.
  Map<String, dynamic> _representativeState = const {};
  Map<String, dynamic>? _document;
  final Set<String> _actAreas = {'COMMUNICATION', 'CONTRACTUAL', 'FINANCIAL'};
  List<int>? _pickedBytes;
  String? _pickedName;

  /// The cadence picked on the plan step; monthly until the owner picks.
  String _cadence = 'MONTHLY';

  /// Back from a paid checkout and waiting for the payment to be recorded.
  bool _awaitingPayment = false;
  Timer? _paymentPoll;
  bool _setupCompleted = false;
  bool _planDeferred = false;
  Timer? _domainPoll;
  Timer? _draftTimer;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _website, _line1, _city, _postcode, _offer]) {
      c.addListener(_keepDraft);
    }
    // The address they signed up with is usually the one notes come from.
    _address.text = AuthSessionController.instance.email.trim();
    _load();
  }

  @override
  void dispose() {
    _paymentPoll?.cancel();
    _domainPoll?.cancel();
    _draftTimer?.cancel();
    for (final c in [
      _name, _website, _line1, _city, _postcode, _offer,
      _address, _appPassword, _server,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Loading ────────────────────────────────────────────────────────

  Map<String, dynamic> _map(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, v) => MapEntry('$k', v));
    return <String, dynamic>{};
  }

  List<dynamic> _list(dynamic v) => v is List ? v : const [];
  String _text(Map<String, dynamic> m, String k) => (m[k] ?? '').toString().trim();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailure = null;
    });
    try {
      final results = OnePathSetupScreen.debugSeed ??
          await Future.wait<dynamic>([
        _identity.fetchProfile(),
        _auth.fetchClientSetup().catchError((_) => <String, dynamic>{}),
        _mailbox
            .fetchInfrastructureSnapshot()
            .catchError((_) => <String, dynamic>{}),
        _mailbox.fetchSendingDomain(),
        _outreach
            .fetchExecutionEligibility()
            .catchError((_) => <String, dynamic>{}),
        _mailbox.fetchProviderAvailability(),
        ClientBillingRepository()
            .fetchCommercialModel()
            .then<CommercialModel?>((m) => m)
            .catchError((_) => null),
        _representative.fetchCurrent().catchError((_) => <String, dynamic>{}),
        _representative.documentStatus().catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted) return;
      final rawProfile = _map(results[0]);
      final profile = _map(rawProfile['profile']).isNotEmpty
          ? _map(rawProfile['profile'])
          : rawProfile;
      final setupResponse = _map(results[1]);
      final setup = _map(setupResponse['setup']);
      final session = AuthSessionController.instance;
      final draft = _map(_map(session.setupDraft)['onePath']);

      setState(() {
        _profile = profile;
        _snapshot = _map(results[2]);
        _domain = _map(results[3]);
        _eligibility = _map(results[4]);
        _providers = List<Map<String, dynamic>>.from(
            _list(results[5]).map(_map));
        _pricing = results[6] as CommercialModel?;
        _setupCompleted = session.hasSetupCompleted;
        _planDeferred = draft['planDeferred'] == true;
        _hydrate(profile, setup, draft);
        if (results.length > 8) {
          _representativeState = _map(_map(results[7])['readiness']);
          final doc = _map(results[8])['document'];
          _document = doc is Map ? _map(doc) : null;
        }
        _step = _stepFromKey(widget.initialStep) ?? _firstOpenStep();
        if (widget.oauthStatus == 'error') {
          _stepError = _oauthReason(widget.oauthReason);
        } else if (widget.oauthStatus == 'success') {
          _markSaved();
        }
        _loading = false;
      });
      _schedulePollIfWaiting();
      if (widget.checkoutStatus == 'success' && !_planActive) _awaitPayment();
      // Back from the provider with an address on the business's own domain:
      // prepare its records at once rather than asking for another press.
      if (widget.oauthStatus == 'success' && _emailConnected &&
          !_personalMailbox && !_domainAttached) {
        await _attachDomain();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailure = _reasonFor(error,
            fallback: 'Setup could not be loaded just now. Your answers are '
                'safe. Try again in a moment.');
      });
    }
  }

  /// Server first; the on-device draft only fills what the server lacks, so
  /// typing that never reached the server is still here after a reload.
  void _hydrate(Map<String, dynamic> p, Map<String, dynamic> setup,
      Map<String, dynamic> draft) {
    String pick(String server, String key) =>
        server.isNotEmpty ? server : (draft[key] ?? '').toString();
    _name.text = pick(_text(p, 'displayName'), 'name');
    _website.text = pick(_text(p, 'websiteUrl'), 'website');
    final address = _map(p['postalAddress']);
    _line1.text = pick(_text(address, 'line1'), 'line1');
    _city.text = pick(_text(address, 'locality'), 'city');
    _postcode.text = pick(_text(address, 'postalCode'), 'postcode');
    _addressCountry = pick(_text(address, 'countryCode'), 'addressCountry')
        .toUpperCase();

    final industryLabel = _text(p, 'industry');
    _industryCode = GlobalSetupOptions.industries
            .where((o) =>
                o.label.toLowerCase() == industryLabel.toLowerCase() ||
                o.code == industryLabel)
            .map((o) => o.code)
            .firstOrNull ??
        _list(setup['industries'])
            .map(_map)
            .map((m) => (m['code'] ?? '').toString())
            .where((c) => c.isNotEmpty)
            .firstOrNull ??
        (draft['industryCode'] as String?);

    final icp = _map(p['icp']);
    _buyerKinds
      ..clear()
      ..addAll(_list(icp['industryTags']).map((e) => '$e').where((e) => e.isNotEmpty));
    if (_buyerKinds.isEmpty) {
      _buyerKinds.addAll(_list(draft['buyerKinds']).map((e) => '$e'));
    }
    _countries
      ..clear()
      ..addAll(_list(setup['countries'])
          .map((c) => c is Map ? '${c['code']}' : '$c')
          .map((c) => c.toUpperCase())
          .where((c) => c.isNotEmpty));
    if (_countries.isEmpty) {
      _countries.addAll(_list(draft['countries']).map((e) => '$e'));
    }
    _regions
      ..clear()
      ..addAll(_list(setup['regions'])
          .map((r) => r is Map ? '${r['regionCode'] ?? r['code']}' : '$r')
          .where((c) => c.isNotEmpty));
    if (_regions.isEmpty) {
      _regions.addAll(_list(draft['regions']).map((e) => '$e'));
    }
    _towns
      ..clear()
      ..addAll(_list(setup['metros'])
          .map((m) => m is Map ? '${m['label']}' : '$m')
          .where((c) => c.isNotEmpty));
    if (_towns.isEmpty) _towns.addAll(_list(draft['towns']).map((e) => '$e'));

    _offer.text = pick(_text(p, 'outboundOffer'), 'offer');
    final lane = (setup['serviceType'] ?? setup['selectedPlan'] ?? draft['lane'] ?? '')
        .toString()
        .toLowerCase();
    _lane = lane == 'revenue' ? 'revenue' : 'opportunity';
    if (_addressCountry.isEmpty && _countries.length == 1) {
      _addressCountry = _countries.first;
    }
    // Starting points, never overwriting anything typed: the website from
    // a work address's domain, the country from this device's region.
    if (_website.text.trim().isEmpty) {
      final email = AuthSessionController.instance.email.trim().toLowerCase();
      final at = email.lastIndexOf('@');
      final domain = at < 0 ? '' : email.substring(at + 1);
      if (domain.contains('.') && !_freeMailDomains.contains(domain)) {
        _website.text = domain;
      }
    }
    if (_addressCountry.isEmpty) {
      final region = WidgetsBinding.instance.platformDispatcher.locale.countryCode;
      if (region != null && GlobalSetupOptions.countryByCode(region) != null) {
        _addressCountry = region;
      }
    }
  }

  /// Personal mailboxes: their domain is nobody's business website.
  static const _freeMailDomains = {
    'gmail.com', 'googlemail.com', 'outlook.com', 'hotmail.com', 'live.com',
    'msn.com', 'yahoo.com', 'icloud.com', 'me.com', 'aol.com', 'proton.me',
    'protonmail.com', 'gmx.com', 'zoho.com', 'yandex.com', 'mail.com',
  };

  String _oauthReason(String? raw) {
    switch ((raw ?? '').trim()) {
      case 'access_denied':
      case 'user_denied':
        return 'The sign-in was declined, so nothing was connected. Press '
            'Continue to try again.';
      case 'missing_code_or_state':
        return 'The sign-in window closed before it finished. Press Continue '
            'to try again.';
      default:
        return 'The sign-in did not finish, so nothing was connected. Press '
            'Continue to try again.';
    }
  }

  void _keepDraft() {
    // The side card previews what is typed (the footer, the first note), so
    // it is redrawn with each keystroke, not only on the next step.
    if (mounted && !_loading) setState(() {});
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 600), _writeDraft);
  }

  Future<void> _writeDraft() async {
    final session = AuthSessionController.instance;
    final all = Map<String, dynamic>.from(session.setupDraft ?? const {});
    all['onePath'] = <String, dynamic>{
      'name': _name.text,
      'website': _website.text,
      'line1': _line1.text,
      'city': _city.text,
      'postcode': _postcode.text,
      'addressCountry': _addressCountry,
      'industryCode': _industryCode,
      'buyerKinds': _buyerKinds,
      'countries': _countries.toList(),
      'regions': _regions.toList(),
      'towns': _towns,
      'offer': _offer.text,
      'lane': _lane,
      'planDeferred': _planDeferred,
      // Read by the OAuth return screen: a connect started here comes back here.
      'returnToSetup': _step != SetupStep.ready,
    };
    await session.saveSetupDraft(all);
  }

  // ── What the server says about each step ───────────────────────────

  bool get _addressUsable =>
      _line1.text.trim().isNotEmpty &&
      _addressCountry.isNotEmpty &&
      (_city.text.trim().isNotEmpty || _postcode.text.trim().isNotEmpty);

  Map<String, dynamic> get _transport => _map(_snapshot['transport']);
  Map<String, dynamic> get _mailboxInfo => _map(_transport['mailbox']);
  bool get _emailConnected => _transport['clientAuthorized'] == true;
  bool get _personalMailbox =>
      (_snapshot['identityClass'] ?? '').toString() == 'PERSONAL_PROVIDER';
  String get _mailboxAddress => (_mailboxInfo['address'] ?? '').toString();
  String get _mailboxDomain {
    final at = _mailboxAddress.indexOf('@');
    return at < 0 ? '' : _mailboxAddress.substring(at + 1).toLowerCase();
  }

  bool get _domainAttached {
    final status = (_domain['status'] ?? '').toString().toLowerCase();
    return _domain.isNotEmpty &&
        status != 'no_domain' &&
        (_domain['domain'] ?? '').toString().trim().isNotEmpty;
  }

  bool get _domainReady => _domain['ready'] == true;

  List<Map<String, dynamic>> get _blockers =>
      _list(_eligibility['blockers']).map(_map).toList();

  static const _planCodes = {
    'PLAN_ACTIVATION_REQUIRED',
    'EXECUTION_SERVICE_NOT_ACTIVATED',
    'SUBSCRIPTION_BLOCKED',
    'SUBSCRIPTION_REQUIRED',
    'PLAN_LAPSED',
  };

  bool get _planActive =>
      _eligibility.isNotEmpty &&
      !_blockers.any((b) => _planCodes.contains((b['code'] ?? '').toString()));

  StepState _stateOf(SetupStep s) {
    switch (s) {
      case SetupStep.business:
        final p = _profile;
        final ok = _text(p, 'displayName').isNotEmpty &&
            _text(p, 'websiteUrl').isNotEmpty &&
            _text(p, 'industry').isNotEmpty &&
            _map(p['postalAddress']).isNotEmpty &&
            _text(_map(p['postalAddress']), 'line1').isNotEmpty;
        return ok ? StepState.done : StepState.todo;
      case SetupStep.want:
        final icp = _map(_profile['icp']);
        return _setupCompleted &&
                _list(icp['industryTags']).isNotEmpty &&
                _list(icp['geoTargets']).isNotEmpty
            ? StepState.done
            : StepState.todo;
      case SetupStep.offer:
        return _setupCompleted && _text(_profile, 'outboundOffer').isNotEmpty
            ? StepState.done
            : StepState.todo;
      case SetupStep.email:
        if (!_emailConnected) return StepState.todo;
        if (_personalMailbox || _domainReady) return StepState.done;
        return StepState.waiting;
      case SetupStep.permission:
        // Done when both records stand: Orchestrate may write for the
        // business, and the business recognises who decides. Waiting while
        // the document is checked.
        final authority = (_map(_representativeState['organizationalAuthority'])['state'] ?? '')
            .toString();
        if (_profile['representationAuthorized'] == true && authority == 'ESTABLISHED') {
          return StepState.done;
        }
        if (_profile['representationAuthorized'] == true &&
            (authority == 'UNDER_REVIEW' || (_document ?? const {}).isNotEmpty)) {
          return StepState.waiting;
        }
        return StepState.todo;
      case SetupStep.plan:
        // Putting the plan off is a choice, not a plan: it waits, never ticks.
        return _planActive
            ? StepState.done
            : _planDeferred
                ? StepState.waiting
                : StepState.todo;
      case SetupStep.ready:
        return StepState.todo;
    }
  }

  SetupStep _firstOpenStep() {
    for (final s in SetupStep.values.take(6)) {
      if (_stateOf(s) == StepState.todo) return s;
    }
    return SetupStep.ready;
  }

  int get _doneCount => SetupStep.values
      .take(6)
      .where((s) => _stateOf(s) == StepState.done)
      .length;

  void _schedulePollIfWaiting() {
    _domainPoll?.cancel();
    if (_stateOf(SetupStep.email) != StepState.waiting) return;
    // The server re-checks pending domains every five minutes. Reading its
    // answer on the same rhythm means the tick turns green without anyone
    // having to know there was a button.
    _domainPoll = Timer.periodic(const Duration(minutes: 1), (_) async {
      final d = await _mailbox.fetchSendingDomain();
      if (!mounted) return;
      setState(() => _domain = d);
      if (_domainReady) _domainPoll?.cancel();
    });
  }

  // ── Navigation ─────────────────────────────────────────────────────

  /// The last step opens only once every step before it is done or waiting.
  bool get _actUnlocked => SetupStep.values
      .take(SetupStep.permission.index)
      .every((s) => _stateOf(s) != StepState.todo);

  void _goTo(SetupStep s) {
    setState(() {
      // Buyers are usually in the business's own country: start there.
      if (s == SetupStep.want && _countries.isEmpty && _addressCountry.isNotEmpty) {
        _countries.add(_addressCountry);
      }
      _step = s;
      _stepError = null;
      _fieldErrors = {};
    });
    _writeDraft();
    // Keep the address honest so a reload lands on the same step.
    final router = GoRouter.maybeOf(context);
    router?.replace('/client/setup?step=${s.key}');
  }

  SetupStep _next(SetupStep s) {
    // After a save, the next step still to do; ready once nothing is left.
    for (final candidate in SetupStep.values.skip(s.index + 1).take(6)) {
      if (candidate == SetupStep.ready) break;
      if (_stateOf(candidate) != StepState.done) return candidate;
    }
    return _firstOpenStep();
  }

  void _markSaved() => _savedAt = DateTime.now();

  String _reasonFor(Object error, {required String fallback}) {
    if (error is ApiException) {
      final m = error.message.trim();
      if (error.statusCode >= 400 &&
          error.statusCode < 500 &&
          error.statusCode != 401 &&
          m.isNotEmpty &&
          m != 'Request failed' &&
          !m.startsWith('{')) {
        return m;
      }
      if (error.statusCode == 401) {
        return 'Your session has ended. Sign in again and you will come back '
            'to this step with everything you typed.';
      }
    }
    final t = error.toString();
    if (t.contains('SocketException') || t.contains('Failed host')) {
      return 'We could not reach Orchestrate. Check your connection; what you '
          'typed is kept on this device.';
    }
    return fallback;
  }

  /// Puts a server reason under the field it is about, when it names one.
  Map<String, String> _placeReason(String reason) {
    final r = reason.toLowerCase();
    if (r.contains('address') || r.contains('postal') || r.contains('postcode') || r.contains('city')) {
      return {'address': reason};
    }
    if (r.contains('website') || r.contains('url')) return {'website': reason};
    if (r.contains('name')) return {'name': reason};
    if (r.contains('industry')) return {'industry': reason};
    return const {};
  }

  // ── Saves ──────────────────────────────────────────────────────────

  Future<void> _saveBusiness() async {
    final errors = <String, String>{};
    if (_name.text.trim().isEmpty) errors['name'] = 'Add your business name.';
    if (_website.text.trim().isEmpty) {
      errors['website'] = 'Add your website, for example yourbusiness.com.';
    }
    if (_industryCode == null) {
      errors['industry'] = 'Choose what kind of business it is.';
    }
    if (_line1.text.trim().isEmpty) {
      errors['address'] = 'Add the street address. Every business email must '
          'carry a full postal address by law, so it goes in the footer of '
          'each note.';
    } else if (_city.text.trim().isEmpty && _postcode.text.trim().isEmpty) {
      errors['address'] = 'This address needs a town or a postcode.';
    } else if (_addressCountry.isEmpty) {
      errors['address'] = 'Choose the country this address is in.';
    }
    if (errors.isNotEmpty) {
      setState(() => _fieldErrors = errors);
      return;
    }
    final industry = GlobalSetupOptions.industryByCode(_industryCode);
    var website = _website.text.trim();
    if (!website.startsWith('http')) website = 'https://$website';
    setState(() {
      _busy = true;
      _fieldErrors = {};
      _stepError = null;
    });
    try {
      final existingLegal = _text(_profile, 'legalName');
      final result = await _identity.patchProfile({
        'displayName': _name.text.trim(),
        if (existingLegal.isEmpty) 'legalName': _name.text.trim(),
        'websiteUrl': website,
        if (industry != null) 'industry': industry.label,
        'postalAddress': {
          'line1': _line1.text.trim(),
          'locality': _city.text.trim(),
          'postalCode': _postcode.text.trim(),
          'countryCode': _addressCountry,
        },
      });
      final profile = _map(result['profile']);
      if (!mounted) return;
      setState(() {
        if (profile.isNotEmpty) _profile = profile;
        _busy = false;
        _markSaved();
      });
      _goTo(_next(SetupStep.business));
    } catch (error) {
      if (!mounted) return;
      final reason = _reasonFor(error,
          fallback: 'This step could not be saved just now. Nothing you typed '
              'is lost; try again in a moment.');
      setState(() {
        _busy = false;
        _fieldErrors = _placeReason(reason);
        _stepError = _fieldErrors.isEmpty ? reason : null;
      });
    }
  }

  List<Map<String, String>> _countriesPayload() => _countries
      .map((code) => GlobalSetupOptions.countryByCode(code))
      .whereType<SetupOption>()
      .map((c) => {'code': c.code, 'label': c.label})
      .toList();

  GeoRegionOption? _region(String code) {
    for (final r in GlobalSetupOptions.regionsForCountry(code.split('-').first)) {
      if (r.code == code) return r;
    }
    return null;
  }

  List<Map<String, String>> _regionsPayload() => _regions
      .map(_region)
      .whereType<GeoRegionOption>()
      .map((r) {
        final cc = r.code.split('-').first.toUpperCase();
        return {
          'countryCode': cc,
          'countryLabel': GlobalSetupOptions.countryByCode(cc)?.label ?? cc,
          'regionType': r.type,
          'regionCode': r.code,
          'regionLabel': r.label,
        };
      })
      .toList();

  /// The chosen-country area whose name this is, if any.
  String? _areaNamed(String name) {
    final n = name.toLowerCase();
    for (final cc in _countries) {
      for (final r in GlobalSetupOptions.regionsForCountry(cc)) {
        if (r.label.toLowerCase() == n) return r.code;
      }
    }
    return null;
  }

  static String _titleCase(String s) => s
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w.length <= 2 && w == w.toUpperCase()
          ? w
          : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  List<Map<String, String>> _townsPayload(List<Map<String, String>> regions) {
    if (_towns.isEmpty) return const [];
    // A town is filed under a region of its own country when one is chosen;
    // with no regions it rides on the country alone.
    return _towns.map((t) {
      final country = _countries.first;
      // Filed under a region only when exactly one was chosen in its
      // country. Taking the first of many filed every town under whichever
      // region sorted first (Alabama, for a business that picked all states).
      final inCountry = regions
          .where((r) => r['countryCode'] == country)
          .map((r) => r['regionCode']!)
          .toList();
      final region = inCountry.length == 1 ? inCountry.single : null;
      return {
        'countryCode': country,
        if (region != null) 'regionCode': region,
        'label': t,
      };
    }).toList();
  }

  String get _scopeMode {
    if (_towns.isNotEmpty) return 'precision';
    if (_countries.length > 1) return 'multi';
    return 'focused';
  }

  List<String> get _geoTargets => [
        ..._towns,
        ..._regions.map((c) => _region(c)?.label ?? c),
        ..._countries
            .map((c) => GlobalSetupOptions.countryByCode(c)?.label ?? c),
      ];

  Future<void> _postSetup() async {
    final regions = _regionsPayload();
    final industry = GlobalSetupOptions.industryByCode(_industryCode);
    final response = await _auth.saveClientSetup(
      serviceType: _lane,
      scopeMode: _scopeMode,
      countries: _countriesPayload(),
      regions: regions,
      metros: _townsPayload(regions),
      industries: [
        if (industry != null) {'code': industry.code, 'label': industry.label},
      ],
    );
    await AuthSessionController.instance.applyClientSetupResponse(response);
    _setupCompleted = AuthSessionController.instance.hasSetupCompleted;
  }

  Future<void> _saveWant() async {
    if (_buyerKinds.isEmpty) {
      setState(() => _stepError =
          'Add at least one kind of business that buys from you.');
      return;
    }
    if (_countries.isEmpty) {
      setState(() => _stepError = 'Add at least one country.');
      return;
    }
    setState(() {
      _busy = true;
      _stepError = null;
    });
    try {
      await _postSetup();
      final result = await _identity.patchProfile({
        'icp': {'industryTags': _buyerKinds, 'geoTargets': _geoTargets},
      });
      final profile = _map(result['profile']);
      if (!mounted) return;
      setState(() {
        if (profile.isNotEmpty) _profile = profile;
        _busy = false;
        _markSaved();
      });
      _goTo(_next(SetupStep.want));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _stepError = _reasonFor(error,
            fallback: 'This step could not be saved just now. Your choices '
                'are kept; try again in a moment.');
      });
    }
  }

  Future<void> _saveOffer() async {
    final offer = _offer.text.trim();
    if (offer.isEmpty) {
      setState(() => _fieldErrors = {
            'offer': 'Say what you offer in a sentence or two. Every first '
                'note is written from it.'
          });
      return;
    }
    setState(() {
      _busy = true;
      _fieldErrors = {};
      _stepError = null;
    });
    try {
      final result = await _identity.patchProfile({'outboundOffer': offer});
      if (_countries.isNotEmpty) await _postSetup();
      final profile = _map(result['profile']);
      if (!mounted) return;
      setState(() {
        if (profile.isNotEmpty) _profile = profile;
        _busy = false;
        _markSaved();
      });
      _goTo(_next(SetupStep.offer));
    } catch (error) {
      if (!mounted) return;
      final reason = _reasonFor(error,
          fallback: 'Your offer could not be saved just now. It is kept here; '
              'try again in a moment.');
      setState(() {
        _busy = false;
        _fieldErrors = {'offer': reason};
      });
    }
  }

  Future<void> _connect(String provider) async {
    setState(() {
      _busy = true;
      _stepError = null;
    });
    await _writeDraft();
    try {
      final response = await _mailbox.startMailboxOAuth(provider: provider);
      final url = (response['authorizeUrl'] ?? '').toString();
      final uri = Uri.tryParse(url);
      if (uri == null || url.isEmpty) {
        throw StateError('no authorize url');
      }
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _stepError = launched
            ? null
            : 'The sign-in page could not be opened on this device.';
      });
      if (launched) _awaitConnection();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _stepError = _reasonFor(error,
            fallback: 'Connecting could not start just now. Try again in a '
                'moment.');
      });
    }
  }

  /// After the provider's own sign-in page opens, watch for the connection to
  /// land rather than asking the person to come back and press something.
  void _awaitConnection() {
    var tries = 0;
    Timer.periodic(const Duration(seconds: 4), (t) async {
      tries++;
      if (!mounted || tries > 45) {
        t.cancel();
        return;
      }
      final snap = await _mailbox
          .fetchInfrastructureSnapshot()
          .catchError((_) => <String, dynamic>{});
      if (!mounted) return;
      if (_map(snap['transport'])['clientAuthorized'] == true) {
        t.cancel();
        final d = await _mailbox.fetchSendingDomain();
        if (!mounted) return;
        setState(() {
          _snapshot = snap;
          _domain = d;
          _markSaved();
        });
        // An address on the business's own domain goes straight on to the
        // records for it; nobody should have to ask for them.
        if (!_personalMailbox && !_domainAttached) await _attachDomain();
        _schedulePollIfWaiting();
      }
    });
  }

  Future<void> _connectOther() async {
    final saved = await SmtpConnectDialog.show(context);
    if (saved != true || !mounted) return;
    await _refreshEmail();
  }

  String get _recognisedProvider => (_recognised?['provider'] ?? '').toString();

  bool _oauthAvailable(String key) =>
      _providers.any((p) => p['key'] == key && p['available'] == true);

  /// The owner types an address; the server says who holds it. Google and
  /// Microsoft sign in on their own page; everyone else gives a password.
  Future<void> _continueWithAddress() async {
    final address = _address.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(address)) {
      setState(() => _fieldErrors = {'address': 'Type the full address, like you@yourbusiness.com.'});
      return;
    }
    setState(() {
      _busy = true;
      _stepError = null;
      _fieldErrors = {};
    });
    try {
      final r = await _mailbox.recogniseMailbox(address);
      if (!mounted) return;
      final provider = (r['provider'] ?? 'generic').toString();
      setState(() {
        _recognised = r;
        _busy = false;
        if (provider == 'generic' && _server.text.trim().isEmpty) {
          _server.text = 'mail.${(r['domain'] ?? '').toString()}';
        }
      });
      if ((provider == 'google' || provider == 'microsoft') &&
          _oauthAvailable(provider)) {
        await _connect(provider);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _stepError = _reasonFor(error,
            fallback: 'That address could not be checked just now. Try again in a moment.');
      });
    }
  }

  /// Connect with a password: the servers come from the provider, so the
  /// owner never types a port or an encryption mode. The server tries the
  /// provider's other documented endpoints itself if the first refuses.
  Future<void> _connectWithPassword() async {
    final r = _recognised ?? const {};
    final provider = _recognisedProvider.isEmpty ? 'generic' : _recognisedProvider;
    final address = _address.text.trim();
    final password = _appPassword.text;
    if (password.isEmpty) {
      setState(() => _fieldErrors = {'password': 'Enter the password for this mailbox.'});
      return;
    }
    final smtp = _map(r['smtp']);
    final imap = _map(r['imap']);
    final host = provider == 'generic' ? _server.text.trim() : '${smtp['host'] ?? ''}';
    if (host.isEmpty) {
      setState(() => _fieldErrors = {'server': 'Enter your mail server, like mail.yourbusiness.com.'});
      return;
    }
    setState(() {
      _busy = true;
      _stepError = null;
      _fieldErrors = {};
    });
    try {
      await _mailbox.connectCustomTransport(
        smtp: {
          'host': host,
          'port': smtp['port'] ?? 465,
          'secure': smtp['secure'] ?? 'tls',
          'username': address,
          'password': password,
          'fromAddress': address,
          if (AuthSessionController.instance.fullName.trim().isNotEmpty)
            'fromName': AuthSessionController.instance.fullName.trim(),
          'providerOverride': provider,
        },
        imap: {
          'host': provider == 'generic' ? host : '${imap['host'] ?? host}',
          'port': imap['port'] ?? 993,
          'secure': imap['secure'] ?? 'tls',
          'username': address,
          'password': password,
        },
      );
      _appPassword.clear();
      await _refreshEmail();
      if (!mounted) return;
      if (_emailConnected && !_personalMailbox && !_domainAttached) {
        await _attachDomain();
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _markSaved();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _stepError = _reasonFor(error,
            fallback: 'That mailbox did not accept the password. Check it and try again.');
      });
    }
  }

  Future<void> _refreshEmail() async {
    final snap = await _mailbox
        .fetchInfrastructureSnapshot()
        .catchError((_) => <String, dynamic>{});
    final d = await _mailbox.fetchSendingDomain();
    if (!mounted) return;
    setState(() {
      _snapshot = snap;
      _domain = d;
    });
    _schedulePollIfWaiting();
  }

  Future<void> _attachDomain() async {
    setState(() {
      _busy = true;
      _stepError = null;
    });
    try {
      final d = await _mailbox.attachSendingDomain(_mailboxDomain);
      if (!mounted) return;
      setState(() {
        _domain = d;
        _busy = false;
        _markSaved();
      });
      _schedulePollIfWaiting();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _stepError = _reasonFor(error,
            fallback: 'The domain could not be added just now. Try again in a '
                'moment.');
      });
    }
  }

  Future<void> _checkDomainNow() async {
    setState(() => _busy = true);
    try {
      await _mailbox.verifySendingDomain();
    } catch (_) {
      // The result is read back below either way; a refusal here only means
      // the records are not visible yet, which the table already says.
    }
    final d = await _mailbox.fetchSendingDomain();
    if (!mounted) return;
    setState(() {
      _domain = d;
      _busy = false;
    });
    _schedulePollIfWaiting();
  }

  /// Straight from the plan step to secure checkout: no second price page.
  /// A store build sends nobody out to pay, so it opens Billing, where the
  /// store's own purchase sheet lives.
  Future<void> _startCheckout() async {
    if (!externalPurchaseAllowed) {
      context.go('/client/billing');
      return;
    }
    setState(() {
      _busy = true;
      _stepError = null;
    });
    await _writeDraft();
    try {
      final response =
          await ClientBillingRepository().createSubscription(period: _cadence);
      final url = (response['checkoutUrl'] ?? '').toString();
      if (url.isEmpty) {
        // The server says why when it will not open a checkout, and that
        // sentence is the one worth showing.
        final why = (response['reason'] ?? response['message'] ?? '').toString();
        throw StateError(why.isEmpty ? 'Checkout could not open just now.' : why);
      }
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _stepError = ok ? null : 'Checkout could not open on this device.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _stepError = error is StateError
            ? error.message
            : _reasonFor(error, fallback: 'Checkout could not open just now. '
                'Try again in a moment.');
      });
    }
  }

  /// Stripe has taken the payment; its confirmation reaches us a moment later.
  /// Ask every few seconds until the plan is on, for up to three minutes.
  void _awaitPayment() {
    setState(() => _awaitingPayment = true);
    var tries = 0;
    _paymentPoll?.cancel();
    _paymentPoll = Timer.periodic(const Duration(seconds: 4), (t) async {
      tries++;
      final elig = await _outreach
          .fetchExecutionEligibility()
          .catchError((_) => <String, dynamic>{});
      if (!mounted) return t.cancel();
      setState(() => _eligibility = elig);
      if (_planActive || tries >= 45) {
        t.cancel();
        setState(() => _awaitingPayment = false);
        if (_planActive) _markSaved();
      }
    });
  }

  Future<void> _deferPlan() async {
    setState(() => _planDeferred = true);
    await _writeDraft();
    _goTo(_actUnlocked ? SetupStep.permission : SetupStep.ready);
  }

  Future<void> _signOut() async {
    try {
      await _auth.logout();
    } catch (_) {
      // Leaving must work even when the server cannot be reached.
    } finally {
      await AuthSessionController.instance.clear();
      ScreenMemory.forget();
      if (mounted) context.go('/auth/login');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Ob.theme(),
      child: Scaffold(
        backgroundColor: Ob.paper,
        body: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Ob.ink, strokeWidth: 2))
              : _loadFailure != null
                  ? _LoadFailure(message: _loadFailure!, onRetry: _load, onSignOut: _signOut)
                  : LayoutBuilder(builder: (context, c) {
                      final phone = c.maxWidth < 900;
                      return phone ? _phone(c) : _desktop(c);
                    }),
        ),
      ),
    );
  }

  Widget _desktop(BoxConstraints c) {
    final twoColumns = c.maxWidth >= 1240;
    final content = _stepContent(phone: false);
    final side = _sideCard();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Rail(
          current: _step,
          stateOf: _stateOf,
          done: _doneCount,
          savedAt: _savedAt,
          onTap: _goTo,
          onSignOut: _signOut,
        ),
        Expanded(
          // Keyed by step: every step opens at its top, not where the last
          // one was scrolled to.
          child: SingleChildScrollView(
            key: ValueKey('setup-desktop-${_step.key}'),
            padding: const EdgeInsets.fromLTRB(64, 44, 64, 44),
            child: _step == SetupStep.ready
                ? _readyView(phone: false)
                : twoColumns && side != null
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 11, child: content),
                          const SizedBox(width: 56),
                          Expanded(flex: 10, child: side),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          content,
                          if (side != null) ...[
                            const SizedBox(height: 32),
                            side,
                          ],
                        ],
                      ),
          ),
        ),
      ],
    );
  }

  Widget _phone(BoxConstraints c) {
    final side = _sideCard();
    final isReady = _step == SetupStep.ready;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 10, 0),
          child: Row(children: [
            if (_step.index > 0 && !isReady)
              TextButton.icon(
                style: TextButton.styleFrom(
                    foregroundColor: Ob.inkMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 4)),
                onPressed: () => _goTo(SetupStep.values[_step.index - 1]),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back'),
              ),
            const Spacer(),
            if (_savedAt != null) _SavedDot(savedAt: _savedAt!, compact: true),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Ob.inkMuted),
              onPressed: _signOut,
              child: const Text('Sign out'),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
          child: _ProgressBar(stateOf: _stateOf),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: ValueKey('setup-phone-${_step.key}'),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            child: isReady
                ? _readyView(phone: true)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _stepContent(phone: true),
                      if (side != null) ...[const SizedBox(height: 22), side],
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _head(String title, String why, {bool phone = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            phone
                ? 'STEP ${_step.number} OF 6 · ${_step.title.toUpperCase()}'
                : 'STEP ${_step.number} OF 6',
            style: Ob.eyebrow()),
        const SizedBox(height: 10),
        ObHeadline(title, size: phone ? 32 : 46),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(why, style: Ob.body(16)),
        ),
      ],
    );
  }

  Widget _gap([double h = 22]) => SizedBox(height: h);

  /// A neutral note: news, not a refusal.
  Widget _notice(String text) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Ob.track,
          borderRadius: BorderRadius.circular(Ob.radiusControl),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_awaitingPayment) ...[
            const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Ob.ink)),
            const SizedBox(width: 10),
          ],
          Expanded(child: Text(text, style: Ob.body(14.5, color: Ob.ink))),
        ]),
      );

  Widget _errorLine() => _stepError == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Ob.refusedSoft,
              borderRadius: BorderRadius.circular(Ob.radiusControl),
            ),
            child: Text(_stepError!, style: Ob.body(14.5, color: Ob.refused)),
          ),
        );

  Widget _stepContent({required bool phone}) {
    switch (_step) {
      case SetupStep.business:
        return _businessStep(phone);
      case SetupStep.want:
        return _wantStep(phone);
      case SetupStep.offer:
        return _offerStep(phone);
      case SetupStep.email:
        return _emailStep(phone);
      case SetupStep.permission:
        return _permissionStep(phone);
      case SetupStep.plan:
        return _planStep(phone);
      case SetupStep.ready:
        return _readyView(phone: phone);
    }
  }

  Widget _pair(bool phone, Widget a, Widget b) => phone
      ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, _gap(16), b])
      : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: a),
          const SizedBox(width: 16),
          Expanded(child: b),
        ]);

  Widget _businessStep(bool phone) {
    final industry = GlobalSetupOptions.industryByCode(_industryCode);
    final country = GlobalSetupOptions.countryByCode(_addressCountry);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head('Tell us about your business.',
            'This is how your business will appear in every note Orchestrate '
                'sends for you. You type it once; it is used everywhere.',
            phone: phone),
        _gap(),
        _pair(
          phone,
          ObField(
            label: 'Business name',
            controller: _name,
            error: _fieldErrors['name'],
            autofillHints: const [AutofillHints.organizationName],
          ),
          ObField(
            label: 'Website',
            controller: _website,
            error: _fieldErrors['website'],
            placeholder: 'yourbusiness.com',
            keyboardType: TextInputType.url,
            autofillHints: const [AutofillHints.url],
          ),
        ),
        _gap(),
        Text('What kind of business is it?', style: Ob.strong(15)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (industry != null) ObChoice(industry.label),
          ObAddChoice(industry == null ? 'Choose' : 'Change', onTap: () async {
            final picked = await _pick(
              title: 'What kind of business is it?',
              options: [
                for (final o in GlobalSetupOptions.industries) (o.code, o.label)
              ],
              selected: {if (_industryCode != null) _industryCode!},
              single: true,
            );
            if (picked == null || !mounted) return;
            setState(() {
              _industryCode = picked.firstOrNull;
              _fieldErrors = {..._fieldErrors}..remove('industry');
            });
            _keepDraft();
          }),
        ]),
        if (_fieldErrors['industry'] != null) ...[
          const SizedBox(height: 6),
          Text(_fieldErrors['industry']!, style: Ob.body(13.5, color: Ob.refused)),
        ],
        _gap(),
        Text('Business address', style: Ob.strong(15)),
        const SizedBox(height: 6),
        TextField(
          controller: _line1,
          autofillHints: const [AutofillHints.streetAddressLine1],
          style: Ob.body(16, color: Ob.ink),
          decoration: InputDecoration(
            hintText: 'Street and number',
            enabledBorder: _fieldErrors['address'] != null
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Ob.radiusControl),
                    borderSide: const BorderSide(color: Ob.refused, width: 2))
                : null,
          ),
        ),
        const SizedBox(height: 10),
        _pair(
          phone,
          TextField(
            controller: _city,
            autofillHints: const [AutofillHints.addressCity],
            style: Ob.body(16, color: Ob.ink),
            decoration: const InputDecoration(hintText: 'Town or city'),
          ),
          TextField(
            controller: _postcode,
            autofillHints: const [AutofillHints.postalCode],
            style: Ob.body(16, color: Ob.ink),
            decoration: const InputDecoration(hintText: 'Postcode or ZIP'),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.public, size: 18),
            label: Text(country?.label ?? 'Country'),
            onPressed: () async {
              final picked = await _pick(
                title: 'Which country is the address in?',
                options: [
                  for (final o in GlobalSetupOptions.countries) (o.code, o.label)
                ],
                selected: {if (_addressCountry.isNotEmpty) _addressCountry},
                single: true,
              );
              if (picked == null || !mounted) return;
              setState(() => _addressCountry = picked.firstOrNull ?? '');
              _keepDraft();
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _fieldErrors['address'] ??
              'Every business email must carry a postal address by law, so '
                  'it goes in the footer of each note.',
          style: Ob.body(13.5,
              color: _fieldErrors['address'] != null ? Ob.refused : Ob.inkMuted),
        ),
        _errorLine(),
        _gap(26),
        ObActions(
          primary: 'Save and continue',
          onPrimary: _saveBusiness,
          busy: _busy,
        ),
      ],
    );
  }

  Widget _wantStep(bool phone) {
    final regionGroups = [
      for (final cc in _countries)
        if (GlobalSetupOptions.regionsForCountry(cc).isNotEmpty) cc
    ];
    final suggestions = metroSuggestionsFor(_countries, _regions, _towns);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head('Who should Orchestrate find?',
            'Pick the kinds of businesses that buy from you and where they '
                'are. Start small; you can widen it later.',
            phone: phone),
        _gap(),
        Text('Businesses that buy from you', style: Ob.strong(15)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final k in _buyerKinds)
            ObChoice(k, onRemove: () {
              setState(() => _buyerKinds.remove(k));
              _keepDraft();
            }),
          // Who usually buys from a business of this kind, one tap each.
          for (final s in buyerSuggestionsFor(_industryCode, _buyerKinds))
            ObAddChoice(s, onTap: () {
              setState(() {
                _buyerKinds.add(s);
                _stepError = null;
              });
              _keepDraft();
            }),
          ObAddChoice(
              buyerSuggestionsFor(_industryCode, const []).isEmpty
                  ? 'Add a kind'
                  : 'Another kind',
              onTap: () async {
            final picked = await _pick(
              title: 'Which businesses buy from you?',
              options: [
                for (final o in GlobalSetupOptions.industries) (o.label, o.label)
              ],
              selected: _buyerKinds.toSet(),
              allowCustom: true,
            );
            if (picked == null || !mounted) return;
            setState(() {
              _buyerKinds
                ..clear()
                ..addAll(picked.take(12));
              _stepError = null;
            });
            _keepDraft();
          }),
        ]),
        _gap(),
        Text('Where they are', style: Ob.strong(15)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final cc in _countries)
            ObChoice(GlobalSetupOptions.countryByCode(cc)?.label ?? cc,
                onRemove: () {
              setState(() {
                _countries.remove(cc);
                _regions.removeWhere((r) => r.startsWith('$cc-'));
              });
              _keepDraft();
            }),
          ObAddChoice('Add a country', onTap: () async {
            final picked = await _pick(
              title: 'Which countries?',
              options: [
                for (final o in GlobalSetupOptions.countries) (o.code, o.label)
              ],
              selected: _countries,
            );
            if (picked == null || !mounted) return;
            setState(() {
              _countries
                ..clear()
                ..addAll(picked.take(12));
              _regions.removeWhere(
                  (r) => !_countries.contains(r.split('-').first.toUpperCase()));
              _stepError = null;
            });
            _keepDraft();
          }),
        ]),
        if (_countries.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final r in _regions)
              ObChoice(_region(r)?.label ?? r, onRemove: () {
                setState(() => _regions.remove(r));
                _keepDraft();
              }),
            if (regionGroups.isNotEmpty)
              ObAddChoice('Add an area', onTap: () async {
                final picked = await _pick(
                  title: 'Which areas?',
                  options: [
                    for (final cc in regionGroups)
                      for (final r in GlobalSetupOptions.regionsForCountry(cc))
                        (
                          r.code,
                          _countries.length > 1
                              ? '${r.label} · ${GlobalSetupOptions.countryByCode(cc)?.label ?? cc}'
                              : r.label
                        )
                  ],
                  selected: _regions,
                );
                if (picked == null || !mounted) return;
                setState(() => _regions
                  ..clear()
                  ..addAll(picked.take(80)));
                _keepDraft();
              }),
          ]),
          const SizedBox(height: 6),
          Text(
              regionGroups.isEmpty
                  ? 'No areas are needed here; the whole country counts.'
                  : 'Areas are optional. Leave them out to cover the whole country.',
              style: Ob.body(13, color: Ob.inkMuted)),
        ],
        _gap(),
        Row(children: [
          Text('Towns to start with ', style: Ob.strong(15)),
          Text('(optional)', style: Ob.body(15, color: Ob.inkMuted)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in _towns)
            ObChoice(t, onRemove: () {
              setState(() => _towns.remove(t));
              _keepDraft();
            }),
          ObAddChoice('Add a town', onTap: () async {
            final picked = await _pick(
              title: 'Towns to start with',
              options: [
                for (final s in {...suggestions, ..._towns}) (s, s)
              ],
              selected: _towns.toSet(),
              allowCustom: true,
            );
            if (picked == null || !mounted) return;
            setState(() {
              _towns.clear();
              for (final raw in picked.take(120)) {
                final t = _titleCase(raw.trim());
                if (t.isEmpty) continue;
                // A state or province typed as a town is an area: file it
                // there, where it is searched as the whole area it is.
                final area = _areaNamed(t);
                if (area != null) {
                  _regions.add(area);
                } else if (!_towns.any((x) => x.toLowerCase() == t.toLowerCase())) {
                  _towns.add(t);
                }
              }
            });
            _keepDraft();
          }),
        ]),
        _errorLine(),
        _gap(26),
        ObActions(
          primary: 'Save and continue',
          onPrimary: _saveWant,
          secondary: 'Back',
          onSecondary: () => _goTo(SetupStep.business),
          busy: _busy,
        ),
      ],
    );
  }

  Widget _offerStep(bool phone) {
    // One path: Orchestrate finds the customer and follows them through to
    // paid, so there is no "what first" to choose. A business that chose
    // before keeps its choice; a new one starts by finding customers.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head('What do you offer them?',
            'One or two sentences, the way you would say it on the phone. '
                'Orchestrate writes every first note from this.',
            phone: phone),
        _gap(),
        Text('Your offer', style: Ob.strong(15)),
        const SizedBox(height: 6),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _offer,
          builder: (context, value, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _offer,
                maxLines: 4,
                maxLength: 500,
                style: Ob.body(16, color: Ob.ink),
                decoration: InputDecoration(
                  counterText: '',
                  errorText: _fieldErrors['offer'],
                  hintText:
                      'For example: Boundary and topographic surveys, delivered '
                      'within ten working days.',
                ),
              ),
              const SizedBox(height: 6),
              Text('${value.text.length} of 500 characters',
                  style: Ob.body(13, color: Ob.inkMuted)),
            ],
          ),
        ),
        _errorLine(),
        _gap(26),
        ObActions(
          primary: 'Save and continue',
          onPrimary: _saveOffer,
          secondary: 'Back',
          onSecondary: () => _goTo(SetupStep.want),
          busy: _busy,
        ),
      ],
    );
  }

  Widget _emailStep(bool phone) {
    if (_emailConnected && !_personalMailbox) return _domainStep(phone);
    final connected = _emailConnected;
    final provider = _recognisedProvider;
    // A password is asked for only once the address is known to need one.
    final needsPassword = !connected &&
        provider.isNotEmpty &&
        !((provider == 'google' || provider == 'microsoft') && _oauthAvailable(provider));
    final providerName = const {
      'google': 'Google',
      'microsoft': 'Microsoft',
      'zoho': 'Zoho',
    }[provider];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head('Which address should notes come from?',
            'Notes go out from it, and replies come back to it.',
            phone: phone),
        _gap(),
        if (!connected) ...[
          ObField(
            label: 'Your email',
            controller: _address,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            error: _fieldErrors['address'],
            onChanged: (_) {
              if (_recognised != null) setState(() => _recognised = null);
            },
          ),
          if (needsPassword) ...[
            const SizedBox(height: 18),
            if (provider == 'generic') ...[
              ObField(
                label: 'Mail server',
                controller: _server,
                error: _fieldErrors['server'],
                hint: 'Your email host lists it, often as the SMTP server.',
              ),
              const SizedBox(height: 18),
            ],
            ObField(
              label: providerName == null ? 'Password' : '$providerName app password',
              controller: _appPassword,
              obscure: true,
              error: _fieldErrors['password'],
              hint: provider == 'zoho'
                  ? 'Zoho Mail: Settings, Security, App passwords. Make one for Orchestrate.'
                  : provider == 'google'
                      ? 'Google account: Security, App passwords. Make one for Orchestrate.'
                      : provider == 'microsoft'
                          ? 'Microsoft account: Security, App passwords. Make one for Orchestrate.'
                          : 'The password for this mailbox. If it uses two-step sign-in, an app password.',
            ),
          ],
          const SizedBox(height: 12),
          Text(
              'Orchestrate sends only the notes you approve, and reads only '
              'the replies to them.',
              style: Ob.body(13.5, color: Ob.inkMuted)),
        ],
        if (connected) ...[
          ObCard(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              const Icon(Icons.check_circle, color: Ob.ink, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text('$_mailboxAddress is connected.',
                    style: Ob.strong(15)),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          Text(
              'A Gmail or Outlook address needs no change at a domain host. '
              'Orchestrate sends at a careful pace from it.',
              style: Ob.body(13.5, color: Ob.inkMuted)),
        ],
        _errorLine(),
        _gap(26),
        if (connected)
          ObActions(
            primary: 'Continue',
            onPrimary: () => _goTo(_next(SetupStep.email)),
            secondary: 'Back',
            onSecondary: () => _goTo(SetupStep.offer),
          )
        else ...[
          ObActions(
            primary: needsPassword
                ? 'Connect'
                : provider == 'google' || provider == 'microsoft'
                    ? 'Sign in with ${providerName ?? 'your provider'}'
                    : 'Continue',
            onPrimary: needsPassword ? _connectWithPassword : _continueWithAddress,
            secondary: 'Back',
            onSecondary: () => _goTo(SetupStep.offer),
            busy: _busy,
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: Ob.inkMuted,
                  padding: EdgeInsets.zero,
                  textStyle: Ob.body(14, weight: FontWeight.w600)),
              onPressed: _busy ? null : () => _goTo(_next(SetupStep.email)),
              child: const Text('Do this later'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _domainStep(bool phone) {
    final domainName = _domainAttached
        ? (_domain['domain'] ?? '').toString()
        : _mailboxDomain;
    final records = _list(_domain['records']).map(_map).toList();
    final missing = records.where((r) => r['matched'] != true).length;
    final lastChecked = (_domain['lastCheckedAt'] ?? '').toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(
            _domainReady
                ? 'Your domain is trusted.'
                : missing <= 1
                    ? 'One change at your domain host.'
                    : '${const ['', 'One', 'Two', 'Three'][missing.clamp(1, 3)]} changes at your domain host.',
            _domainReady
                ? '$_mailboxAddress is connected and $domainName checks out. '
                    'Inboxes will trust notes sent from it.'
                : '$_mailboxAddress is connected. So that inboxes trust notes '
                    'from $domainName, make the changes marked "Not seen yet" '
                    'where your domain is managed. Records already found need nothing.',
            phone: phone),
        _gap(),
        if (!_domainAttached)
          ObCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Use $domainName for sending?', style: Ob.name(19)),
                const SizedBox(height: 6),
                Text(
                    'Orchestrate will prepare the exact records for $domainName.',
                    style: Ob.body(14.5)),
                const SizedBox(height: 14),
                ObActions(
                    primary: 'Prepare the records',
                    onPrimary: _attachDomain,
                    busy: _busy),
              ],
            ),
          )
        else ...[
          // Who manages this domain's records, and the page to make changes on.
          if (!_domainReady && _map(_domain['dnsHost'])['name'] != null) ...[
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Your domain is managed at ${_map(_domain['dnsHost'])['name']}.',
                    style: Ob.strong(15)),
                if ((_map(_domain['dnsHost'])['dnsPageUrl'] ?? '').toString().isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(
                        Uri.parse(_map(_domain['dnsHost'])['dnsPageUrl'].toString()),
                        mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text('Open ${_map(_domain['dnsHost'])['name']}'),
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          _RecordsTable(records: records, phone: phone),
          const SizedBox(height: 14),
          if (!_domainReady)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Ob.track,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.schedule, size: 18, color: Ob.ink),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    TextSpan(
                        text: 'Checking on its own every few minutes. ',
                        style: Ob.strong(14)),
                    TextSpan(
                        text: '${lastChecked.isEmpty ? '' : 'Last checked ${_clock(lastChecked)}. '}'
                            'Changes can take up to a day to show. You do not '
                            'need to wait here.',
                        style: Ob.body(14, color: Ob.ink)),
                  ])),
                ),
              ]),
            ),
        ],
        _errorLine(),
        _gap(26),
        ObActions(
          primary: _domainReady ? 'Continue' : 'Continue, finish this later',
          onPrimary: () => _goTo(_next(SetupStep.email)),
          secondary: _domainAttached && !_domainReady ? 'Check now' : 'Back',
          onSecondary: _domainAttached && !_domainReady
              ? _checkDomainNow
              : () => _goTo(SetupStep.offer),
          busy: _busy,
        ),
      ],
    );
  }

  /// WHO ACTS FOR THIS BUSINESS (DD-27): one screen, one submit.
  ///
  /// The owner confirms they act for the business in three areas, sends the
  /// business registration document, and gives Orchestrate permission to
  /// write in the business's name. One press writes the two separate records
  /// (who the business recognises; what Orchestrate may do) through their own
  /// services, exactly as before. The document is then checked; anything
  /// uncertain goes to a person, never to a refusal.
  Widget _permissionStep(bool phone) {
    final who = AuthSessionController.instance.fullName.trim();
    final business = _text(_profile, 'displayName').isEmpty
        ? 'your business'
        : _text(_profile, 'displayName');
    final state = _stateOf(SetupStep.permission);
    final doc = _map(_document);
    final sent = doc.isNotEmpty;
    if (!_actUnlocked) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _head('Who acts for this business.',
            'This opens once the steps above are done.',
            phone: phone),
        _gap(26),
        ObActions(
          primary: 'Go to the next open step',
          onPrimary: () => _goTo(_firstOpenStep()),
        ),
      ]);
    }
    if (state != StepState.todo) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _head(
            state == StepState.done
                ? 'You act for $business.'
                : 'Checking your document.',
            state == StepState.done
                ? 'Your document is confirmed and Orchestrate may write in the '
                    "business's name, with your approval on each note."
                : '${(doc['says'] ?? 'We are checking your document.').toString()} You can use the rest '
                    'of the workspace meanwhile; nothing is sent before this is done.',
            phone: phone),
        _gap(),
        if (sent)
          ObCard(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Icon(state == StepState.done ? Icons.check_circle : Icons.schedule,
                  color: Ob.ink, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Text('${doc['fileName'] ?? 'Your document'}', style: Ob.strong(15))),
            ]),
          ),
        if ((doc['request'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 12),
          _notice(doc['request'].toString()),
        ],
        _gap(26),
        ObActions(
          primary: 'Continue',
          onPrimary: () => _goTo(SetupStep.ready),
          secondary: 'Back',
          onSecondary: () => _goTo(SetupStep.plan),
        ),
      ]);
    }

    Widget area(String key, String label, String meaning) {
      final on = _actAreas.contains(key);
      return InkWell(
        borderRadius: BorderRadius.circular(Ob.radiusControl),
        onTap: _busy
            ? null
            : () => setState(() => on ? _actAreas.remove(key) : _actAreas.add(key)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(on ? Icons.check_box : Icons.check_box_outline_blank,
                size: 22, color: on ? Ob.ink : Ob.inkMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: Ob.strong(15.5)),
                const SizedBox(height: 2),
                Text(meaning, style: Ob.body(14, color: Ob.inkMuted)),
              ]),
            ),
          ]),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head('Who acts for this business.',
            'Orchestrate writes to businesses in your name, so it needs to know '
                'who may decide for $business. One step, then you are ready.',
            phone: phone),
        _gap(),
        Text('1. You act for $business in', style: Ob.strong(15)),
        const SizedBox(height: 4),
        area('COMMUNICATION', 'Notes', 'Approve what is written to other businesses.'),
        area('CONTRACTUAL', 'Agreements', 'Approve proposals and agreements.'),
        area('FINANCIAL', 'Invoices', 'Approve invoices and payment reminders.'),
        _gap(18),
        Text('2. Your business registration document', style: Ob.strong(15)),
        const SizedBox(height: 4),
        Text(
            'Articles of organization or incorporation, an annual report, or a '
            'business name certificate. A PDF or a photo of the page.',
            style: Ob.body(14, color: Ob.inkMuted)),
        const SizedBox(height: 10),
        Row(children: [
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickDocument,
            icon: const Icon(Icons.upload_file, size: 18),
            label: Text(_pickedName == null ? 'Choose a file' : 'Choose another'),
          ),
          const SizedBox(width: 12),
          if (_pickedName != null)
            Expanded(
              child: Text(_pickedName!,
                  overflow: TextOverflow.ellipsis, style: Ob.strong(14.5)),
            ),
        ]),
        if (_fieldErrors['document'] != null) ...[
          const SizedBox(height: 6),
          Text(_fieldErrors['document']!, style: Ob.body(13.5, color: Ob.refused)),
        ],
        _gap(18),
        Text('3. Your permission', style: Ob.strong(15)),
        const SizedBox(height: 8),
        ObCard(
          waitingOnYes: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(TextSpan(style: Ob.body(15.5, color: Ob.ink), children: [
                const TextSpan(text: 'I allow Orchestrate to find businesses for '),
                TextSpan(text: business, style: Ob.strong(15.5)),
                const TextSpan(
                    text: ' and prepare notes, proposals and invoices in its name.'),
              ])),
              const SizedBox(height: 10),
              Text('Nothing is sent until I, or someone I name, approves it.',
                  style: Ob.body(15.5, color: Ob.ink)),
              const SizedBox(height: 10),
              Text('I can withdraw this at any time from Setup.',
                  style: Ob.body(15.5, color: Ob.ink)),
              const SizedBox(height: 16),
              Text(
                  'Given by ${who.isEmpty ? 'you' : '$who (you)'} when you press the button below.',
                  style: Ob.body(14, color: Ob.inkMuted)),
            ],
          ),
        ),
        _errorLine(),
        _gap(26),
        ObActions(
          primary: 'Confirm and send',
          onPrimary: _submitAct,
          secondary: 'Someone else should do this',
          onSecondary: () => context.go('/account/people'),
          busy: _busy,
        ),
      ],
    );
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final f = result.files.first;
    if (f.bytes == null) return;
    if (f.bytes!.length > 10 * 1024 * 1024) {
      setState(() => _fieldErrors = {'document': 'That file is over 10 MB. A PDF or a photo of the page is enough.'});
      return;
    }
    setState(() {
      _pickedBytes = f.bytes;
      _pickedName = f.name;
      _fieldErrors = {};
    });
  }

  /// One press: send the document, record who acts for the business, and
  /// record the permission. Each is its own record, written by its own service.
  Future<void> _submitAct() async {
    if (_actAreas.isEmpty) {
      setState(() => _stepError = 'Choose at least one area you act in.');
      return;
    }
    if (_pickedBytes == null) {
      setState(() => _fieldErrors = {'document': 'Choose your registration document.'});
      return;
    }
    setState(() {
      _busy = true;
      _stepError = null;
      _fieldErrors = {};
    });
    try {
      final uploaded = await _representative.uploadDocument(
          bytes: _pickedBytes!, fileName: _pickedName ?? 'document.pdf');
      final current = await _representative.fetchCurrent();
      final hash = (_map(current['designation'])['hash'] ??
              _map(current['designation'])['artifactHash'] ??
              '')
          .toString();
      final submitted = await _representative.submit(
        requested: [
          for (final a in _actAreas)
            {'capability': a, 'mayExercise': true, 'mayDelegate': true, 'maySubdelegate': false},
        ],
        acknowledgedRepresentation: true,
        artifactHash: hash,
        supportingReference: (uploaded['id'] ?? '').toString(),
        supportingKind: 'REGISTRATION_DOCUMENT',
      );
      if (submitted['ok'] == false) {
        throw StateError((submitted['reason'] ?? 'That could not be recorded just now.').toString());
      }
      if (_profile['representationAuthorized'] != true) {
        await _campaign.acceptRepresentationAuth();
      }
      final rep = await _representative.fetchCurrent().catchError((_) => <String, dynamic>{});
      if (!mounted) return;
      setState(() {
        _profile = {..._profile, 'representationAuthorized': true};
        _representativeState = _map(rep['readiness']);
        _document = uploaded;
        _pickedBytes = null;
        _busy = false;
        _markSaved();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _stepError = error is StateError
            ? error.message
            : _reasonFor(error,
                fallback: 'That could not be sent just now. Try again in a moment.');
      });
    }
  }

  Widget _planStep(bool phone) {
    // The picked cadence is the dark card; tapping the other picks it.
    Widget price(String period, String cadence, String amount, String unit, String note,
        {String? badge}) {
      final dark = _cadence == period;
      return InkWell(
        borderRadius: BorderRadius.circular(Ob.radiusCard),
        onTap: _busy ? null : () => setState(() => _cadence = period),
        child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: dark ? Ob.ink : Ob.card,
          borderRadius: BorderRadius.circular(Ob.radiusCard),
          border: Border.all(color: dark ? Ob.ink : Ob.line, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(dark ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 18, color: dark ? Ob.onInk : Ob.inkMuted),
              const SizedBox(width: 8),
              Text(cadence,
                  style: Ob.body(13, color: dark ? Ob.onInkMuted : Ob.inkMuted)),
              const Spacer(),
              if (badge != null)
                Text(badge,
                    style: Ob.body(13,
                        color: dark ? Ob.moneyOnInk : Ob.money,
                        weight: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text(amount, style: Ob.figure(34, color: dark ? Ob.onInk : Ob.ink)),
                const SizedBox(width: 6),
                Text(unit, style: Ob.body(14, color: dark ? Ob.onInkMuted : Ob.inkMuted)),
              ]),
            ),
            const SizedBox(height: 6),
            Text(note, style: Ob.body(13, color: dark ? Ob.onInkMuted : Ob.inkMuted)),
          ],
        ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(_planActive ? 'Your plan is active.' : 'Choose when to start sending.',
            _planActive
                ? 'Orchestrate can send the notes you approve.'
                : 'Setting up is free. Orchestrate can start finding businesses '
                    'for you now; sending notes begins when you choose a plan.',
            phone: phone),
        _gap(),
        if (!_planActive && (_awaitingPayment || widget.checkoutStatus != null)) ...[
          _notice(_awaitingPayment
              ? 'Payment received. Switching your plan on; this takes a few seconds.'
              : widget.checkoutStatus == 'success'
                  ? 'Your payment has not reached us yet. It can take a minute; '
                      'this page will show it when it does. Nothing more is needed from you.'
                  : 'Checkout was closed before paying. Nothing was charged.'),
          const SizedBox(height: 16),
        ],
        if (!_planActive && _offers.isNotEmpty) ...[
          const EarlyPriceLine(),
          const SizedBox(height: 14),
          // Prices are the server's (`/public/pricing`), never written here.
          _pair(
            phone,
            price(_offers.first.period, 'Monthly', _offers.first.priceLabel, '/ month',
                'Cancel any time'),
            _offers.length > 1
                ? price(_offers.last.period, 'Yearly', _offers.last.priceLabel, '/ year',
                    '${_perMonth(_offers.last)} a month, paid yearly',
                    badge: _monthsFree())
                : const SizedBox.shrink(),
          ),
        ],
        _errorLine(),
        _gap(26),
        if (_planActive)
          ObActions(
            primary: 'Continue',
            onPrimary: () => _goTo(_next(SetupStep.plan)),
            secondary: 'Back',
            onSecondary: () => _goTo(SetupStep.email),
          )
        else
          ObActions(
            primary: 'Continue to payment',
            onPrimary: _startCheckout,
            secondary: 'Not yet, look around first',
            onSecondary: _deferPlan,
            busy: _busy,
          ),
      ],
    );
  }

  List<CommercialOffer> get _offers => _pricing?.offers ?? const [];

  String _perMonth(CommercialOffer annual) =>
      CommercialOffer.fromJson({'amountUsdCents': (annual.amountUsdCents / 12).round()})
          .priceLabel
          .replaceAll('.00', '');

  String? _monthsFree() {
    final monthly = _pricing?.offerFor('MONTHLY');
    final annual = _pricing?.offerFor('ANNUAL');
    if (monthly == null || annual == null || monthly.amountUsdCents == 0) {
      return null;
    }
    final months =
        ((monthly.amountUsdCents * 12 - annual.amountUsdCents) / monthly.amountUsdCents)
            .round();
    if (months < 1) return null;
    return months == 1 ? 'One month free' : '${_numberWord(months)} months free';
  }

  String _numberWord(int n) =>
      const ['Zero', 'One', 'Two', 'Three', 'Four', 'Five', 'Six'].elementAtOrNull(n) ?? '$n';

  Widget? _sideCard() {
    switch (_step) {
      case SetupStep.business:
        return _SideCard(
          label: 'HOW IT WILL LOOK AT THE FOOT OF EVERY NOTE',
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([_name, _website, _line1, _city, _postcode]),
              builder: (context, _) {
                final who = AuthSessionController.instance.fullName.trim();
                final addressParts = [
                  _line1.text.trim(),
                  _city.text.trim(),
                  _postcode.text.trim(),
                ].where((e) => e.isNotEmpty).join(', ');
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Ob.cardSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kind regards,', style: Ob.body(14)),
                      if (who.isNotEmpty) Text(who, style: Ob.strong(14)),
                      Text(
                          [
                            _name.text.trim().isEmpty ? 'Your business' : _name.text.trim(),
                            if (_website.text.trim().isNotEmpty) _website.text.trim(),
                          ].join(' · '),
                          style: Ob.body(14)),
                      const SizedBox(height: 2),
                      Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Text(addressParts.isEmpty ? 'Your address' : addressParts,
                            style: Ob.body(14)),
                        if (addressParts.isNotEmpty && !_addressUsable)
                          const ObPill('town or postcode missing', tone: PillTone.refused),
                      ]),
                    ],
                  ),
                );
              },
            ),
            const ObAssurance('Nothing is sent while you set up. You will see '
                'every note before it goes.'),
          ],
        );
      case SetupStep.want:
        final kinds = _buyerKinds.isEmpty
            ? 'Businesses that buy from you'
            : _joinWords(_buyerKinds);
        final where = _geoTargets.isEmpty ? '' : ' in ${_joinWords(_geoTargets.take(4).toList())}';
        return _SideCard(
          label: 'WHAT ORCHESTRATE WILL LOOK FOR',
          children: [
            Text('$kinds$where.', style: Ob.name(24).copyWith(height: 1.3)),
            const Divider(),
            const ObAssurance('Orchestrate checks each business before it is '
                'shown to you, and says why it fits. Nobody is contacted '
                'without your yes.'),
          ],
        );
      case SetupStep.offer:
        final offer = _offer.text.trim();
        return _SideCard(
          label: 'WHAT A FIRST NOTE STARTS FROM',
          children: [
            Text(
                offer.isEmpty
                    ? 'Your offer appears here as you type it.'
                    : offer,
                style: Ob.name(18).copyWith(height: 1.55)),
            Text('Each note is written for the business it goes to, and you '
                'approve every one before it is sent.',
                style: Ob.body(13, color: Ob.inkMuted)),
          ],
        );
      case SetupStep.email:
        if (_emailConnected && !_personalMailbox) {
          final domainName = _domainAttached
              ? (_domain['domain'] ?? '').toString()
              : _mailboxDomain;
          return _SideCard(
            label: 'WHERE TO MAKE THE CHANGE',
            children: [
              Text.rich(TextSpan(style: Ob.body(15, color: Ob.ink), children: [
                const TextSpan(text: 'Sign in where you bought '),
                TextSpan(text: domainName, style: Ob.strong(15)),
                const TextSpan(
                    text: ' (for example GoDaddy, Namecheap, 123-reg or '
                        'Cloudflare), open '),
                TextSpan(text: 'DNS settings', style: Ob.strong(15)),
                const TextSpan(text: ', and add each record.'),
              ])),
              Text('If someone else runs your website, send them this page; '
                  'the records are all they need.',
                  style: Ob.body(14)),
              Text('Until this is done, Orchestrate sends slowly and in small '
                  'numbers so your address stays trusted.',
                  style: Ob.body(13, color: Ob.inkMuted)),
            ],
          );
        }
        return _SideCard(
          label: 'WHAT CONNECTING ALLOWS',
          children: [
            _allow(true, 'Send the notes you approve, from your address'),
            _allow(true, 'Replies arrive in your own inbox, as they always do'),
            _allow(false, 'Read or change anything else in your mailbox'),
            Text('Disconnect any time from Setup.',
                style: Ob.body(13, color: Ob.inkMuted)),
          ],
        );
      case SetupStep.permission:
        return _SideCard(
          label: 'IF SOMEONE ELSE ACTS FOR IT',
          children: [
            Text('Invite the owner or a director to this workspace. Everything '
                'you filled in stays as it is; they sign in and finish this '
                'step.',
                style: Ob.body(15, color: Ob.ink)),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: () => context.go('/account/people'),
                child: const Text('Invite them'),
              ),
            ),
          ],
        );
      case SetupStep.plan:
        return _SideCard(
          label: 'WHAT YOU GET EITHER WAY',
          children: [
            _row('Businesses found and explained', 'Now, free'),
            _row('First notes written for you to read', 'Now, free'),
            _row('Notes sent, replies followed up', 'With a plan'),
            _row('Proposals, invoices, payments', 'With a plan'),
            Text('Pay by card, or through the App Store or Google Play on '
                'your phone.',
                style: Ob.body(13, color: Ob.inkMuted)),
          ],
        );
      case SetupStep.ready:
        return null;
    }
  }

  Widget _allow(bool yes, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(yes ? Icons.check : Icons.close,
                size: 17, color: yes ? Ob.ink : Ob.inkFaint),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Ob.body(14.5, color: Ob.ink))),
        ],
      );

  Widget _row(String a, String b) => Row(children: [
        Expanded(child: Text(a, style: Ob.body(14.5, color: Ob.ink))),
        const SizedBox(width: 12),
        Text(b, style: Ob.strong(14.5)),
      ]);

  String _openCountLine() {
    final open =
        SetupStep.values.take(6).where((s) => _stateOf(s) == StepState.todo).length;
    const words = ['No', 'One', 'Two', 'Three', 'Four', 'Five', 'Six'];
    return open == 1 ? 'One thing is still open.' : '${words[open]} things are still open.';
  }

  Widget _readyView({required bool phone}) {
    final allDone = SetupStep.values.take(6).every((s) => _stateOf(s) != StepState.todo);
    String line(SetupStep s) {
      switch (s) {
        case SetupStep.business:
          final a = _map(_profile['postalAddress']);
          return [
            _text(_profile, 'displayName'),
            [_text(a, 'line1'), _text(a, 'locality'), _text(a, 'postalCode')]
                .where((e) => e.isNotEmpty)
                .join(', '),
          ].where((e) => e.isNotEmpty).join(' · ');
        case SetupStep.want:
          final icp = _map(_profile['icp']);
          // Short enough to read whole: the kinds, then the first place and
          // how many more, never a list cut off mid-word.
          final places = _list(icp['geoTargets']).map((e) => '$e').toList();
          final where = places.isEmpty
              ? ''
              : places.length == 1
                  ? places.first
                  : '${places.first} and ${places.length - 1} more';
          return [
            _joinWords(_list(icp['industryTags']).map((e) => '$e').take(3).toList()),
            where,
          ].where((e) => e.isNotEmpty).join(' · ');
        case SetupStep.offer:
          return _text(_profile, 'outboundOffer');
        case SetupStep.email:
          if (!_emailConnected) return 'Not connected yet';
          if (_stateOf(s) == StepState.waiting) {
            return '$_mailboxAddress connected · domain check still running · '
                'sending slowly until then';
          }
          return '$_mailboxAddress connected';
        case SetupStep.permission:
          final st = _stateOf(s);
          return st == StepState.done
              ? 'Confirmed'
              : st == StepState.waiting
                  ? 'Checking your document'
                  : _actUnlocked
                      ? 'Not done yet'
                      : 'Opens when the steps above are done';
        case SetupStep.plan:
          return _planActive
              ? 'Active'
              : 'Not chosen yet. Finding businesses is free.';
        case SetupStep.ready:
          return '';
      }
    }

    final summary = ObCard(
      raised: true,
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('YOUR SETUP', style: Ob.eyebrow()),
          const SizedBox(height: 8),
          for (final s in SetupStep.values.take(6))
            InkWell(
              onTap: () => _goTo(s),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Ob.line))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StepDot(state: _stateOf(s), number: s.number, current: false),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.title, style: Ob.strong(15)),
                          const SizedBox(height: 2),
                          Text(line(s),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Ob.body(13.5, color: Ob.inkMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    final lead = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(allDone ? 'READY' : 'NEARLY THERE',
            style: Ob.eyebrow(color: allDone ? Ob.ink : Ob.inkMuted)),
        const SizedBox(height: 12),
        ObHeadline(
            allDone
                ? 'Orchestrate is looking for your first customers.'
                : _openCountLine(),
            size: phone ? 36 : 60),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
              allDone
                  ? 'New businesses appear in Market as Orchestrate finds them. '
                      'When a note is ready, it waits on Today for your yes.'
                  : 'Everything you have done is saved. Open any line to finish '
                      'it; the rest of the workspace is yours meanwhile.',
              style: Ob.body(18)),
        ),
        const SizedBox(height: 22),
        ObActions(
          primary: 'Go to Today',
          onPrimary: () async {
            final all = Map<String, dynamic>.from(
                AuthSessionController.instance.setupDraft ?? const {});
            final one = Map<String, dynamic>.from(_map(all['onePath']));
            one['returnToSetup'] = false;
            all['onePath'] = one;
            await AuthSessionController.instance.saveSetupDraft(all);
            if (mounted) context.go('/client/today');
          },
          secondary: 'See the market',
          onSecondary: () => context.go('/client/market'),
        ),
      ],
    );

    if (phone) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        lead,
        const SizedBox(height: 26),
        summary,
      ]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: 11, child: Padding(padding: const EdgeInsets.only(top: 40), child: lead)),
      const SizedBox(width: 64),
      Expanded(flex: 10, child: summary),
    ]);
  }

  // ── Picker ─────────────────────────────────────────────────────────

  Future<Set<String>?> _pick({
    required String title,
    required List<(String, String)> options,
    required Set<String> selected,
    bool single = false,
    bool allowCustom = false,
  }) {
    return showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Ob.paper,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Theme(
        data: Ob.theme(),
        child: _PickerSheet(
          title: title,
          options: options,
          selected: selected,
          single: single,
          allowCustom: allowCustom,
        ),
      ),
    );
  }
}

String _joinWords(List<String> items) {
  if (items.isEmpty) return '';
  if (items.length == 1) return items.first;
  return '${items.take(items.length - 1).join(', ')} and ${items.last}';
}

String _clock(String iso) {
  final t = DateTime.tryParse(iso)?.toLocal();
  if (t == null) return '';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// "Early-onboarding price" line, shared by pricing and the plan step.
class EarlyPriceLine extends StatelessWidget {
  const EarlyPriceLine({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: Ob.ink,
            borderRadius: BorderRadius.circular(Ob.radiusPill),
          ),
          child: Text('EARLY-ONBOARDING PRICE',
              style: Ob.body(12, color: Ob.onInk, weight: FontWeight.w600)
                  .copyWith(letterSpacing: 0.4)),
        ),
        Text('Starting prices for the first businesses to join. They will rise later.',
            style: Ob.body(14)),
      ],
    );
  }
}

// ── Pieces ───────────────────────────────────────────────────────────

class _SideCard extends StatelessWidget {
  const _SideCard({required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ObCard(
      raised: true,
      padding: const EdgeInsets.all(30),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: Ob.eyebrow()),
          for (final c in children) ...[const SizedBox(height: 16), c],
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.state, required this.number, required this.current});
  final StepState state;
  final int number;
  final bool current;

  @override
  Widget build(BuildContext context) {
    if (state == StepState.done) {
      return Container(
        width: 26,
        height: 26,
        decoration: const BoxDecoration(color: Ob.ink, shape: BoxShape.circle),
        child: const Icon(Icons.check, size: 15, color: Ob.card),
      );
    }
    if (state == StepState.waiting) {
      return Container(
        width: 26,
        height: 26,
        decoration: const BoxDecoration(color: Ob.track, shape: BoxShape.circle),
        child: const Icon(Icons.schedule, size: 15, color: Ob.ink),
      );
    }
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: current ? Ob.card : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
            color: current ? Ob.ink : const Color(0xFFCFC8BA),
            width: current ? 2.5 : 1.5),
      ),
      child: Text('$number',
          style: Ob.figure(12, color: current ? Ob.ink : Ob.inkFaint)),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.stateOf});
  final StepState Function(SetupStep) stateOf;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (var i = 0; i < 6; i++) ...[
        if (i > 0) const SizedBox(width: 4),
        Expanded(
          child: Container(
            height: 5,
            decoration: BoxDecoration(
              color: switch (stateOf(SetupStep.values[i])) {
                StepState.done => Ob.ink,
                StepState.waiting => const Color(0xFF9CA3AF),
                StepState.todo => Ob.track,
              },
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ],
    ]);
  }
}

class _SavedDot extends StatelessWidget {
  const _SavedDot({required this.savedAt, this.compact = false});
  final DateTime savedAt;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(color: Ob.ink, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text(compact ? 'Saved' : 'Saved ${_clock(savedAt.toIso8601String())}',
          style: Ob.body(13, color: Ob.ink, weight: FontWeight.w600)),
    ]);
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.current,
    required this.stateOf,
    required this.done,
    required this.savedAt,
    required this.onTap,
    required this.onSignOut,
  });

  final SetupStep current;
  final StepState Function(SetupStep) stateOf;
  final int done;
  final DateTime? savedAt;
  final ValueChanged<SetupStep> onTap;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: Ob.line))),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Ob.ink, width: 4),
                ),
              ),
              const SizedBox(width: 10),
              Text('Getting ready', style: Ob.body(16, color: Ob.ink, weight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProgressBar(stateOf: stateOf),
                const SizedBox(height: 8),
                Text(
                    done >= 6
                        ? 'All 6 done'
                        : '$done of 6 done · about ${6 - done} ${6 - done == 1 ? 'minute' : 'minutes'} left',
                    style: Ob.body(13, color: Ob.inkMuted)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final s in SetupStep.values.take(6))
            _RailRow(
              step: s,
              state: stateOf(s),
              current: s == current,
              onTap: () => onTap(s),
            ),
          const SizedBox(height: 6),
          _RailRow(
            step: SetupStep.ready,
            state: StepState.todo,
            current: current == SetupStep.ready,
            onTap: () => onTap(SetupStep.ready),
            label: 'Where everything stands',
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Ob.card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (savedAt != null) ...[
                  _SavedDot(savedAt: savedAt!),
                  const SizedBox(height: 6),
                ],
                Text('Everything you type is kept. Leave any time and you come '
                    'back to this step.',
                    style: Ob.body(13)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Ob.inkMuted),
              onPressed: onSignOut,
              icon: const Icon(Icons.logout, size: 16),
              label: const Text('Sign out'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailRow extends StatelessWidget {
  const _RailRow({
    required this.step,
    required this.state,
    required this.current,
    required this.onTap,
    this.label,
  });

  final SetupStep step;
  final StepState state;
  final bool current;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final isReady = step == SetupStep.ready;
    return Semantics(
      button: true,
      selected: current,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: current ? Ob.card : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: current
                ? const [BoxShadow(color: Color(0x1417202B), blurRadius: 24, offset: Offset(0, 10))]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isReady)
                const SizedBox(
                    width: 26,
                    height: 26,
                    child: Icon(Icons.flag_outlined, size: 18, color: Ob.inkMuted))
              else
                _StepDot(state: state, number: step.number, current: current),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label ?? step.title,
                        style: Ob.body(15,
                            color: state == StepState.todo && !current && !isReady
                                ? Ob.inkMuted
                                : Ob.ink,
                            weight: current
                                ? FontWeight.w700
                                : state == StepState.todo
                                    ? FontWeight.w400
                                    : FontWeight.w600)),
                    if (!isReady) ...[
                      const SizedBox(height: 2),
                      Text(
                          state != StepState.waiting
                              ? step.subtitle
                              : step == SetupStep.plan
                                  ? 'Later, when you want to send'
                                  : step == SetupStep.permission
                                      ? 'Checking your document'
                                      : 'Domain check running on its own',
                          style: Ob.body(12.5, color: Ob.inkMuted)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordsTable extends StatelessWidget {
  const _RecordsTable({required this.records, required this.phone});
  final List<Map<String, dynamic>> records;
  final bool phone;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return ObCard(
        child: Text('The records for this domain are being prepared. Check '
            'back in a minute.',
            style: Ob.body(14.5)),
      );
    }
    return ObCard(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
      radius: Ob.radiusCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final r in records) _RecordRow(record: r, phone: phone),
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record, required this.phone});
  final Map<String, dynamic> record;
  final bool phone;

  @override
  Widget build(BuildContext context) {
    final type = (record['type'] ?? '').toString();
    final host = (record['host'] ?? '').toString();
    final value = (record['expectedValue'] ?? '').toString();
    final matched = record['matched'] == true;
    final why = (record['explanation'] ?? '').toString();
    // Google's and Microsoft's DKIM key is made in their admin console, not
    // by us: there is nothing to copy, only steps to follow.
    final providerMade = record['match'] == 'dkim-present';
    final status = matched
        ? const ObPill('Found', tone: PillTone.ink)
        : const ObPill('Not seen yet');
    Widget copy(String what, String text) => TextButton(
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36)),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (!context.mounted) return;
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(content: Text('$what copied')));
          },
          child: Text('Copy $what'),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Ob.line))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text(type, style: Ob.figure(14)),
            const SizedBox(width: 12),
            Expanded(
              child: SelectableText(host.isEmpty ? '@' : host,
                  style: Ob.figure(14, color: Ob.inkSoft, weight: FontWeight.w500)),
            ),
            status,
          ]),
          const SizedBox(height: 6),
          if (!providerMade)
            SelectableText(value,
                style: Ob.figure(13.5, color: Ob.inkSoft, weight: FontWeight.w500)
                    .copyWith(height: 1.4)),
          if (why.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(why, style: Ob.body(13.5, color: Ob.inkMuted)),
          ],
          if (!matched && !providerMade)
            Wrap(children: [copy('name', host.isEmpty ? '@' : host), copy('value', value)]),
        ],
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.message, required this.onRetry, required this.onSignOut});
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ObCard(
            raised: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Setup is not loading.', style: Ob.name(24)),
                const SizedBox(height: 10),
                Text(message, style: Ob.body(15)),
                const SizedBox(height: 18),
                ObActions(
                    primary: 'Try again',
                    onPrimary: onRetry,
                    secondary: 'Sign out',
                    onSecondary: onSignOut),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerSheet extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.single,
    required this.allowCustom,
  });

  final String title;
  final List<(String, String)> options;
  final Set<String> selected;
  final bool single;
  final bool allowCustom;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  late final Set<String> _chosen = {...widget.selected};
  late final List<(String, String)> _options = [
    ...widget.options,
    // Custom entries already chosen stay visible and removable.
    for (final s in widget.selected)
      if (!widget.options.any((o) => o.$1 == s)) (s, s),
  ];
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _toggle(String code) {
    setState(() {
      if (widget.single) {
        _chosen
          ..clear()
          ..add(code);
      } else if (!_chosen.remove(code)) {
        _chosen.add(code);
      }
    });
    if (widget.single) Navigator.of(context).pop(_chosen);
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final visible = q.isEmpty
        ? _options
        : _options.where((o) => o.$2.toLowerCase().contains(q)).toList();
    final canAddCustom = widget.allowCustom &&
        q.isNotEmpty &&
        !_options.any((o) => o.$2.toLowerCase() == q);
    final height = MediaQuery.sizeOf(context).height * 0.8;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 12, 8),
              child: Row(children: [
                Expanded(child: Text(widget.title, style: Ob.name(22))),
                if (!widget.single)
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_chosen),
                    child: Text(_chosen.isEmpty ? 'Done' : 'Done · ${_chosen.length}'),
                  ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 10),
              child: TextField(
                controller: _query,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                onSubmitted: (v) {
                  if (canAddCustom) {
                    final value = v.trim();
                    setState(() {
                      _options.insert(0, (value, value));
                      _query.clear();
                    });
                    _toggle(value);
                  }
                },
                style: Ob.body(16, color: Ob.ink),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: Ob.inkMuted),
                  hintText: widget.allowCustom ? 'Search or type your own' : 'Search',
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                children: [
                  if (canAddCustom)
                    ListTile(
                      leading: const Icon(Icons.add, color: Ob.ink),
                      title: Text('Add "${_query.text.trim()}"', style: Ob.strong(15)),
                      onTap: () {
                        final value = _query.text.trim();
                        setState(() {
                          _options.insert(0, (value, value));
                          _query.clear();
                        });
                        _toggle(value);
                      },
                    ),
                  for (final o in visible)
                    ListTile(
                      dense: true,
                      title: Text(o.$2, style: Ob.body(15, color: Ob.ink)),
                      trailing: _chosen.contains(o.$1)
                          ? const Icon(Icons.check_circle, color: Ob.ink)
                          : const Icon(Icons.circle_outlined, color: Ob.lineStrong),
                      onTap: () => _toggle(o.$1),
                    ),
                  if (visible.isEmpty && !canAddCustom)
                    Padding(
                      padding: const EdgeInsets.all(22),
                      child: Text('Nothing matches "${_query.text.trim()}".',
                          style: Ob.body(14.5, color: Ob.inkMuted)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
