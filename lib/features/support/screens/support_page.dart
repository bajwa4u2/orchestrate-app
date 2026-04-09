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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.publicMode ? 'Tell us what you need' : 'Help & Support',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.publicMode
                        ? 'We’ll respond immediately or guide you forward.'
                        : 'Describe what you need and we’ll guide you forward using your current workspace context where it helps.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  IntakeCard(
                    publicMode: widget.publicMode,
                    isLoading: controller.session.isLoading,
                    initialValue: _draft,
                    onChanged: (value) => _draft = value,
                    onSubmit: (message, name, email) async {
                      _draft = '';
                      await controller.sendMessage(
                        message: message,
                        name: name,
                        email: email,
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  ResponseStream(
                    messages: controller.session.messages,
                    isLoading: controller.session.isLoading,
                    onFollowUpTap: (value) async {
                      await controller.sendMessage(message: value);
                    },
                  ),
                  SupportFooter(showStripe: false),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
