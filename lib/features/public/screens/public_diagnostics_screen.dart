import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/core/widgets/substrate_chip.dart';
import 'package:orchestrate_app/core/widgets/substrate_citation.dart';
import 'package:orchestrate_app/data/repositories/public_repository.dart';

/// Public, signup-free DNS diagnostic surface.
///
/// Doctrine
/// --------
/// Visitors evaluating Orchestrate should be able to confirm SPF /
/// DKIM / DMARC readiness before creating an account. This screen
/// hits the public diagnostic endpoint which runs the SAME live DNS
/// checks the authenticated verifier uses. Read-only — no records
/// are stored, no signup is required, no credentials are exposed.
///
/// UX is calm, procurement-grade, and structurally consistent with
/// the rest of the public surface. No flashy admin dashboard. No
/// fake AI diagnosis. The per-record check is rendered verbatim
/// from the backend's DnsRecordCheck shape.
class PublicDiagnosticsScreen extends StatelessWidget {
  const PublicDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Hero(),
              const SizedBox(height: 24),
              const PublicDnsDiagnosticCard(),
              const SizedBox(height: 16),
              const SubstrateDoctrine(
                text:
                    'Verification has three states, not two. When the substrate '
                    'hasn\'t evaluated a record yet, the result is UNKNOWN '
                    'and is never coerced into PASS.',
              ),
              const SizedBox(height: 16),
              const SubstrateCitation(
                paths: [
                  'orchestrate_backend/src/deliverability/sending-identity.service.ts',
                  'orchestrate_backend/src/runtime-truth/runtime-truth.types.ts (CanonicalDnsCheck)',
                ],
              ),
              const SizedBox(height: 24),
              _CrossLinks(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.publicAccentSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Operational diagnostics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.publicAccent,
                  ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Verify your sending-domain readiness against Orchestrate\'s real DNS checks.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'No account required. The check below runs live SPF / DKIM / DMARC lookups against the domain you supply. The same verification logic gates dispatch eligibility on activated accounts. Nothing here is mocked or estimated.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
        ],
      ),
    );
  }
}

class _CrossLinks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Related operational surfaces',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton(
                onPressed: () => context.go('/trust-architecture'),
                child: const Text('Trust architecture'),
              ),
              OutlinedButton(
                onPressed: () => context.go('/how-orchestrate-operates'),
                child: const Text('How Orchestrate operates'),
              ),
              OutlinedButton(
                onPressed: () => context.go('/for-evaluators'),
                child: const Text('For evaluators'),
              ),
              FilledButton(
                onPressed: () => context.go('/activation'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.publicText,
                  foregroundColor: Colors.white,
                ),
                child: const Text('See activation progression'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Reusable diagnostic card — input domain + run check + render
/// per-record outcome.
class PublicDnsDiagnosticCard extends StatefulWidget {
  const PublicDnsDiagnosticCard({super.key, this.repository});

  final PublicRepository? repository;

  @override
  State<PublicDnsDiagnosticCard> createState() =>
      _PublicDnsDiagnosticCardState();
}

class _PublicDnsDiagnosticCardState extends State<PublicDnsDiagnosticCard> {
  late final PublicRepository _repository =
      widget.repository ?? PublicRepository();
  final _controller = TextEditingController();
  bool _running = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final domain = _controller.text.trim();
    if (domain.isEmpty) {
      setState(() => _error = 'Enter the sending domain you want to verify.');
      return;
    }
    setState(() {
      _running = true;
      _error = null;
      _result = null;
    });
    try {
      _result = await _repository.diagnosticsDns(domain);
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dns_outlined,
                  size: 16, color: AppTheme.publicMuted),
              const SizedBox(width: 8),
              Text(
                'DNS readiness check',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.publicMuted,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Enter the domain you intend to send from. The check confirms SPF, DKIM, and DMARC records exist and match what Orchestrate expects to find at dispatch time.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.publicMuted,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 540;
              final field = TextField(
                controller: _controller,
                onSubmitted: (_) => _run(),
                decoration: InputDecoration(
                  labelText: 'Domain',
                  hintText: 'e.g. mail.acme.com',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              );
              final button = FilledButton(
                onPressed: _running ? null : _run,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.publicText,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                ),
                child: Text(_running ? 'Checking…' : 'Run check'),
              );
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    field,
                    const SizedBox(height: 12),
                    button,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: field),
                  const SizedBox(width: 12),
                  button,
                ],
              );
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 18),
            _renderResult(context, _result!),
          ],
        ],
      ),
    );
  }

  Widget _renderResult(BuildContext context, Map<String, dynamic> result) {
    final domain = result['domain']?.toString() ?? '';
    final ready = result['ready'] == true;
    final checks = (result['checks'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: ready
                ? AppTheme.coVerdant.withValues(alpha: 0.08)
                : AppTheme.publicSurfaceSoft,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(
              color: ready
                  ? AppTheme.coVerdant.withValues(alpha: 0.40)
                  : AppTheme.publicLine,
            ),
          ),
          child: Row(
            children: [
              SubstrateChip(
                label: ready ? 'READY' : 'INCOMPLETE',
                state: ready
                    ? SubstrateChipState.verdant
                    : SubstrateChipState.sun,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  ready
                      ? 'All required records present and match. $domain is dispatch-ready.'
                      : 'One or more records are missing or have not yet been evaluated. See per-record detail below.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.publicText,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final check in checks) _renderCheck(context, check.cast<String, dynamic>()),
        const SizedBox(height: 12),
        Text(
          'No records were stored. The lookup runs against live DNS each time you press "Run check".',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.publicMuted,
                fontStyle: FontStyle.italic,
              ),
        ),
      ],
    );
  }

  Widget _renderCheck(BuildContext context, Map<String, dynamic> check) {
    final purpose = check['purpose']?.toString().toUpperCase() ?? '?';
    final type = check['type']?.toString() ?? '';
    final host = check['host']?.toString() ?? '';
    final expected = check['expectedValue']?.toString() ?? '';
    final observed = (check['observedValues'] as List? ?? const [])
        .map((v) => v?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    final matched = check['matched'] == true;
    final explanation = check['explanation']?.toString() ?? '';
    final errorMessage = check['errorMessage']?.toString();

    // Canonical three-state triad per `CanonicalDnsCheck` doctrine.
    // PASS = matched. FAIL = explicit error from the resolver.
    // UNKNOWN = no match yet, no error — honest unknown, not failure.
    final state = matched
        ? _CheckState.pass
        : (errorMessage != null && errorMessage.isNotEmpty
            ? _CheckState.fail
            : _CheckState.unknown);

    final SubstrateChipState chipState;
    final IconData icon;
    final String label;
    switch (state) {
      case _CheckState.pass:
        chipState = SubstrateChipState.verdant;
        icon = Icons.check_circle_outline;
        label = 'PASS';
        break;
      case _CheckState.fail:
        chipState = SubstrateChipState.rose;
        icon = Icons.cancel_outlined;
        label = 'FAIL';
        break;
      case _CheckState.unknown:
        chipState = SubstrateChipState.mist;
        icon = Icons.help_outline;
        label = 'UNKNOWN';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _foreground(state)),
              const SizedBox(width: 8),
              Text(
                '$purpose · $type',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.publicText,
                ),
              ),
              const Spacer(),
              SubstrateChip(label: label, state: chipState),
            ],
          ),
          const SizedBox(height: 8),
          if (explanation.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                explanation,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.publicMuted,
                      height: 1.4,
                    ),
              ),
            ),
          _kv('Host', host),
          _kv('Expected', expected),
          if (observed.isEmpty)
            _kv('Observed', '(no records returned)')
          else
            for (final value in observed) _kv('Observed', value),
          if (errorMessage != null && errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                errorMessage,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppTheme.publicMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                color: AppTheme.publicText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Internal three-state verification result. Mirrors the backend's
/// `CanonicalDnsCheck = 'pass' | 'fail' | 'unknown'` discipline —
/// see `orchestrate_backend/src/runtime-truth/runtime-truth.types.ts`.
enum _CheckState { pass, fail, unknown }

Color _foreground(_CheckState state) {
  switch (state) {
    case _CheckState.pass:
      return AppTheme.coVerdant;
    case _CheckState.fail:
      return AppTheme.coRose;
    case _CheckState.unknown:
      return AppTheme.coMist;
  }
}
