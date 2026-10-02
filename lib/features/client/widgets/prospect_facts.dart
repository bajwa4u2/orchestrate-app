import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/market/client_market.dart';

/// WHY THIS BUSINESS, AS FACTS A PERSON CAN CHECK.
///
/// A card that asked "Worth writing to?" and offered only "this business sells
/// across sectors" gave the owner no reason to say yes (2 Oct 2026). These are
/// the facts behind a business that passed every check: what it is, which of
/// the owner's own buyer kinds it matches, where it is, and what was verified.
/// Used by Today's card and by the business's detail sheet, so both say the
/// same thing.
class ProspectFact {
  const ProspectFact(this.icon, this.text);
  final IconData icon;
  final String text;
}

/// One plain sentence: "A dental office in Long Beach, CA. Matches “Dental
/// practices” in your list."
String prospectSummary(Candidate c) {
  final checks = c.checks;
  final what = checks?.kind;
  final where = (c.geography ?? '').trim();
  final who = what != null && what.isNotEmpty
      ? '${_article(what)} $what${where.isEmpty ? '' : ' in $where'}.'
      : where.isNotEmpty
          ? 'Based in $where.'
          : '';
  final matches = checks?.matchesYour ?? const <String>[];
  final match = matches.isEmpty
      ? ''
      : ' Matches ${matches.take(2).map((m) => '“$m”').join(' and ')} in your list of buyers.';
  return '$who$match'.trim();
}

/// "Won the Lakewood school renovation · SAM.gov contract awards, 20 Sep
/// 2026": what happened, where it was seen, when. Led with on every card.
String momentSaid(CandidateMoment m) => [
      m.said,
      [
        if (m.source.isNotEmpty) m.source,
        if (m.at != null) whenSaid(m.at!),
      ].join(', '),
    ].where((s) => s.isNotEmpty).join(' · ');

List<ProspectFact> prospectFacts(Candidate c) {
  final checks = c.checks;
  if (checks == null) return const [];
  return [
    for (final m in c.moments.take(2)) ProspectFact(Icons.bolt, momentSaid(m)),
    if (c.domain.isNotEmpty && !c.domain.startsWith('name:'))
      ProspectFact(Icons.language,
          '${c.domain}${checks.websiteAnswers ? ': its own site, answering' : ''}'),
    ProspectFact(
        Icons.alternate_email,
        '${checks.email}, published ${checks.addressFoundInSaid}'
        '${checks.mailboxConfirmed ? '; its mailbox accepts mail' : ''}'),
    if (checks.sources.isNotEmpty)
      ProspectFact(Icons.fact_check_outlined,
          'Seen in ${_joinAnd(checks.sources)}'),
    if (checks.checkedAt != null)
      ProspectFact(Icons.schedule, 'Checked ${whenSaid(checks.checkedAt!)}'),
  ];
}

/// "today · 4:42 PM", or "14 Sep 2026 · 5:18 PM". Always with the time.
String whenSaid(DateTime at) {
  final now = DateTime.now();
  final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
  final time = '$h:${at.minute.toString().padLeft(2, '0')} ${at.hour < 12 ? 'AM' : 'PM'}';
  if (at.year == now.year && at.month == now.month && at.day == now.day) {
    return 'today · $time';
  }
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${at.day} ${months[at.month - 1]} ${at.year} · $time';
}

String _article(String word) => RegExp(r'^[aeiou]', caseSensitive: false).hasMatch(word) ? 'An' : 'A';

String _joinAnd(List<String> items) => items.length <= 1
    ? items.join()
    : '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
