import 'package:orchestrate_app/core/ui/screen_memory.dart';
import 'package:flutter/material.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/client/client_evidence_repository.dart';

class ClientEvidenceScreen extends StatefulWidget {
  const ClientEvidenceScreen({super.key});

  @override
  State<ClientEvidenceScreen> createState() => _ClientEvidenceScreenState();
}

class _ClientEvidenceScreenState extends State<ClientEvidenceScreen> {
  final _repo = ClientEvidenceRepository();
  /// Seeded from the last answer this screen was given, so returning
  /// to it paints immediately instead of blanking behind a spinner.
  List<Map<String, dynamic>>? _records = ScreenMemory.recall<List<Map<String, dynamic>>>('evidence');
  late bool _loading = _records == null;
  String? _error;
  String? _filterType;

  static const _recordTypes = [
    'capability_statement', 'case_study', 'reference',
    'past_performance', 'work_sample', 'testimonial', 'supporting_document',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = _records == null; _error = null; });
    try {
      final data = await _repo.list(recordType: _filterType);
      if (!mounted) return;
      ScreenMemory.remember('evidence', data);
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
              'Evidence',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            FilledButton.icon(
              onPressed: () => _showEditDialog(context, null),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add evidence'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Case studies, capability statements, references, and proof points for outreach and proposals.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.publicMuted),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(label: 'All', selected: _filterType == null, onTap: () { setState(() => _filterType = null); _load(); }),
              ..._recordTypes.map((t) => _FilterChip(
                label: _fmt(t),
                selected: _filterType == t,
                onTap: () { setState(() => _filterType = t); _load(); },
              )),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          _ErrorCard(message: _error!, onRetry: _load)
        else if (_records!.isEmpty)
          _EmptyState(onAdd: () => _showEditDialog(context, null))
        else
          ...(_records!.map((r) => _EvidenceCard(
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
        title: const Text('Archive evidence?'),
        content: const Text('This record will be removed from your identity. The record is preserved but inactive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Archive', style: TextStyle(color: Colors.red))),
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
      builder: (ctx) => _EvidenceEditDialog(record: record, repo: _repo),
    );
    if (result == true) _load();
  }

  String _fmt(String s) => s.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.record, required this.onEdit, required this.onArchive});
  final Map<String, dynamic> record;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final allowedUse = record['allowedUse'] as String? ?? 'internal_only';
    final confidential = record['confidential'] as bool? ?? false;
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
          Icon(_iconFor(record['recordType'] as String? ?? ''), size: 22, color: AppTheme.publicMuted),
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
                    _Chip(label: _fmt(record['recordType'] as String? ?? '')),
                    _Chip(label: _useLabel(allowedUse), color: _useColor(allowedUse)),
                    if (confidential) const _Chip(label: 'Confidential', color: Colors.orange),
                    if (record['industry'] != null) _Chip(label: record['industry'] as String),
                  ],
                ),
                if (record['summary'] != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    record['summary'] as String,
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
      case 'case_study': return Icons.auto_stories_outlined;
      case 'testimonial': return Icons.format_quote_outlined;
      case 'reference': return Icons.people_alt_outlined;
      case 'capability_statement': return Icons.description_outlined;
      default: return Icons.library_books_outlined;
    }
  }

  String _fmt(String s) => s.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  String _useLabel(String u) {
    switch (u) {
      case 'outreach_allowed': return 'Outreach';
      case 'proposal_allowed': return 'Proposals';
      default: return 'Internal';
    }
  }
  Color _useColor(String u) {
    switch (u) {
      case 'outreach_allowed': return Colors.green;
      case 'proposal_allowed': return Colors.blue;
      default: return AppTheme.publicMuted;
    }
  }
}

class _EvidenceEditDialog extends StatefulWidget {
  const _EvidenceEditDialog({required this.record, required this.repo});
  final Map<String, dynamic>? record;
  final ClientEvidenceRepository repo;

  @override
  State<_EvidenceEditDialog> createState() => _EvidenceEditDialogState();
}

class _EvidenceEditDialogState extends State<_EvidenceEditDialog> {
  late final _titleCtrl = TextEditingController(text: widget.record?['title'] as String? ?? '');
  late final _summaryCtrl = TextEditingController(text: widget.record?['summary'] as String? ?? '');
  late final _industryCtrl = TextEditingController(text: widget.record?['industry'] as String? ?? '');
  late final _geoCtrl = TextEditingController(text: widget.record?['geography'] as String? ?? '');

  String _recordType = 'case_study';
  String _allowedUse = 'internal_only';
  bool _confidential = false;
  bool _saving = false;
  String? _error;

  static const _recordTypes = [
    'capability_statement', 'case_study', 'reference',
    'past_performance', 'work_sample', 'testimonial', 'supporting_document',
  ];
  static const _allowedUses = ['internal_only', 'proposal_allowed', 'outreach_allowed'];

  @override
  void initState() {
    super.initState();
    if (widget.record != null) {
      _recordType = widget.record!['recordType'] as String? ?? 'case_study';
      _allowedUse = widget.record!['allowedUse'] as String? ?? 'internal_only';
      _confidential = widget.record!['confidential'] as bool? ?? false;
    }
  }

  @override
  void dispose() {
    for (final c in [_titleCtrl, _summaryCtrl, _industryCtrl, _geoCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.record != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Evidence' : 'Add Evidence'),
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
              TextField(controller: _titleCtrl, decoration: _dec(hint: 'e.g. SaaS Fintech Case Study Q3 2025')),
              const SizedBox(height: 14),
              _label('Summary'),
              TextField(controller: _summaryCtrl, decoration: _dec(), maxLines: 3),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Industry'),
                  TextField(controller: _industryCtrl, decoration: _dec(hint: 'e.g. SaaS')),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Geography'),
                  TextField(controller: _geoCtrl, decoration: _dec(hint: 'e.g. North America')),
                ])),
              ]),
              const SizedBox(height: 14),
              _label('Allowed Use'),
              DropdownButtonFormField<String>(
                value: _allowedUse,
                items: _allowedUses.map((u) => DropdownMenuItem(value: u, child: Text(_useLabel(u)))).toList(),
                onChanged: (v) => setState(() => _allowedUse = v!),
                decoration: _dec(),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Checkbox(value: _confidential, onChanged: (v) => setState(() => _confidential = v!)),
                const SizedBox(width: 8),
                const Text('Mark as confidential'),
              ]),
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
          summary: _summaryCtrl.text.trim().isEmpty ? null : _summaryCtrl.text.trim(),
          industry: _industryCtrl.text.trim().isEmpty ? null : _industryCtrl.text.trim(),
          geography: _geoCtrl.text.trim().isEmpty ? null : _geoCtrl.text.trim(),
          confidential: _confidential,
          allowedUse: _allowedUse,
        );
      } else {
        await widget.repo.update(widget.record!['id'] as String, {
          'title': _titleCtrl.text.trim(),
          'summary': _summaryCtrl.text.trim().isEmpty ? null : _summaryCtrl.text.trim(),
          'industry': _industryCtrl.text.trim().isEmpty ? null : _industryCtrl.text.trim(),
          'geography': _geoCtrl.text.trim().isEmpty ? null : _geoCtrl.text.trim(),
          'confidential': _confidential,
          'allowedUse': _allowedUse,
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
  InputDecoration _dec({String? hint}) => InputDecoration(hintText: hint, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), isDense: true);
  String _fmt(String s) => s.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  String _useLabel(String u) {
    switch (u) {
      case 'outreach_allowed': return 'Outreach allowed';
      case 'proposal_allowed': return 'Proposals allowed';
      default: return 'Internal only';
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.publicAccent : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppTheme.publicAccent : AppTheme.publicLine),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.publicText,
          ),
        ),
      ),
    );
  }
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
            Icon(Icons.library_books_outlined, size: 48, color: AppTheme.publicMuted.withOpacity(.4)),
            const SizedBox(height: 16),
            Text('No evidence records yet', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Add case studies, capability statements, and proof points\nto strengthen your proposals and outreach.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.publicMuted),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add evidence'),
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
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color ?? AppTheme.publicMuted)),
    );
  }
}
