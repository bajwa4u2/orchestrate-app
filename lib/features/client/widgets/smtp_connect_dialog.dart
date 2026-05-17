import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:orchestrate_app/data/repositories/client/client_mailbox_repository.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';

/// Combined custom mail transport onboarding dialog.
///
/// One guided flow that configures:
///   • Outbound sending via SMTP
///   • Inbound reply monitoring via IMAP
///
/// IMAP is part of the same flow — not a deferred future step. The
/// dialog gathers both blocks at once and POSTs them together to
/// /v1/client/mailbox/custom-transport/connect, so a paying client
/// never lands in an inconsistent half-configured state. Inbound can
/// be explicitly skipped (the dialog calls this "outbound-only mode")
/// but it is a conscious operator choice, not a hidden default.
///
/// On success the dialog reveals the DKIM TXT record the client must
/// publish at their registrar; copy buttons paste the values directly.
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

  // Outbound SMTP
  late final TextEditingController _smtpHost;
  late final TextEditingController _smtpPort;
  late final TextEditingController _smtpUsername;
  late final TextEditingController _smtpPassword;
  late final TextEditingController _fromAddress;
  late final TextEditingController _fromName;
  late final TextEditingController _replyTo;
  String _smtpSecure = 'starttls';

  // Inbound IMAP
  bool _attachInbound = true;
  late final TextEditingController _imapHost;
  late final TextEditingController _imapPort;
  late final TextEditingController _imapUsername;
  late final TextEditingController _imapPassword;
  late final TextEditingController _imapFolder;
  String _imapSecure = 'tls';
  /// When true, the IMAP username field mirrors the SMTP username.
  /// Most relays use the same auth pair for both protocols.
  bool _imapMirrorsSmtpAuth = true;

  bool _testing = false;
  bool _saving = false;
  String? _errorMessage;
  String? _testOkMessage;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _smtpHost = TextEditingController();
    _smtpPort = TextEditingController(text: '587');
    _smtpUsername = TextEditingController();
    _smtpPassword = TextEditingController();
    _fromAddress = TextEditingController(text: widget.initialFromAddress ?? '');
    _fromName = TextEditingController();
    _replyTo = TextEditingController();
    _imapHost = TextEditingController();
    _imapPort = TextEditingController(text: '993');
    _imapUsername = TextEditingController();
    _imapPassword = TextEditingController();
    _imapFolder = TextEditingController(text: 'INBOX');
  }

  @override
  void dispose() {
    _smtpHost.dispose();
    _smtpPort.dispose();
    _smtpUsername.dispose();
    _smtpPassword.clear();
    _smtpPassword.dispose();
    _fromAddress.dispose();
    _fromName.dispose();
    _replyTo.dispose();
    _imapHost.dispose();
    _imapPort.dispose();
    _imapUsername.dispose();
    _imapPassword.clear();
    _imapPassword.dispose();
    _imapFolder.dispose();
    super.dispose();
  }

  int get _smtpPortValue => int.tryParse(_smtpPort.text.trim()) ?? 0;
  int get _imapPortValue => int.tryParse(_imapPort.text.trim()) ?? 0;

  String get _effectiveImapUsername =>
      _imapMirrorsSmtpAuth ? _smtpUsername.text.trim() : _imapUsername.text.trim();
  String get _effectiveImapPassword =>
      _imapMirrorsSmtpAuth ? _smtpPassword.text : _imapPassword.text;

  Map<String, dynamic> _smtpPayload() => <String, dynamic>{
        'host': _smtpHost.text.trim(),
        'port': _smtpPortValue,
        'secure': _smtpSecure,
        'username': _smtpUsername.text.trim(),
        'password': _smtpPassword.text,
        'fromAddress': _fromAddress.text.trim(),
        if (_fromName.text.trim().isNotEmpty) 'fromName': _fromName.text.trim(),
        if (_replyTo.text.trim().isNotEmpty) 'replyTo': _replyTo.text.trim(),
      };

  Map<String, dynamic>? _imapPayload() {
    if (!_attachInbound) return null;
    return <String, dynamic>{
      'host': _imapHost.text.trim(),
      'port': _imapPortValue,
      'secure': _imapSecure,
      'username': _effectiveImapUsername,
      'password': _effectiveImapPassword,
      if (_imapFolder.text.trim().isNotEmpty) 'folder': _imapFolder.text.trim(),
    };
  }

  Future<void> _runTest() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _testing = true;
      _errorMessage = null;
      _testOkMessage = null;
    });
    try {
      // Test SMTP first; abort before touching IMAP if it fails.
      await _repository.testSmtpConnection(
        host: _smtpHost.text.trim(),
        port: _smtpPortValue,
        secure: _smtpSecure,
        username: _smtpUsername.text.trim(),
        password: _smtpPassword.text,
        fromAddress: _fromAddress.text.trim(),
        fromName: _fromName.text,
        replyTo: _replyTo.text,
      );
      String message =
          'Outbound SMTP server accepted the credentials.';
      if (_attachInbound) {
        final imap = await _repository.testImapConnection(
          host: _imapHost.text.trim(),
          port: _imapPortValue,
          secure: _imapSecure,
          username: _effectiveImapUsername,
          password: _effectiveImapPassword,
          folder: _imapFolder.text.trim(),
        );
        final folder = imap['folder'] ?? 'INBOX';
        final count = imap['messageCount'] ?? 0;
        message =
            'Outbound SMTP accepted; inbound IMAP accepted (folder $folder, $count message(s) currently visible). Save to persist.';
      } else {
        message =
            '$message Inbound monitoring is not part of this setup — outbound-only mode confirmed.';
      }
      if (!mounted) return;
      setState(() => _testOkMessage = message);
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
      final result = await _repository.connectCustomTransport(
        smtp: _smtpPayload(),
        imap: _imapPayload(),
      );
      if (!mounted) return;
      _smtpPassword.clear();
      _imapPassword.clear();
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
        constraints: const BoxConstraints(maxWidth: 760),
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
          'Connect custom mail transport',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Use any SMTP-capable infrastructure (your own server, SES, '
          'Mailgun, SendGrid, Postfix, Zoho, a regional provider). One '
          'guided setup configures outbound dispatch via SMTP and '
          'inbound reply monitoring via IMAP. Credentials are sealed in '
          'the vault and never returned to the browser.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Orchestrate only processes mail tied to its outbound '
          'operations. Inbox messages without a Message-ID, References, '
          'or X-Orchestrate-Operation-Id match are not stored, '
          'classified, surfaced, or fed to AI. Inbox is header-inspected '
          'first; bodies are fetched only for matched operations.',
          style: theme.textTheme.bodySmall
              ?.copyWith(fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 20),
        _sectionHeader(theme, 'Outbound sending (SMTP)'),
        const SizedBox(height: 12),
        _row([
          _field(
            controller: _smtpHost,
            label: 'SMTP host',
            hint: 'e.g. smtp.gmail.com',
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Host is required' : null,
          ),
          _field(
            controller: _smtpPort,
            label: 'Port',
            hint: '587',
            keyboardType: TextInputType.number,
            validator: _portValidator,
          ),
        ]),
        const SizedBox(height: 12),
        _secureDropdown(
          value: _smtpSecure,
          onChanged: _testing || _saving
              ? null
              : (value) => setState(() => _smtpSecure = value ?? 'starttls'),
          starttlsHint: 'STARTTLS (typically port 587)',
          tlsHint: 'Implicit TLS / SMTPS (typically port 465)',
        ),
        const SizedBox(height: 12),
        _row([
          _field(
            controller: _smtpUsername,
            label: 'SMTP username',
            hint: 'Often the from-address or a relay-issued account',
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Username is required' : null,
          ),
          _field(
            controller: _smtpPassword,
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
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _sectionHeader(theme, 'Inbound reply monitoring (IMAP)'),
            ),
            Switch.adaptive(
              value: _attachInbound,
              onChanged: _testing || _saving
                  ? null
                  : (value) => setState(() => _attachInbound = value),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _attachInbound
              ? 'Replies arriving in the configured folder are matched to '
                  'Orchestrate-managed outbound and ingested into the '
                  'Replies workspace. Follow-ups against the same lead '
                  'are suppressed automatically.'
              : 'Outbound-only mode. Reply continuity will not be wired — '
                  'replies arriving in the mailbox will not be ingested or '
                  'auto-suppressed. You can attach IMAP later from '
                  'Infrastructure.',
          style: theme.textTheme.bodySmall,
        ),
        if (_attachInbound) ...[
          const SizedBox(height: 14),
          CheckboxListTile(
            value: _imapMirrorsSmtpAuth,
            onChanged: _testing || _saving
                ? null
                : (value) =>
                    setState(() => _imapMirrorsSmtpAuth = value ?? true),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Use the same auth as SMTP'),
            subtitle: const Text(
              'Most relays accept the same username + password on IMAP. '
              'Uncheck if your provider uses a separate IMAP account.',
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          _row([
            _field(
              controller: _imapHost,
              label: 'IMAP host',
              hint: 'e.g. imap.gmail.com',
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Host is required' : null,
            ),
            _field(
              controller: _imapPort,
              label: 'Port',
              hint: '993',
              keyboardType: TextInputType.number,
              validator: _portValidator,
            ),
          ]),
          const SizedBox(height: 12),
          _secureDropdown(
            value: _imapSecure,
            onChanged: _testing || _saving
                ? null
                : (value) => setState(() => _imapSecure = value ?? 'tls'),
            starttlsHint: 'STARTTLS (typically port 143)',
            tlsHint: 'Implicit TLS (typically port 993)',
          ),
          if (!_imapMirrorsSmtpAuth) ...[
            const SizedBox(height: 12),
            _row([
              _field(
                controller: _imapUsername,
                label: 'IMAP username',
                validator: (v) => (v ?? '').trim().isEmpty
                    ? 'Username is required'
                    : null,
              ),
              _field(
                controller: _imapPassword,
                label: 'IMAP password',
                obscure: true,
                validator: (v) =>
                    (v ?? '').isEmpty ? 'Password is required' : null,
              ),
            ]),
          ],
          const SizedBox(height: 12),
          _field(
            controller: _imapFolder,
            label: 'Folder to monitor',
            hint: 'INBOX',
            validator: (_) => null,
          ),
        ],
        const SizedBox(height: 16),
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
        const SizedBox(height: 4),
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
    final inbound = (_result?['inbound'] as Map?) ?? const {};
    final inboundKind = (inbound['kind'] ?? '').toString();
    final folder = (inbound['folder'] ?? '').toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Custom mail transport connected',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Credentials are vaulted. Orchestrate generated a DKIM keypair '
          'for the outbound transport — publish the TXT record below at '
          'your DNS provider so dispatch trust can verify.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        _DkimRow(label: 'TXT host', value: host),
        const SizedBox(height: 12),
        _DkimRow(label: 'TXT value', value: txt, longValue: true),
        const SizedBox(height: 18),
        Text(
          inboundKind == 'imap_attached'
              ? 'Inbound reply monitoring is active on folder '
                  '${folder.isNotEmpty ? folder : 'INBOX'}. Replies are '
                  'matched only to Orchestrate-managed outbound; '
                  'unrelated mailbox content is not stored or processed.'
              : 'Outbound-only mode. You can attach IMAP inbound later '
                  'from Infrastructure to enable reply continuity.',
          style: theme.textTheme.bodyMedium,
        ),
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

  Widget _sectionHeader(ThemeData theme, String text) {
    return Text(
      text,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _secureDropdown({
    required String value,
    required ValueChanged<String?>? onChanged,
    required String starttlsHint,
    required String tlsHint,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: const InputDecoration(
        labelText: 'Encryption',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        DropdownMenuItem(value: 'starttls', child: Text(starttlsHint)),
        DropdownMenuItem(value: 'tls', child: Text(tlsHint)),
        const DropdownMenuItem(
            value: 'none', child: Text('Plain (internal relays only)')),
      ],
      onChanged: onChanged,
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

  String? _portValidator(String? value) {
    final n = int.tryParse((value ?? '').trim());
    return (n == null || n < 1 || n > 65535) ? 'Port must be 1–65535' : null;
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
