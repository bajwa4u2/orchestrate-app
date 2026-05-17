import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/client/client_portal_repository.dart';
import 'package:orchestrate_app/features/client/widgets/governed_template_picker.dart';
import 'package:orchestrate_app/features/system/widgets/governance_primitives.dart';

/// SequenceStep authoring widget with three explicit modes.
///
/// Doctrine
/// --------
/// SequenceStep authoring must make the governance posture of each
/// step explicit to the operator/client at write time:
///
///   1. **Governed template** — pick a catalog key + bind approved
///      variables. The renderer validates variables; the dispatch
///      path stamps template provenance on the wire.
///
///   2. **Legacy / custom body** — write subject + body verbatim.
///      The dispatch path uses them but truthfully omits template
///      provenance. Workspace governance panel labels these as
///      "legacy sequence body" with no governed-template claim.
///
///   3. **Bounded-AI (future)** — placeholder mode that explains the
///      planned contract: AI selects a governed template and binds
///      approved variables; the renderer is the bottleneck. Not
///      enabled in this UI yet; the backend service is ready but a
///      pre-flight UX (operator review before dispatch) is still
///      being designed.
///
/// The widget posts directly to the new SequenceStep CRUD endpoints
/// on the client portal. When `existingStepId` is provided the
/// widget edits an existing row; otherwise it creates a new one on
/// the supplied `sequenceId`.
class SequenceStepAuthor extends StatefulWidget {
  const SequenceStepAuthor({
    super.key,
    required this.sequenceId,
    this.existingStep,
    this.repository,
    this.onSaved,
  });

  final String sequenceId;

  /// When set, the widget edits the supplied step (read from
  /// `/client/sequences/:sequenceId`). When null, a new step is
  /// created.
  final Map<String, dynamic>? existingStep;

  final ClientPortalRepository? repository;

  /// Fired with the saved step row after a successful write.
  final void Function(Map<String, dynamic> step)? onSaved;

  @override
  State<SequenceStepAuthor> createState() => _SequenceStepAuthorState();
}

enum _AuthoringMode { governed, legacy, boundedAi }

class _SequenceStepAuthorState extends State<SequenceStepAuthor> {
  late final ClientPortalRepository _repository =
      widget.repository ?? ClientPortalRepository();

  _AuthoringMode _mode = _AuthoringMode.governed;
  String? _selectedTemplateKey;
  Map<String, dynamic> _selectedTemplateVariables = const {};

  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _waitDaysCtrl = TextEditingController();
  final _instructionCtrl = TextEditingController();

  bool _saving = false;
  String? _error;
  String? _status;
  Map<String, dynamic>? _savedStep;

  @override
  void initState() {
    super.initState();
    _hydrateFromExisting();
  }

  void _hydrateFromExisting() {
    final step = widget.existingStep;
    if (step == null) return;
    _subjectCtrl.text = (step['subjectTemplate'] ?? '').toString();
    _bodyCtrl.text = (step['bodyTemplate'] ?? '').toString();
    _waitDaysCtrl.text = step['waitDays']?.toString() ?? '';
    _instructionCtrl.text = (step['instructionText'] ?? '').toString();
    _selectedTemplateKey = step['templateKey']?.toString();
    final vars = step['templateVariablesJson'];
    if (vars is Map) {
      _selectedTemplateVariables =
          vars.map((k, v) => MapEntry('$k', v));
    }
    final mode = (step['mode'] ?? '').toString();
    if (mode == 'governed') {
      _mode = _AuthoringMode.governed;
    } else if (mode == 'legacy') {
      _mode = _AuthoringMode.legacy;
    } else {
      _mode = _AuthoringMode.legacy;
    }
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    _waitDaysCtrl.dispose();
    _instructionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _status = null;
    });
    try {
      final waitDays = int.tryParse(_waitDaysCtrl.text.trim());
      Map<String, dynamic> result;
      if (widget.existingStep != null) {
        result = await _repository.updateSequenceStep(
          stepId: widget.existingStep!['id'].toString(),
          waitDays: waitDays,
          subjectTemplate: _mode == _AuthoringMode.legacy
              ? _trimToNull(_subjectCtrl.text)
              : null,
          bodyTemplate: _mode == _AuthoringMode.legacy
              ? _trimToNull(_bodyCtrl.text)
              : null,
          templateKey:
              _mode == _AuthoringMode.governed ? _selectedTemplateKey : null,
          templateVariables: _mode == _AuthoringMode.governed
              ? _selectedTemplateVariables
              : null,
          instructionText: _trimToNull(_instructionCtrl.text),
        );
      } else {
        result = await _repository.createSequenceStep(
          sequenceId: widget.sequenceId,
          waitDays: waitDays,
          subjectTemplate: _mode == _AuthoringMode.legacy
              ? _trimToNull(_subjectCtrl.text)
              : null,
          bodyTemplate: _mode == _AuthoringMode.legacy
              ? _trimToNull(_bodyCtrl.text)
              : null,
          templateKey:
              _mode == _AuthoringMode.governed ? _selectedTemplateKey : null,
          templateVariables: _mode == _AuthoringMode.governed
              ? _selectedTemplateVariables
              : null,
          instructionText: _trimToNull(_instructionCtrl.text),
        );
      }
      _savedStep = result;
      _status = widget.existingStep != null
          ? 'Step updated. Provenance will reflect this on next dispatch.'
          : 'Step created. The dispatch path will use it on the next eligible job.';
      widget.onSaved?.call(result);
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _trimToNull(String value) {
    final t = value.trim();
    return t.isEmpty ? null : t;
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
                widget.existingStep != null
                    ? 'Edit sequence step'
                    : 'New sequence step',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.publicMuted,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              _ModePill(mode: _mode),
            ],
          ),
          const SizedBox(height: 12),
          _renderModeSwitch(context),
          const SizedBox(height: 16),
          _renderModeContent(context),
          const SizedBox(height: 16),
          _renderCommon(context),
          const SizedBox(height: 16),
          _renderActions(context),
          if (_status != null) ...[
            const SizedBox(height: 12),
            Text(
              _status!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.publicAccent,
                  ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ],
          if (_savedStep != null) ...[
            const SizedBox(height: 16),
            ProvenanceChainStrip(
              operationId: null, // not yet dispatched
              threadId: null,
              templateKey: _savedStep!['templateKey']?.toString(),
              templateVersion: null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _renderModeSwitch(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _modeButton(
          context,
          mode: _AuthoringMode.governed,
          label: 'Governed template',
          tone: GovernanceTone.positive,
        ),
        _modeButton(
          context,
          mode: _AuthoringMode.legacy,
          label: 'Legacy custom body',
          tone: GovernanceTone.neutral,
        ),
        _modeButton(
          context,
          mode: _AuthoringMode.boundedAi,
          label: 'Bounded AI (preview)',
          tone: GovernanceTone.cautious,
          enabled: false,
        ),
      ],
    );
  }

  Widget _modeButton(
    BuildContext context, {
    required _AuthoringMode mode,
    required String label,
    required GovernanceTone tone,
    bool enabled = true,
  }) {
    final selected = _mode == mode;
    return OutlinedButton(
      onPressed: !enabled
          ? null
          : () => setState(() {
                _mode = mode;
                _status = null;
                _error = null;
              }),
      style: OutlinedButton.styleFrom(
        foregroundColor:
            selected ? AppTheme.publicText : AppTheme.publicMuted,
        backgroundColor:
            selected ? AppTheme.publicSurfaceSoft : Colors.transparent,
        side: BorderSide(
          color: selected ? AppTheme.publicText : AppTheme.publicLine,
          width: selected ? 1.4 : 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      child: Text(label),
    );
  }

  Widget _renderModeContent(BuildContext context) {
    switch (_mode) {
      case _AuthoringMode.governed:
        return _renderGovernedContent(context);
      case _AuthoringMode.legacy:
        return _renderLegacyContent(context);
      case _AuthoringMode.boundedAi:
        return _renderBoundedAiPreview(context);
    }
  }

  Widget _renderGovernedContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GovernanceBadge(
          label: 'Template provenance will be stamped on the wire',
          tone: GovernanceTone.positive,
        ),
        const SizedBox(height: 12),
        GovernedTemplatePicker(
          onTemplateSelected: (key, variables) {
            setState(() {
              _selectedTemplateKey = key;
              _selectedTemplateVariables = variables;
              _status =
                  'Template "$key" selected. Save to attach it to this step.';
            });
          },
        ),
        if (_selectedTemplateKey != null) ...[
          const SizedBox(height: 12),
          Text(
            'Bound template: $_selectedTemplateKey',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.publicAccent,
            ),
          ),
        ],
      ],
    );
  }

  Widget _renderLegacyContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GovernanceBadge(
          label:
              'Legacy custom body — governed template provenance will not be claimed',
          tone: GovernanceTone.cautious,
        ),
        const SizedBox(height: 8),
        Text(
          'The dispatch path will still attach operation, thread, lane, lifecycle, and attempt headers — only the template-key / template-version headers are omitted, truthfully.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.publicMuted,
                height: 1.45,
              ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _subjectCtrl,
          decoration: InputDecoration(
            labelText: 'Subject template',
            hintText: '{{prospectFirstName}} — quick note',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _bodyCtrl,
          minLines: 5,
          maxLines: 12,
          decoration: InputDecoration(
            labelText: 'Body template',
            alignLabelWithHint: true,
            hintText: 'Hi {{prospectFirstName}}, …',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
          ),
        ),
      ],
    );
  }

  Widget _renderBoundedAiPreview(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BoundedAIIndicator(bodySource: 'catalog'),
          const SizedBox(height: 8),
          Text(
            'Bounded AI selects a governed template and binds approved variables — it does not write a free-form body. The catalog renderer remains the source of truth for subject and body.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.publicMuted,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Backend support is live. UI activation is paused pending operator-review UX (the bounded draft should be reviewed before it is bound to a step). Use "Governed template" for now if you want template provenance, or "Legacy custom body" for a hand-authored step.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.publicMuted,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }

  Widget _renderCommon(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _waitDaysCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Wait days (before next step)',
              hintText: '2',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: TextField(
            controller: _instructionCtrl,
            decoration: InputDecoration(
              labelText: 'Operator instruction (optional)',
              hintText: 'Internal note for the operator',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _renderActions(BuildContext context) {
    final canSave = _mode != _AuthoringMode.boundedAi &&
        (_mode == _AuthoringMode.legacy
            ? _bodyCtrl.text.trim().isNotEmpty
            : _selectedTemplateKey != null);
    return Row(
      children: [
        FilledButton(
          onPressed: (_saving || !canSave) ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.publicText,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          child: Text(_saving ? 'Saving…' : 'Save step'),
        ),
        const SizedBox(width: 12),
        if (_savedStep != null)
          BodySourcePill(
            bodySource: _savedStep!['mode'] == 'governed'
                ? 'catalog'
                : _savedStep!['mode'] == 'legacy'
                    ? 'sequence_legacy'
                    : null,
            templateKey: _savedStep!['templateKey']?.toString(),
          ),
      ],
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({required this.mode});
  final _AuthoringMode mode;

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case _AuthoringMode.governed:
        return const GovernanceBadge(
          label: 'governed',
          tone: GovernanceTone.positive,
        );
      case _AuthoringMode.legacy:
        return const GovernanceBadge(
          label: 'legacy',
          tone: GovernanceTone.neutral,
        );
      case _AuthoringMode.boundedAi:
        return const GovernanceBadge(
          label: 'bounded AI (preview)',
          tone: GovernanceTone.cautious,
        );
    }
  }
}
