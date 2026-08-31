import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';

class CommercialHero extends StatelessWidget {
  const CommercialHero({super.key, required this.onTalk});
  final VoidCallback onTalk;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(32, 38, 32, 34),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E1723), Color(0xFF173A3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2F5A5B)),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final stacked = c.maxWidth < 820;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Overline('ORCHESTRATE / COMMERCIAL EXECUTION'),
              const SizedBox(height: 18),
              Text(
                'Move the work\nfrom prospect to complete.',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontSize: c.maxWidth < 520 ? 34 : 54,
                      height: .99,
                      letterSpacing: -.8,
                    ),
              ),
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 610),
                child: Text(
                  'Orchestrate runs the commercial operation behind qualified outbound: readiness, outreach, replies, meetings, delivery and revenue records move through one managed system.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFFD2E2DF),
                        height: 1.6,
                      ),
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    onPressed: () => context.go('/pricing?trial=15d'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: const Color(0xFF071311),
                    ),
                    child: const Text('See managed execution'),
                  ),
                  OutlinedButton(
                    onPressed: onTalk,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF6F9F98)),
                    ),
                    child: const Text('Talk to Orchestrate'),
                  ),
                ],
              ),
            ],
          );
          final lane = const _LifecycleRail(compact: false);
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                copy,
                const SizedBox(height: 30),
                const _LifecycleRail(compact: true)
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(flex: 7, child: copy),
              const SizedBox(width: 40),
              Expanded(flex: 5, child: lane)
            ],
          );
        },
      ),
    );
  }
}

class _Overline extends StatelessWidget {
  const _Overline(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: AppTheme.accent,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6));
}

class _LifecycleRail extends StatelessWidget {
  const _LifecycleRail({required this.compact});
  final bool compact;
  static const stages = [
    'Prospect',
    'Qualify',
    'Agreement',
    'Customer',
    'Delivery',
    'Invoice',
    'Payment',
    'Complete'
  ];

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < stages.length; i++) {
      children
          .add(_LifecycleNode(index: i + 1, label: stages[i], active: i == 2));
      if (i < stages.length - 1) children.add(const _RailConnector());
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF416B69))),
      child: compact
          ? Wrap(
              spacing: 8,
              runSpacing: 8,
              children: stages
                  .asMap()
                  .entries
                  .map((e) => _LifecycleNode(
                      index: e.key + 1, label: e.value, active: e.key == 2))
                  .toList())
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _Overline('THE COMMERCIAL PATH'),
              const SizedBox(height: 16),
              ...children
            ]),
    );
  }
}

class _LifecycleNode extends StatelessWidget {
  const _LifecycleNode(
      {required this.index, required this.label, required this.active});
  final int index;
  final String label;
  final bool active;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 25,
            height: 25,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? AppTheme.accent : const Color(0xFF27484A),
                border: Border.all(
                    color: active ? AppTheme.accent : const Color(0xFF5A8580))),
            child: Text('$index',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: active ? const Color(0xFF071311) : Colors.white))),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))
      ]);
}

class _RailConnector extends StatelessWidget {
  const _RailConnector();
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
      child: Container(width: 1, height: 15, color: const Color(0xFF527E79)));
}

class ExecutionLifecycleSection extends StatefulWidget {
  const ExecutionLifecycleSection({super.key});
  @override
  State<ExecutionLifecycleSection> createState() =>
      _ExecutionLifecycleSectionState();
}

class _ExecutionLifecycleSectionState extends State<ExecutionLifecycleSection> {
  int selected = 2;
  static const data = [
    ('Prospect', 'A defined market signal enters the operation.'),
    (
      'Qualify',
      'The opportunity is evaluated against the business identity and targeting authority.'
    ),
    (
      'Agreement',
      'A qualified relationship becomes an executable commercial commitment.'
    ),
    (
      'Customer',
      'The relationship is accepted into the delivery and revenue path.'
    ),
    ('Delivery', 'Work, follow-up and completion dependencies remain visible.'),
    (
      'Invoice',
      'Revenue records, invoices, statements and reminders stay connected to the work.'
    ),
    (
      'Payment',
      'Payment status is carried as a commercial record, not an afterthought.'
    ),
    (
      'Complete',
      'The operation closes with an explainable record of what happened.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
          color: const Color(0xFF0E1723),
          borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Overline('THE WORK DOES NOT STOP AT OUTREACH'),
        const SizedBox(height: 12),
        Text('Commercial execution, made visible.',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(color: Colors.white, fontSize: 32)),
        const SizedBox(height: 8),
        const SizedBox(
            width: 680,
            child: Text(
                'Orchestrate holds the handoffs between opportunity, customer work and payment so the operation can be supervised without becoming another dashboard to operate.',
                style: TextStyle(color: Color(0xFFB9C8D6), height: 1.55))),
        const SizedBox(height: 26),
        LayoutBuilder(builder: (context, c) {
          final wrap = c.maxWidth < 760;
          final nodes = data
              .asMap()
              .entries
              .map((e) => _StageButton(
                  index: e.key,
                  label: e.value.$1,
                  active: selected == e.key,
                  onTap: () => setState(() => selected = e.key)))
              .toList();
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                wrap
                    ? Wrap(spacing: 8, runSpacing: 8, children: nodes)
                    : Row(children: [
                        for (var i = 0; i < nodes.length; i++) ...[
                          Expanded(child: nodes[i]),
                          if (i != nodes.length - 1) const SizedBox(width: 4)
                        ]
                      ]),
                const SizedBox(height: 22),
                AnimatedSwitcher(
                    duration: reduce
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    child: Container(
                        key: ValueKey(selected),
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                            color: const Color(0xFF18283A),
                            border: Border.all(color: const Color(0xFF2C5361)),
                            borderRadius: BorderRadius.circular(8)),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('0${selected + 1}',
                                  style: const TextStyle(
                                      color: AppTheme.accent,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: Text(data[selected].$2,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          height: 1.45)))
                            ])))
              ]);
        }),
      ]),
    );
  }
}

class _StageButton extends StatelessWidget {
  const _StageButton(
      {required this.index,
      required this.label,
      required this.active,
      required this.onTap});
  final int index;
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      selected: active,
      label: '$label commercial stage',
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
              decoration: BoxDecoration(
                  color: active ? AppTheme.accent : const Color(0xFF18283A),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                      color:
                          active ? AppTheme.accent : const Color(0xFF2C3E51))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('0${index + 1}',
                        style: TextStyle(
                            color: active
                                ? const Color(0xFF071311)
                                : AppTheme.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(label,
                        style: TextStyle(
                            color:
                                active ? const Color(0xFF071311) : Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700))
                  ]))));
}

class ExecutionCapabilityGrid extends StatelessWidget {
  const ExecutionCapabilityGrid({super.key});
  static const items = [
    (
      'Readiness',
      'Identity, mailbox transport and sending-domain verification must be ready before execution begins.'
    ),
    (
      'Qualification',
      'Defined targeting and signals become contactable commercial opportunities.'
    ),
    (
      'Delivery',
      'Dispatch, follow-up, reply handling and meeting handoff run as managed operation.'
    ),
    (
      'Revenue records',
      'Agreements, invoices, statements, reminders and payment status remain connected.'
    ),
    (
      'Holds and recovery',
      'Failures pause safely, explain the next condition and recover toward readiness.'
    ),
    (
      'Responsible AI',
      'AI assists within explicit boundaries; decisions and enforcement remain traceable.'
    ),
  ];
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth >= 900
            ? 3
            : c.maxWidth >= 560
                ? 2
                : 1;
        final width = (c.maxWidth - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map((item) => SizedBox(
                    width: width,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      constraints: const BoxConstraints(minHeight: 150),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppTheme.publicLine),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.$1,
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 10),
                          Text(item.$2,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(height: 1.55)),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

class CommercialSupportBand extends StatelessWidget {
  const CommercialSupportBand({super.key});
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: const Color(0xFFE6F4F1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFB5D8D0))),
      child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 16,
          children: [
            const SizedBox(
                width: 520,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Built in a commercialization environment.',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.publicText)),
                      SizedBox(height: 7),
                      Text(
                          'Aura Platform builds and operates Orchestrate with support from programs that help early products become durable businesses.',
                          style: TextStyle(
                              color: AppTheme.publicMuted, height: 1.5))
                    ])),
            Wrap(spacing: 10, children: [
              for (final label in [
                'Microsoft for Startups',
                'Google for Startups',
                'AWS Activate'
              ])
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFC8DED9))),
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.publicText)))
            ])
          ]));
}
