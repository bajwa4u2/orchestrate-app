import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/features/public/widgets/commercial_execution_surface.dart';
import 'package:orchestrate_app/features/public/widgets/execution_visual_chapters.dart';
import 'package:orchestrate_app/features/public/widgets/public_overview_widget.dart';
import 'package:orchestrate_app/features/support/screens/support_drawer.dart';

Future<void> _openPublicSupportDrawer(BuildContext context) async {
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Support',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: SupportDrawer(
              publicMode: true,
            ),
          ),
        ],
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

class PublicHomeScreen extends StatelessWidget {
  const PublicHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The PublicShell already provides 28px horizontal gutters. This screen
    // adds only vertical spacing. On narrow viewports the vertical gaps also
    // tighten so the page does not become an excessive scroll tower.
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        final gap = compact ? 16.0 : 24.0;
        return Padding(
          padding: EdgeInsets.only(
            top: compact ? 8 : 10,
            bottom: compact ? 28 : 44,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PublicOverviewWidget(),
              SizedBox(height: gap),
              CommercialHero(onTalk: () => _openPublicSupportDrawer(context)),
              SizedBox(height: gap),
              const ExecutionObjectStage(),
              SizedBox(height: gap),
              const ExecutionGraphChapter(),
              SizedBox(height: gap),
              const RecoveryVisualChapter(),
              SizedBox(height: gap),
              const SignalsVisualChapter(),
              SizedBox(height: gap),
              const RevenueRecordsVisual(),
              SizedBox(height: gap),
              const ResponsibleAiVisualChapter(),
              SizedBox(height: gap),
            ],
          ),
        );
      },
    );
  }
}

// The previous public home lived in this file as a long chain of private
// section widgets. Every one of them was orphaned when the page moved to the
// composed surfaces above, and the orphans kept an older product story alive in
// the source: a "Governed Revenue Automation" hero about DNS records and mailbox
// OAuth that had not rendered for some time. It was read twice as though it were
// the live page and reported as a defect both times. Dead copy that still
// describes the product is not neutral, so it is gone rather than commented out.
