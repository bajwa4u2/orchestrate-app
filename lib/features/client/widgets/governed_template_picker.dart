import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/client/client_portal_repository.dart';

/// Governed template picker (sequence-authoring helper, focused MVP).
///
/// Doctrine
/// --------
/// SequenceStep authoring should eventually let an operator (and
/// later a client) choose between:
///   - A GOVERNED TEMPLATE step (the new path) where the operator
///     picks a catalog template key, binds approved variables, and
///     the renderer attaches template provenance on the wire.
///   - A LEGACY / CUSTOM step (the existing path) where
///     SequenceStep.subjectTemplate / bodyTemplate carry hand-written
///     copy. The wire carries operation / thread / lane / lifecycle
///     / attempt provenance but does NOT claim template provenance.
///   - A FUTURE BOUNDED-AI step (scaffolded only): the model selects
///     a governed template and binds approved variables; not yet
///     implemented (see ai-governance.ts in the backend).
///
/// This widget is the GOVERNED-template half of that picker. It
/// stands alone today so it can be embedded in any operator or
/// client sequence-authoring screen without committing to a full new
/// screen yet. Backend authoring endpoints (POST /sequences/steps)
/// do not exist as of this commit — this picker shows the catalog
/// and renders previews; persistence is a later pass.
class GovernedTemplatePicker extends StatefulWidget {
  const GovernedTemplatePicker({
    super.key,
    this.repository,
    this.laneFilter,
    this.lifecycleStageFilter,
    this.onTemplateSelected,
  });

  final ClientPortalRepository? repository;

  /// Filter the catalog list to a specific lane (opportunity / revenue
  /// / shared). Omit to show all lanes.
  final String? laneFilter;

  /// Filter the catalog to a specific lifecycle stage. Omit to show
  /// all stages.
  final String? lifecycleStageFilter;

  /// Notifier for when the operator selects a template key + binds
  /// variables. Useful when this widget is embedded inside a larger
  /// authoring screen that persists the choice onto a SequenceStep
  /// row.
  final void Function(String templateKey, Map<String, dynamic> variables)?
      onTemplateSelected;

  @override
  State<GovernedTemplatePicker> createState() => _GovernedTemplatePickerState();
}

class _GovernedTemplatePickerState extends State<GovernedTemplatePicker> {
  late final ClientPortalRepository _repository =
      widget.repository ?? ClientPortalRepository();

  bool _loadingList = true;
  String? _listError;
  List<Map<String, dynamic>> _templates = const [];
  String? _selectedKey;
  Map<String, dynamic>? _selectedTemplate;
  final Map<String, TextEditingController> _variableControllers = {};

  bool _previewing = false;
  Map<String, dynamic>? _previewResult;
  String? _previewError;

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  @override
  void dispose() {
    for (final c in _variableControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadList() async {
    setState(() {
      _loadingList = true;
      _listError = null;
    });
    try {
      final all = await _repository.fetchMessageTemplates();
      _templates = all
          .map((row) => row is Map
              ? row.map((k, v) => MapEntry('$k', v))
              : <String, dynamic>{})
          .where((tpl) {
            if (widget.laneFilter != null &&
                tpl['lane']?.toString() != widget.laneFilter) {
              return false;
            }
            if (widget.lifecycleStageFilter != null &&
                tpl['lifecycleStage']?.toString() !=
                    widget.lifecycleStageFilter) {
              return false;
            }
            return true;
          })
          .toList();
    } catch (error) {
      _listError = error.toString();
    } finally {
      if (mounted) setState(() => _loadingList = false);
    }
  }

  Future<void> _selectTemplate(String key) async {
    setState(() {
      _selectedKey = key;
      _selectedTemplate = null;
      _previewResult = null;
      _previewError = null;
      _disposeVarControllers();
    });
    try {
      final detail = await _repository.fetchMessageTemplate(key);
      _selectedTemplate = detail;
      final required =
          (detail['requiredVariables'] as List? ?? const []).cast<dynamic>();
      final allowed =
          (detail['allowedVariables'] as List? ?? const []).cast<dynamic>();
      for (final name in [...required, ...allowed]) {
        _variableControllers[name.toString()] = TextEditingController();
      }
    } catch (error) {
      _previewError = error.toString();
    } finally {
      if (mounted) setState(() {});
    }
  }

  void _disposeVarControllers() {
    for (final c in _variableControllers.values) {
      c.dispose();
    }
    _variableControllers.clear();
  }

  Map<String, dynamic> _gatherVariables() {
    final out = <String, dynamic>{};
    _variableControllers.forEach((key, ctrl) {
      final text = ctrl.text.trim();
      if (text.isNotEmpty) out[key] = text;
    });
    return out;
  }

  Future<void> _runPreview() async {
    final key = _selectedKey;
    if (key == null) return;
    setState(() {
      _previewing = true;
      _previewResult = null;
      _previewError = null;
    });
    try {
      final result = await _repository.previewMessageTemplate(
        key,
        _gatherVariables(),
      );
      _previewResult = result;
    } catch (error) {
      _previewError = error.toString();
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  void _commitSelection() {
    final key = _selectedKey;
    if (key == null) return;
    widget.onTemplateSelected?.call(key, _gatherVariables());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree_outlined,
                  size: 16, color: AppTheme.publicMuted),
              const SizedBox(width: 8),
              Text(
                'Governed template',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.publicMuted,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Pick a governed template family for this step. The renderer enforces required variables and never lets the body claim a template provenance it did not use.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.publicMuted,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 16),
          if (_loadingList)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_listError != null)
            _errorRow(_listError!, _loadList)
          else
            _renderList(context),
          if (_selectedTemplate != null) ...[
            const Divider(height: 24),
            _renderDetail(context, _selectedTemplate!),
          ],
        ],
      ),
    );
  }

  Widget _renderList(BuildContext context) {
    if (_templates.isEmpty) {
      return Text(
        'No governed templates match the requested filter.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.publicMuted,
            ),
      );
    }
    return Column(
      children: [
        for (final tpl in _templates) ...[
          _renderTemplateRow(context, tpl),
          if (tpl != _templates.last) const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _renderTemplateRow(BuildContext context, Map<String, dynamic> tpl) {
    final key = tpl['key']?.toString() ?? '';
    final lane = tpl['lane']?.toString() ?? '';
    final stage = tpl['lifecycleStage']?.toString() ?? '';
    final version = tpl['version']?.toString() ?? '';
    final selected = key == _selectedKey;
    return InkWell(
      onTap: () => _selectTemplate(key),
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.publicAccentSoft : AppTheme.publicSurfaceSoft,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(
            color: selected ? AppTheme.publicText : AppTheme.publicLine,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    key,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.publicText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tpl['subjectPreview']?.toString() ?? '',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.publicMuted,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Wrap(
              spacing: 6,
              children: [
                _miniPill('lane', lane),
                _miniPill('stage', stage),
                _miniPill('v', version),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _renderDetail(BuildContext context, Map<String, dynamic> detail) {
    final required =
        (detail['requiredVariables'] as List? ?? const []).cast<dynamic>();
    final allowed =
        (detail['allowedVariables'] as List? ?? const []).cast<dynamic>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Variables',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.publicText,
              ),
        ),
        const SizedBox(height: 8),
        if (required.isEmpty && allowed.isEmpty)
          Text(
            'This template has no variables.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          )
        else ...[
          for (final name in required) _varField(name.toString(), required: true),
          for (final name in allowed) _varField(name.toString(), required: false),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: _previewing ? null : _runPreview,
              child: Text(_previewing ? 'Rendering…' : 'Render preview'),
            ),
            if (widget.onTemplateSelected != null)
              FilledButton(
                onPressed: _commitSelection,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.publicText,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Use this template'),
              ),
          ],
        ),
        if (_previewError != null) ...[
          const SizedBox(height: 12),
          Text(
            _previewError!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
        ],
        if (_previewResult != null) ...[
          const SizedBox(height: 12),
          _renderPreviewResult(context, _previewResult!),
        ],
        const SizedBox(height: 12),
        Text(
          'Compliance: ${detail['complianceNotes'] ?? '—'}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.publicMuted,
                height: 1.45,
              ),
        ),
      ],
    );
  }

  Widget _varField(String name, {required bool required}) {
    final controller = _variableControllers[name];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: required ? '$name *' : name,
          hintText: required ? 'Required' : 'Optional',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _renderPreviewResult(BuildContext context, Map<String, dynamic> r) {
    if (r['ok'] == false) {
      final reason = (r['reason'] ?? '').toString();
      final missing = (r['missing'] as List? ?? const []).join(', ');
      final unknown = (r['unknown'] as List? ?? const []).join(', ');
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.publicSurfaceSoft,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.publicLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reason == 'MISSING_REQUIRED_VARIABLE'
                  ? 'Missing required variables'
                  : reason == 'UNKNOWN_VARIABLE'
                      ? 'Unknown variables supplied'
                      : 'Preview unavailable',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
            if (missing.isNotEmpty)
              Text(
                'Missing: $missing',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (unknown.isNotEmpty)
              Text(
                'Unknown: $unknown',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      );
    }
    final rendered =
        (r['rendered'] as Map?)?.cast<String, dynamic>() ?? const {};
    final subject = rendered['subject']?.toString() ?? '';
    final body = rendered['body']?.toString() ?? '';
    final templateKey = rendered['templateKey']?.toString() ?? '';
    final templateVersion = rendered['templateVersion']?.toString() ?? '';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subject',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.publicMuted,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            subject,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.publicText,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'Body',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.publicMuted,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            body,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.5,
              height: 1.45,
              color: AppTheme.publicText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Will stamp template: $templateKey · v$templateVersion',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.publicAccent,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  Widget _miniPill(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: AppTheme.publicMuted,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _errorRow(String message, Future<void> Function() retry) {
    return Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        TextButton(onPressed: () => retry(), child: const Text('Retry')),
      ],
    );
  }
}
