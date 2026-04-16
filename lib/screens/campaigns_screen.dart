import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _industryController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _starting = false;
  bool _campaignActive = false;
  String? _activationMessage;
  String? _error;

  String _subscriptionPlanLabel = 'Current plan';
  String _subscriptionTier = '';
  String _campaignLane = 'opportunity';
  String _campaignMode = 'focused';

  final List<_NamedItem> _countries = <_NamedItem>[];
  final List<_RegionItem> _regions = <_RegionItem>[];
  final List<_MetroItem> _metros = <_MetroItem>[];
  final List<_NamedItem> _industries = <_NamedItem>[];

  String? _activeCountryCode;
  String? _activeRegionKey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _countryController.dispose();
    _regionController.dispose();
    _cityController.dispose();
    _industryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<_RegionItem> get _regionsForActiveCountry {
    if (_activeCountryCode == null) return const <_RegionItem>[];
    return _regions.where((item) => item.countryCode == _activeCountryCode).toList();
  }

  List<_MetroItem> get _metrosForActiveRegion {
    if (_activeCountryCode == null || _activeRegionKey == null) return const <_MetroItem>[];
    final region = _regions.firstWhere(
      (item) => item.key == _activeRegionKey,
      orElse: () => const _RegionItem(
        countryCode: '',
        countryLabel: '',
        regionType: 'region',
        regionCode: '',
        regionLabel: '',
      ),
    );
    if (region.key.isEmpty) return const <_MetroItem>[];
    return _metros
        .where((item) => item.countryCode == region.countryCode && item.regionCode == region.regionCode)
        .toList();
  }

  String get _scopeSummary {
    final countries = _countries.length;
    final regions = _regions.length;
    final cities = _metros.length;
    final industries = _industries.length;
    final parts = <String>[];
    if (countries > 0) {
      parts.add(countries == 1 ? '1 market selected' : '$countries markets selected');
    }
    if (regions > 0) {
      parts.add(regions == 1 ? '1 area narrowed' : '$regions areas narrowed');
    }
    if (cities > 0) {
      parts.add(cities == 1 ? '1 city focus' : '$cities city focuses');
    }
    if (industries > 0) {
      parts.add(industries == 1 ? '1 business type' : '$industries business types');
    }
    if (parts.isEmpty) return 'Add a market and business type to get this campaign ready.';
    return parts.join(' • ');
  }

  String get _coverageMessage {
    switch (_subscriptionTier) {
      case 'focused':
        return 'Built for one country with room to narrow by area.';
      case 'multi':
        return 'Built for broader coverage across multiple countries.';
      case 'precision':
        return 'Built for deep targeting down to the city level.';
      default:
        return 'Your saved targeting will stay aligned with your current plan.';
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
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

      _notesController.text = _string(profile['notes']);

      _activeCountryCode = _countries.any((item) => item.code == _activeCountryCode)
          ? _activeCountryCode
          : (_countries.isNotEmpty ? _countries.first.code : null);

      final availableRegions = _regionsForActiveCountry;
      _activeRegionKey = availableRegions.any((item) => item.key == _activeRegionKey)
          ? _activeRegionKey
          : (availableRegions.isNotEmpty ? availableRegions.first.key : null);

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'This campaign area could not be loaded right now.';
      });
    }
  }


  Map<String, dynamic> _buildProfilePayload() {
    return <String, dynamic>{
      'countries': _countries.map((item) => <String, String>{'code': item.code, 'label': item.label}).toList(),
      'regions': _regions
          .map(
            (item) => <String, String>{
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
            (item) => <String, String>{
              'countryCode': item.countryCode,
              'regionCode': item.regionCode,
              'label': item.label,
            },
          )
          .toList(),
      'industries': _industries.map((item) => <String, String>{'code': item.code, 'label': item.label}).toList(),
      'notes': _notesController.text.trim(),
    };
  }

  Future<void> _save() async {
    if (_countries.isEmpty) {
      _showNotice('Add at least one market before saving.');
      return;
    }
    if (_industries.isEmpty) {
      _showNotice('Add at least one business type before saving.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _campaignRepository.updateCampaignProfile(
        profile: _buildProfilePayload(),
      );

      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Targeting saved')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Targeting could not be saved right now.';
      });
    }
  }

  Future<void> _showPlanDialog(_PlanIssue issue) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(issue.title),
        content: Text(issue.message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Adjust targeting'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/client/billing');
            },
            child: const Text('View plans'),
          ),
        ],
      ),
    );
  }

  void _showNotice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _startCampaign() async {
    if (_countries.isEmpty) {
      _showNotice('Add at least one market before starting.');
      return;
    }
    if (_industries.isEmpty) {
      _showNotice('Add at least one business type before starting.');
      return;
    }

    setState(() {
      _starting = true;
      _error = null;
      _activationMessage = null;
    });

    try {
      await _campaignRepository.updateCampaignProfile(profile: _buildProfilePayload());
      final result = await _campaignRepository.startCampaign();
      if (!mounted) return;

      final status = _string(result['status']);
      final message = _string(result['message']);

      if (status == 'upgrade_required') {
        setState(() {
          _starting = false;
        });
        await _showPlanDialog(
          _PlanIssue(
            title: 'Expand your plan',
            message: message.isEmpty
                ? 'Your current plan does not cover this targeting.'
                : message,
          ),
        );
        return;
      }

      setState(() {
        _starting = false;
        _campaignActive = status == 'active';
        _activationMessage = message.isEmpty
            ? 'Your campaign has started. We are finding businesses and preparing outreach now.'
            : message;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_activationMessage!)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = 'Your campaign could not be started right now.';
      });
    }
  }

  void _addCountry() {
    final label = _countryController.text.trim();
    if (label.isEmpty) return;
    final item = _NamedItem(code: _slug(label).toUpperCase(), label: _titleCase(label));
    final exists = _countries.any((entry) => entry.label.toLowerCase() == item.label.toLowerCase());
    if (exists) {
      _showNotice('That market is already listed.');
      return;
    }
    setState(() {
      _countries.add(item);
      _activeCountryCode = item.code;
      _activeRegionKey = null;
      _countryController.clear();
    });
  }

  void _addRegion() {
    if (_activeCountryCode == null) {
      _showNotice('Choose a market first.');
      return;
    }
    final label = _regionController.text.trim();
    if (label.isEmpty) return;
    final country = _countries.firstWhere(
      (item) => item.code == _activeCountryCode,
      orElse: () => const _NamedItem(code: '', label: ''),
    );
    if (country.code.isEmpty) return;
    final region = _RegionItem(
      countryCode: country.code,
      countryLabel: country.label,
      regionType: 'region',
      regionCode: _slug(label).toUpperCase(),
      regionLabel: _titleCase(label),
    );
    final exists = _regions.any((entry) => entry.key == region.key);
    if (exists) {
      _showNotice('That area is already listed for this market.');
      return;
    }
    setState(() {
      _regions.add(region);
      _activeRegionKey = region.key;
      _regionController.clear();
    });
  }

  void _addCity() {
    if (_activeCountryCode == null || _activeRegionKey == null) {
      _showNotice('Choose a market and area first.');
      return;
    }
    final label = _cityController.text.trim();
    if (label.isEmpty) return;
    final region = _regions.firstWhere(
      (item) => item.key == _activeRegionKey,
      orElse: () => const _RegionItem(
        countryCode: '',
        countryLabel: '',
        regionType: 'region',
        regionCode: '',
        regionLabel: '',
      ),
    );
    if (region.key.isEmpty) return;
    final city = _MetroItem(
      countryCode: region.countryCode,
      regionCode: region.regionCode,
      label: _titleCase(label),
    );
    final exists = _metros.any(
      (entry) =>
          entry.countryCode == city.countryCode &&
          entry.regionCode == city.regionCode &&
          entry.label.toLowerCase() == city.label.toLowerCase(),
    );
    if (exists) {
      _showNotice('That city is already listed for this area.');
      return;
    }
    setState(() {
      _metros.add(city);
      _cityController.clear();
    });
  }

  void _addIndustry() {
    final label = _industryController.text.trim();
    if (label.isEmpty) return;
    final item = _NamedItem(code: _slug(label), label: _titleCase(label));
    final exists = _industries.any((entry) => entry.label.toLowerCase() == item.label.toLowerCase());
    if (exists) {
      _showNotice('That business type is already listed.');
      return;
    }
    setState(() {
      _industries.add(item);
      _industryController.clear();
    });
  }

  void _removeCountry(_NamedItem item) {
    setState(() {
      _countries.removeWhere((entry) => entry.code == item.code);
      _regions.removeWhere((entry) => entry.countryCode == item.code);
      _metros.removeWhere((entry) => entry.countryCode == item.code);
      if (_activeCountryCode == item.code) {
        _activeCountryCode = _countries.isNotEmpty ? _countries.first.code : null;
        final nextRegions = _regionsForActiveCountry;
        _activeRegionKey = nextRegions.isNotEmpty ? nextRegions.first.key : null;
      }
    });
  }

  void _removeRegion(_RegionItem item) {
    setState(() {
      _regions.removeWhere((entry) => entry.key == item.key);
      _metros.removeWhere((entry) => entry.countryCode == item.countryCode && entry.regionCode == item.regionCode);
      final nextRegions = _regionsForActiveCountry;
      if (_activeRegionKey == item.key) {
        _activeRegionKey = nextRegions.isNotEmpty ? nextRegions.first.key : null;
      }
    });
  }

  void _removeCity(_MetroItem item) {
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
    setState(() {
      _industries.removeWhere((entry) => entry.code == item.code);
    });
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

    final theme = Theme.of(context);
    _NamedItem? activeCountry;
    for (final item in _countries) {
      if (item.code == _activeCountryCode) {
        activeCountry = item;
        break;
      }
    }
    _RegionItem? activeRegion;
    for (final item in _regions) {
      if (item.key == _activeRegionKey) {
        activeRegion = item;
        break;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _HeroCard(
                planLabel: _subscriptionPlanLabel,
                summary: _scopeSummary,
                coverageMessage: _coverageMessage,
                laneLabel: _humanize(_campaignLane),
              ),
              const SizedBox(height: 20),
              _SectionCard(
                title: 'Where should we look?',
                subtitle: 'Add markets in plain language. We will keep the saved targeting aligned with your plan.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _AddBar(
                      controller: _countryController,
                      hintText: 'Type a country and press add',
                      buttonLabel: 'Add market',
                      onSubmitted: (_) => _addCountry(),
                      onPressed: _addCountry,
                    ),
                    const SizedBox(height: 12),
                    _SelectableChipWrap<_NamedItem>(
                      items: _countries,
                      labelBuilder: (item) => item.label,
                      selected: (item) => item.code == _activeCountryCode,
                      onSelected: (item) {
                        setState(() {
                          _activeCountryCode = item.code;
                          final nextRegions = _regionsForActiveCountry;
                          _activeRegionKey = nextRegions.isNotEmpty ? nextRegions.first.key : null;
                        });
                      },
                      onDeleted: _removeCountry,
                      emptyLabel: 'No markets added yet.',
                    ),
                    if (activeCountry != null) ...<Widget>[
                      const SizedBox(height: 20),
                      Text(
                        'Narrow ${activeCountry.label}',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      _AddBar(
                        controller: _regionController,
                        hintText: 'Add a state, province, region, or county',
                        buttonLabel: 'Add area',
                        onSubmitted: (_) => _addRegion(),
                        onPressed: _addRegion,
                      ),
                      const SizedBox(height: 12),
                      _SelectableChipWrap<_RegionItem>(
                        items: _regionsForActiveCountry,
                        labelBuilder: (item) => item.regionLabel,
                        selected: (item) => item.key == _activeRegionKey,
                        onSelected: (item) => setState(() => _activeRegionKey = item.key),
                        onDeleted: _removeRegion,
                        emptyLabel: 'No areas added yet for this market.',
                      ),
                    ],
                    if (activeRegion != null) ...<Widget>[
                      const SizedBox(height: 20),
                      Text(
                        'City focus in ${activeRegion.regionLabel}',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      _AddBar(
                        controller: _cityController,
                        hintText: 'Add a city or metro area',
                        buttonLabel: 'Add city',
                        onSubmitted: (_) => _addCity(),
                        onPressed: _addCity,
                      ),
                      const SizedBox(height: 12),
                      _ChipList<_MetroItem>(
                        items: _metrosForActiveRegion,
                        labelBuilder: (item) => item.label,
                        onDeleted: _removeCity,
                        emptyLabel: 'No city focus added yet.',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SectionCard(
                title: 'What kind of businesses should we reach?',
                subtitle: 'Use everyday language. You can add one or several business types.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _AddBar(
                      controller: _industryController,
                      hintText: 'Examples: roofing companies, dental clinics, trucking companies',
                      buttonLabel: 'Add business type',
                      onSubmitted: (_) => _addIndustry(),
                      onPressed: _addIndustry,
                    ),
                    const SizedBox(height: 12),
                    _ChipList<_NamedItem>(
                      items: _industries,
                      labelBuilder: (item) => item.label,
                      onDeleted: _removeIndustry,
                      emptyLabel: 'No business types added yet.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SectionCard(
                title: 'Anything else we should keep in mind?',
                subtitle: 'Optional guidance helps us keep the campaign closer to your intent.',
                child: TextField(
                  controller: _notesController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Examples: focus on locally owned businesses, avoid franchises, prioritize companies with a clear booking need.',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _campaignActive ? 'Campaign is running' : 'Start your campaign',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _campaignActive
                          ? 'We are actively finding businesses and preparing outreach from your saved targeting.'
                          : 'We will begin finding businesses and preparing outreach based on your targeting.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    if (_error != null) ...<Widget>[
                      Text(
                        _error!,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_activationMessage != null) ...<Widget>[
                      Text(
                        _activationMessage!,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: (_starting || _saving)
                            ? null
                            : (_campaignActive ? () => context.go('/client/leads') : _startCampaign),
                        icon: (_starting || _saving)
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(_campaignActive ? Icons.people_outline : Icons.rocket_launch_outlined),
                        label: Text(
                          _starting
                              ? 'Starting your campaign...'
                              : _saving
                                  ? 'Saving...'
                                  : (_campaignActive ? 'View leads' : 'Start finding customers'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed: (_saving || _starting) ? null : _save,
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(_saving ? 'Saving...' : 'Save for later'),
                        ),
                        TextButton.icon(
                          onPressed: () => context.go('/client/workspace'),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back to workspace'),
                        ),
                      ],
                    ),
                    if (_campaignActive) ...<Widget>[
                      const SizedBox(height: 16),
                      Text(
                        'Finding businesses
Identifying decision-makers
Preparing outreach',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.planLabel,
    required this.summary,
    required this.coverageMessage,
    required this.laneLabel,
  });

  final String planLabel;
  final String summary;
  final String coverageMessage;
  final String laneLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                'Find customers',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  planLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  laneLabel,
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Tell us where to look and who you want to reach. The system will use this saved profile when your campaign runs.',
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text(
            summary,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            coverageMessage,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _AddBar extends StatelessWidget {
  const _AddBar({
    required this.controller,
    required this.hintText,
    required this.buttonLabel,
    required this.onSubmitted,
    required this.onPressed,
  });

  final TextEditingController controller;
  final String hintText;
  final String buttonLabel;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hintText,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: onSubmitted,
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: onPressed,
          child: Text(buttonLabel),
        ),
      ],
    );
  }
}

class _SelectableChipWrap<T> extends StatelessWidget {
  const _SelectableChipWrap({
    required this.items,
    required this.labelBuilder,
    required this.selected,
    required this.onSelected,
    required this.onDeleted,
    required this.emptyLabel,
  });

  final List<T> items;
  final String Function(T item) labelBuilder;
  final bool Function(T item) selected;
  final ValueChanged<T> onSelected;
  final ValueChanged<T> onDeleted;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (items.isEmpty) {
      return Text(
        emptyLabel,
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items
          .map(
            (item) => InputChip(
              label: Text(labelBuilder(item)),
              selected: selected(item),
              onSelected: (_) => onSelected(item),
              onDeleted: () => onDeleted(item),
            ),
          )
          .toList(),
    );
  }
}

class _ChipList<T> extends StatelessWidget {
  const _ChipList({
    required this.items,
    required this.labelBuilder,
    required this.onDeleted,
    required this.emptyLabel,
  });

  final List<T> items;
  final String Function(T item) labelBuilder;
  final ValueChanged<T> onDeleted;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (items.isEmpty) {
      return Text(
        emptyLabel,
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items
          .map(
            (item) => InputChip(
              label: Text(labelBuilder(item)),
              onDeleted: () => onDeleted(item),
            ),
          )
          .toList(),
    );
  }
}

class _PlanIssue {
  const _PlanIssue({required this.title, required this.message});

  final String title;
  final String message;
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
  const _MetroItem({
    required this.countryCode,
    required this.regionCode,
    required this.label,
  });

  final String countryCode;
  final String regionCode;
  final String label;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, dynamic entry) => MapEntry(key.toString(), entry));
  }
  return <String, dynamic>{};
}

String _string(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String _titleCase(String value) {
  final words = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
      .toList();
  return words.join(' ');
}

String _slug(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

String _humanize(String value) {
  if (value.trim().isEmpty) return '';
  return value
      .trim()
      .split(RegExp(r'[_\s-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
      .join(' ');
}

String _resolveSubscriptionLabel(Map<String, dynamic>? subscription) {
  if (subscription == null) return 'Current plan';

  final explicit = _string(subscription['displayPlanLabel']);
  if (explicit.isNotEmpty) return explicit;

  final plan = _string(subscription['plan']);
  final service = _string(subscription['service']);
  final lane = _string(subscription['lane']);
  final tier = _string(subscription['tier']);

  final parts = <String>[plan, service, lane, tier].where((entry) => entry.isNotEmpty).map(_humanize).toSet().toList();
  if (parts.isEmpty) return 'Current plan';
  return parts.join(' • ');
}

String _resolveSubscriptionTier(Map<String, dynamic>? subscription) {
  if (subscription == null) return '';
  return _string(subscription['tier']).toLowerCase();
}

List<_NamedItem> _readNamedItems(dynamic value) {
  if (value is! List) return const <_NamedItem>[];
  return value.map((entry) {
    final map = _asMap(entry);
    final code = _string(map['code']);
    final label = _string(map['label']);
    return _NamedItem(code: code, label: label);
  }).where((item) => item.code.isNotEmpty && item.label.isNotEmpty).toList();
}

List<_RegionItem> _readRegions(dynamic value) {
  if (value is! List) return const <_RegionItem>[];
  return value.map((entry) {
    final map = _asMap(entry);
    return _RegionItem(
      countryCode: _string(map['countryCode']).toUpperCase(),
      countryLabel: _string(map['countryLabel']),
      regionType: _string(map['regionType'], fallback: 'region'),
      regionCode: _string(map['regionCode']).toUpperCase(),
      regionLabel: _string(map['regionLabel']),
    );
  }).where((item) => item.countryCode.isNotEmpty && item.regionCode.isNotEmpty && item.regionLabel.isNotEmpty).toList();
}

List<_MetroItem> _readMetros(dynamic value) {
  if (value is! List) return const <_MetroItem>[];
  return value.map((entry) {
    final map = _asMap(entry);
    return _MetroItem(
      countryCode: _string(map['countryCode']).toUpperCase(),
      regionCode: _string(map['regionCode']).toUpperCase(),
      label: _string(map['label']),
    );
  }).where((item) => item.countryCode.isNotEmpty && item.regionCode.isNotEmpty && item.label.isNotEmpty).toList();
}
