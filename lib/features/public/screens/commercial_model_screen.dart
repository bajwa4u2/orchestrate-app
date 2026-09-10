import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/core/commercial/commercial_model.dart';
import 'package:orchestrate_app/data/repositories/public_repository.dart';

/// WHAT ORCHESTRATE CHARGES FOR.
///
/// This replaces a page that sold six plans at fixed monthly prices which had
/// never been approved, disagreed with the amounts stored against real
/// organisations, and were purchasable through live checkout. For a while it
/// published no amount at all, which was the honest state while three sources
/// disagreed about the number and none of them was appointed.
///
/// There is one answer now, so the page states it: an account costs nothing,
/// and the one subscription is billed monthly or annually. Two prices, one
/// product — said in those words, because a page that shows two numbers and
/// leaves the reader to work out the rest has already taught them the cheaper
/// one is smaller.
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
  CommercialModel? _model;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final model = await PublicRepository().fetchPricing();
      if (mounted) setState(() => _model = model);
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

  Widget _body(TextTheme text, CommercialModel model) {
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
              Text(model.says, style: text.bodyLarge?.copyWith(height: 1.5)),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Each part of the model, said as what the customer gets and what it
        // costs them — never as a feature list beside a tick column.
        for (final dimension in model.dimensions)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _Panel(
              title: _label(dimension.dimension),
              body: dimension.means,
            ),
          ),

        const SizedBox(height: 12),

        // WHAT IT COSTS.
        //
        // Free entry first, and stated as an account rather than as the bottom
        // of a price ladder. Somebody who has not bought anything has not
        // failed to do anything, and a zero row sitting under two paid ones
        // says otherwise however it is worded.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            border: Border.all(
                color: AppTheme.publicAccent.withValues(alpha: 0.45)),
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // EXPLICIT LIGHT COLOURS, BECAUSE THIS CARD HAS NO FILL.
              //
              // Every other panel on this page paints itself white and inherits
              // the theme's near-black `publicText`. This one is a bordered
              // outline over the dark page ground, so the same inherited colour
              // renders near-black on near-black. On a Pixel 9a the heading and
              // the closing line were invisible — and nothing in the analyzer,
              // the widget tests or a browser at desktop width said so.
              Text(model.pricingSays,
                  style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.publicOnDark)),
              if (model.free.says.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(model.free.says,
                    style: text.bodyMedium?.copyWith(
                        height: 1.5, color: AppTheme.publicOnDarkMuted)),
              ],
              const SizedBox(height: 22),
              // Two cadences of one subscription, side by side. Neither is
              // marked recommended and neither is styled as the better one:
              // there is nothing to recommend between them but a preference
              // about being billed.
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final offer in model.offers) _CadenceCard(offer: offer),
                ],
              ),
              if (model.cadenceMeans.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(model.cadenceMeans,
                    style: text.bodySmall?.copyWith(
                        height: 1.5, color: AppTheme.publicOnDarkMuted)),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // The invitation is to build a workspace, not to buy. The workspace no
        // longer depends on payment, so the page no longer pretends it does.
        // Also directly on the dark ground, and also invisible before this.
        Text(model.startSays,
            style: text.bodyLarge
                ?.copyWith(height: 1.5, color: AppTheme.publicOnDark)),
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

/// One cadence, priced.
///
/// The currency is named rather than left to the dollar sign, which several
/// countries also use. And the amount is the published US list price — a phone
/// shows the store's own localized price instead, which is why no purchase
/// button anywhere in this product reads its number from here.
class _CadenceCard extends StatelessWidget {
  const _CadenceCard({required this.offer});

  final CommercialOffer offer;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: 240,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(offer.isAnnual ? 'Annual' : 'Monthly',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text('${offer.priceLabel} USD',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(offer.says, style: text.bodySmall?.copyWith(height: 1.4)),
        ],
      ),
    );
  }
}
