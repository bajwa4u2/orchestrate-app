import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/repositories/client/client_billing_repository.dart';
import '../data/repositories/client/client_campaign_repository.dart';

class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({super.key});

  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> {
  final ClientCampaignRepository _campaignRepository = ClientCampaignRepository();
  final ClientBillingRepository _billingRepository = ClientBillingRepository();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, dynamic> _profile = const {};
  Map<String, dynamic>? _subscription;

  List<_NamedItem> _countries = [];
  List<_NamedItem> _industries = [];
  List<String> _priorityMarkets = [];
  List<String> _includeGeo = [];
  List<String> _excludeGeo = [];
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait<dynamic>([
        _campaignRepository.fetchCampaignProfile(),
        _billingRepository.fetchSubscription(),
      ]);
      final campaignJson = Map<String, dynamic>.from(results[0] as Map);
      _subscription = results[1] == null ? null : Map<String, dynamic>.from(results[1] as Map);
      _profile = _asMap(campaignJson['campaignProfile']);
      _countries = _readNamedItems(_profile['countries']);
      _industries = _readNamedItems(_profile['industries']);
      _priorityMarkets = _readStringList(_profile['priorityMarkets']);
      _includeGeo = _readStringList(_profile['includeGeo']);
      _excludeGeo = _readStringList(_profile['excludeGeo']);
      _notesController.text = _read(_profile, 'notes');
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Campaign settings could not load right now.'; });
    }
  }

  Future<void> _save() async {
    if (_countries.isEmpty) return _showNotice('Add at least one country before saving.');
    if (_industries.isEmpty) return _showNotice('Add at least one industry before saving.');
    setState(() { _saving = true; _error = null; });
    try {
      final payload = Map<String, dynamic>.from(_profile);
      payload['countries'] = _countries.map((e) => {'code': e.code, 'label': e.label}).toList();
      payload['industries'] = _industries.map((e) => {'code': e.code, 'label': e.label}).toList();
      payload['priorityMarkets'] = List<String>.from(_priorityMarkets);
      payload['includeGeo'] = List<String>.from(_includeGeo);
      payload['excludeGeo'] = List<String>.from(_excludeGeo);
      payload['notes'] = _notesController.text.trim();
      await _campaignRepository.updateCampaignProfile(profile: payload);
      if (!mounted) return;
      setState(() { _saving = false; _profile = payload; });
      _showNotice('Campaign settings updated.');
    } catch (_) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'Campaign settings could not be saved right now.'; });
    }
  }

  void _showNotice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addNamedItem({required String title, required List<_NamedItem> target}) async {
    final codeController = TextEditingController();
    final labelController = TextEditingController();
    final result = await showDialog<_NamedItem>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: codeController, decoration: const InputDecoration(labelText: 'Code')),
          const SizedBox(height: 12),
          TextField(controller: labelController, decoration: const InputDecoration(labelText: 'Label')),
        ]),
        actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () {
          final code = codeController.text.trim();
          final label = labelController.text.trim();
          if (code.isEmpty || label.isEmpty) return;
          Navigator.pop(context, _NamedItem(code: code, label: label));
        }, child: const Text('Add'))],
      ),
    );
    codeController.dispose();
    labelController.dispose();
    if (result == null) return;
    if (target.any((e) => e.code.toLowerCase() == result.code.toLowerCase())) {
      return _showNotice('That entry already exists.');
    }
    setState(() => target.add(result));
  }

  Future<void> _addTextValue({required String title, required List<String> target}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Value')),
        actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () {
          final value = controller.text.trim();
          if (value.isEmpty) return;
          Navigator.pop(context, value);
        }, child: const Text('Add'))],
      ),
    );
    controller.dispose();
    if (result == null) return;
    if (target.any((e) => e.toLowerCase() == result.toLowerCase())) {
      return _showNotice('That entry already exists.');
    }
    setState(() => target.add(result));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));

    final planLabel = _join([
      _read(_subscription ?? const {}, 'serviceName', fallback: _read(_subscription ?? const {}, 'service', fallback: 'Not set')),
      _read(_subscription ?? const {}, 'tierName', fallback: _read(_subscription ?? const {}, 'tier')),
    ]);
    final regions = _readListLength(_profile['regions']);
    final metros = _readListLength(_profile['metros']);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Hero(planLabel: planLabel.isEmpty ? 'Not set' : planLabel),
        const SizedBox(height: 18),
        _MetricRow(items: [
          _MetricItem('Countries', '${_countries.length}'),
          _MetricItem('Industries', '${_industries.length}'),
          _MetricItem('Regions', '$regions'),
          _MetricItem('Metros', '$metros'),
        ]),
        const SizedBox(height: 18),
        if (_error != null) ...[
          Text(_error!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red)),
          const SizedBox(height: 18),
        ],
        _SectionCard(
          title: 'Targeting',
          subtitle: 'This is the one place to define the scope used for lead generation. Setup should not compete with this screen.',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _EditableChipGroup(title: 'Countries', items: _countries.map((e) => e.label).toList(), onAdd: ()=>_addNamedItem(title: 'Add country', target: _countries), onRemove: (label) => setState(()=>_countries.removeWhere((e)=>e.label==label))),
            const SizedBox(height: 18),
            _EditableChipGroup(title: 'Industries', items: _industries.map((e) => e.label).toList(), onAdd: ()=>_addNamedItem(title: 'Add industry', target: _industries), onRemove: (label) => setState(()=>_industries.removeWhere((e)=>e.label==label))),
            const SizedBox(height: 18),
            _EditableChipGroup(title: 'Priority markets', items: _priorityMarkets, onAdd: ()=>_addTextValue(title: 'Add priority market', target: _priorityMarkets), onRemove: (value) => setState(()=>_priorityMarkets.remove(value))),
            const SizedBox(height: 18),
            _EditableChipGroup(title: 'Include geography', items: _includeGeo, onAdd: ()=>_addTextValue(title: 'Add include geography', target: _includeGeo), onRemove: (value) => setState(()=>_includeGeo.remove(value))),
            const SizedBox(height: 18),
            _EditableChipGroup(title: 'Exclude geography', items: _excludeGeo, onAdd: ()=>_addTextValue(title: 'Add exclude geography', target: _excludeGeo), onRemove: (value) => setState(()=>_excludeGeo.remove(value))),
            const SizedBox(height: 18),
            TextField(controller: _notesController, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Notes for targeting and outreach')),
          ]),
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Saved scope already on record',
          subtitle: 'Regions and metros stay visible here so the client can see what the backend will use without opening a second editor.',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _ReadOnlyList(title: 'Regions', values: _readStructuredLabels(_profile['regions'], ['regionLabel', 'regionCode'])),
            const SizedBox(height: 16),
            _ReadOnlyList(title: 'Metros', values: _readStructuredLabels(_profile['metros'], ['label'])),
          ]),
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save campaign settings'),
          ),
        ),
      ]),
    );
  }
}

class _NamedItem { const _NamedItem({required this.code, required this.label}); final String code; final String label; }
class _MetricItem { const _MetricItem(this.label, this.value); final String label; final String value; }
class _Hero extends StatelessWidget { const _Hero({required this.planLabel}); final String planLabel; @override Widget build(BuildContext context){ return Container(width: double.infinity,padding: const EdgeInsets.all(28),decoration: BoxDecoration(color: Colors.white,borderRadius: BorderRadius.circular(28),border: Border.all(color: AppTheme.publicLine)),child: Column(crossAxisAlignment: CrossAxisAlignment.start,children:[Text('Campaign targeting', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 12), Text('Lead generation should start here. This screen now owns targeting so the client does not face duplicate setup editors.', style: Theme.of(context).textTheme.bodyLarge), const SizedBox(height: 16), Text('Plan: $planLabel', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))])); }}
class _MetricRow extends StatelessWidget { const _MetricRow({required this.items}); final List<_MetricItem> items; @override Widget build(BuildContext context){ return LayoutBuilder(builder:(context,constraints){ final widgets=items.map((item)=>Container(padding: const EdgeInsets.all(18),decoration: BoxDecoration(color: Colors.white,borderRadius: BorderRadius.circular(22),border: Border.all(color: AppTheme.publicLine)),child: Column(crossAxisAlignment: CrossAxisAlignment.start,children:[Text(item.label, style: Theme.of(context).textTheme.bodyMedium), const SizedBox(height: 10), Text(item.value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))]))).toList(); if(constraints.maxWidth<900) return Column(children:[for(final w in widgets)...[w,const SizedBox(height:12)]]); return Row(children:[for(int i=0;i<widgets.length;i++) ...[Expanded(child: widgets[i]), if(i<widgets.length-1) const SizedBox(width:12)]]);}); }}
class _SectionCard extends StatelessWidget { const _SectionCard({required this.title, required this.subtitle, required this.child}); final String title; final String subtitle; final Widget child; @override Widget build(BuildContext context){ return Container(width: double.infinity,padding: const EdgeInsets.all(24),decoration: BoxDecoration(color: Colors.white,borderRadius: BorderRadius.circular(28),border: Border.all(color: AppTheme.publicLine)),child: Column(crossAxisAlignment: CrossAxisAlignment.start,children:[Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 8), Text(subtitle, style: Theme.of(context).textTheme.bodyMedium), const SizedBox(height: 18), child])); }}
class _EditableChipGroup extends StatelessWidget { const _EditableChipGroup({required this.title, required this.items, required this.onAdd, required this.onRemove}); final String title; final List<String> items; final VoidCallback onAdd; final ValueChanged<String> onRemove; @override Widget build(BuildContext context){ return Column(crossAxisAlignment: CrossAxisAlignment.start,children:[Row(children:[Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))), FilledButton.tonal(onPressed: onAdd, child: const Text('Add'))]), const SizedBox(height: 12), if(items.isEmpty) Text('Nothing added yet.', style: Theme.of(context).textTheme.bodyMedium) else Wrap(spacing: 10,runSpacing: 10,children: items.map((item)=>InputChip(label: Text(item), onDeleted: ()=>onRemove(item))).toList())]); }}
class _ReadOnlyList extends StatelessWidget { const _ReadOnlyList({required this.title, required this.values}); final String title; final List<String> values; @override Widget build(BuildContext context){ return Column(crossAxisAlignment: CrossAxisAlignment.start,children:[Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 12), if(values.isEmpty) Text('Nothing on record yet.', style: Theme.of(context).textTheme.bodyMedium) else Wrap(spacing: 10, runSpacing: 10, children: values.map((v)=>Chip(label: Text(v))).toList())]); }}

Map<String, dynamic> _asMap(dynamic value){ if(value is Map<String,dynamic>) return value; if(value is Map) return value.map((k,v)=>MapEntry(k.toString(),v)); return const {}; }
String _read(Map<String,dynamic> map,String key,{String fallback=''}){ final v=map[key]; if(v==null) return fallback; final s=v.toString().trim(); return s.isEmpty?fallback:s; }
List<_NamedItem> _readNamedItems(dynamic raw){ if(raw is! List) return []; return raw.map((item){ final map=_asMap(item); return _NamedItem(code: _read(map,'code',fallback:_read(map,'value')), label: _read(map,'label',fallback:_read(map,'name',fallback:_read(map,'code')))); }).where((e)=>e.label.isNotEmpty).toList(); }
List<String> _readStringList(dynamic raw){ if(raw is! List) return []; return raw.map((e)=>e.toString().trim()).where((e)=>e.isNotEmpty).toList(); }
int _readListLength(dynamic raw)=> raw is List ? raw.length : 0;
List<String> _readStructuredLabels(dynamic raw,List<String> keys){ if(raw is! List) return []; return raw.map((item){ final map=_asMap(item); for(final key in keys){ final value=_read(map,key); if(value.isNotEmpty) return value; } return ''; }).where((e)=>e.isNotEmpty).toList(); }
String _join(List<String> values)=> values.where((e)=>e.trim().isNotEmpty).join(' · ');
