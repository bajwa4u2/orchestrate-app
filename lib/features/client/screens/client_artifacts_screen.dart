import 'package:flutter/material.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/client/client_artifacts_repository.dart';

class ClientArtifactsScreen extends StatefulWidget {
  const ClientArtifactsScreen({super.key});

  @override
  State<ClientArtifactsScreen> createState() => _ClientArtifactsScreenState();
}

class _ClientArtifactsScreenState extends State<ClientArtifactsScreen> {
  final _repo = ClientArtifactsRepository();
  List<Map<String, dynamic>>? _artifacts;
  bool _loading = true;
  String? _error;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _repo.list();
      if (!mounted) return;
      setState(() { _artifacts = data; _loading = false; });
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
              'Artifacts',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            FilledButton.icon(
              onPressed: _generating ? null : () => _showGenerateDialog(context),
              icon: _generating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_fix_high_outlined, size: 18),
              label: const Text('Generate'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Identity reports, capability documents, and proposal drafts generated from your identity.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.publicMuted),
        ),
        const SizedBox(height: 24),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          _ErrorCard(message: _error!, onRetry: _load)
        else if (_artifacts!.isEmpty)
          _EmptyState(onGenerate: () => _showGenerateDialog(context))
        else
          ...(_artifacts!.map((a) => _ArtifactCard(
                artifact: a,
                onRefresh: _load,
                onArchive: () => _archive(a['id'] as String),
              ))),
      ],
    );
  }

  Future<void> _archive(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive artifact?'),
        content: const Text('This artifact will be removed from the list.'),
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

  Future<void> _showGenerateDialog(BuildContext context) async {
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (ctx) => const _GenerateDialog(),
    );
    if (result == null) return;
    setState(() => _generating = true);
    try {
      await _repo.generate(
        artifactType: result['artifactType']!,
        title: result['title']?.isEmpty == true ? null : result['title'],
      );
      if (!mounted) return;
      setState(() => _generating = false);
      _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _generating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

class _ArtifactCard extends StatelessWidget {
  const _ArtifactCard({required this.artifact, required this.onRefresh, required this.onArchive});
  final Map<String, dynamic> artifact;
  final VoidCallback onRefresh;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final status = artifact['status'] as String? ?? 'generating';
    final artifactType = artifact['artifactType'] as String? ?? '';
    final createdAt = artifact['createdAt'] as String? ?? '';
    final completedAt = artifact['completedAt'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Row(
        children: [
          Icon(_iconFor(artifactType), size: 24, color: AppTheme.publicMuted),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  artifact['title'] as String? ?? '',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _Chip(label: _typeLabel(artifactType)),
                    _Chip(label: _statusLabel(status), color: _statusColor(status)),
                    _Chip(label: _date(createdAt)),
                  ],
                ),
                if (artifact['errorMessage'] != null) ...[
                  const SizedBox(height: 6),
                  Text(artifact['errorMessage'] as String, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (status == 'generating')
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else if (status == 'ready')
                IconButton(
                  icon: const Icon(Icons.download_outlined),
                  tooltip: 'Download',
                  onPressed: () => _download(context),
                ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'archive') onArchive();
                  if (v == 'refresh') onRefresh();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'refresh', child: Text('Refresh')),
                  const PopupMenuItem(value: 'archive', child: Text('Archive')),
                ],
                child: const Icon(Icons.more_horiz, color: AppTheme.publicMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _download(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Open the download URL from your API client. In-browser download coming soon.')),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'identity_report': return Icons.analytics_outlined;
      case 'capability_document': return Icons.description_outlined;
      case 'proposal_draft': return Icons.edit_document;
      default: return Icons.insert_drive_file_outlined;
    }
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'identity_report': return 'Identity Report';
      case 'capability_document': return 'Capability Doc';
      case 'proposal_draft': return 'Proposal';
      default: return t;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'generating': return 'Generating…';
      case 'ready': return 'Ready';
      case 'failed': return 'Failed';
      case 'archived': return 'Archived';
      default: return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'ready': return Colors.green;
      case 'failed': return Colors.red;
      case 'generating': return Colors.orange;
      default: return AppTheme.publicMuted;
    }
  }

  String _date(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso.substring(0, 10);
    }
  }
}

class _GenerateDialog extends StatefulWidget {
  const _GenerateDialog();

  @override
  State<_GenerateDialog> createState() => _GenerateDialogState();
}

class _GenerateDialogState extends State<_GenerateDialog> {
  String _artifactType = 'identity_report';
  final _titleCtrl = TextEditingController();

  static const _types = [
    ('identity_report', 'Identity Report', 'A complete snapshot of your client identity across all domains.'),
    ('capability_document', 'Capability Statement', 'Your organisation\'s capabilities, differentiators, and proof points.'),
    ('proposal_draft', 'Proposal Draft', 'A structured proposal template with your identity pre-populated.'),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generate Artifact'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose the type of document to generate from your current identity.', style: TextStyle(color: AppTheme.publicMuted)),
            const SizedBox(height: 16),
            ..._types.map(((String, String, String) t) => RadioListTile<String>(
              value: t.$1,
              groupValue: _artifactType,
              title: Text(t.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(t.$3),
              onChanged: (v) => setState(() => _artifactType = v!),
              contentPadding: EdgeInsets.zero,
            )),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Custom title (optional)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            'artifactType': _artifactType,
            'title': _titleCtrl.text.trim(),
          }),
          child: const Text('Generate'),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onGenerate});
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.analytics_outlined, size: 48, color: AppTheme.publicMuted.withOpacity(.4)),
            const SizedBox(height: 16),
            Text('No artifacts yet', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Generate identity reports, capability documents, and\nproposal drafts from your configured identity.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.publicMuted),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
              label: const Text('Generate artifact'),
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
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(AppTheme.radius), border: Border.all(color: Colors.red.shade200)),
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
