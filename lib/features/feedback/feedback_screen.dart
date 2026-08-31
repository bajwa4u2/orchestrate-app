import 'package:flutter/material.dart';

import '../../data/repositories/product_feedback_repository.dart';

/// TELLING US SOMETHING.
///
/// Not an inquiry. An inquiry is what a client opens when they need an answer
/// and are owed one; this is for a member of the operating team who has
/// something to say about Orchestrate itself and wants it to reach the people
/// building it.
///
/// One question, a box, and a button. Anything more asks the person to do
/// triage work on our behalf before we have earned it.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, this.fromSurface});

  /// The KIND of screen they came from, already reduced to a pattern by the
  /// caller. Never a populated path: that names a real client or campaign.
  final String? fromSurface;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _controller = TextEditingController();
  final _repository = ProductFeedbackRepository();

  FeedbackIntent _intent = FeedbackIntent.problem;
  bool _sending = false;
  FeedbackRecord? _sent;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _controller.text.trim();
    if (message.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final context = await FeedbackContext.resolve(
        surface: widget.fromSurface,
        locale: Localizations.maybeLocaleOf(this.context)?.toLanguageTag(),
      );
      final record = await _repository.submit(
        intent: _intent,
        message: message,
        context: context,
      );
      if (!mounted) return;
      _controller.clear();
      setState(() => _sent = record);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That did not send. Try again shortly.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send feedback')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _sent != null ? _acknowledgement(_sent!) : _form(),
          ),
        ),
      ),
    );
  }

  Widget _form() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What would you like to tell us?',
            style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        RadioGroup<FeedbackIntent>(
          groupValue: _intent,
          onChanged: (v) => setState(() => _intent = v ?? _intent),
          child: Column(
            children: [
              for (final intent in FeedbackIntent.values)
                RadioListTile<FeedbackIntent>(
                  value: intent,
                  contentPadding: EdgeInsets.zero,
                  title: Text(intent.label),
                  subtitle: Text(intent.hint),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          minLines: 5,
          maxLines: 10,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'In your own words',
            hintText: 'What happened, or what you would like to see',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        const _ContextDisclosure(),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _sending ? null : _send,
          child: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send'),
        ),
      ],
    );
  }

  Widget _acknowledgement(FeedbackRecord record) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Thank you — it reached us', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        SelectableText('Your reference is ${record.ref}.'),
        const SizedBox(height: 8),
        // Honest about what happens next, including the part where it might be
        // nothing. Promising a reply we do not always send is worse than
        // saying so.
        Text(
          'Someone reads every one of these. You will hear back if it changes '
          'something, or when there is nothing further to do — not every piece '
          'of feedback gets a reply.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => setState(() => _sent = null),
          child: const Text('Send another'),
        ),
      ],
    );
  }
}

/// What we attach, said plainly and BEFORE they send.
///
/// Disclosure after the fact is not disclosure. Deliberately the whole answer
/// rather than a link to a policy: someone deciding whether to write something
/// candid should be able to see it without leaving the screen.
class _ContextDisclosure extends StatelessWidget {
  const _ContextDisclosure();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16),
              const SizedBox(width: 8),
              Text('Sent with your message',
                  style: theme.textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'The app version and build, your platform and OS version, the kind '
            'of screen you came from, and your language. Nothing about your '
            'clients, campaigns, leads or mailboxes, and no screenshot.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
