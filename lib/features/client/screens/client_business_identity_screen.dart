import 'package:orchestrate_app/core/ui/screen_memory.dart';
import 'package:flutter/material.dart';

import 'package:orchestrate_app/data/repositories/client/client_business_identity_repository.dart';
import 'package:orchestrate_app/data/repositories/client/client_campaign_repository.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';
import 'package:orchestrate_app/features/guidance/guidance_drawer.dart';
import 'package:orchestrate_app/features/guidance/widgets/why_affordance.dart';
import 'package:orchestrate_app/core/theme/workspace_theme.dart';

/// Business identity / commercial profile surface.
///
/// Doctrine: this screen is the single place where a client teaches
/// Orchestrate "who should you represent, what do you sell, who
/// should you reach, what should you never claim, how should you
/// operate". Not a CRM profile. Not a marketing-branding toy. Partial
/// saves work. Required vs recommended is named plainly on every
/// section. Inline Why? affordances open the guidance drawer with
/// the right explain target.
class ClientBusinessIdentityScreen extends StatefulWidget {
  const ClientBusinessIdentityScreen({super.key});

  @override
  State<ClientBusinessIdentityScreen> createState() =>
      _ClientBusinessIdentityScreenState();
}

class _ClientBusinessIdentityScreenState
    extends State<ClientBusinessIdentityScreen> {
  final ClientBusinessIdentityRepository _repository =
      ClientBusinessIdentityRepository();

  late Future<_IdentityViewModel> _future = ScreenMemory.keep('representation', _load());

  // Section editors keep their own controllers so partial saves work
  // without re-typing everything on each load.
  final TextEditingController _legalName = TextEditingController();
  // THE ADDRESS THIS BUSINESS PUBLISHES.
  //
  // Readiness on this very screen refused outbound without one, and the only
  // field for it in the whole product was a free-text compliance footer on the
  // signature card in Workspace settings. The gate lived here and the field
  // lived three surfaces away, which is why the refusal named the wrong place.
  final TextEditingController _addressLine1 = TextEditingController();
  final TextEditingController _addressLine2 = TextEditingController();
  final TextEditingController _addressLocality = TextEditingController();
  final TextEditingController _addressRegion = TextEditingController();
  final TextEditingController _addressPostcode = TextEditingController();
  final TextEditingController _addressCountry = TextEditingController();
  final TextEditingController _displayName = TextEditingController();
  final TextEditingController _websiteUrl = TextEditingController();
  final TextEditingController _industry = TextEditingController();
  final TextEditingController _country = TextEditingController();
  final TextEditingController _timezone = TextEditingController();
  final TextEditingController _outboundOffer = TextEditingController();
  final TextEditingController _valueProps = TextEditingController();
  final TextEditingController _differentiators = TextEditingController();
  final TextEditingController _industryTags = TextEditingController();
  final TextEditingController _geoTargets = TextEditingController();
  final TextEditingController _titleKeywords = TextEditingController();
  final TextEditingController _exclusionKeywords = TextEditingController();
  final TextEditingController _disallowedMarkets = TextEditingController();
  final TextEditingController _voiceTone = TextEditingController();
  final TextEditingController _forbiddenClaims = TextEditingController();
  final TextEditingController _complianceConstraints = TextEditingController();
  final TextEditingController _requiredDisclaimers = TextEditingController();
  final TextEditingController _outreachPosture = TextEditingController();
  final TextEditingController _pacingPreference = TextEditingController();
  final TextEditingController _replyHandling = TextEditingController();
  final TextEditingController _followUpSensitivity = TextEditingController();

  bool _savingSection = false;
  String? _resultMessage;

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _legalName,
      _addressLine1,
      _addressLine2,
      _addressLocality,
      _addressRegion,
      _addressPostcode,
      _addressCountry,
      _displayName,
      _websiteUrl,
      _industry,
      _country,
      _timezone,
      _outboundOffer,
      _valueProps,
      _differentiators,
      _industryTags,
      _geoTargets,
      _titleKeywords,
      _exclusionKeywords,
      _disallowedMarkets,
      _voiceTone,
      _forbiddenClaims,
      _complianceConstraints,
      _requiredDisclaimers,
      _outreachPosture,
      _pacingPreference,
      _replyHandling,
      _followUpSensitivity,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<_IdentityViewModel> _load() async {
    final raw = await _repository.fetchProfile();
    final profile = asMap(raw['profile']);
    final icp = asMap(profile['icp']);
    final readinessRaw = await _repository.fetchReadiness();
    _hydrateControllers(profile, icp);
    return _IdentityViewModel(
      profile: profile,
      icp: icp,
      sections: asList(raw['sections']).map(asMap).toList(),
      readiness: readinessRaw,
    );
  }

  void _hydrateControllers(Map<String, dynamic> profile, Map<String, dynamic> icp) {
    _legalName.text = readText(profile, 'legalName');
    final address = asMap(profile['postalAddress']);
    _addressLine1.text = readText(address, 'line1');
    _addressLine2.text = readText(address, 'line2');
    _addressLocality.text = readText(address, 'locality');
    _addressRegion.text = readText(address, 'region');
    _addressPostcode.text = readText(address, 'postalCode');
    _addressCountry.text = readText(address, 'countryCode');
    _displayName.text = readText(profile, 'displayName');
    _websiteUrl.text = readText(profile, 'websiteUrl');
    _industry.text = readText(profile, 'industry');
    _country.text = readText(profile, 'country');
    _timezone.text = readText(profile, 'primaryTimezone');
    _outboundOffer.text = readText(profile, 'outboundOffer');
    _valueProps.text = _joinList(profile['valuePropositions']);
    _differentiators.text = _joinList(profile['differentiators']);
    _industryTags.text = _joinList(icp['industryTags']);
    _geoTargets.text = _joinList(icp['geoTargets']);
    _titleKeywords.text = _joinList(icp['titleKeywords']);
    _exclusionKeywords.text = _joinList(icp['exclusionKeywords']);
    _disallowedMarkets.text = _joinList(icp['disallowedMarkets']);
    _voiceTone.text = readText(profile, 'voiceTone');
    _forbiddenClaims.text = _joinList(profile['forbiddenClaims']);
    _complianceConstraints.text = _joinList(profile['complianceConstraints']);
    _requiredDisclaimers.text = _joinList(profile['requiredDisclaimers']);
    _outreachPosture.text = readText(profile, 'outreachPosture');
    _pacingPreference.text = readText(profile, 'pacingPreference');
    _replyHandling.text = readText(profile, 'replyHandlingPreference');
    _followUpSensitivity.text = readText(profile, 'followUpSensitivity');
  }

  String _joinList(dynamic raw) {
    if (raw is List) {
      return raw.whereType<String>().join(', ');
    }
    return '';
  }

  List<String> _splitList(String value) {
    return value
        .split(RegExp(r'[\n,]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  /// THE CONFIRMATION WAS AT THE TOP OF THE PAGE.
  ///
  /// It existed all along — a "Latest save" panel above the readiness summary
  /// — and on a phone nobody ever saw it. The sections are tall, so saving
  /// "Where it operates" put the only evidence the save happened several
  /// screens above the button that was pressed. On a Pixel the form simply went
  /// quiet: no spinner, no message, nothing to distinguish saved from ignored.
  /// The value had in fact been written, which is the worse version of this —
  /// it teaches people to press Save twice.
  ///
  /// Said where the person is looking now. An error also stays in the panel,
  /// because a failure has to survive being glanced away from; a success does
  /// not need to persist once it has been seen.
  /// What to say about an address depends on which source is answering.
  ///
  /// A business can satisfy the requirement from the legacy free-text block
  /// on its signature while having designated no structured address at all.
  /// Leaving this form empty beside a satisfied gate, with no explanation,
  /// would read as a bug.
  String _addressSubtitle(String source) {
    switch (source) {
      case 'AUTHORED_BLOCK':
        return 'Commercial outbound must carry a postal address. Yours is '
            'currently coming from the free-text block on your signature, '
            'which still works. Entering it here records it properly, as a '
            'structured address this business owns.';
      case 'DESIGNATED':
        return 'The address this business publishes on its correspondence. '
            'Counterparties see it on the footer of what they receive. '
            'Replacing it keeps the previous one on record.';
      default:
        return 'Commercial outbound must carry a postal address by law, so '
            'nothing is sent until this is here. Counterparties see it on '
            'the footer of what they receive.';
    }
  }

  Future<void> _saveSection(Map<String, dynamic> patch, {String? message}) async {
    setState(() => _savingSection = true);
    try {
      final result = await _repository.patchProfile(patch);
      final readiness = asMap(result['readiness']);
      final saved = message ?? 'Saved.';
      setState(() {
        _resultMessage = null;
        _future = _refreshAfterPatch(result, readiness);
        _savingSection = false;
      });
      _say(saved);
    } catch (error) {
      final failure = ClientErrorView.classifyError(error);
      setState(() {
        _resultMessage = failure;
        _savingSection = false;
      });
      _say(failure, error: true);
    }
  }

  void _say(String message, {bool error = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Ws.critical : Ws.ink,
          duration: Duration(seconds: error ? 6 : 3),
        ),
      );
  }

  Future<_IdentityViewModel> _refreshAfterPatch(
    Map<String, dynamic> patchResult,
    Map<String, dynamic> readiness,
  ) async {
    final profile = asMap(patchResult['profile']);
    final icp = asMap(profile['icp']);
    _hydrateControllers(profile, icp);
    return _IdentityViewModel(
      profile: profile,
      icp: icp,
      sections: const [],
      readiness: readiness,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_IdentityViewModel>(
      future: _future,
      // What this screen was last told. Returning to it paints that
      // immediately rather than blanking; the request still goes out,
      // and its answer replaces this one underneath.
      initialData: ScreenMemory.recall<_IdentityViewModel>('representation'),
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const ClientLoadingView(
            eyebrow: 'Representation',
            label: 'Loading representation infrastructure',
          );
        }
        if ((snapshot.hasError || snapshot.data == null)
            && !snapshot.hasData) {
          return ClientErrorView.fromError(
            snapshot.error,
            title: 'Representation is temporarily unavailable',
            onRetry: () => setState(() => _future = ScreenMemory.keep('representation', _load())),
          );
        }
        final data = snapshot.data!;
        final readiness = data.readiness;
        final missingRequired = asList(readiness['missingRequired']).map(asMap).toList();
        final missingRecommended =
            asList(readiness['missingRecommended']).map(asMap).toList();
        final completenessScore = (readiness['completenessScore'] ?? 0) as num;
        final requiredComplete = readiness['requiredComplete'] == true;

        return ClientPage(
          eyebrow: 'Representation',
          title: 'How Orchestrate represents your business operationally',
          subtitle:
              'What Orchestrate needs to know before it can represent your '
              'business. Some of it is required and some of it sharpens the '
              'result — both are marked. You can save as you go, and managed '
              'execution begins once the required parts are in place.',
          banner: ClientStatusBanner(
            tone: requiredComplete
                ? ClientBannerTone.success
                : ClientBannerTone.warning,
            title: requiredComplete
                ? 'Business identity is sufficient for managed execution'
                : missingRequired.length == 1
                    ? 'One required detail is still missing'
                    : '${missingRequired.length} required details are still '
                        'missing',
            message: requiredComplete
                ? 'Adding the recommended details below sharpens who Orchestrate '
                    'looks for and what it says on your behalf.'
                // Named rather than counted-then-truncated: the banner used to
                // say six and then list three, which reads as a bug.
                : _named(missingRequired),
          ),
          actions: [
            WhyAffordance(
              target: requiredComplete
                  ? GuidanceTarget.readiness
                  : GuidanceTarget
                      .signalQualificationRejected, // placeholder — see below
              surface: 'client_business_identity_screen',
              label: 'Explain this state',
            ),
          ],
          children: [
            if (_resultMessage != null) ...[
              ClientPanel(
                title: 'Last save did not go through',
                children: [
                  ClientInfoRow(title: 'Status', primary: _resultMessage!),
                ],
              ),
              const SizedBox(height: 18),
            ],
            _ReadinessSummaryPanel(
              completenessScore: completenessScore.toInt(),
              requiredComplete: requiredComplete,
              missingRequired: missingRequired,
              missingRecommended: missingRecommended,
            ),
            const SizedBox(height: 18),
            // ── WHO THIS BUSINESS IS, AND WHO SEES WHAT ──────────────
            //
            // These six fields were one block called "Representation
            // profile", which treated a legal name and a timezone as the same
            // kind of edit. They are not. A legal name is what the business
            // commits as on an agreement; a display name is what a
            // counterparty reads on an email; a timezone is scheduling.
            //
            // Split by consequence, because that is the question somebody
            // editing them actually has — who sees this, and what does
            // changing it change.
            _IdentitySectionCard(
              title: 'Legal identity',
              subtitle:
                  'The name this business commits under. It appears on '
                  'agreements and invoices, and it is not what counterparties '
                  'see day to day.',
              guidanceLabel: 'Why this matters',
              // ignore: sort_child_properties_last
              child: _FieldRow(children: [
                _Field(
                  label: 'Legal name',
                  controller: _legalName,
                  required: true,
                  width: _FieldWidth.medium,
                  affects: 'Used on agreements and invoices.',
                ),
              ]),
              onSave: _savingSection
                  ? null
                  : () => _saveSection({'legalName': _legalName.text.trim()}),
            ),
            const SizedBox(height: 16),
            _IdentitySectionCard(
              title: 'Registered address',
              subtitle: _addressSubtitle(readText(data.profile, 'postalAddressSource')),
              guidanceLabel: 'Why this matters',
              // ignore: sort_child_properties_last
              child: _FieldRow(children: [
                _Field(
                  label: 'Address line 1',
                  controller: _addressLine1,
                  required: true,
                  width: _FieldWidth.full,
                  affects: 'Carried on every commercial message.',
                ),
                _Field(
                  label: 'Address line 2',
                  controller: _addressLine2,
                  required: false,
                  width: _FieldWidth.full,
                ),
                _Field(
                  label: 'City',
                  controller: _addressLocality,
                  required: false,
                  width: _FieldWidth.medium,
                ),
                _Field(
                  label: 'State or region',
                  controller: _addressRegion,
                  required: false,
                  width: _FieldWidth.medium,
                ),
                _Field(
                  label: 'Postal code',
                  controller: _addressPostcode,
                  required: false,
                  width: _FieldWidth.compact,
                ),
                _Field(
                  label: 'Country code',
                  controller: _addressCountry,
                  required: true,
                  width: _FieldWidth.compact,
                  affects: 'Two letters, such as US or GB.',
                ),
              ]),
              onSave: _savingSection
                  ? null
                  : () => _saveSection({
                        'postalAddress': {
                          'line1': _addressLine1.text.trim(),
                          'line2': _addressLine2.text.trim(),
                          'locality': _addressLocality.text.trim(),
                          'region': _addressRegion.text.trim(),
                          'postalCode': _addressPostcode.text.trim(),
                          'countryCode':
                              _addressCountry.text.trim().toUpperCase(),
                        }
                      }, message: 'Registered address saved.'),
            ),
            const SizedBox(height: 16),
            _IdentitySectionCard(
              title: 'How counterparties see this business',
              subtitle:
                  'What appears on correspondence. Changing these changes what '
                  'the people you write to read.',
              // ignore: sort_child_properties_last
              child: _FieldRow(children: [
                _Field(
                  label: 'Display name',
                  controller: _displayName,
                  required: true,
                  width: _FieldWidth.medium,
                  affects: 'Shown on every message that leaves the business.',
                ),
                _Field(
                  label: 'Website',
                  controller: _websiteUrl,
                  required: true,
                  hint: 'https://example.com',
                  width: _FieldWidth.medium,
                ),
              ]),
              onSave: _savingSection
                  ? null
                  : () => _saveSection({
                        'displayName': _displayName.text.trim(),
                        'websiteUrl': _websiteUrl.text.trim(),
                      }),
            ),
            const SizedBox(height: 16),
            _IdentitySectionCard(
              title: 'Where it operates',
              subtitle:
                  'Used to find counterparties and to time what is sent. '
                  'Counterparties do not see any of it.',
              // ignore: sort_child_properties_last
              child: _FieldRow(children: [
                _Field(
                  label: 'Industry',
                  controller: _industry,
                  required: true,
                  width: _FieldWidth.medium,
                ),
                _Field(
                  label: 'Primary country',
                  controller: _country,
                  required: true,
                  hint: 'US',
                  width: _FieldWidth.compact,
                ),
                _Field(
                  label: 'Primary timezone',
                  controller: _timezone,
                  hint: 'America/Los_Angeles',
                  width: _FieldWidth.medium,
                ),
              ]),
              onSave: _savingSection
                  ? null
                  : () => _saveSection({
                        'industry': _industry.text.trim(),
                        'country': _country.text.trim(),
                        'primaryTimezone': _timezone.text.trim(),
                      }),
            ),
            const SizedBox(height: 16),
            _IdentitySectionCard(
              title: 'Commercial positioning',
              subtitle: 'Offer, value propositions, and differentiators that anchor message context for governed dispatch.',
              // ignore: sort_child_properties_last
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Field(
                    label: 'Offer / service description',
                    controller: _outboundOffer,
                    required: true,
                    multiline: true,
                    hint:
                        'One paragraph that names what you sell, the outcome you create, and the typical buyer.',
                  ),
                  _Field(
                    label: 'Value propositions (comma-separated)',
                    controller: _valueProps,
                    hint: 'Outbound that does not get blocked, Verified sending identity required, ...',
                  ),
                  _Field(
                    label: 'Differentiators (comma-separated)',
                    controller: _differentiators,
                    hint: 'What makes your offer different from the obvious alternatives',
                  ),
                ],
              ),
              onSave: _savingSection
                  ? null
                  : () => _saveSection({
                        'outboundOffer': _outboundOffer.text.trim(),
                        'valuePropositions': _splitList(_valueProps.text),
                        'differentiators': _splitList(_differentiators.text),
                      }),
            ),
            const SizedBox(height: 16),
            _IdentitySectionCard(
              title: 'Ideal customer profile',
              subtitle: 'What discovery watches for and what it never dispatches against.',
              // ignore: sort_child_properties_last
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Field(
                    label: 'Target industries (comma-separated)',
                    controller: _industryTags,
                    required: true,
                  ),
                  _Field(
                    label: 'Target geographies (comma-separated)',
                    controller: _geoTargets,
                    required: true,
                    hint: 'US, CA, UK, ...',
                  ),
                  _Field(
                    label: 'Target buyer roles / titles (comma-separated)',
                    controller: _titleKeywords,
                    hint: 'VP Sales, CRO, Head of Revenue',
                  ),
                  _Field(
                    label: 'Excluded customer types (comma-separated)',
                    controller: _exclusionKeywords,
                  ),
                  _Field(
                    label: 'Disallowed markets (comma-separated)',
                    controller: _disallowedMarkets,
                    hint: 'Geographies, segments, or buyer types Orchestrate may never target',
                  ),
                ],
              ),
              onSave: _savingSection
                  ? null
                  : () => _saveSection({
                        'icp': <String, dynamic>{
                          'industryTags': _splitList(_industryTags.text),
                          'geoTargets': _splitList(_geoTargets.text),
                          'titleKeywords': _splitList(_titleKeywords.text),
                          'exclusionKeywords': _splitList(_exclusionKeywords.text),
                          'disallowedMarkets': _splitList(_disallowedMarkets.text),
                        },
                      }),
            ),
            const SizedBox(height: 16),
            _IdentitySectionCard(
              title: 'Representation boundaries',
              subtitle: 'Voice, forbidden claims, compliance constraints, and disclaimers enforced before any send.',
              // ignore: sort_child_properties_last
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Field(label: 'Voice / tone', controller: _voiceTone, hint: 'professional / friendly / technical'),
                  _Field(
                    label: 'Forbidden claims (comma-separated)',
                    controller: _forbiddenClaims,
                    hint:
                        'Claims Orchestrate may never make on your behalf. Protects compliance and reputation.',
                  ),
                  _Field(
                    label: 'Compliance constraints (comma-separated)',
                    controller: _complianceConstraints,
                  ),
                  _Field(
                    label: 'Required disclaimers (comma-separated)',
                    controller: _requiredDisclaimers,
                  ),
                ],
              ),
              onSave: _savingSection
                  ? null
                  : () => _saveSection({
                        'voiceTone': _voiceTone.text.trim(),
                        'forbiddenClaims': _splitList(_forbiddenClaims.text),
                        'complianceConstraints': _splitList(_complianceConstraints.text),
                        'requiredDisclaimers': _splitList(_requiredDisclaimers.text),
                      }),
            ),
            const SizedBox(height: 16),
            _IdentitySectionCard(
              title: 'Execution preferences',
              subtitle: 'Posture, pacing, reply handling, and follow-up sensitivity that shape governed dispatch.',
              // ignore: sort_child_properties_last
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Field(
                    label: 'Outreach posture',
                    controller: _outreachPosture,
                    hint: 'calm / disciplined / active',
                  ),
                  _Field(
                    label: 'Pacing preference',
                    controller: _pacingPreference,
                    hint: 'gentle / standard / accelerated',
                  ),
                  _Field(
                    label: 'Reply handling preference',
                    controller: _replyHandling,
                    hint: 'auto-acknowledge / human-review / hand-off-to-meeting',
                  ),
                  _Field(
                    label: 'Follow-up sensitivity',
                    controller: _followUpSensitivity,
                    hint: 'low / medium / high',
                  ),
                ],
              ),
              onSave: _savingSection
                  ? null
                  : () => _saveSection({
                        'outreachPosture': _outreachPosture.text.trim(),
                        'pacingPreference': _pacingPreference.text.trim(),
                        'replyHandlingPreference': _replyHandling.text.trim(),
                        'followUpSensitivity': _followUpSensitivity.text.trim(),
                      }),
            ),
            const SizedBox(height: 18),
            _RepresentationAuthPanel(
              authorized: data.profile['representationAuthorized'] == true,
              loading: readiness.isEmpty,
              onAuthorized: () => setState(() => _future = ScreenMemory.keep('representation', _load())),
            ),
            const SizedBox(height: 16),
            ClientPanel(
              title: 'What changes when this is complete',
              subtitle:
                  'Orchestrate uses this identity as operational context for signal-driven discovery, qualification, governed dispatch, and representation guarantees.',
              children: const [
                ClientInfoRow(
                  title: 'Signal discovery',
                  primary:
                      'Industry + geography + ICP keywords scope what Orchestrate watches for.',
                ),
                ClientInfoRow(
                  title: 'Qualification',
                  primary:
                      'Excluded types + disallowed markets gate which signals enter governed dispatch.',
                ),
                ClientInfoRow(
                  title: 'Message context',
                  primary:
                      'Offer + value propositions + differentiators + voice anchor message generation.',
                ),
                ClientInfoRow(
                  title: 'Representation guarantees',
                  primary:
                      'Forbidden claims, compliance constraints, and required disclaimers are enforced before dispatch.',
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _IdentityViewModel {
  const _IdentityViewModel({
    required this.profile,
    required this.icp,
    required this.sections,
    required this.readiness,
  });

  final Map<String, dynamic> profile;
  final Map<String, dynamic> icp;
  final List<Map<String, dynamic>> sections;
  final Map<String, dynamic> readiness;
}

class _IdentitySectionCard extends StatelessWidget {
  const _IdentitySectionCard({
    required this.title,
    required this.subtitle,
    this.guidanceLabel,
    required this.onSave,
    required this.child,
  });

  final String title;
  final String subtitle;
  final String? guidanceLabel;
  final Widget child;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return ClientPanel(
      title: title,
      subtitle: subtitle,
      children: [
        child,
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Save section'),
            ),
            const SizedBox(width: 8),
            if (guidanceLabel != null)
              WhyAffordance(
                target: GuidanceTarget.readiness,
                surface: 'client_business_identity_screen:$title',
                label: guidanceLabel!,
              ),
          ],
        ),
      ],
    );
  }
}

/// HOW MUCH ROOM A VALUE ACTUALLY NEEDS.
///
/// Every field on this screen was full width because a Column with stretch
/// makes that the default. So an ISO country code and a timezone got the same
/// eight hundred pixels as a company's value proposition, which tells a person
/// nothing about what is expected and makes a desktop form look like a phone
/// form that grew.
///
/// Width is information. A short value in a short box is a hint that arrives
/// before the label is read.
enum _FieldWidth {
  /// Country code, timezone, reference — a handful of characters.
  compact,

  /// A name, a domain, an address.
  medium,

  /// Long-form prose that deserves a full measure.
  full,
}


/// FIELDS LAID OUT BY WHAT THEY HOLD.
///
/// A Wrap rather than a Column, so a country code and a timezone can share a
/// line on a desktop and stack on a phone without either being told to.
class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.children});

  final List<_Field> children;

  double _widthFor(_FieldWidth w, double available) {
    // Below this there is no room for two fields side by side, and forcing
    // it produces two cramped boxes instead of one usable one.
    if (available < 520) return available;
    switch (w) {
      case _FieldWidth.compact:
        return 190;
      case _FieldWidth.medium:
        return (available - 16) / 2;
      case _FieldWidth.full:
        return available;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final available = constraints.maxWidth;
      return Wrap(
        spacing: 16,
        runSpacing: 0,
        children: [
          for (final field in children)
            SizedBox(
              width: _widthFor(field.width, available),
              child: field,
            ),
        ],
      );
    });
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.required = false,
    this.hint,
    this.multiline = false,
    this.width = _FieldWidth.full,
    this.affects,
  });

  final String label;
  final TextEditingController controller;
  final bool required;
  final String? hint;
  final bool multiline;
  final _FieldWidth width;

  /// What changing this value actually does. Shown only where the answer is
  /// consequential — a legal name appears on agreements, a display name on
  /// correspondence — and omitted where the field speaks for itself.
  final String? affects;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(child: Text(label, style: theme.textTheme.titleSmall)),
              // A PILL ON ALMOST EVERY FIELD IS NOT EMPHASIS.
              //
              // Five of six fields here were required, each carrying a
              // bordered red-tinted badge. When nearly everything is marked,
              // the marking stops meaning anything and the form reads as a
              // wall of warnings. What is OPTIONAL is the rarer and more
              // useful thing to say, and it says it quietly.
              if (!required) ...[
                const SizedBox(width: 6),
                Text('optional',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: Ws.inkSubtle)),
              ],
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: multiline ? 4 : 1,
            decoration: InputDecoration(hintText: hint),
          ),
          // WHAT CHANGING THIS ACTUALLY DOES.
          //
          // Only where the answer is consequential. A legal name appears on
          // agreements; a display name is read by every counterparty. A
          // timezone explains itself and gets nothing.
          if (affects != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(affects!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Ws.inkSubtle)),
            ),
        ],
      ),
    );
  }
}

class _ReadinessSummaryPanel extends StatelessWidget {
  const _ReadinessSummaryPanel({
    required this.completenessScore,
    required this.requiredComplete,
    required this.missingRequired,
    required this.missingRecommended,
  });

  final int completenessScore;
  final bool requiredComplete;
  final List<Map<String, dynamic>> missingRequired;
  final List<Map<String, dynamic>> missingRecommended;

  @override
  Widget build(BuildContext context) {
    return ClientPanel(
      title: 'Readiness summary',
      subtitle:
          'Required gates must pass before managed execution can run. Recommended fields strengthen qualification and message context.',
      children: [
        ClientInfoRow(
          title: 'Completeness',
          primary: '$completenessScore / 100',
          trailing: ClientBadge(
            label: requiredComplete ? 'Required passed' : 'Required missing',
          ),
        ),
        if (missingRequired.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...missingRequired.map(
            (m) => ClientInfoRow(
              title: readText(m, 'label'),
              primary:
                  readText(m, 'message', fallback: 'This field is required.'),
              secondary: _sectionName(readText(m, 'section')),
              trailing: const ClientBadge(label: 'Required'),
            ),
          ),
        ],
        if (missingRecommended.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...missingRecommended.take(4).map(
                (m) => ClientInfoRow(
                  title: readText(m, 'label'),
                  primary: readText(m, 'message',
                      fallback: 'This field is recommended.'),
                  secondary: _sectionName(readText(m, 'section')),
                  trailing: const ClientBadge(label: 'Recommended'),
                ),
              ),
        ],
      ],
    );
  }
}

/// Representation authorization gate — resolved inline. Tapping "Authorize
/// representation" pops a confirmation modal that calls
/// /client/campaigns/representation-auth on the backend and refreshes the
/// representation screen in place. No scavenger-hunt navigation.
class _RepresentationAuthPanel extends StatefulWidget {
  const _RepresentationAuthPanel({
    required this.authorized,
    required this.loading,
    required this.onAuthorized,
  });

  final bool authorized;
  final bool loading;
  final VoidCallback onAuthorized;

  @override
  State<_RepresentationAuthPanel> createState() =>
      _RepresentationAuthPanelState();
}

class _RepresentationAuthPanelState extends State<_RepresentationAuthPanel> {
  final ClientCampaignRepository _campaignRepository = ClientCampaignRepository();
  bool _submitting = false;
  String? _error;

  Future<void> _confirmAndAuthorize() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Authorize Orchestrate to represent your business'),
        content: const Text(
          'Confirming this acknowledges that Orchestrate may send governed outbound dispatch on behalf of your business. Messages are sent under the verified sending identity you connect; representation boundaries (forbidden claims, compliance constraints, required disclaimers) are enforced before every send.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Authorize representation'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _campaignRepository.acceptRepresentationAuth();
      if (!mounted) return;
      setState(() => _submitting = false);
      widget.onAuthorized();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Representation authorized.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = ClientErrorView.classifyError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClientPanel(
      title: 'Representation authorization',
      subtitle:
          'Authorization for Orchestrate to send outbound on your behalf.',
      children: [
        ClientInfoRow(
          title: 'Status',
          primary: widget.loading
              ? 'Loading…'
              : widget.authorized
                  ? 'Authorized. Managed execution can run.'
                  : 'Not yet authorized. Authorization is a one-time client-owned acknowledgement.',
          trailing: widget.authorized
              ? const ClientBadge(label: 'Authorized')
              : FilledButton.icon(
                  onPressed:
                      _submitting || widget.loading ? null : _confirmAndAuthorize,
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_user_outlined, size: 18),
                  label: Text(_submitting
                      ? 'Authorizing…'
                      : 'Authorize representation'),
                ),
        ),
        if (_error != null)
          ClientInfoRow(
            title: 'Error',
            primary: _error!,
          ),
      ],
    );
  }
}


/// WHERE A MISSING DETAIL LIVES, IN WORDS A PERSON USES.
///
/// The server names sections the way the model does — business_identity,
/// market_and_offer, ideal_client — and those identifiers were printed to
/// customers verbatim, prefixed with "Section:". Unknown keys are still shown
/// rather than swallowed, just spelled like English: a section this map has
/// not met is more useful than silence.
String _sectionName(String raw) {
  const known = {
    'business_identity': 'Under Business identity',
    'market_and_offer': 'Under What you sell',
    'ideal_client': 'Under Who you sell to',
    'communication': 'Under How you communicate',
    'authorization': 'Under Authority to represent you',
  };
  final key = raw.trim();
  if (key.isEmpty) return '';
  final match = known[key];
  if (match != null) return match;
  final words = key.replaceAll('_', ' ').trim();
  return 'Under ${words[0].toUpperCase()}${words.substring(1)}';
}

/// The missing details, named. Long lists end with a count rather than a
/// truncation, so the sentence stays true however many there are.
String _named(List<dynamic> missing) {
  final labels = missing
      .map((m) => readText(m, 'label'))
      .where((s) => s.isNotEmpty)
      .toList();
  if (labels.isEmpty) return '';
  if (labels.length <= 3) return labels.join(' · ');
  final shown = labels.take(3).join(' · ');
  return '$shown · and ${labels.length - 3} more';
}
