import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/theme/ob.dart';
import 'package:orchestrate_app/core/ui/ob_widgets.dart';

/// WHERE A PROVIDER'S SIGN-IN COMES BACK TO (DD-27).
///
/// The backend redirects here after Google or Microsoft with safe query
/// parameters (`status`, `provider`, `reason`, `email`). A mailbox connection
/// belongs to setup's email step, which already reads `oauth` and `reason`
/// and shows the outcome in plain words, so the person is taken straight back
/// there. Google Contacts, which is not part of setup, gets one short card.
class OAuthReturnScreen extends StatefulWidget {
  const OAuthReturnScreen({
    super.key,
    required this.status,
    this.provider,
    this.reason,
    this.email,
    this.mailboxId,
  });

  /// `success` | `error` | empty when the page was opened directly.
  final String status;
  final String? provider;
  final String? reason;
  final String? email;
  final String? mailboxId;

  @override
  State<OAuthReturnScreen> createState() => _OAuthReturnScreenState();
}

class _OAuthReturnScreenState extends State<OAuthReturnScreen> {
  bool get _contacts => (widget.provider ?? '').toLowerCase() == 'google_contacts';
  bool get _ok => widget.status.toLowerCase() == 'success';

  @override
  void initState() {
    super.initState();
    if (!_contacts) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final q = <String, String>{
          'step': 'email',
          'oauth': _ok ? 'success' : 'error',
          if ((widget.reason ?? '').isNotEmpty) 'reason': widget.reason!,
        };
        context.go(Uri(path: '/client/setup', queryParameters: q).toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_contacts) {
      return const Center(child: CircularProgressIndicator(color: Ob.ink, strokeWidth: 2));
    }
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ObCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ObHeadline(
                  _ok ? 'Google Contacts is connected.' : 'Google Contacts did not connect.',
                  size: 30),
              const SizedBox(height: 10),
              Text(
                  _ok
                      ? 'Orchestrate can now read your contact list to know who you '
                          'already work with. It never writes to it.'
                      : 'Nothing was saved. You can try again from Customers.',
                  style: Ob.body(16)),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.go('/client/relationships'),
                child: const Text('Go to Customers'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
