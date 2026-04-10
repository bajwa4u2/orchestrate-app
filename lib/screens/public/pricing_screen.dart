import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_session.dart';
import '../../core/config/app_config.dart';
import '../../core/config/pricing_config.dart';
import '../../core/theme/app_theme.dart';
import '../../features/support/screens/support_drawer.dart';
import '../../data/repositories/public_repository.dart';

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
        _error = 'Pricing could not be loaded right now.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Hero(trialRequested: _trialRequested, trialDays: catalog?.trialDays ?? 15),
          const SizedBox(height: 20),
          _PlanSwitch(selectedPlan: _selectedPlan, onChanged: (value) => setState(() => _selectedPlan = value)),
          const SizedBox(height: 16),
          _TrialToggle(
            selected: _trialRequested,
            trialDays: catalog?.trialDays ?? 15,
            onChanged: (value) => setState(() => _trialRequested = value),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
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
                      ]
                    ],
                  );
                }
                return Row(
                  children: [
                    for (int i = 0; i < plans.length; i++) ...[
                      Expanded(
                        child: _TierCard(
                          plan: plans[i],
                          trialRequested: _trialRequested,
                          trialDays: catalog.trialDays,
                          onSelect: (tierCode) => _goForward(context, tierCode),
                        ),
                      ),
                      if (i != plans.length - 1) const SizedBox(width: 16),
                    ]
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            const _CapabilityMatrix(),
            const SizedBox(height: 20),
            _SupportAssistCard(onPressed: _openSupportDrawer),
            const SizedBox(height: 20),
            _Footnote(trialDays: catalog.trialDays),
          ],
        ],
      ),
    );
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
                baseUrl: AppConfig.apiBaseUrl,
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }

  Future<void> _goForward(BuildContext context, String tierCode) async {
    final session = AuthSessionController.instance;
    await session.rememberSelection(plan: _selectedPlan, tier: tierCode);

    final route = _route('/client/join', plan: _selectedPlan, tier: tierCode, trialRequested: _trialRequested);
    final setupRoute = _route('/client/setup', plan: _selectedPlan, tier: tierCode, trialRequested: _trialRequested);
    final subscribeRoute = _route('/client/subscribe', plan: _selectedPlan, tier: tierCode, trialRequested: _trialRequested);

    if (!mounted) return;

    if (!session.isAuthenticated || session.surface != 'client') {
      context.go(route);
      return;
    }
    if (!session.emailVerified) {
      context.go(_route('/client/verify-email', plan: _selectedPlan, tier: tierCode, trialRequested: _trialRequested));
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
    context.go('/client/workspace');
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.trialRequested, required this.trialDays});
  final bool trialRequested;
  final int trialDays;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pricing built around your operating scope', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(
            'Choose the service first, then the coverage you need. Pricing follows the scope you want active from day one.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.publicMuted),
          ),
          if (trialRequested) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.publicAccentSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.publicLine),
              ),
              child: Text(
                '${trialDays}-day start period selected. This stays with your plan as you continue.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.publicAccent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanSwitch extends StatelessWidget {
  const _PlanSwitch({required this.selectedPlan, required this.onChanged});
  final String selectedPlan;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Row(children: [
        Expanded(child: _PlanButton(title: 'Opportunity', subtitle: 'Lead generation to meetings', selected: selectedPlan == 'opportunity', onTap: () => onChanged('opportunity'))),
        const SizedBox(width: 8),
        Expanded(child: _PlanButton(title: 'Revenue', subtitle: 'Billing and payment operations', selected: selectedPlan == 'revenue', onTap: () => onChanged('revenue'))),
      ]),
    );
  }
}

class _PlanButton extends StatelessWidget {
  const _PlanButton({required this.title, required this.subtitle, required this.selected, required this.onTap});
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppTheme.publicText : Colors.transparent),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ]),
      ),
    );
  }
}

class _TrialToggle extends StatelessWidget {
  const _TrialToggle({required this.selected, required this.trialDays, required this.onChanged});
  final bool selected;
  final int trialDays;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${trialDays}-day start period', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Use this when you want a ${trialDays}-day start period before monthly billing begins.', style: Theme.of(context).textTheme.bodyMedium),
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
  const _TierCard({required this.plan, required this.trialRequested, required this.trialDays, required this.onSelect});
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
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: highlight ? AppTheme.publicText : AppTheme.publicLine),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (highlight)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: AppTheme.publicAccentSoft, borderRadius: BorderRadius.circular(999)),
            child: Text('Best balance', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.publicAccent)),
          ),
        Text(plan.label, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        Text(
          plan.description?.isNotEmpty == true ? plan.description! : content.summary,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.publicMuted),
        ),
        const SizedBox(height: 16),
        RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyMedium,
            children: [
              TextSpan(text: plan.priceLabel, style: Theme.of(context).textTheme.headlineMedium),
              const TextSpan(text: ' / month'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final item in content.items) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Icon(Icons.check_circle_outline, size: 18, color: AppTheme.publicAccent),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(item, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.publicText))),
          ]),
          const SizedBox(height: 10),
        ],
        if (trialRequested) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.publicSurfaceSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.publicLine),
            ),
            child: Text('${trialDays}-day start period selected for this tier.', style: Theme.of(context).textTheme.bodyMedium),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(trialRequested ? 'Continue' : 'Choose ${plan.label}'),
          ),
        ),
      ]),
    );
  }
}

class _CapabilityMatrix extends StatelessWidget {
  const _CapabilityMatrix();

  @override
  Widget build(BuildContext context) {
    final rows = const [
      ['Geography', 'One country, multiple regions', 'Multiple countries and regions', 'City-level targeting, include or exclude logic'],
      ['Use case', 'Tight market focus', 'Cross-market expansion', 'Priority-market sequencing and precision coverage'],
      ['Best for', 'Disciplined launch', 'Growing operator reach', 'High-control targeting across markets'],
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Coverage guide', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingTextStyle: Theme.of(context).textTheme.titleMedium,
            columns: const [
              DataColumn(label: Text('Capability')),
              DataColumn(label: Text('Focused')),
              DataColumn(label: Text('Multi-Market')),
              DataColumn(label: Text('Precision')),
            ],
            rows: [for (final row in rows) DataRow(cells: [for (final cell in row) DataCell(Text(cell))])],
          ),
        ),
      ]),
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
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 760;
          final left = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Need help choosing the right setup?', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              Text(
                'Describe your market, service need, or billing requirement and Orchestrate will guide you before you choose a plan.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.publicMuted),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  Text(
                    'Powered by OpenAI',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.publicMuted),
                  ),
                  Text(
                    'Secure billing powered by Stripe',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.publicMuted),
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
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Get guidance'),
              ),
              FilledButton(
                onPressed: () => GoRouter.of(context).go('/contact'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.publicText,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Open full support'),
              ),
            ],
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [left, const SizedBox(height: 16), right],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(flex: 7, child: left), const SizedBox(width: 20), Expanded(flex: 5, child: Align(alignment: Alignment.centerRight, child: right))],
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly billing begins through secure checkout. The ${trialDays}-day option on this page continues with your selected plan into activation.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          Text(
            'Secure billing powered by Stripe',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.publicMuted),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
  const _TierContent({required this.summary, required this.items});
  final String summary;
  final List<String> items;
}

_TierContent _tierContent(String tier) {
  switch (tier) {
    case 'precision':
      return const _TierContent(
        summary: 'For controlled targeting with city, metro, include or exclude logic, and market priority.',
        items: [
          'City and metro targeting plus include or exclude logic',
          'Priority market ordering and tighter operational control',
          'Built for complex market maps and sharper targeting demands',
        ],
      );
    case 'multi':
      return const _TierContent(
        summary: 'For operators expanding across countries while keeping one system posture.',
        items: [
          'Multiple countries and multiple regions',
          'Broader market scope across one operating model',
          'Good fit for distributed teams and cross-market coverage',
        ],
      );
    default:
      return const _TierContent(
        summary: 'For a disciplined launch inside one country with room to work across regions.',
        items: [
          'One country with multiple regions',
          'Lead generation, writing, follow-up, and meeting movement',
          'Strong fit for contained market testing and steady outreach',
        ],
      );
  }
}

String _route(String path, {required String plan, required String tier, required bool trialRequested}) {
  return Uri(
    path: path,
    queryParameters: {
      'plan': plan,
      'tier': tier,
      if (trialRequested) 'trial': '15d',
    },
  ).toString();
}
