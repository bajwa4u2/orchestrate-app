import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:orchestrate_app/app/shell/auth_shell.dart';
import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/config/pricing_config.dart';
import 'package:orchestrate_app/core/platform/billing_gate.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/client/client_billing_repository.dart';

class ClientSubscribeScreen extends StatefulWidget {
  const ClientSubscribeScreen({super.key});

  @override
  State<ClientSubscribeScreen> createState() => _ClientSubscribeScreenState();
}

class _ClientSubscribeScreenState extends State<ClientSubscribeScreen> {
  bool _loading = true;
  bool _subscribing = false;
  String? _error;

  String _planCode = 'opportunity';
  String _tierCode = 'focused';
  bool _trialRequested = false;
  PricingCatalog? _catalog;
  String? _lastAppliedRouteKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _loadCatalogAndSyncRoute());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uri = GoRouterState.of(context).uri;
    final routeKey = uri.toString();
    if (_lastAppliedRouteKey == routeKey) return;

    _lastAppliedRouteKey = routeKey;
    _syncSelectionFromUri(uri);
  }

  void _syncSelectionFromUri(Uri uri) {
    final session = AuthSessionController.instance;
    final nextPlan = _normalizedPlan(uri.queryParameters['plan']) ??
        _normalizedPlan(session.selectedPlan) ??
        'opportunity';
    final nextTier = _normalizedTier(uri.queryParameters['tier']) ??
        _normalizedTier(session.selectedTier) ??
        'focused';
    final nextTrial =
        uri.queryParameters['trial']?.trim().toLowerCase() == '15d';

    session.rememberSelection(plan: nextPlan, tier: nextTier);

    if (!mounted) return;
    setState(() {
      _planCode = nextPlan;
      _tierCode = nextTier;
      _trialRequested = nextTrial;
    });
  }

  Future<void> _loadCatalogAndSyncRoute() async {
    final uri = GoRouterState.of(context).uri;
    _lastAppliedRouteKey = uri.toString();
    _syncSelectionFromUri(uri);

    try {
      final catalog = await ClientBillingRepository().fetchPricingCatalog();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Pricing details could not be loaded at the moment.';
      });
    }
  }

  Future<void> _applySelection(
      {String? plan, String? tier, bool? trialRequested}) async {
    final nextPlan = _normalizedPlan(plan ?? _planCode) ?? 'opportunity';
    final nextTier = _normalizedTier(tier ?? _tierCode) ?? 'focused';
    final nextTrial = trialRequested ?? _trialRequested;

    await AuthSessionController.instance
        .rememberSelection(plan: nextPlan, tier: nextTier);
    if (!mounted) return;

    setState(() {
      _planCode = nextPlan;
      _tierCode = nextTier;
      _trialRequested = nextTrial;
    });

    final nextUri = Uri(
      path: '/app/subscribe',
      queryParameters: {
        'plan': nextPlan,
        'tier': nextTier,
        if (nextTrial) 'trial': '15d',
      },
    );

    final routeKey = nextUri.toString();
    if (_lastAppliedRouteKey == routeKey) return;
    _lastAppliedRouteKey = routeKey;
    context.go(routeKey);
  }

  Future<void> _activate() async {
    // App Store §3.1.1 — never open an external checkout from the
    // iOS native app. The button is hidden on iOS; this guard is a
    // belt-and-braces no-op so the callback is safe even if invoked
    // (e.g. from automated test scaffolding).
    if (!externalPurchaseAllowed) return;

    setState(() {
      _subscribing = true;
      _error = null;
    });

    try {
      final response = await ClientBillingRepository()
          .createSubscription(_planCode, _tierCode);
      final url = response['checkoutUrl']?.toString();
      if (url == null || url.isEmpty) {
        throw Exception('Missing checkout URL');
      }
      final ok =
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok) throw Exception('Checkout launch failed');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Secure checkout could not open at the moment.');
    } finally {
      if (mounted) setState(() => _subscribing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog;
    final selection =
        catalog == null ? null : catalog.find(_planCode, _tierCode);
    final setupDraft = AuthSessionController.instance.setupDraft;

    return AuthShell(
      maxContentWidth: 1120,
      child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SubscribeHero(
                          planCode: _planCode,
                          trialRequested: _trialRequested,
                          trialDays: catalog?.trialDays ?? 15,
                        ),
                        const SizedBox(height: 18),
                        if (_error != null)
                          _Banner(message: _error!, error: true),
                        if (_error != null) const SizedBox(height: 18),
                        if (selection == null)
                          _MissingPricingCard(onRetry: _loadCatalogAndSyncRoute)
                        else
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final stacked = constraints.maxWidth < 940;
                              final left = Column(
                                children: [
                                  _SelectionCard(
                                    planCode: _planCode,
                                    tierCode: _tierCode,
                                    trialRequested: _trialRequested,
                                    trialDays: catalog?.trialDays ?? 15,
                                    onPlanChanged: (value) =>
                                        _applySelection(plan: value),
                                    onTierChanged: (value) =>
                                        _applySelection(tier: value),
                                    onTrialChanged: (value) =>
                                        _applySelection(trialRequested: value),
                                  ),
                                  const SizedBox(height: 18),
                                  _SummaryCard(
                                      selection: selection,
                                      trialRequested: _trialRequested),
                                  if (setupDraft != null) ...[
                                    const SizedBox(height: 18),
                                    _ScopeSnapshotCard(draft: setupDraft),
                                  ],
                                ],
                              );
                              final right = externalPurchaseAllowed
                                  ? _ReadinessCard(
                                      selection: selection,
                                      trialRequested: _trialRequested,
                                      trialDays: catalog?.trialDays ?? 15,
                                      activating: _subscribing,
                                      onActivate:
                                          _subscribing ? null : _activate,
                                      onReviewAccount: () =>
                                          context.go('/app/account'),
                                      onReviewWorkspace: () =>
                                          context.go('/app/home'),
                                    )
                                  : _IosPlanNoticeCard(
                                      selection: selection,
                                      onReviewAccount: () =>
                                          context.go('/app/account'),
                                      onReviewWorkspace: () =>
                                          context.go('/app/home'),
                                    );

                              if (stacked) {
                                return Column(children: [
                                  left,
                                  const SizedBox(height: 18),
                                  right
                                ]);
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 6, child: left),
                                  const SizedBox(width: 18),
                                  Expanded(flex: 5, child: right),
                                ],
                              );
                            },
                          ),
                      ],
                    ),
    );
  }
}

class _SubscribeHero extends StatelessWidget {
  const _SubscribeHero(
      {required this.planCode,
      required this.trialRequested,
      required this.trialDays});
  final String planCode;
  final bool trialRequested;
  final int trialDays;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.publicLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Activate managed execution',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppTheme.publicMuted)),
        const SizedBox(height: 10),
        Text('Confirm the scope of execution',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(
            externalPurchaseAllowed
                ? 'Your business identity is in place. Confirm the scope of '
                    'managed execution Orchestrate will operate, then continue '
                    'into Stripe to set up the subscription. If you selected '
                    'the trial, the trial starts there before monthly billing. '
                    'Readiness orchestration starts as soon as checkout completes.'
                : 'Your business identity is in place. Confirm the scope of '
                    'managed execution Orchestrate will operate. Plan '
                    'activation is handled on the web platform.',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppTheme.publicMuted)),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _Pill(label: 'Scope: ${_title(planCode)}'),
          if (trialRequested)
            _Pill(label: '${trialDays}-day trial selected'),
        ]),
      ]),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({
    required this.planCode,
    required this.tierCode,
    required this.trialRequested,
    required this.trialDays,
    required this.onPlanChanged,
    required this.onTierChanged,
    required this.onTrialChanged,
  });

  final String planCode;
  final String tierCode;
  final bool trialRequested;
  final int trialDays;
  final ValueChanged<String> onPlanChanged;
  final ValueChanged<String> onTierChanged;
  final ValueChanged<bool> onTrialChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.publicLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Confirm plan fit',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 18),
        DropdownButtonFormField<String>(
          value: planCode,
          items: const [
            DropdownMenuItem(value: 'opportunity', child: Text('Opportunity')),
            DropdownMenuItem(value: 'revenue', child: Text('Revenue')),
          ],
          onChanged: (value) {
            if (value != null) onPlanChanged(value);
          },
          decoration: const InputDecoration(labelText: 'Service'),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: tierCode,
          items: const [
            DropdownMenuItem(value: 'focused', child: Text('Focused')),
            DropdownMenuItem(value: 'multi', child: Text('Multi-Market')),
            DropdownMenuItem(value: 'precision', child: Text('Precision')),
          ],
          onChanged: (value) {
            if (value != null) onTierChanged(value);
          },
          decoration: const InputDecoration(labelText: 'Coverage'),
        ),
        const SizedBox(height: 18),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: trialRequested,
          onChanged: onTrialChanged,
          title: Text('Start with a ${trialDays}-day trial'),
          subtitle: Text(
            externalPurchaseAllowed
                ? 'Stripe checkout opens after you confirm this selection and sets up the subscription. The trial runs first, then monthly billing begins after it ends.'
                : 'Selection is recorded for your workspace. '
                    'Plan activation is handled on the web platform.',
          ),
        ),
      ]),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.selection, required this.trialRequested});
  final PricingPlanOption selection;
  final bool trialRequested;

  @override
  Widget build(BuildContext context) {
    final points = _selectionPoints(selection.lane, selection.tier);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: AppTheme.publicSurfaceSoft,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.publicLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('What this plan includes',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 14),
        for (final item in points) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Icon(Icons.check_circle_outline,
                  size: 18, color: AppTheme.publicAccent),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text(item,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppTheme.publicText))),
          ]),
          const SizedBox(height: 10),
        ],
        if (trialRequested)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(color: AppTheme.publicLine)),
            child: const Text(
                'Trial selected. Your plan context continues into Stripe checkout, where the subscription is set up and the trial starts before monthly billing.'),
          ),
      ]),
    );
  }
}

class _ScopeSnapshotCard extends StatelessWidget {
  const _ScopeSnapshotCard({required this.draft});

  final Map<String, dynamic> draft;

  @override
  Widget build(BuildContext context) {
    final service = draft['serviceType']?.toString() == 'revenue'
        ? 'Revenue'
        : 'Opportunity';
    final mode =
        _title(_normalizedTier(draft['scopeMode']?.toString()) ?? 'focused');
    final countries = _stringList(draft['countries']);
    final regions = _stringList(draft['regions']);
    final metros = _stringList(draft['metros']);
    final industry = draft['industryLabel']?.toString() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your setup summary',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          _SnapshotRow(label: 'Service', value: service),
          _SnapshotRow(label: 'Coverage', value: mode),
          if (countries.isNotEmpty)
            _SnapshotRow(label: 'Countries', value: countries.join(', ')),
          if (regions.isNotEmpty)
            _SnapshotRow(label: 'Regions', value: regions.join(', ')),
          if (metros.isNotEmpty)
            _SnapshotRow(label: 'Cities or metros', value: metros.join(', ')),
          if (industry.isNotEmpty)
            _SnapshotRow(label: 'Industry', value: industry),
        ],
      ),
    );
  }
}

class _SnapshotRow extends StatelessWidget {
  const _SnapshotRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.publicMuted)),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({
    required this.selection,
    required this.trialRequested,
    required this.trialDays,
    required this.activating,
    required this.onActivate,
    required this.onReviewAccount,
    required this.onReviewWorkspace,
  });

  final PricingPlanOption selection;
  final bool trialRequested;
  final int trialDays;
  final bool activating;
  final VoidCallback? onActivate;
  final VoidCallback onReviewAccount;
  final VoidCallback onReviewWorkspace;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.publicLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(trialRequested
                ? 'Ready to start your trial setup'
                : 'Ready to activate infrastructure',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Text('${_title(selection.lane)} • ${selection.label}',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(selection.monthlyLabel,
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(
            trialRequested
                ? 'Secure checkout opens next in Stripe to set up the subscription and start your ${trialDays}-day trial. No monthly billing starts today. After the trial ends, Stripe moves the subscription into monthly billing unless you change it there first. Once checkout completes, readiness orchestration begins — Orchestrate then waits on mailbox connection and sending-identity verification before activating execution.'
                : 'Secure checkout opens next in Stripe to set up monthly billing. Once checkout completes, readiness orchestration begins — Orchestrate then waits on mailbox connection and sending-identity verification before activating execution.',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppTheme.publicMuted)),
        if (trialRequested) ...[
          const SizedBox(height: 12),
          Text(
              'The ${trialDays}-day trial is attached to this selection and will appear when Stripe opens.'),
        ],
        const SizedBox(height: 18),
        SizedBox(
            width: double.infinity,
            child: FilledButton(
                onPressed: onActivate,
                child: Text(activating
                    ? 'Opening secure checkout...'
                    : 'Open secure checkout'))),
        const SizedBox(height: 12),
        Text(
          'Secure billing powered by Stripe',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppTheme.publicMuted),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          OutlinedButton(
              onPressed: onReviewWorkspace,
              child: const Text('Review workspace')),
          OutlinedButton(
              onPressed: onReviewAccount, child: const Text('Review account')),
        ]),
      ]),
    );
  }
}

/// iOS-only stand-in for [_ReadinessCard]. Renders the same plan
/// summary tile but replaces the "Begin secure checkout" CTA + Stripe
/// attribution with [kIosPlanManagementNotice]. The workspace and
/// account review actions remain so the user can leave the screen
/// without a dead end.
class _IosPlanNoticeCard extends StatelessWidget {
  const _IosPlanNoticeCard({
    required this.selection,
    required this.onReviewAccount,
    required this.onReviewWorkspace,
  });

  final PricingPlanOption selection;
  final VoidCallback onReviewAccount;
  final VoidCallback onReviewWorkspace;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.publicLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${_title(selection.lane)} • ${selection.label}',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(selection.monthlyLabel,
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        Text(kIosPlanManagementNotice,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppTheme.publicMuted)),
        const SizedBox(height: 18),
        Wrap(spacing: 10, runSpacing: 10, children: [
          OutlinedButton(
              onPressed: onReviewWorkspace,
              child: const Text('Review workspace')),
          OutlinedButton(
              onPressed: onReviewAccount, child: const Text('Review account')),
        ]),
      ]),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
            color: error ? Colors.red.shade100 : Colors.green.shade100),
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
          border: Border.all(color: AppTheme.publicLine)),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _MissingPricingCard extends StatelessWidget {
  const _MissingPricingCard({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pricing details are temporarily unavailable.',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

List<String> _selectionPoints(String lane, String tier) {
  final revenue = lane == 'revenue';
  switch (tier) {
    case 'precision':
      return [
        'High-resolution targeting for the cities and metros that matter most',
        'Priority market ordering with include or exclude control',
        revenue
            ? 'Governed execution plus revenue continuity in the same audited flow'
            : 'Governed lead-to-meeting execution with reply attribution and suppression',
      ];
    case 'multi':
      return [
        'Broader market coverage without splitting systems or readiness logic',
        'Multiple countries and regions under one governed operating surface',
        revenue
            ? 'Revenue-side continuity stays attached as markets expand'
            : 'Cross-market outreach, follow-up continuity, and reputation protection included',
      ];
    default:
      return [
        'A disciplined starting scope for one market you want governed end to end',
        'One country with regional coverage, readiness verification, and controlled follow-up',
        revenue
            ? 'Revenue continuity begins from the same governed service scope'
            : 'Lead generation, writing, dispatch, and meetings stay aligned',
      ];
  }
}

String _title(String text) => text
    .split(RegExp(r'[-_]'))
    .where((part) => part.isNotEmpty)
    .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .whereType<String>()
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }
  return const <String>[];
}

String? _normalizedPlan(String? value) {
  final text = value?.trim().toLowerCase();
  if (text == 'opportunity' || text == 'revenue') return text;
  return null;
}

String? _normalizedTier(String? value) {
  final text = value?.trim().toLowerCase();
  if (text == 'focused') return 'focused';
  if (text == 'multi' || text == 'multi-market' || text == 'multi_market') {
    return 'multi';
  }
  if (text == 'precision') return 'precision';
  return null;
}
