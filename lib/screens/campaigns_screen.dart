import 'package:flutter/material.dart';

import '../data/repositories/client/client_campaign_repository.dart';

class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({super.key});

  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> {
  final ClientCampaignRepository _repository = ClientCampaignRepository();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  String _lane = 'opportunity';
  String _mode = 'focused';

  final List<_NamedItem> _countries = [];
  final List<_NamedItem> _industries = [];
  final List<String> _includeGeo = [];
  final List<String> _excludeGeo = [];
  final List<String> _priorityMarkets = [];

  late final TextEditingController _countryCodeController;
  late final TextEditingController _countryLabelController;
  late final TextEditingController _industryCodeController;
  late final TextEditingController _industryLabelController;
  late final TextEditingController _includeGeoController;
  late final TextEditingController _excludeGeoController;
  late final TextEditingController _priorityMarketController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _countryCodeController = TextEditingController();
    _countryLabelController = TextEditingController();
    _industryCodeController = TextEditingController();
    _industryLabelController = TextEditingController();
    _includeGeoController = TextEditingController();
    _excludeGeoController = TextEditingController();
    _priorityMarketController = TextEditingController();
    _notesController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _countryCodeController.dispose();
    _countryLabelController.dispose();
    _industryCodeController.dispose();
    _industryLabelController.dispose();
    _includeGeoController.dispose();
    _excludeGeoController.dispose();
    _priorityMarketController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final json = await _repository.fetchCampaignProfile();
      final profile = _asMap(json['campaignProfile']);

      _lane = _string(profile['lane'], fallback: 'opportunity');
      _mode = _string(profile['mode'], fallback: 'focused');

      _countries
        ..clear()
        ..addAll(_readNamedItems(profile['countries']));

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
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _repository.updateCampaignProfile(
        profile: {
          'countries': _countries
              .map(
                (item) => {
                  'code': item.code,
                  'label': item.label,
                },
              )
              .toList(),
          'industries': _industries
              .map(
                (item) => {
                  'code': item.code,
                  'label': item.label,
                },
              )
              .toList(),
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

  void _addCountry() {
    final code = _countryCodeController.text.trim().toUpperCase();
    final label = _countryLabelController.text.trim();

    if (code.isEmpty || label.isEmpty) return;
    if (_countries.any((item) => item.code.toUpperCase() == code)) return;

    setState(() {
      _countries.add(_NamedItem(code: code, label: label));
      _countryCodeController.clear();
      _countryLabelController.clear();
    });
  }

  void _removeCountry(_NamedItem item) {
    setState(() {
      _countries.removeWhere((entry) => entry.code == item.code);
    });
  }

  void _addIndustry() {
    final code = _industryCodeController.text.trim().toLowerCase();
    final label = _industryLabelController.text.trim();

    if (code.isEmpty || label.isEmpty) return;
    if (_industries.any((item) => item.code.toLowerCase() == code)) return;

    setState(() {
      _industries.add(_NamedItem(code: code, label: label));
      _industryCodeController.clear();
      _industryLabelController.clear();
    });
  }

  void _removeIndustry(_NamedItem item) {
    setState(() {
      _industries.removeWhere((entry) => entry.code == item.code);
    });
  }

  void _addStringItem(TextEditingController controller, List<String> target) {
    final value = controller.text.trim();
    if (value.isEmpty) return;
    if (target.any((entry) => entry.toLowerCase() == value.toLowerCase())) return;

    setState(() {
      target.add(value);
      controller.clear();
    });
  }

  void _removeStringItem(String value, List<String> target) {
    setState(() {
      target.remove(value);
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
            lane: _humanize(_lane),
            mode: _humanize(_mode),
            countryCount: _countries.length,
            industryCount: _industries.length,
          ),
          const SizedBox(height: 18),
          _Panel(
            title: 'Targeting foundation',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NamedItemSection(
                  title: 'Countries',
                  hint: 'Add each target country with code and label.',
                  codeLabel: 'Country code',
                  nameLabel: 'Country label',
                  codeController: _countryCodeController,
                  nameController: _countryLabelController,
                  items: _countries,
                  emptyText: 'No countries added yet.',
                  onAdd: _addCountry,
                  onRemove: _removeCountry,
                ),
                const SizedBox(height: 24),
                _NamedItemSection(
                  title: 'Industries',
                  hint: 'Define the industries this campaign should target.',
                  codeLabel: 'Industry code',
                  nameLabel: 'Industry label',
                  codeController: _industryCodeController,
                  nameController: _industryLabelController,
                  items: _industries,
                  emptyText: 'No industries added yet.',
                  onAdd: _addIndustry,
                  onRemove: _removeIndustry,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _Panel(
            title: 'Market boundaries',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StringListSection(
                  title: 'Include geography',
                  hint: 'Specific markets that should be included.',
                  controller: _includeGeoController,
                  items: _includeGeo,
                  emptyText: 'No inclusion rules added yet.',
                  onAdd: () => _addStringItem(_includeGeoController, _includeGeo),
                  onRemove: (value) => _removeStringItem(value, _includeGeo),
                ),
                const SizedBox(height: 24),
                _StringListSection(
                  title: 'Exclude geography',
                  hint: 'Markets or areas that should stay outside this campaign.',
                  controller: _excludeGeoController,
                  items: _excludeGeo,
                  emptyText: 'No exclusion rules added yet.',
                  onAdd: () => _addStringItem(_excludeGeoController, _excludeGeo),
                  onRemove: (value) => _removeStringItem(value, _excludeGeo),
                ),
                const SizedBox(height: 24),
                _StringListSection(
                  title: 'Priority markets',
                  hint: 'Markets to prioritize first.',
                  controller: _priorityMarketController,
                  items: _priorityMarkets,
                  emptyText: 'No priority markets added yet.',
                  onAdd: () => _addStringItem(_priorityMarketController, _priorityMarkets),
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
            Text(
              _error!,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving...' : 'Save changes'),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _saving ? null : _load,
                child: const Text('Reload'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.subtitle,
  });

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
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF6B7280),
                ),
          ),
        ],
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.lane,
    required this.mode,
    required this.countryCount,
    required this.industryCount,
  });

  final String lane;
  final String mode;
  final int countryCount;
  final int industryCount;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _MetricTile(label: 'Lane', value: lane),
        _MetricTile(label: 'Mode', value: mode),
        _MetricTile(label: 'Countries', value: '$countryCount'),
        _MetricTile(label: 'Industries', value: '$industryCount'),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
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
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
  });

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
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _NamedItemSection extends StatelessWidget {
  const _NamedItemSection({
    required this.title,
    required this.hint,
    required this.codeLabel,
    required this.nameLabel,
    required this.codeController,
    required this.nameController,
    required this.items,
    required this.emptyText,
    required this.onAdd,
    required this.onRemove,
  });

  final String title;
  final String hint;
  final String codeLabel;
  final String nameLabel;
  final TextEditingController codeController;
  final TextEditingController nameController;
  final List<_NamedItem> items;
  final String emptyText;
  final VoidCallback onAdd;
  final void Function(_NamedItem item) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          hint,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF6B7280),
              ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Text(
            emptyText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B7280),
                ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map(
                  (item) => InputChip(
                    label: Text('${item.label} (${item.code})'),
                    onDeleted: () => onRemove(item),
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 760) {
              return Column(
                children: [
                  TextField(
                    controller: codeController,
                    decoration: InputDecoration(
                      labelText: codeLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: nameLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed: onAdd,
                      child: const Text('Add'),
                    ),
                  ),
                ],
              );
            }

            return Row(
              children: [
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: codeController,
                    decoration: InputDecoration(
                      labelText: codeLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: nameLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: onAdd,
                  child: const Text('Add'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StringListSection extends StatelessWidget {
  const _StringListSection({
    required this.title,
    required this.hint,
    required this.controller,
    required this.items,
    required this.emptyText,
    required this.onAdd,
    required this.onRemove,
  });

  final String title;
  final String hint;
  final TextEditingController controller;
  final List<String> items;
  final String emptyText;
  final VoidCallback onAdd;
  final void Function(String value) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          hint,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF6B7280),
              ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Text(
            emptyText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B7280),
                ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map(
                  (item) => InputChip(
                    label: Text(item),
                    onDeleted: () => onRemove(item),
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 760) {
              return Column(
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Add item',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed: onAdd,
                      child: const Text('Add'),
                    ),
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Add item',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: onAdd,
                  child: const Text('Add'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _NamedItem {
  const _NamedItem({
    required this.code,
    required this.label,
  });

  final String code;
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