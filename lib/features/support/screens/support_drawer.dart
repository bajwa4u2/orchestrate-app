import 'package:flutter/material.dart';

import '../services/support_service.dart';
import '../state/support_controller.dart';
import '../widgets/intake_card.dart';
import '../widgets/response_stream.dart';
import '../widgets/support_footer.dart';

class SupportDrawer extends StatefulWidget {
  final bool publicMode;
  final String baseUrl;
  final String? sourcePage;
  final String? inquiryTypeHint;

  const SupportDrawer({
    super.key,
    required this.publicMode,
    required this.baseUrl,
    this.sourcePage,
    this.inquiryTypeHint,
  });

  @override
  State<SupportDrawer> createState() => _SupportDrawerState();
}

class _SupportDrawerState extends State<SupportDrawer> {
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
    final availableWidth = MediaQuery.of(context).size.width;
    final drawerWidth = availableWidth < 560 ? availableWidth : 460.0;
    final session = controller.session;
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: scheme.surface,
        child: SafeArea(
          child: SizedBox(
            width: drawerWidth,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Help & Support',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.publicMode
                        ? 'Start with what you need. We will answer immediately where possible and guide the rest into review only when needed.'
                        : 'Describe the question, issue, or setup need. We will use your current workspace context where it helps.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.72),
                        ),
                  ),
                  const SizedBox(height: 16),
                  IntakeCard(
                    publicMode: widget.publicMode,
                    isLoading: session.isLoading,
                    initialValue: _draft,
                    onChanged: (value) => _draft = value,
                    onSubmit: _submit,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: ResponseStream(
                        messages: session.messages,
                        isLoading: session.isLoading,
                        onFollowUpTap: (value) async {
                          await controller.sendMessage(message: value);
                        },
                      ),
                    ),
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
