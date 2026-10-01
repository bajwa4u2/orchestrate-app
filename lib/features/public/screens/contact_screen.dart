import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/ob.dart';
import 'package:orchestrate_app/core/ui/ob_widgets.dart';
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
      padding: const EdgeInsets.fromLTRB(0, 56, 0, 56),
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

/// DD-26: who to talk to and about what, in the front door's words.
class _ContactIntro extends StatelessWidget {
  const _ContactIntro({required this.onOpenDrawer});

  final VoidCallback onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    Widget point(String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Ob.strong(16)),
              const SizedBox(height: 4),
              Text(body, style: Ob.body(15)),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CONTACT', style: Ob.eyebrow()),
        const SizedBox(height: 14),
        const ObHeadline('Ask us anything before you start.', size: 44),
        const SizedBox(height: 14),
        Text(
            'Ask about price, how Orchestrate would find customers for your '
            'business, or what setting up your email involves.',
            style: Ob.body(17)),
        const SizedBox(height: 28),
        point('Good things to tell us',
            'What you sell, who usually buys it, and where they are.'),
        point('About your email',
            'Which address you would send from, and who runs your domain. '
            'A Gmail or Outlook address is fine.'),
        point('Short question?',
            'Quick answers stay open beside the page you are reading.'),
        OutlinedButton(
          onPressed: onOpenDrawer,
          child: const Text('Open quick answers'),
        ),
      ],
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
        color: Ob.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Ob.liftHigh,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 10),
            child: Text('Write to us', style: Ob.name(26)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 18),
            child: Text(
              'Leave your email and we will answer there.',
              style: Ob.body(15, color: Ob.inkMuted),
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
