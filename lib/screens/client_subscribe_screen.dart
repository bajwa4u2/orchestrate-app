import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/auth/auth_session.dart';
import '../core/theme/app_theme.dart';
import '../data/repositories/client_portal_repository.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final uri = GoRouterState.of(context).uri;
    final session = AuthSessionController.instance;
    final plan = uri.queryParameters['plan']?.trim().toLowerCase() ?? session.selectedPlan ?? 'opportunity';
    final tier = uri.queryParameters['tier']?.trim().toLowerCase() ?? session.selectedTier ?? 'focused';
    final trial = uri.queryParameters['trial']?.trim().toLowerCase() == '15d';
    await session.rememberSelection(plan: plan, tier: tier);

    if (!mounted) return;
    setState(() {
      _planCode = plan;
      _tierCode = tier;
      _trialRequested = trial;
      _loading = false;
    });
  }

  Future<void> _applySelection({String? plan, String? tier}) async {
    final nextPlan = (plan ?? _planCode).trim().toLowerCase();
    final nextTier = (tier ?? _tierCode).trim().toLowerCase();
    await AuthSessionController.instance.rememberSelection(plan: nextPlan, tier: nextTier);
    if (!mounted) return;
    context.go(Uri(path: '/client/subscribe', queryParameters: {
      'plan': nextPlan,
      'tier': nextTier,
      if (_trialRequested) 'trial': '15d',
    }).toString());
  }

  Future<void> _activate() async {
    setState(() {
      _subscribing = true;
      _error = null;
    });

    try {
      final response = await ClientPortalRepository().createSubscription(_planCode, _tierCode);
      final url = response['checkoutUrl']?.toString();
      if (url == null || url.isEmpty) {
        throw Exception('Missing checkout URL');
      }
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok) throw Exception('Checkout launch failed');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Secure checkout could not open right now.');
    } finally {
      if (mounted) setState(() => _subscribing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selection = _selection(_planCode, _tierCode);

    return Scaffold(
      backgroundColor: AppTheme.publicBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SubscribeHero(planCode: _planCode, trialRequested: _trialRequested),
                        const SizedBox(height: 18),
                        if (_error != null) _Banner(message: _error!, error: true),
                        if (_error != null) const SizedBox(height: 18),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final stacked = constraints.maxWidth < 940;
                            final left = Column(
                              children: [
                                _SelectionCard(
                                  planCode: _planCode,
                                  tierCode: _tierCode,
                                  trialRequested: _trialRequested,
                                  onPlanChanged: (value) => _applySelection(plan: value),
                                  onTierChanged: (value) => _applySelection(tier: value),
                                  onTrialChanged: (value) => setState(() => _trialRequested = value),
                                ),
                                const SizedBox(height: 18),
                                _SummaryCard(selection: selection, trialRequested: _trialRequested),
                              ],
                            );
                            final right = _ReadinessCard(
                              selection: selection,
                              trialRequested: _trialRequested,
                              activating: _subscribing,
                              onActivate: _subscribing ? null : _activate,
                              onReviewAccount: () => context.go('/client/account'),
                              onReviewWorkspace: () => context.go('/client/workspace'),
                            );

                            if (stacked) {
                              return Column(children: [left, const SizedBox(height: 18), right]);
                            }
                            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 6, child: left), const SizedBox(width: 18), Expanded(flex: 5, child: right)]);
                          },
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubscribeHero extends StatelessWidget {
  const _SubscribeHero({required this.planCode, required this.trialRequested});
  final String planCode;
  final bool trialRequested;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: AppTheme.publicLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Subscription readiness', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.publicMuted)),
        const SizedBox(height: 10),
        Text('Activate your operating model', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text('Your setup is in place. Confirm plan and market depth before secure checkout opens.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.publicMuted)),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _Pill(label: 'Lane: ${_title(planCode)}'),
          if (trialRequested) const _Pill(label: '15-day trial request active'),
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
    required this.onPlanChanged,
    required this.onTierChanged,
    required this.onTrialChanged,
  });

  final String planCode;
  final String tierCode;
  final bool trialRequested;
  final ValueChanged<String> onPlanChanged;
  final ValueChanged<String> onTierChanged;
  final ValueChanged<bool> onTrialChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: AppTheme.publicLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Confirm scope', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
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
          decoration: const InputDecoration(labelText: 'Service lane'),
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
          decoration: const InputDecoration(labelText: 'Market coverage tier'),
        ),
        const SizedBox(height: 18),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: trialRequested,
          onChanged: onTrialChanged,
          title: const Text('Carry a 15-day trial request into activation'),
          subtitle: const Text('This request is preserved on the frontend. Recurring billing still proceeds through secure checkout.'),
        ),
      ]),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.selection, required this.trialRequested});
  final _Selection selection;
  final bool trialRequested;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppTheme.publicSurfaceSoft, borderRadius: BorderRadius.circular(28), border: Border.all(color: AppTheme.publicLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('What this selection unlocks', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 14),
        for (final item in selection.points) ...[
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
        if (trialRequested)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.publicLine)),
            child: const Text('Trial request note: this preference will remain visible during activation review.'),
          ),
      ]),
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({
    required this.selection,
    required this.trialRequested,
    required this.activating,
    required this.onActivate,
    required this.onReviewAccount,
    required this.onReviewWorkspace,
  });

  final _Selection selection;
  final bool trialRequested;
  final bool activating;
  final VoidCallback? onActivate;
  final VoidCallback onReviewAccount;
  final VoidCallback onReviewWorkspace;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: AppTheme.publicLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Ready to activate', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Text('${selection.planLabel} • ${selection.tierLabel}', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(selection.priceLabel, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text('Secure checkout opens after this confirmation step. Account and setup can still be reviewed before paying.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.publicMuted)),
        if (trialRequested) ...[
          const SizedBox(height: 12),
          const Text('The 15-day trial request is noted here as a frontend preference. Actual subscription billing still follows the Stripe checkout flow.'),
        ],
        const SizedBox(height: 18),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: onActivate, child: Text(activating ? 'Opening secure checkout...' : 'Open secure checkout'))),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          OutlinedButton(onPressed: onReviewWorkspace, child: const Text('Review workspace')),
          OutlinedButton(onPressed: onReviewAccount, child: const Text('Review account')),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: error ? Colors.red.shade100 : Colors.green.shade100),
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
      decoration: BoxDecoration(color: AppTheme.publicSurfaceSoft, borderRadius: BorderRadius.circular(999), border: Border.all(color: AppTheme.publicLine)),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _Selection {
  const _Selection({required this.planLabel, required this.tierLabel, required this.priceLabel, required this.points});
  final String planLabel;
  final String tierLabel;
  final String priceLabel;
  final List<String> points;
}

_Selection _selection(String planCode, String tierCode) {
  final revenue = planCode == 'revenue';
  switch (tierCode) {
    case 'precision':
      return _Selection(
        planLabel: revenue ? 'Revenue' : 'Opportunity',
        tierLabel: 'Precision',
        priceLabel: revenue ? '\$1450 / month' : '\$985 / month',
        points: [
          'City and metro targeting with include or exclude logic',
          'Priority market ordering for sharper execution control',
          revenue ? 'Billing continuity and document movement included' : 'Lead-to-meeting execution included',
        ],
      );
    case 'multi':
      return _Selection(
        planLabel: revenue ? 'Revenue' : 'Opportunity',
        tierLabel: 'Multi-Market',
        priceLabel: revenue ? '\$1120 / month' : '\$685 / month',
        points: [
          'Multiple countries and multiple regions',
          'Broader execution coverage without leaving one system',
          revenue ? 'Revenue-side continuity stays attached across markets' : 'Cross-market outreach and follow-up coverage included',
        ],
      );
    default:
      return _Selection(
        planLabel: revenue ? 'Revenue' : 'Opportunity',
        tierLabel: 'Focused',
        priceLabel: revenue ? '\$870 / month' : '\$435 / month',
        points: [
          'One country with multiple regions',
          'A disciplined operating start for one contained market',
          revenue ? 'Billing continuity begins from the same operating lane' : 'Lead generation, writing, and meetings stay aligned',
        ],
      );
  }
}

String _title(String text) => text.split(RegExp(r'[-_]')).where((part) => part.isNotEmpty).map((word) => '${word[0].toUpperCase()}${word.substring(1)}').join(' ');
