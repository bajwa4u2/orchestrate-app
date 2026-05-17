import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:orchestrate_app/data/repositories/client/client_mailbox_repository.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';

/// First-class SMTP / custom-transport onboarding dialog.
///
/// SMTP sits next to Google Workspace and Microsoft 365 in the
/// transport choices. The dialog gathers host + port + auth + from
/// address, validates against the upstream SMTP server before any
/// persistence, then completes the connect by POSTing to
/// /v1/client/mailbox/smtp/connect. The dialog never logs or returns
/// the password; that field is wiped on close.
///
/// On successful save the dialog reveals the DKIM TXT record the
/// client must publish at their registrar. Copy buttons let them paste
/// the values straight in.
class SmtpConnectDialog extends StatefulWidget {
  const SmtpConnectDialog({super.key, this.initialFromAddress});

  /// Pre-fills the From address — typically the inferred sending
  /// domain or the user's email address.
  final String? initialFromAddress;

  /// Convenience launcher. Returns true if the dialog persisted a
  /// connection so callers can refresh their state.
  static Future<bool> show(
    BuildContext context, {
    String? initialFromAddress,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          SmtpConnectDialog(initialFromAddress: initialFromAddress),
    );
    return saved == true;
  }

  @override
  State<SmtpConnectDialog> createState() => _SmtpConnectDialogState();
}

class _SmtpConnectDialogState extends State<SmtpConnectDialog> {
  final ClientMailboxRepository _repository = ClientMailboxRepository();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _fromAddress;
  late final TextEditingController _fromName;
  late final TextEditingController _replyTo;
  String _secure = 'starttls';
  bool _testing = false;
  bool _saving = false;
  String? _errorMessage;
  String? _testOkMessage;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _host = TextEditingController();
    _port = TextEditingController(text: '587');
    _username = TextEditingController();
    _password = TextEditingController();
    _fromAddress = TextEditingController(text: widget.initialFromAddress ?? '');
    _fromName = TextEditingController();
    _replyTo = TextEditingController();
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _username.dispose();
    _password.clear();
    _password.dispose();
    _fromAddress.dispose();
    _fromName.dispose();
    _replyTo.dispose();
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
      await _repository.testSmtpConnection(
        host: _host.text.trim(),
        port: _portValue,
        secure: _secure,
        username: _username.text.trim(),
        password: _password.text,
        fromAddress: _fromAddress.text.trim(),
        fromName: _fromName.text,
        replyTo: _replyTo.text,
      );
      if (!mounted) return;
      setState(() => _testOkMessage =
          'SMTP server accepted the credentials. Save to persist.');
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
      final result = await _repository.connectSmtpMailbox(
        host: _host.text.trim(),
        port: _portValue,
        secure: _secure,
        username: _username.text.trim(),
        password: _password.text,
        fromAddress: _fromAddress.text.trim(),
        fromName: _fromName.text,
        replyTo: _replyTo.text,
      );
      if (!mounted) return;
      // Clear the password from controller state once persistence
      // succeeds. The vault has the only copy.
      _password.clear();
      setState(() => _result = result);
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
    final saved = _result != null;
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
              child: saved ? _buildSuccess(theme) : _buildForm(theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connect a custom SMTP transport',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Use any SMTP-capable infrastructure — your own mail server, SES, '
          'Mailgun, SendGrid, Postfix, Zoho, or a regional provider. '
          'Orchestrate verifies the credentials against the SMTP host '
          'before saving and generates a DKIM keypair scoped to your '
          'sending domain.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        _row([
          _field(
            controller: _host,
            label: 'SMTP host',
            hint: 'e.g. smtp.gmail.com',
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Host is required' : null,
          ),
          _field(
            controller: _port,
            label: 'Port',
            hint: '587',
            keyboardType: TextInputType.number,
            validator: (v) {
              final n = int.tryParse((v ?? '').trim());
              return (n == null || n < 1 || n > 65535)
                  ? 'Port must be 1–65535'
                  : null;
            },
          ),
        ]),
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
                value: 'starttls', child: Text('STARTTLS (typically port 587)')),
            DropdownMenuItem(
                value: 'tls', child: Text('Implicit TLS / SMTPS (typically port 465)')),
            DropdownMenuItem(
                value: 'none', child: Text('Plain (internal relays only)')),
          ],
          onChanged: _testing || _saving
              ? null
              : (value) => setState(() => _secure = value ?? 'starttls'),
        ),
        const SizedBox(height: 12),
        _row([
          _field(
            controller: _username,
            label: 'SMTP username',
            hint: 'Often the from-address or a relay-issued account',
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Username is required' : null,
          ),
          _field(
            controller: _password,
            label: 'SMTP password / app password',
            obscure: true,
            validator: (v) => (v ?? '').isEmpty ? 'Password is required' : null,
          ),
        ]),
        const SizedBox(height: 12),
        _row([
          _field(
            controller: _fromAddress,
            label: 'From address',
            hint: 'sales@yourdomain.com',
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return 'From address is required';
              if (!s.contains('@')) return 'Must be a valid address';
              return null;
            },
          ),
          _field(
            controller: _fromName,
            label: 'From name (optional)',
            hint: 'Yourself or your business',
            validator: (_) => null,
          ),
        ]),
        const SizedBox(height: 12),
        _field(
          controller: _replyTo,
          label: 'Reply-to (optional)',
          hint: 'Defaults to the from-address',
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
        Text(
          'Reply monitoring via IMAP is not part of this connect flow — outbound '
          'dispatch is fully supported, and inbound webhook integration is the '
          'documented path for replies on SMTP transports today.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
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
                  : const Icon(Icons.lock, size: 18),
              label: Text(_saving ? 'Saving' : 'Save and connect'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuccess(ThemeData theme) {
    final dkim = (_result?['dkim'] as Map?) ?? const {};
    final selector = (dkim['selector'] ?? '').toString();
    final domain = (dkim['domain'] ?? '').toString();
    final txt = (dkim['txtRecord'] ?? '').toString();
    final host = selector.isNotEmpty && domain.isNotEmpty
        ? '$selector._domainkey.$domain'
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SMTP transport connected',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Credentials are vaulted. Orchestrate generated a DKIM keypair '
          'for this transport — publish the TXT record below at your DNS '
          'provider so dispatch trust can verify.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        _DkimRow(label: 'TXT host', value: host),
        const SizedBox(height: 12),
        _DkimRow(label: 'TXT value', value: txt, longValue: true),
        const SizedBox(height: 12),
        Text(
          'SPF and DMARC records are listed on the Sending domain panel. '
          'Once all three records propagate, the trust classification '
          'flips to full-trust and dispatch eligibility unlocks at scale.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Done'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _row(List<Widget> children) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          Expanded(child: children[i]),
          if (i < children.length - 1) const SizedBox(width: 12),
        ],
      ],
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

class _DkimRow extends StatefulWidget {
  const _DkimRow({required this.label, required this.value, this.longValue = false});
  final String label;
  final String value;
  final bool longValue;

  @override
  State<_DkimRow> createState() => _DkimRowState();
}

class _DkimRowState extends State<_DkimRow> {
  bool _copied = false;
  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClientInfoRow(
      title: widget.label,
      primary: widget.value.isEmpty ? '—' : widget.value,
      trailing: widget.value.isEmpty
          ? null
          : TextButton.icon(
              onPressed: _copy,
              icon: Icon(_copied ? Icons.check : Icons.copy, size: 16),
              label: Text(_copied ? 'Copied' : 'Copy'),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: const Size(0, 32),
              ),
            ),
    );
  }
}
