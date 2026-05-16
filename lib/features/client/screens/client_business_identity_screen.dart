import 'package:flutter/material.dart';

import 'package:orchestrate_app/data/repositories/client/client_business_identity_repository.dart';
import 'package:orchestrate_app/data/repositories/client/client_campaign_repository.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';
import 'package:orchestrate_app/features/guidance/guidance_drawer.dart';
import 'package:orchestrate_app/features/guidance/widgets/why_affordance.dart';

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

  late Future<_IdentityViewModel> _future = _load();

  // Section editors keep their own controllers so partial saves work
  // without re-typing everything on each load.
  final TextEditingController _legalName = TextEditingController();
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

  Future<void> _saveSection(Map<String, dynamic> patch, {String? message}) async {
    setState(() => _savingSection = true);
    try {
      final result = await _repository.patchProfile(patch);
      final readiness = asMap(result['readiness']);
      setState(() {
        _resultMessage = message ?? 'Saved.';
        _future = _refreshAfterPatch(result, readiness);
        _savingSection = false;
      });
    } catch (error) {
      setState(() {
        _resultMessage = ClientErrorView.classifyError(error);
        _savingSection = false;
      });
    }
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
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ClientLoadingView(
            eyebrow: 'Representation',
            label: 'Loading representation infrastructure',
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return ClientErrorView.fromError(
            snapshot.error,
            title: 'Representation is temporarily unavailable',
            onRetry: () => setState(() => _future = _load()),
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
              'Five guided sections + authorization. Required vs recommended is named plainly. Partial saves work — readiness orchestration re-checks on each save and activates managed execution once the gates pass.',
          banner: ClientStatusBanner(
            tone: requiredComplete
                ? ClientBannerTone.success
                : ClientBannerTone.warning,
            title: requiredComplete
                ? 'Business identity is sufficient for managed execution'
                : 'Business identity is incomplete on ${missingRequired.length} required field(s)',
            message: requiredComplete
                ? 'Add the recommended fields below to lift qualification precision and message context.'
                : missingRequired
                    .take(3)
                    .map((m) => readText(m, 'label'))
                    .where((s) => s.isNotEmpty)
                    .join(' · '),
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
                title: 'Latest save',
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
            _IdentitySectionCard(
              title: 'Representation profile',
              subtitle: 'Who Orchestrate represents — the entity facts that anchor every dispatch.',
              guidanceLabel: 'Why this matters',
              // ignore: sort_child_properties_last
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Field(label: 'Legal name', controller: _legalName, required: true),
                  _Field(label: 'Display name', controller: _displayName, required: true),
                  _Field(label: 'Website URL', controller: _websiteUrl, required: true, hint: 'https://example.com'),
                  _Field(label: 'Industry / category', controller: _industry, required: true),
                  _Field(label: 'Primary country (ISO code or name)', controller: _country, required: true),
                  _Field(label: 'Primary timezone', controller: _timezone, hint: 'America/Los_Angeles'),
                ],
              ),
              onSave: _savingSection
                  ? null
                  : () => _saveSection({
                        'legalName': _legalName.text.trim(),
                        'displayName': _displayName.text.trim(),
                        'websiteUrl': _websiteUrl.text.trim(),
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
              subtitle: 'The qualification scope — what signal-driven discovery should watch for and what it should never dispatch against.',
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
              onAuthorized: () => setState(() => _future = _load()),
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

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.required = false,
    this.hint,
    this.multiline = false,
  });

  final String label;
  final TextEditingController controller;
  final bool required;
  final String? hint;
  final bool multiline;

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
              Text(label, style: theme.textTheme.titleSmall),
              if (required) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: theme.colorScheme.errorContainer),
                  ),
                  child: Text(
                    'Required',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: multiline ? 4 : 1,
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
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
              secondary: 'Section: ${readText(m, 'section')}',
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
                  secondary: 'Section: ${readText(m, 'section')}',
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
          'Required acknowledgement that Orchestrate may send outbound on the business’s behalf. Resolved inline — no scavenger-hunt navigation.',
      children: [
        ClientInfoRow(
          title: 'Status',
          primary: widget.loading
              ? 'Loading…'
              : widget.authorized
                  ? 'Authorized — managed execution can run under this representation.'
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
