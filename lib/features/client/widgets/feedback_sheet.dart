import 'package:flutter/material.dart';

import '../../../core/release/release_identity.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/client/client_feedback_repository.dart';

/// TELLING US SOMETHING WITHOUT LEAVING THE PRODUCT.
///
/// One sheet, reachable from the account menu on every client. It says what
/// travels with the report before the person sends it, because a feedback form
/// that quietly attaches diagnostics is collecting rather than listening.
class FeedbackSheet extends StatefulWidget {
  const FeedbackSheet({super.key, required this.surface});

  /// Where they were when they opened it. Sent so a report about "the
  /// relationships page" does not have to describe which page it was.
  final String surface;

  static Future<void> open(BuildContext context, {required String surface}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: FeedbackSheet(surface: surface),
      ),
    );
  }

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<FeedbackSheet> {
  final _repo = ClientFeedbackRepository();
  final _message = TextEditingController();

  FeedbackIntent _intent = FeedbackIntent.problem;
  ReleaseIdentity? _release;
  bool _sending = false;
  bool _sent = false;
  String? _refusal;

  @override
  void initState() {
    super.initState();
    ReleaseIdentity.load().then((r) {
      if (mounted) setState(() => _release = r);
    });
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _refusal = null;
    });
    final result = await _repo.send(
      intent: _intent,
      message: _message.text,
      surface: widget.surface,
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = result.ok;
      _refusal = result.reason;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final release = _release;

    return Container(
      constraints: const BoxConstraints(maxWidth: 560),
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: _sent ? _thanks(text) : _form(text, release),
    );
  }

  Widget _thanks(TextTheme text) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  size: 20, color: AppTheme.publicAccent),
              const SizedBox(width: 10),
              Text('Sent', style: text.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Thank you. A person reads these — it goes to the same queue our '
            'own team works from, not into a mailbox nobody opens.',
            style: text.bodySmall?.copyWith(height: 1.55),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ),
        ],
      );

  Widget _form(TextTheme text, ReleaseIdentity? release) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tell us something', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'About Orchestrate itself — not about a customer or a deal.',
            style: text.bodySmall?.copyWith(color: AppTheme.publicMuted),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final intent in FeedbackIntent.values)
                ChoiceChip(
                  label: Text(intent.label),
                  selected: _intent == intent,
                  onSelected: (_) => setState(() => _intent = intent),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _message,
            autofocus: true,
            minLines: 4,
            maxLines: 8,
            maxLength: 4000,
            decoration: const InputDecoration(
              hintText: 'What happened, and what you expected instead.',
            ),
          ),
          const SizedBox(height: 4),
          // WHAT TRAVELS WITH IT, SAID BEFORE THEY SEND.
          //
          // A feedback form that quietly attaches diagnostics is collecting
          // rather than listening. Nothing goes but what they typed and which
          // build they are on.
          Text(
            release == null
                ? 'Your message is sent with which build you are on. Nothing '
                    'from your workspace is attached.'
                : 'Sent with your message: Orchestrate ${release.label} on '
                    '${release.platform.toLowerCase()}, and which page you were '
                    'on. Nothing from your workspace is attached — no customer '
                    'data, no messages, no screenshot.',
            style: text.bodySmall?.copyWith(
                color: AppTheme.publicMuted, height: 1.5),
          ),
          if (_refusal != null) ...[
            const SizedBox(height: 10),
            Text(_refusal!,
                style: text.bodySmall?.copyWith(color: AppTheme.amber)),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _sending ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _sending ? null : _send,
                child: Text(_sending ? 'Sending…' : 'Send'),
              ),
            ],
          ),
        ],
      );
}
