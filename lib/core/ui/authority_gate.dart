import 'package:flutter/material.dart';

import '../authority/client_authority.dart';
import '../theme/app_theme.dart';
import 'governed_action.dart';

/// THE POINT-OF-ACTION CONTRACT.
///
/// Every consequential act in the product answers the same three questions:
/// what does this do in the world, may this person do it, and if not, why. This
/// is where those are answered together, once — so a later chapter adding
/// "issue an invoice" or "sign an agreement" wires an act into governance
/// rather than inventing a permission check of its own.
///
/// The two failure modes it exists to prevent.
///
///   OPTIMISTIC OFFERING. An enabled button, a click, a server refusal, and a
///   red toast. The person was invited to do something they were never allowed
///   to do, and learned it the hard way. Authority is asked BEFORE the act is
///   offered, and the surface shapes itself around the answer.
///
///   SILENT DISABLING. A greyed-out control with no explanation, which states
///   a refusal and withholds the reason. The backend always sends a reason and
///   a resolution; withholding either is discarding the most useful part of
///   the response.
///
/// It never decides anything. `permitted` comes from the server, every time.
class AuthorityGate extends StatefulWidget {
  const AuthorityGate({
    super.key,
    required this.consequence,
    required this.label,
    required this.onProceed,
    this.by = PerformedBy.human,
    this.busy = false,
  });

  /// What this act does in the world. Drives both the authority question and
  /// how the control looks, from the one classification.
  final Consequence consequence;

  final String label;

  /// Run only when the server has said this may proceed.
  final VoidCallback onProceed;

  /// Whether the person does this themselves, or Orchestrate does it for them.
  /// The same act has different answers, and asking the wrong one is how
  /// software ends up acting on authority nobody delegated to it.
  final PerformedBy by;

  final bool busy;

  @override
  State<AuthorityGate> createState() => _AuthorityGateState();
}

class _AuthorityGateState extends State<AuthorityGate> {
  ActionAuthority? _answer;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _ask();
  }

  @override
  void didUpdateWidget(AuthorityGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.consequence != widget.consequence || oldWidget.by != widget.by) {
      _ask();
    }
  }

  Future<void> _ask() async {
    setState(() {
      _answer = null;
      _error = null;
    });
    try {
      final answer = await ClientAuthority.instance
          .can(widget.consequence, by: widget.by);
      if (mounted) setState(() => _answer = answer);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      // Unknown is not permitted. An act whose authority could not be read is
      // withheld, and says so, rather than being offered on the assumption
      // that it would probably have been fine.
      return GovernedAction(
        label: widget.label,
        consequence: widget.consequence,
        onPressed: null,
        unavailableBecause:
            'We could not check whether you may do this, so it is unavailable '
            'for now.',
      );
    }

    final answer = _answer;
    if (answer == null) {
      return GovernedAction(
        label: widget.label,
        consequence: widget.consequence,
        onPressed: null,
        busy: true,
      );
    }

    if (answer.permitted) {
      return GovernedAction(
        label: widget.label,
        consequence: widget.consequence,
        onPressed: widget.onProceed,
        busy: widget.busy,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GovernedAction(
          label: widget.label,
          consequence: widget.consequence,
          onPressed: null,
          unavailableBecause: answer.requiresLabel == null
              ? null
              : 'Needs ${answer.requiresLabel!.toLowerCase()} authority.',
        ),
        if (answer.refusal != null) AuthorityRefusalNotice(refusal: answer.refusal!),
      ],
    );
  }
}

/// A refusal the backend explained, rendered as an explanation.
///
/// Three parts, and all three are shown: what happened, what would resolve it,
/// and the code — because the code is what makes a support conversation
/// possible, and the resolution is what keeps a refusal from being a dead end.
class AuthorityRefusalNotice extends StatelessWidget {
  const AuthorityRefusalNotice({super.key, required this.refusal, this.onResolve});

  final AuthorityRefusal refusal;

  /// Offered when this surface can actually take the person to the resolution.
  /// Absent is fine; the resolution is stated either way.
  final VoidCallback? onResolve;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.amber.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.gpp_maybe_outlined, size: 16, color: AppTheme.amber),
              const SizedBox(width: 8),
              // Verbatim. The backend wrote this for the person reading it.
              Expanded(child: Text(refusal.why, style: text.bodySmall)),
            ],
          ),
          if (refusal.resolution.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 24),
              child: Text(
                refusal.resolution,
                style: text.bodySmall?.copyWith(color: AppTheme.publicMuted),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 24),
            child: Row(
              children: [
                Text(
                  refusal.code,
                  style: text.bodySmall?.copyWith(
                    color: AppTheme.publicMuted,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                if (onResolve != null)
                  TextButton(
                    onPressed: onResolve,
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: const Text('Sort this out'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
