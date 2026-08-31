import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';

const _ink = Color(0xFF0E1723);
const _inkSoft = Color(0xFF18283A);
const _teal = Color(0xFF67D2C4);
const _muted = Color(0xFFB9C8D6);

class ExecutionObjectStage extends StatelessWidget {
  const ExecutionObjectStage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _inkSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF416B69)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Kicker('EXECUTION OBJECTS'),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Expanded(
              child: _ObjectTile(
            label: 'PROSPECT',
            title: 'Market signal',
            detail: 'Ready to qualify',
            accent: Color(0xFF6E9BF4),
          )),
          const _ArrowConnector(),
          const Expanded(
              child: _ObjectTile(
            label: 'AGREEMENT',
            title: 'Commercial intent',
            detail: 'Executable',
            accent: _teal,
          )),
        ]),
        const SizedBox(height: 12),
        const _ProgressLine(),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Expanded(
              child: _ObjectTile(
            label: 'DELIVERY',
            title: 'Work in motion',
            detail: 'Handoff visible',
            accent: Color(0xFFE5B75E),
          )),
          const _ArrowConnector(),
          const Expanded(
              child: _ObjectTile(
            label: 'COMPLETE',
            title: 'Payment recorded',
            detail: 'Closed with context',
            accent: _teal,
          )),
        ]),
      ]),
    );
  }
}

class _ObjectTile extends StatelessWidget {
  const _ObjectTile(
      {required this.label,
      required this.title,
      required this.detail,
      required this.accent});
  final String label;
  final String title;
  final String detail;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _ink,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withValues(alpha: .5)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  color: accent,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2)),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(detail, style: const TextStyle(color: _muted, fontSize: 11)),
        ]),
      );
}

class _ArrowConnector extends StatelessWidget {
  const _ArrowConnector();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(top: 30),
        child: Icon(Icons.arrow_forward, color: _teal, size: 18),
      );
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine();
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 8,
            height: 8,
            decoration:
                const BoxDecoration(color: _teal, shape: BoxShape.circle)),
        Expanded(
            child: Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: _teal.withValues(alpha: .45))),
        const Text('state transition',
            style: TextStyle(color: _muted, fontSize: 10)),
      ]);
}

class ExecutionGraphChapter extends StatefulWidget {
  const ExecutionGraphChapter({super.key});
  @override
  State<ExecutionGraphChapter> createState() => _ExecutionGraphChapterState();
}

class _ExecutionGraphChapterState extends State<ExecutionGraphChapter> {
  int selected = 1;
  static const states = <(String, String, String)>[
    (
      'Prospect',
      'A signal enters the operation.',
      'Identity and market context are still being established.'
    ),
    (
      'Qualify',
      'Opportunity becomes contactable.',
      'Targeting authority and readiness decide what can move next.'
    ),
    (
      'Agreement',
      'Intent becomes executable.',
      'The commercial relationship has a defined next action.'
    ),
    (
      'Customer',
      'The relationship enters delivery.',
      'Work and revenue records can now stay connected.'
    ),
    (
      'Delivery',
      'The promised work is visible.',
      'Handoffs, follow-up and dependencies stay in the path.'
    ),
    (
      'Invoice',
      'The commercial record is issued.',
      'The agreement and delivery context remain attached.'
    ),
    (
      'Payment',
      'Payment status is legible.',
      'The operation can close on a known commercial state.'
    ),
    (
      'Complete',
      'The work closes with context.',
      'What happened is easier to understand and act on.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final active = states[selected];
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
      decoration:
          BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Kicker('A COMMERCIAL STATE MACHINE'),
        const SizedBox(height: 10),
        Text('The relationship changes shape as the work moves.',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(color: Colors.white, fontSize: 32)),
        const SizedBox(height: 8),
        const Text(
            'Select a state to see the object, decision and next condition that make the path meaningful.',
            style: TextStyle(color: _muted, height: 1.5)),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          final buttons = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < states.length; i++)
                _StateChip(
                    index: i,
                    label: states[i].$1,
                    selected: i == selected,
                    onTap: () => setState(() => selected = i))
            ],
          );
          final visual = _StateVisual(index: selected, label: active.$1);
          return compact
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  buttons,
                  const SizedBox(height: 18),
                  visual,
                  const SizedBox(height: 18),
                  _StateCopy(state: active, reduce: reduce)
                ])
              : Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(flex: 6, child: visual),
                  const SizedBox(width: 26),
                  Expanded(
                      flex: 5,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buttons,
                            const SizedBox(height: 22),
                            _StateCopy(state: active, reduce: reduce)
                          ]))
                ]);
        }),
      ]),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip(
      {required this.index,
      required this.label,
      required this.selected,
      required this.onTap});
  final int index;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      selected: selected,
      label: '$label commercial state',
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                  color: selected ? _teal : _inkSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: selected ? _teal : const Color(0xFF2C5361))),
              child: Text('${index + 1}. $label',
                  style: TextStyle(
                      color: selected ? _ink : Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)))));
}

class _StateVisual extends StatelessWidget {
  const _StateVisual({required this.index, required this.label});
  final int index;
  final String label;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 210,
        child: CustomPaint(
          painter: _StatePainter(index),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: _teal,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: _teal.withValues(alpha: .2), blurRadius: 22)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('STATE ${index + 1}',
                      style: const TextStyle(
                          color: _ink,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 6),
                  Text(label,
                      style: const TextStyle(
                          color: _ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ),
      );
}

class _StatePainter extends CustomPainter {
  _StatePainter(this.index);
  final int index;
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = _teal.withValues(alpha: .48)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final dot = Paint()..color = _teal;
    final y = size.height / 2;
    final left = Offset(18, y);
    final right = Offset(size.width - 18, y);
    final path = Path()
      ..moveTo(left.dx, left.dy)
      ..cubicTo(size.width * .28, y - 70, size.width * .72, y + 70, right.dx,
          right.dy);
    canvas.drawPath(path, line);
    canvas.drawCircle(left, 6, dot);
    canvas.drawCircle(right, 6, dot);
    for (var i = 0; i < 3; i++) {
      final x = size.width * (.28 + i * .22);
      canvas.drawCircle(Offset(x, y + (i.isEven ? -22 : 22)), 4, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _StatePainter oldDelegate) =>
      oldDelegate.index != index;
}

class _StateCopy extends StatelessWidget {
  const _StateCopy({required this.state, required this.reduce});
  final (String, String, String) state;
  final bool reduce;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
      duration: reduce ? Duration.zero : const Duration(milliseconds: 220),
      child: Column(
          key: ValueKey(state.$1),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(state.$2,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(state.$3, style: const TextStyle(color: _muted, height: 1.5))
          ]));
}

class RecoveryVisualChapter extends StatelessWidget {
  const RecoveryVisualChapter({super.key});
  @override
  Widget build(BuildContext context) => const _DarkChapter(
        kicker: 'HOLDS ARE PART OF THE PATH',
        title: 'When a condition is not ready, execution pauses with a reason.',
        child: _RecoveryDiagram(),
      );
}

class _DarkChapter extends StatelessWidget {
  const _DarkChapter(
      {required this.kicker, required this.title, required this.child});
  final String kicker;
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
      decoration: BoxDecoration(
          color: _inkSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2C5361))),
      child: LayoutBuilder(builder: (context, c) {
        final stacked = c.maxWidth < 800;
        final copy =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(kicker,
              style: const TextStyle(
                  color: _teal,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4)),
          const SizedBox(height: 12),
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: Colors.white, fontSize: 28, height: 1.1))
        ]);
        return stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [copy, const SizedBox(height: 24), child])
            : Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(flex: 5, child: copy),
                const SizedBox(width: 28),
                Expanded(flex: 6, child: child)
              ]);
      }));
}

class _RecoveryDiagram extends StatelessWidget {
  const _RecoveryDiagram();
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 190,
        child: CustomPaint(
          painter: _RecoveryPainter(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [_PathLabel('READY'), _PathLabel('READY')]),
              _PathLabel('HOLD · DOMAIN CHECK', alert: true),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _PathLabel('CONDITION CLEAR'),
                _PathLabel('EXECUTE')
              ]),
            ],
          ),
        ),
      );
}

class _PathLabel extends StatelessWidget {
  const _PathLabel(this.text, {this.alert = false});
  final String text;
  final bool alert;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
          color: alert ? const Color(0xFF3A2C24) : _ink,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
              color:
                  alert ? const Color(0xFFE5B75E) : const Color(0xFF416B69))),
      child: Text(text,
          style: TextStyle(
              color: alert ? const Color(0xFFE5B75E) : _teal,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: .8)));
}

class _RecoveryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _teal.withValues(alpha: .6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(34, 22)
      ..lineTo(size.width - 34, 22)
      ..cubicTo(size.width * .72, 22, size.width * .72, size.height - 22,
          size.width * .5, size.height - 22)
      ..lineTo(size.width - 34, size.height - 22);
    final dot = Paint()..color = _teal;
    canvas.drawPath(path, p);
    canvas.drawCircle(const Offset(34, 22), 5, dot);
    canvas.drawCircle(Offset(size.width - 34, size.height - 22), 5, dot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RevenueRecordsVisual extends StatelessWidget {
  const RevenueRecordsVisual({super.key});
  @override
  Widget build(BuildContext context) => _DarkChapter(
      kicker: 'REVENUE RECORDS STAY CONNECTED',
      title:
          'Agreement, delivery, invoice and payment describe one commercial relationship.',
      child: SizedBox(
          height: 180,
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                _RecordNode('AGREEMENT', 'accepted'),
                _RecordLine(),
                _RecordNode('DELIVERY', 'in motion'),
                _RecordLine(),
                _RecordNode('INVOICE', 'issued'),
                _RecordLine(),
                _RecordNode('PAYMENT', 'complete')
              ])));
}

class _RecordNode extends StatelessWidget {
  const _RecordNode(this.label, this.status);
  final String label;
  final String status;
  @override
  Widget build(BuildContext context) => Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _teal.withValues(alpha: .16),
                border: Border.all(color: _teal)),
            child: const Icon(Icons.check, color: _teal, size: 20)),
        const SizedBox(height: 10),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: .8)),
        const SizedBox(height: 4),
        Text(status, style: const TextStyle(color: _muted, fontSize: 10))
      ]));
}

class _RecordLine extends StatelessWidget {
  const _RecordLine();
  @override
  Widget build(BuildContext context) =>
      Container(width: 18, height: 1, color: _teal.withValues(alpha: .5));
}

class SignalsVisualChapter extends StatelessWidget {
  const SignalsVisualChapter({super.key});
  @override
  Widget build(BuildContext context) => _DarkChapter(
      kicker: 'SIGNALS BECOME OPPORTUNITY',
      title:
          'A market signal is useful only when it becomes qualified and contactable.',
      child: SizedBox(
          height: 180,
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _SignalRow('INPUTS', ['market', 'identity', 'offer']),
                _SignalArrow(),
                _SignalRow('QUALIFY', ['fit', 'authority', 'ready']),
                _SignalArrow(),
                _SignalRow('OPPORTUNITY', ['contactable', 'held', 'suppressed'])
              ])));
}

class _SignalRow extends StatelessWidget {
  const _SignalRow(this.title, this.items);
  final String title;
  final List<String> items;
  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
            width: 82,
            child: Text(title,
                style: const TextStyle(
                    color: _teal,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1))),
        Expanded(
            child: Wrap(spacing: 6, runSpacing: 6, children: [
          for (final item in items)
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                    color: _ink,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF416B69))),
                child: Text(item,
                    style: const TextStyle(color: Colors.white, fontSize: 10)))
        ]))
      ]);
}

class _SignalArrow extends StatelessWidget {
  const _SignalArrow();
  @override
  Widget build(BuildContext context) => const Padding(
      padding: EdgeInsets.only(left: 38, top: 7, bottom: 7),
      child: Align(
          alignment: Alignment.centerLeft,
          child: Icon(Icons.south, color: _teal, size: 16)));
}

class ResponsibleAiVisualChapter extends StatelessWidget {
  const ResponsibleAiVisualChapter({super.key});
  @override
  Widget build(BuildContext context) => _DarkChapter(
      kicker: 'AI INSIDE THE OPERATION',
      title: 'Assistance can accelerate the work without owning the authority.',
      child: Column(children: const [
        _AuthorityRow('AI assistance', 'organize signals and prepare work'),
        _AuthorityRow(
            'Policy boundary', 'check the conditions before execution'),
        _AuthorityRow(
            'Business authority', 'decide what may move and what must hold')
      ]));
}

class _AuthorityRow extends StatelessWidget {
  const _AuthorityRow(this.label, this.detail);
  final String label;
  final String detail;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
            width: 9,
            height: 9,
            decoration:
                const BoxDecoration(color: _teal, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12))),
        Expanded(
            flex: 2,
            child: Text(detail,
                style: const TextStyle(color: _muted, fontSize: 11)))
      ]));
}

class OfficialSupportMarks extends StatelessWidget {
  const OfficialSupportMarks({super.key});
  @override
  Widget build(BuildContext context) => Wrap(
          alignment: WrapAlignment.end,
          spacing: 22,
          runSpacing: 16,
          children: const [
            _SupportAsset(
                'assets/branding/support/microsoft-for-startups-badge.png',
                'Microsoft for Startups',
                width: 132),
            _SupportAsset('assets/branding/support/google-for-startups.svg',
                'Google for Startups',
                width: 110),
            _SupportAsset(
                'assets/branding/support/aws-activate.svg', 'AWS Activate',
                width: 94)
          ]);
}

class _SupportAsset extends StatelessWidget {
  const _SupportAsset(this.asset, this.label, {required this.width});
  final String asset;
  final String label;
  final double width;
  @override
  Widget build(BuildContext context) => Semantics(
      image: true,
      label: label,
      // These are the same governed originals used by the Company estate.
      // Keep the marks free on the support field; a white wrapper makes them
      // read as pasted image cards against Orchestrate's closing surface.
      child: SizedBox(
          width: width,
          height: 42,
          child: Image.asset(asset,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => Text(label,
                  style: const TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w700)))));
}

class _Kicker extends StatelessWidget {
  const _Kicker(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: _teal,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4));
}
