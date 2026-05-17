import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/config/app_config.dart';
import 'package:orchestrate_app/core/config/pricing_config.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/public_repository.dart';
import 'package:orchestrate_app/features/support/screens/support_drawer.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  String _selectedPlan = 'opportunity';
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
        _selectedPlan = plan!;
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

  Future<void> _goForward(BuildContext context, String tierCode) async {
    final session = AuthSessionController.instance;
    await session.rememberSelection(plan: _selectedPlan, tier: tierCode);

    final route = _route(
      '/auth/join',
      plan: _selectedPlan,
      tier: tierCode,
      trialRequested: _trialRequested,
    );
    final setupRoute = _route(
      '/app/setup',
      plan: _selectedPlan,
      tier: tierCode,
      trialRequested: _trialRequested,
    );
    final subscribeRoute = _route(
      '/app/subscribe',
      plan: _selectedPlan,
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
          plan: _selectedPlan,
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
          _PlanSwitch(
            selectedPlan: _selectedPlan,
            onChanged: (value) => setState(() => _selectedPlan = value),
          ),
          const SizedBox(height: 16),
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
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 980;
                final plans = catalog.plansForLane(_selectedPlan);

                if (stacked) {
                  return Column(
                    children: [
                      for (int i = 0; i < plans.length; i++) ...[
                        _TierCard(
                          plan: plans[i],
                          trialRequested: _trialRequested,
                          trialDays: catalog.trialDays,
                          onSelect: (tierCode) => _goForward(context, tierCode),
                        ),
                        if (i != plans.length - 1) const SizedBox(height: 16),
                      ],
                    ],
                  );
                }

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < plans.length; i++) ...[
                        Expanded(
                          child: _TierCard(
                            plan: plans[i],
                            trialRequested: _trialRequested,
                            trialDays: catalog.trialDays,
                            onSelect: (tierCode) =>
                                _goForward(context, tierCode),
                          ),
                        ),
                        if (i != plans.length - 1) const SizedBox(width: 16),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const _InfrastructureBurdenCard(),
            const SizedBox(height: 20),
            const _CapabilityMatrix(),
            const SizedBox(height: 20),
            const _AfterChoosingCard(),
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
            'Pick the scope of managed execution.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'You are not buying seats, sequences, or AI credits. You are buying managed commercial execution infrastructure: signal discovery, qualification, governed dispatch, follow-up continuity, reply attribution, suppression, recovery, and audit — operated as a runtime beneath your identity. The plan picks the scope; the runtime is the same.',
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
                '$trialDays-day start period selected. This will carry forward with the plan you choose.',
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

class _PlanSwitch extends StatelessWidget {
  const _PlanSwitch({
    required this.selectedPlan,
    required this.onChanged,
  });

  final String selectedPlan;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PlanButton(
              title: 'Managed execution',
              subtitle: 'Discovery, qualification, governed dispatch, follow-up continuity, and reply handling.',
              selected: selectedPlan == 'opportunity',
              onTap: () => onChanged('opportunity'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PlanButton(
              title: 'Managed execution + revenue continuity',
              subtitle: 'Adds invoices, statements, reminders, and agreements governed alongside execution.',
              selected: selectedPlan == 'revenue',
              onTap: () => onChanged('revenue'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanButton extends StatelessWidget {
  const _PlanButton({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(
            color: selected ? AppTheme.publicText : Colors.transparent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
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
                  '$trialDays-day start period',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Use this if you want a $trialDays-day start period before monthly billing begins.',
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

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.plan,
    required this.trialRequested,
    required this.trialDays,
    required this.onSelect,
  });

  final PricingPlanOption plan;
  final bool trialRequested;
  final int trialDays;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final content = _tierContent(plan.tier);
    final highlight = plan.tier == 'multi';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: highlight ? AppTheme.publicText : AppTheme.publicLine,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (highlight)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppTheme.publicAccentSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Best balance',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.publicAccent,
                    ),
              ),
            ),
          Text(plan.label, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(
            plan.description?.isNotEmpty == true
                ? plan.description!
                : content.summary,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                TextSpan(
                  text: plan.priceLabel,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const TextSpan(text: ' / month'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final item in content.items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: AppTheme.publicAccent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.publicText,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (trialRequested) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.publicSurfaceSoft,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(color: AppTheme.publicLine),
              ),
              child: Text(
                '$trialDays-day start period selected for this plan.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => onSelect(plan.tier),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.publicText,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
              ),
              child: Text(
                trialRequested
                    ? 'Continue with ${plan.label}'
                    : 'Start with this plan',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CapabilityMatrix extends StatelessWidget {
  const _CapabilityMatrix();

  @override
  Widget build(BuildContext context) {
    final rows = const [
      [
        'Geography',
        'One country, multiple regions',
        'Multiple countries and regions',
        'City-level targeting with include or exclude logic',
      ],
      [
        'Best fit',
        'Contained launch',
        'Cross-market expansion',
        'High-control targeting across markets',
      ],
      [
        'Use case',
        'Disciplined rollout',
        'Broader market coverage',
        'Priority-market sequencing and tighter precision',
      ],
    ];

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
            'Choose your coverage level',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: Theme.of(context).textTheme.titleMedium,
              columns: const [
                DataColumn(label: Text('Decision')),
                DataColumn(label: Text('Focused')),
                DataColumn(label: Text('Multi-Market')),
                DataColumn(label: Text('Precision')),
              ],
              rows: [
                for (final row in rows)
                  DataRow(
                    cells: [
                      for (final cell in row) DataCell(Text(cell)),
                    ],
                  ),
              ],
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
                'Need help choosing the right option?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                'Use guidance if the fit is unclear. Pricing should remain the primary path. Support is here when service fit, setup, or billing questions need a direct conversation.',
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
                    'Powered by OpenAI',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.publicMuted,
                        ),
                  ),
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
            'Monthly billing begins through secure checkout. The $trialDays-day option on this page carries forward with the plan you select.',
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

class _AfterChoosingCard extends StatelessWidget {
  const _AfterChoosingCard();

  static const _steps = <(String, String, String)>[
    (
      '1',
      'Account + identity',
      'Create the account, confirm your business identity, and grant representation authorization.',
    ),
    (
      '2',
      'Mailbox transport',
      'Connect via Google Workspace OAuth, Microsoft 365 OAuth, or custom SMTP + IMAP. Credentials are vaulted; tokens never touch the browser.',
    ),
    (
      '3',
      'Sending domain',
      'Publish SPF, DKIM, and DMARC at your DNS host. Orchestrate verifies with live DNS and re-checks automatically until they pass.',
    ),
    (
      '4',
      'Readiness',
      'The readiness engine evaluates the dependency chain. Dispatch eligibility flips when every layer is verified — no operator action.',
    ),
    (
      '5',
      'Managed execution',
      'Signal discovery, qualification, governed dispatch, follow-up continuity, reply attribution, suppression, recovery — all running as infrastructure beneath your identity.',
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
                    'Pricing connects directly to activation. The plan governs scope; the activation chain below brings the runtime online.',
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
          const SizedBox(height: 20),
          for (var i = 0; i < _steps.length; i++) ...[
            _ActivationStepRow(
              index: _steps[i].$1,
              title: _steps[i].$2,
              body: _steps[i].$3,
            ),
            if (i != _steps.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ActivationStepRow extends StatelessWidget {
  const _ActivationStepRow({
    required this.index,
    required this.title,
    required this.body,
  });

  final String index;
  final String title;
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.publicAccentSoft,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.publicLine),
            ),
            child: Text(
              index,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.publicAccent,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.publicText,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.publicMuted,
                      ),
                ),
              ],
            ),
          ),
        ],
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

class _TierContent {
  const _TierContent({
    required this.summary,
    required this.items,
  });

  final String summary;
  final List<String> items;
}

_TierContent _tierContent(String tier) {
  switch (tier) {
    case 'precision':
      return const _TierContent(
        summary:
            'Highest-resolution execution scope: city, metro, include/exclude logic, and priority-market ordering for managed execution.',
        items: [
          'City and metro execution scope plus include / exclude logic',
          'Priority-market ordering for governed dispatch sequencing',
          'Built for complex market maps where signal discovery and managed execution need sharp scope',
        ],
      );
    case 'multi':
      return const _TierContent(
        summary:
            'Cross-country execution scope while keeping one infrastructure scope.',
        items: [
          'Multiple countries and multiple regions inside one execution scope',
          'Broader signal-discovery coverage without splitting infrastructure',
          'Fits distributed teams running managed execution across markets',
        ],
      );
    default:
      return const _TierContent(
        summary:
            'Single-country execution scope with room for regional coverage. The disciplined starting scope for managed execution.',
        items: [
          'One country with multiple regions inside the execution scope',
          'Signal discovery, qualification, governed dispatch, follow-up continuity',
          'Right scope for a focused market entry running on managed infrastructure',
        ],
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
