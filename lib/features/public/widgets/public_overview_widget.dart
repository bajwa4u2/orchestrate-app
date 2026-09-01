import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:orchestrate_app/data/repositories/public_repository.dart';

const _field = Color(0xFF0B1825);
const _deep = Color(0xFF07111C);
const _line = Color(0xFF2D5360);
const _teal = Color(0xFF6FD3C3);
const _soft = Color(0xFFB8EEE6);
const _muted = Color(0xFFA9BFCA);
const _blue = Color(0xFF7EAEFF);

/// Live public lifecycle projection. The backend owns surfaced records,
/// ordering, values and hidden/zero behavior; this widget owns expression.
class PublicOverviewWidget extends StatefulWidget {
  const PublicOverviewWidget({super.key});
  @override
  State<PublicOverviewWidget> createState() => _PublicOverviewWidgetState();
}

class _PublicOverviewWidgetState extends State<PublicOverviewWidget> {
  final _repository = PublicRepository();
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

  List<_LifecycleNode> get _nodes {
    final raw = (_payload?['cards'] as List?) ?? const [];
    return [
      for (final item in raw)
        if (item is Map)
          _LifecycleNode.fromJson(Map<String, dynamic>.from(item))
    ];
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final width = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : (MediaQuery.sizeOf(context).width - 56)
                  .clamp(0, 1320)
                  .toDouble();
          final duration = MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 260);
          final nodes = _nodes;
          return SizedBox(
            width: width,
            child: DecoratedBox(
              decoration: const BoxDecoration(color: _field),
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: compact ? 2 : 10, vertical: compact ? 20 : 28),
                child: _loading
                    ? _LoadingField(compact: compact)
                    : _error != null
                        ? _UnavailableField(onRetry: _load)
                        : nodes.isEmpty
                            ? const _EmptyField()
                            : _FlagshipField(
                                nodes: nodes,
                                selected: _selected.clamp(0, nodes.length - 1),
                                compact: compact,
                                duration: duration,
                                onSelect: (i) => setState(() => _selected = i)),
              ),
            ),
          );
        },
      );
}

class _FlagshipField extends StatelessWidget {
  const _FlagshipField(
      {required this.nodes,
      required this.selected,
      required this.compact,
      required this.duration,
      required this.onSelect});
  final List<_LifecycleNode> nodes;
  final int selected;
  final bool compact;
  final Duration duration;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final active = nodes[selected];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(compact: compact),
        SizedBox(height: compact ? 20 : 26),
        _BroadcastStrip(nodes: nodes, compact: compact),
        SizedBox(height: compact ? 12 : 20),
        _OperatingNetwork(
            nodes: nodes,
            selected: selected,
            compact: compact,
            duration: duration,
            onSelect: onSelect),
        SizedBox(height: compact ? 18 : 22),
        AnimatedSwitcher(
            duration: duration,
            child: _SelectedRecord(
                key: ValueKey(active.key), node: active, compact: compact)),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.compact});
  final bool compact;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('LIVE OPERATING FIELD',
            style: TextStyle(
                color: _teal,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.7)),
        const SizedBox(height: 10),
        Text('Orchestrate operating.',
            style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 30 : 46,
                height: 1.02,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.2)),
        const SizedBox(height: 10),
        const Text(
            'Current operating records, held in one commercial execution system.',
            style: TextStyle(color: _muted, fontSize: 14, height: 1.5)),
      ]);
}

class _BroadcastStrip extends StatefulWidget {
  const _BroadcastStrip({required this.nodes, required this.compact});
  final List<_LifecycleNode> nodes;
  final bool compact;
  @override
  State<_BroadcastStrip> createState() => _BroadcastStripState();
}

class _BroadcastStripState extends State<_BroadcastStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 8))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final phase =
              MediaQuery.disableAnimationsOf(context) ? .15 : _controller.value;
          final focus =
              (phase * widget.nodes.length).floor() % widget.nodes.length;
          return Container(
            padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 10 : 14, vertical: 10),
            decoration: const BoxDecoration(
                color: _deep,
                border: Border(
                    top: BorderSide(color: _line),
                    bottom: BorderSide(color: _line))),
            child: Row(children: [
              const _LiveDot(),
              const SizedBox(width: 9),
              const Text('OPERATING NOW',
                  style: TextStyle(
                      color: _teal,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2)),
              const SizedBox(width: 14),
              Expanded(
                  child: ClipRect(
                      child: Row(children: [
                for (var i = 0; i < widget.nodes.length; i++) ...[
                  if (i > 0)
                    const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 9),
                        child: Text('•', style: TextStyle(color: _line))),
                  Flexible(
                      child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 220),
                          opacity: i == focus ? 1 : .5,
                          child: Text(
                              '${widget.nodes[i].label.toUpperCase()} ${widget.nodes[i].valueText}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: i == focus ? _soft : _muted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: .55)))),
                ]
              ]))),
            ]),
          );
        },
      );
}

class _OperatingNetwork extends StatefulWidget {
  const _OperatingNetwork(
      {required this.nodes,
      required this.selected,
      required this.compact,
      required this.duration,
      required this.onSelect});
  final List<_LifecycleNode> nodes;
  final int selected;
  final bool compact;
  final Duration duration;
  final ValueChanged<int> onSelect;
  @override
  State<_OperatingNetwork> createState() => _OperatingNetworkState();
}

class _OperatingNetworkState extends State<_OperatingNetwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 7))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stages = widget.nodes.where((n) => n.kind != 'ASSET').toList();
    final assets = widget.nodes.where((n) => n.kind == 'ASSET').toList();
    final h = widget.compact
        ? 16 + stages.length * 88.0 + assets.length * 78.0 + 64
        : 340.0;
    return LayoutBuilder(
        builder: (context, constraints) => AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final phase = MediaQuery.disableAnimationsOf(context)
                    ? .12
                    : _controller.value;
                return SizedBox(
                    height: h,
                    child: Stack(children: [
                      Positioned.fill(
                          child: CustomPaint(
                              painter: _NetworkPainter(
                                  compact: widget.compact,
                                  phase: phase,
                                  stageCount: stages.length))),
                      for (var i = 0; i < stages.length; i++)
                        _placeNode(stages[i], widget.nodes.indexOf(stages[i]),
                            i, stages.length, constraints.maxWidth,
                            assets: false, stageCount: stages.length),
                      for (var i = 0; i < assets.length; i++)
                        _placeNode(assets[i], widget.nodes.indexOf(assets[i]),
                            i, assets.length, constraints.maxWidth,
                            assets: true, stageCount: stages.length),
                      Positioned(
                          left: widget.compact ? 4 : 0,
                          bottom: 0,
                          child: Row(children: [
                            const Icon(Icons.route_rounded,
                                color: _teal, size: 16),
                            const SizedBox(width: 8),
                            Text(
                                widget.compact
                                    ? 'SURFACED EXECUTION PATH'
                                    : 'SURFACED EXECUTION PATH  /  RETAINED INTELLIGENCE',
                                style: const TextStyle(
                                    color: _muted,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: .9))
                          ])),
                    ]));
              },
            ));
  }

  Widget _placeNode(
      _LifecycleNode node, int index, int local, int count, double width,
      {required bool assets, required int stageCount}) {
    final left = widget.compact
        ? 34.0
        : (assets
            ? width * .58 + (local * 148).clamp(0, width * .35)
            : (count <= 1
                ? width / 2 - 72
                : (width - 144) * local / (count - 1)));
    final top = widget.compact
        ? (assets
            ? 16 + stageCount * 88.0 + 20 + local * 78.0
            : 16 + local * 88.0)
        : (assets ? 10.0 : 126 + (local.isEven ? 0 : 40));
    return Positioned(
        left: left.toDouble(),
        top: top.toDouble(),
        width: widget.compact ? width - 68 : 144,
        child: _NetworkNode(
            node: node,
            selected: widget.selected == index,
            compact: widget.compact,
            onTap: () => widget.onSelect(index)));
  }
}

class _NetworkNode extends StatelessWidget {
  const _NetworkNode(
      {required this.node,
      required this.selected,
      required this.compact,
      required this.onTap});
  final _LifecycleNode node;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final accent = node.kind == 'ASSET' ? _blue : _teal;
    return Semantics(
        button: true,
        selected: selected,
        label: '${node.label}, ${node.valueText} ${node.suffix}',
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                          padding: const EdgeInsets.only(top: 5, right: 9),
                          child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              width: selected ? 12 : 8,
                              height: selected ? 12 : 8,
                              decoration: BoxDecoration(
                                  color: selected ? accent : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: accent, width: 1.4),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                              color: accent.withOpacity(.6),
                                              blurRadius: 12)
                                        ]
                                      : null))),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(node.label.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: accent,
                                    fontSize: compact ? 9 : 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.05)),
                            const SizedBox(height: 3),
                            Text(node.valueText,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: compact ? 27 : 30,
                                    height: 1,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -1)),
                            const SizedBox(height: 3),
                            Text(node.suffix,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: _muted, fontSize: 10)),
                            if (node.amountText != null)
                              Text(node.amountText!,
                                  style: const TextStyle(
                                      color: _soft,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700))
                          ])),
                      if (selected)
                        Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Icon(Icons.north_east,
                                color: accent, size: 14)),
                    ]))));
  }
}

class _NetworkPainter extends CustomPainter {
  const _NetworkPainter(
      {required this.compact, required this.phase, required this.stageCount});
  final bool compact;
  final double phase;
  final int stageCount;
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0x1837616B)
      ..strokeWidth = .7;
    for (var x = 0.0; x < size.width; x += compact ? 48 : 72)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    for (var y = 0.0; y < size.height; y += compact ? 48 : 54)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    final pathPaint = Paint()
      ..color = const Color(0xB02D6971)
      ..style = PaintingStyle.stroke
      ..strokeWidth = compact ? 1.5 : 1.8;
    final glow = Paint()
      ..color = const Color(0x326FD3C3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = compact ? 8 : 10
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    if (compact) {
      final path = Path()
        ..moveTo(39, 16)
        ..lineTo(39, size.height - 22);
      canvas.drawPath(path, glow);
      canvas.drawPath(path, pathPaint);
      final branchY = 16 + stageCount * 88.0 + 20;
      final branch = Path()
        ..moveTo(39, branchY)
        ..cubicTo(size.width * .2, branchY, size.width * .48, branchY + 44,
            size.width * .78, branchY + 44);
      canvas.drawPath(branch, pathPaint);
    } else {
      final path = Path()
        ..moveTo(36, size.height * .62)
        ..cubicTo(size.width * .27, size.height * .1, size.width * .58,
            size.height * .88, size.width - 28, size.height * .38);
      canvas.drawPath(path, glow);
      canvas.drawPath(path, pathPaint);
      final branch = Path()
        ..moveTo(size.width * .59, size.height * .38)
        ..cubicTo(size.width * .7, size.height * .55, size.width * .76,
            size.height * .58, size.width * .92, size.height * .62);
      canvas.drawPath(branch, pathPaint);
    }
    final t = phase;
    final position = compact
        ? Offset(39, 16 + (size.height - 38) * t)
        : Offset(36 + (size.width - 64) * t,
            size.height * (.62 - .24 * math.sin(t * math.pi * 2)));
    canvas.drawCircle(position, compact ? 4 : 4.5, Paint()..color = _soft);
    canvas.drawCircle(
        position,
        (compact ? 9 : 12) + math.sin(t * math.pi * 2) * 2,
        Paint()
          ..color = _teal.withOpacity(.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
  }

  @override
  bool shouldRepaint(covariant _NetworkPainter old) => old.phase != phase;
}

class _SelectedRecord extends StatelessWidget {
  const _SelectedRecord({super.key, required this.node, required this.compact});
  final _LifecycleNode node;
  final bool compact;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(compact ? 12 : 4, 14, 4, 4),
      decoration:
          const BoxDecoration(border: Border(top: BorderSide(color: _line))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.insights_outlined, color: _soft, size: 18),
        const SizedBox(width: 12),
        Expanded(
            child: Text.rich(TextSpan(
                style:
                    const TextStyle(color: _muted, fontSize: 12, height: 1.45),
                children: [
              TextSpan(
                  text: node.label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
              TextSpan(
                  text:
                      ' is surfaced as ${node.kind == 'ASSET' ? 'retained operating intelligence' : 'a commercial execution record'} with ${node.valueText} ${node.suffix}.')
            ])))
      ]));
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();
  @override
  Widget build(BuildContext context) => Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(color: _teal, shape: BoxShape.circle));
}

class _LoadingField extends StatelessWidget {
  const _LoadingField({required this.compact});
  final bool compact;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('LIVE OPERATING FIELD',
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
            height: compact ? 260 : 220,
            child: Center(
                child: CircularProgressIndicator(color: _teal, strokeWidth: 2)))
      ]);
}

class _EmptyField extends StatelessWidget {
  const _EmptyField();
  @override
  Widget build(BuildContext context) =>
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('LIVE OPERATING FIELD',
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
            style: TextStyle(color: _muted, fontSize: 13, height: 1.5))
      ]);
}

class _UnavailableField extends StatelessWidget {
  const _UnavailableField({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('LIVE OPERATING FIELD',
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
                foregroundColor: _soft, side: const BorderSide(color: _line)))
      ]);
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
      amountCents: _numberOrNull(json['amountCents']));
  final String key, label, suffix, kind;
  final num value;
  final num? amountCents;
  String get valueText => value.toInt().toString();
  String? get amountText => amountCents != null && amountCents! > 0
      ? '\$${_formatAmount(amountCents! / 100)}'
      : null;

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

  static num _number(dynamic value) =>
      value is num ? value : num.tryParse('$value') ?? 0;
  static num? _numberOrNull(dynamic value) =>
      value == null ? null : _number(value);
}
