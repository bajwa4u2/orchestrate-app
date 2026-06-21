import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/features/support/screens/support_drawer.dart';
import 'package:orchestrate_app/features/support/services/support_service.dart';
import 'package:orchestrate_app/features/support/state/support_controller.dart';
import 'package:orchestrate_app/features/support/widgets/intake_card.dart';
import 'package:orchestrate_app/features/support/widgets/response_stream.dart';
import 'package:orchestrate_app/features/support/widgets/support_footer.dart';

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
      service: SupportService(),
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
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offset = Tween<Offset>(
          begin: const Offset(0.08, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );

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
        borderRadius: BorderRadius.circular(AppTheme.radius),
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
            'Talk through whether managed execution infrastructure is the right fit.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'Use this page when you want a direct conversation before activating. Orchestrate is commercial intelligence + execution infrastructure, not outreach software. The right conversation is usually about scope, sending identity readiness, and which infrastructure scope (Opportunity or revenue continuity) you want Orchestrate to operate.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 28),
          const _DetailCard(
            title: 'Good reasons to use this page',
            body:
                'Scope and pricing clarity, sending-identity / domain questions, onboarding flow, or deciding between Opportunity (managed execution) and Opportunity + revenue continuity before account setup.',
          ),
          const SizedBox(height: 14),
          const _DetailCard(
            title: 'What helps the conversation',
            body:
                'Share what your business sells, the market and segments you target, the mailbox / sending domain you would connect, and any constraint (compliance, internal infrastructure, deliverability history) that shapes how Orchestrate would activate for you.',
          ),
          const SizedBox(height: 14),
          const _DetailCard(
            title: 'When quick guidance helps',
            body:
                'Use quick guidance if you want support to stay open while you compare scopes or review another public page. It is faster than booking a call when the question is short.',
          ),
          const SizedBox(height: 22),
          OutlinedButton(
            onPressed: onOpenDrawer,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.publicText,
              side: const BorderSide(color: AppTheme.publicLine),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
            ),
            child: const Text('Open quick guidance'),
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
      height: 600,
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 10),
            child: Text(
              'Start the conversation',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 18),
            child: Text(
              'We’ll respond directly or guide the next step from here.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.publicMuted,
                  ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: ResponseStream(
                messages: controller.session.messages,
                isLoading: controller.session.isLoading,
                onFollowUpTap: (_) {},
              ),
            ),
          ),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SupportFooter(showStripe: false),
          ),
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
        borderRadius: BorderRadius.circular(AppTheme.radius),
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
