import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:orchestrate_app/core/network/api_client.dart';
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
  /// Provider catalog from /v1/client/mailbox/smtp/providers/catalog.
  /// Drives the chooser at the top of the dialog. Null until loaded;
  /// empty list when the endpoint returns no providers.
  List<Map<String, dynamic>>? _catalog;
  /// Currently-selected provider key from the chooser ('zoho',
  /// 'generic', 'google', 'microsoft', or null when no choice made
  /// yet).
  String? _providerKey;
  /// Structured diagnostic returned by the backend SMTP probe when
  /// the test connection fails. Populated from the response's
  /// `diagnostic` block; null when no test has been run or the most
  /// recent test passed.
  Map<String, dynamic>? _smtpDiagnostic;
  /// Per-candidate attempt summary the backend returns from the
  /// verify-with-candidates path. Each entry names the endpoint
  /// tried, whether it succeeded, and the failure stage on failure.
  List<Map<String, dynamic>>? _smtpAttempts;
  /// Provider key the backend detected from the host
  /// (zoho / google / microsoft / custom).
  String? _smtpProvider;
  /// Winning endpoint when the candidate retry loop converged on a
  /// host different from the user's input.
  Map<String, dynamic>? _smtpWinning;

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
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final catalog = await _repository.fetchProviderCatalog();
      // Filter to credentialType=smtp_imap — the chooser entries the
      // SMTP dialog can act on. OAuth providers (Google / Microsoft)
      // are connected via separate flows; we list them in the chooser
      // as informational entries that route the user out of this
      // dialog.
      if (!mounted) return;
      setState(() => _catalog = catalog);
    } catch (_) {
      // Catalog is non-essential — the dialog still works without
      // it (legacy free-form mode).
      if (!mounted) return;
      setState(() => _catalog = const <Map<String, dynamic>>[]);
    }
  }

  void _applyCatalogChoice(Map<String, dynamic> entry) {
    final key = (entry['key'] ?? '').toString();
    final credentialType = (entry['credentialType'] ?? '').toString();
    if (credentialType != 'smtp_imap') {
      // Selected an OAuth provider — close the dialog with a hint;
      // the caller routes to the OAuth screen.
      setState(() {
        _errorMessage =
            'For ${entry['displayName']}, use the OAuth connect action on the main Infrastructure screen (Connect Google / Microsoft).';
      });
      return;
    }
    final defaultHost = (entry['defaultHost'] ?? '').toString();
    final defaultPort = entry['defaultPort'];
    final defaultEncryption = (entry['defaultEncryption'] ?? '').toString();
    setState(() {
      _providerKey = key;
      _errorMessage = null;
      _testOkMessage = null;
      _smtpDiagnostic = null;
      _smtpAttempts = null;
      _smtpWinning = null;
      if (defaultHost.isNotEmpty) {
        _smtpHost.text = defaultHost;
      }
      if (defaultPort is num) {
        _smtpPort.text = defaultPort.toInt().toString();
      }
      if (defaultEncryption.isNotEmpty) {
        _smtpSecure = defaultEncryption;
      }
      // For Zoho IMAP, pre-fill the standard implicit-TLS endpoint.
      if (key == 'zoho') {
        _imapHost.text = 'imappro.zoho.com';
        _imapPort.text = '993';
        _imapSecure = 'tls';
      }
    });
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
        if (_providerKey != null) 'providerOverride': _providerKey,
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
      _smtpDiagnostic = null;
      _smtpAttempts = null;
      _smtpProvider = null;
      _smtpWinning = null;
    });
    try {
      // Test SMTP first; abort before touching IMAP if it fails.
      final smtpResult = await _repository.testSmtpConnection(
        host: _smtpHost.text.trim(),
        port: _smtpPortValue,
        secure: _smtpSecure,
        username: _smtpUsername.text.trim(),
        password: _smtpPassword.text,
        fromAddress: _fromAddress.text.trim(),
        fromName: _fromName.text,
        replyTo: _replyTo.text,
        providerOverride: _providerKey,
      );
      // The backend SMTP probe returns a 200 with either
      // `{ ok: true, ... }` on success or
      // `{ ok: false, diagnostic: {...} }` on failure. We render
      // the diagnostic inline so the user sees the exact failure
      // stage rather than a generic "Connection timeout."
      // Always pull attempts + provider out so the user sees what
      // we tried, even on success.
      final attemptsRaw = smtpResult['attempts'];
      final attempts = attemptsRaw is List
          ? attemptsRaw
              .whereType<Map>()
              .map((m) => m.map((k, v) => MapEntry('$k', v)))
              .toList()
          : <Map<String, dynamic>>[];
      final provider = (smtpResult['provider'] ?? '').toString();
      if (smtpResult['ok'] != true) {
        // Build the diagnostic from TOP-LEVEL AGGREGATE fields
        // (aggregateStage / aggregateFailureClass / aggregateMessage).
        // The per-candidate `diagnostic` legacy field is still
        // accepted as a fallback for older backend responses.
        final aggregateStage =
            (smtpResult['aggregateStage'] ?? '').toString();
        final aggregateFailureClass =
            (smtpResult['aggregateFailureClass'] ?? '').toString();
        final aggregateMessage =
            (smtpResult['aggregateMessage'] ?? '').toString();
        final nextAction = (smtpResult['nextAction'] ?? '').toString();
        final correlationId =
            (smtpResult['correlationId'] ?? '').toString();
        final legacyDiagnostic = smtpResult['diagnostic'];
        final legacyDiagMap = legacyDiagnostic is Map
            ? legacyDiagnostic.map((k, v) => MapEntry('$k', v))
            : <String, dynamic>{};
        final fallbackHints = legacyDiagMap['fallbackHints'] ?? const <String>[];
        if (!mounted) return;
        setState(() {
          _smtpDiagnostic = <String, dynamic>{
            // Prefer aggregate stage; fall back to legacy
            // failureStage only if backend did not supply
            // aggregate. Either way, this is NEVER an empty
            // string — that was the "unknown stage" bug.
            'stage': aggregateStage.isNotEmpty
                ? aggregateStage
                : (legacyDiagMap['failureStage'] ?? '').toString(),
            'failureClass': aggregateFailureClass.isNotEmpty
                ? aggregateFailureClass
                : (legacyDiagMap['failureCode'] ?? '').toString(),
            'message': aggregateMessage.isNotEmpty
                ? aggregateMessage
                : (legacyDiagMap['failureMessage'] ?? '').toString(),
            'nextAction': nextAction,
            'host': (legacyDiagMap['host'] ?? '').toString(),
            'port': legacyDiagMap['port'],
            'encryption': (legacyDiagMap['encryption'] ?? '').toString(),
            'providerHint':
                (legacyDiagMap['providerHint'] ?? '').toString(),
            'fallbackHints': fallbackHints,
            'correlationId': correlationId,
          };
          _smtpAttempts = attempts;
          _smtpProvider = provider.isEmpty ? null : provider;
          _errorMessage = aggregateMessage.isNotEmpty
              ? aggregateMessage
              : 'The transport test could not complete.';
        });
        return;
      }
      // Candidate retry succeeded — capture the winning endpoint so
      // the user knows which host/port the backend converged on.
      final winningHost = (smtpResult['host'] ?? '').toString();
      final winningPort = smtpResult['port'];
      final winningEnc = (smtpResult['encryption'] ?? '').toString();
      String message =
          'Outbound SMTP accepted via $winningHost:$winningPort ($winningEnc).';
      setState(() {
        _smtpAttempts = attempts;
        _smtpProvider = provider.isEmpty ? null : provider;
        _smtpWinning = <String, dynamic>{
          'host': winningHost,
          'port': winningPort,
          'encryption': winningEnc,
        };
        // Sync the form to the winning endpoint so Save reuses it.
        if (winningHost.isNotEmpty &&
            (winningHost != _smtpHost.text.trim() ||
                winningPort.toString() != _smtpPort.text.trim() ||
                winningEnc != _smtpSecure)) {
          _smtpHost.text = winningHost;
          if (winningPort is num) _smtpPort.text = winningPort.toInt().toString();
          if (winningEnc.isNotEmpty) _smtpSecure = winningEnc;
        }
      });
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
      // CRITICAL: never leak raw exception text. Map known failure
      // shapes into operational copy keyed by failure class so the
      // user sees an actionable next step, not a Dart stack trace.
      final mapped = _mapTransportError(error);
      setState(() {
        _smtpDiagnostic = mapped.diagnosticPayload;
        _errorMessage = mapped.userMessage;
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  /// Convert any exception thrown by the SMTP / IMAP / save calls
  /// into a structured `{userMessage, diagnosticPayload}` shape so
  /// the dialog can render safe operational copy. The mapping
  /// covers:
  ///   - TimeoutException   → orchestration_timeout
  ///   - ApiException 4xx   → structured backend body if present,
  ///                          else server-side classified failure
  ///   - ApiException 5xx   → save/orchestration failure
  ///   - generic Exception  → unknown class, render-safe text
  _MappedTransportError _mapTransportError(Object error) {
    if (error is TimeoutException) {
      return _MappedTransportError(
        userMessage:
            'The test did not complete in time. The deployment runtime may be slow to reach the provider. Retry — if this persists, it is likely a runtime network reachability issue, not a credential problem.',
        diagnosticPayload: <String, dynamic>{
          'failureStage': 'orchestration_timeout',
          'failureCode': 'EORCH_TIMEOUT_FE',
          'failureMessage':
              'HTTP request to the transport-test endpoint did not complete before the client cap.',
          'host': _smtpHost.text.trim(),
          'port': _smtpPortValue,
          'encryption': _smtpSecure,
          'providerHint': _providerKey ?? 'custom',
          'fallbackHints': const <String>[],
          'retrySuggestion':
              'Retry the test. If it consistently times out, the runtime likely cannot reach this provider — try a different transport or contact support.',
          'correlationId': '',
        },
      );
    }
    if (error is ApiException) {
      // Body may already be a structured diagnostic from the backend.
      // Surface it verbatim so failureClass guidance renders.
      final structured = _parseStructuredError(error.body);
      if (structured != null) {
        return _MappedTransportError(
          userMessage: structured.userMessage,
          diagnosticPayload: structured.diagnostic,
        );
      }
      return _MappedTransportError(
        userMessage:
            'The transport test could not complete (${error.statusCode}). Retry; if persistent, capture the request reference and contact support.',
        diagnosticPayload: <String, dynamic>{
          'failureStage': 'unknown',
          'failureCode': 'EHTTP_${error.statusCode}',
          'failureMessage': error.displayMessage,
          'host': _smtpHost.text.trim(),
          'port': _smtpPortValue,
          'encryption': _smtpSecure,
          'providerHint': _providerKey ?? 'custom',
          'fallbackHints': const <String>[],
          'retrySuggestion': 'Retry, then contact support if persistent.',
          'correlationId': error.correlationId ?? '',
        },
      );
    }
    return _MappedTransportError(
      userMessage:
          'The transport test ran into an unexpected error. Retry; if persistent, capture the request reference and contact support.',
      diagnosticPayload: <String, dynamic>{
        'failureStage': 'unknown',
        'failureCode': 'EUNKNOWN_FE',
        'failureMessage': '',
        'host': _smtpHost.text.trim(),
        'port': _smtpPortValue,
        'encryption': _smtpSecure,
        'providerHint': _providerKey ?? 'custom',
        'fallbackHints': const <String>[],
        'retrySuggestion': 'Retry, then contact support if persistent.',
        'correlationId': '',
      },
    );
  }

  void _applyFallback({
    required String host,
    required int port,
    required String secure,
  }) {
    setState(() {
      _smtpHost.text = host;
      _smtpPort.text = port.toString();
      _smtpSecure = secure;
      _smtpDiagnostic = null;
      _errorMessage = null;
      _testOkMessage = null;
    });
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
      final mapped = _mapTransportError(error);
      setState(() {
        _smtpDiagnostic = mapped.diagnosticPayload;
        _errorMessage = mapped.userMessage;
      });
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
        const SizedBox(height: 16),
        _ProviderChooser(
          catalog: _catalog,
          selectedKey: _providerKey,
          onChoose: _applyCatalogChoice,
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
        if (_smtpAttempts != null && _smtpAttempts!.isNotEmpty) ...[
          _SmtpAttemptsPanel(
            attempts: _smtpAttempts!,
            provider: _smtpProvider,
            winning: _smtpWinning,
          ),
          const SizedBox(height: 12),
        ],
        if (_smtpDiagnostic != null) ...[
          _SmtpDiagnosticPanel(
            diagnostic: _smtpDiagnostic!,
            onApplyFallback: _applyFallback,
          ),
          const SizedBox(height: 12),
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

/// Renders the structured SMTP diagnostic the backend probe returns
/// when the test connection fails. Shows the exact failure stage,
/// fallback host suggestions (one-click apply), and a retry hint.
/// No credentials are ever part of the diagnostic payload.
class _SmtpDiagnosticPanel extends StatelessWidget {
  const _SmtpDiagnosticPanel({
    required this.diagnostic,
    required this.onApplyFallback,
  });

  final Map<String, dynamic> diagnostic;
  final void Function({
    required String host,
    required int port,
    required String secure,
  }) onApplyFallback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // New contract: read `stage` (aggregate) first, fall back to
    // legacy `failureStage` only for backwards compatibility. The
    // panel NEVER renders "unknown stage" — when stage is missing
    // we render a different headline entirely.
    final stage = (diagnostic['stage'] ??
            diagnostic['failureStage'] ??
            '')
        .toString();
    final failureClass = (diagnostic['failureClass'] ?? '').toString();
    final code = (diagnostic['failureCode'] ?? failureClass).toString();
    final message = (diagnostic['message'] ??
            diagnostic['failureMessage'] ??
            '')
        .toString();
    final host = (diagnostic['host'] ?? '').toString();
    final port = diagnostic['port'];
    final encryption = (diagnostic['encryption'] ?? '').toString();
    final providerHint = (diagnostic['providerHint'] ?? '').toString();
    final retry = (diagnostic['nextAction'] ??
            diagnostic['retrySuggestion'] ??
            '')
        .toString();
    final correlationId = (diagnostic['correlationId'] ?? '').toString();
    final hintsRaw = diagnostic['fallbackHints'];
    final hints = (hintsRaw is List)
        ? hintsRaw.map((e) => e.toString()).toList()
        : <String>[];

    final headline = _headlineForStage(stage);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE7C97A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 18, color: Colors.orange.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  headline,
                  style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.brown.shade800,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$host:$port ($encryption)'
            '${providerHint.isNotEmpty && providerHint != 'custom' ? '  ·  Provider: $providerHint' : ''}',
            style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.brown.shade900,
                  fontFamily: 'monospace',
                ),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.brown.shade900),
            ),
          ],
          if (code.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Code: $code',
              style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.brown.shade700,
                    fontFamily: 'monospace',
                  ),
            ),
          ],
          if (retry.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              retry,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.brown.shade800),
            ),
          ],
          if (hints.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Try a fallback:',
              style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.brown.shade900,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            ...hints.map((hint) => _FallbackHintRow(
                  hint: hint,
                  onApply: () => _maybeApply(hint),
                )),
          ],
          if (correlationId.isNotEmpty) ...[
            const SizedBox(height: 10),
            SelectableText(
              'correlationId: $correlationId',
              style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.brown.shade700,
                    fontFamily: 'monospace',
                  ),
            ),
          ],
        ],
      ),
    );
  }

  /// Compose the panel headline from the aggregate stage. NEVER
  /// returns "unknown stage" — that was the contract-violation bug.
  /// When the stage is unrecognised, we render a generic but truthful
  /// headline instead.
  static String _headlineForStage(String stage) {
    switch (stage) {
      case 'dns':
      case 'dns_failed':
        return 'Connection failed at DNS resolution';
      case 'tcp':
      case 'tcp_timeout':
        return 'Connection failed at TCP connect';
      case 'tls':
      case 'tls_timeout':
        return 'Connection failed at TLS handshake';
      case 'starttls':
      case 'starttls_failed':
        return 'Connection failed at STARTTLS upgrade';
      case 'greeting':
      case 'greeting_timeout':
        return 'Connection failed at SMTP greeting';
      case 'auth':
      case 'auth_failed':
        return 'Connection failed at authentication';
      case 'provider_policy':
      case 'provider_policy_block':
        return 'Connection blocked by provider policy';
      case 'runtime_egress':
      case 'runtime_egress_block':
        return 'Deployment runtime could not reach the provider';
      case 'orchestration':
      case 'orchestration_timeout':
        return 'Transport test did not complete in time';
      case '':
      case 'unknown':
        return 'Transport test did not complete';
      default:
        return 'Transport test did not complete';
    }
  }

  void _maybeApply(String hint) {
    // Parse "Try <label>: <host>:<port> (<enc>)" hints into apply
    // calls. Hints that don't match this shape (generic advisories
    // like the egress note) become read-only — there is nothing to
    // apply.
    final match = RegExp(
      r'([a-z0-9\.\-]+):(\d+)\s*\((tls|starttls|none)\)',
      caseSensitive: false,
    ).firstMatch(hint);
    if (match == null) return;
    final host = match.group(1)!;
    final port = int.tryParse(match.group(2)!) ?? 0;
    final secure = match.group(3)!.toLowerCase();
    if (port == 0) return;
    onApplyFallback(host: host, port: port, secure: secure);
  }
}

class _FallbackHintRow extends StatelessWidget {
  const _FallbackHintRow({required this.hint, required this.onApply});

  final String hint;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Show an apply button only when we can confidently parse a
    // host:port (enc) tuple from the hint.
    final hasApplyTarget = RegExp(
      r'[a-z0-9\.\-]+:\d+\s*\((tls|starttls|none)\)',
      caseSensitive: false,
    ).hasMatch(hint);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.east, size: 14, color: Colors.brown.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hint,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.brown.shade900),
            ),
          ),
          if (hasApplyTarget) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onApply,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                minimumSize: const Size(0, 28),
                foregroundColor: Colors.brown.shade900,
              ),
              child: const Text('Apply'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Renders the per-candidate attempt list the backend's
/// verify-with-candidates path returns. Shows the user every
/// endpoint that was tried, the failure stage on each failure, and
/// the winning endpoint when one succeeds.
class _SmtpAttemptsPanel extends StatelessWidget {
  const _SmtpAttemptsPanel({
    required this.attempts,
    required this.provider,
    required this.winning,
  });

  final List<Map<String, dynamic>> attempts;
  final String? provider;
  final Map<String, dynamic>? winning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final providerLabel = _providerNameLabel(provider);
    final winningHost = (winning?['host'] ?? '').toString();
    final winningPort = winning?['port']?.toString() ?? '';
    final winningEnc = (winning?['encryption'] ?? '').toString();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBCC9D6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.travel_explore,
                  size: 16, color: Colors.blueGrey.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  providerLabel.isNotEmpty
                      ? 'Endpoint attempts ($providerLabel)'
                      : 'Endpoint attempts',
                  style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.blueGrey.shade900,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final attempt in attempts) _AttemptRow(attempt: attempt),
          if (winning != null && winningHost.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFA5D6A7)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Verified via $winningHost:$winningPort ($winningEnc). Save will persist this exact endpoint.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.green.shade900,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _providerNameLabel(String? provider) {
    switch (provider) {
      case 'zoho':
        return 'Zoho Mail';
      case 'google':
        return 'Gmail / Google Workspace';
      case 'microsoft':
        return 'Microsoft 365';
      default:
        return '';
    }
  }
}

class _AttemptRow extends StatelessWidget {
  const _AttemptRow({required this.attempt});

  final Map<String, dynamic> attempt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The new backend contract carries `status` (closed enum) on
    // every attempt. The legacy `ok` boolean is still accepted as
    // a fallback for backwards compatibility with old responses,
    // but `status` is the truth source.
    final status = (attempt['status'] ?? '').toString();
    final legacyOk = attempt['ok'] == true;
    final ok = status == 'attempted_success' || (status.isEmpty && legacyOk);
    final isFailed = status == 'attempted_failed' ||
        (status.isEmpty && !legacyOk && attempt['failureStage'] != null);
    final isNotAttempted =
        status == 'not_attempted' || status == 'skipped' || status == 'cancelled';
    final label = (attempt['label'] ?? '').toString();
    final host = (attempt['host'] ?? '').toString();
    final port = attempt['port']?.toString() ?? '';
    final encryption = (attempt['encryption'] ?? '').toString();
    // ONLY render a stage when this candidate actually attempted
    // and failed. Skipped / not_attempted candidates carry no
    // stage and we must not invent one.
    final stage = isFailed
        ? (attempt['stage'] ?? attempt['failureStage'] ?? '').toString()
        : '';
    final duration = attempt['elapsedMs'] ?? attempt['durationMs'];
    final fallback = '$host:$port ($encryption)';
    final displayLabel = label.isEmpty ? fallback : label;

    IconData iconData;
    Color iconColor;
    String? subline;
    Color sublineColor;
    if (ok) {
      iconData = Icons.check_circle_outline;
      iconColor = Colors.green.shade700;
      subline = null;
      sublineColor = Colors.transparent;
    } else if (isFailed) {
      iconData = Icons.cancel_outlined;
      iconColor = Colors.red.shade700;
      subline = stage.isEmpty
          ? 'Failed'
          : 'Failed at: ${_attemptStageLabel(stage)}';
      sublineColor = Colors.red.shade700;
    } else if (isNotAttempted) {
      iconData = Icons.remove_circle_outline;
      iconColor = Colors.blueGrey.shade400;
      subline = status == 'cancelled' ? 'Cancelled' : 'Not attempted';
      sublineColor = Colors.blueGrey.shade600;
    } else {
      // Defensive: unrecognised status. Render as not_attempted
      // rather than implying failure.
      iconData = Icons.remove_circle_outline;
      iconColor = Colors.blueGrey.shade400;
      subline = 'Not attempted';
      sublineColor = Colors.blueGrey.shade600;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(iconData, size: 14, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.blueGrey.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (subline != null)
                  Text(
                    subline,
                    style: theme.textTheme.bodySmall?.copyWith(
                          color: sublineColor,
                        ),
                  ),
              ],
            ),
          ),
          // Only render elapsed time when the candidate actually
          // attempted. A "0ms" badge on a not_attempted candidate
          // is the contract violation we just fixed.
          if ((isFailed || ok) && duration is num)
            Text(
              '${duration}ms',
              style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.blueGrey.shade700,
                    fontFamily: 'monospace',
                  ),
            ),
        ],
      ),
    );
  }
}

/// Provider chooser rendered at the top of the SMTP dialog. Reads
/// the catalog from /v1/client/mailbox/smtp/providers/catalog and
/// renders one button per provider. Selecting an SMTP/IMAP provider
/// prefills sensible defaults + tags subsequent requests with
/// `providerOverride` so the backend's candidate retry knows which
/// preset to use. OAuth entries surface as informational tags.
class _ProviderChooser extends StatelessWidget {
  const _ProviderChooser({
    required this.catalog,
    required this.selectedKey,
    required this.onChoose,
  });

  final List<Map<String, dynamic>>? catalog;
  final String? selectedKey;
  final void Function(Map<String, dynamic> entry) onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loading = catalog == null;
    final entries = catalog ?? const <Map<String, dynamic>>[];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD0DAE3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pick a provider',
            style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Orchestrate uses provider presets so you do not have to guess between ports, encryption modes, or regional endpoints.',
            style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.blueGrey.shade800,
                ),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('Loading provider catalog…'),
            )
          else if (entries.isEmpty)
            Text(
              'Provider catalog unavailable. You can still enter SMTP credentials manually below.',
              style: theme.textTheme.bodySmall,
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: entries.map((entry) {
                final key = (entry['key'] ?? '').toString();
                final label = (entry['setupActionLabel'] ?? entry['displayName'] ?? '')
                    .toString();
                final credentialType =
                    (entry['credentialType'] ?? '').toString();
                final isOauth = credentialType == 'oauth';
                final isSelected = selectedKey == key;
                final color = isSelected
                    ? theme.colorScheme.primary
                    : Colors.blueGrey.shade400;
                return OutlinedButton.icon(
                  onPressed: () => onChoose(entry),
                  icon: Icon(
                    isOauth ? Icons.shield_outlined : Icons.dns_outlined,
                    size: 16,
                    color: color,
                  ),
                  label: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                          color: color,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: color),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }).toList(),
            ),
          if (selectedKey != null) ...[
            const SizedBox(height: 10),
            _ProviderGuidance(
              entry: entries.firstWhere(
                (e) => (e['key'] ?? '').toString() == selectedKey,
                orElse: () => const <String, dynamic>{},
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Renders the provider's userGuidance + knownQuirks below the
/// chooser once a provider is picked.
class _ProviderGuidance extends StatelessWidget {
  const _ProviderGuidance({required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (entry.isEmpty) return const SizedBox.shrink();
    final guidanceRaw = entry['userGuidance'];
    final quirksRaw = entry['knownQuirks'];
    final guidance = guidanceRaw is List
        ? guidanceRaw.map((e) => e.toString()).toList()
        : <String>[];
    final quirks = quirksRaw is List
        ? quirksRaw.map((e) => e.toString()).toList()
        : <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in guidance) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 14, color: Colors.blueGrey.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    line,
                    style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.blueGrey.shade900,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
        for (final line in quirks) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 14, color: Colors.orange.shade800),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    line,
                    style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.brown.shade900,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Mapping result emitted by `_mapTransportError`. The user message
/// is rendered in the dialog's error banner; the diagnostic payload
/// is rendered in `_SmtpDiagnosticPanel` (failureStage / nextAction
/// / fallback hints).
class _MappedTransportError {
  const _MappedTransportError({
    required this.userMessage,
    required this.diagnosticPayload,
  });

  final String userMessage;
  final Map<String, dynamic> diagnosticPayload;
}

/// Parse a structured backend error body (the JSON-encoded
/// BadRequestException body the controller throws on save failure).
/// Returns null when the body is not a structured shape — the
/// caller falls back to a generic ApiException mapping.
_StructuredError? _parseStructuredError(String body) {
  if (body.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return null;
    final map = decoded.map((k, v) => MapEntry('$k', v));
    final diagnostic = map['diagnostic'];
    final failureStage = (map['stage'] ?? map['failureStage'] ?? '').toString();
    final message = (map['message'] ?? map['failureMessage'] ?? '').toString();
    if (diagnostic is Map) {
      return _StructuredError(
        userMessage: _userMessageForStage(failureStage, message),
        diagnostic: diagnostic.map((k, v) => MapEntry('$k', v)),
      );
    }
    if (failureStage.isNotEmpty || message.isNotEmpty) {
      return _StructuredError(
        userMessage: _userMessageForStage(failureStage, message),
        diagnostic: <String, dynamic>{
          'failureStage': failureStage.isEmpty ? 'unknown' : failureStage,
          'failureCode': (map['failureCode'] ?? '').toString(),
          'failureMessage': message,
          'host': (map['host'] ?? '').toString(),
          'port': map['port'],
          'encryption': (map['encryption'] ?? '').toString(),
          'providerHint': (map['providerHint'] ?? 'custom').toString(),
          'fallbackHints': map['fallbackHints'] ?? const <String>[],
          'retrySuggestion': (map['retrySuggestion'] ?? '').toString(),
          'correlationId': (map['correlationId'] ?? '').toString(),
        },
      );
    }
    return null;
  } catch (_) {
    return null;
  }
}

class _StructuredError {
  const _StructuredError({
    required this.userMessage,
    required this.diagnostic,
  });

  final String userMessage;
  final Map<String, dynamic> diagnostic;
}

String _userMessageForStage(String stage, String fallbackMessage) {
  switch (stage) {
    case 'dns_failed':
    case 'dns':
      return 'The provider host could not be resolved. Check the host spelling.';
    case 'tcp_timeout':
    case 'tcp':
      return 'The transport test could not reach the provider in time. The deployment runtime may be filtering outbound traffic to this port — Orchestrate will try the alternate endpoint on retry.';
    case 'tls_timeout':
    case 'tls':
      return 'The TLS handshake with the provider did not complete. Try the implicit-TLS endpoint (port 465) — STARTTLS is more brittle on managed runtimes.';
    case 'starttls':
    case 'starttls_failed':
      return 'STARTTLS upgrade did not complete. The implicit-TLS endpoint (port 465) avoids this negotiation entirely.';
    case 'greeting':
    case 'greeting_timeout':
      return 'The provider opened a connection but did not return an SMTP greeting in time. Check that the host actually serves SMTP on this port.';
    case 'auth':
    case 'auth_failed':
    case 'auth_post_dkim':
      return 'The provider rejected the credentials. Most providers require an APP-SPECIFIC PASSWORD if 2FA is enabled — the account password will not work.';
    case 'provider_policy_block':
      return 'The provider rejected the connection on policy grounds. Check the provider account settings (region, SMTP-AUTH enabled, admin policy).';
    case 'runtime_egress_block':
      return 'Every candidate endpoint failed at the network layer. This looks like a deployment runtime network reachability issue, not a credential problem.';
    case 'orchestration_timeout':
      return 'The transport test orchestration ran out of time before completing. The runtime is likely slow to reach this provider — retry.';
    case 'vault_store':
    case 'vault_stage_failed':
      return 'SMTP verified, but the credential vault could not store the credentials. Retry; if this persists, capture the reference and contact support.';
    case 'mailbox_resolve':
    case 'mailbox_update':
    case 'db_stage_failed':
      return 'SMTP verified, but the mailbox database write failed. Retry; if this persists, capture the reference and contact support.';
    case 'save_stage_failed':
      return 'SMTP verified, but the save flow failed after verification. Retry; if persistent, contact support.';
    case 'transport_post_dkim':
      return 'SMTP transport regressed between verification and final save. Retry once; if it persists, the deployment runtime may be unstable.';
    default:
      if (fallbackMessage.isNotEmpty) {
        return 'The transport test reported: $fallbackMessage';
      }
      return 'The transport test could not complete. Retry, then contact support if persistent.';
  }
}

/// Short, render-safe label for an attempted candidate's failure
/// stage. Used in the per-attempt row. Never returns "unknown
/// stage".
String _attemptStageLabel(String stage) {
  switch (stage) {
    case 'dns':
    case 'dns_failed':
      return 'DNS resolution';
    case 'tcp':
    case 'tcp_timeout':
      return 'TCP connect';
    case 'tls':
    case 'tls_timeout':
      return 'TLS handshake';
    case 'starttls':
    case 'starttls_failed':
      return 'STARTTLS upgrade';
    case 'greeting':
    case 'greeting_timeout':
      return 'SMTP greeting';
    case 'auth':
    case 'auth_failed':
      return 'authentication';
    case 'orchestration':
    case 'orchestration_timeout':
      return 'orchestration';
    default:
      return stage;
  }
}
