import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/operator_repository.dart';

class OperatorSystemDoctorScreen extends StatefulWidget {
  const OperatorSystemDoctorScreen({super.key});

  @override
  State<OperatorSystemDoctorScreen> createState() =>
      _OperatorSystemDoctorScreenState();
}

class _OperatorSystemDoctorScreenState
    extends State<OperatorSystemDoctorScreen> {
  final _issueController = TextEditingController(
    text:
        'Operator control is showing failed, blocked, or missing operating status.',
  );
  final _expectedController = TextEditingController(
    text:
        'Operator should identify the affected layer, evidence, safe fix plan, and validation steps.',
  );
  final _observedController = TextEditingController();
  final _logsController = TextEditingController();

  Map<String, dynamic>? _result;
  String? _message;
  bool _running = false;

  @override
  void dispose() {
    _issueController.dispose();
    _expectedController.dispose();
    _observedController.dispose();
    _logsController.dispose();
    super.dispose();
  }

  Future<void> _runDiagnosis() async {
    final issue = _issueController.text.trim();
    if (issue.isEmpty) {
      setState(() => _message = 'Describe the operating issue first.');
      return;
    }

    setState(() {
      _running = true;
      _message = null;
    });

    try {
      final result = await OperatorRepository().diagnoseSystem(
        issue: issue,
        expectedBehavior: _expectedController.text,
        observedBehavior: _observedController.text,
        logs: _logsController.text
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList(),
      );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message =
            'System check could not run. Confirm operator access and AI system doctor setup.';
      });
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final diagnosis = _asMap(_result?['diagnosis']);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Hero(onRun: _running ? null : _runDiagnosis, running: _running),
          const SizedBox(height: 18),
          _InputPanel(
            issueController: _issueController,
            expectedController: _expectedController,
            observedController: _observedController,
            logsController: _logsController,
            message: _message,
            running: _running,
            onPreset: _applyPreset,
            onRun: _runDiagnosis,
          ),
          const SizedBox(height: 18),
          if (_running)
            const Center(child: CircularProgressIndicator())
          else if (diagnosis.isEmpty)
            const _EmptyDiagnosis()
          else
            _DiagnosisPanel(diagnosis: diagnosis),
        ],
      ),
    );
  }

  void _applyPreset(String value) {
    setState(() {
      _issueController.text = value;
      _expectedController.text =
          'Identify the issue, likely cause, recommended action, validation step, and rollback plan.';
      _observedController.clear();
      _logsController.clear();
      _message = null;
    });
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onRun, required this.running});

  final VoidCallback? onRun;
  final bool running;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _box(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('System Doctor',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: AppTheme.subdued)),
                const SizedBox(height: 8),
                Text('AI-assisted operating diagnosis',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 10),
                Text(
                  'Run a structured system check when a queue, worker, provider, campaign, billing flow, or control view is not behaving as expected.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          FilledButton.icon(
            onPressed: onRun,
            icon: running
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.health_and_safety_outlined),
            label: Text(running ? 'Running check' : 'Run diagnosis'),
          ),
        ],
      ),
    );
  }
}

class _InputPanel extends StatelessWidget {
  const _InputPanel({
    required this.issueController,
    required this.expectedController,
    required this.observedController,
    required this.logsController,
    required this.message,
    required this.running,
    required this.onPreset,
    required this.onRun,
  });

  final TextEditingController issueController;
  final TextEditingController expectedController;
  final TextEditingController observedController;
  final TextEditingController logsController;
  final String? message;
  final bool running;
  final ValueChanged<String> onPreset;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Check input', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final preset in const [
                'Queue not moving',
                'Campaign not sourcing',
                'Outreach not sending',
                'Replies not processing',
                'Billing records not visible',
              ])
                OutlinedButton(
                  onPressed: running ? null : () => onPreset(preset),
                  child: Text(preset),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: issueController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Operating issue',
              hintText: 'Describe the failure, blocked state, or mismatch.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: expectedController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Expected behavior'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: observedController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Observed behavior'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: logsController,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Evidence or logs',
              hintText: 'Optional. One item per line.',
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: running ? null : onRun,
            icon: const Icon(Icons.play_arrow_outlined),
            label: const Text('Run system check'),
          ),
        ],
      ),
    );
  }
}

class _EmptyDiagnosis extends StatelessWidget {
  const _EmptyDiagnosis();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No diagnosis yet',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Run a system check to produce readiness, issue, fix, rollback, and validation guidance.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _DiagnosisPanel extends StatelessWidget {
  const _DiagnosisPanel({required this.diagnosis});

  final Map<String, dynamic> diagnosis;

  @override
  Widget build(BuildContext context) {
    final severity = _read(diagnosis, 'severity', fallback: 'medium');
    final layer = _read(diagnosis, 'affectedLayer', fallback: 'unknown');
    final confidence = _confidence(diagnosis['confidence']);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Pill('Severity: ${severity.toUpperCase()}'),
              _Pill('Layer: $layer'),
              _Pill('Confidence: ${(confidence * 100).round()}%'),
            ],
          ),
          const SizedBox(height: 18),
          Text('Issue', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            _read(
              diagnosis,
              'rootCause',
              fallback: 'Root cause was not determined from the evidence.',
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          _ListBlock(title: 'Evidence', items: _list(diagnosis['proof'])),
          _ListBlock(
              title: 'Recommended action',
              items: _list(diagnosis['safeFixPlan'])),
          _ListBlock(
              title: 'Validation plan',
              items: _list(diagnosis['validationPlan'])),
          _ListBlock(
              title: 'Rollback plan', items: _list(diagnosis['rollbackPlan'])),
          _ListBlock(
              title: 'Open questions',
              items: _list(diagnosis['openQuestions'])),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Diagnostic details',
                style: Theme.of(context).textTheme.titleLarge),
            children: [
              _ListBlock(
                  title: 'Likely files',
                  items: _list(diagnosis['likelyFiles'])),
              _ListBlock(
                  title: 'Do not touch', items: _list(diagnosis['doNotTouch'])),
            ],
          ),
        ],
      ),
    );
  }
}

class _ListBlock extends StatelessWidget {
  const _ListBlock({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final item in items) ...[
            Text('- $item', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.panelRaised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.line),
      ),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

BoxDecoration _box() {
  return BoxDecoration(
    color: AppTheme.panel,
    borderRadius: BorderRadius.circular(AppTheme.radius),
    border: Border.all(color: AppTheme.line),
  );
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, item) => MapEntry('$key', item));
  return const <String, dynamic>{};
}

String _read(
  Map<String, dynamic> map,
  String key, {
  String fallback = '',
}) {
  final value = map[key];
  if (value == null) return fallback;
  final text = '$value'.trim();
  return text.isEmpty ? fallback : text;
}

List<String> _list(dynamic value) {
  return (value as List? ?? const [])
      .map((item) => '$item'.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

double _confidence(dynamic value) {
  if (value is num) return value.clamp(0, 1).toDouble();
  return double.tryParse('$value')?.clamp(0, 1).toDouble() ?? 0.5;
}
