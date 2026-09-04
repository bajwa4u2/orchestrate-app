import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/public_repository.dart';

/// WHAT ORCHESTRATE CHARGES FOR.
///
/// This replaces a page that sold six plans at fixed monthly prices which had
/// never been approved, disagreed with the amounts stored against real
/// organisations, and were purchasable through live checkout.
///
/// It publishes no amount, and that is the honest state rather than an
/// omission: pricing is being set with the first customers while the usage
/// economics are established. What it does publish is the whole model — what a
/// business pays for, why it is charged to the organisation rather than to each
/// person, what is included, and what expands. Replacing a price list with
/// "contact us" would be hiding. This is not that.
///
/// Every sentence comes from the server's commercial projection. The page adds
/// no commercial claim of its own, so the public site and the API cannot come
/// to disagree about what the business model is.
class CommercialModelScreen extends StatefulWidget {
  const CommercialModelScreen({super.key});

  @override
  State<CommercialModelScreen> createState() => _CommercialModelScreenState();
}

class _CommercialModelScreenState extends State<CommercialModelScreen> {
  Map<String, dynamic>? _model;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final json = await PublicRepository().fetchCommercialModel();
      if (mounted) setState(() => _model = json);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: _error != null
              ? _Panel(
                  title: 'We could not load this right now.',
                  body: 'Nothing has changed about what Orchestrate costs — we '
                      'just could not read it.',
                )
              : _model == null
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : _body(text, _model!),
        ),
      ),
    );
  }

  Widget _body(TextTheme text, Map<String, dynamic> model) {
    final dimensions = (model['dimensions'] as List?) ?? const [];
    final pricing = Map<String, dynamic>.from(
        (model['pricing'] as Map?) ?? const <String, dynamic>{});
    final start = Map<String, dynamic>.from(
        (model['start'] as Map?) ?? const <String, dynamic>{});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The headline is the model itself, not a slogan. A business reading
        // this is deciding whether the shape suits them before any number
        // matters.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.publicSurface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppTheme.publicLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What Orchestrate costs',
                  style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text((model['says'] as String?) ?? '',
                  style: text.bodyLarge?.copyWith(height: 1.5)),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Each part of the model, said as what the customer gets and what it
        // costs them — never as a feature list beside a tick column.
        for (final dimension in dimensions)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _Panel(
              title: _label(
                  (dimension as Map)['dimension']?.toString() ?? ''),
              body: dimension['means']?.toString() ?? '',
            ),
          ),

        const SizedBox(height: 12),

        // Where pricing actually stands. Said plainly, in the first person,
        // because a business deciding whether to talk to us deserves to know
        // that the number is a conversation rather than a secret.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.publicAccent.withValues(alpha: 0.45)),
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Early access',
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(pricing['says']?.toString() ?? '',
                  style: text.bodyMedium?.copyWith(height: 1.5)),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // The invitation is to build a workspace, not to buy. The workspace no
        // longer depends on payment, so the page no longer pretends it does.
        Text(start['says']?.toString() ?? '',
            style: text.bodyLarge?.copyWith(height: 1.5)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton(
              onPressed: () => context.go('/auth/register'),
              child: const Text('Create your workspace'),
            ),
            OutlinedButton(
              onPressed: () => context.go('/contact'),
              child: const Text('Talk to us about terms'),
            ),
          ],
        ),
      ],
    );
  }

  /// The server's dimension keys, in the words a customer would use.
  static String _label(String dimension) => switch (dimension) {
        'PLATFORM_SUBSCRIPTION' => 'One subscription for your organisation',
        'INCLUDED_OPERATING_CAPACITY' => 'Meaningful operation is included',
        'USAGE_EXPANSION' => 'It grows with what you actually use',
        'GOVERNED_EXECUTION' => 'Orchestrate acting on your behalf',
        'ASSISTED_IMPLEMENTATION' => 'Help setting up, only if you need it',
        _ => dimension,
      };
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(body, style: text.bodyMedium?.copyWith(height: 1.5)),
        ],
      ),
    );
  }
}
