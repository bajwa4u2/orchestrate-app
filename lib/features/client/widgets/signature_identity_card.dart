import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/client/client_portal_repository.dart';

/// Workspace signature identity editor.
///
/// Doctrine
/// --------
/// Orchestrate operates the dispatch infrastructure but the commercial
/// speaker remains the client business. The signature defined here is
/// appended to every governed outbound (and to AI-generated outbound
/// once the catalog renderer is the binding path) so the recipient
/// always reads a message attributable to the client, not to
/// Orchestrate.
///
/// Plaintext-first. No HTML banners, no image attachments, no growth-
/// hack badges. The backend sanitizes every field (CR/LF/NUL stripped,
/// length capped) before persisting.
class SignatureIdentityCard extends StatefulWidget {
  const SignatureIdentityCard({super.key, this.repository});

  /// Optional override for tests / DI.
  final ClientPortalRepository? repository;

  @override
  State<SignatureIdentityCard> createState() => _SignatureIdentityCardState();
}

class _SignatureIdentityCardState extends State<SignatureIdentityCard> {
  late final ClientPortalRepository _repository =
      widget.repository ?? ClientPortalRepository();

  final _displayNameCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  final _businessCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _schedulingCtrl = TextEditingController();
  final _complianceCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _statusMessage;
  String _preview = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _roleCtrl.dispose();
    _businessCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
    _schedulingCtrl.dispose();
    _complianceCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _statusMessage = null;
    });
    try {
      final data = await _repository.fetchSignature();
      final sig = (data['signature'] as Map?)?.cast<String, dynamic>();
      _displayNameCtrl.text = sig?['displayName']?.toString() ?? '';
      _roleCtrl.text = sig?['role']?.toString() ?? '';
      _businessCtrl.text = sig?['businessName']?.toString() ?? '';
      _phoneCtrl.text = sig?['phone']?.toString() ?? '';
      _websiteCtrl.text = sig?['websiteUrl']?.toString() ?? '';
      _schedulingCtrl.text = sig?['schedulingUrl']?.toString() ?? '';
      _complianceCtrl.text = sig?['complianceFooter']?.toString() ?? '';
      _preview = (data['preview'] ?? '').toString();
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _statusMessage = null;
    });
    try {
      final data = await _repository.updateSignature(
        displayName: _trimToNull(_displayNameCtrl.text),
        role: _trimToNull(_roleCtrl.text),
        businessName: _trimToNull(_businessCtrl.text),
        phone: _trimToNull(_phoneCtrl.text),
        websiteUrl: _trimToNull(_websiteCtrl.text),
        schedulingUrl: _trimToNull(_schedulingCtrl.text),
        complianceFooter: _trimToNull(_complianceCtrl.text),
      );
      _preview = (data['preview'] ?? '').toString();
      _statusMessage = 'Signature saved. Every governed outbound will use it.';
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _trimToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Signature identity',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Orchestrate operates the dispatch infrastructure, but the commercial speaker remains your business. This signature is appended to every governed outbound under your sending identity. Plaintext only — no HTML banners, no image attachments.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.publicMuted,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 18),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _formField(
              context,
              controller: _displayNameCtrl,
              label: 'Display name',
              hint: 'e.g. Casey Rivera',
            ),
            const SizedBox(height: 10),
            _formField(
              context,
              controller: _roleCtrl,
              label: 'Role / title',
              hint: 'e.g. Revenue Operations Lead',
            ),
            const SizedBox(height: 10),
            _formField(
              context,
              controller: _businessCtrl,
              label: 'Business name',
              hint: 'e.g. Aura Platform',
            ),
            const SizedBox(height: 10),
            _formField(
              context,
              controller: _phoneCtrl,
              label: 'Phone (optional)',
              hint: 'Any human-readable format',
            ),
            const SizedBox(height: 10),
            _formField(
              context,
              controller: _websiteCtrl,
              label: 'Website (optional)',
              hint: 'https://...',
            ),
            const SizedBox(height: 10),
            _formField(
              context,
              controller: _schedulingCtrl,
              label: 'Scheduling link (optional)',
              hint: 'https://cal.example/...',
            ),
            const SizedBox(height: 10),
            _formField(
              context,
              controller: _complianceCtrl,
              label: 'Compliance footer (optional)',
              hint:
                  'Legal mailing address or required sender disclosure. Plaintext.',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.publicText,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                  child: Text(_saving ? 'Saving…' : 'Save signature'),
                ),
                const SizedBox(width: 12),
                if (_statusMessage != null)
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.publicAccent,
                          ),
                    ),
                  ),
                if (_error != null)
                  Expanded(
                    child: Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                  ),
              ],
            ),
            if (_preview.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                'Wire preview',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.publicMuted,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.publicSurfaceSoft,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: AppTheme.publicLine),
                ),
                child: Text(
                  _preview,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.45,
                    color: AppTheme.publicText,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _formField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }
}
