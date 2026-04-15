import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/repositories/client/client_outreach_repository.dart';
import '../data/repositories/client/client_workspace_repository.dart';

class LeadsScreen extends StatelessWidget {
  const LeadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LeadViewData>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const Center(child: Text('Lead generation could not load right now.'));
        }
        final data = snapshot.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.only(top: 12, bottom: 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Hero(total: data.totalLeads, sendable: data.sendableLeads),
            const SizedBox(height: 18),
            _StatusRow(cards: [
              _StatusCardData(label: 'Leads', value: '${data.totalLeads}'),
              _StatusCardData(label: 'Sendable', value: '${data.sendableLeads}'),
              _StatusCardData(label: 'Replies', value: '${data.replyCount}'),
              _StatusCardData(label: 'Dispatches', value: '${data.dispatchCount}'),
            ]),
            const SizedBox(height: 18),
            _Panel(title: 'Recent lead movement', emptyLabel: 'Lead movement will appear here once sourcing and outreach begin.', items: data.rows),
          ]),
        );
      },
    );
  }

  Future<_LeadViewData> _load() async {
    final workspaceRepo = ClientWorkspaceRepository();
    final outreachRepo = ClientOutreachRepository();
    final overview = await workspaceRepo.fetchOverview();
    final replies = await outreachRepo.fetchReplies(limit: 12);
    final dispatches = await outreachRepo.fetchEmailDispatches();

    final activity = _asMap(overview['activity']);
    final totalLeads = _countValue(activity['leadCount'] ?? activity['leads'] ?? activity['prospects']);
    final sendableLeads = _countValue(activity['sendableLeadCount'] ?? activity['sendableLeads'] ?? activity['queuedLeads']);

    final rows = <_LeadRow>[];
    for (final item in dispatches.take(8)) {
      final map = _asMap(item);
      rows.add(_LeadRow(
        title: _firstNonEmpty([_read(map, 'recipientName'), _read(map, 'toEmail'), 'Outbound lead']),
        primary: _join([_read(map, 'companyName'), _read(map, 'subject'), _title(_read(map, 'status'))]),
        secondary: _join([_read(map, 'sentAt'), _read(map, 'deliveryChannel')]),
      ));
    }
    for (final item in replies.take(8)) {
      final map = _asMap(item);
      final lead = _asMap(map['lead']);
      rows.add(_LeadRow(
        title: _firstNonEmpty([_read(lead, 'fullName'), _read(map, 'fromEmail'), 'Reply received']),
        primary: _join([_read(lead, 'companyName'), _title(_read(map, 'intent')), _title(_read(map, 'status'))]),
        secondary: _join([_read(map, 'receivedAt'), _read(map, 'subjectLine')]),
      ));
    }

    return _LeadViewData(
      totalLeads: totalLeads,
      sendableLeads: sendableLeads,
      replyCount: replies.length,
      dispatchCount: dispatches.length,
      rows: rows,
    );
  }
}

class _LeadViewData { const _LeadViewData({required this.totalLeads, required this.sendableLeads, required this.replyCount, required this.dispatchCount, required this.rows}); final int totalLeads; final int sendableLeads; final int replyCount; final int dispatchCount; final List<_LeadRow> rows; }
class _LeadRow { const _LeadRow({required this.title, required this.primary, required this.secondary}); final String title; final String primary; final String secondary; }
class _Hero extends StatelessWidget { const _Hero({required this.total, required this.sendable}); final int total; final int sendable; @override Widget build(BuildContext context){ return Container(width: double.infinity,padding: const EdgeInsets.all(28),decoration: BoxDecoration(color: Colors.white,borderRadius: BorderRadius.circular(28),border: Border.all(color: AppTheme.publicLine)),child: Column(crossAxisAlignment: CrossAxisAlignment.start,children:[Text('Lead generation', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.publicMuted)), const SizedBox(height: 10), Text(total == 0 ? 'No leads are visible yet' : '$total leads currently visible', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 12), Text(sendable == 0 ? 'This screen separates sourced records from sendable records so the client can see what is actually ready for outreach.' : '$sendable leads appear ready for outreach from the current client-side view.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.publicMuted))])); }}
class _StatusCardData { const _StatusCardData({required this.label, required this.value}); final String label; final String value; }
class _StatusRow extends StatelessWidget { const _StatusRow({required this.cards}); final List<_StatusCardData> cards; @override Widget build(BuildContext context){ return LayoutBuilder(builder:(context,constraints){ if(constraints.maxWidth<860){ return Column(children:[for(int i=0;i<cards.length;i++) ...[_StatusTile(card: cards[i]), if(i!=cards.length-1) const SizedBox(height:12)]]);} return Row(children:[for(int i=0;i<cards.length;i++) ...[Expanded(child:_StatusTile(card: cards[i])), if(i!=cards.length-1) const SizedBox(width:12)]]);}); }}
class _StatusTile extends StatelessWidget { const _StatusTile({required this.card}); final _StatusCardData card; @override Widget build(BuildContext context){ return Container(padding: const EdgeInsets.all(18),decoration: BoxDecoration(color: Colors.white,borderRadius: BorderRadius.circular(22),border: Border.all(color: AppTheme.publicLine)),child: Column(crossAxisAlignment: CrossAxisAlignment.start,children:[Text(card.label, style: Theme.of(context).textTheme.bodyMedium), const SizedBox(height:10), Text(card.value, style: Theme.of(context).textTheme.titleLarge)])); }}
class _Panel extends StatelessWidget { const _Panel({required this.title, required this.emptyLabel, required this.items}); final String title; final String emptyLabel; final List<_LeadRow> items; @override Widget build(BuildContext context){ return Container(width: double.infinity,padding: const EdgeInsets.all(24),decoration: BoxDecoration(color: Colors.white,borderRadius: BorderRadius.circular(28),border: Border.all(color: AppTheme.publicLine)),child: Column(crossAxisAlignment: CrossAxisAlignment.start,children:[Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height:16), if(items.isEmpty) Text(emptyLabel, style: Theme.of(context).textTheme.bodyMedium) else for(int i=0;i<items.length;i++) ...[_LeadTile(item: items[i]), if(i!=items.length-1) const Divider(height:22)]])); }}
class _LeadTile extends StatelessWidget { const _LeadTile({required this.item}); final _LeadRow item; @override Widget build(BuildContext context){ return Column(crossAxisAlignment: CrossAxisAlignment.start,children:[Text(item.title, style: Theme.of(context).textTheme.titleLarge), if(item.primary.isNotEmpty)...[const SizedBox(height:6), Text(item.primary, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.publicText))], if(item.secondary.isNotEmpty)...[const SizedBox(height:4), Text(item.secondary, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.publicMuted))]]); }}
Map<String, dynamic> _asMap(dynamic value){ if(value is Map<String,dynamic>) return value; if(value is Map) return value.map((k,v)=>MapEntry(k.toString(),v)); return const {}; }
String _read(Map<String,dynamic> map,String key){ final value=map[key]; if(value==null) return ''; return value.toString().trim(); }
int _countValue(dynamic value){ if(value is num) return value.toInt(); return int.tryParse((value??'').toString()) ?? 0; }
String _firstNonEmpty(List<String> values){ for(final v in values){ if(v.trim().isNotEmpty) return v.trim(); } return ''; }
String _join(List<String> values)=> values.where((e)=>e.trim().isNotEmpty).join(' · ');
String _title(String value){ if(value.trim().isEmpty) return ''; return value.split(RegExp(r'[_\s-]+')).map((e)=>e.isEmpty?e:'${e[0].toUpperCase()}${e.substring(1).toLowerCase()}').join(' '); }
