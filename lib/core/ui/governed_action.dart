import 'package:flutter/material.dart';
import '../authority/consequence.dart';
import '../theme/app_theme.dart';

export '../authority/consequence.dart' show Consequence;

/// CONSEQUENCE AND REFUSAL, AS THE BACKEND ACTUALLY STATES THEM.
///
/// Two failures this replaces.
///
///   CONSEQUENCE WAS INVISIBLE. "Save draft" and "Issue invoice" looked
///   identical. The backend has always classified acts — reversible-internal,
///   externally communicated, contractual, financial, terminal — and the
///   client rendered none of it. The fix is not a confirmation dialog on
///   everything; it is that the action itself should look like what it does.
///
///   REFUSALS BECAME "Something went wrong." Fifty-six sites surfaced
///   `e.toString()`. Meanwhile the backend writes refusals a person can act
///   on: "This client granted representation for EXTERNAL_COMMUNICATION, which
///   does not cover CONTRACTUAL." Throwing that away and substituting a
///   generic failure is destroying the most useful thing in the response.

extension ConsequencePresentation on Consequence {
  /// The short phrase shown beside an action. Absent for internal work,
  /// because saying "this is internal" about everything trains people to stop
  /// reading the ones that are not.
  String? get note => switch (this) {
        Consequence.informational => null,
        Consequence.reversibleInternal => null,
        Consequence.externallyCommunicated => 'Goes to the counterparty',
        Consequence.contractual => 'Commits the business',
        Consequence.financial => 'Claims money',
        Consequence.terminal => 'Cannot be undone',
      };

  Color get accent => switch (this) {
        Consequence.informational => AppTheme.publicMuted,
        Consequence.reversibleInternal => AppTheme.publicMuted,
        Consequence.externallyCommunicated => AppTheme.publicAccent,
        Consequence.contractual => AppTheme.amber,
        Consequence.financial => AppTheme.amber,
        Consequence.terminal => AppTheme.rose,
      };

  bool get leavesTheSystem =>
      this != Consequence.reversibleInternal && this != Consequence.informational;
}

/// An action that looks like what it costs.
///
/// Internal work is a quiet outlined button. Anything that leaves the system
/// is filled and carries its consequence in words underneath — so the weight
/// is read before the click, not confirmed after it.
class GovernedAction extends StatelessWidget {
  const GovernedAction({
    super.key,
    required this.label,
    required this.consequence,
    this.onPressed,
    this.busy = false,
    this.unavailableBecause,
  });

  final String label;
  final Consequence consequence;
  final VoidCallback? onPressed;
  final bool busy;

  /// Why this cannot be done right now.
  ///
  /// A greyed-out button with no explanation is the silent cousin of
  /// "Something went wrong" — it states a refusal and withholds the reason.
  final String? unavailableBecause;

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox(
            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
        : Text(label);
    final enabled = onPressed != null && !busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (consequence.leavesTheSystem)
          FilledButton(
            onPressed: enabled ? onPressed : null,
            style: FilledButton.styleFrom(
              backgroundColor: consequence == Consequence.terminal
                  ? AppTheme.rose
                  : AppTheme.publicAccent,
            ),
            child: child,
          )
        else
          OutlinedButton(onPressed: enabled ? onPressed : null, child: child),
        if (!enabled && unavailableBecause != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(
              unavailableBecause!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.publicMuted, fontSize: 11),
            ),
          )
        else if (consequence.note != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(
              consequence.note!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: consequence.accent, fontSize: 11),
            ),
          ),
      ],
    );
  }
}

/// A refusal the backend explained.
///
/// The backend returns `{ok: false, code, reason}` for governed refusals. The
/// reason is written for the person who hit it and is the whole value of the
/// response; this renders it verbatim. The code is shown quietly, because it
/// is what makes a support conversation possible.
class Refusal {
  const Refusal({required this.reason, this.code, this.kind = RefusalKind.governed});

  final String reason;
  final String? code;
  final RefusalKind kind;

  /// Read a refusal out of a backend response.
  ///
  /// Returns null when the response is not a refusal, so a caller can treat
  /// "succeeded" and "was refused" as genuinely different outcomes rather than
  /// discovering the difference by inspecting strings.
  static Refusal? fromResponse(Map<String, dynamic> response) {
    if (response['ok'] != false) return null;
    final reason = response['reason']?.toString();
    return Refusal(
      reason: reason?.isNotEmpty == true
          ? reason!
          : 'This was refused, and no reason was given.',
      code: response['code']?.toString(),
    );
  }

  /// Everything else. A transport failure is not a governed refusal and must
  /// not be dressed up as one — the distinction matters to whoever debugs it.
  factory Refusal.unexpected(Object error) => Refusal(
        reason: error.toString(),
        kind: RefusalKind.unexpected,
      );
}

enum RefusalKind {
  /// The system decided, and said why.
  governed,

  /// Something broke.
  unexpected,
}

/// How a refusal is shown wherever one can happen.
class RefusalNotice extends StatelessWidget {
  const RefusalNotice({super.key, required this.refusal, this.onRetry});

  final Refusal refusal;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final governed = refusal.kind == RefusalKind.governed;
    final accent = governed ? AppTheme.amber : AppTheme.rose;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: accent.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(governed ? Icons.gpp_maybe_outlined : Icons.error_outline,
                  size: 16, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  // Verbatim. The backend wrote this for the person reading it.
                  refusal.reason,
                  style: text.bodySmall,
                ),
              ),
            ],
          ),
          // THE CODE IS OURS, NOT THEIRS.
          //
          // ORGANIZATION_AUTHORITY_NOT_ESTABLISHED was printed in monospace
          // underneath a refusal a customer had just read in plain English. It
          // told them nothing they could act on and made a clear sentence look
          // like an error screen. The refusal already says what happened and
          // what would resolve it; the code stays in the payload for support
          // and in the tooltip for anyone who needs to quote it.
          if (onRetry != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 24),
              child: Row(
                children: [
                  const Spacer(),
                  if (onRetry != null)
                    TextButton(
                        onPressed: onRetry,
                        style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact),
                        child: const Text('Try again')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
