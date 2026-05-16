import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'guidance_models.dart';
import 'guidance_repository.dart';
import 'widgets/guidance_reply_card.dart';

/// Explicit targets the drawer can be opened with. Each target maps
/// to one backend explain endpoint. No free-text chat surface.
enum GuidanceTarget {
  readiness,
  sendingIdentity,
  dispatchGovernance,
  executionPaused,
  dispatchThrottled,
  dnsVerificationPending,
  mailboxReauthRequired,
  mailboxProviderError,
  recoveryInProgress,
  signalQualificationRejected,
}

/// Opens the Orchestrate guidance drawer with the requested target.
/// The drawer is the one deliberate guidance surface — there is no
/// floating bubble, no popup, no auto-open.
Future<void> openGuidanceDrawer(
  BuildContext context, {
  required GuidanceTarget target,
  String? surface,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close guidance',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: GuidanceDrawer(target: target, surface: surface),
          ),
        ],
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

class GuidanceDrawer extends StatefulWidget {
  const GuidanceDrawer({
    super.key,
    required this.target,
    this.surface,
    GuidanceRepository? repository,
  }) : _repository = repository;

  final GuidanceTarget target;
  final String? surface;
  final GuidanceRepository? _repository;

  @override
  State<GuidanceDrawer> createState() => _GuidanceDrawerState();
}

class _GuidanceDrawerState extends State<GuidanceDrawer> {
  late final GuidanceRepository _repository =
      widget._repository ?? GuidanceRepository();
  Future<GuidanceReply>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<GuidanceReply> _load() {
    switch (widget.target) {
      case GuidanceTarget.readiness:
        return _repository.explainReadiness(surface: widget.surface);
      case GuidanceTarget.sendingIdentity:
        return _repository.explainSendingIdentity(surface: widget.surface);
      case GuidanceTarget.dispatchGovernance:
        return _repository.explainDispatchGovernance(surface: widget.surface);
      case GuidanceTarget.executionPaused:
        return _repository.explainExecutionState(
            kind: 'execution-paused', surface: widget.surface);
      case GuidanceTarget.dispatchThrottled:
        return _repository.explainExecutionState(
            kind: 'dispatch-throttled', surface: widget.surface);
      case GuidanceTarget.dnsVerificationPending:
        return _repository.explainExecutionState(
            kind: 'dns-verification-pending', surface: widget.surface);
      case GuidanceTarget.mailboxReauthRequired:
        return _repository.explainExecutionState(
            kind: 'mailbox-reauth-required', surface: widget.surface);
      case GuidanceTarget.mailboxProviderError:
        return _repository.explainExecutionState(
            kind: 'mailbox-provider-error', surface: widget.surface);
      case GuidanceTarget.recoveryInProgress:
        return _repository.explainExecutionState(
            kind: 'recovery-in-progress', surface: widget.surface);
      case GuidanceTarget.signalQualificationRejected:
        return _repository.explainExecutionState(
            kind: 'signal-qualification-rejected', surface: widget.surface);
    }
  }

  Future<void> _submitFeedback(GuidanceReply reply, String rating) async {
    final auditEventId = reply.auditEventId;
    if (auditEventId == null) return;
    try {
      if (rating == 'incorrect') {
        await _repository.reportUnsafeResponse(
          auditEventId: auditEventId,
          surface: widget.surface,
          reason: 'inaccurate',
        );
      } else {
        await _repository.submitFeedback(
          auditEventId: auditEventId,
          rating: rating,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback recorded')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not record feedback right now')),
      );
    }
  }

  void _handleNavigate(String route) {
    Navigator.of(context).pop();
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border:
              Border(left: BorderSide(color: theme.colorScheme.outlineVariant)),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(target: widget.target, onClose: () => Navigator.of(context).pop()),
              const _SystemBanner(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: FutureBuilder<GuidanceReply>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Center(
                            child: SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      if (snapshot.hasError || snapshot.data == null) {
                        return _ErrorState(onRetry: () {
                          setState(() {
                            _future = _load();
                          });
                        });
                      }
                      final reply = snapshot.data!;
                      return GuidanceReplyCard(
                        reply: reply,
                        onNavigate: _handleNavigate,
                        onFeedback: (rating) => _submitFeedback(reply, rating),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.target, required this.onClose});

  final GuidanceTarget target;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guidance',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _targetTitle(target),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  String _targetTitle(GuidanceTarget target) {
    switch (target) {
      case GuidanceTarget.readiness:
        return 'Why this readiness state?';
      case GuidanceTarget.sendingIdentity:
        return 'Sending identity explained';
      case GuidanceTarget.dispatchGovernance:
        return 'Dispatch governance explained';
      case GuidanceTarget.executionPaused:
        return 'Why execution is paused';
      case GuidanceTarget.dispatchThrottled:
        return 'Why dispatch is throttled';
      case GuidanceTarget.dnsVerificationPending:
        return 'Why DNS verification is pending';
      case GuidanceTarget.mailboxReauthRequired:
        return 'Why the mailbox needs re-authorization';
      case GuidanceTarget.mailboxProviderError:
        return 'Why outbound provider is being reconfigured';
      case GuidanceTarget.recoveryInProgress:
        return 'Recovery in progress';
      case GuidanceTarget.signalQualificationRejected:
        return 'Why a signal did not enter dispatch';
    }
  }
}

class _SystemBanner extends StatelessWidget {
  const _SystemBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "System-aware guidance — not a chatbot. Every answer is read from real backend state and shows its sources. Not a human.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Guidance is temporarily unavailable',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'The guidance service did not return an answer. This is typically a transient backend issue; try again in a moment.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
