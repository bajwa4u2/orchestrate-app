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
                    horizontal: compact ? 2 : 10, vertical: compact ? 10 : 12),
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
        SizedBox(height: compact ? 0 : 2),
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
                if (widget.compact)
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Text(
                        '${widget.nodes[focus].label.toUpperCase()} ${widget.nodes[focus].valueText}',
                        key: ValueKey(widget.nodes[focus].key),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _soft,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .55),
                      ),
                    ),
                  )
                else
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
        ? 16 + stages.length * 88.0 + assets.length * 78.0 + 24
        : 300.0;
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
                                  stageCount: stages.length,
                                  stageKeys: [
                            for (final stage in stages) stage.key
                          ]))),
                      for (var i = 0; i < stages.length; i++)
                        _placeNode(stages[i], widget.nodes.indexOf(stages[i]),
                            i, stages.length, constraints.maxWidth,
                            assets: false, stageCount: stages.length),
                      for (var i = 0; i < assets.length; i++)
                        _placeNode(assets[i], widget.nodes.indexOf(assets[i]),
                            i, assets.length, constraints.maxWidth,
                            assets: true, stageCount: stages.length),
                    ]));
              },
            ));
  }

  Widget _placeNode(
      _LifecycleNode node, int index, int local, int count, double width,
      {required bool assets, required int stageCount}) {
    final compactNodeWidth = math.min(width * .58, 220.0);
    final left = widget.compact
        ? (assets
            ? width * .16
            : (local.isEven ? 4.0 : width - compactNodeWidth - 4.0))
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
        width: widget.compact ? (assets ? width * .68 : compactNodeWidth) : 144,
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
      {required this.compact,
      required this.phase,
      required this.stageCount,
      required this.stageKeys});
  final bool compact;
  final double phase;
  final int stageCount;
  final List<String> stageKeys;
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
    late final Path primaryPath;
    Path? packetPath;
    Path? exceptionPath;
    int? indexFor(String value) {
      final index = stageKeys
          .indexWhere((key) => key.toLowerCase().contains(value.toLowerCase()));
      return index < 0 ? null : index;
    }

    Path connect(Offset from, Offset to, {double lift = 0}) {
      final path = Path()..moveTo(from.dx, from.dy + lift);
      final middle = (from.dy + to.dy) / 2;
      path.cubicTo(from.dx, middle, to.dx, middle, to.dx, to.dy + lift);
      return path;
    }

    if (compact) {
      final nodeWidth = math.min(size.width * .58, 220.0);
      double stageX(int index) =>
          (index.isEven ? 4.0 : size.width - nodeWidth - 4.0) + 20.0;
      double stageY(int index) => 32.0 + index * 88.0;
      Offset point(int index) => Offset(stageX(index), stageY(index));
      final lead = indexFor('lead') ?? 0;
      final opportunity = indexFor('opportun');
      final dispatch = indexFor('dispatch');
      final suppressed = indexFor('suppress');
      final primaryIndices = [
        lead,
        if (opportunity != null) opportunity,
        if (dispatch != null) dispatch,
      ];
      primaryPath = Path()
        ..moveTo(
            point(primaryIndices.first).dx, point(primaryIndices.first).dy);
      for (var i = 1; i < primaryIndices.length; i++) {
        final segment =
            connect(point(primaryIndices[i - 1]), point(primaryIndices[i]));
        primaryPath.addPath(segment, Offset.zero);
      }
      if (suppressed != null) {
        exceptionPath = connect(point(lead), point(suppressed));
      }
      if (opportunity != null && dispatch != null) {
        packetPath = connect(point(opportunity), point(dispatch), lift: 22);
      }
    } else {
      final nodeWidth = 144.0;
      Offset point(int index) => Offset(
          (size.width - nodeWidth) * index / math.max(1, stageCount - 1) + 20,
          141 + (index.isEven ? 0 : 40));
      final lead = indexFor('lead') ?? 0;
      final opportunity = indexFor('opportun');
      final dispatch = indexFor('dispatch');
      final suppressed = indexFor('suppress');
      final primaryIndices = [
        lead,
        if (opportunity != null) opportunity,
        if (dispatch != null) dispatch,
      ];
      primaryPath = Path()
        ..moveTo(
            point(primaryIndices.first).dx, point(primaryIndices.first).dy);
      for (var i = 1; i < primaryIndices.length; i++) {
        final segment =
            connect(point(primaryIndices[i - 1]), point(primaryIndices[i]));
        primaryPath.addPath(segment, Offset.zero);
      }
      if (suppressed != null)
        exceptionPath = connect(point(lead), point(suppressed));
      if (opportunity != null && dispatch != null) {
        packetPath = connect(point(opportunity), point(dispatch), lift: 26);
      }
    }
    canvas.drawPath(primaryPath, glow);
    canvas.drawPath(primaryPath, pathPaint);
    if (exceptionPath != null) canvas.drawPath(exceptionPath!, pathPaint);
    if (packetPath != null) canvas.drawPath(packetPath!, pathPaint);
    _drawTraveler(canvas, primaryPath, phase, compact: compact, packet: false);
    if (packetPath != null) {
      _drawTraveler(canvas, packetPath!, (phase + .47) % 1,
          compact: compact, packet: true);
    }
  }

  void _drawTraveler(Canvas canvas, Path path, double phase,
      {required bool compact, required bool packet}) {
    final metrics = path.computeMetrics().toList(growable: false);
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final distance = metric.length * phase.clamp(0.0, 1.0);
    final tangent = metric.getTangentForOffset(distance);
    if (tangent == null) return;
    final position = tangent.position;
    final trailStart = math.max(0.0, distance - (packet ? 34 : 46));
    final trail = metric.extractPath(trailStart, distance);
    canvas.drawPath(
        trail,
        Paint()
          ..color = (packet ? _blue : _soft).withOpacity(.62)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = packet ? 2.2 : 2.8
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    final halo = Paint()
      ..color = (packet ? _blue : _teal).withOpacity(.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(position,
        (compact ? 8 : 10) + math.sin(phase * math.pi * 2) * 1.5, halo);
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(tangent.angle);
    if (packet) {
      final envelope = Path()
        ..moveTo(-8, -5)
        ..lineTo(8, -5)
        ..lineTo(8, 5)
        ..lineTo(-8, 5)
        ..close();
      canvas.drawPath(
          envelope,
          Paint()
            ..color = _blue.withOpacity(.94)
            ..style = PaintingStyle.fill);
      final fold = Path()
        ..moveTo(-7, -4)
        ..lineTo(0, 1)
        ..lineTo(7, -4);
      canvas.drawPath(
          fold,
          Paint()
            ..color = _field
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1);
    } else {
      canvas.drawCircle(Offset.zero, compact ? 4 : 4.5, Paint()..color = _soft);
      canvas.drawLine(
          const Offset(-8, 0),
          const Offset(-13, 0),
          Paint()
            ..color = _soft.withOpacity(.7)
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round);
    }
    canvas.restore();
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
