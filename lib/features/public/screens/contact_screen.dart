import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/theme/ob.dart';
import 'package:orchestrate_app/core/ui/ob_widgets.dart';
import 'package:orchestrate_app/features/public/widgets/visitor_assistant.dart';

/// CONTACT (DD-26, rebuilt 2 Oct 2026).
///
/// The visitor assistant is the support here: answered on the spot from what
/// Orchestrate is today, about the visitor's own kind of business, with a
/// person when they want one. It replaced a conversation that described
/// retired plans ("Opportunity", "Revenue", "Focused", "Multi", "Precision").
class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

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
              const intro = _ContactIntro();
              const support = VisitorAssistant(page: '/contact');
              if (stacked) {
                return const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [intro, SizedBox(height: 20), support],
                );
              }
              return const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: intro),
                  SizedBox(width: 24),
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

/// What the page is for, and the two other doors: email, and signing in for
/// anything about an account.
class _ContactIntro extends StatelessWidget {
  const _ContactIntro();

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
        Text('Whether Orchestrate fits your kind of business, what it costs, '
            'or how your email is connected. Ask in the box and an answer '
            'comes back straight away; a person whenever you want one.',
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
