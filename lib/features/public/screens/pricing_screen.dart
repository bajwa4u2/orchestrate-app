import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/config/pricing_config.dart';
import 'package:orchestrate_app/core/platform/billing_gate.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/public_repository.dart';
import 'package:orchestrate_app/features/support/screens/support_drawer.dart';

/// Pricing surface aligned with the backend plan catalog.
///
/// Backend reality (see orchestrate_backend/src/billing/pricing/plan-catalog.ts):
///  - Two operational lanes: `opportunity`, `revenue`.
///  - Three execution tiers per lane: `focused`, `multi`, `precision`.
///  - Six concrete plans returned via /public/pricing as
///    { trialDays, plans[], grouped: { opportunity, revenue }, sequence }.
///
/// This screen surfaces all six plans as a 2-lane x 3-tier matrix so the
/// catalog reality is visible at a glance. The lane communicates *how far
/// the operational runtime extends*; the tier communicates *the execution
/// scope*. The boundary between client identity and Orchestrate operation
/// stays constant — only the scope changes with the plan.
class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  // No "selected lane" state — both lanes are visible. The query parameter
  // ?plan= is honored as a soft *highlight*, not a filter, so deep links
  // from `/pricing?plan=revenue` still emphasize the requested lane while
  // keeping the comparison visible.
  String? _highlightLane;
  bool _trialRequested = false;
  bool _loading = true;
  String? _error;
  PricingCatalog? _catalog;
  bool _queryInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_queryInitialized) {
      final uri = GoRouterState.of(context).uri;
      final plan = uri.queryParameters['plan']?.trim().toLowerCase();
      final trial = uri.queryParameters['trial']?.trim().toLowerCase();

      if (plan == 'revenue' || plan == 'opportunity') {
        _highlightLane = plan;
      }

      _trialRequested = trial == '15d';
      _queryInitialized = true;
      _loadPricing();
    }
  }

  Future<void> _loadPricing() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final catalog = await PublicRepository().fetchPricing();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Pricing could not be loaded at the moment.';
      });
    }
  }

  Future<void> _openSupportDrawer() async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Support',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: SupportDrawer(
                publicMode: true,
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }

  /// Initiate activation for a specific (lane, tier) pair from the catalog.
  /// The lane is sourced per-card so each of the six matrix cells routes
  /// directly to its own Stripe price downstream — no shared lane state.
  Future<void> _goForward(
      BuildContext context, String lane, String tierCode) async {
    final session = AuthSessionController.instance;
    await session.rememberSelection(plan: lane, tier: tierCode);

    final route = _route(
      '/auth/join',
      plan: lane,
      tier: tierCode,
      trialRequested: _trialRequested,
    );
    final setupRoute = _route(
      '/app/setup',
      plan: lane,
      tier: tierCode,
      trialRequested: _trialRequested,
    );
    final subscribeRoute = _route(
      '/app/subscribe',
      plan: lane,
      tier: tierCode,
      trialRequested: _trialRequested,
    );

    if (!mounted) return;

    if (!session.isAuthenticated || session.surface != 'client') {
      context.go(route);
      return;
    }

    if (!session.emailVerified) {
      context.go(
        _route(
          '/auth/verify-email',
          plan: lane,
          tier: tierCode,
          trialRequested: _trialRequested,
        ),
      );
      return;
    }

    if (!session.hasSetupCompleted) {
      context.go(setupRoute);
      return;
    }

    if (session.normalizedSubscriptionStatus != 'active') {
      context.go(subscribeRoute);
      return;
    }

    context.go('/app/home');
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Hero(
            trialRequested: _trialRequested,
            trialDays: catalog?.trialDays ?? 15,
          ),
          const SizedBox(height: 20),
          const _OperationalBoundaryCard(),
          const SizedBox(height: 20),
          _TrialToggle(
            selected: _trialRequested,
            trialDays: catalog?.trialDays ?? 15,
            onChanged: (value) => setState(() => _trialRequested = value),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            _ErrorCard(message: _error!, onRetry: _loadPricing)
          else if (catalog != null) ...[
            const _LaneAlignmentDisclosure(),
            const SizedBox(height: 14),
            _LaneMatrixSection(
              catalog: catalog,
              trialRequested: _trialRequested,
              highlightLane: _highlightLane,
              onSelect: _goForward,
            ),
            const SizedBox(height: 24),
            const _TierScopeRow(),
            const SizedBox(height: 20),
            const _InfrastructureBurdenCard(),
            const SizedBox(height: 20),
            _ActivationContinuationCard(sequence: catalog.sequence),
            const SizedBox(height: 20),
            _SupportAssistCard(onPressed: _openSupportDrawer),
            const SizedBox(height: 20),
            _Footnote(trialDays: catalog.trialDays),
          ],
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.trialRequested,
    required this.trialDays,
  });

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
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.publicAccentSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Managed execution infrastructure',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.publicAccent,
                  ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Choose the governed execution outcome you need.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Choose how much of your outbound Orchestrate governs for you, then choose how much market coverage it runs. Every plan includes governed execution, readiness verification, reputation protection, and an auditable operating trail.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          if (trialRequested) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: AppTheme.publicAccentSoft,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(color: AppTheme.publicLine),
              ),
              child: Text(
                '$trialDays-day trial selected. Stripe will set up the subscription when you continue, the trial runs first, and monthly billing starts after the trial.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.publicAccent,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrialToggle extends StatelessWidget {
  const _TrialToggle({
    required this.selected,
    required this.trialDays,
    required this.onChanged,
  });

  final bool selected;
  final int trialDays;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$trialDays-day trial',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Use this if you want Stripe checkout to set up the subscription now and start a $trialDays-day trial before monthly billing begins. The choice carries forward to whichever plan you pick below.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(value: selected, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _LaneMatrixSection extends StatelessWidget {
  const _LaneMatrixSection({
    required this.catalog,
    required this.trialRequested,
    required this.highlightLane,
    required this.onSelect,
  });

  final PricingCatalog catalog;
  final bool trialRequested;
  final String? highlightLane;
  final void Function(BuildContext, String lane, String tier) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Operational lanes.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Pick the outcome first. Opportunity governs prospecting and follow-up. Revenue adds billing continuity on top of the same governed execution foundation.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.publicMuted,
              ),
        ),
        const SizedBox(height: 20),
        _LaneBlock(
          laneCode: 'opportunity',
          laneTitle: 'Opportunity lane',
          laneCaption:
              'Start governed prospecting without burning your sending identity. Orchestrate verifies readiness, protects reputation, suppresses bad follow-up, attributes replies correctly, and keeps every dispatch auditable.',
          plans: catalog.opportunity,
          trialRequested: trialRequested,
          trialDays: catalog.trialDays,
          highlight: highlightLane == 'opportunity',
          onSelect: onSelect,
        ),
        const SizedBox(height: 20),
        _LaneBlock(
          laneCode: 'revenue',
          laneTitle: 'Revenue lane',
          laneCaption:
              'Expand governed execution into revenue continuity. Keep the same readiness checks, reputation protection, suppression, and audit trail while Orchestrate also governs invoices, reminders, statements, and payment accountability.',
          plans: catalog.revenue,
          trialRequested: trialRequested,
          trialDays: catalog.trialDays,
          highlight: highlightLane == 'revenue',
          onSelect: onSelect,
        ),
      ],
    );
  }
}

class _LaneAlignmentDisclosure extends StatelessWidget {
  const _LaneAlignmentDisclosure();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 10),
            child: Icon(
              Icons.info_outline,
              size: 16,
              color: AppTheme.publicMuted,
            ),
          ),
          Expanded(
            child: Text(
              'Pricing is aligned across lanes because the governed execution core stays the same. The difference is whether Orchestrate stops at opportunity execution or continues into revenue continuity on the same audited infrastructure.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.publicMuted,
                    height: 1.45,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LaneBlock extends StatelessWidget {
  const _LaneBlock({
    required this.laneCode,
    required this.laneTitle,
    required this.laneCaption,
    required this.plans,
    required this.trialRequested,
    required this.trialDays,
    required this.highlight,
    required this.onSelect,
  });

  final String laneCode;
  final String laneTitle;
  final String laneCaption;
  final List<PricingPlanOption> plans;
  final bool trialRequested;
  final int trialDays;
  final bool highlight;
  final void Function(BuildContext, String lane, String tier) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: highlight ? AppTheme.publicText : AppTheme.publicLine,
          width: highlight ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.publicAccentSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              laneTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.publicAccent,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            laneCaption,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 760;
              if (stacked) {
                return Column(
                  children: [
                    for (var i = 0; i < plans.length; i++) ...[
                      _TierCard(
                        lane: laneCode,
                        plan: plans[i],
                        trialRequested: trialRequested,
                        trialDays: trialDays,
                        onSelect: onSelect,
                      ),
                      if (i != plans.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < plans.length; i++) ...[
                      Expanded(
                        child: _TierCard(
                          lane: laneCode,
                          plan: plans[i],
                          trialRequested: trialRequested,
                          trialDays: trialDays,
                          onSelect: onSelect,
                        ),
                      ),
                      if (i != plans.length - 1) const SizedBox(width: 12),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.lane,
    required this.plan,
    required this.trialRequested,
    required this.trialDays,
    required this.onSelect,
  });

  final String lane;
  final PricingPlanOption plan;
  final bool trialRequested;
  final int trialDays;
  final void Function(BuildContext, String lane, String tier) onSelect;

  @override
  Widget build(BuildContext context) {
    final description = (plan.description ?? '').trim();
    final fullName = (plan.name ?? '').trim();
    final outcome = _tierOutcome(lane, plan.tier);
    final differentiators = _tierDifferentiators(lane, plan.tier);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            plan.label,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            outcome,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.publicText,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
          ),
          if (fullName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              fullName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.publicMuted,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.publicMuted,
                  ),
              children: [
                TextSpan(
                  text: plan.priceLabel,
                  style:
                      Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: AppTheme.publicText,
                          ),
                ),
                TextSpan(text: ' / ${plan.interval}'),
              ],
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.publicText,
                  ),
            ),
          ],
          const SizedBox(height: 14),
          for (final item in differentiators) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: AppTheme.publicAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.publicMuted,
                          height: 1.45,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (trialRequested) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(color: AppTheme.publicLine),
              ),
              child: Text(
                '$trialDays-day trial carries forward. Secure checkout sets up the subscription now; monthly billing starts after the trial.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.publicMuted,
                    ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (externalPurchaseAllowed)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => onSelect(context, lane, plan.tier),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.publicText,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                ),
                child: Text(
                  trialRequested
                      ? 'Continue with ${plan.label}'
                      : 'Start with ${plan.label}',
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(color: AppTheme.publicLine),
              ),
              child: Text(
                kIosPlanManagementNotice,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.publicMuted,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TierScopeRow extends StatelessWidget {
  const _TierScopeRow();

  static const _tiers = <(String, String, String)>[
    (
      'Focused',
      'Single country, multiple regions',
      'Best when you need governed execution to prove one market cleanly: one country, regional coverage, verified readiness, and protected follow-up inside a contained operating scope.',
    ),
    (
      'Multi',
      'Multiple countries, multiple regions',
      'Best when you need one governed system across several markets: expand countries and regions without splitting readiness, reply attribution, or auditability.',
    ),
    (
      'Precision',
      'City-level, prioritized markets',
      'Best when execution depends on tight targeting: prioritize cities and metros, refine where Orchestrate operates, and keep suppression, reputation protection, and auditability intact.',
    ),
  ];

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
          Text(
            'What each tier helps you accomplish.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          Text(
            'The governed execution core does not change. What changes is how much market coverage and targeting depth Orchestrate carries for you.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 760;
              if (stacked) {
                return Column(
                  children: [
                    for (var i = 0; i < _tiers.length; i++) ...[
                      _TierScopeCell(
                        tier: _tiers[i].$1,
                        scope: _tiers[i].$2,
                        body: _tiers[i].$3,
                      ),
                      if (i != _tiers.length - 1)
                        const SizedBox(height: 12),
                    ],
                  ],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < _tiers.length; i++) ...[
                      Expanded(
                        child: _TierScopeCell(
                          tier: _tiers[i].$1,
                          scope: _tiers[i].$2,
                          body: _tiers[i].$3,
                        ),
                      ),
                      if (i != _tiers.length - 1)
                        const SizedBox(width: 12),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TierScopeCell extends StatelessWidget {
  const _TierScopeCell({
    required this.tier,
    required this.scope,
    required this.body,
  });

  final String tier;
  final String scope;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tier, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            scope,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.publicAccent,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
        ],
      ),
    );
  }
}

class _ActivationContinuationCard extends StatelessWidget {
  const _ActivationContinuationCard({required this.sequence});

  final List<String> sequence;

  // Hard-coded fallback if the backend ever returns an empty sequence —
  // matches the current backend contract verbatim.
  static const _fallbackSequence = <String>[
    'Choose plan',
    'Create account',
    'Verify email',
    'Define operating profile',
    'Activate subscription',
    'Begin service',
  ];

  @override
  Widget build(BuildContext context) {
    final steps = sequence.isNotEmpty ? sequence : _fallbackSequence;
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
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 720;
              final lead = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'After you choose a plan.',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'The activation chain below is the same regardless of lane and tier. Pricing connects directly to the readiness runtime: identity is verified, transport is connected, sending domain is published, readiness flips, and managed execution starts.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.publicMuted,
                        ),
                  ),
                ],
              );
              final cta = OutlinedButton(
                onPressed: () => context.go('/activation'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.publicText,
                  side: const BorderSide(color: AppTheme.publicLine),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                ),
                child: const Text('See activation progression'),
              );

              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    lead,
                    const SizedBox(height: 14),
                    cta,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: lead),
                  const SizedBox(width: 18),
                  cta,
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < steps.length; i++) ...[
            _SequenceStep(
              index: (i + 1).toString(),
              label: steps[i],
            ),
            if (i != steps.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _SequenceStep extends StatelessWidget {
  const _SequenceStep({required this.index, required this.label});

  final String index;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.publicAccentSoft,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.publicLine),
            ),
            child: Text(
              index,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.publicAccent,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.publicText,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportAssistCard extends StatelessWidget {
  const _SupportAssistCard({required this.onPressed});

  final Future<void> Function() onPressed;

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 760;

          final left = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Need help choosing lane or tier?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                'Use guidance if the fit is unclear. Pricing remains the primary path. Support is here when scope, setup, or billing questions need a direct conversation.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.publicMuted,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  Text(
                    'Secure billing powered by Stripe',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.publicMuted,
                        ),
                  ),
                ],
              ),
            ],
          );

          final right = Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton(
                onPressed: () => onPressed(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.publicText,
                  side: const BorderSide(color: AppTheme.publicLine),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                ),
                child: const Text('Get guidance'),
              ),
              FilledButton(
                onPressed: () => GoRouter.of(context).go('/contact'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.publicText,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                ),
                child: const Text('Open contact'),
              ),
            ],
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                left,
                const SizedBox(height: 16),
                right,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: left),
              const SizedBox(width: 20),
              Expanded(
                flex: 5,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: right,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Footnote extends StatelessWidget {
  const _Footnote({required this.trialDays});

  final int trialDays;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Secure checkout uses Stripe to set up the subscription. If you start with the $trialDays-day trial, the trial runs first and monthly billing begins after it ends.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          Text(
            'Secure billing powered by Stripe',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
        ],
      ),
    );
  }
}

class _OperationalBoundaryCard extends StatelessWidget {
  const _OperationalBoundaryCard();

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
          Text(
            'The operational boundary stays constant across every plan.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          Text(
            'Identity belongs to the client. Operation belongs to Orchestrate. The plan picks how far the operational runtime extends — never the boundary itself.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 760;
              const you = _OwnershipColumn(
                ownerLabel: 'Client retains',
                title: 'You provide identity + authorization',
                tone: _OwnershipTone.client,
                items: [
                  'Business identity, market, and offer context',
                  'Mailbox transport — Google Workspace, Microsoft 365, or custom SMTP + IMAP',
                  'Sending domain (publish SPF / DKIM / DMARC at your DNS host)',
                  'Representation authorization',
                  'Commercial responsibility for who you target and what you say',
                ],
              );
              const us = _OwnershipColumn(
                ownerLabel: 'Orchestrate operates',
                title: 'We run the execution runtime',
                tone: _OwnershipTone.orchestrate,
                items: [
                  'Live DNS verification of SPF / DKIM / DMARC + automatic re-checks',
                  'Operation-scoped mailbox ingestion (header-first, body-on-match-only)',
                  'Governed dispatch + per-mailbox in-flight cap + DKIM signing',
                  'Suppression enforcement at every send path — no bypass',
                  'Reply attribution + automatic follow-up suppression on response',
                  'Readiness engine, audit trail, recovery, and operational continuity',
                ],
              );

              if (stacked) {
                return const Column(
                  children: [
                    you,
                    SizedBox(height: 16),
                    us,
                  ],
                );
              }

              return const IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: you),
                    SizedBox(width: 18),
                    Expanded(child: us),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

enum _OwnershipTone { client, orchestrate }

class _OwnershipColumn extends StatelessWidget {
  const _OwnershipColumn({
    required this.ownerLabel,
    required this.title,
    required this.tone,
    required this.items,
  });

  final String ownerLabel;
  final String title;
  final _OwnershipTone tone;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final isClient = tone == _OwnershipTone.client;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isClient ? Colors.white : AppTheme.publicAccentSoft,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.publicLine),
            ),
            child: Text(
              ownerLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        isClient ? AppTheme.publicMuted : AppTheme.publicAccent,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          for (final item in items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: Icon(Icons.circle,
                      size: 7, color: AppTheme.publicAccent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _InfrastructureBurdenCard extends StatelessWidget {
  const _InfrastructureBurdenCard();

  static const _absorbed = <(String, String)>[
    (
      'Deliverability operations',
      'Live SPF / DKIM / DMARC verification, propagation re-checks, mailbox health, transport recovery.',
    ),
    (
      'Mailbox infrastructure',
      'OAuth refresh, token-expiry recovery, SMTP retry, IMAP cursor management, DKIM signing.',
    ),
    (
      'Sequencing engine',
      'No sequence-builder UI to operate. Governed dispatch runs under a per-mailbox in-flight cap with readiness gating.',
    ),
    (
      'Reply triage',
      'Operation-scoped IMAP ingestion attaches matched replies to outbound and cancels queued follow-ups automatically.',
    ),
    (
      'Suppression enforcement',
      'Opt-outs, hard bounces, complaints, and operator blocks gate every dispatch path. No bypass exists.',
    ),
    (
      'Operational recovery',
      'Health checks surface degraded state with the named dependency and a concrete next action.',
    ),
    (
      'Audit + traceability',
      'Append-only audit trail. Metadata only — never credentials, never message bodies.',
    ),
  ];

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
          Text(
            'What the price absorbs.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          Text(
            'Concrete operational burden that stops landing on your team once Orchestrate is running.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < _absorbed.length; i++) ...[
            _BurdenRow(
              title: _absorbed[i].$1,
              body: _absorbed[i].$2,
            ),
            if (i != _absorbed.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _BurdenRow extends StatelessWidget {
  const _BurdenRow({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 560;
          final label = Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.publicText,
                  fontWeight: FontWeight.w700,
                ),
          );
          final desc = Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label,
                const SizedBox(height: 6),
                desc,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 220, child: label),
              const SizedBox(width: 16),
              Expanded(child: desc),
            ],
          );
        },
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

String _route(
  String path, {
  required String plan,
  required String tier,
  required bool trialRequested,
}) {
  return Uri(
    path: path,
    queryParameters: {
      'plan': plan,
      'tier': tier,
      if (trialRequested) 'trial': '15d',
    },
  ).toString();
}

String _tierOutcome(String lane, String tier) {
  final revenue = lane == 'revenue';
  switch (tier) {
    case 'precision':
      return revenue
          ? 'Expand governed execution into the exact markets where revenue continuity needs the tightest control.'
          : 'Run governed execution in the exact markets where targeting precision matters most.';
    case 'multi':
      return revenue
          ? 'Scale governed execution and revenue continuity across multiple markets from one operating system.'
          : 'Scale governed execution across multiple markets without losing control of follow-up or reputation.';
    default:
      return revenue
          ? 'Start with one governed market and keep billing continuity attached from the first workflow onward.'
          : 'Start with one governed market and protect reputation while Orchestrate handles execution end to end.';
  }
}

List<String> _tierDifferentiators(String lane, String tier) {
  final revenue = lane == 'revenue';
  switch (tier) {
    case 'precision':
      return [
        'SPF, DKIM, and DMARC readiness verification before execution starts',
        'Reply attribution, follow-up suppression, and reputation protection stay in force',
        if (revenue)
          'Invoices, reminders, and payment accountability stay under the same audit trail',
      ];
    case 'multi':
      return [
        'Governed execution stays auditable as scope widens across countries and regions',
        'Readiness verification and reputation protection apply across the expanded footprint',
        if (revenue)
          'Revenue continuity expands with the same auditability and suppression controls',
      ];
    default:
      return [
        'Readiness verification checks sending identity before managed execution begins',
        'Follow-up suppression and reply attribution protect the operating surface from day one',
        if (revenue)
          'Revenue continuity runs on the same governed infrastructure as execution',
      ];
  }
}
