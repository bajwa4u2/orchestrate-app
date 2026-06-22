import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
  });
  final String scanId;
  final String? generatedAt;
  final _Summary summary;
  final List<_RelContact> contacts;
}

// ─── Parsers ─────────────────────────────────────────────────────────────────

_Summary _parseSummary(Map<String, dynamic> m) => _Summary(
      total: _int(m['total']),
      activeInLast30Days: _int(m['activeInLast30Days']),
      bidirectional: _int(m['bidirectional']),
      inactiveSince90Days: _int(m['inactiveSince90Days']),
    );

_RelContact _parseContact(Map<String, dynamic> m) {
  final sources = (m['sources'] as List? ?? [])
      .whereType<Map>()
      .map((s) => _str(s['source']))
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

    if (scanState == 'none') {
      final hasMailbox = data['hasConnectedMailbox'] != false;
      setState(() => _state = hasMailbox ? _PageState.none : _PageState.noMailbox);
      return;
    }

    if (scanState == 'no_mailbox') {
      setState(() => _state = _PageState.noMailbox);
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

    if (scanState == 'failed') {
      setState(() {
        _state = _PageState.failed;
        _error = _str(data['failureReason']);
      });
      return;
    }

    // complete
    final summaryMap = data['summary'] is Map
        ? Map<String, dynamic>.from(data['summary'] as Map)
        : <String, dynamic>{};
    final contactsList = (data['contacts'] as List? ?? [])
        .whereType<Map>()
        .map((m) => _parseContact(Map<String, dynamic>.from(m)))
        .toList();

    setState(() {
      _state = _PageState.complete;
      _scanId = _str(data['scanId']);
      _generatedAt = _strOrNull(data['generatedAt']);
      _inventory = _Inventory(
        scanId: _scanId ?? '',
        generatedAt: _generatedAt,
        summary: _parseSummary(summaryMap),
        contacts: contactsList,
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

  Widget _buildComplete() {
    final inv = _inventory;
    if (inv == null) return _buildScanning();

    final contacts = _sortedContacts;
    final reDiscovered = contacts.where((c) => c.isReDiscovered).toList();
    final normal = contacts.where((c) => !c.isReDiscovered).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 12, bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryStrip(summary: inv.summary),
          const SizedBox(height: 18),
          _SourceManagement(
            generatedAt: inv.generatedAt,
            isSyncing: _isSyncing,
            isRebuilding: _isRebuilding,
            onResync: _resync,
            onRebuild: _rebuild,
            onRemoveSource: _removeSource,
          ),
          const SizedBox(height: 18),
          _InventoryPanel(
            contacts: normal,
            reDiscovered: reDiscovered,
            sortBy: _sortBy,
            onSortChanged: (s) => setState(() => _sortBy = s),
            onSuppress: _suppress,
            onUnsuppress: _unsuppress,
            onDelete: _deleteContact,
            onResolveReDiscovery: _resolveReDiscovery,
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
    required this.isSyncing,
    required this.isRebuilding,
    required this.onResync,
    required this.onRebuild,
    required this.onRemoveSource,
  });

  final String? generatedAt;
  final bool isSyncing;
  final bool isRebuilding;
  final VoidCallback onResync;
  final VoidCallback onRebuild;
  final VoidCallback onRemoveSource;

  String get _scanLabel {
    if (generatedAt == null) return 'Not scanned';
    try {
      final dt = DateTime.parse(generatedAt!).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final narrow = constraints.maxWidth < WorkspaceBreakpoints.mobile;
        final meta = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(
                  color: AppTheme.coVerdant,
                  shape: BoxShape.circle,
                ),
              ),
              Text(
                'Connected mailbox',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              'Header analysis · Last scanned $_scanLabel · 90-day window',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppTheme.publicMuted),
            ),
          ],
        );

        final actions = Wrap(
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
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Remove source'),
            ),
          ],
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [meta, const SizedBox(height: 14), actions],
          );
        }
        return Row(
          children: [
            Expanded(child: meta),
            const SizedBox(width: 16),
            actions,
          ],
        );
      }),
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

// ─── Inventory panel ──────────────────────────────────────────────────────────

class _InventoryPanel extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          // Header row
          Row(
            children: [
              Expanded(
                child: Text(
                  'People in your network',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              _SortDropdown(value: sortBy, onChanged: onSortChanged),
            ],
          ),
          const SizedBox(height: 16),

          // Re-discovered banners
          for (final c in reDiscovered) ...[
            _ReDiscoveredBanner(
              contact: c,
              onKeep: () => onResolveReDiscovery(c.email, keep: true),
              onSkip: () => onResolveReDiscovery(c.email, keep: false),
            ),
            const SizedBox(height: 10),
          ],

          // Empty state
          if (contacts.isEmpty && reDiscovered.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No relationships found in the past 90 days',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The mailbox scan completed but all discovered addresses '
                    'were filtered as automated senders. If you expected to '
                    'see real contacts, try rebuilding the inventory.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: AppTheme.publicMuted),
                  ),
                ],
              ),
            ),
          ],

          // Contact list
          for (int i = 0; i < contacts.length; i++) ...[
            _ContactTile(
              contact: contacts[i],
              onSuppress: () => onSuppress(contacts[i].email),
              onUnsuppress: () => onUnsuppress(contacts[i].email),
              onDelete: () => onDelete(contacts[i].email),
            ),
            if (i < contacts.length - 1) const Divider(height: 22),
          ],
        ],
      ),
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
        return 'Import';
      default:
        return source;
    }
  }
}
