import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

/// DD-26: one support surface, the way support works now. The conversation
/// on the right is the support; this side only says what it is for and the
/// two other doors: email, and signing in for anything about an account.
/// The explanatory cards and the second "quick answers" tray that opened the
/// same conversation again are gone.
class _ContactIntro extends StatelessWidget {
  const _ContactIntro({required this.onOpenDrawer});

  // Kept for the call site; the tray is no longer offered here.
  final VoidCallback onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    Widget door(IconData icon, String title, Widget body) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 12),
              child: Icon(icon, size: 20, color: Ob.inkSoft),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Ob.strong(16)),
                const SizedBox(height: 3),
                body,
              ]),
            ),
          ]),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CONTACT', style: Ob.eyebrow()),
        const SizedBox(height: 14),
        const ObHeadline('Ask us anything.', size: 44),
        const SizedBox(height: 14),
        Text('Price, how Orchestrate would find customers for your business, '
            'or setting up your email. Ask in the box and an answer comes '
            'back straight away.',
            style: Ob.body(17)),
        const SizedBox(height: 28),
        door(Icons.mail_outline, 'Email',
            SelectableText('support@orchestrateops.com', style: Ob.body(15))),
        door(
            Icons.lock_outline,
            'Already a customer?',
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('Sign in and use Support inside your workspace, so we can '
                  'see your account. ',
                  style: Ob.body(15)),
              InkWell(
                onTap: () => GoRouter.of(context).go('/auth/login'),
                child: Text('Sign in', style: Ob.strong(15)),
              ),
            ])),
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
              'Your message reaches the Orchestrate team, and a first answer appears here.',
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
