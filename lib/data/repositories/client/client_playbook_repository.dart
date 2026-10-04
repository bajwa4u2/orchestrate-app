import '../../../core/network/api_client.dart';

/// HOW THIS BUSINESS WINS WORK (DD-34): its kind of business, the buyers it
/// wants, the moments that make a buyer ready, its proof and how it is paid.
///
/// Every choice Setup offers comes from the server's playbooks, so a new kind
/// of business, buyer, moment or source arrives without an app release. The
/// app keeps no list of its own.
class ClientPlaybookRepository {
  ClientPlaybookRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<PlaybookState> fetch() async {
    final json = await _apiClient.getJson('/client/playbook', surface: ApiSurface.client);
    return PlaybookState.fromJson(_map(json));
  }

  /// Saves only what is given; the answer is the whole record again.
  Future<PlaybookState> save(Map<String, dynamic> patch) async {
    final json = await _apiClient.patchJson('/client/playbook',
        surface: ApiSurface.client, body: patch);
    return PlaybookState.fromJson(_map(json));
  }
}

Map<String, dynamic> _map(dynamic v) =>
    v is Map ? v.map((k, v) => MapEntry('$k', v)) : <String, dynamic>{};
List<dynamic> _list(dynamic v) => v is List ? v : const [];
List<String> _strings(dynamic v) => _list(v).map((e) => '$e').toList(growable: false);
String? _text(dynamic v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

class BusinessKindOption {
  const BusinessKindOption({
    required this.key,
    required this.label,
    required this.group,
    required this.playbook,
    required this.industryCode,
    required this.defaultMoments,
    this.buyerRoles = const [],
    this.defaultBuyerRoles = const [],
    this.proofKinds = const [],
    this.questions = const [],
  });

  /// This kind's own buyers, proof and questions, resolved by the server.
  final List<Labelled> buyerRoles;
  final List<String> defaultBuyerRoles;
  final List<ProofKind> proofKinds;
  final List<SetupQuestion> questions;

  final String key;
  final String label;
  final String group;
  final String playbook;
  final String industryCode;
  final List<String> defaultMoments;

  static BusinessKindOption fromJson(Map<String, dynamic> j) => BusinessKindOption(
        key: '${j['key'] ?? ''}',
        label: '${j['label'] ?? ''}',
        group: '${j['group'] ?? ''}',
        playbook: '${j['playbook'] ?? ''}',
        industryCode: '${j['industryCode'] ?? ''}',
        defaultMoments: _strings(j['defaultMoments']),
        buyerRoles: [
          for (final r in _list(j['buyerRoles']).map(_map))
            Labelled('${r['key'] ?? ''}', '${r['label'] ?? ''}')
        ],
        defaultBuyerRoles: _strings(j['defaultBuyerRoles']),
        proofKinds: _list(j['proofKinds']).map(_map).map(ProofKind.fromJson).toList(),
        questions: _list(j['questions']).map(_map).map(SetupQuestion.fromJson).toList(),
      );
}

/// A question only some kinds of business are asked, drawn from what the
/// server says: its type, its choices, and the step it belongs to.
class SetupQuestion {
  const SetupQuestion({
    required this.key,
    required this.label,
    required this.type,
    required this.step,
    this.hint,
    this.unit,
    this.options = const [],
  });

  final String key;
  final String label;

  /// choices | text | number | range | dated_names
  final String type;

  /// want | moments | offer
  final String step;
  final String? hint;
  final String? unit;
  final List<Labelled> options;

  static SetupQuestion fromJson(Map<String, dynamic> j) => SetupQuestion(
        key: '${j['key'] ?? ''}',
        label: '${j['label'] ?? ''}',
        type: '${j['type'] ?? 'text'}',
        step: '${j['step'] ?? 'offer'}',
        hint: _text(j['hint']),
        unit: _text(j['unit']),
        options: [
          for (final o in _list(j['options']).map(_map))
            Labelled('${o['key'] ?? ''}', '${o['label'] ?? ''}')
        ],
      );
}

class Labelled {
  const Labelled(this.key, this.label);
  final String key;
  final String label;
}

class MomentOption {
  const MomentOption({
    required this.key,
    required this.label,
    required this.why,
    required this.sources,
    required this.watching,
    required this.coverageSaid,
  });

  final String key;
  final String label;
  final String why;
  final List<String> sources;

  /// Watched now in at least one of the business's countries.
  final bool watching;

  /// "Not watched yet in the United States. No public source yet in Pakistan".
  final String? coverageSaid;

  static MomentOption fromJson(Map<String, dynamic> j) => MomentOption(
        key: '${j['key'] ?? ''}',
        label: '${j['label'] ?? ''}',
        why: '${j['why'] ?? ''}',
        sources: _strings(j['sources']),
        watching: j['watching'] == true,
        coverageSaid: _text(j['coverageSaid']),
      );
}

class ProofKind {
  const ProofKind({
    required this.key,
    required this.label,
    required this.hint,
    required this.expires,
    this.stored = 'trust',
  });
  final String key;
  final String label;
  final String hint;
  final bool expires;

  /// `trust` (a credential, a public fact) or `evidence` (work that may be private).
  final String stored;
  bool get isEvidence => stored == 'evidence';

  static ProofKind fromJson(Map<String, dynamic> j) => ProofKind(
        key: '${j['key'] ?? ''}',
        label: '${j['label'] ?? ''}',
        hint: '${j['hint'] ?? ''}',
        expires: j['expires'] == true,
        stored: '${j['stored'] ?? 'trust'}',
      );
}

class PaymentTerms {
  const PaymentTerms({
    required this.model,
    required this.depositPercent,
    required this.retainagePercent,
    required this.termsDays,
  });

  /// progress | commission | terms | recurring
  final String model;
  final double? depositPercent;
  final double? retainagePercent;
  final int termsDays;

  static PaymentTerms fromJson(Map<String, dynamic> j) => PaymentTerms(
        model: '${j['model'] ?? 'terms'}',
        depositPercent: (j['depositPercent'] as num?)?.toDouble(),
        retainagePercent: (j['retainagePercent'] as num?)?.toDouble(),
        termsDays: (j['termsDays'] as num?)?.toInt() ?? 30,
      );

  Map<String, dynamic> toJson() => {
        'model': model,
        'depositPercent': depositPercent,
        'retainagePercent': retainagePercent,
        'termsDays': termsDays,
      };
}

/// One way of being paid, as the server says it (4 Oct 2026): a model the app
/// has never heard of still shows, in the server's words, without a release.
class PaymentChoice {
  const PaymentChoice(this.key, this.label, this.says, this.asks);

  final String key;
  final String label;
  final String says;

  /// The percentages it asks for: "deposit", "retainage".
  final List<String> asks;

  /// The words this app has always used, for a server that sends none.
  static const _known = {
    'recurring': PaymentChoice('recurring', 'A monthly or yearly subscription',
        'Billed every month or year, in advance, until the customer stops.', []),
    'progress': PaymentChoice('progress', 'Monthly, as the work progresses',
        'Each month you bill for the work done so far, and the customer holds '
            'back a share until the job is finished.',
        ['deposit', 'retainage']),
    'terms': PaymentChoice('terms', 'An invoice when the work is done',
        'One invoice, or one per stage, due after the work is done.', ['deposit']),
    'commission': PaymentChoice('commission', 'Commission from the insurer',
        'The insurer pays your commission. Fees you bill yourself follow the '
            'terms below.',
        []),
  };

  static PaymentChoice known(String key) =>
      _known[key] ?? PaymentChoice(key, key, '', const ['deposit']);

  static PaymentChoice fromJson(Map<String, dynamic> j) {
    final key = '${j['key'] ?? ''}';
    final fallback = known(key);
    final label = '${j['label'] ?? ''}'.trim();
    final says = '${j['says'] ?? ''}'.trim();
    final asks = j['asks'];
    return PaymentChoice(
      key,
      label.isEmpty ? fallback.label : label,
      says.isEmpty ? fallback.says : says,
      asks is List ? asks.map((a) => '$a').toList() : fallback.asks,
    );
  }
}

class PlaybookOption {
  const PlaybookOption({
    required this.key,
    required this.label,
    required this.buyerRoles,
    required this.defaultBuyerRoles,
    required this.moments,
    required this.proofKinds,
    required this.payment,
    this.paymentModels = const ['terms'],
    List<PaymentChoice>? paymentChoices,
  }) : _paymentChoices = paymentChoices;

  final List<PaymentChoice>? _paymentChoices;

  /// The server's choices, in its words; else the models in this app's words.
  List<PaymentChoice> get paymentChoices =>
      _paymentChoices ?? paymentModels.map(PaymentChoice.known).toList();

  final String key;
  final String label;

  /// The ways of being paid this playbook offers: progress, terms,
  /// commission, recurring.
  final List<String> paymentModels;
  final List<Labelled> buyerRoles;
  final List<String> defaultBuyerRoles;
  final List<MomentOption> moments;
  final List<ProofKind> proofKinds;
  final PaymentTerms payment;

  static PlaybookOption fromJson(Map<String, dynamic> j) => PlaybookOption(
        key: '${j['key'] ?? ''}',
        label: '${j['label'] ?? ''}',
        buyerRoles: [
          for (final r in _list(j['buyerRoles']).map(_map))
            Labelled('${r['key'] ?? ''}', '${r['label'] ?? ''}')
        ],
        defaultBuyerRoles: _strings(j['defaultBuyerRoles']),
        moments: _list(j['moments']).map(_map).map(MomentOption.fromJson).toList(),
        proofKinds: _list(j['proofKinds']).map(_map).map(ProofKind.fromJson).toList(),
        payment: PaymentTerms.fromJson(_map(j['payment'])),
        paymentModels: _strings(j['paymentModels']).isEmpty
            ? const ['terms']
            : _strings(j['paymentModels']),
        paymentChoices: _list(j['paymentChoices']).isEmpty
            ? null
            : _list(j['paymentChoices'])
                .map(_map)
                .map(PaymentChoice.fromJson)
                .where((c) => c.key.isNotEmpty)
                .toList(),
      );
}

/// One credential or piece of evidence, as kept in the business's records.
class ProofItem {
  const ProofItem({
    required this.id,
    required this.kind,
    required this.label,
    this.kindLabel,
    this.number,
    this.issuer,
    this.expiresOn,
    this.mentionable = true,
    this.hasFile = false,
  });

  /// The kind's own name, including kinds only older records carry ("Award").
  final String? kindLabel;

  /// Evidence only: may Orchestrate mention it in a note.
  final bool mentionable;

  /// A file is attached to the record; it stays when the item is edited.
  final bool hasFile;

  final String id;
  final String kind;
  final String label;
  final String? number;
  final String? issuer;

  /// YYYY-MM-DD
  final String? expiresOn;

  static ProofItem fromJson(Map<String, dynamic> j) => ProofItem(
        id: '${j['id'] ?? ''}',
        kind: '${j['kind'] ?? ''}',
        label: '${j['label'] ?? ''}',
        number: _text(j['number']),
        issuer: _text(j['issuer']),
        expiresOn: _text(j['expiresOn']),
        kindLabel: _text(j['kindLabel']),
        mentionable: j['mentionable'] != false,
        hasFile: j['hasFile'] == true,
      );

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'kind': kind,
        'label': label,
        'number': number,
        'issuer': issuer,
        'expiresOn': expiresOn,
        'mentionable': mentionable,
      };
}

class SavedPlaybook {
  const SavedPlaybook({
    required this.kindKey,
    required this.playbook,
    required this.buyerRoles,
    required this.customBuyers,
    required this.businessesOnly,
    required this.sizeBand,
    required this.moments,
    required this.customMoments,
    required this.offerResult,
    required this.proof,
    required this.payment,
    required this.confirmed,
    this.answers = const {},
  });

  /// Answers to this kind's own questions, by question key.
  final Map<String, dynamic> answers;

  final String kindKey;
  final String playbook;
  final List<String> buyerRoles;
  final List<String> customBuyers;
  final bool businessesOnly;
  final String sizeBand;
  final List<String> moments;
  final List<String> customMoments;
  final String? offerResult;
  final List<ProofItem> proof;
  final PaymentTerms payment;

  /// Steps the owner answered: buyers, moments, offer, payment. Defaults the
  /// playbook filled in are not answers.
  final List<String> confirmed;

  static SavedPlaybook fromJson(Map<String, dynamic> j) => SavedPlaybook(
        kindKey: '${j['kindKey'] ?? ''}',
        playbook: '${j['playbook'] ?? ''}',
        buyerRoles: _strings(j['buyerRoles']),
        customBuyers: _strings(j['customBuyers']),
        businessesOnly: j['businessesOnly'] != false,
        sizeBand: '${j['sizeBand'] ?? 'any'}',
        moments: _strings(j['moments']),
        customMoments: _strings(j['customMoments']),
        offerResult: _text(j['offerResult']),
        proof: _list(j['proof']).map(_map).map(ProofItem.fromJson).toList(),
        payment: PaymentTerms.fromJson(_map(j['payment'])),
        confirmed: _strings(j['confirmed']),
        answers: _map(j['answers']),
      );
}

class PlaybookState {
  const PlaybookState({
    required this.kinds,
    required this.playbooks,
    required this.sizeBands,
    required this.countries,
    required this.suggestedKind,
    required this.saved,
  });

  final List<BusinessKindOption> kinds;
  final Map<String, PlaybookOption> playbooks;
  final List<String> sizeBands;
  final List<String> countries;

  /// For a business saved before playbooks: the kind its industry implies.
  final String? suggestedKind;
  final SavedPlaybook? saved;

  static const empty = PlaybookState(
      kinds: [], playbooks: {}, sizeBands: [], countries: [], suggestedKind: null, saved: null);

  bool get isEmpty => kinds.isEmpty;

  BusinessKindOption? kind(String? key) {
    for (final k in kinds) {
      if (k.key == key) return k;
    }
    return null;
  }

  PlaybookOption? playbookOf(String? kindKey) => playbooks[kind(kindKey)?.playbook];

  static PlaybookState fromJson(Map<String, dynamic> j) {
    final books = _list(j['playbooks']).map(_map).map(PlaybookOption.fromJson);
    final saved = _map(j['saved']);
    return PlaybookState(
      kinds: _list(j['kinds']).map(_map).map(BusinessKindOption.fromJson).toList(),
      playbooks: {for (final b in books) b.key: b},
      sizeBands: _strings(j['sizeBands']),
      countries: _strings(j['countries']),
      suggestedKind: _text(j['suggestedKind']),
      saved: saved.isEmpty ? null : SavedPlaybook.fromJson(saved),
    );
  }
}
