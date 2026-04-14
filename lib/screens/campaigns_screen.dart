import 'package:flutter/material.dart';

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

  String _subscriptionPlanLabel = 'Not set';
  String _subscriptionTier = '';
  String _campaignLane = 'opportunity';
  String _campaignMode = 'focused';

  final List<_NamedItem> _countries = [];
  final List<_RegionItem> _regions = [];
  final List<_MetroItem> _metros = [];
  final List<_NamedItem> _industries = [];
  final List<String> _includeGeo = [];
  final List<String> _excludeGeo = [];
  final List<String> _priorityMarkets = [];

  String? _selectedCountryCode;
  String? _selectedRegionKey;
  final TextEditingController _notesController = TextEditingController();

  static const List<String> _regionTypes = <String>[
    'state',
    'province',
    'region',
    'county',
    'territory',
  ];

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

  bool get _singleCountryPlan => _subscriptionTier == 'focused';

  List<_RegionItem> get _regionsForSelectedCountry {
    if (_selectedCountryCode == null) return const <_RegionItem>[];
    return _regions.where((item) => item.countryCode == _selectedCountryCode).toList();
  }

  List<_MetroItem> get _metrosForSelectedRegion {
    if (_selectedCountryCode == null || _selectedRegionKey == null) {
      return const <_MetroItem>[];
    }

    final region = _regions.firstWhere(
      (item) => item.key == _selectedRegionKey,
      orElse: () => const _RegionItem(
        countryCode: '',
        countryLabel: '',
        regionType: '',
        regionCode: '',
        regionLabel: '',
      ),
    );

    if (region.key.isEmpty) return const <_MetroItem>[];

    return _metros
        .where((item) => item.countryCode == region.countryCode && item.regionCode == region.regionCode)
        .toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        _campaignRepository.fetchCampaignProfile(),
        _billingRepository.fetchSubscription(),
      ]);

      final campaignJson = results[0] as Map<String, dynamic>;
      final subscriptionJson = results[1] as Map<String, dynamic>?;
      final profile = _asMap(campaignJson['campaignProfile']);

      _campaignLane = _string(profile['lane'], fallback: 'opportunity');
      _campaignMode = _string(profile['mode'], fallback: 'focused');
      _subscriptionPlanLabel = _resolveSubscriptionLabel(subscriptionJson);
      _subscriptionTier = _resolveSubscriptionTier(subscriptionJson);

      _countries
        ..clear()
        ..addAll(_readNamedItems(profile['countries']));
      _regions
        ..clear()
        ..addAll(_readRegions(profile['regions']));
      _metros
        ..clear()
        ..addAll(_readMetros(profile['metros']));
      _industries
        ..clear()
        ..addAll(_readNamedItems(profile['industries']));
      _includeGeo
        ..clear()
        ..addAll(_readStringList(profile['includeGeo']));
      _excludeGeo
        ..clear()
        ..addAll(_readStringList(profile['excludeGeo']));
      _priorityMarkets
        ..clear()
        ..addAll(_readStringList(profile['priorityMarkets']));

      _notesController.text = _string(profile['notes']);

      _selectedCountryCode = _countries.any((item) => item.code == _selectedCountryCode)
          ? _selectedCountryCode
          : (_countries.isNotEmpty ? _countries.first.code : null);

      final availableRegions = _regionsForSelectedCountry;
      _selectedRegionKey = availableRegions.any((item) => item.key == _selectedRegionKey)
          ? _selectedRegionKey
          : (availableRegions.isNotEmpty ? availableRegions.first.key : null);

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Campaign settings could not be loaded right now.';
      });
    }
  }

  Future<void> _save() async {
    if (_countries.isEmpty) {
      _showNotice('Add at least one country before saving.');
      return;
    }
    if (_industries.isEmpty) {
      _showNotice('Add at least one industry before saving.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _campaignRepository.updateCampaignProfile(
        profile: {
          'countries': _countries.map((item) => {'code': item.code, 'label': item.label}).toList(),
          'regions': _regions
              .map(
                (item) => {
                  'countryCode': item.countryCode,
                  'countryLabel': item.countryLabel,
                  'regionType': item.regionType,
                  'regionCode': item.regionCode,
                  'regionLabel': item.regionLabel,
                },
              )
              .toList(),
          'metros': _metros
              .map(
                (item) => {
                  'countryCode': item.countryCode,
                  'regionCode': item.regionCode,
                  'label': item.label,
                },
              )
              .toList(),
          'industries': _industries.map((item) => {'code': item.code, 'label': item.label}).toList(),
          'includeGeo': List<String>.from(_includeGeo),
          'excludeGeo': List<String>.from(_excludeGeo),
          'priorityMarkets': List<String>.from(_priorityMarkets),
          'notes': _notesController.text.trim(),
        },
      );

      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Campaign settings updated')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Campaign settings could not be saved right now.';
      });
    }
  }

  void _showNotice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openAddCountryDialog() async {
    final codeController = TextEditingController();
    final labelController = TextEditingController();

    final result = await showDialog<_NamedItem>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add country'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Country code'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: 'Country label'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final code = codeController.text.trim().toUpperCase();
              final label = labelController.text.trim();
              if (code.isEmpty || label.isEmpty) return;
              Navigator.pop(context, _NamedItem(code: code, label: label));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    codeController.dispose();
    labelController.dispose();

    if (result == null) return;
    if (_countries.any((item) => item.code.toUpperCase() == result.code)) {
      _showNotice('That country is already in this campaign.');
      return;
    }
    if (_singleCountryPlan && _countries.isNotEmpty) {
      _showNotice('The current plan allows one country only. Upgrade the plan to add more.');
      return;
    }

    setState(() {
      _countries.add(result);
      _selectedCountryCode = result.code;
      _selectedRegionKey = null;
    });
  }

  Future<void> _openAddRegionDialog() async {
    if (_selectedCountryCode == null) {
      _showNotice('Select a country first.');
      return;
    }

    final codeController = TextEditingController();
    final labelController = TextEditingController();
    String selectedType = _regionTypes.first;

    final result = await showDialog<_RegionItem>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Add region'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Region type'),
                items: _regionTypes
                    .map((type) => DropdownMenuItem<String>(value: type, child: Text(_humanize(type))))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setLocalState(() => selectedType = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'Region code'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: labelController,
                decoration: const InputDecoration(labelText: 'Region label'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final regionCode = codeController.text.trim();
                final regionLabel = labelController.text.trim();
                if (regionCode.isEmpty || regionLabel.isEmpty) return;

                final country = _countries.firstWhere(
                  (item) => item.code == _selectedCountryCode,
                  orElse: () => const _NamedItem(code: '', label: ''),
                );
                if (country.code.isEmpty) return;

                Navigator.pop(
                  context,
                  _RegionItem(
                    countryCode: country.code,
                    countryLabel: country.label,
                    regionType: selectedType,
                    regionCode: regionCode,
                    regionLabel: regionLabel,
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    codeController.dispose();
    labelController.dispose();

    if (result == null) return;
    if (_regions.any((item) => item.key == result.key)) {
      _showNotice('That region is already in this campaign.');
      return;
    }

    setState(() {
      _regions.add(result);
      _selectedRegionKey = result.key;
    });
  }

  Future<void> _openAddMetroDialog() async {
    if (_selectedCountryCode == null || _selectedRegionKey == null) {
      _showNotice('Select a country and region first.');
      return;
    }

    final labelController = TextEditingController();

    final result = await showDialog<_MetroItem>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add city or metro'),
        content: TextField(
          controller: labelController,
          decoration: const InputDecoration(labelText: 'City or metro label'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final label = labelController.text.trim();
              if (label.isEmpty) return;

              final region = _regions.firstWhere(
                (item) => item.key == _selectedRegionKey,
                orElse: () => const _RegionItem(
                  countryCode: '',
                  countryLabel: '',
                  regionType: '',
                  regionCode: '',
                  regionLabel: '',
                ),
              );
              if (region.key.isEmpty) return;

              Navigator.pop(
                context,
                _MetroItem(
                  countryCode: region.countryCode,
                  regionCode: region.regionCode,
                  label: label,
                ),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    labelController.dispose();

    if (result == null) return;
    final exists = _metros.any(
      (item) =>
          item.countryCode == result.countryCode &&
          item.regionCode == result.regionCode &&
          item.label.toLowerCase() == result.label.toLowerCase(),
    );
    if (exists) {
      _showNotice('That city or metro is already in this campaign.');
      return;
    }

    setState(() => _metros.add(result));
  }

  Future<void> _openAddIndustryDialog() async {
    final codeController = TextEditingController();
    final labelController = TextEditingController();

    final result = await showDialog<_NamedItem>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add industry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: 'Industry code'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: 'Industry label'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final code = codeController.text.trim().toLowerCase();
              final label = labelController.text.trim();
              if (code.isEmpty || label.isEmpty) return;
              Navigator.pop(context, _NamedItem(code: code, label: label));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    codeController.dispose();
    labelController.dispose();

    if (result == null) return;
    if (_industries.any((item) => item.code.toLowerCase() == result.code)) {
      _showNotice('That industry is already in this campaign.');
      return;
    }

    setState(() => _industries.add(result));
  }

  Future<void> _openAddStringDialog({
    required String title,
    required List<String> target,
  }) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Value'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(context, value);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (result == null) return;
    if (target.any((entry) => entry.toLowerCase() == result.toLowerCase())) {
      _showNotice('That value is already listed.');
      return;
    }

    setState(() => target.add(result));
  }

  void _removeCountry(_NamedItem item) {
    setState(() {
      _countries.removeWhere((entry) => entry.code == item.code);
      _regions.removeWhere((entry) => entry.countryCode == item.code);
      _metros.removeWhere((entry) => entry.countryCode == item.code);

      if (_selectedCountryCode == item.code) {
        _selectedCountryCode = _countries.isNotEmpty ? _countries.first.code : null;
        _selectedRegionKey = null;
      }
    });
  }

  void _removeRegion(_RegionItem item) {
    setState(() {
      _regions.removeWhere((entry) => entry.key == item.key);
      _metros.removeWhere(
        (entry) => entry.countryCode == item.countryCode && entry.regionCode == item.regionCode,
      );

      if (_selectedRegionKey == item.key) {
        final nextRegions = _regionsForSelectedCountry;
        _selectedRegionKey = nextRegions.isNotEmpty ? nextRegions.first.key : null;
      }
    });
  }

  void _removeMetro(_MetroItem item) {
    setState(() {
      _metros.removeWhere(
        (entry) =>
            entry.countryCode == item.countryCode &&
            entry.regionCode == item.regionCode &&
            entry.label == item.label,
      );
    });
  }

  void _removeIndustry(_NamedItem item) {
    setState(() => _industries.removeWhere((entry) => entry.code == item.code));
  }

  void _removeStringItem(String value, List<String> target) {
    setState(() => target.remove(value));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && !_saving) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroCard(
            title: 'Campaign settings',
            subtitle:
                'Control targeting, geography, market boundaries, and operating notes from one client surface.',
          ),
          const SizedBox(height: 18),
          _StatusStrip(
            subscriptionPlanLabel: _subscriptionPlanLabel,
            campaignLane: _humanize(_campaignLane),
            campaignMode: _humanize(_campaignMode),
            countryCount: _countries.length,
            regionCount: _regions.length,
            metroCount: _metros.length,
            industryCount: _industries.length,
          ),
          const SizedBox(height: 18),
          _Panel(
            title: 'Geography flow',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StepHeader(
                  step: '1',
                  title: 'Countries',
                  subtitle: _singleCountryPlan
                      ? 'This plan currently supports one country.'
                      : 'Select one or more countries for this campaign.',
                ),
                const SizedBox(height: 12),
                _FlowChipWrap(
                  children: _countries
                      .map(
                        (item) => ChoiceChip(
                          label: Text(item.label),
                          selected: _selectedCountryCode == item.code,
                          onSelected: (_) {
                            setState(() {
                              _selectedCountryCode = item.code;
                              final nextRegions = _regionsForSelectedCountry;
                              _selectedRegionKey = nextRegions.isNotEmpty ? nextRegions.first.key : null;
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton(onPressed: _openAddCountryDialog, child: const Text('Add country')),
                    const SizedBox(width: 10),
                    if (_countries.isNotEmpty)
                      Text(
                        '${_countries.length} selected',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: const Color(0xFF6B7280)),
                      ),
                  ],
                ),
                if (_countries.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _countries
                        .map(
                          (item) => InputChip(
                            label: Text('${item.label} (${item.code})'),
                            onDeleted: () => _removeCountry(item),
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (_selectedCountryCode != null) ...[
                  const SizedBox(height: 26),
                  _StepHeader(
                    step: '2',
                    title: 'Regions',
                    subtitle: "After selecting a country, only that country's regions stay in view.",
                  ),
                  const SizedBox(height: 12),
                  _FlowChipWrap(
                    children: _regionsForSelectedCountry
                        .map(
                          (item) => ChoiceChip(
                            label: Text(item.regionLabel),
                            selected: _selectedRegionKey == item.key,
                            onSelected: (_) => setState(() => _selectedRegionKey = item.key),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton(onPressed: _openAddRegionDialog, child: const Text('Add region')),
                      const SizedBox(width: 10),
                      if (_regionsForSelectedCountry.isNotEmpty)
                        Text(
                          '${_regionsForSelectedCountry.length} listed',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: const Color(0xFF6B7280)),
                        ),
                    ],
                  ),
                  if (_regionsForSelectedCountry.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _regionsForSelectedCountry
                          .map(
                            (item) => InputChip(
                              label: Text('${item.regionLabel} (${item.regionType})'),
                              onDeleted: () => _removeRegion(item),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
                if (_selectedRegionKey != null) ...[
                  const SizedBox(height: 26),
                  _StepHeader(
                    step: '3',
                    title: 'Cities and metros',
                    subtitle: 'After selecting a region, city and metro targets appear beneath it.',
                  ),
                  const SizedBox(height: 12),
                  _FlowChipWrap(
                    children: _metrosForSelectedRegion.map((item) => Chip(label: Text(item.label))).toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton(onPressed: _openAddMetroDialog, child: const Text('Add metro')),
                      const SizedBox(width: 10),
                      if (_metrosForSelectedRegion.isNotEmpty)
                        Text(
                          '${_metrosForSelectedRegion.length} listed',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: const Color(0xFF6B7280)),
                        ),
                    ],
                  ),
                  if (_metrosForSelectedRegion.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _metrosForSelectedRegion
                          .map(
                            (item) => InputChip(
                              label: Text(item.label),
                              onDeleted: () => _removeMetro(item),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          _Panel(
            title: 'Industry and market controls',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StepHeader(
                  step: '4',
                  title: 'Industries',
                  subtitle: 'Keep industry targeting visible and editable without burying it in a setup flow.',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton(onPressed: _openAddIndustryDialog, child: const Text('Add industry')),
                    const SizedBox(width: 10),
                    if (_industries.isNotEmpty)
                      Text(
                        '${_industries.length} listed',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: const Color(0xFF6B7280)),
                      ),
                  ],
                ),
                if (_industries.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _industries
                        .map(
                          (item) => InputChip(
                            label: Text('${item.label} (${item.code})'),
                            onDeleted: () => _removeIndustry(item),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 26),
                _StringListSection(
                  title: 'Include geography',
                  hint: 'Specific markets that should be included.',
                  items: _includeGeo,
                  emptyText: 'No inclusion rules added yet.',
                  onAdd: () => _openAddStringDialog(title: 'Add included geography', target: _includeGeo),
                  onRemove: (value) => _removeStringItem(value, _includeGeo),
                ),
                const SizedBox(height: 24),
                _StringListSection(
                  title: 'Exclude geography',
                  hint: 'Markets or areas that should stay outside this campaign.',
                  items: _excludeGeo,
                  emptyText: 'No exclusion rules added yet.',
                  onAdd: () => _openAddStringDialog(title: 'Add excluded geography', target: _excludeGeo),
                  onRemove: (value) => _removeStringItem(value, _excludeGeo),
                ),
                const SizedBox(height: 24),
                _StringListSection(
                  title: 'Priority markets',
                  hint: 'Markets to prioritize first.',
                  items: _priorityMarkets,
                  emptyText: 'No priority markets added yet.',
                  onAdd: () => _openAddStringDialog(title: 'Add priority market', target: _priorityMarkets),
                  onRemove: (value) => _removeStringItem(value, _priorityMarkets),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _Panel(
            title: 'Operating notes',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Use this to keep campaign-specific constraints, guidance, or important operating context in one place.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: 'Add campaign notes',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving...' : 'Save changes'),
              ),
              const SizedBox(width: 10),
              OutlinedButton(onPressed: _saving ? null : _load, child: const Text('Reload')),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFF6B7280))),
        ],
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.subscriptionPlanLabel,
    required this.campaignLane,
    required this.campaignMode,
    required this.countryCount,
    required this.regionCount,
    required this.metroCount,
    required this.industryCount,
  });

  final String subscriptionPlanLabel;
  final String campaignLane;
  final String campaignMode;
  final int countryCount;
  final int regionCount;
  final int metroCount;
  final int industryCount;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _MetricTile(label: 'Subscription', value: subscriptionPlanLabel),
        _MetricTile(label: 'Campaign lane', value: campaignLane),
        _MetricTile(label: 'Campaign mode', value: campaignMode),
        _MetricTile(label: 'Countries', value: '$countryCount'),
        _MetricTile(label: 'Regions', value: '$regionCount'),
        _MetricTile(label: 'Metros', value: '$metroCount'),
        _MetricTile(label: 'Industries', value: '$industryCount'),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.title, required this.subtitle});

  final String step;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(radius: 16, backgroundColor: const Color(0xFFF3F4F6), child: Text(step)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280))),
            ],
          ),
        ),
      ],
    );
  }
}

class _FlowChipWrap extends StatelessWidget {
  const _FlowChipWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return Text('Nothing selected yet.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280)));
    }
    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }
}

class _StringListSection extends StatelessWidget {
  const _StringListSection({
    required this.title,
    required this.hint,
    required this.items,
    required this.emptyText,
    required this.onAdd,
    required this.onRemove,
  });

  final String title;
  final String hint;
  final List<String> items;
  final String emptyText;
  final VoidCallback onAdd;
  final void Function(String value) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(hint, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280))),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Text(emptyText, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280)))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) => InputChip(label: Text(item), onDeleted: () => onRemove(item))).toList(),
          ),
        const SizedBox(height: 12),
        FilledButton(onPressed: onAdd, child: const Text('Add item')),
      ],
    );
  }
}

class _NamedItem {
  const _NamedItem({required this.code, required this.label});
  final String code;
  final String label;
}

class _RegionItem {
  const _RegionItem({
    required this.countryCode,
    required this.countryLabel,
    required this.regionType,
    required this.regionCode,
    required this.regionLabel,
  });

  final String countryCode;
  final String countryLabel;
  final String regionType;
  final String regionCode;
  final String regionLabel;

  String get key => '$countryCode::$regionCode';
}

class _MetroItem {
  const _MetroItem({required this.countryCode, required this.regionCode, required this.label});
  final String countryCode;
  final String regionCode;
  final String label;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return const <String, dynamic>{};
}

String _string(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _humanize(String value) {
  final text = value.trim();
  if (text.isEmpty) return 'Not set';
  return text
      .split(RegExp(r'[\s_-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
      .join(' ');
}

String _resolveSubscriptionLabel(Map<String, dynamic>? subscription) {
  if (subscription == null || subscription.isEmpty) return 'Not set';

  final explicit = _string(subscription['displayPlanLabel']);
  if (explicit.isNotEmpty) return explicit;

  final plan = _string(subscription['plan']);
  final service = _string(subscription['service']);
  final lane = _string(subscription['lane']);
  final tier = _string(subscription['tier']);

  final primaryPlan = service.isNotEmpty ? service : lane.isNotEmpty ? lane : plan;
  final humanPlan = _humanize(primaryPlan);
  final humanTier = _humanize(tier);

  if (humanPlan.isEmpty && humanTier.isEmpty) return 'Not set';
  if (humanPlan.isEmpty) return humanTier;
  if (humanTier.isEmpty) return humanPlan;
  return '$humanPlan · $humanTier';
}

String _resolveSubscriptionTier(Map<String, dynamic>? subscription) {
  if (subscription == null || subscription.isEmpty) return '';
  return _string(subscription['tier']).toLowerCase();
}

List<_NamedItem> _readNamedItems(dynamic value) {
  if (value is! List) return const [];
  final items = <_NamedItem>[];
  final seen = <String>{};
  for (final entry in value) {
    final map = _asMap(entry);
    final code = _string(map['code']);
    final label = _string(map['label']);
    if (code.isEmpty || label.isEmpty) continue;
    final key = code.toLowerCase();
    if (seen.contains(key)) continue;
    seen.add(key);
    items.add(_NamedItem(code: code, label: label));
  }
  return items;
}

List<_RegionItem> _readRegions(dynamic value) {
  if (value is! List) return const [];
  final items = <_RegionItem>[];
  final seen = <String>{};
  for (final entry in value) {
    final map = _asMap(entry);
    final countryCode = _string(map['countryCode']).toUpperCase();
    final countryLabel = _string(map['countryLabel']);
    final regionType = _string(map['regionType']);
    final regionCode = _string(map['regionCode']);
    final regionLabel = _string(map['regionLabel']);
    if (countryCode.isEmpty || countryLabel.isEmpty || regionType.isEmpty || regionCode.isEmpty || regionLabel.isEmpty) {
      continue;
    }
    final key = '$countryCode::$regionCode';
    if (seen.contains(key)) continue;
    seen.add(key);
    items.add(_RegionItem(
      countryCode: countryCode,
      countryLabel: countryLabel,
      regionType: regionType,
      regionCode: regionCode,
      regionLabel: regionLabel,
    ));
  }
  return items;
}

List<_MetroItem> _readMetros(dynamic value) {
  if (value is! List) return const [];
  final items = <_MetroItem>[];
  final seen = <String>{};
  for (final entry in value) {
    final map = _asMap(entry);
    final countryCode = _string(map['countryCode']).toUpperCase();
    final regionCode = _string(map['regionCode']);
    final label = _string(map['label']);
    if (countryCode.isEmpty || regionCode.isEmpty || label.isEmpty) continue;
    final key = '$countryCode::$regionCode::${label.toLowerCase()}';
    if (seen.contains(key)) continue;
    seen.add(key);
    items.add(_MetroItem(countryCode: countryCode, regionCode: regionCode, label: label));
  }
  return items;
}

List<String> _readStringList(dynamic value) {
  if (value is! List) return const [];
  final items = <String>[];
  final seen = <String>{};
  for (final entry in value) {
    final text = _string(entry);
    if (text.isEmpty) continue;
    final key = text.toLowerCase();
    if (seen.contains(key)) continue;
    seen.add(key);
    items.add(text);
  }
  return items;
}
