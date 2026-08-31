import 'package:flutter/material.dart';

import 'package:orchestrate_app/data/repositories/public_repository.dart';

const _field = Color(0xFF0B1825);
const _fieldRaised = Color(0xFF10283A);
const _fieldDeep = Color(0xFF07111C);
const _line = Color(0xFF2D5360);
const _teal = Color(0xFF6FD3C3);
const _tealSoft = Color(0xFFB8EEE6);
const _muted = Color(0xFFA9BFCA);
const _blue = Color(0xFF7EAEFF);
const _amber = Color(0xFFF0C56A);

/// The public lifecycle flagship.
///
/// The backend decides which records are eligible for public presentation.
/// This widget owns only their visual expression; it never invents values,
/// visibility, ordering, or conversion mathematics.
class PublicOverviewWidget extends StatefulWidget {
  const PublicOverviewWidget({super.key});

  @override
  State<PublicOverviewWidget> createState() => _PublicOverviewWidgetState();
}

class _PublicOverviewWidgetState extends State<PublicOverviewWidget> {
  final PublicRepository _repository = PublicRepository();
  Map<String, dynamic>? _payload;
  Object? _error;
  bool _loading = true;
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _repository.fetchLifecycle();
      if (!mounted) return;
      setState(() {
        _payload = result;
        _loading = false;
        _selected = 0;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final nodes = _nodes;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final viewportWidth = MediaQuery.sizeOf(context).width;
        final contentWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : (viewportWidth - 56).clamp(0, 1320).toDouble();
        final duration = MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 260);

        return Container(
          width: contentWidth,
          padding: EdgeInsets.fromLTRB(
            compact ? 18 : 32,
            compact ? 22 : 30,
            compact ? 18 : 32,
            compact ? 20 : 30,
          ),
          decoration: BoxDecoration(
            color: _field,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF28515E)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: _loading
              ? _LoadingField(compact: compact)
              : _error != null
                  ? _UnavailableField(onRetry: _load)
                  : nodes.isEmpty
                      ? const _EmptyField()
                      : _GraphField(
                          nodes: nodes,
                          selected:
                              _selected.clamp(0, nodes.length - 1).toInt(),
                          compact: compact,
                          duration: duration,
                          onSelect: (index) =>
                              setState(() => _selected = index),
                        ),
        );
      },
    );
  }

  List<_LifecycleNode> get _nodes {
    final raw = (_payload?['cards'] as List?) ?? const [];
    return [
      for (final item in raw)
        if (item is Map)
          _LifecycleNode.fromJson(Map<String, dynamic>.from(item)),
    ];
  }
}

class _GraphField extends StatelessWidget {
  const _GraphField({
    required this.nodes,
    required this.selected,
    required this.compact,
    required this.duration,
    required this.onSelect,
  });

  final List<_LifecycleNode> nodes;
  final int selected;
  final bool compact;
  final Duration duration;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final stages = nodes.where((node) => node.kind != 'ASSET').toList();
    final assets = nodes.where((node) => node.kind == 'ASSET').toList();
    final active = nodes[selected];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FlagshipHeading(compact: compact, count: nodes.length),
        SizedBox(height: compact ? 22 : 30),
        _RailLabel(
          label: 'COMMERCIAL EXECUTION',
          detail: 'surfaced operating records',
          color: _teal,
          compact: compact,
        ),
        const SizedBox(height: 12),
        _ExecutionRail(
          nodes: stages,
          allNodes: nodes,
          compact: compact,
          selected: selected,
          duration: duration,
          onSelect: onSelect,
        ),
        if (assets.isNotEmpty) ...[
          SizedBox(height: compact ? 22 : 28),
          _RailLabel(
            label: 'RETAINED OPERATING INTELLIGENCE',
            detail: 'assets already available to the system',
            color: _blue,
            compact: compact,
          ),
          const SizedBox(height: 12),
          _AssetRail(
            nodes: assets,
            allNodes: nodes,
            compact: compact,
            selected: selected,
            duration: duration,
            onSelect: onSelect,
          ),
        ],
        SizedBox(height: compact ? 18 : 24),
        AnimatedSwitcher(
          duration: duration,
          child: _SelectedRecord(
            key: ValueKey(active.key),
            node: active,
            compact: compact,
          ),
        ),
      ],
    );
  }
}

class _FlagshipHeading extends StatelessWidget {
  const _FlagshipHeading({required this.compact, required this.count});

  final bool compact;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'LIVE OPERATING RECORD',
                style: TextStyle(
                  color: _teal,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Orchestrate operating.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 28 : 42,
                  height: 1.02,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.1,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'A current database snapshot of the commercial records the system is carrying forward.',
                style: TextStyle(color: _muted, fontSize: 14, height: 1.5),
              ),
            ],
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: _fieldDeep,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('SURFACED NOW',
                    style: TextStyle(
                        color: _muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text('$count records',
                    style: const TextStyle(
                        color: _tealSoft,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _RailLabel extends StatelessWidget {
  const _RailLabel(
      {required this.label,
      required this.detail,
      required this.color,
      required this.compact});

  final String label;
  final String detail;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final labelRow = Row(
      children: [
        Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 9),
        Flexible(
          child: Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2)),
        ),
      ],
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          labelRow,
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 4),
            child: Text(detail,
                style: const TextStyle(color: _muted, fontSize: 11)),
          ),
        ],
      );
    }
    return Row(
      children: [
        labelRow,
        const SizedBox(width: 10),
        Flexible(
            child: Text(detail,
                style: const TextStyle(color: _muted, fontSize: 11))),
      ],
    );
  }
}

class _ExecutionRail extends StatelessWidget {
  const _ExecutionRail(
      {required this.nodes,
      required this.allNodes,
      required this.compact,
      required this.selected,
      required this.duration,
      required this.onSelect});

  final List<_LifecycleNode> nodes;
  final List<_LifecycleNode> allNodes;
  final bool compact;
  final int selected;
  final Duration duration;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return SizedBox(
        width: double.infinity,
        child: _VerticalRail(
          nodes: nodes,
          allNodes: allNodes,
          selected: selected,
          duration: duration,
          onSelect: onSelect,
        ),
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 12,
      children: [
        for (var i = 0; i < nodes.length; i++) ...[
          _NodeButton(
              node: nodes[i],
              selected: allNodes.indexOf(nodes[i]) == selected,
              compact: false,
              duration: duration,
              onTap: () => onSelect(allNodes.indexOf(nodes[i]))),
          if (i < nodes.length - 1) const _RailConnector(),
        ],
      ],
    );
  }
}

class _AssetRail extends StatelessWidget {
  const _AssetRail(
      {required this.nodes,
      required this.allNodes,
      required this.compact,
      required this.selected,
      required this.duration,
      required this.onSelect});

  final List<_LifecycleNode> nodes;
  final List<_LifecycleNode> allNodes;
  final bool compact;
  final int selected;
  final Duration duration;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final node in nodes)
            _NodeButton(
                node: node,
                selected: allNodes.indexOf(node) == selected,
                compact: compact,
                duration: duration,
                onTap: () => onSelect(allNodes.indexOf(node))),
        ],
      ),
    );
  }
}

class _VerticalRail extends StatelessWidget {
  const _VerticalRail(
      {required this.nodes,
      required this.allNodes,
      required this.selected,
      required this.duration,
      required this.onSelect});

  final List<_LifecycleNode> nodes;
  final List<_LifecycleNode> allNodes;
  final int selected;
  final Duration duration;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth =
              constraints.hasBoundedWidth ? constraints.maxWidth : 220.0;
          final cardWidth =
              (availableWidth - 21).clamp(0, double.infinity).toDouble();
          return Column(
            children: [
              for (var i = 0; i < nodes.length; i++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                                color: _teal, shape: BoxShape.circle)),
                        if (i < nodes.length - 1)
                          Container(width: 1, height: 44, color: _line),
                      ],
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: cardWidth,
                      child: _NodeButton(
                          node: nodes[i],
                          selected: allNodes.indexOf(nodes[i]) == selected,
                          compact: true,
                          duration: duration,
                          onTap: () => onSelect(allNodes.indexOf(nodes[i]))),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      );
}

class _RailConnector extends StatelessWidget {
  const _RailConnector();

  @override
  Widget build(BuildContext context) => const SizedBox(
      width: 18,
      child: Center(child: Icon(Icons.arrow_forward, color: _teal, size: 14)));
}

class _NodeButton extends StatelessWidget {
  const _NodeButton(
      {required this.node,
      required this.selected,
      required this.compact,
      required this.duration,
      required this.onTap});

  final _LifecycleNode node;
  final bool selected;
  final bool compact;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final asset = node.kind == 'ASSET';
    final accent = asset ? _blue : _teal;
    return Semantics(
      button: true,
      selected: selected,
      label: '${node.label}, ${node.valueText} ${node.suffix}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: duration,
          width: compact ? double.infinity : 164,
          padding:
              EdgeInsets.fromLTRB(compact ? 14 : 15, 13, compact ? 14 : 15, 14),
          decoration: BoxDecoration(
            color: selected ? _fieldRaised : _fieldDeep,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? accent : _line, width: selected ? 1.3 : 0.8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(node.label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: accent,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.05)),
                    const SizedBox(height: 8),
                    Text(node.valueText,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 22 : 25,
                            fontWeight: FontWeight.w700,
                            height: 1)),
                    const SizedBox(height: 5),
                    Text(node.suffix,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _muted, fontSize: 10, height: 1.25)),
                    if (node.amountText != null) ...[
                      const SizedBox(height: 7),
                      Text(node.amountText!,
                          style: const TextStyle(
                              color: _amber,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
              ),
              if (selected) Icon(Icons.north_east, color: accent, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedRecord extends StatelessWidget {
  const _SelectedRecord({super.key, required this.node, required this.compact});

  final _LifecycleNode node;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 14 : 16),
        decoration: BoxDecoration(
            color: const Color(0xFF112D38),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF356873))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.insights_outlined, color: _tealSoft, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(
                      color: _muted, fontSize: 12, height: 1.45),
                  children: [
                    TextSpan(
                        text: node.label,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                    TextSpan(
                        text:
                            ' is currently surfaced as ${node.kind == 'ASSET' ? 'retained operating intelligence' : 'a commercial execution record'} with ${node.valueText} ${node.suffix}.'),
                    if (node.amountText != null)
                      TextSpan(text: ' Recorded amount: ${node.amountText}.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _LoadingField extends StatelessWidget {
  const _LoadingField({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('LIVE OPERATING RECORD',
              style: TextStyle(
                  color: _teal,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6)),
          const SizedBox(height: 16),
          Text('Orchestrate operating.',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 28 : 42,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 24),
          SizedBox(
              height: compact ? 150 : 190,
              child: Center(
                  child:
                      CircularProgressIndicator(color: _teal, strokeWidth: 2))),
        ],
      );
}

class _EmptyField extends StatelessWidget {
  const _EmptyField();
  @override
  Widget build(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LIVE OPERATING RECORD',
              style: TextStyle(
                  color: _teal,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6)),
          SizedBox(height: 16),
          Text('Nothing is surfaced yet.',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Text(
              'The public projection currently contains no eligible operating records. The system has not manufactured a substitute view.',
              style: TextStyle(color: _muted, fontSize: 13, height: 1.5)),
        ],
      );
}

class _UnavailableField extends StatelessWidget {
  const _UnavailableField({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('LIVE OPERATING RECORD',
              style: TextStyle(
                  color: _teal,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6)),
          const SizedBox(height: 16),
          const Text('The operating record is unavailable.',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
              'The public authority could not be reached. This is different from an empty operating record.',
              style: TextStyle(color: _muted, fontSize: 13, height: 1.5)),
          const SizedBox(height: 18),
          OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: _tealSoft,
                  side: const BorderSide(color: _line))),
        ],
      );
}

class _LifecycleNode {
  const _LifecycleNode(
      {required this.key,
      required this.label,
      required this.suffix,
      required this.kind,
      required this.value,
      this.amountCents});

  factory _LifecycleNode.fromJson(Map<String, dynamic> json) => _LifecycleNode(
        key: '${json['key'] ?? ''}',
        label: '${json['label'] ?? json['key'] ?? ''}',
        suffix: '${json['suffix'] ?? ''}',
        kind: '${json['kind'] ?? 'STAGE'}',
        value: _number(json['value']),
        amountCents: _numberOrNull(json['amountCents']),
      );

  final String key;
  final String label;
  final String suffix;
  final String kind;
  final num value;
  final num? amountCents;

  String get valueText => value.toInt().toString();
  String? get amountText => amountCents != null && amountCents! > 0
      ? '\$${_formatAmount(amountCents! / 100)}'
      : null;

  static num _number(dynamic value) =>
      value is num ? value : num.tryParse('$value') ?? 0;
  static num? _numberOrNull(dynamic value) =>
      value == null ? null : _number(value);

  static String _formatAmount(num value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = parts.first;
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
      buffer.write(whole[i]);
    }
    return '${buffer.toString()}.${parts.last}';
  }
}
