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
            (item) =>
                item['code']?.toString().toLowerCase() == selectedPlan,
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
        _error =
            'The subscription activation screen could not load right now.';
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
      final response =
          await ClientPortalRepository().createSubscription(planCode);

      final url = response['checkoutUrl'];

      if (url == null || url.toString().isEmpty) {
        throw Exception('Missing checkout URL');
      }

      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error =
            'Could not start secure checkout. Please try again.';
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

    final planName = plan?['name']?.toString() ??
        (_planCode == 'revenue' ? 'Revenue' : 'Opportunity');

    final amount =
        ((plan?['amountCents'] as num?) ??
                (_planCode == 'revenue' ? 87000 : 43500)) /
            100;

    final summary =
        plan?['summary']?.toString() ??
            'Activate your selected service plan.';

    final scope =
        GlobalSetupOptions.planScopes[_planCode ?? ''] ??
            const <String>[];

    return Scaffold(
      backgroundColor: AppTheme.publicBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                  side: const BorderSide(
                      color: AppTheme.publicLine),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: _loading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Activate subscription',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Your setup is complete. Activate your plan to begin live service.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color:
                                        AppTheme.publicMuted,
                                  ),
                            ),
                            const SizedBox(height: 24),

                            if (_error != null)
                              _SubscribeBanner(
                                  message: _error!,
                                  error: true),

                            Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F8F5),
                                borderRadius:
                                    BorderRadius.circular(
                                        24),
                                border: Border.all(
                                    color:
                                        AppTheme.publicLine),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    planName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontWeight:
                                              FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '\$${amount.toStringAsFixed(2)} / month',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight:
                                              FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(summary),
                                  if (scope.isNotEmpty) ...[
                                    const SizedBox(
                                        height: 18),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: scope
                                          .map((item) =>
                                              Chip(
                                                  label: Text(
                                                      item.replaceAll(
                                                          '_',
                                                          ' '))))
                                          .toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _subscribing
                                    ? null
                                    : _activate,
                                child: Text(_subscribing
                                    ? 'Redirecting...'
                                    : 'Activate subscription'),
                              ),
                            ),

                            const SizedBox(height: 12),

                            TextButton(
                              onPressed: () =>
                                  context.go(
                                      '/client/account'),
                              child: const Text(
                                  'Review company profile first'),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
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
      margin:
          const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error
            ? Colors.red.shade50
            : Colors.green.shade50,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: error
              ? Colors.red.shade100
              : Colors.green.shade100,
        ),
      ),
      child: Text(message),
    );
  }
}