import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:orchestrate_app/core/network/api_client.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/core/widgets/substrate_chip.dart';
import 'package:orchestrate_app/data/repositories/client/client_relationship_repository.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';

// ─── Page state ──────────────────────────────────────────────────────────────

enum _PageState {
  loading,
  error,
  noMailbox,
  none,      // mailbox connected but no scan run yet
  scanning,  // pending or processing
  complete,
  failed,
}

enum _SortBy { lastActivity, frequency, alphabetical }

// ─── Data model ──────────────────────────────────────────────────────────────

class _Summary {
  const _Summary({
    required this.total,
    required this.activeInLast30Days,
    required this.bidirectional,
    required this.inactiveSince90Days,
  });
  final int total;
  final int activeInLast30Days;
  final int bidirectional;
  final int inactiveSince90Days;
}

class _RelContact {
  const _RelContact({
    required this.email,
    required this.displayName,
    required this.domain,
    this.organizationName,
    required this.totalMessageCount,
    required this.sentCount,
    required this.receivedCount,
    required this.daysSinceLastActivity,
    required this.isBidirectional,
    required this.sources,
    required this.isSuppressed,
    this.isReDiscovered = false,
  });

  final String email;
  final String displayName;
  final String domain;
  final String? organizationName;
  final int totalMessageCount;
  final int sentCount;
  final int receivedCount;
  final int daysSinceLastActivity;
  final bool isBidirectional;
  final List<String> sources;
  final bool isSuppressed;
  final bool isReDiscovered;

  _RelContact copyWith({bool? isSuppressed}) => _RelContact(
        email: email,
        displayName: displayName,
        domain: domain,
        organizationName: organizationName,
        totalMessageCount: totalMessageCount,
        sentCount: sentCount,
        receivedCount: receivedCount,
        daysSinceLastActivity: daysSinceLastActivity,
        isBidirectional: isBidirectional,
        sources: sources,
        isSuppressed: isSuppressed ?? this.isSuppressed,
        isReDiscovered: isReDiscovered,
      );

  String get directionLabel {
    if (sentCount > 0 && receivedCount > 0) return 'both directions';
    if (sentCount > 0) return 'you sent only';
    return 'they sent only';
  }

  String get recencyLabel {
    if (daysSinceLastActivity == 0) return 'today';
    if (daysSinceLastActivity == 1) return '1 day ago';
    return '$daysSinceLastActivity days ago';
  }

  String get displayOrg => organizationName ?? domain;
}

class _Inventory {
  const _Inventory({
    required this.scanId,
    this.generatedAt,
    required this.summary,
    required this.contacts,
    this.hasConnectedMailbox = false,
    this.hasGoogleMailbox = false,
    this.hasGoogleContactsAuth = false,
  });
  final String scanId;
  final String? generatedAt;
  final _Summary summary;
  final List<_RelContact> contacts;
  final bool hasConnectedMailbox;
  final bool hasGoogleMailbox;
  final bool hasGoogleContactsAuth;

  int get csvContactCount => contacts.where((c) => c.sources.contains('CSV_IMPORT')).length;
  int get googleContactCount => contacts.where((c) => c.sources.contains('GOOGLE_CONTACTS')).length;
  int get manualContactCount => contacts.where((c) => c.sources.contains('MANUAL')).length;
}

// ─── Parsers ─────────────────────────────────────────────────────────────────

_Summary _parseSummary(Map<String, dynamic> m) => _Summary(
      total: _int(m['total']),
      activeInLast30Days: _int(m['activeInLast30Days']),
      bidirectional: _int(m['bidirectional']),
      inactiveSince90Days: _int(m['inactiveSince90Days']),
    );

_RelContact _parseContact(Map<String, dynamic> m) {
  // sources is a flat String[] from the backend, not a List<{source}>
  final sources = (m['sources'] as List? ?? [])
      .map((s) => s?.toString() ?? '')
      .where((s) => s.isNotEmpty)
      .toList();
  return _RelContact(
    email: _str(m['email']),
    displayName: _str(m['displayName']).isNotEmpty
        ? _str(m['displayName'])
        : _str(m['email']),
    domain: _str(m['domain']),
    organizationName: _strOrNull(m['organizationName']),
    totalMessageCount: _int(m['totalMessageCount']),
    sentCount: _int(m['sentCount']),
    receivedCount: _int(m['receivedCount']),
    daysSinceLastActivity: _int(m['daysSinceLastActivity']),
    isBidirectional: m['isBidirectional'] == true,
    sources: sources.isEmpty ? ['MAILBOX_INTELLIGENCE'] : sources,
    isSuppressed: m['isSuppressed'] == true,
    isReDiscovered: m['isReDiscovered'] == true,
  );
}

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return 0;
}

String _str(dynamic v) => v?.toString().trim() ?? '';
String? _strOrNull(dynamic v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class ClientRelationshipsScreen extends StatefulWidget {
  const ClientRelationshipsScreen({super.key});

  @override
  State<ClientRelationshipsScreen> createState() =>
      _ClientRelationshipsScreenState();
}

class _ClientRelationshipsScreenState
    extends State<ClientRelationshipsScreen> {
  final _repo = ClientRelationshipRepository();

  _PageState _state = _PageState.loading;
  _Inventory? _inventory;
  String? _scanId;
  String? _generatedAt;
  Timer? _pollTimer;
  String? _error;
  _SortBy _sortBy = _SortBy.lastActivity;
  bool _isSyncing = false;
  bool _isRebuilding = false;
  bool _inventoryExpanded = false;
  bool _isSyncingGoogle = false;
  bool _isImportingCsv = false;
  bool _isConnectingGoogle = false;

  static const _pollInterval = Duration(seconds: 5);
  static const _pollTimeout = Duration(minutes: 3);
  Duration _pollElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  // ─── Load / state machine ─────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() => _state = _PageState.loading);
    try {
      final data = await _repo.fetchInventory();
      _applyInventoryResponse(data);
    } on ApiException catch (e) {
      if (e.statusCode == 401) rethrow;
      setState(() {
        _state = _PageState.error;
        _error = e.displayMessage;
      });
    } catch (e) {
      setState(() {
        _state = _PageState.error;
        _error = e.toString();
      });
    }
  }

  void _applyInventoryResponse(Map<String, dynamic> data) {
    final scanState = _str(data['scanState']);
    final hasConnectedMailbox = data['hasConnectedMailbox'] == true;
    final hasGoogleMailbox = data['hasGoogleMailbox'] == true;
    final hasGoogleContactsAuth = data['hasGoogleContactsAuth'] == true;

    // Parse contacts regardless of scan state (CSV/manual exist independently)
    final summaryMap = data['summary'] is Map
        ? Map<String, dynamic>.from(data['summary'] as Map)
        : <String, dynamic>{};
    final contactsList = (data['contacts'] as List? ?? [])
        .whereType<Map>()
        .map((m) => _parseContact(Map<String, dynamic>.from(m)))
        .toList();
    final hasContacts = contactsList.isNotEmpty;

    // No mailbox and no contacts of any kind → show no-mailbox prompt
    if (scanState == 'no_mailbox' && !hasContacts) {
      setState(() => _state = _PageState.noMailbox);
      return;
    }

    // Mailbox present but no scan yet, and no other contacts → consent panel
    if (scanState == 'none' && !hasContacts) {
      setState(() => _state = _PageState.none);
      return;
    }

    if (scanState == 'pending' || scanState == 'processing') {
      final sid = _str(data['scanId']);
      setState(() {
        _state = _PageState.scanning;
        _scanId = sid.isNotEmpty ? sid : _scanId;
      });
      _startPolling();
      return;
    }

    if (scanState == 'failed' && !hasContacts) {
      setState(() {
        _state = _PageState.failed;
        _error = _str(data['failureReason']);
      });
      return;
    }

    // complete / failed-with-contacts / none-with-contacts / no_mailbox-with-contacts
    setState(() {
      _state = _PageState.complete;
      _scanId = _str(data['scanId']);
      _generatedAt = _strOrNull(data['generatedAt']);
      _inventory = _Inventory(
        scanId: _scanId ?? '',
        generatedAt: _generatedAt,
        summary: _parseSummary(summaryMap),
        contacts: contactsList,
        hasConnectedMailbox: hasConnectedMailbox,
        hasGoogleMailbox: hasGoogleMailbox,
        hasGoogleContactsAuth: hasGoogleContactsAuth,
      );
    });
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollElapsed = Duration.zero;
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  Future<void> _poll() async {
    _pollElapsed += _pollInterval;
    if (_pollElapsed >= _pollTimeout) {
      _pollTimer?.cancel();
      // Timeout: reload full inventory — may have partial data
      await _load();
      return;
    }
    if (_scanId == null) return;
    try {
      final status = await _repo.fetchScanStatus(_scanId!);
      final s = _str(status['status']);
      if (s == 'complete') {
        _pollTimer?.cancel();
        await _load();
      } else if (s == 'failed') {
        _pollTimer?.cancel();
        setState(() {
          _state = _PageState.failed;
          _error = _str(status['failureReason']);
        });
      }
    } catch (_) {
      // Transient poll failure — keep polling
    }
  }

  // ─── Governance actions ───────────────────────────────────────────────────

  Future<void> _triggerScan() async {
    setState(() => _state = _PageState.scanning);
    try {
      final result = await _repo.triggerScan();
      final sid = _str(result['scanId']);
      // 409 = scan already running; pick up the existing scanId
      setState(() => _scanId = sid.isNotEmpty ? sid : _scanId);
      _startPolling();
    } on ApiException catch (e) {
      if (e.statusCode == 400 &&
          e.message.contains('MAILBOX_NOT_CONNECTED')) {
        setState(() => _state = _PageState.noMailbox);
        return;
      }
      if (e.statusCode == 409) {
        final sid = _str(e.body);
        if (sid.isNotEmpty) setState(() => _scanId = sid);
        _startPolling();
        return;
      }
      setState(() {
        _state = _PageState.failed;
        _error = e.displayMessage;
      });
    } catch (e) {
      setState(() {
        _state = _PageState.failed;
        _error = e.toString();
      });
    }
  }

  Future<void> _suppress(String email) async {
    _updateContact(email, (c) => c.copyWith(isSuppressed: true));
    try {
      await _repo.suppress(email);
    } catch (_) {
      _updateContact(email, (c) => c.copyWith(isSuppressed: false));
    }
  }

  Future<void> _unsuppress(String email) async {
    _updateContact(email, (c) => c.copyWith(isSuppressed: false));
    try {
      await _repo.unsuppress(email);
    } catch (_) {
      _updateContact(email, (c) => c.copyWith(isSuppressed: true));
    }
  }

  Future<void> _deleteContact(String email) async {
    final confirmed = await _showDeleteConfirm(email);
    if (!confirmed || !mounted) return;
    setState(() {
      final inv = _inventory;
      if (inv == null) return;
      _inventory = _Inventory(
        scanId: inv.scanId,
        generatedAt: inv.generatedAt,
        summary: inv.summary,
        contacts: inv.contacts.where((c) => c.email != email).toList(),
      );
    });
    try {
      await _repo.deleteContact(email);
    } catch (_) {
      // Refresh to restore the tile on failure
      _load();
    }
  }

  Future<void> _resync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final result = await _repo.resync();
      final sid = _str(result['scanId']);
      setState(() {
        _isSyncing = false;
        _state = _PageState.scanning;
        if (sid.isNotEmpty) _scanId = sid;
      });
      _startPolling();
    } catch (_) {
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _rebuild() async {
    final confirmed = await _showRebuildConfirm();
    if (!confirmed || !mounted) return;
    setState(() {
      _isRebuilding = true;
      _inventory = null;
    });
    try {
      final result = await _repo.rebuild();
      final sid = _str(result['scanId']);
      setState(() {
        _isRebuilding = false;
        _state = _PageState.scanning;
        if (sid.isNotEmpty) _scanId = sid;
      });
      _startPolling();
    } catch (_) {
      setState(() {
        _isRebuilding = false;
        _state = _PageState.failed;
        _error = 'Rebuild could not start. Please try again.';
      });
    }
  }

  Future<void> _removeSource() async {
    final behavior = await _showRemoveSourceDialog();
    if (behavior == null || !mounted) return;
    try {
      await _repo.removeSource(behavior);
      _load();
    } catch (_) {}
  }

  Future<void> _connectGoogleContacts() async {
    if (_isConnectingGoogle) return;
    setState(() => _isConnectingGoogle = true);
    try {
      final result = await _repo.beginGoogleContactsAuth();
      final authUrl = _str(result['authUrl']);
      if (authUrl.isEmpty || !mounted) return;
      final uri = Uri.tryParse(authUrl);
      if (uri == null) return;
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google authorization page.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start Google authorization: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnectingGoogle = false);
    }
  }

  Future<void> _syncGoogleContacts() async {
    if (_isSyncingGoogle) return;
    setState(() => _isSyncingGoogle = true);
    try {
      final result = await _repo.syncGoogleContacts();
      final status = _str(result['status']);
      if (!mounted) return;
      if (status == 'no_google_contacts_auth' || status == 'no_google_mailbox') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Google Contacts not connected. Use "Connect Google Contacts" to authorize.',
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      } else if (status == 'insufficient_scope') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Contacts access not granted. Reconnect your Google account and allow contacts permission.',
            ),
            duration: Duration(seconds: 6),
          ),
        );
      } else if (status == 'failed') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_str(result['error']).isNotEmpty
              ? _str(result['error'])
              : 'Google Contacts sync failed.')),
        );
      } else {
        final count = result['count'] as int? ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Synced $count contacts from Google.')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncingGoogle = false);
    }
  }

  Future<void> _importCsv() async {
    final result = await showDialog<_CsvFileSelection?>(
      context: context,
      builder: (ctx) => const _CsvImportDialog(),
    );
    if (result == null || !mounted) return;

    final csvCountBefore = _inventory?.csvContactCount ?? 0;
    setState(() => _isImportingCsv = true);
    try {
      final res = await _repo.importCsv(result.bytes, result.filename);
      if (!mounted) return;
      final imported = res['imported'] as int? ?? 0;
      final updated = res['updated'] as int? ?? 0;
      final skipped = res['skipped'] as int? ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $imported · Updated $updated · Skipped $skipped')),
      );
      _load();
    } on TimeoutException {
      // Backend may have finished after the timeout. Refresh inventory to find out.
      if (!mounted) return;
      try {
        final data = await _repo.fetchInventory();
        if (!mounted) return;
        _applyInventoryResponse(data);
        final csvCountAfter = _inventory?.csvContactCount ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              csvCountAfter > csvCountBefore
                  ? 'Import completed — $csvCountAfter contacts from CSV'
                  : 'Import is still processing. Refresh in a moment.',
            ),
          ),
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Import timed out. Refresh to check if contacts were imported.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImportingCsv = false);
    }
  }

  Future<void> _addManual() async {
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (ctx) => const _AddManualDialog(),
    );
    if (result == null || !mounted) return;
    try {
      await _repo.addManual(
        result['email']!,
        name: result['name']?.isNotEmpty == true ? result['name'] : null,
        organization: result['organization']?.isNotEmpty == true ? result['organization'] : null,
      );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add contact: $e')),
        );
      }
    }
  }

  Future<void> _removeCsvSource() async {
    final behavior = await _showRemoveGenericSourceDialog(
      title: 'Remove CSV-imported contacts?',
      sourceLabel: 'CSV import',
    );
    if (behavior == null || !mounted) return;
    try {
      await _repo.removeCsvSource(behavior);
      _load();
    } catch (_) {}
  }

  Future<void> _removeGoogleSource() async {
    final behavior = await _showRemoveGenericSourceDialog(
      title: 'Remove Google Contacts?',
      sourceLabel: 'Google Contacts',
    );
    if (behavior == null || !mounted) return;
    try {
      await _repo.removeGoogleSource(behavior);
      _load();
    } catch (_) {}
  }

  Future<void> _resolveReDiscovery(String email, {required bool keep}) async {
    try {
      await _repo.resolveReDiscovery(email, keep: keep);
    } catch (_) {}
    setState(() {
      final inv = _inventory;
      if (inv == null) return;
      final updated = keep
          ? inv.contacts
              .map((c) =>
                  c.email == email ? _RelContact(
                    email: c.email,
                    displayName: c.displayName,
                    domain: c.domain,
                    organizationName: c.organizationName,
                    totalMessageCount: c.totalMessageCount,
                    sentCount: c.sentCount,
                    receivedCount: c.receivedCount,
                    daysSinceLastActivity: c.daysSinceLastActivity,
                    isBidirectional: c.isBidirectional,
                    sources: c.sources,
                    isSuppressed: c.isSuppressed,
                    isReDiscovered: false,
                  )
                  : c)
              .toList()
          : inv.contacts.where((c) => c.email != email).toList();
      _inventory = _Inventory(
        scanId: inv.scanId,
        generatedAt: inv.generatedAt,
        summary: inv.summary,
        contacts: updated,
      );
    });
  }

  void _updateContact(String email, _RelContact Function(_RelContact) fn) {
    setState(() {
      final inv = _inventory;
      if (inv == null) return;
      _inventory = _Inventory(
        scanId: inv.scanId,
        generatedAt: inv.generatedAt,
        summary: inv.summary,
        contacts: inv.contacts
            .map((c) => c.email == email ? fn(c) : c)
            .toList(),
      );
    });
  }

  // ─── Dialogs ──────────────────────────────────────────────────────────────

  Future<bool> _showDeleteConfirm(String email) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Remove from Orchestrate?'),
            content: Text(
              'This removes the record derived from your mailbox scan for '
              '$email. Your mailbox messages are not affected.\n\n'
              'If you run a future scan, this contact may be re-discovered. '
              'To prevent re-discovery, suppress this contact instead.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.error,
                ),
                child: const Text('Remove from Orchestrate'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _showRebuildConfirm() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Rebuild relationship inventory?'),
            content: const Text(
              'This clears all contacts derived from your mailbox scan and '
              'runs a new 90-day analysis.\n\n'
              'Your suppression decisions are preserved. This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Rebuild inventory'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<String?> _showRemoveSourceDialog() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => _RemoveSourceDialog(),
    );
  }

  Future<String?> _showRemoveGenericSourceDialog({
    required String title,
    required String sourceLabel,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => _RemoveGenericSourceDialog(
        title: title,
        sourceLabel: sourceLabel,
      ),
    );
  }

  // ─── Sorted contacts ──────────────────────────────────────────────────────

  List<_RelContact> get _sortedContacts {
    final list = List<_RelContact>.from(_inventory?.contacts ?? []);
    switch (_sortBy) {
      case _SortBy.lastActivity:
        list.sort((a, b) =>
            a.daysSinceLastActivity.compareTo(b.daysSinceLastActivity));
      case _SortBy.frequency:
        list.sort(
            (a, b) => b.totalMessageCount.compareTo(a.totalMessageCount));
      case _SortBy.alphabetical:
        list.sort((a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    }
    return list;
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _PageState.loading:
        return const ClientLoadingView(
          eyebrow: 'Relationships',
          label: 'Loading your relationship inventory',
        );
      case _PageState.error:
        return ClientErrorView(
          message: _error ?? 'Could not load relationships.',
          onRetry: _load,
          title: 'Relationships are temporarily unavailable',
        );
      case _PageState.noMailbox:
        return _buildNoMailbox();
      case _PageState.none:
        return _buildNone();
      case _PageState.scanning:
        return _buildScanning();
      case _PageState.failed:
        return _buildFailed();
      case _PageState.complete:
        return _buildComplete();
    }
  }

  // ─── State views ──────────────────────────────────────────────────────────

  Widget _buildNoMailbox() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 12, bottom: 28),
      child: _ConsentPanel(
        title: 'No mailbox connected',
        body: 'Connect a mailbox in Infrastructure to build your relationship '
            'inventory from your email activity. Orchestrate analyzes only '
            'header information — message content is never read.',
        action: FilledButton(
          onPressed: () => context.go('/client/infrastructure'),
          child: const Text('Open Infrastructure'),
        ),
      ),
    );
  }

  Widget _buildNone() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 12, bottom: 28),
      child: _ConsentPanel(
        title: 'Build your relationship inventory',
        body: 'Orchestrate will analyze email header activity from your '
            'connected mailbox to identify who you communicate with, how '
            'often, and when you last heard from them.\n\n'
            'Message content is never read or stored. Headers only: '
            'From, To, CC, Date.',
        footer: 'Looking back 90 days from today.',
        action: FilledButton(
          onPressed: _triggerScan,
          child: const Text('Build relationship inventory'),
        ),
      ),
    );
  }

  Widget _buildScanning() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 12, bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ConsentPanel(
            title: 'Building your relationship inventory',
            body: 'Analyzing mailbox headers from the past 90 days. '
                'This runs once. Results are cached until you choose to rescan.\n\n'
                'Message content is not read.',
            footer: null,
            action: null,
            showProgress: true,
          ),
          const SizedBox(height: 18),
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.publicSurfaceSoft,
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.publicSurfaceSoft,
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.publicSurfaceSoft,
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailed() {
    return ClientErrorView(
      title: 'Relationship scan did not complete',
      message: _error?.isNotEmpty == true
          ? _error!
          : 'The mailbox scan encountered an error. Your existing contacts '
              'are not affected.',
      onRetry: _triggerScan,
    );
  }

  static const _inventoryCollapseThreshold = 50;

  Widget _buildComplete() {
    final inv = _inventory;
    if (inv == null) return _buildScanning();

    final contacts = _sortedContacts;
    final reDiscovered = contacts.where((c) => c.isReDiscovered).toList();
    final normal = contacts.where((c) => !c.isReDiscovered).toList();
    final active = normal.where((c) => !c.isSuppressed).toList();
    final isLarge = normal.length > _inventoryCollapseThreshold;
    final showInventory = !isLarge || _inventoryExpanded;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 12, bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryStrip(summary: inv.summary),
          const SizedBox(height: 18),
          _SourceManagement(
            generatedAt: inv.generatedAt,
            hasConnectedMailbox: inv.hasConnectedMailbox,
            hasGoogleMailbox: inv.hasGoogleMailbox,
            hasGoogleContactsAuth: inv.hasGoogleContactsAuth,
            csvContactCount: inv.csvContactCount,
            googleContactCount: inv.googleContactCount,
            manualContactCount: inv.manualContactCount,
            isSyncing: _isSyncing,
            isRebuilding: _isRebuilding,
            isSyncingGoogle: _isSyncingGoogle,
            isImportingCsv: _isImportingCsv,
            isConnectingGoogle: _isConnectingGoogle,
            onResync: _resync,
            onRebuild: _rebuild,
            onRemoveSource: _removeSource,
            onConnectGoogle: _connectGoogleContacts,
            onSyncGoogle: _syncGoogleContacts,
            onImportCsv: _importCsv,
            onAddManual: _addManual,
            onRemoveCsvSource: _removeCsvSource,
            onRemoveGoogleSource: _removeGoogleSource,
          ),
          if (active.isNotEmpty) ...[
            const SizedBox(height: 18),
            _IntelligenceSection(contacts: active),
          ],
          const SizedBox(height: 18),
          if (showInventory)
            _InventoryPanel(
              contacts: normal,
              reDiscovered: reDiscovered,
              sortBy: _sortBy,
              onSortChanged: (s) => setState(() => _sortBy = s),
              onSuppress: _suppress,
              onUnsuppress: _unsuppress,
              onDelete: _deleteContact,
              onResolveReDiscovery: _resolveReDiscovery,
            )
          else
            _InventoryCollapsedBanner(
              total: normal.length,
              suppressed: normal.where((c) => c.isSuppressed).length,
              onExpand: () => setState(() => _inventoryExpanded = true),
            ),
        ],
      ),
    );
  }
}

// ─── Consent panel ────────────────────────────────────────────────────────────

class _ConsentPanel extends StatelessWidget {
  const _ConsentPanel({
    required this.title,
    required this.body,
    this.footer,
    this.action,
    this.showProgress = false,
  });

  final String title;
  final String body;
  final String? footer;
  final Widget? action;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Text(
            body,
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: AppTheme.publicMuted, height: 1.5),
          ),
          if (showProgress) ...[
            const SizedBox(height: 18),
            const LinearProgressIndicator(minHeight: 3),
          ],
          if (action != null) ...[
            const SizedBox(height: 22),
            action!,
          ],
          if (footer != null) ...[
            const SizedBox(height: 12),
            Text(
              footer!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppTheme.publicMuted),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Summary strip ────────────────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.summary});
  final _Summary summary;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _MetricTile(label: 'Total', value: '${summary.total}'),
      _MetricTile(label: 'Last 30 days', value: '${summary.activeInLast30Days}'),
      _MetricTile(label: 'Bidirectional', value: '${summary.bidirectional}'),
      _MetricTile(label: 'Quiet 90+ days', value: '${summary.inactiveSince90Days}'),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < WorkspaceBreakpoints.compact) {
        return Column(
          children: [
            Row(children: [
              Expanded(child: tiles[0]),
              const SizedBox(width: 12),
              Expanded(child: tiles[1]),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: tiles[2]),
              const SizedBox(width: 12),
              Expanded(child: tiles[3]),
            ]),
          ],
        );
      }
      return Row(children: [
        for (int i = 0; i < tiles.length; i++) ...[
          Expanded(child: tiles[i]),
          if (i < tiles.length - 1) const SizedBox(width: 12),
        ],
      ]);
    });
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppTheme.publicMuted)),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ─── Source management ────────────────────────────────────────────────────────

class _SourceManagement extends StatelessWidget {
  const _SourceManagement({
    required this.generatedAt,
    required this.hasConnectedMailbox,
    required this.hasGoogleMailbox,
    required this.hasGoogleContactsAuth,
    required this.csvContactCount,
    required this.googleContactCount,
    required this.manualContactCount,
    required this.isSyncing,
    required this.isRebuilding,
    required this.isSyncingGoogle,
    required this.isImportingCsv,
    required this.isConnectingGoogle,
    required this.onResync,
    required this.onRebuild,
    required this.onRemoveSource,
    required this.onConnectGoogle,
    required this.onSyncGoogle,
    required this.onImportCsv,
    required this.onAddManual,
    required this.onRemoveCsvSource,
    required this.onRemoveGoogleSource,
  });

  final String? generatedAt;
  final bool hasConnectedMailbox;
  final bool hasGoogleMailbox;
  final bool hasGoogleContactsAuth;
  final int csvContactCount;
  final int googleContactCount;
  final int manualContactCount;
  final bool isSyncing;
  final bool isRebuilding;
  final bool isSyncingGoogle;
  final bool isImportingCsv;
  final bool isConnectingGoogle;
  final VoidCallback onResync;
  final VoidCallback onRebuild;
  final VoidCallback onRemoveSource;
  final VoidCallback onConnectGoogle;
  final VoidCallback onSyncGoogle;
  final VoidCallback onImportCsv;
  final VoidCallback onAddManual;
  final VoidCallback onRemoveCsvSource;
  final VoidCallback onRemoveGoogleSource;

  String get _scanLabel {
    if (generatedAt == null) return 'Not scanned';
    try {
      final dt = DateTime.parse(generatedAt!).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return generatedAt ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Show Google active source row only when there are contacts already synced
    final showGoogleSourceRow = googleContactCount > 0 || hasGoogleContactsAuth;
    // Whether to show "Connect Google Contacts" in the add section
    final showConnectGoogle = !hasGoogleContactsAuth;
    // Whether to show "Sync now" in add section (authorized but 0 contacts yet)
    final showSyncNowGoogle = hasGoogleContactsAuth && googleContactCount == 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sources',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),

          // ── Mailbox row ──────────────────────────────────────────────────
          if (hasConnectedMailbox) ...[
            _SourceRow(
              dot: AppTheme.coVerdant,
              title: 'Connected mailbox',
              subtitle: 'Header analysis · Last scanned $_scanLabel · 90-day window',
              actions: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: isSyncing ? null : onResync,
                    child: Text(isSyncing ? 'Syncing…' : 'Resync'),
                  ),
                  OutlinedButton(
                    onPressed: isRebuilding ? null : onRebuild,
                    child: Text(isRebuilding ? 'Rebuilding…' : 'Rebuild'),
                  ),
                  TextButton(
                    onPressed: onRemoveSource,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    child: const Text('Remove source'),
                  ),
                ],
              ),
            ),
          ],

          // ── Google Contacts row ──────────────────────────────────────────
          if (showGoogleSourceRow) ...[
            if (hasConnectedMailbox) const Divider(height: 24),
            _SourceRow(
              dot: AppTheme.coVerdant,
              title: 'Google Contacts',
              subtitle: googleContactCount > 0
                  ? '$googleContactCount contacts synced from Google'
                  : 'Connected · No contacts synced yet',
              actions: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: isSyncingGoogle ? null : onSyncGoogle,
                    child: Text(isSyncingGoogle
                        ? 'Syncing…'
                        : googleContactCount > 0
                            ? 'Sync again'
                            : 'Sync now'),
                  ),
                  if (googleContactCount > 0)
                    TextButton(
                      onPressed: onRemoveGoogleSource,
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                      child: const Text('Remove source'),
                    ),
                ],
              ),
            ),
          ],

          // ── CSV row ──────────────────────────────────────────────────────
          if (csvContactCount > 0) ...[
            if (hasConnectedMailbox || showGoogleSourceRow) const Divider(height: 24),
            _SourceRow(
              dot: AppTheme.coMist,
              title: 'CSV import',
              subtitle: '$csvContactCount contacts from last import',
              actions: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: isImportingCsv ? null : onImportCsv,
                    child: Text(isImportingCsv ? 'Importing…' : 'Re-import'),
                  ),
                  TextButton(
                    onPressed: onRemoveCsvSource,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    child: const Text('Remove source'),
                  ),
                ],
              ),
            ),
          ],

          // ── Manual row ───────────────────────────────────────────────────
          if (manualContactCount > 0) ...[
            if (hasConnectedMailbox || showGoogleSourceRow || csvContactCount > 0)
              const Divider(height: 24),
            _SourceRow(
              dot: AppTheme.coSun,
              title: 'Manual',
              subtitle: '$manualContactCount contacts added manually',
              actions: const SizedBox.shrink(),
            ),
          ],

          // ── Add a source ─────────────────────────────────────────────────
          const Divider(height: 24),
          Text(
            'Add contacts',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: AppTheme.publicMuted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (showConnectGoogle)
                OutlinedButton.icon(
                  onPressed: isConnectingGoogle ? null : onConnectGoogle,
                  icon: const Icon(Icons.account_circle_outlined, size: 16),
                  label: Text(isConnectingGoogle ? 'Opening…' : 'Connect Google Contacts'),
                ),
              if (showSyncNowGoogle)
                OutlinedButton.icon(
                  onPressed: isSyncingGoogle ? null : onSyncGoogle,
                  icon: const Icon(Icons.sync_outlined, size: 16),
                  label: Text(isSyncingGoogle ? 'Syncing…' : 'Sync Google Contacts'),
                ),
              OutlinedButton.icon(
                onPressed: isImportingCsv ? null : onImportCsv,
                icon: const Icon(Icons.upload_file_outlined, size: 16),
                label: Text(isImportingCsv ? 'Importing…' : 'Import CSV'),
              ),
              OutlinedButton.icon(
                onPressed: onAddManual,
                icon: const Icon(Icons.person_add_outlined, size: 16),
                label: const Text('Add manually'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.dot,
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final Color dot;
  final String title;
  final String subtitle;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < WorkspaceBreakpoints.mobile;
      final meta = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              subtitle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppTheme.publicMuted),
            ),
          ),
        ],
      );
      if (narrow) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [meta, const SizedBox(height: 12), actions],
        );
      }
      return Row(
        children: [
          Expanded(child: meta),
          const SizedBox(width: 16),
          actions,
        ],
      );
    });
  }
}

// ─── Generic remove source dialog ────────────────────────────────────────────

class _RemoveGenericSourceDialog extends StatefulWidget {
  const _RemoveGenericSourceDialog({
    required this.title,
    required this.sourceLabel,
  });
  final String title;
  final String sourceLabel;

  @override
  State<_RemoveGenericSourceDialog> createState() =>
      _RemoveGenericSourceDialogState();
}

class _RemoveGenericSourceDialogState
    extends State<_RemoveGenericSourceDialog> {
  String _behavior = 'keep';

  @override
  Widget build(BuildContext context) {
    final label = widget.sourceLabel;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<String>(
            value: 'keep',
            groupValue: _behavior,
            onChanged: (v) => setState(() => _behavior = v!),
            title: const Text('Keep contacts'),
            subtitle: Text(
              'Contacts from $label remain in your inventory.',
            ),
            contentPadding: EdgeInsets.zero,
          ),
          RadioListTile<String>(
            value: 'remove_exclusive',
            groupValue: _behavior,
            onChanged: (v) => setState(() => _behavior = v!),
            title: const Text('Remove contacts with no other sources'),
            subtitle: Text(
              'Only contacts that came exclusively from $label are removed.',
            ),
            contentPadding: EdgeInsets.zero,
          ),
          RadioListTile<String>(
            value: 'remove_all',
            groupValue: _behavior,
            onChanged: (v) => setState(() => _behavior = v!),
            title: Text('Remove all $label contacts'),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _behavior),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

// ─── CSV file selection result ────────────────────────────────────────────────

class _CsvFileSelection {
  const _CsvFileSelection({
    required this.bytes,
    required this.filename,
    required this.rowCount,
  });
  final List<int> bytes;
  final String filename;
  final int rowCount;
}

// ─── CSV import dialog ────────────────────────────────────────────────────────

class _CsvImportDialog extends StatefulWidget {
  const _CsvImportDialog();

  @override
  State<_CsvImportDialog> createState() => _CsvImportDialogState();
}

class _CsvImportDialogState extends State<_CsvImportDialog> {
  String? _fileName;
  List<int>? _fileBytes;
  String? _validationError;
  int _rowCount = 0;

  void _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (!mounted) return;
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    final content = utf8.decode(bytes, allowMalformed: true);
    final lines = content
        .split(RegExp(r'\r?\n'))
        .where((l) => l.trim().isNotEmpty)
        .toList();
    final header = lines.isNotEmpty ? lines.first.toLowerCase() : '';
    final hasEmail = header
        .split(',')
        .any((col) => col.trim().replaceAll('"', '') == 'email');
    setState(() {
      _fileName = file.name;
      _fileBytes = bytes;
      _rowCount = lines.length > 1 ? lines.length - 1 : 0;
      _validationError = hasEmail ? null : 'No "email" column found in first row.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canImport = _fileBytes != null && _validationError == null && _rowCount > 0;

    return AlertDialog(
      title: const Text('Upload CSV'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a CSV file from your device. Required header column: email. '
              'Optional columns: name, organization.',
              style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.publicMuted),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: const Text('Choose file'),
            ),
            if (_fileName != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.publicSurfaceSoft,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: AppTheme.publicLine),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file_outlined, size: 16,
                        color: AppTheme.publicMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _fileName!,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_validationError == null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '$_rowCount row${_rowCount == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppTheme.publicMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (_validationError != null) ...[
              const SizedBox(height: 10),
              Text(
                _validationError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canImport
              ? () => Navigator.pop(
                    context,
                    _CsvFileSelection(
                      bytes: _fileBytes!,
                      filename: _fileName!,
                      rowCount: _rowCount,
                    ),
                  )
              : null,
          child: const Text('Import'),
        ),
      ],
    );
  }
}

// ─── Add manually dialog ──────────────────────────────────────────────────────

class _AddManualDialog extends StatefulWidget {
  const _AddManualDialog();

  @override
  State<_AddManualDialog> createState() => _AddManualDialogState();
}

class _AddManualDialogState extends State<_AddManualDialog> {
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _orgCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _orgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add contact'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _orgCtrl,
                decoration: const InputDecoration(
                  labelText: 'Organization (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, {
              'email': _emailCtrl.text.trim(),
              'name': _nameCtrl.text.trim(),
              'organization': _orgCtrl.text.trim(),
            });
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// ─── Remove source dialog ────────────────────────────────────────────────────

class _RemoveSourceDialog extends StatefulWidget {
  @override
  State<_RemoveSourceDialog> createState() => _RemoveSourceDialogState();
}

class _RemoveSourceDialogState extends State<_RemoveSourceDialog> {
  String _behavior = 'keep';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Remove mailbox as a source?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<String>(
            value: 'keep',
            groupValue: _behavior,
            onChanged: (v) => setState(() => _behavior = v!),
            title: const Text('Keep derived contacts'),
            subtitle: const Text(
              "Contacts remain in your inventory and won't update on future scans.",
            ),
            contentPadding: EdgeInsets.zero,
          ),
          RadioListTile<String>(
            value: 'remove_exclusive',
            groupValue: _behavior,
            onChanged: (v) => setState(() => _behavior = v!),
            title: const Text('Remove contacts with no other sources'),
            subtitle: const Text(
              'Only contacts that came exclusively from mailbox analysis are removed.',
            ),
            contentPadding: EdgeInsets.zero,
          ),
          RadioListTile<String>(
            value: 'remove_all',
            groupValue: _behavior,
            onChanged: (v) => setState(() => _behavior = v!),
            title: const Text('Remove all mailbox-derived contacts'),
            subtitle: const Text(
              'All contacts derived from mailbox analysis are removed.',
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _behavior),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

// ─── Intelligence section ─────────────────────────────────────────────────────

class _IntelligenceSection extends StatelessWidget {
  const _IntelligenceSection({required this.contacts});
  final List<_RelContact> contacts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final hasMailbox = contacts.any((c) => c.totalMessageCount > 0);
    final recentlyActive = hasMailbox
        ? contacts.where((c) => c.totalMessageCount > 0 && c.daysSinceLastActivity <= 30).length
        : 0;
    final strongConnections = hasMailbox
        ? contacts.where((c) => c.isBidirectional && c.totalMessageCount >= 5).length
        : 0;
    final dormant = hasMailbox
        ? contacts.where((c) => c.totalMessageCount > 0 && c.daysSinceLastActivity > 90).length
        : 0;

    final orgCounts = <String, int>{};
    for (final c in contacts) {
      orgCounts[c.displayOrg] = (orgCounts[c.displayOrg] ?? 0) + 1;
    }
    final multiOrgs = orgCounts.values.where((n) => n >= 2).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Intelligence',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _InsightCard(
                icon: Icons.people_outline,
                value: '${contacts.length}',
                label: 'Total contacts',
                color: AppTheme.publicText,
              ),
              if (hasMailbox) ...[
                _InsightCard(
                  icon: Icons.schedule_outlined,
                  value: '$recentlyActive',
                  label: 'Active in 30 days',
                  color: const Color(0xFF2E7D32),
                ),
                _InsightCard(
                  icon: Icons.swap_horiz_outlined,
                  value: '$strongConnections',
                  label: 'Two-way (5+ msg)',
                  color: AppTheme.coSun,
                ),
                if (dormant > 0)
                  _InsightCard(
                    icon: Icons.hourglass_empty_outlined,
                    value: '$dormant',
                    label: 'Dormant (90+ days)',
                    color: AppTheme.publicMuted,
                  ),
              ],
              if (multiOrgs > 0)
                _InsightCard(
                  icon: Icons.business_outlined,
                  value: '$multiOrgs',
                  label: 'Orgs with 2+ contacts',
                  color: AppTheme.coMist,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 154,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.publicMuted),
          ),
        ],
      ),
    );
  }
}

// ─── Inventory collapsed banner ───────────────────────────────────────────────

class _InventoryCollapsedBanner extends StatelessWidget {
  const _InventoryCollapsedBanner({
    required this.total,
    required this.suppressed,
    required this.onExpand,
  });
  final int total;
  final int suppressed;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Relationship inventory',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '$total contacts · ${suppressed > 0 ? '$suppressed suppressed · ' : ''}Search, filter and manage individual records.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppTheme.publicMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: onExpand,
            icon: const Icon(Icons.people_outline, size: 16),
            label: Text('Review $total contacts'),
          ),
        ],
      ),
    );
  }
}

// ─── Inventory panel ──────────────────────────────────────────────────────────

class _InventoryPanel extends StatefulWidget {
  const _InventoryPanel({
    required this.contacts,
    required this.reDiscovered,
    required this.sortBy,
    required this.onSortChanged,
    required this.onSuppress,
    required this.onUnsuppress,
    required this.onDelete,
    required this.onResolveReDiscovery,
  });

  final List<_RelContact> contacts;
  final List<_RelContact> reDiscovered;
  final _SortBy sortBy;
  final ValueChanged<_SortBy> onSortChanged;
  final Future<void> Function(String) onSuppress;
  final Future<void> Function(String) onUnsuppress;
  final Future<void> Function(String) onDelete;
  final Future<void> Function(String, {required bool keep}) onResolveReDiscovery;

  @override
  State<_InventoryPanel> createState() => _InventoryPanelState();
}

class _InventoryPanelState extends State<_InventoryPanel> {
  static const _pageSize = 50;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _sourceFilter; // null = all
  bool _showSuppressed = false;
  int _visibleCount = _pageSize;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_RelContact> get _filtered {
    var list = widget.contacts.where((c) {
      if (!_showSuppressed && c.isSuppressed) return false;
      if (_sourceFilter != null && !c.sources.contains(_sourceFilter)) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!c.email.contains(q) &&
            !c.displayName.toLowerCase().contains(q) &&
            !(c.organizationName ?? '').toLowerCase().contains(q) &&
            !c.domain.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered;
    final visible = filtered.take(_visibleCount).toList();
    final remaining = filtered.length - visible.length;
    final suppressed = widget.contacts.where((c) => c.isSuppressed).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Relationship inventory',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${widget.contacts.length} contacts${suppressed > 0 ? ' · $suppressed suppressed' : ''}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppTheme.publicMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _SortDropdown(value: widget.sortBy, onChanged: widget.onSortChanged),
            ],
          ),
          const SizedBox(height: 16),

          // Search + filter bar
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() {
                      _searchQuery = v.trim();
                      _visibleCount = _pageSize;
                    }),
                    decoration: InputDecoration(
                      hintText: 'Search name, email, company…',
                      prefixIcon: const Icon(Icons.search, size: 16),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 14),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _visibleCount = _pageSize;
                                });
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: AppTheme.publicLine),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: AppTheme.publicLine),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _SourceFilterDropdown(
                value: _sourceFilter,
                onChanged: (v) => setState(() {
                  _sourceFilter = v;
                  _visibleCount = _pageSize;
                }),
              ),
              if (suppressed > 0) ...[
                const SizedBox(width: 10),
                FilterChip(
                  label: Text('Suppressed ($suppressed)'),
                  selected: _showSuppressed,
                  onSelected: (v) => setState(() {
                    _showSuppressed = v;
                    _visibleCount = _pageSize;
                  }),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Re-discovered banners
          for (final c in widget.reDiscovered) ...[
            _ReDiscoveredBanner(
              contact: c,
              onKeep: () => widget.onResolveReDiscovery(c.email, keep: true),
              onSkip: () => widget.onResolveReDiscovery(c.email, keep: false),
            ),
            const SizedBox(height: 10),
          ],

          // Empty state
          if (filtered.isEmpty && widget.reDiscovered.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _searchQuery.isNotEmpty || _sourceFilter != null
                        ? 'No contacts match your filters'
                        : 'No relationships found in the past 90 days',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _searchQuery.isNotEmpty || _sourceFilter != null
                        ? 'Try a different search or clear the filter.'
                        : 'The mailbox scan completed but all discovered addresses '
                          'were filtered as automated senders. If you expected to '
                          'see real contacts, try rebuilding the inventory.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: AppTheme.publicMuted),
                  ),
                ],
              ),
            ),
          ],

          // Contact list (paginated)
          for (int i = 0; i < visible.length; i++) ...[
            _ContactTile(
              contact: visible[i],
              onSuppress: () => widget.onSuppress(visible[i].email),
              onUnsuppress: () => widget.onUnsuppress(visible[i].email),
              onDelete: () => widget.onDelete(visible[i].email),
            ),
            if (i < visible.length - 1) const Divider(height: 22),
          ],

          // Load more
          if (remaining > 0) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => setState(() => _visibleCount += _pageSize),
                  child: Text('Show ${remaining > _pageSize ? _pageSize : remaining} more'),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => setState(() => _visibleCount = filtered.length),
                  child: Text('Show all ${filtered.length}'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceFilterDropdown extends StatelessWidget {
  const _SourceFilterDropdown({required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String?>(
      value: value,
      hint: const Text('All sources'),
      underline: const SizedBox(),
      isDense: true,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.publicMuted),
      items: const [
        DropdownMenuItem(value: null, child: Text('All sources')),
        DropdownMenuItem(value: 'MAILBOX_INTELLIGENCE', child: Text('Mailbox')),
        DropdownMenuItem(value: 'GOOGLE_CONTACTS', child: Text('Google')),
        DropdownMenuItem(value: 'CSV_IMPORT', child: Text('CSV')),
        DropdownMenuItem(value: 'MANUAL', child: Text('Manual')),
      ],
      onChanged: onChanged,
    );
  }
}

class _SortDropdown extends StatelessWidget {
  const _SortDropdown({required this.value, required this.onChanged});
  final _SortBy value;
  final ValueChanged<_SortBy> onChanged;

  String _label(_SortBy s) {
    switch (s) {
      case _SortBy.lastActivity:
        return 'Most recent';
      case _SortBy.frequency:
        return 'Most frequent';
      case _SortBy.alphabetical:
        return 'Alphabetical';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButton<_SortBy>(
      value: value,
      underline: const SizedBox(),
      isDense: true,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.publicMuted,
          ),
      items: _SortBy.values
          .map((s) => DropdownMenuItem(value: s, child: Text(_label(s))))
          .toList(),
      onChanged: (s) {
        if (s != null) onChanged(s);
      },
    );
  }
}

// ─── Re-discovered banner ─────────────────────────────────────────────────────

class _ReDiscoveredBanner extends StatelessWidget {
  const _ReDiscoveredBanner({
    required this.contact,
    required this.onKeep,
    required this.onSkip,
  });
  final _RelContact contact;
  final VoidCallback onKeep;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.publicAmberSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: AppTheme.amber.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Re-discovered: ${contact.displayName}',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${contact.email} was found again in your mailbox. '
                  'You previously removed this record.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppTheme.publicMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(onPressed: onKeep, child: const Text('Keep')),
          TextButton(
            onPressed: onSkip,
            child: const Text('Skip again'),
          ),
        ],
      ),
    );
  }
}

// ─── Contact tile ─────────────────────────────────────────────────────────────

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.onSuppress,
    required this.onUnsuppress,
    required this.onDelete,
  });

  final _RelContact contact;
  final VoidCallback onSuppress;
  final VoidCallback onUnsuppress;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = contact;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c.displayName,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (c.isSuppressed) ...[
                    const SizedBox(width: 8),
                    const SubstrateChip(
                      label: 'Suppressed',
                      state: SubstrateChipState.sun,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${c.displayOrg} · ${c.email}',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppTheme.publicText),
              ),
              const SizedBox(height: 4),
              Text(
                '${c.totalMessageCount} messages · ${c.directionLabel} · last ${c.recencyLabel}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppTheme.publicMuted),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  for (final src in c.sources)
                    SubstrateChip(
                      label: _sourceLabel(src),
                      state: SubstrateChipState.mist,
                    ),
                ],
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert,
              size: 18, color: AppTheme.publicMuted),
          onSelected: (action) {
            if (action == 'suppress') onSuppress();
            if (action == 'unsuppress') onUnsuppress();
            if (action == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            if (!c.isSuppressed)
              const PopupMenuItem(
                value: 'suppress',
                child: Text('Suppress'),
              ),
            if (c.isSuppressed)
              const PopupMenuItem(
                value: 'unsuppress',
                child: Text('Unsuppress'),
              ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete from Orchestrate'),
            ),
          ],
        ),
      ],
    );
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'MAILBOX_INTELLIGENCE':
        return 'Mailbox';
      case 'GOOGLE_CONTACTS':
        return 'Google';
      case 'CSV_IMPORT':
        return 'CSV';
      case 'MANUAL':
        return 'Manual';
      default:
        return source;
    }
  }
}
