import '../../../core/network/api_client.dart';

/// The business's own money with its customers (DD-26): what was proposed,
/// agreed, invoiced and paid. Read from `/client/money`, which summarizes the
/// K11 commercial records. Orchestrate's own subscription billing is a
/// different thing and lives in the account layer.
class ClientMoneyRepository {
  ClientMoneyRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Null when the server does not publish money yet (an older deployment):
  /// the screen then says so rather than showing zeros as if they were facts.
  Future<MoneyView?> fetch() async {
    try {
      final json =
          await _apiClient.getJson('/client/money', surface: ApiSurface.client);
      return MoneyView.fromJson(Map<String, dynamic>.from(json as Map));
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }
}

class MoneyTotals {
  const MoneyTotals({
    required this.proposedCount,
    required this.activeAgreementCount,
    required this.invoicedDueCents,
    required this.overdueCents,
    required this.paidThisMonthCents,
    required this.paidAllTimeCents,
    required this.draftInvoiceCount,
  });

  final int proposedCount;
  final int activeAgreementCount;
  final int invoicedDueCents;
  final int overdueCents;
  final int paidThisMonthCents;
  final int paidAllTimeCents;
  final int draftInvoiceCount;

  bool get isEmpty =>
      proposedCount == 0 &&
      activeAgreementCount == 0 &&
      invoicedDueCents == 0 &&
      paidAllTimeCents == 0 &&
      draftInvoiceCount == 0;

  static MoneyTotals fromJson(Map<String, dynamic> j) {
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    return MoneyTotals(
      proposedCount: n('proposedCount'),
      activeAgreementCount: n('activeAgreementCount'),
      invoicedDueCents: n('invoicedDueCents'),
      overdueCents: n('overdueCents'),
      paidThisMonthCents: n('paidThisMonthCents'),
      paidAllTimeCents: n('paidAllTimeCents'),
      draftInvoiceCount: n('draftInvoiceCount'),
    );
  }
}

class MoneyRow {
  const MoneyRow({
    required this.kind,
    required this.id,
    required this.relationshipId,
    required this.counterparty,
    required this.title,
    required this.amountCents,
    required this.currencyCode,
    required this.state,
    required this.at,
    required this.dueAt,
  });

  /// INVOICE | AGREEMENT | PAYMENT
  final String kind;
  final String id;
  final String? relationshipId;
  final String counterparty;
  final String? title;
  final int? amountCents;
  final String currencyCode;
  final String state;
  final DateTime? at;
  final DateTime? dueAt;

  bool get isPaid =>
      (kind == 'PAYMENT' && state == 'RECEIVED') ||
      (kind == 'INVOICE' && state == 'PAID');

  static MoneyRow fromJson(Map<String, dynamic> j) => MoneyRow(
        kind: (j['kind'] ?? '').toString(),
        id: (j['id'] ?? '').toString(),
        relationshipId: j['relationshipId']?.toString(),
        counterparty: (j['counterparty'] ?? '').toString().trim().isEmpty
            ? 'A customer'
            : j['counterparty'].toString().trim(),
        title: j['title']?.toString(),
        amountCents: (j['amountCents'] as num?)?.toInt(),
        currencyCode: (j['currencyCode'] ?? 'USD').toString(),
        state: (j['state'] ?? '').toString(),
        at: DateTime.tryParse(j['at']?.toString() ?? ''),
        dueAt: DateTime.tryParse(j['dueAt']?.toString() ?? ''),
      );
}

class MoneyView {
  const MoneyView({
    required this.currencyCode,
    required this.totals,
    required this.rows,
    required this.says,
  });

  final String currencyCode;
  final MoneyTotals totals;
  final List<MoneyRow> rows;
  final String says;

  static MoneyView fromJson(Map<String, dynamic> j) => MoneyView(
        currencyCode: (j['currencyCode'] ?? 'USD').toString(),
        totals: MoneyTotals.fromJson(
            Map<String, dynamic>.from(j['totals'] as Map? ?? const {})),
        rows: [
          for (final r in (j['rows'] as List? ?? const []))
            MoneyRow.fromJson(Map<String, dynamic>.from(r as Map)),
        ],
        says: (j['says'] ?? '').toString(),
      );
}

/// Whole-unit money as the boards show it: 4,800 with the currency's sign.
/// Cents are kept only when the amount has them.
String moneyLabel(int cents, {String currencyCode = 'USD'}) {
  const signs = {'USD': r'$', 'GBP': '£', 'EUR': '€', 'CAD': r'CA$', 'AUD': r'A$'};
  final sign = signs[currencyCode] ?? '$currencyCode ';
  final whole = (cents.abs() ~/ 100).toString();
  final out = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) out.write(',');
    out.write(whole[i]);
  }
  final rest = cents.abs() % 100;
  final tail = rest == 0 ? '' : '.${rest.toString().padLeft(2, '0')}';
  return '${cents < 0 ? '-' : ''}$sign$out$tail';
}
