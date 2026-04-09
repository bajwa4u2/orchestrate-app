import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../features/support/screens/support_drawer.dart';
import '../../features/support/services/support_service.dart';
import '../../features/support/state/support_controller.dart';
import '../../features/support/widgets/intake_card.dart';
import '../../features/support/widgets/response_stream.dart';
import '../../features/support/widgets/support_footer.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  late final SupportController _controller;
  String _draft = '';

  @override
  void initState() {
    super.initState();
    _controller = SupportController(
      publicMode: true,
      service: const SupportService(baseUrl: AppConfig.apiBaseUrl),
    )..addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openSupportDrawer() async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close support',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const SupportDrawer(
          publicMode: true,
          baseUrl: AppConfig.apiBaseUrl,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offset = Tween<Offset>(
          begin: const Offset(0.08, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

        return SlideTransition(
          position: offset,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 980;

              final intro = _ContactIntro(onOpenDrawer: _openSupportDrawer);
              final support = _ContactSupportSurface(
                controller: _controller,
                draft: _draft,
                onDraftChanged: (value) => setState(() => _draft = value),
              );

              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    intro,
                    const SizedBox(height: 20),
                    support,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: intro),
                  const SizedBox(width: 24),
                  Expanded(flex: 6, child: support),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ContactIntro extends StatelessWidget {
  const _ContactIntro({required this.onOpenDrawer});

  final VoidCallback onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.publicSurfaceSoft,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.publicLine),
            ),
            child: Text(
              'Contact',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.publicMuted,
                  ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Describe what you need and we’ll guide the conversation forward.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'Use this page for fit, pricing, onboarding, billing, or any operational question before you move ahead.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 28),
          const _DetailCard(
            title: 'How to begin',
            body:
                'Start with the message itself. We will respond directly or guide the next step from there.',
          ),
          const SizedBox(height: 14),
          const _DetailCard(
            title: 'What to include',
            body:
                'Share the market you serve, what you want to achieve, what is already in place, and anything that changes the scope.',
          ),
          const SizedBox(height: 14),
          const _DetailCard(
            title: 'When to open the side panel',
            body:
                'Use the side panel if you want support to stay open while you review pricing or another public page.',
          ),
          const SizedBox(height: 22),
          OutlinedButton(
            onPressed: onOpenDrawer,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.publicText,
              side: const BorderSide(color: AppTheme.publicLine),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Open support panel'),
          ),
        ],
      ),
    );
  }
}

class _ContactSupportSurface extends StatelessWidget {
  const _ContactSupportSurface({
    required this.controller,
    required this.draft,
    required this.onDraftChanged,
  });

  final SupportController controller;
  final String draft;
  final ValueChanged<String> onDraftChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tell us what you need',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          Text(
            'We’ll respond immediately or guide you forward.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 24),
          IntakeCard(
            publicMode: true,
            isLoading: controller.session.isLoading,
            initialValue: draft,
            onChanged: onDraftChanged,
            onSubmit: (message, name, email) async {
              onDraftChanged('');
              await controller.sendMessage(
                message: message,
                name: name,
                email: email,
              );
            },
          ),
          const SizedBox(height: 18),
          ResponseStream(
            messages: controller.session.messages,
            isLoading: controller.session.isLoading,
            onFollowUpTap: (value) => controller.sendMessage(message: value),
          ),
          const SizedBox(height: 18),
          const SupportFooter(showStripe: false),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
