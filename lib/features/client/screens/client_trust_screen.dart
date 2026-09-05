import 'package:orchestrate_app/core/ui/screen_memory.dart';
import 'package:flutter/material.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/client/client_trust_repository.dart';

class ClientTrustScreen extends StatefulWidget {
  const ClientTrustScreen({super.key});

  @override
  State<ClientTrustScreen> createState() => _ClientTrustScreenState();
}

class _ClientTrustScreenState extends State<ClientTrustScreen> {
  final _repo = ClientTrustRepository();
  /// Seeded from the last answer this screen was given, so returning
  /// to it paints immediately instead of blanking behind a spinner.
  List<Map<String, dynamic>>? _records = ScreenMemory.recall<List<Map<String, dynamic>>>('credentials');
  late bool _loading = _records == null;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = _records == null; _error = null; });
    try {
      final data = await _repo.list();
      if (!mounted) return;
      ScreenMemory.remember('credentials', data);
      setState(() { _records = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Credentials',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            FilledButton.icon(
              onPressed: () => _showEditDialog(context, null),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add credential'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Certifications, licenses, insurance, and other verifiable credentials.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.publicMuted),
        ),
        const SizedBox(height: 24),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          _ErrorCard(message: _error!, onRetry: _load)
        else if (_records!.isEmpty)
          _EmptyState(onAdd: () => _showEditDialog(context, null))
        else
          ...(_records!.map((r) => _TrustCard(
                record: r,
                onEdit: () => _showEditDialog(context, r),
                onArchive: () => _archive(r['id'] as String),
              ))),
      ],
    );
  }

  Future<void> _archive(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive record?'),
        content: const Text('This credential will be removed from your identity. The record is preserved but inactive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archive', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.archive(id);
      if (!mounted) return;
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _showEditDialog(BuildContext context, Map<String, dynamic>? record) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _TrustEditDialog(record: record, repo: _repo),
    );
    if (result == true) _load();
  }
}

class _TrustCard extends StatelessWidget {
  const _TrustCard({required this.record, required this.onEdit, required this.onArchive});
  final Map<String, dynamic> record;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final status = record['status'] as String? ?? 'active';
    final expiry = record['expiryDate'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _iconFor(record['recordType'] as String? ?? ''),
            size: 22,
            color: AppTheme.publicMuted,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record['title'] as String? ?? '',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _Chip(label: _labelFor(record['recordType'] as String? ?? '')),
                    _Chip(label: status, color: _statusColor(status)),
                    if (record['issuer'] != null) _Chip(label: record['issuer'] as String),
                    if (expiry != null) _Chip(label: 'Expires $expiry'),
                  ],
                ),
                if (record['notes'] != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    record['notes'] as String,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.publicMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'archive') onArchive();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'archive', child: Text('Archive')),
            ],
            child: const Icon(Icons.more_horiz, color: AppTheme.publicMuted),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'certification': return Icons.verified_outlined;
      case 'license': return Icons.assignment_outlined;
      case 'insurance': return Icons.shield_outlined;
      case 'award': return Icons.emoji_events_outlined;
      case 'membership': return Icons.group_outlined;
      default: return Icons.badge_outlined;
    }
  }

  String _labelFor(String type) => type.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

  Color _statusColor(String status) {
    switch (status) {
      case 'active': return Colors.green;
      case 'expired': return Colors.red;
      case 'pending': return Colors.orange;
      default: return AppTheme.publicMuted;
    }
  }
}

class _TrustEditDialog extends StatefulWidget {
  const _TrustEditDialog({required this.record, required this.repo});
  final Map<String, dynamic>? record;
  final ClientTrustRepository repo;

  @override
  State<_TrustEditDialog> createState() => _TrustEditDialogState();
}

class _TrustEditDialogState extends State<_TrustEditDialog> {
  late final _titleCtrl = TextEditingController(text: widget.record?['title'] as String? ?? '');
  late final _issuerCtrl = TextEditingController(text: widget.record?['issuer'] as String? ?? '');
  late final _identifierCtrl = TextEditingController(text: widget.record?['identifier'] as String? ?? '');
  late final _jurisdictionCtrl = TextEditingController(text: widget.record?['jurisdiction'] as String? ?? '');
  late final _notesCtrl = TextEditingController(text: widget.record?['notes'] as String? ?? '');
  late final _issueDateCtrl = TextEditingController(text: widget.record?['issueDate'] as String? ?? '');
  late final _expiryDateCtrl = TextEditingController(text: widget.record?['expiryDate'] as String? ?? '');

  String _recordType = 'certification';
  String _status = 'active';
  bool _saving = false;
  String? _error;

  static const _recordTypes = [
    'certification', 'license', 'insurance', 'accreditation',
    'qualification', 'membership', 'award', 'other',
  ];
  static const _statuses = ['active', 'expired', 'pending', 'archived'];

  @override
  void initState() {
    super.initState();
    if (widget.record != null) {
      _recordType = widget.record!['recordType'] as String? ?? 'certification';
      _status = widget.record!['status'] as String? ?? 'active';
    }
  }

  @override
  void dispose() {
    for (final c in [_titleCtrl, _issuerCtrl, _identifierCtrl, _jurisdictionCtrl, _notesCtrl, _issueDateCtrl, _expiryDateCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.record != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Credential' : 'Add Credential'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
              ],
              _label('Type'),
              DropdownButtonFormField<String>(
                value: _recordType,
                items: _recordTypes.map((t) => DropdownMenuItem(value: t, child: Text(_fmt(t)))).toList(),
                onChanged: (v) => setState(() => _recordType = v!),
                decoration: _dec(),
              ),
              const SizedBox(height: 14),
              _label('Title *'),
              TextField(controller: _titleCtrl, decoration: _dec(hint: 'e.g. ISO 9001 Certification')),
              const SizedBox(height: 14),
              _label('Issuing Organisation'),
              TextField(controller: _issuerCtrl, decoration: _dec(hint: 'e.g. Bureau Veritas')),
              const SizedBox(height: 14),
              _label('Certificate / License Number'),
              TextField(controller: _identifierCtrl, decoration: _dec()),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _label('Issue Date'),
                    TextField(controller: _issueDateCtrl, decoration: _dec(hint: 'YYYY-MM-DD')),
                  ])),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _label('Expiry Date'),
                    TextField(controller: _expiryDateCtrl, decoration: _dec(hint: 'YYYY-MM-DD')),
                  ])),
                ],
              ),
              const SizedBox(height: 14),
              _label('Jurisdiction'),
              TextField(controller: _jurisdictionCtrl, decoration: _dec(hint: 'e.g. United States')),
              const SizedBox(height: 14),
              _label('Status'),
              DropdownButtonFormField<String>(
                value: _status,
                items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(_fmt(s)))).toList(),
                onChanged: (v) => setState(() => _status = v!),
                decoration: _dec(),
              ),
              const SizedBox(height: 14),
              _label('Notes'),
              TextField(controller: _notesCtrl, decoration: _dec(), maxLines: 3),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      if (widget.record == null) {
        await widget.repo.create(
          recordType: _recordType,
          title: _titleCtrl.text.trim(),
          issuer: _issuerCtrl.text.trim().isEmpty ? null : _issuerCtrl.text.trim(),
          identifier: _identifierCtrl.text.trim().isEmpty ? null : _identifierCtrl.text.trim(),
          issueDate: _issueDateCtrl.text.trim().isEmpty ? null : _issueDateCtrl.text.trim(),
          expiryDate: _expiryDateCtrl.text.trim().isEmpty ? null : _expiryDateCtrl.text.trim(),
          jurisdiction: _jurisdictionCtrl.text.trim().isEmpty ? null : _jurisdictionCtrl.text.trim(),
          status: _status,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
      } else {
        await widget.repo.update(widget.record!['id'] as String, {
          'title': _titleCtrl.text.trim(),
          'issuer': _issuerCtrl.text.trim().isEmpty ? null : _issuerCtrl.text.trim(),
          'identifier': _identifierCtrl.text.trim().isEmpty ? null : _identifierCtrl.text.trim(),
          'issueDate': _issueDateCtrl.text.trim().isEmpty ? null : _issueDateCtrl.text.trim(),
          'expiryDate': _expiryDateCtrl.text.trim().isEmpty ? null : _expiryDateCtrl.text.trim(),
          'jurisdiction': _jurisdictionCtrl.text.trim().isEmpty ? null : _jurisdictionCtrl.text.trim(),
          'status': _status,
          'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        });
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = e.toString(); });
    }
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.publicMuted)),
  );

  InputDecoration _dec({String? hint}) => InputDecoration(
    hintText: hint,
    border: const OutlineInputBorder(),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    isDense: true,
  );

  String _fmt(String s) => s.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_outlined, size: 48, color: AppTheme.publicMuted.withOpacity(.4)),
            const SizedBox(height: 16),
            Text('No credentials yet', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Add certifications, licenses, and other credentials\nto strengthen your outreach and proposals.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.publicMuted),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add credential'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: Colors.red),
        const SizedBox(width: 12),
        Expanded(child: Text(message, style: const TextStyle(color: Colors.red))),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (color ?? AppTheme.publicMuted).withOpacity(.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color ?? AppTheme.publicMuted),
      ),
    );
  }
}
