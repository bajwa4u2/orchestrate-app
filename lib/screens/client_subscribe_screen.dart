
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/auth/auth_session.dart';
import '../core/theme/app_theme.dart';
import '../data/repositories/client_portal_repository.dart';
import '../data/repositories/public_repository.dart';
import '../data/setup/global_setup_options.dart';

class ClientSubscribeScreen extends StatefulWidget {
  const ClientSubscribeScreen({super.key});

  @override
  State<ClientSubscribeScreen> createState() => _ClientSubscribeScreenState();
}

class _ClientSubscribeScreenState extends State<ClientSubscribeScreen> {
  bool _loading = true;
  bool _subscribing = false;
  String? _error;
  String? _planCode;
  Map<String, dynamic>? _selectedPlan;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    try {
      final uri = GoRouterState.of(context).uri;
      final queryPlan = uri.queryParameters['plan']?.trim().toLowerCase();
      final selectedPlan =
          queryPlan ?? AuthSessionController.instance.selectedPlan ?? 'opportunity';

      final pricing = await PublicRepository().fetchPricing();
      final plans = (pricing['plans'] as List? ?? const []).cast<dynamic>();

      final planMap = plans
          .cast<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .firstWhere(
            (item) => item['code']?.toString().toLowerCase() == selectedPlan,
            orElse: () => <String, dynamic>{},
          );

      if (!mounted) return;
      setState(() {
        _planCode = selectedPlan;
        _selectedPlan = planMap.isEmpty ? null : planMap;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'The subscription screen could not load right now.';
      });
    }
  }

  Future<void> _activate() async {
    final planCode = _planCode;
    if (planCode == null || planCode.isEmpty) return;

    setState(() {
      _subscribing = true;
      _error = null;
    });

    try {
      final response = await ClientPortalRepository().createSubscription(planCode);
      final url = response['checkoutUrl'];

      if (url == null || url.toString().isEmpty) {
        throw Exception('Missing checkout URL');
      }

      await launchUrl(
        Uri.parse(url.toString()),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Secure checkout could not open right now.';
      });
    } finally {
      if (mounted) {
        setState(() => _subscribing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _selectedPlan;
    final planName =
        plan?['name']?.toString() ?? (_planCode == 'revenue' ? 'Revenue' : 'Opportunity');
    final amount =
        ((plan?['amountCents'] as num?) ?? (_planCode == 'revenue' ? 87000 : 43500)) / 100;
    final summary = plan?['summary']?.toString() ?? 'Activate your selected service plan.';
    final serviceScope = GlobalSetupOptions.planScopes[_planCode ?? ''] ?? const <String>[];

    return Scaffold(
      backgroundColor: AppTheme.publicBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: _loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SubscribeHero(
                          title: 'Activate your plan',
                          subtitle:
                              'Your setup is in place. Once billing is active, your account moves into live service.',
                        ),
                        const SizedBox(height: 18),
                        if (_error != null) ...[
                          _SubscribeBanner(message: _error!, error: true),
                          const SizedBox(height: 18),
                        ],
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final stacked = constraints.maxWidth < 860;

                            final left = _PlanCard(
                              planName: planName,
                              amount: amount,
                              summary: summary,
                              serviceScope: serviceScope,
                            );

                            final right = _ReadinessCard(
                              onReviewAccount: () => context.go('/client/account'),
                              onReviewWorkspace: () => context.go('/client/workspace'),
                              onActivate: _subscribing ? null : _activate,
                              activating: _subscribing,
                            );

                            if (stacked) {
                              return Column(
                                children: [
                                  left,
                                  const SizedBox(height: 18),
                                  right,
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 7, child: left),
                                const SizedBox(width: 18),
                                Expanded(flex: 5, child: right),
                              ],
                            );
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
  const _SubscribeHero({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

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
          Text(
            'Subscription',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.publicMuted,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.02,
                ),
          ),
          const SizedBox(height: 14),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.planName,
    required this.amount,
    required this.summary,
    required this.serviceScope,
  });

  final String planName;
  final double amount;
  final String summary;
  final List<String> serviceScope;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            planName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            '\$${amount.toStringAsFixed(2)} / month',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 14),
          Text(
            summary,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                  height: 1.45,
                ),
          ),
          if (serviceScope.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text(
              'What stays in motion',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: serviceScope
                  .map(
                    (item) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8F5),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppTheme.publicLine),
                      ),
                      child: Text(item.replaceAll('_', ' ')),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({
    required this.onReviewAccount,
    required this.onReviewWorkspace,
    required this.onActivate,
    required this.activating,
  });

  final VoidCallback onReviewAccount;
  final VoidCallback onReviewWorkspace;
  final VoidCallback? onActivate;
  final bool activating;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Before you continue',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 14),
          Text(
            'You can activate now, or review your account and workspace first. Both remain available without losing your place.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 20),
          _ActionRow(
            label: 'Review account',
            onTap: onReviewAccount,
          ),
          const SizedBox(height: 10),
          _ActionRow(
            label: 'Return to workspace',
            onTap: onReviewWorkspace,
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onActivate,
              child: Text(activating ? 'Opening checkout...' : 'Activate plan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.publicText,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppTheme.publicLine),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const Icon(Icons.arrow_forward_rounded, size: 18),
        ],
      ),
    );
  }
}

class _SubscribeBanner extends StatelessWidget {
  const _SubscribeBanner({
    required this.message,
    required this.error,
  });

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
        border: Border.all(
          color: error ? Colors.red.shade100 : Colors.green.shade100,
        ),
      ),
      child: Text(message),
    );
  }
}
