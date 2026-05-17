import 'package:flutter/material.dart';

import 'package:orchestrate_app/data/repositories/client/client_mailbox_repository.dart';

/// IMAP inbound onboarding dialog. Attaches reply monitoring to an
/// existing SMTP mailbox (the custom transport pair is SMTP + IMAP).
///
/// Without IMAP attached, the SMTP custom transport runs outbound only
/// — the runtime says so explicitly. Once IMAP is attached, the poll
/// worker ingests replies, persists them as Reply rows, and suppresses
/// pending follow-ups against the same lead automatically.
class ImapConnectDialog extends StatefulWidget {
  const ImapConnectDialog({
    super.key,
    required this.mailboxId,
    this.initialUsername,
  });

  /// The SMTP-typed mailbox we are layering IMAP onto.
  final String mailboxId;

  /// Pre-fill the username — typically the same address used for SMTP.
  final String? initialUsername;

  static Future<bool> show(
    BuildContext context, {
    required String mailboxId,
    String? initialUsername,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ImapConnectDialog(
        mailboxId: mailboxId,
        initialUsername: initialUsername,
      ),
    );
    return saved == true;
  }

  @override
  State<ImapConnectDialog> createState() => _ImapConnectDialogState();
}

class _ImapConnectDialogState extends State<ImapConnectDialog> {
  final ClientMailboxRepository _repository = ClientMailboxRepository();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _folder;
  String _secure = 'tls';
  bool _testing = false;
  bool _saving = false;
  String? _errorMessage;
  String? _testOkMessage;

  @override
  void initState() {
    super.initState();
    _host = TextEditingController();
    _port = TextEditingController(text: '993');
    _username = TextEditingController(text: widget.initialUsername ?? '');
    _password = TextEditingController();
    _folder = TextEditingController(text: 'INBOX');
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _username.dispose();
    _password.clear();
    _password.dispose();
    _folder.dispose();
    super.dispose();
  }

  int get _portValue => int.tryParse(_port.text.trim()) ?? 0;

  Future<void> _runTest() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _testing = true;
      _errorMessage = null;
      _testOkMessage = null;
    });
    try {
      final result = await _repository.testImapConnection(
        host: _host.text.trim(),
        port: _portValue,
        secure: _secure,
        username: _username.text.trim(),
        password: _password.text,
        folder: _folder.text,
      );
      if (!mounted) return;
      setState(() => _testOkMessage =
          'IMAP server accepted the credentials. Folder ${result['folder'] ?? 'INBOX'} has ${result['messageCount'] ?? 0} message(s). Save to persist.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage =
          'Test failed: ${error.toString().replaceAll(RegExp(r'^Exception:\s*'), '')}');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
      _testOkMessage = null;
    });
    try {
      await _repository.connectImapMailbox(
        mailboxId: widget.mailboxId,
        host: _host.text.trim(),
        port: _portValue,
        secure: _secure,
        username: _username.text.trim(),
        password: _password.text,
        folder: _folder.text,
      );
      if (!mounted) return;
      _password.clear();
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage =
          'Connect failed: ${error.toString().replaceAll(RegExp(r'^Exception:\s*'), '')}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attach IMAP inbound monitoring',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Orchestrate polls the configured folder for new '
                    'messages, matches them to outbound sends by their '
                    'message-id headers, persists each match as a reply, '
                    'and cancels pending follow-ups against the same lead. '
                    'Credentials are sealed in the vault and never returned '
                    'to the browser.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Orchestrate only processes mail tied to its outbound '
                    'operations. Inbox messages without a Message-ID, '
                    'References, or X-Orchestrate-Operation-Id match are '
                    'not stored, classified, surfaced, or fed to AI. A '
                    'dedicated sending mailbox is recommended.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          controller: _host,
                          label: 'IMAP host',
                          hint: 'imap.gmail.com',
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'Host is required'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          controller: _port,
                          label: 'Port',
                          hint: '993',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final n = int.tryParse((v ?? '').trim());
                            return (n == null || n < 1 || n > 65535)
                                ? 'Port must be 1–65535'
                                : null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _secure,
                    decoration: const InputDecoration(
                      labelText: 'Encryption',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'tls',
                          child: Text('Implicit TLS (typically port 993)')),
                      DropdownMenuItem(
                          value: 'starttls',
                          child: Text('STARTTLS (typically port 143)')),
                      DropdownMenuItem(
                          value: 'none',
                          child: Text('Plain (internal relays only)')),
                    ],
                    onChanged: _testing || _saving
                        ? null
                        : (value) =>
                            setState(() => _secure = value ?? 'tls'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          controller: _username,
                          label: 'IMAP username',
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'Username is required'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          controller: _password,
                          label: 'IMAP password / app password',
                          obscure: true,
                          validator: (v) =>
                              (v ?? '').isEmpty ? 'Password is required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _folder,
                    label: 'Folder to monitor',
                    hint: 'INBOX',
                    validator: (_) => null,
                  ),
                  const SizedBox(height: 14),
                  if (_errorMessage != null) ...[
                    Text(
                      _errorMessage!,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.error),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_testOkMessage != null) ...[
                    Text(
                      _testOkMessage!,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _testing || _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _testing || _saving ? null : _runTest,
                        icon: _testing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi_tethering, size: 18),
                        label: Text(_testing ? 'Testing' : 'Test connection'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _testing || _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.inbox_outlined, size: 18),
                        label: Text(_saving ? 'Saving' : 'Attach IMAP inbound'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool obscure = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      enabled: !_testing && !_saving,
    );
  }
}
