import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/network/api_client.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/client/client_account_repository.dart';

/// WHAT A PERSON DOES WITH THEIR OWN ACCOUNT (DD-34).
///
/// These lived on the old "Your account" page, the only place a person could
/// delete their account, which the app stores require to be reachable inside
/// the app. They now sit on Account & security, where the question is asked;
/// the old page is retired.

/// Changes the name this person signs with. Returns true when saved.
Future<bool> showOwnNameEditor(BuildContext context) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => const _OwnNameDialog(),
  );
  return saved == true;
}

Future<void> showDeactivateAccount(BuildContext context) async {
  final done = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ConfirmLeaveDialog(
      title: 'Deactivate account',
      explanation: 'This closes your access to this workspace. Your business\'s '
          'records are kept.',
      word: 'DEACTIVATE',
      action: 'Deactivate',
      danger: false,
      askReason: true,
      run: (repo, reason, typed) =>
          repo.deactivateClientAccount(reason: reason, confirmationText: typed),
      failure: 'The account could not be deactivated just now. Please try again.',
    ),
  );
  if (done == true && context.mounted) {
    await AuthSessionController.instance.clear();
    if (context.mounted) context.go('/auth/login');
  }
}

Future<void> showDeleteAccount(BuildContext context) async {
  final done = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ConfirmLeaveDialog(
      title: 'Delete account',
      explanation: 'This permanently deletes your sign-in and personal profile. '
          'It cannot be undone. Any active subscription is canceled and you '
          'will be signed out. Some records are kept after deletion: the '
          'business\'s workspace records, and the record of who authorized '
          'Orchestrate to act for the business or accepted an agreement, '
          'including that person\'s name and email. The Account deletion page '
          'lists what is kept.',
      word: 'DELETE',
      action: 'Delete account',
      danger: true,
      askReason: false,
      run: (repo, _, typed) => repo.deleteClientAccount(confirmationText: typed),
      failure: 'The account could not be deleted right now. Please try again.',
    ),
  );
  if (done == true && context.mounted) {
    await AuthSessionController.instance.clear();
    // Said on arrival, so an irreversible act does not end on a sign-in
    // screen indistinguishable from any other sign-out.
    if (context.mounted) context.go('/auth/login?deleted=1');
  }
}

class _ConfirmLeaveDialog extends StatefulWidget {
  const _ConfirmLeaveDialog({
    required this.title,
    required this.explanation,
    required this.word,
    required this.action,
    required this.danger,
    required this.askReason,
    required this.run,
    required this.failure,
  });

  final String title;
  final String explanation;
  final String word;
  final String action;
  final bool danger;
  final bool askReason;
  final Future<void> Function(ClientAccountRepository repo, String reason, String typed) run;
  final String failure;

  @override
  State<_ConfirmLeaveDialog> createState() => _ConfirmLeaveDialogState();
}

class _ConfirmLeaveDialogState extends State<_ConfirmLeaveDialog> {
  final _repo = ClientAccountRepository();
  final _reason = TextEditingController();
  final _typed = TextEditingController();
  bool _working = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    _typed.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_typed.text.trim().toUpperCase() != widget.word) {
      setState(() => _error = 'Type ${widget.word} to confirm.');
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await widget.run(_repo, _reason.text.trim(), _typed.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = widget.failure;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radius)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: text.headlineSmall),
              const SizedBox(height: 8),
              Text(widget.explanation,
                  style: text.bodyLarge?.copyWith(color: AppTheme.publicMuted)),
              if (widget.askReason) ...[
                const SizedBox(height: 18),
                TextField(
                  controller: _reason,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Reason (optional)'),
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: _typed,
                decoration: InputDecoration(labelText: 'Type ${widget.word} to confirm'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: text.bodyMedium?.copyWith(color: Colors.red.shade700)),
              ],
              const SizedBox(height: 22),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: _working ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  style: widget.danger
                      ? FilledButton.styleFrom(backgroundColor: Colors.red.shade700)
                      : null,
                  onPressed: _working ? null : _submit,
                  child: Text(_working ? 'Working…' : widget.action),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnNameDialog extends StatefulWidget {
  const _OwnNameDialog();

  @override
  State<_OwnNameDialog> createState() => _OwnNameDialogState();
}

class _OwnNameDialogState extends State<_OwnNameDialog> {
  final _repo = ClientAccountRepository();
  late final _name = TextEditingController(text: AuthSessionController.instance.fullName);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Add your name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repo.updateOwnName(name);
      // The session carries what every other surface reads; re-read it from
      // the server so one answer decides the name shown everywhere.
      await AuthSessionController.instance.applyAuthResponse(await _repo.fetchMe());
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _refusalText(error) ??
            'Your name could not be saved just now. Please try again.';
      });
    }
  }

  /// The server's own words for a refusal. 4xx only: a 5xx or a dropped
  /// connection has nothing worth quoting.
  String? _refusalText(Object error) {
    if (error is! ApiException) return null;
    if (error.statusCode < 400 || error.statusCode >= 500) return null;
    final message = error.message.trim();
    return message.isEmpty ? null : message;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Your name'),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: _name,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Your name',
            helperText: 'How every note sent for you is signed.',
            errorText: _error,
          ),
          onSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save')),
      ],
    );
  }
}
