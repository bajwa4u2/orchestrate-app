import 'package:flutter/material.dart';

import '../services/support_service.dart';
import '../state/support_controller.dart';
import '../widgets/intake_card.dart';
import '../widgets/response_stream.dart';
import '../widgets/support_footer.dart';

class SupportPage extends StatefulWidget {
  final bool publicMode;
  final String baseUrl;
  final String? sourcePage;
  final String? inquiryTypeHint;

  const SupportPage({
    super.key,
    required this.publicMode,
    required this.baseUrl,
    this.sourcePage,
    this.inquiryTypeHint,
  });

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  late final SupportController controller;
  String _draft = '';

  @override
  void initState() {
    super.initState();
    controller = SupportController(
      publicMode: widget.publicMode,
      sourcePage: widget.sourcePage,
      inquiryTypeHint: widget.inquiryTypeHint,
      service: SupportService(baseUrl: widget.baseUrl),
    )..addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    controller.removeListener(_refresh);
    controller.dispose();
    super.dispose();
  }

  Future<void> _submit(String message, String? name, String? email) async {
    setState(() => _draft = '');
    await controller.sendMessage(
      message: message,
      name: name,
      email: email,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = controller.session;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SupportPageHeader(publicMode: widget.publicMode),
                  const SizedBox(height: 24),
                  IntakeCard(
                    publicMode: widget.publicMode,
                    isLoading: session.isLoading,
                    initialValue: _draft,
                    onChanged: (value) => _draft = value,
                    onSubmit: _submit,
                  ),
                  const SizedBox(height: 20),
                  ResponseStream(
                    messages: session.messages,
                    isLoading: session.isLoading,
                    onFollowUpTap: (value) async {
                      await controller.sendMessage(message: value);
                    },
                  ),
                  const SizedBox(height: 4),
                  const SupportFooter(showStripe: false),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportPageHeader extends StatelessWidget {
  const _SupportPageHeader({required this.publicMode});

  final bool publicMode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Help & Support',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            publicMode ? 'Start with what you need' : 'Get help without losing context',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          Text(
            publicMode
                ? 'Describe the question, issue, or setup need. We will answer immediately where possible and move it into review only when needed.'
                : 'Describe the question, issue, or setup need. We will answer immediately where possible and use your existing workspace context where it helps.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.72),
                ),
          ),
        ],
      ),
    );
  }
}
