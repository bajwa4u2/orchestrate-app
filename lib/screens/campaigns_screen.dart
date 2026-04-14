import 'package:flutter/material.dart';

import '../data/repositories/client/client_campaign_repository.dart';

class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({super.key});

  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> {
  final repo = ClientCampaignRepository();

  Map<String, dynamic>? profile;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final data = await repo.fetchCampaignProfile();
    setState(() {
      profile = data['campaignProfile'];
      loading = false;
    });
  }

  Future<void> save() async {
    if (profile == null) return;

    await repo.updateCampaignProfile(profile: profile!);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Campaign settings updated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final countries = profile?['countries'] ?? [];
    final industries = profile?['industries'] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Campaign settings',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),

          const SizedBox(height: 16),

          Text('Countries: ${countries.length}'),
          Text('Industries: ${industries.length}'),

          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: save,
            child: const Text('Save changes'),
          ),
        ],
      ),
    );
  }
}