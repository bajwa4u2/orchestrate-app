import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_session.dart';
import '../../core/theme/app_theme.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  String _selectedPlan = 'opportunity';
  bool _trialRequested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uri = GoRouterState.of(context).uri;
    final plan = uri.queryParameters['plan']?.trim().toLowerCase();
    final trial = uri.queryParameters['trial']?.trim().toLowerCase();
    if (plan == 'revenue' || plan == 'opportunity') {
      _selectedPlan = plan!;
    }
    _trialRequested = trial == '15d';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Hero(trialRequested: _trialRequested),
          const SizedBox(height: 20),
          _PlanSwitch(selectedPlan: _selectedPlan, onChanged: (value) => setState(() => _selectedPlan = value)),
          const SizedBox(height: 16),
          _TrialToggle(selected: _trialRequested, onChanged: (value) => setState(() => _trialRequested = value)),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 980;
              if (stacked) {
                return Column(children: [for (int i = 0; i < _tiers.length; i++) ...[
                  _TierCard(
                    tier: _tiers[i],
                    selectedPlan: _selectedPlan,
                    trialRequested: _trialRequested,
                    onSelect: (tierCode) => _goForward(context, tierCode),
                  ),
                  if (i != _tiers.length - 1) const SizedBox(height: 16),
                ]]);
              }
              return Row(children: [for (int i = 0; i < _tiers.length; i++) ...[
                Expanded(
                  child: _TierCard(
                    tier: _tiers[i],
                    selectedPlan: _selectedPlan,
                    trialRequested: _trialRequested,
                    onSelect: (tierCode) => _goForward(context, tierCode),
                  ),
                ),
                if (i != _tiers.length - 1) const SizedBox(width: 16),
              ]]);
            },
          ),
          const SizedBox(height: 20),
          const _CapabilityMatrix(),
          const SizedBox(height: 20),
          const _Footnote(),
        ],
      ),
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
  const _Hero({required this.trialRequested});
  final bool trialRequested;

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
          Text('Pricing tied to operating scope', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(
            'Choose the lane first, then the market coverage. Capability limits follow the tier. The 15-day option below is carried into activation as a trial request, not a hidden upsell.',
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
              child: Text('15-day trial request selected. This preference will carry into client activation.', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.publicAccent)),
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
        Expanded(child: _PlanButton(title: 'Revenue', subtitle: 'Execution plus billing continuity', selected: selectedPlan == 'revenue', onTap: () => onChanged('revenue'))),
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
  const _TrialToggle({required this.selected, required this.onChanged});
  final bool selected;
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
                Text('15-day trial request', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Use this when you want the activation conversation to begin with a 15-day trial request before recurring service begins.', style: Theme.of(context).textTheme.bodyMedium),
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
  const _TierCard({required this.tier, required this.selectedPlan, required this.trialRequested, required this.onSelect});
  final _Tier tier;
  final String selectedPlan;
  final bool trialRequested;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final price = selectedPlan == 'revenue' ? tier.revenuePrice : tier.opportunityPrice;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: tier.highlight ? AppTheme.publicText : AppTheme.publicLine),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (tier.highlight)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: AppTheme.publicAccentSoft, borderRadius: BorderRadius.circular(999)),
            child: Text('Best balance', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.publicAccent)),
          ),
        Text(tier.name, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        Text(tier.summary, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.publicMuted)),
        const SizedBox(height: 16),
        RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyMedium,
            children: [
              TextSpan(text: price, style: Theme.of(context).textTheme.headlineMedium),
              const TextSpan(text: ' / month'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final item in tier.items) ...[
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
            child: Text('15-day trial request will be carried into activation for this tier.', style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => onSelect(tier.code),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.publicText,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(trialRequested ? 'Continue with trial request' : 'Continue with ${tier.name}'),
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
        Text('Tier capability map', style: Theme.of(context).textTheme.headlineMedium),
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

class _Footnote extends StatelessWidget {
  const _Footnote();

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
      child: Text(
        'Recurring billing still proceeds through secure checkout. The 15-day option on this page is recorded as a frontend trial request and carried into activation flow.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _Tier {
  const _Tier({required this.code, required this.name, required this.summary, required this.opportunityPrice, required this.revenuePrice, required this.items, this.highlight = false});
  final String code;
  final String name;
  final String summary;
  final String opportunityPrice;
  final String revenuePrice;
  final List<String> items;
  final bool highlight;
}

const _tiers = [
  _Tier(
    code: 'focused',
    name: 'Focused',
    summary: 'For a disciplined launch inside one country with room to work across regions.',
    opportunityPrice: '\$435',
    revenuePrice: '\$870',
    items: [
      'One country with multiple regions',
      'Lead generation, writing, follow-up, and meeting movement',
      'Strong fit for contained market testing and steady outreach',
    ],
  ),
  _Tier(
    code: 'multi',
    name: 'Multi-Market',
    summary: 'For operators expanding across countries while keeping one system posture.',
    opportunityPrice: '\$645',
    revenuePrice: '\$1290',
    items: [
      'Multiple countries and multiple regions',
      'Broader market scope across one operating model',
      'Good fit for distributed teams and cross-market coverage',
    ],
    highlight: true,
  ),
  _Tier(
    code: 'precision',
    name: 'Precision',
    summary: 'For controlled targeting with city, metro, include or exclude logic, and market priority.',
    opportunityPrice: '\$975',
    revenuePrice: '\$1950',
    items: [
      'City and metro targeting plus include or exclude logic',
      'Priority market ordering and tighter operational control',
      'Built for complex market maps and sharper targeting demands',
    ],
  ),
];

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
