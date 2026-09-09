import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:orchestrate_app/app/shell/auth_shell.dart';
import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/commercial/client_capabilities.dart';
import 'package:orchestrate_app/core/commercial/commercial_model.dart';
import 'package:orchestrate_app/core/platform/billing_gate.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/client/client_billing_repository.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';

/// SUBSCRIBING TO ORCHESTRATE, ON THE RAIL ORCHESTRATE BILLS DIRECTLY.
///
/// This screen used to be a package chooser: two lanes by three tiers, a trial
/// toggle, a summary of what the chosen tier included, and a readiness card
/// arguing for it. Six packages, none of them ever sold, and every one of them
/// requiring the screen to decide which was better than which.
///
/// There is one product. A business either subscribes or does not, and the only
/// choice left is how often to be billed — which buys them nothing extra, and
/// is said in those words rather than left to be inferred from two numbers.
///
/// Every sentence and every amount comes from the server's commercial
/// projection. Nothing commercial is decided or worded here.
class ClientSubscribeScreen extends StatefulWidget {
  const ClientSubscribeScreen({super.key, this.insideWorkspace = false});

  /// True when the client shell is already providing the chrome. The signed-out
  /// funnel still brings its own.
  final bool insideWorkspace;

  @override
  State<ClientSubscribeScreen> createState() => _ClientSubscribeScreenState();
}

class _ClientSubscribeScreenState extends State<ClientSubscribeScreen> {
  bool _loading = true;
  bool _subscribing = false;
  String? _error;

  CommercialModel? _model;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final model = await ClientBillingRepository().fetchCommercialModel();
      if (!mounted) return;
      setState(() {
        _model = model;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Pricing details could not be loaded at the moment.';
      });
    }
  }

  Future<void> _subscribe(CommercialOffer offer) async {
    // App Store §3.1.1 — never open an external checkout from the iOS native
    // app. The buttons are not rendered there; this guard makes the callback
    // safe even if something invokes it.
    if (!externalPurchaseAllowed) return;

    setState(() {
      _subscribing = true;
      _error = null;
    });

    try {
      final response = await ClientBillingRepository()
          .createSubscription(period: offer.period);
      final url = response['checkoutUrl']?.toString();
      if (url == null || url.isEmpty) {
        // The server refuses before opening a session when activation is shut,
        // and its refusal is the sentence worth showing.
        throw _Refused(response['reason']?.toString());
      }
      final ok =
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok) throw _Refused(null);
    } on _Refused catch (refusal) {
      if (!mounted) return;
      setState(() => _error =
          refusal.reason ?? 'Secure checkout could not open at the moment.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Secure checkout could not open at the moment.');
    } finally {
      if (mounted) setState(() => _subscribing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = _model;
    final setupDraft = AuthSessionController.instance.setupDraft;

    // COMMERCIAL ACTIVATION IS CLOSED, AND THAT IS NOT A LOADING FAILURE.
    //
    // A closed rail comes back legitimately unsellable. This screen once read
    // that as breakage and offered "Pricing details are temporarily
    // unavailable / Retry", a button that could only ever fail again.
    final activation = model?.activation;

    final content = _loading
        ? const Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(),
          )
        : (activation != null && !activation.open)
            ? _ActivationClosedCard(
                says: activation.says,
                resolution: activation.resolution,
                onTalkToUs: () => context.go(
                    widget.insideWorkspace ? '/client/support' : '/contact'),
                onBack: () =>
                    context.go(widget.insideWorkspace ? '/client/billing' : '/'),
                insideWorkspace: widget.insideWorkspace,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── WHAT YOU ALREADY HAVE, BEFORE WHAT YOU COULD BUY ─────
                  //
                  // Somebody inside the workspace lands here wanting to
                  // understand their commercial state, and a price list cannot
                  // answer "what do I have access to". The entitlement
                  // authority already holds that answer and gates the
                  // workspace with it; it was simply never shown to the person
                  // it governs.
                  //
                  // Only inside the workspace. Somebody arriving from setup has
                  // no entitlement to report, and leading with an empty one
                  // answers a question they have not asked.
                  if (widget.insideWorkspace) ...[
                    const _CurrentAccessCard(),
                    const SizedBox(height: 18),
                  ],
                  if (model != null) _Hero(model: model),
                  const SizedBox(height: 18),
                  if (_error != null) ...[
                    _Banner(message: _error!, error: true),
                    const SizedBox(height: 18),
                  ],
                  if (model == null || model.offers.isEmpty)
                    _MissingPricingCard(onRetry: _load)
                  else ...[
                    // Two cadences of one subscription. Neither is marked
                    // recommended: there is nothing to recommend between them
                    // but a preference about being billed.
                    Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        for (final offer in model.offers)
                          _CadenceCard(
                            offer: offer,
                            busy: _subscribing,
                            // iOS opens no external checkout, so it gets the
                            // explanation instead of a button that must not
                            // work.
                            onSubscribe: externalPurchaseAllowed
                                ? () => _subscribe(offer)
                                : null,
                          ),
                      ],
                    ),
                    if (model.cadenceMeans.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(model.cadenceMeans,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(height: 1.5)),
                    ],
                    if (!externalPurchaseAllowed) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Subscriptions are purchased through the App Store on '
                        'this device. Open Billing to subscribe.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(height: 1.5),
                      ),
                    ],
                  ],
                  if (setupDraft != null) ...[
                    const SizedBox(height: 18),
                    _ScopeSnapshotCard(draft: setupDraft),
                  ],
                ],
              );

    if (widget.insideWorkspace) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: content,
      );
    }
    return AuthShell(
      maxContentWidth: 1120,
      setupFlow: true,
      child: content,
    );
  }
}

/// A refusal the server wrote, carried up so its own wording is shown.
class _Refused implements Exception {
  _Refused(this.reason);
  final String? reason;
}

/// The headline, and the fact that an account already costs nothing.
class _Hero extends StatelessWidget {
  const _Hero({required this.model});

  final CommercialModel model;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Subscribe to Orchestrate',
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        if (model.pricingSays.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(model.pricingSays, style: text.bodyLarge?.copyWith(height: 1.5)),
        ],
        // Said even on the page that is trying to sell. Somebody who decides
        // not to subscribe today has not lost their workspace, and finding
        // that out here rather than after cancelling is the honest order.
        if (model.free.says.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(model.free.says, style: text.bodyMedium?.copyWith(height: 1.5)),
        ],
      ],
    );
  }
}

/// One cadence, priced by the server, with the one button that buys it.
class _CadenceCard extends StatelessWidget {
  const _CadenceCard({
    required this.offer,
    required this.busy,
    required this.onSubscribe,
  });

  final CommercialOffer offer;
  final bool busy;

  /// Null where this device must not open an external checkout.
  final VoidCallback? onSubscribe;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(offer.isAnnual ? 'Annual' : 'Monthly',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          // The currency is named rather than left to the dollar sign, which
          // several countries also use.
          Text('${offer.priceLabel} USD',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(offer.says, style: text.bodySmall?.copyWith(height: 1.4)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy ? null : onSubscribe,
              child: Text(busy ? 'Working…' : 'Subscribe'),
            ),
          ),
        ],
      ),
    );
  }
}

/// WHAT THIS BUSINESS CAN CURRENTLY DO.
///
/// Read from the entitlement authority, which is the same source that gates
/// the workspace. Nothing here is derived a second time: a capability says
/// whether it is permitted, and when it is not it says why and what resolves
/// it, in the authority's own words.
///
/// Capability codes are translated because READ_OWN_RECORDS is not a sentence.
/// The translation is a label only — the reason and the resolution are passed
/// through untouched, because those are the parts that carry consequence.
class _CurrentAccessCard extends StatefulWidget {
  const _CurrentAccessCard();

  @override
  State<_CurrentAccessCard> createState() => _CurrentAccessCardState();
}

class _CurrentAccessCardState extends State<_CurrentAccessCard> {
  final ClientCapabilities _capabilities = ClientCapabilities.instance;

  static const _labels = <String, String>{
    'READ_OWN_RECORDS': 'See your own records',
    'CONFIGURE_BUSINESS': 'Configure the business',
    'MANAGE_ACCOUNT': 'Manage the account',
    'EXPORT': 'Export your data',
    'OPERATE_COMMERCIALLY': 'Operate commercially',
    'RESEARCH_COUNTERPARTIES': 'Research counterparties',
    'GOVERNED_EXECUTION': 'Run governed execution',
  };

  @override
  void initState() {
    super.initState();
    _capabilities.addListener(_changed);
    _capabilities.load();
  }

  @override
  void dispose() {
    _capabilities.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final projection = _capabilities.projection;
    if (projection == null) {
      // Silent while loading. A skeleton above a pricing page would be
      // furniture, and the page below is already usable.
      return const SizedBox.shrink();
    }

    final verdicts = projection.capabilities;
    final permitted = verdicts.where((v) => v.permitted).toList();
    final refused = verdicts.where((v) => !v.permitted).toList();

    return ClientPanel(
      title: 'What this business can do today',
      subtitle: refused.isEmpty
          ? 'Everything below is available.'
          : 'Some capability is not available yet. Each one says why, and what '
              'resolves it.',
      children: [
        // Refusals first: they are the reason somebody opened this screen.
        for (final v in refused)
          ClientInfoRow(
            title: _labels[v.capability] ?? v.capability,
            primary: v.why ?? 'Not available.',
            secondary: v.resolution ?? '',
          ),
        if (permitted.isNotEmpty)
          ClientInfoRow(
            title: 'Available now',
            primary: permitted
                .map((v) => _labels[v.capability] ?? v.capability)
                .join(' · '),
          ),
        // The authority's own sentence, carried verbatim. It draws a line the
        // product must not blur: paying for capability is not the same as
        // authorising a person to act.
        if (projection.note.isNotEmpty)
          ClientInfoRow(title: 'Worth knowing', primary: projection.note),
      ],
    );
  }
}

/// What setup captured, shown back before somebody commits money to it.
///
/// It used to lead with a service and a coverage mode — the lane and the tier
/// under different names. Those described a package, not a business, and the
/// rest of this card describes the business.
class _ScopeSnapshotCard extends StatelessWidget {
  const _ScopeSnapshotCard({required this.draft});

  final Map<String, dynamic> draft;

  @override
  Widget build(BuildContext context) {
    final countries = _stringList(draft['countries']);
    final regions = _stringList(draft['regions']);
    final metros = _stringList(draft['metros']);
    final industry = draft['industryLabel']?.toString() ?? '';

    if (countries.isEmpty &&
        regions.isEmpty &&
        metros.isEmpty &&
        industry.isEmpty) {
      return const SizedBox.shrink();
    }

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

/// The server answered, and named nothing purchasable.
///
/// Distinct from a closed rail, which says so in its own words, and from a
/// failed request, which says that. This is the case where pricing genuinely
/// could not be read, so retrying is a reasonable thing to offer.
class _MissingPricingCard extends StatelessWidget {
  const _MissingPricingCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
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
          Text('We could not read our own pricing just now.',
              style: text.titleMedium),
          const SizedBox(height: 10),
          Text(
            'Nothing about your workspace has changed, and nothing has been '
            'charged.',
            style: text.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 18),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _ActivationClosedCard extends StatelessWidget {
  const _ActivationClosedCard({
    required this.says,
    required this.resolution,
    required this.onTalkToUs,
    required this.onBack,
    required this.insideWorkspace,
  });

  final String says;
  final String resolution;
  final VoidCallback onTalkToUs;
  final VoidCallback onBack;
  final bool insideWorkspace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Subscribing',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 8),
          // This said "Set with you, not published" — right while no price was
          // published, and a plain contradiction the day one was. The heading
          // now describes what is actually closed, and the server's own
          // sentences below say where subscribing does work.
          Text('Not open on this rail yet',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          if (says.isNotEmpty)
            Text(says, style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
          if (resolution.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(resolution,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
          ],
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                  onPressed: onTalkToUs, child: const Text('Talk to us')),
              OutlinedButton(
                onPressed: onBack,
                child: Text(insideWorkspace ? 'Back to billing' : 'Back'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
