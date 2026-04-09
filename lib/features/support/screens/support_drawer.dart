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

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.of(context).size.width;
    final drawerWidth = availableWidth < 560 ? availableWidth : 460.0;

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
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
                        ? 'Describe your need and we’ll guide you forward.'
                        : 'Describe what you need and we’ll guide you forward using your current workspace context where it helps.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: ResponseStream(
                        messages: controller.session.messages,
                        isLoading: controller.session.isLoading,
                        onFollowUpTap: (value) async {
                          await controller.sendMessage(message: value);
                        },
                      ),
                    ),
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
