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
import '../../../core/commercial/client_capabilities.dart';
import '../../../core/platform/billing_gate.dart';
import '../../../data/repositories/client/client_billing_repository.dart';
import '../../../data/repositories/client/client_business_identity_repository.dart';
import '../../../data/repositories/client/client_campaign_repository.dart';
import '../../../data/repositories/client/client_mailbox_repository.dart';
import '../../../data/repositories/client/client_outreach_repository.dart';
import '../../../data/repositories/client/client_playbook_repository.dart';
import '../../../data/repositories/client/client_representative_repository.dart';
import '../../../data/setup/buyer_suggestions.dart';
import '../../../data/setup/global_setup_options.dart';
import '../../../data/setup/metro_suggestions.dart';
import '../widgets/smtp_connect_dialog.dart';
import '../widgets/sign_off_section.dart';
import '../../../data/repositories/client/client_branding_repository.dart';
import '../../../core/config/app_config.dart';

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
//
// DD-34 (2 Oct 2026): every business is set up by the playbook for its kind.
// "When they're ready" asks which moments bring it work, and "How you get
// paid" how the work is billed; the choices themselves come from the server.
enum SetupStep { business, want, moments, offer, payment, email, plan, permission, ready }

/// The steps a person works through; "ready" is where they land.
const int _setupSteps = 8;

extension on SetupStep {
  String get key => name;
  int get number => index + 1;
  String get title => const [
        'Your business',
        'Who you want',
        'When they\'re ready',
        'What you offer',
        'How you get paid',
        'Your email',
        'Your plan',
        'Who acts for it',
        'Ready',
      ][index];
  String get subtitle => const [
        'Name, website, address',
        'Buyers and where they are',
        'The moments that bring you work',
        'In your words, with your proof',
        'Deposits, terms, retainage',
        'Where notes are sent from',
        'Only when you want to send',
        'You, your document, your yes',
        '',
      ][index];
}

/// Countries whose postal address is incomplete without a state or province.
bool _needsState(String countryCode) =>
    const {'US', 'CA', 'AU'}.contains(countryCode.trim().toUpperCase());

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
      {super.key,
      this.initialStep,
      this.oauthStatus,
      this.oauthReason,
      this.checkoutStatus,
      this.embedded = false});

  /// Inside the workspace (its sidebar around it): no screen of its own, and
  /// the steps as a strip across the top.
  final bool embedded;

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
  @override
  void didUpdateWidget(covariant OnePathSetupScreen old) {
    super.didUpdateWidget(old);
    // Arriving at another step while Setup is already open (Search, Market,
    // Today) kept the step on screen: the state outlived the new address.
    final asked = _stepFromKey(widget.initialStep);
    if (!_loading && asked != null && widget.initialStep != old.initialStep && asked != _step) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _goTo(asked);
      });
    }
  }

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

  /// "Anywhere in the world": the chosen countries and towns are searched
  /// first, then the world's main business cities.
  bool _worldwide = false;
  final Set<String> _regions = {};
  final List<String> _towns = [];

  /// The country each town was saved with, so a save never moves it. Towns
  /// in Oman were refiled under the United States because the country was
  /// guessed from area names (2 Oct 2026).
  final Map<String, String> _townCountries = {};

  // Step 4: one address; a password only where the provider needs one.
  final _address = TextEditingController();
  final _appPassword = TextEditingController();
  final _server = TextEditingController();
  Map<String, dynamic>? _recognised;

  /// "Add the records for me", when the domain's host takes our template.
  Map<String, dynamic> _autoRecords = const {};

  // Details that used to live only on the retired Business identity page
  // (DD-34): asked here, each beside the step it belongs to.
  final _legalName = TextEditingController();
  final _line2 = TextEditingController();
  final _stateRegion = TextEditingController();
  final _timezone = TextEditingController();
  final _titles = TextEditingController();
  final _neverKinds = TextEditingController();
  final _neverMarkets = TextEditingController();
  final _valueProps = TextEditingController();
  final _differentiators = TextEditingController();
  final _forbidden = TextEditingController();
  final _rules = TextEditingController();
  final _disclaimers = TextEditingController();
  String _tone = '';
  String _posture = '';
  String _pace = '';
  String _followUp = '';
  String _replies = '';
  bool _moreBusiness = false;
  bool _moreSound = false;
  final _branding = ClientBrandingRepository();
  bool _hasLogo = false;
  bool _logoBusy = false;
  String? _logoNote;

  // Step 3: what you offer, and the result a customer gets.
  final _offer = TextEditingController();
  final _offerResult = TextEditingController();
  String _lane = 'opportunity';

  // How this business wins work (DD-34). Every choice is the server's.
  final _playbooks = ClientPlaybookRepository();
  PlaybookState _playbook = PlaybookState.empty;
  String? _kindKey;
  final List<String> _roles = [];
  final List<String> _customBuyers = [];
  bool _businessesOnly = true;
  String _sizeBand = 'any';
  final Set<String> _moments = {};
  final List<String> _customMoments = [];
  final List<ProofItem> _proof = [];
  PaymentTerms? _payment;

  /// The playbook's choices, once the server has said what they are.
  bool get _guided => !_playbook.isEmpty;
  PlaybookOption? get _book => _playbook.playbookOf(_kindKey);
  Set<String> get _confirmed =>
      (_playbook.saved?.confirmed ?? const <String>[]).toSet();

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
    for (final c in [_name, _website, _line1, _city, _postcode, _offer, _offerResult]) {
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
      _name, _website, _line1, _city, _postcode, _offer, _offerResult,
      _address, _appPassword, _server,
      _deposit, _retainage, _termsDays, ..._textAnswers.values,
      _legalName, _line2, _timezone, _titles, _neverKinds,
      _neverMarkets, _valueProps, _differentiators, _forbidden, _rules, _stateRegion,
      _disclaimers,
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
        // Never fatal: without it Setup asks as it did before playbooks.
        _playbooks.fetch().catchError((_) => PlaybookState.empty),
      ]);
      // Who holds the platform, asked so the plan step never prices it twice.
      ClientCapabilities.instance.load().then((_) {
        if (mounted) setState(() {});
      }, onError: (Object _) {});
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
        _playbook = results.length > 9 && results[9] is PlaybookState
            ? results[9] as PlaybookState
            : PlaybookState.empty;
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
      // Back from the domain host after approving: read the records now.
      if (GoRouterState.of(context).uri.queryParameters['dc'] == 'done' && _domainAttached) {
        await _checkDomainNow();
      }
      _loadAutoRecords();
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
          .map(_countryCodeOf)
          .where((c) => c.isNotEmpty));
    if (_countries.isEmpty) {
      _countries.addAll(_list(draft['countries']).map((e) => '$e'));
    }
    _regions
      ..clear()
      ..addAll(_list(setup['regions'])
          .map((r) => r is Map
              ? _regionCodeOf('${r['regionCode'] ?? r['code']}',
                  '${r['regionLabel'] ?? ''}', '${r['countryCode'] ?? ''}')
              : '$r')
          .where((c) => c.isNotEmpty && _region(c) != null));
    if (_regions.isEmpty) {
      _regions.addAll(_list(draft['regions']).map((e) => '$e'));
    }
    _worldwide = setup['worldwide'] == true || draft['worldwide'] == true;
    _towns.clear();
    _townCountries.clear();
    for (final m in _list(setup['metros'])) {
      final label = m is Map ? '${m['label'] ?? ''}'.trim() : '$m'.trim();
      if (label.isEmpty) continue;
      _towns.add(label);
      final cc = m is Map ? _countryCodeOf('${m['countryCode'] ?? ''}') : '';
      if (cc.isNotEmpty) _townCountries[label.toLowerCase()] = cc;
    }
    // An old record named cities as areas ("Lahore", "Doha"). An area the
    // screen does not know is kept as a town in its own country, never
    // dropped on the next save (2 Oct 2026: fifteen were).
    for (final r in _list(setup['regions'])) {
      if (r is! Map) continue;
      final code = _regionCodeOf('${r['regionCode'] ?? r['code'] ?? ''}',
          '${r['regionLabel'] ?? ''}', '${r['countryCode'] ?? ''}');
      if (_region(code) != null) continue;
      final label = '${r['regionLabel'] ?? r['label'] ?? ''}'.trim();
      final cc = _countryCodeOf('${r['countryCode'] ?? ''}');
      if (label.isEmpty || cc.isEmpty) continue;
      if (!_towns.any((t) => t.toLowerCase() == label.toLowerCase())) _towns.add(label);
      _townCountries[label.toLowerCase()] = cc;
    }
    if (_towns.isEmpty) _towns.addAll(_list(draft['towns']).map((e) => '$e'));

    _offer.text = pick(_text(p, 'outboundOffer'), 'offer');
    _hydratePlaybook(draft);
    _hydrateDetails(p);
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

  /// The playbook as saved; a business saved before playbooks starts from
  /// the kind its industry implies, chosen by nobody until it is saved.
  void _hydratePlaybook(Map<String, dynamic> draft, {bool keepText = false}) {
    final saved = _playbook.saved;
    _kindKey = saved?.kindKey ??
        (draft['kindKey'] as String?) ??
        _playbook.suggestedKind;
    if (_playbook.kind(_kindKey) == null) _kindKey = null;
    _roles
      ..clear()
      ..addAll(saved?.buyerRoles ?? const []);
    _customBuyers
      ..clear()
      ..addAll(saved?.customBuyers ?? const []);
    // Buyers listed before playbooks are carried over, never replaced by the
    // playbook's defaults: a known buyer is chosen, anything else is kept in
    // the owner's own words.
    final book = _book;
    if (book != null && !_confirmed.contains('buyers') && _buyerKinds.isNotEmpty) {
      final byLabel = {for (final r in _kindBuyers) r.label.toLowerCase(): r.key};
      _roles.clear();
      _customBuyers.clear();
      for (final kind in _buyerKinds) {
        final key = byLabel[kind.trim().toLowerCase()];
        if (key != null) {
          if (!_roles.contains(key)) _roles.add(key);
        } else if (_customBuyers.length < 24 &&
            !_customBuyers.any((c) => c.toLowerCase() == kind.trim().toLowerCase())) {
          _customBuyers.add(kind.trim());
        }
      }
    }
    _businessesOnly = saved?.businessesOnly ?? true;
    _sizeBand = saved?.sizeBand ?? 'any';
    _moments
      ..clear()
      ..addAll(saved?.moments ?? _playbook.kind(_kindKey)?.defaultMoments ?? const []);
    _customMoments
      ..clear()
      ..addAll(saved?.customMoments ?? const []);
    _proof
      ..clear()
      ..addAll(saved?.proof ?? const []);
    _payment = saved?.payment ?? _book?.payment;
    _paymentFields();
    _hydrateAnswers(saved?.answers ?? const {});
    if (!keepText) {
      _offerResult.text = saved?.offerResult ?? (draft['offerResult'] ?? '').toString();
    }
  }

  /// The server's answer after a save. A new kind may bring a new playbook,
  /// whose buyers and moments start from its own defaults.
  void _applyPlaybook(PlaybookState state) {
    _playbook = state;
    _hydratePlaybook(const {}, keepText: true);
  }

  String _words(dynamic v) => _list(v).map((e) => '$e'.trim()).where((e) => e.isNotEmpty).join(', ');
  List<String> _wordList(TextEditingController c) => c.text
      .split(RegExp(r'[,;\n]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList();

  void _hydrateDetails(Map<String, dynamic> p) {
    final legal = _text(p, 'legalName');
    _legalName.text = legal == _text(p, 'displayName') ? '' : legal;
    final a = _map(p['postalAddress']);
    _line2.text = _text(a, 'line2');
    _stateRegion.text = _text(a, 'region');
    _timezone.text = _text(p, 'primaryTimezone');
    final icp = _map(p['icp']);
    _titles.text = _words(icp['titleKeywords']);
    _neverKinds.text = _words(icp['exclusionKeywords']);
    _neverMarkets.text = _words(icp['disallowedMarkets']);
    _valueProps.text = _words(p['valuePropositions']);
    _differentiators.text = _words(p['differentiators']);
    _forbidden.text = _words(p['forbiddenClaims']);
    _rules.text = _words(p['complianceConstraints']);
    _disclaimers.text = _words(p['requiredDisclaimers']);
    _tone = _text(p, 'voiceTone').toLowerCase();
    _posture = _text(p, 'outreachPosture').toLowerCase();
    _pace = _text(p, 'pacingPreference').toLowerCase();
    _followUp = _text(p, 'followUpSensitivity').toLowerCase();
    _replies = _text(p, 'replyHandlingPreference').toLowerCase();
    // Groups holding answers open by themselves: nothing saved looks missing.
    _moreBusiness = [_legalName, _line2].any((c) => c.text.isNotEmpty);
    _openReach = [_titles, _neverKinds, _neverMarkets].any((c) => c.text.isNotEmpty);
    _moreSound = [_forbidden, _rules, _disclaimers].any((c) => c.text.isNotEmpty) ||
        [_tone, _pace, _followUp, _replies].any((v) => v.isNotEmpty);
    _branding.fetchBranding().then((b) {
      final logo = b['logo'] ?? _map(b['branding'])['logo'];
      if (mounted) setState(() => _hasLogo = logo is Map && logo.isNotEmpty);
    }, onError: (Object _) {});
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
      'worldwide': _worldwide,
      'regions': _regions.toList(),
      'towns': _towns,
      'offer': _offer.text,
      'offerResult': _offerResult.text,
      'kindKey': _kindKey,
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

  bool get _holdsPlatform =>
      ClientCapabilities.instance.entitlement?.state.operating ?? false;

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
            (!_guided || _playbook.saved != null) &&
            _map(p['postalAddress']).isNotEmpty &&
            _text(_map(p['postalAddress']), 'line1').isNotEmpty;
        return ok ? StepState.done : StepState.todo;
      case SetupStep.want:
        final icp = _map(_profile['icp']);
        return _setupCompleted &&
                _list(icp['industryTags']).isNotEmpty &&
                _list(icp['geoTargets']).isNotEmpty &&
                (!_guided || _confirmed.contains('buyers'))
            ? StepState.done
            : StepState.todo;
      case SetupStep.moments:
        if (!_guided) return StepState.done;
        return _confirmed.contains('moments') ? StepState.done : StepState.todo;
      case SetupStep.offer:
        return _setupCompleted && _text(_profile, 'outboundOffer').isNotEmpty
            ? StepState.done
            : StepState.todo;
      case SetupStep.payment:
        if (!_guided) return StepState.done;
        return _confirmed.contains('payment') ? StepState.done : StepState.todo;
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
    for (final s in SetupStep.values.take(_setupSteps)) {
      if (_stateOf(s) == StepState.todo) return s;
    }
    return SetupStep.ready;
  }

  int get _doneCount => SetupStep.values
      .take(_setupSteps)
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
  ///
  /// Its conditions are the ones it always had: business, buyers, offer, email
  /// and plan. The two steps added before it (moments, payment) are not among
  /// them: adding them locked every existing business out of its own
  /// authority document (founder, live walk, 2 Oct 2026). And once the step is
  /// under way, or its document sent, it never locks again.
  bool get _actUnlocked =>
      _stateOf(SetupStep.permission) != StepState.todo ||
      (_document ?? const {}).isNotEmpty ||
      const [
        SetupStep.business,
        SetupStep.want,
        SetupStep.offer,
        SetupStep.email,
        SetupStep.plan,
      ].every((s) => _stateOf(s) != StepState.todo);

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
    router?.replace(
        '${widget.embedded ? '/client/setup/workspace' : '/client/setup'}?step=${s.key}');
  }

  SetupStep _next(SetupStep s) {
    // After a save, the next step still to do; ready once nothing is left.
    for (final candidate in SetupStep.values.skip(s.index + 1).take(_setupSteps)) {
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
    if (_guided ? _kindKey == null : _industryCode == null) {
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
    } else if (_needsState(_addressCountry) && _stateRegion.text.trim().isEmpty) {
      errors['address'] = 'Add the state. A postal address there is not complete without it.';
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
        if (_legalName.text.trim().isNotEmpty)
          'legalName': _legalName.text.trim()
        else if (existingLegal.isEmpty)
          'legalName': _name.text.trim(),
        if (_timezone.text.trim().isNotEmpty) 'primaryTimezone': _timezone.text.trim(),
        'websiteUrl': website,
        if (industry != null) 'industry': industry.label,
        'postalAddress': {
          'line1': _line1.text.trim(),
          if (_line2.text.trim().isNotEmpty) 'line2': _line2.text.trim(),
          if (_stateRegion.text.trim().isNotEmpty) 'region': _stateRegion.text.trim(),
          'locality': _city.text.trim(),
          'postalCode': _postcode.text.trim(),
          'countryCode': _addressCountry,
        },
      });
      final profile = _map(result['profile']);
      // The kind decides the playbook every later step offers.
      final playbook = _guided && _kindKey != null
          ? await _playbooks.save({'kindKey': _kindKey})
          : null;
      if (!mounted) return;
      setState(() {
        if (profile.isNotEmpty) _profile = profile;
        if (playbook != null) _applyPlaybook(playbook);
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
      final country = _townCountry(t);
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

  /// "Lahore · Pakistan" when the business sells in more than one country,
  /// so a town filed under the wrong one is visible before it is saved.
  String _townLabel(String town) {
    if (_countries.length < 2) return town;
    final cc = _townCountry(town);
    return '$town · ${GlobalSetupOptions.countryByCode(cc)?.label ?? cc}';
  }

  static String _shout(String s) =>
      s.toUpperCase().replaceAll(RegExp(r'[^A-Z]+'), '_').replaceAll(RegExp(r'^_|_$'), '');

  /// A country as this screen knows it. The two oldest workspaces saved names
  /// ("UNITED_STATES"), which showed as raw chips and could not be saved back,
  /// because setup takes two-letter codes (2 Oct 2026).
  static String _countryCodeOf(String raw) {
    final code = raw.trim().toUpperCase();
    if (GlobalSetupOptions.countryByCode(code) != null) return code;
    for (final c in GlobalSetupOptions.countries) {
      if (_shout(c.label) == _shout(code)) return c.code;
    }
    return code;
  }

  /// An area as this screen knows it, recovered by name for the same records.
  static String _regionCodeOf(String raw, String label, String country) {
    final cc = _countryCodeOf(country);
    final options = GlobalSetupOptions.regionsForCountry(cc);
    if (options.any((r) => r.code == raw)) return raw;
    final want = _shout(label.isNotEmpty ? label : raw);
    for (final r in options) {
      if (_shout(r.label) == want) return r.code;
    }
    return raw;
  }

  /// The chosen country a town lies in: the one whose area list names it, or
  /// the one written after a comma ("Lahore, Pakistan"). Every town used to be
  /// filed under the first country, so a business selling in the United
  /// States and Pakistan had Lahore searched for in the United States.
  String _townCountry(String town) {
    final saved = _townCountries[town.trim().toLowerCase()];
    if (saved != null && _countries.contains(saved)) return saved;
    final parts = town.split(',').map((p) => p.trim()).toList();
    if (parts.length > 1) {
      final said = parts.last.toLowerCase();
      for (final cc in _countries) {
        final label = GlobalSetupOptions.countryByCode(cc)?.label.toLowerCase();
        if (label == said || cc.toLowerCase() == said) return cc;
      }
    }
    final name = parts.first.toLowerCase();
    for (final cc in _countries) {
      for (final r in GlobalSetupOptions.regionsForCountry(cc)) {
        if (r.label.toLowerCase() == name) return cc;
      }
    }
    return _countries.isEmpty ? (_addressCountry) : _countries.first;
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
      worldwide: _worldwide,
    );
    await AuthSessionController.instance.applyClientSetupResponse(response);
    _setupCompleted = AuthSessionController.instance.hasSetupCompleted;
  }

  Future<void> _saveWant() async {
    if (_guided && _book == null) {
      setState(() => _stepError = 'Choose what kind of business it is first.');
      return;
    }
    if (_guided ? _roles.isEmpty && _customBuyers.isEmpty : _buyerKinds.isEmpty) {
      setState(() => _stepError =
          'Add at least one kind of business that buys from you.');
      return;
    }
    // "Anywhere in the world" is a market on its own; towns still need the
    // country they are in.
    if (_countries.isEmpty && (!_worldwide || _towns.isNotEmpty)) {
      setState(() => _stepError = _worldwide
          ? 'Add the country your towns are in.'
          : 'Add at least one country, or choose anywhere in the world.');
      return;
    }
    final answersWant = _answersOn('want');
    if (answersWant == null) return;
    setState(() {
      _busy = true;
      _stepError = null;
    });
    try {
      await _postSetup();
      // Guided, the server writes the buyer list from the chosen buyers, in
      // their own words; only the places are sent here.
      final playbook = _guided
          ? await _playbooks.save({
              'buyerRoles': _roles,
              'customBuyers': _customBuyers,
              'businessesOnly': _businessesOnly,
              'sizeBand': _sizeBand,
              if (answersWant.isNotEmpty) 'answers': answersWant,
            })
          : null;
      final result = await _identity.patchProfile({
        'icp': {
          if (!_guided) 'industryTags': _buyerKinds,
          'geoTargets': _geoTargets,
          'titleKeywords': _wordList(_titles),
          'exclusionKeywords': _wordList(_neverKinds),
          'disallowedMarkets': _wordList(_neverMarkets),
        },
      });
      final profile = _map(result['profile']);
      if (!mounted) return;
      setState(() {
        if (profile.isNotEmpty) _profile = profile;
        if (playbook != null) _playbook = playbook;
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
    final answersOffer = _answersOn('offer');
    if (answersOffer == null) return;
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
      final result = await _identity.patchProfile({
        'outboundOffer': offer,
        'valuePropositions': _wordList(_valueProps),
        'differentiators': _wordList(_differentiators),
        'forbiddenClaims': _wordList(_forbidden),
        'complianceConstraints': _wordList(_rules),
        'requiredDisclaimers': _wordList(_disclaimers),
        if (_tone.isNotEmpty) 'voiceTone': _tone,
        if (_posture.isNotEmpty) 'outreachPosture': _posture,
        if (_pace.isNotEmpty) 'pacingPreference': _pace,
        if (_followUp.isNotEmpty) 'followUpSensitivity': _followUp,
        if (_replies.isNotEmpty) 'replyHandlingPreference': _replies,
      });
      if (_countries.isNotEmpty) await _postSetup();
      final profile = _map(result['profile']);
      final playbook = _guided && _book != null
          ? await _playbooks.save({
              'offerResult': _offerResult.text.trim(),
              'proof': [for (final p in _proof) p.toJson()],
              if (answersOffer.isNotEmpty) 'answers': answersOffer,
            })
          : null;
      if (!mounted) return;
      setState(() {
        if (profile.isNotEmpty) _profile = profile;
        if (playbook != null) _playbook = playbook;
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

  Future<void> _loadAutoRecords() async {
    if (!_domainAttached || _domainReady) return;
    final link = await _mailbox.domainConnectLink();
    if (mounted) setState(() => _autoRecords = link);
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
  /// A store build sends nobody out to pay, so it opens Plan and billing,
  /// where the store's own purchase sheet lives.
  Future<void> _startCheckout() async {
    if (!externalPurchaseAllowed) {
      context.go('/account/plan');
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
    if (widget.embedded) {
      return Theme(
        data: Ob.theme(),
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Ob.ink, strokeWidth: 2))
            : _loadFailure != null
                ? _LoadFailure(message: _loadFailure!, onRetry: _load, onSignOut: _signOut)
                : LayoutBuilder(builder: (context, c) => _embeddedLayout(c)),
      );
    }
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

  /// Setup inside the workspace: the steps across the top, the step below.
  Widget _embeddedLayout(BoxConstraints c) {
    final phone = c.maxWidth < 700;
    final twoColumns = c.maxWidth >= 1080;
    final content = _stepContent(phone: phone);
    final side = _sideCard();
    // The steps scroll with the page. Pinned above it, their two rows took
    // about 40% of a narrow screen (2 Oct 2026).
    return SingleChildScrollView(
      key: ValueKey('setup-embedded-${_step.key}'),
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in SetupStep.values)
              _StepChip(
                number: s == SetupStep.ready ? null : s.number,
                label: s == SetupStep.ready ? 'Where it stands' : s.title,
                state: s == SetupStep.ready ? StepState.todo : _stateOf(s),
                current: s == _step,
                onTap: () => _goTo(s),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Builder(
            builder: (_) => _step == SetupStep.ready
                ? _readyView(phone: phone)
                : twoColumns && side != null
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 11, child: content),
                          const SizedBox(width: 40),
                          Expanded(flex: 9, child: side),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          content,
                          if (side != null) ...[const SizedBox(height: 28), side],
                        ],
                      ),
        ),
      ],
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
                ? 'STEP ${_step.number} OF $_setupSteps · ${_step.title.toUpperCase()}'
                : 'STEP ${_step.number} OF $_setupSteps',
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
      case SetupStep.moments:
        return _momentsStep(phone);
      case SetupStep.offer:
        return _offerStep(phone);
      case SetupStep.payment:
        return _paymentStep(phone);
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
        if (_guided)
          _kindPicker()
        else ...[
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
        ],
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
        // State sits with the town (founder walk, 3 Oct 2026): it was folded
        // under "More about your business", so a US address went into every
        // note's footer without its state.
        _pair(
          phone,
          TextField(
            controller: _city,
            autofillHints: const [AutofillHints.addressCity],
            style: Ob.body(16, color: Ob.ink),
            decoration: const InputDecoration(hintText: 'Town or city'),
          ),
          TextField(
            controller: _stateRegion,
            autofillHints: const [AutofillHints.addressState],
            style: Ob.body(16, color: Ob.ink),
            decoration: InputDecoration(
              hintText: _needsState(_addressCountry) ? 'State' : 'State or region (if any)',
            ),
          ),
        ),
        const SizedBox(height: 10),
        Builder(builder: (context) {
          final postcode = TextField(
            controller: _postcode,
            autofillHints: const [AutofillHints.postalCode],
            style: Ob.body(16, color: Ob.ink),
            decoration: const InputDecoration(hintText: 'Postcode or ZIP'),
          );
          return phone
              ? postcode
              : Row(children: [
                  Expanded(child: postcode),
                  const SizedBox(width: 16),
                  const Expanded(child: SizedBox.shrink()),
                ]);
        }),
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
        _gap(),
        _more('More about your business', _moreBusiness,
            () => setState(() => _moreBusiness = !_moreBusiness), [
          ObField(
            label: 'Legal name, if different',
            controller: _legalName,
            placeholder: 'For example: Harbour Property Group LLC',
          ),
          const SizedBox(height: 12),
          ObField(label: 'Address line 2', controller: _line2, placeholder: 'Suite or floor'),
          const SizedBox(height: 12),
          ObField(
            label: 'Time zone',
            controller: _timezone,
            placeholder: 'America/Detroit',
            hint: 'Notes go out and Today\'s email arrives in your working hours.',
          ),
          const SizedBox(height: 16),
          _logoRow(),
        ]),
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
        if (_guided)
          _buyerPicker()
        else ...[
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
        ],
        _gap(),
        Text('Where they are', style: Ob.strong(15)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (_worldwide)
            ObChoice('Anywhere in the world', onRemove: () {
              setState(() => _worldwide = false);
              _keepDraft();
            })
          else
            ObAddChoice('Anywhere in the world', onTap: () {
              setState(() {
                _worldwide = true;
                _stepError = null;
              });
              _keepDraft();
            }),
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
                ..addAll(picked.take(30));
              _regions.removeWhere(
                  (r) => !_countries.contains(r.split('-').first.toUpperCase()));
              _stepError = null;
            });
            _keepDraft();
          }),
        ]),
        if (_worldwide) ...[
          const SizedBox(height: 6),
          Text(
              'Your countries and towns are searched first, then the world\'s '
              'main business cities.',
              style: Ob.body(13, color: Ob.inkMuted)),
        ],
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
            ObChoice(_townLabel(t), onRemove: () {
              setState(() => _towns.remove(t));
              _keepDraft();
            }),
          ObAddChoice('Add a town', onTap: () async {
            final picked = await _pick(
              title: 'Towns to start with',
              options: [
                for (final s in {...suggestions, ..._towns}) (s, _townLabel(s))
              ],
              selected: _towns.toSet(),
              allowCustom: true,
              hint: _countries.length > 1
                  ? 'Type a town and its country; several with ";" — Lahore, Pakistan; Dubai, United Arab Emirates'
                  : null,
            );
            if (picked == null || !mounted) return;
            setState(() {
              _towns.clear();
              for (final raw in picked.take(120)) {
                // "Lahore, Pakistan": the town, filed under that country.
                final parts = raw.split(',').map((p) => p.trim()).toList();
                String? said;
                if (parts.length > 1) {
                  for (final cc in _countries) {
                    final label = GlobalSetupOptions.countryByCode(cc)?.label.toLowerCase();
                    if (label == parts.last.toLowerCase() || cc.toLowerCase() == parts.last.toLowerCase()) {
                      said = cc;
                    }
                  }
                }
                final t = _titleCase(said != null
                    ? parts.sublist(0, parts.length - 1).join(', ')
                    : raw.trim());
                if (t.isEmpty) continue;
                if (said != null) _townCountries[t.toLowerCase()] = said;
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
        _gap(),
        _more('People to reach, and who never to contact', _hasReachAnswers,
            () => setState(() => _openReach = !_openReach), [
          ObField(
            label: 'The people to reach',
            controller: _titles,
            placeholder: 'Estimator, facilities manager, office manager',
            hint: 'Job titles, separated by commas. Orchestrate writes to the '
                'person a business itself names for that role.',
          ),
          const SizedBox(height: 12),
          ObField(
            label: 'Kinds of business you never sell to',
            controller: _neverKinds,
            placeholder: 'Homeowners, franchises',
          ),
          const SizedBox(height: 12),
          ObField(
            label: 'Markets you stay out of',
            controller: _neverMarkets,
            placeholder: 'Gambling, tobacco',
          ),
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
        if (_guided) ...[
          _gap(),
          ObField(
            label: 'What your customer gets (optional)',
            controller: _offerResult,
            maxLength: 300,
            maxLines: 2,
            placeholder: switch (_book?.key) {
              'trade_contractor' || 'general_contractor' =>
                'For example: inspection-ready in one visit, with photos the same day.',
              'insurance_agency' =>
                'For example: cover in place before your first load.',
              _ => 'For example: the work done when promised, with one person to call.',
            },
          ),
          ..._questionsOn('offer'),
          _gap(),
          ObField(
            label: 'What customers value most (optional)',
            controller: _valueProps,
            placeholder: 'Same-day answers, one invoice a month',
            hint: 'Separated by commas.',
          ),
          const SizedBox(height: 12),
          ObField(
            label: 'What makes you different (optional)',
            controller: _differentiators,
            placeholder: 'Family-owned since 1998, union crews',
          ),
          if (_book != null) ...[
            _gap(),
            _proofSection(),
          ],
          _gap(),
          _more('How your notes sound', _moreSound,
              () => setState(() => _moreSound = !_moreSound), _soundFields()),
        ],
        _errorLine(),
        _gap(26),
        ObActions(
          primary: 'Save and continue',
          onPrimary: _saveOffer,
          secondary: 'Back',
          onSecondary: () => _goTo(SetupStep.moments),
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
        if (connected) ...[
          _gap(),
          const SignOffSection(),
        ],
        _errorLine(),
        _gap(26),
        if (connected)
          ObActions(
            primary: 'Continue',
            onPrimary: () => _goTo(_next(SetupStep.email)),
            secondary: 'Back',
            onSecondary: () => _goTo(SetupStep.payment),
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
            onSecondary: () => _goTo(SetupStep.payment),
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
          // Signed in at the domain's host, the owner approves and the
          // records are added for them.
          if (!_domainReady && _autoRecords['available'] == true) ...[
            ObCard(
              raised: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Let ${_autoRecords['host'] ?? 'your domain host'} add them for you.',
                      style: Ob.name(19)),
                  const SizedBox(height: 6),
                  Text('You sign in there, see exactly what will be added, and approve. '
                      'Nothing else in your domain changes.',
                      style: Ob.body(14.5)),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () => launchUrl(Uri.parse(_autoRecords['url'].toString()),
                        mode: LaunchMode.externalApplication),
                    child: const Text('Add the records for me'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Or add them yourself:', style: Ob.body(14, color: Ob.inkMuted)),
            const SizedBox(height: 8),
          ],
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
        _gap(),
        const SignOffSection(),
        _errorLine(),
        _gap(26),
        ObActions(
          primary: _domainReady ? 'Continue' : 'Continue, finish this later',
          onPrimary: () => _goTo(_next(SetupStep.email)),
          secondary: _domainAttached && !_domainReady ? 'Check now' : 'Back',
          onSecondary: _domainAttached && !_domainReady
              ? _checkDomainNow
              : () => _goTo(SetupStep.payment),
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
        _head(_planActive ? 'Your plan is active.' : 'Choose your plan.',
            _planActive
                ? 'Orchestrate can send the notes you approve.'
                : 'Setting up is free. A plan starts Orchestrate finding and '
                    'checking businesses for you, and sending the notes you approve.',
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
        // Never price what the organisation already holds, on any rail: the
        // entitlement decides, not a Stripe row (from the retired Subscribe
        // page, DD-34).
        if (!_planActive && !_holdsPlatform && _offers.isNotEmpty) ...[
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

  // ── Playbook steps (DD-34) ───────────────────────────────────────

  BusinessKindOption? get _kind => _playbook.kind(_kindKey);

  /// This kind's own buyers; the playbook's for a server that sends none.
  List<Labelled> get _kindBuyers =>
      (_kind?.buyerRoles.isNotEmpty ?? false) ? _kind!.buyerRoles : (_book?.buyerRoles ?? const []);
  List<ProofKind> get _kindProof =>
      (_kind?.proofKinds.isNotEmpty ?? false) ? _kind!.proofKinds : (_book?.proofKinds ?? const []);

  /// What the buyers are, said in the owner's words.
  List<String> get _buyerWords => _guided
      ? [
          for (final r in _kindBuyers)
            if (_roles.contains(r.key)) r.label,
          ..._customBuyers,
        ]
      : _buyerKinds;

  bool _kindOpen = false;

  Widget _kindPicker() {
    final chosen = _playbook.kind(_kindKey);
    final groups = <String, List<BusinessKindOption>>{};
    for (final k in _playbook.kinds) {
      groups.putIfAbsent(k.group, () => []).add(k);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('What kind of business is it?', style: Ob.strong(15)),
        const SizedBox(height: 4),
        Text('Orchestrate looks for buyers the way businesses like yours win '
            'work. Not listed? Choose the nearest.',
            style: Ob.body(13.5, color: Ob.inkMuted)),
        const SizedBox(height: 10),
        if (chosen != null && !_kindOpen)
          Wrap(spacing: 8, runSpacing: 8, children: [
            ObChoice(chosen.label),
            ObAddChoice('Change', onTap: () => setState(() => _kindOpen = true)),
          ])
        else
          for (final g in groups.entries) ...[
            Text(g.key.toUpperCase(), style: Ob.eyebrow()),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final k in g.value)
                _Toggle(k.label, on: k.key == _kindKey, onTap: () {
                  setState(() {
                    _kindKey = k.key;
                    _industryCode = k.industryCode;
                    _kindOpen = false;
                    _fieldErrors = {..._fieldErrors}..remove('industry');
                  });
                  _keepDraft();
                }),
            ]),
            const SizedBox(height: 14),
          ],
      ],
    );
  }

  Widget _needKind() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Choose what kind of business it is first; the choices here '
              'follow from it.',
              style: Ob.body(15, color: Ob.ink)),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => _goTo(SetupStep.business),
            child: const Text('Choose the kind of business'),
          ),
        ],
      );

  static const _sizeLabels = {
    'any': 'Any size',
    '1-9': '1 to 9 people',
    '10-49': '10 to 49',
    '50-249': '50 to 249',
    '250+': '250 or more',
  };

  Widget _buyerPicker() {
    final book = _book;
    if (book == null) return _needKind();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Who buys from you', style: Ob.strong(15)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final r in _kindBuyers)
            _Toggle(r.label, on: _roles.contains(r.key), onTap: () {
              setState(() {
                _roles.contains(r.key) ? _roles.remove(r.key) : _roles.add(r.key);
                _stepError = null;
              });
              _keepDraft();
            }),
          for (final c in _customBuyers)
            ObChoice(c, onRemove: () {
              setState(() => _customBuyers.remove(c));
              _keepDraft();
            }),
          if (_customBuyers.length < 24)
            ObAddChoice('In your own words', onTap: () async {
              final typed = await _askText(
                  title: 'Who else buys from you?',
                  hint: 'For example: hospitals in Ohio',
                  maxLength: 60);
              if (typed == null || !mounted) return;
              setState(() {
                if (!_customBuyers.any((c) => c.toLowerCase() == typed.toLowerCase())) {
                  _customBuyers.add(typed);
                }
                _stepError = null;
              });
              _keepDraft();
            }),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Switch.adaptive(
            value: _businessesOnly,
            onChanged: (v) {
              setState(() => _businessesOnly = v);
              _keepDraft();
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Businesses and public bodies only, never homeowners',
                style: Ob.body(15, color: Ob.ink)),
          ),
        ]),
        _gap(),
        Text('How big are they?', style: Ob.strong(15)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final band in _playbook.sizeBands)
            _Toggle(_sizeLabels[band] ?? band, on: _sizeBand == band, onTap: () {
              setState(() => _sizeBand = band);
              _keepDraft();
            }),
        ]),
        ..._questionsOn('want'),
      ],
    );
  }

  /// An example in this business's own world, never a builder for an accountant.
  (String, String) get _example => switch (_book?.key) {
        'trade_contractor' || 'general_contractor' => (
            'A builder near you won a school renovation on 20 September.',
            'a winner hires its trades within weeks, and the first credible '
                'one to ask is often the one used.'
          ),
        'insurance_agency' => (
            'A trucking company near you got its operating authority on 20 September.',
            'it must file insurance before it can haul a single load.'
          ),
        _ => (
            'A business near you announced a second location on 20 September.',
            'growth means new space, new staff and new suppliers.'
          ),
      };

  Widget _momentsStep(bool phone) {
    final book = _book;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head('When is a buyer ready for you?',
            'Businesses like yours win work at moments: a project awarded, a '
                'permit issued, a policy coming up for renewal. Keep the ones '
                'that bring you work, and Orchestrate tells you which business '
                'is at one.',
            phone: phone),
        _gap(),
        if (book == null)
          _needKind()
        else ...[
          for (final m in book.moments) ...[
            _MomentTile(
              moment: m,
              on: _moments.contains(m.key),
              onTap: () {
                setState(() {
                  _moments.contains(m.key) ? _moments.remove(m.key) : _moments.add(m.key);
                  _stepError = null;
                });
                _keepDraft();
              },
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in _customMoments)
              ObChoice(c, onRemove: () {
                setState(() => _customMoments.remove(c));
                _keepDraft();
              }),
            if (_customMoments.length < 5)
              ObAddChoice('A moment in your own words', onTap: () async {
                final typed = await _askText(
                    title: 'What happens just before a business buys from you?',
                    hint: 'For example: a restaurant changes owner',
                    maxLength: 160);
                if (typed == null || !mounted) return;
                setState(() {
                  _customMoments.add(typed);
                  _stepError = null;
                });
                _keepDraft();
              }),
          ]),
          if (_customMoments.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Moments in your own words are kept with your setup. '
                'Orchestrate watches for them once there is a public source '
                'to read them from.',
                style: Ob.body(13, color: Ob.inkMuted)),
          ],
          ..._questionsOn('moments'),
        ],
        _errorLine(),
        _gap(26),
        ObActions(
          primary: 'Save and continue',
          onPrimary: _saveMoments,
          secondary: 'Back',
          onSecondary: () => _goTo(SetupStep.want),
          busy: _busy,
        ),
      ],
    );
  }

  Future<void> _saveMoments() async {
    if (_book == null) {
      setState(() => _stepError = 'Choose what kind of business it is first.');
      return;
    }
    if (_moments.isEmpty && _customMoments.isEmpty) {
      setState(() => _stepError = 'Keep at least one moment, or write your own.');
      return;
    }
    final answers = _answersOn('moments');
    if (answers == null) return;
    await _savePlaybookStep(SetupStep.moments, {
      'moments': _moments.toList(),
      'customMoments': _customMoments,
      if (answers.isNotEmpty) 'answers': answers,
    });
  }

  /// Saves one playbook step and moves on; a refusal is the server's own.
  Future<void> _savePlaybookStep(SetupStep step, Map<String, dynamic> patch) async {
    setState(() {
      _busy = true;
      _stepError = null;
    });
    try {
      final state = await _playbooks.save(patch);
      if (!mounted) return;
      setState(() {
        _playbook = state;
        _busy = false;
        _markSaved();
      });
      _goTo(_next(step));
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

  String _momentLine() {
    final labels = [
      for (final m in _book?.moments ?? const <MomentOption>[])
        if (_moments.contains(m.key)) m.label,
      ..._customMoments,
    ];
    if (labels.isEmpty) return 'Not chosen yet';
    return labels.length == 1 ? labels.first : '${labels.first} and ${labels.length - 1} more';
  }

  // Proof

  Widget _proofSection() {
    final kinds = {for (final k in _kindProof) k.key: k};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Text('Your proof ', style: Ob.strong(15)),
          Text('(optional)', style: Ob.body(15, color: Ob.inkMuted)),
        ]),
        const SizedBox(height: 4),
        Text('What buyers ask to see before they hire you. Orchestrate can '
            'mention it in a note, and you see every note before it goes.',
            style: Ob.body(13.5, color: Ob.inkMuted)),
        const SizedBox(height: 10),
        for (final p in _proof) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            decoration: BoxDecoration(
              border: Border.all(color: Ob.line),
              borderRadius: BorderRadius.circular(Ob.radiusControl),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(child: Text(p.label, style: Ob.strong(14.5))),
                      if (p.hasFile) ...[
                        const SizedBox(width: 6),
                        const Tooltip(
                          message: 'A file is attached',
                          child: Icon(Icons.attach_file, size: 15, color: Ob.inkMuted),
                        ),
                      ],
                    ]),
                    Text(
                        [
                          p.kindLabel ?? kinds[p.kind]?.label ?? p.kind,
                          if (kinds[p.kind]?.isEvidence ?? false)
                            p.mentionable ? 'may be mentioned in notes' : 'kept private',
                          if (p.number != null) p.number!,
                          if (p.issuer != null) p.issuer!,
                          if (p.expiresOn != null) 'expires ${_dateWords(p.expiresOn!)}',
                        ].join(' · '),
                        style: Ob.body(13, color: Ob.inkMuted)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove ${p.label}',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _proof.remove(p)),
              ),
            ]),
          ),
          const SizedBox(height: 8),
        ],
        if (_proof.length < 60)
          Align(
            alignment: Alignment.centerLeft,
            child: ObAddChoice('Add proof', onTap: _addProof),
          ),
      ],
    );
  }

  static String _dateWords(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _addProof() async {
    final kinds = _kindProof;
    if (kinds.isEmpty) return;
    var kind = kinds.first;
    final label = TextEditingController();
    final number = TextEditingController();
    final issuer = TextEditingController();
    DateTime? expires;
    String? problem;
    var mentionable = true;
    final added = await showDialog<ProofItem>(
      context: context,
      builder: (context) => Theme(
        data: Ob.theme(),
        child: StatefulBuilder(
          builder: (context, set) => AlertDialog(
            backgroundColor: Ob.paper,
            title: Text('Add proof', style: Ob.strong(18)),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final k in kinds)
                        _Toggle(k.label, on: k.key == kind.key, onTap: () => set(() {
                              kind = k;
                              if (!k.expires) expires = null;
                            })),
                    ]),
                    const SizedBox(height: 16),
                    ObField(label: 'What it is', controller: label, placeholder: kind.hint, error: problem),
                    const SizedBox(height: 12),
                    if (!kind.isEvidence) ...[
                      ObField(label: 'Number (optional)', controller: number),
                      const SizedBox(height: 12),
                    ],
                    ObField(
                        label: kind.isEvidence
                            ? 'What you did, and for whom (optional)'
                            : 'Issued by (optional)',
                        controller: issuer),
                    if (kind.isEvidence) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        Switch.adaptive(
                          value: mentionable,
                          onChanged: (v) => set(() => mentionable = v),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Orchestrate may mention it in a note',
                              style: Ob.body(14.5, color: Ob.ink)),
                        ),
                      ]),
                    ],
                    if (kind.expires && !kind.isEvidence) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.event, size: 18),
                          label: Text(expires == null
                              ? 'Expiry date (optional)'
                              : 'Expires ${_dateWords(expires!.toIso8601String())}'),
                          onPressed: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: expires ?? now.add(const Duration(days: 365)),
                              firstDate: now.subtract(const Duration(days: 30)),
                              lastDate: DateTime(now.year + 10),
                            );
                            if (picked != null) set(() => expires = picked);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  if (label.text.trim().isEmpty) {
                    set(() => problem = 'Say what it is, for example: ${kind.hint.toLowerCase()}.');
                    return;
                  }
                  String? two(int n) => n.toString().padLeft(2, '0');
                  Navigator.pop(
                    context,
                    ProofItem(
                      id: '',
                      kind: kind.key,
                      kindLabel: kind.label,
                      mentionable: kind.isEvidence ? mentionable : true,
                      label: label.text.trim(),
                      number: kind.isEvidence || number.text.trim().isEmpty ? null : number.text.trim(),
                      issuer: issuer.text.trim().isEmpty ? null : issuer.text.trim(),
                      expiresOn: expires == null
                          ? null
                          : '${expires!.year}-${two(expires!.month)}-${two(expires!.day)}',
                    ),
                  );
                },
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      ),
    );
    for (final c in [label, number, issuer]) {
      c.dispose();
    }
    if (added == null || !mounted) return;
    setState(() => _proof.add(added));
  }

  // Payment

  final _deposit = TextEditingController();
  final _retainage = TextEditingController();
  final _termsDays = TextEditingController();
  String _paymentModel = 'terms';

  void _paymentFields() {
    final p = _payment;
    if (p == null) return;
    String n(double? v) => v == null ? '' : (v == v.roundToDouble() ? '${v.round()}' : '$v');
    _paymentModel = p.model;
    _deposit.text = n(p.depositPercent);
    _retainage.text = n(p.retainagePercent);
    _termsDays.text = '${p.termsDays}';
  }

  static const _paymentModels = {
    'recurring': 'A monthly or yearly subscription',
    'progress': 'Monthly, as the work progresses',
    'terms': 'An invoice when the work is done',
    'commission': 'Commission from the insurer',
  };

  Widget _paymentStep(bool phone) {
    final model = _paymentModel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head('How do you get paid?',
            'So your agreements and invoices follow the way your work is '
                'billed. Change it on any single agreement when a job differs.',
            phone: phone),
        _gap(),
        if (_book == null)
          _needKind()
        else ...[
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in _paymentModels.entries)
              if (_book!.paymentModels.contains(e.key) || e.key == model)
              _Toggle(e.value, on: model == e.key, onTap: () {
                setState(() => _paymentModel = e.key);
              }),
          ]),
          const SizedBox(height: 8),
          Text(
              switch (model) {
                'progress' => 'Each month you bill for the work done so far, '
                    'and the customer holds back a share until the job is '
                    'finished.',
                'commission' => 'The insurer pays your commission. Fees you '
                    'bill yourself follow the terms below.',
                'recurring' => 'Billed every month or year, in advance, until '
                    'the customer stops.',
                _ => 'One invoice, or one per stage, due after the work is done.',
              },
              style: Ob.body(13.5, color: Ob.inkMuted)),
          _gap(),
          _pair(
            phone,
            ObField(
              label: 'Payment due after (days)',
              controller: _termsDays,
              keyboardType: TextInputType.number,
              placeholder: '30',
            ),
            model == 'commission' || model == 'recurring'
                ? const SizedBox.shrink()
                : ObField(
                    label: 'Deposit (%, optional)',
                    controller: _deposit,
                    keyboardType: TextInputType.number,
                    placeholder: 'None',
                  ),
          ),
          if (model == 'progress') ...[
            _gap(),
            ObField(
              label: 'Retainage held until the job is finished (%)',
              controller: _retainage,
              keyboardType: TextInputType.number,
              placeholder: '10',
              hint: 'Usually 5 or 10. Leave empty if your customers hold none.',
            ),
          ],
        ],
        _errorLine(),
        _gap(26),
        ObActions(
          primary: 'Save and continue',
          onPrimary: _savePayment,
          secondary: 'Back',
          onSecondary: () => _goTo(SetupStep.offer),
          busy: _busy,
        ),
      ],
    );
  }

  Future<void> _savePayment() async {
    if (_book == null) {
      setState(() => _stepError = 'Choose what kind of business it is first.');
      return;
    }
    double? pct(TextEditingController c) =>
        c.text.trim().isEmpty ? null : double.tryParse(c.text.trim().replaceAll('%', ''));
    final days = int.tryParse(_termsDays.text.trim().isEmpty ? '30' : _termsDays.text.trim());
    if (days == null) {
      setState(() => _stepError = 'Say in how many days payment is due, for example 30.');
      return;
    }
    if ((_deposit.text.trim().isNotEmpty && pct(_deposit) == null) ||
        (_retainage.text.trim().isNotEmpty && pct(_retainage) == null)) {
      setState(() => _stepError = 'Give percentages as numbers, for example 10.');
      return;
    }
    await _savePlaybookStep(SetupStep.payment, {
      'payment': {
        'model': _paymentModel,
        'termsDays': days,
        'depositPercent': _paymentModel == 'commission' || _paymentModel == 'recurring' ? null : pct(_deposit),
        'retainagePercent': _paymentModel == 'progress' ? pct(_retainage) : null,
      },
    });
  }

  String _paymentLine() {
    if (!_confirmed.contains('payment')) return 'Not chosen yet';
    final p = _playbook.saved?.payment;
    if (p == null) return 'Not chosen yet';
    return [
      _paymentModels[p.model] ?? p.model,
      if (p.depositPercent != null && p.depositPercent! > 0) '${_pctWords(p.depositPercent!)} deposit',
      if (p.retainagePercent != null && p.retainagePercent! > 0) '${_pctWords(p.retainagePercent!)} retainage',
      'due in ${p.termsDays} days',
    ].join(' · ');
  }

  static String _pctWords(double v) => '${v == v.roundToDouble() ? v.round() : v}%';

  /// One line of the owner's own words, or null when they cancel.
  Future<String?> _askText({required String title, required String hint, required int maxLength}) async {
    final c = TextEditingController();
    final typed = await showDialog<String>(
      context: context,
      builder: (context) => Theme(
        data: Ob.theme(),
        child: AlertDialog(
          backgroundColor: Ob.paper,
          title: Text(title, style: Ob.strong(18)),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: c,
              autofocus: true,
              maxLength: maxLength,
              style: Ob.body(16, color: Ob.ink),
              decoration: InputDecoration(hintText: hint),
              onSubmitted: (v) => Navigator.pop(context, v),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Add')),
          ],
        ),
      ),
    );
    c.dispose();
    final t = (typed ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    return t.isEmpty ? null : t;
  }

  // ── Details from the retired Business identity page (DD-34) ────────

  bool _openReach = false;
  bool get _hasReachAnswers => _openReach;

  /// A quiet, optional group that opens in place; nothing in it is required.
  Widget _more(String title, bool open, VoidCallback toggle, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: toggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Icon(open ? Icons.expand_less : Icons.expand_more, size: 20, color: Ob.ink),
              const SizedBox(width: 6),
              Flexible(child: Text(title, style: Ob.strong(15))),
              Text('  (optional)', style: Ob.body(15, color: Ob.inkMuted)),
            ]),
          ),
        ),
        if (open) ...[
          const SizedBox(height: 10),
          ...children,
        ],
      ],
    );
  }

  Widget _choiceRow(String label, Map<String, String> options, String value,
      ValueChanged<String> onPick) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Ob.strong(14.5)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in options.entries)
            _Toggle(e.value, on: value == e.key, onTap: () {
              setState(() => onPick(value == e.key ? '' : e.key));
              _keepDraft();
            }),
        ]),
      ],
    );
  }

  List<Widget> _soundFields() => [
        _choiceRow('Tone', const {
          'professional': 'Professional',
          'friendly': 'Friendly',
          'plain': 'Plain and short',
          'technical': 'Technical',
        }, _tone, (v) => _tone = v),
        const SizedBox(height: 14),
        _choiceRow('How often to follow up', const {
          'low': 'Once, lightly',
          'medium': 'A couple of times',
          'high': 'Until they answer',
        }, _followUp, (v) => _followUp = v),
        const SizedBox(height: 14),
        _choiceRow('Pace', const {
          'gentle': 'A few at a time',
          'standard': 'Steady',
          'accelerated': 'As many as are ready',
        }, _pace, (v) => _pace = v),
        const SizedBox(height: 14),
        _choiceRow('When someone replies', const {
          'human-review': 'Show me every reply first',
          'auto-acknowledge': 'Thank them for me, then show me',
          'hand-off-to-meeting': 'Offer a time to talk',
        }, _replies, (v) => _replies = v),
        const SizedBox(height: 14),
        ObField(
          label: 'Claims never to make',
          controller: _forbidden,
          placeholder: 'Cheapest in town, guaranteed results',
          hint: 'Separated by commas. Orchestrate leaves them out of every note.',
        ),
        const SizedBox(height: 12),
        ObField(
          label: 'Rules your notes must follow',
          controller: _rules,
          placeholder: 'No pricing in a first note',
        ),
        const SizedBox(height: 12),
        ObField(
          label: 'Wording every note must carry',
          controller: _disclaimers,
          placeholder: 'Licensed in Michigan, licence 12345',
        ),
      ];

  /// Bumped after each upload so the preview asks for the new image.
  int _logoVersion = 0;

  Widget _logoRow() {
    final token = AuthSessionController.instance.token;
    return Row(children: [
      Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Ob.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Ob.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: _hasLogo
            ? Image.network(
                '${AppConfig.normalizedApiBaseUrl}/clients/me/branding/logo/logo_primary?v=$_logoVersion',
                headers: {'Authorization': 'Bearer $token'},
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Center(child: Icon(Icons.broken_image_outlined, color: Ob.inkFaint)),
              )
            : const Center(child: Icon(Icons.image_outlined, color: Ob.inkFaint, size: 28)),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your logo', style: Ob.strong(14.5)),
          const SizedBox(height: 2),
          Text(
              _logoNote ??
                  (_hasLogo
                      ? 'On your proposals and invoices.'
                      : 'Shown on your proposals and invoices. PNG or JPG.'),
              style: Ob.body(13, color: Ob.inkMuted)),
        ]),
      ),
      const SizedBox(width: 12),
      if (_hasLogo)
        TextButton(
          onPressed: _logoBusy ? null : _removeLogo,
          child: const Text('Remove'),
        ),
      OutlinedButton(
        onPressed: _logoBusy ? null : _pickLogo,
        child: Text(_logoBusy ? 'Working…' : _hasLogo ? 'Replace' : 'Add logo'),
      ),
    ]);
  }

  Future<void> _pickLogo() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg'],
      withData: true,
    );
    final file = picked?.files.firstOrNull;
    if (file == null || file.bytes == null) return;
    setState(() {
      _logoBusy = true;
      _logoNote = null;
    });
    try {
      final ext = (file.extension ?? '').toLowerCase();
      await _branding.uploadLogo(
        fileBytes: file.bytes!,
        filename: file.name,
        mimeType: ext == 'png' ? 'image/png' : 'image/jpeg',
        assetType: 'logo_primary',
      );
      _hasLogo = true;
      _logoVersion++;
      _logoNote = 'Saved. It appears on your proposals and invoices.';
    } catch (error) {
      _logoNote = _reasonFor(error, fallback: 'The logo could not be saved. Try a PNG or JPG under 2 MB.');
    } finally {
      if (mounted) setState(() => _logoBusy = false);
    }
  }

  Future<void> _removeLogo() async {
    setState(() => _logoBusy = true);
    try {
      await _branding.removeLogo(assetType: 'logo_primary');
      _hasLogo = false;
      _logoNote = null;
    } catch (error) {
      _logoNote = _reasonFor(error, fallback: 'The logo could not be removed just now.');
    } finally {
      if (mounted) setState(() => _logoBusy = false);
    }
  }

  // ── Questions only this kind is asked (DD-34) ─────────────────────

  final Map<String, Set<String>> _choiceAnswers = {};
  final Map<String, TextEditingController> _textAnswers = {};

  TextEditingController _answerText(String key) =>
      _textAnswers.putIfAbsent(key, TextEditingController.new);

  List<SetupQuestion> _questionsFor(String step) =>
      (_kind?.questions ?? const <SetupQuestion>[]).where((q) => q.step == step).toList();

  void _hydrateAnswers(Map<String, dynamic> answers) {
    _choiceAnswers.clear();
    for (final c in _textAnswers.values) {
      c.clear();
    }
    String n(dynamic v) => v is num ? '${v.round()}' : '';
    for (final q in _kind?.questions ?? const <SetupQuestion>[]) {
      final v = answers[q.key];
      if (v == null) continue;
      switch (q.type) {
        case 'choices':
          _choiceAnswers[q.key] = {for (final x in (v is List ? v : const [])) '$x'};
        case 'number':
          _answerText(q.key).text = n(v);
        case 'range':
          final m = v is Map ? v : const {};
          _answerText('${q.key}.min').text = n(m['min']);
          _answerText('${q.key}.max').text = n(m['max']);
        case 'dated_names':
          _answerText(q.key).text = [
            for (final r in (v is List ? v : const []))
              if (r is Map) '${r['name']}, ${r['date']}'
          ].join('\n');
        default:
          _answerText(q.key).text = '$v';
      }
    }
  }

  /// This step's answers as the server takes them, or null with the reason
  /// shown when a line cannot be read.
  Map<String, dynamic>? _answersOn(String step) {
    final out = <String, dynamic>{};
    num? number(String text) {
      final t = text.replaceAll(RegExp(r'[\s,$]'), '');
      return t.isEmpty ? null : num.tryParse(t);
    }

    for (final q in _questionsFor(step)) {
      switch (q.type) {
        case 'choices':
          out[q.key] = (_choiceAnswers[q.key] ?? const <String>{}).toList();
        case 'number':
          final raw = _answerText(q.key).text;
          final v = number(raw);
          if (raw.trim().isNotEmpty && v == null) {
            setState(() => _stepError = '${q.label}: give a number.');
            return null;
          }
          out[q.key] = v;
        case 'range':
          final lo = _answerText('${q.key}.min').text;
          final hi = _answerText('${q.key}.max').text;
          final a = number(lo);
          final b = number(hi);
          if ((lo.trim().isNotEmpty && a == null) || (hi.trim().isNotEmpty && b == null)) {
            setState(() => _stepError = '${q.label}: give amounts as numbers.');
            return null;
          }
          out[q.key] = a == null && b == null ? null : {'min': a, 'max': b};
        case 'dated_names':
          final rows = <Map<String, String>>[];
          final lines = _answerText(q.key).text.split('\n');
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i].trim();
            if (line.isEmpty) continue;
            final cut = line.lastIndexOf(',');
            final name = cut < 0 ? '' : line.substring(0, cut).trim();
            final date = cut < 0 ? '' : line.substring(cut + 1).trim();
            if (name.isEmpty || DateTime.tryParse(date) == null || date.length != 10) {
              setState(() => _stepError = '${q.label}, line ${i + 1}: write the '
                  'business, a comma, then the date, for example: Acme Trucking, 2027-01-15');
              return null;
            }
            rows.add({'name': name, 'date': date});
          }
          out[q.key] = rows;
        default:
          final t = _answerText(q.key).text.trim();
          out[q.key] = t.isEmpty ? null : t;
      }
    }
    return out;
  }

  List<Widget> _questionsOn(String step) {
    final qs = _questionsFor(step);
    if (qs.isEmpty) return const [];
    return [
      for (final q in qs) ...[
        _gap(),
        _questionField(q),
      ],
    ];
  }

  Widget _questionField(SetupQuestion q) {
    final label = Row(children: [
      Flexible(child: Text('${q.label} ', style: Ob.strong(15))),
      Text('(optional)', style: Ob.body(15, color: Ob.inkMuted)),
    ]);
    final hint = q.hint == null
        ? null
        : Text(q.hint!, style: Ob.body(13, color: Ob.inkMuted));
    Widget field(TextEditingController c, {String? placeholder, String? prefix, String? suffix, int lines = 1}) =>
        TextField(
          controller: c,
          maxLines: lines,
          minLines: lines > 1 ? 3 : 1,
          keyboardType: lines > 1
              ? TextInputType.multiline
              : (q.type == 'number' || q.type == 'range' ? TextInputType.number : TextInputType.text),
          style: Ob.body(16, color: Ob.ink),
          onChanged: (_) => _keepDraft(),
          decoration: InputDecoration(
            hintText: placeholder,
            prefixText: prefix,
            suffixText: suffix,
          ),
        );
    final Widget control;
    switch (q.type) {
      case 'choices':
        final on = _choiceAnswers.putIfAbsent(q.key, () => <String>{});
        control = Wrap(spacing: 8, runSpacing: 8, children: [
          for (final o in q.options)
            _Toggle(o.label, on: on.contains(o.key), onTap: () {
              setState(() => on.contains(o.key) ? on.remove(o.key) : on.add(o.key));
              _keepDraft();
            }),
        ]);
      case 'number':
        control = SizedBox(
          width: 220,
          child: field(_answerText(q.key), suffix: q.unit),
        );
      case 'range':
        final money = q.unit == r'$';
        control = Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 200,
            child: field(_answerText('${q.key}.min'),
                placeholder: 'From', prefix: money ? r'$ ' : null, suffix: money ? null : q.unit),
          ),
          Text('to', style: Ob.body(15, color: Ob.inkMuted)),
          SizedBox(
            width: 200,
            child: field(_answerText('${q.key}.max'),
                placeholder: 'Up to', prefix: money ? r'$ ' : null, suffix: money ? null : q.unit),
          ),
        ]);
      case 'dated_names':
        control = field(_answerText(q.key), lines: 6, placeholder: 'Acme Trucking, 2027-01-15');
      default:
        control = field(_answerText(q.key));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label,
        if (hint != null) ...[const SizedBox(height: 4), hint],
        const SizedBox(height: 8),
        control,
      ],
    );
  }

  Widget? _sideCard() {
    switch (_step) {
      case SetupStep.business:
        return _SideCard(
          label: 'HOW IT WILL LOOK AT THE FOOT OF EVERY NOTE',
          children: [
            AnimatedBuilder(
              animation: Listenable.merge(
                  [_name, _website, _line1, _line2, _city, _stateRegion, _postcode]),
              builder: (context, _) {
                final who = AuthSessionController.instance.fullName.trim();
                // The order the server renders it in every note
                // (postal-address.ts renderAddressLine): street, line 2,
                // town, "state postcode", country.
                final addressParts = [
                  _line1.text.trim(),
                  _line2.text.trim(),
                  _city.text.trim(),
                  [_stateRegion.text.trim(), _postcode.text.trim()]
                      .where((e) => e.isNotEmpty)
                      .join(' '),
                  _addressCountry.trim().toUpperCase(),
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
        final kinds = _buyerWords.isEmpty
            ? 'Businesses that buy from you'
            : _joinWords(_buyerWords);
        // Worldwide is said as that: naming four towns hid it (2 Oct 2026).
        final where = _worldwide
            ? (_geoTargets.isEmpty
                ? ' anywhere in the world'
                : ' anywhere in the world, starting with ${_joinWords(_geoTargets.take(3).toList())}')
            : _geoTargets.isEmpty
                ? ''
                : ' in ${_joinWords(_geoTargets.take(4).toList())}';
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
      case SetupStep.moments:
        return _SideCard(
          label: 'HOW A BUSINESS AT A MOMENT APPEARS',
          children: [
            Text('An example', style: Ob.body(13, color: Ob.inkMuted)),
            Text(_example.$1, style: Ob.name(20).copyWith(height: 1.35)),
            Text('Why now: ${_example.$2}', style: Ob.body(14.5, color: Ob.ink)),
            const Divider(),
            const ObAssurance('Every moment shows where it was seen and when. '
                'Nobody is contacted without your yes.'),
          ],
        );
      case SetupStep.payment:
        return _SideCard(
          label: 'WHERE THIS IS USED',
          children: [
            Text('Kept with your business, so your agreements and invoices '
                'can follow the way your work is paid.',
                style: Ob.body(15, color: Ob.ink)),
            Text('You can change the terms on any single agreement.',
                style: Ob.body(13, color: Ob.inkMuted)),
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
            _row('Your setup, kept', 'Now, free'),
            _row('Businesses found, checked and explained', 'With a plan'),
            _row('First notes written for you to approve', 'With a plan'),
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
        SetupStep.values.take(_setupSteps).where((s) => _stateOf(s) == StepState.todo).length;
    const words = ['No', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight'];
    return open == 1 ? 'One thing is still open.' : '${words[open]} things are still open.';
  }

  Widget _readyView({required bool phone}) {
    final allDone = SetupStep.values.take(_setupSteps).every((s) => _stateOf(s) != StepState.todo);
    String line(SetupStep s) {
      switch (s) {
        case SetupStep.business:
          final a = _map(_profile['postalAddress']);
          return [
            _text(_profile, 'displayName'),
            [
              _text(a, 'line1'),
              _text(a, 'locality'),
              [_text(a, 'region'), _text(a, 'postalCode')].where((e) => e.isNotEmpty).join(' '),
            ].where((e) => e.isNotEmpty).join(', '),
          ].where((e) => e.isNotEmpty).join(' · ');
        case SetupStep.want:
          final icp = _map(_profile['icp']);
          // Short enough to read whole: the kinds, then the first place and
          // how many more, never a list cut off mid-word.
          final places = _list(icp['geoTargets']).map((e) => '$e').toList();
          final where = _worldwide
              ? 'Anywhere in the world'
              : places.isEmpty
                  ? ''
                  : places.length == 1
                      ? places.first
                      : '${places.first} and ${places.length - 1} more';
          return [
            _joinWords(_list(icp['industryTags']).map((e) => '$e').take(3).toList()),
            where,
          ].where((e) => e.isNotEmpty).join(' · ');
        case SetupStep.moments:
          return _momentLine();
        case SetupStep.offer:
          return _text(_profile, 'outboundOffer');
        case SetupStep.payment:
          return _paymentLine();
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
              : 'Not chosen yet. A plan starts finding businesses.';
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
          for (final s in SetupStep.values.take(_setupSteps))
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

  bool _picking = false;

  Future<Set<String>?> _pick({
    required String title,
    required List<(String, String)> options,
    required Set<String> selected,
    bool single = false,
    bool allowCustom = false,
    String? hint,
  }) async {
    // One picker at a time. A second tap opened a second sheet, and the older
    // sheet's Done then overwrote the newer choices (2 Oct 2026).
    if (_picking) return null;
    _picking = true;
    try {
      return await _openPicker(
          title: title,
          options: options,
          selected: selected,
          single: single,
          allowCustom: allowCustom,
          hint: hint);
    } finally {
      _picking = false;
    }
  }

  Future<Set<String>?> _openPicker({
    required String title,
    required List<(String, String)> options,
    required Set<String> selected,
    required bool single,
    required bool allowCustom,
    String? hint,
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
          hint: hint,
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

/// A choice that is on or off, in the same pill as the chosen chips.
class _Toggle extends StatelessWidget {
  const _Toggle(this.label, {required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: on,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Ob.radiusPill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: on ? Ob.ink : Colors.transparent,
            border: Border.all(color: on ? Ob.ink : Ob.line, width: 1.2),
            borderRadius: BorderRadius.circular(Ob.radiusPill),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (on) ...[
              const Icon(Icons.check, size: 15, color: Ob.onInk),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(label,
                  style: Ob.body(14, color: on ? Ob.onInk : Ob.ink)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// One moment: what happens, why it matters, and whether it is watched yet.
class _MomentTile extends StatelessWidget {
  const _MomentTile({required this.moment, required this.on, required this.onTap});
  final MomentOption moment;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: on,
      label: moment.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: on ? Ob.cardSoft : Colors.transparent,
            border: Border.all(color: on ? Ob.ink : Ob.line, width: on ? 1.6 : 1.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(on ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 20, color: on ? Ob.ink : Ob.inkFaint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(moment.label, style: Ob.strong(15)),
                  const SizedBox(height: 3),
                  Text(moment.why, style: Ob.body(13.5, color: Ob.ink)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    ObPill(moment.watching ? 'Watched now' : 'Not watched yet',
                        tone: moment.watching ? PillTone.yes : PillTone.plain),
                    Text('From ${_joinWords(moment.sources)}',
                        style: Ob.body(12.5, color: Ob.inkMuted)),
                  ]),
                  if (moment.coverageSaid != null) ...[
                    const SizedBox(height: 3),
                    Text('${moment.coverageSaid}.',
                        style: Ob.body(12.5, color: Ob.inkMuted)),
                  ],
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
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

/// One step in the strip across the top of Setup inside the workspace.
class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.number,
    required this.label,
    required this.state,
    required this.current,
    required this.onTap,
  });
  final int? number;
  final String label;
  final StepState state;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = state == StepState.done;
    final waiting = state == StepState.waiting;
    return InkWell(
      borderRadius: BorderRadius.circular(Ob.radiusPill),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: current ? Ob.ink : Ob.card,
          borderRadius: BorderRadius.circular(Ob.radiusPill),
          border: Border.all(color: current ? Ob.ink : Ob.line),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            done
                ? Icons.check_circle
                : waiting
                    ? Icons.schedule
                    : number == null
                        ? Icons.flag_outlined
                        : Icons.radio_button_unchecked,
            size: 16,
            color: current ? Ob.onInk : (done ? Ob.ink : Ob.inkMuted),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: Ob.body(13.5,
                  color: current ? Ob.onInk : Ob.ink,
                  weight: current ? FontWeight.w600 : FontWeight.w500)),
        ]),
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
      for (var i = 0; i < _setupSteps; i++) ...[
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
                        : '$done of $_setupSteps done · about ${_setupSteps - done} ${_setupSteps - done == 1 ? 'minute' : 'minutes'} left',
                    style: Ob.body(13, color: Ob.inkMuted)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final s in SetupStep.values.take(_setupSteps))
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
    this.hint,
  });

  final String title;
  final List<(String, String)> options;
  final Set<String> selected;
  final bool single;
  final bool allowCustom;
  final String? hint;

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

  /// What the box holds, as entries: several may be pasted at once,
  /// separated by ";" or new lines. Never an empty one.
  List<String> _typed() => _query.text
      .split(RegExp(r'[;\n]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  void _addTyped() {
    final entries = _typed();
    if (entries.isEmpty) return;
    setState(() {
      for (final value in entries) {
        if (!_options.any((o) => o.$1.toLowerCase() == value.toLowerCase())) {
          _options.insert(0, (value, value));
        }
        if (!widget.single) _chosen.add(value);
      }
      _query.clear();
    });
    if (widget.single) _toggle(entries.first);
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
    final typed = _typed();
    final canAddCustom = widget.allowCustom &&
        typed.isNotEmpty &&
        !(typed.length == 1 && _options.any((o) => o.$2.toLowerCase() == q));
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
                // Read at the moment of submitting: a stale "can add" added
                // empty entries when Enter was pressed on an empty box.
                onSubmitted: (_) {
                  if (widget.allowCustom) _addTyped();
                },
                style: Ob.body(16, color: Ob.ink),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: Ob.inkMuted),
                  hintText: widget.hint ??
                      (widget.allowCustom ? 'Search or type your own' : 'Search'),
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
                      title: Text(
                          typed.length > 1
                              ? 'Add ${typed.length}: ${typed.join('; ')}'
                              : 'Add "${typed.first}"',
                          style: Ob.strong(15)),
                      onTap: _addTyped,
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
