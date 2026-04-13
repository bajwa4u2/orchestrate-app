import 'package:flutter/material.dart';

import '../core/auth/auth_session.dart';
import '../core/config/app_config.dart';
import '../core/theme/app_theme.dart';
import '../features/support/services/support_service.dart';
import '../features/support/state/support_controller.dart';
import '../features/support/widgets/intake_card.dart';
import '../features/support/widgets/response_stream.dart';
import '../features/support/widgets/support_footer.dart';

class ClientSupportScreen extends StatefulWidget {
  const ClientSupportScreen({super.key});

  @override
  State<ClientSupportScreen> createState() => _ClientSupportScreenState();
}

class _ClientSupportScreenState extends State<ClientSupportScreen> {
  late final SupportController _controller;
  String _draft = '';

  @override
  void initState() {
    super.initState();
    _controller = SupportController(
      publicMode: false,
      service: SupportService(
        baseUrl: AppConfig.apiBaseUrl,
        authHeadersBuilder: _authHeaders,
      ),
    )..addListener(_refresh);
  }

  Future<Map<String, String>> _authHeaders() async {
    final session = AuthSessionController.instance;
    final headers = <String, String>{};
    if (session.token.isNotEmpty) {
      headers['authorization'] = 'Bearer ${session.token}';
      headers['x-user-email'] = session.email;
      if (session.organizationId.isNotEmpty) {
        headers['x-organization-id'] = session.organizationId;
      }
      if (session.clientId.isNotEmpty) {
        headers['x-client-id'] = session.clientId;
      }
      if (session.memberRole.isNotEmpty) {
        headers['x-member-role'] = session.memberRole;
      }
    }
    return headers;
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
        return _ClientSupportDrawer(
          controller: _controller,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 1080;
              final overview = _SupportOverview(onOpenDrawer: _openSupportDrawer);
              final thread = _SupportThread(
                controller: _controller,
                draft: _draft,
                onDraftChanged: (value) => setState(() => _draft = value),
              );

              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    overview,
                    const SizedBox(height: 20),
                    thread,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: overview),
                  const SizedBox(width: 24),
                  Expanded(flex: 7, child: thread),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SupportOverview extends StatelessWidget {
  const _SupportOverview({required this.onOpenDrawer});

  final VoidCallback onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    final session = AuthSessionController.instance;
    final accountName =
        session.workspaceName.isNotEmpty ? session.workspaceName : 'Client account';

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.publicSurfaceSoft,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.publicLine),
            ),
            child: Text(
              'Help & Support',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.publicMuted,
                  ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Reach support directly when you need help.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 14),
          Text(
            'Support uses your current account, plan, and setup context automatically so questions can be handled with the right client details already in view.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 22),
          _SupportCard(
            label: 'Account',
            value: accountName,
          ),
          const SizedBox(height: 12),
          _SupportCard(
            label: 'Signed in as',
            value: session.email.isNotEmpty ? session.email : 'Client account',
          ),
          const SizedBox(height: 12),
          const _SupportCard(
            label: 'Use this space for',
            value:
                'Setup guidance, plan questions, billing support, workflow issues, and execution clarity.',
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
            child: const Text('Open support conversation'),
          ),
        ],
      ),
    );
  }
}

class _SupportThread extends StatelessWidget {
  const _SupportThread({
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
            'Start with what you need',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          Text(
            'We’ll respond immediately or guide it into follow-up if needed.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 24),
          IntakeCard(
            publicMode: false,
            isLoading: controller.session.isLoading,
            initialValue: draft,
            onChanged: onDraftChanged,
            onSubmit: (message, name, email) async {
              onDraftChanged('');
              await controller.sendMessage(message: message);
            },
          ),
          const SizedBox(height: 18),
          ResponseStream(
            messages: controller.session.messages,
            isLoading: controller.session.isLoading,
            onFollowUpTap: (value) => controller.sendMessage(message: value),
          ),
          const SizedBox(height: 18),
          const SupportFooter(showStripe: true),
        ],
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.publicMuted,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _ClientSupportDrawer extends StatefulWidget {
  const _ClientSupportDrawer({required this.controller});

  final SupportController controller;

  @override
  State<_ClientSupportDrawer> createState() => _ClientSupportDrawerState();
}

class _ClientSupportDrawerState extends State<_ClientSupportDrawer> {
  String _draft = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant _ClientSupportDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          child: SizedBox(
            width: 460,
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
                    'Continue the same support conversation without leaving this page.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  IntakeCard(
                    publicMode: false,
                    isLoading: widget.controller.session.isLoading,
                    initialValue: _draft,
                    onChanged: (value) => setState(() => _draft = value),
                    onSubmit: (message, name, email) async {
                      setState(() => _draft = '');
                      await widget.controller.sendMessage(message: message);
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: ResponseStream(
                        messages: widget.controller.session.messages,
                        isLoading: widget.controller.session.isLoading,
                        onFollowUpTap: (value) =>
                            widget.controller.sendMessage(message: value),
                      ),
                    ),
                  ),
                  const SupportFooter(showStripe: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}