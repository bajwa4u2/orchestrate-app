import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/workspace.dart';
import '../../../core/theme/ob.dart';
import '../../../core/ui/ob_widgets.dart';
import '../../../data/repositories/client/client_money_repository.dart';

/// MONEY (DD-26, board S10): what was agreed, what is invoiced, what is paid.
///
/// Green appears here because this is money, and only the paid figure is
/// filled green: paid is the one number an owner is looking for. Amber marks
/// only what is waiting for the owner's yes. Every figure is the server's
/// (`/client/money`); an empty business is told it is empty, never shown
/// zeros dressed as results.
class MoneyScreen extends StatefulWidget {
  const MoneyScreen({super.key});

  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen> {
  final _repository = ClientMoneyRepository();
  late Future<MoneyView?> _future = _repository.fetch();

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December'
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return FutureBuilder<MoneyView?>(
      future: _future,
      builder: (context, snap) {
        final phone = Workspace.sizeOf(context, MediaQuery.sizeOf(context).width).isPhone;
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            const ObHeadline('Money'),
            const SizedBox(height: 6),
            Text(
                'What was agreed, what is invoiced, what is paid. '
                '${_months[now.month - 1]} ${now.year}.',
                style: Ob.body(15, color: Ob.inkMuted)),
            const SizedBox(height: 24),
            if (snap.connectionState != ConnectionState.done)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                    child: CircularProgressIndicator(color: Ob.ink, strokeWidth: 2)),
              )
            else if (snap.hasError)
              _Notice(
                text: 'Money could not be loaded just now.',
                action: 'Try again',
                onAction: () => setState(() => _future = _repository.fetch()),
              )
            else if (snap.data == null)
              const _Notice(
                  text: 'Agreements, invoices and payments with your customers '
                      'will appear here as they are recorded.')
            else
              ..._body(snap.data!, phone),
          ],
        );
      },
    );
  }

  List<Widget> _body(MoneyView m, bool phone) {
    final t = m.totals;
    final cc = m.currencyCode;
    final tiles = <Widget>[
      _Tile(
        label: 'Proposed, waiting for you',
        labelColor: Ob.yesDeep,
        value: '${t.proposedCount}',
        note: t.proposedCount == 1 ? '1 proposal' : '${t.proposedCount} proposals',
      ),
      _Tile(
        label: 'Agreed',
        value: '${t.activeAgreementCount}',
        note: t.activeAgreementCount == 1
            ? '1 agreement in force'
            : '${t.activeAgreementCount} agreements in force',
      ),
      _Tile(
        label: 'Invoiced, due',
        value: moneyLabel(t.invoicedDueCents, currencyCode: cc),
        note: t.overdueCents > 0
            ? '${moneyLabel(t.overdueCents, currencyCode: cc)} overdue'
            : 'nothing overdue',
      ),
      _Tile(
        label: 'Paid this month',
        value: moneyLabel(t.paidThisMonthCents, currencyCode: cc),
        note: '${moneyLabel(t.paidAllTimeCents, currencyCode: cc)} paid in all',
        paid: true,
      ),
    ];
    return [
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth < 620 ? 2 : 4;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final tile in tiles)
              SizedBox(width: (c.maxWidth - 16 * (cols - 1)) / cols, child: tile),
          ],
        );
      }),
      const SizedBox(height: 22),
      if (m.rows.isEmpty)
        _Notice(text: m.says.isEmpty ? 'Nothing has been invoiced or paid yet.' : m.says)
      else
        ObCard(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!phone)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(children: [
                    Expanded(flex: 20, child: Text('Customer', style: _head)),
                    Expanded(flex: 10, child: Text('Amount', style: _head)),
                    Expanded(flex: 10, child: Text('Stage', style: _head)),
                    Expanded(flex: 12, child: Text('Date', style: _head)),
                  ]),
                ),
              for (final r in m.rows) _Row(row: r, phone: phone),
            ],
          ),
        ),
      const SizedBox(height: 18),
      const ObAssurance('Every invoice is checked against what was agreed '
          'before it can go out, and none goes without your yes.'),
      const SizedBox(height: 24),
    ];
  }

  TextStyle get _head => Ob.body(13, color: Ob.inkMuted, weight: FontWeight.w600);
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    required this.note,
    this.labelColor = Ob.inkMuted,
    this.paid = false,
  });

  final String label;
  final String value;
  final String note;
  final Color labelColor;
  final bool paid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: paid ? Ob.money : Ob.card,
        borderRadius: BorderRadius.circular(Ob.radiusPanel),
        boxShadow: paid
            // Kept under the card (4 Oct 2026): a 48px glow spilled onto the
            // "Invoiced, due" card beside it.
            ? const [BoxShadow(color: Color(0x3315803D), blurRadius: 18, offset: Offset(0, 10))]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Ob.body(13,
                  color: paid ? Ob.moneySoft : labelColor, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: Ob.figure(34, color: paid ? Ob.card : Ob.ink)),
          ),
          const SizedBox(height: 6),
          Text(note, style: Ob.body(13, color: paid ? Ob.moneySoft : Ob.inkMuted)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row, required this.phone});
  final MoneyRow row;
  final bool phone;

  (String, PillTone) get _stage {
    switch ('${row.kind}:${row.state}') {
      case 'AGREEMENT:PROPOSED':
        return ('Proposal', PillTone.yes);
      case 'AGREEMENT:ACTIVE':
        return ('Agreed', PillTone.plain);
      case 'AGREEMENT:DRAFT':
        return ('Being drafted', PillTone.plain);
      case 'INVOICE:DRAFT':
        return ('Invoice ready', PillTone.yes);
      case 'INVOICE:ISSUED':
        return ('Invoiced', PillTone.plain);
      case 'INVOICE:PARTIALLY_PAID':
        return ('Part paid', PillTone.money);
      case 'INVOICE:PAID':
      case 'PAYMENT:RECEIVED':
        return ('Paid', PillTone.money);
      case 'INVOICE:DISPUTED':
        return ('Disputed', PillTone.refused);
      case 'PAYMENT:FAILED':
        return ('Payment failed', PillTone.refused);
      default:
        return (_title(row.state), PillTone.plain);
    }
  }

  static String _title(String s) => s.isEmpty
      ? ''
      : s[0] + s.substring(1).toLowerCase().replaceAll('_', ' ');

  String get _date {
    final d = row.at?.toLocal();
    if (d == null) return '';
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final verb = row.isPaid
        ? 'Paid'
        : row.kind == 'INVOICE'
            ? 'Issued'
            : row.kind == 'AGREEMENT'
                ? 'Dated'
                : '';
    return '$verb ${m[d.month - 1]} ${d.day}'.trim();
  }

  @override
  Widget build(BuildContext context) {
    final (label, tone) = _stage;
    final amount = row.amountCents == null
        ? '—'
        : moneyLabel(row.amountCents!, currencyCode: row.currencyCode);
    final name = Text(row.counterparty, style: Ob.strong(15));
    final amountText = Text(amount,
        style: Ob.figure(15,
            color: row.isPaid ? Ob.money : Ob.ink, weight: FontWeight.w500));
    final open = row.relationshipId == null
        ? null
        : () => context.go('/client/relationships/${row.relationshipId}');
    return InkWell(
      onTap: open,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Ob.line))),
        child: phone
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: name), amountText]),
                const SizedBox(height: 6),
                Row(children: [
                  ObPill(label, tone: tone),
                  const SizedBox(width: 10),
                  Text(_date, style: Ob.body(13, color: Ob.inkMuted)),
                ]),
              ])
            : Row(children: [
                Expanded(
                    flex: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        name,
                        if ((row.title ?? '').isNotEmpty)
                          Text(row.title!, style: Ob.body(13, color: Ob.inkMuted)),
                      ],
                    )),
                Expanded(flex: 10, child: amountText),
                Expanded(
                    flex: 10,
                    child: Align(
                        alignment: Alignment.centerLeft,
                        child: ObPill(label, tone: tone))),
                Expanded(
                    flex: 12,
                    child: Text(_date, style: Ob.body(14, color: Ob.inkMuted))),
              ]),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ObCard(
      child: Row(children: [
        Expanded(child: Text(text, style: Ob.body(15, color: Ob.ink))),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ]),
    );
  }
}
