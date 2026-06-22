import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/client/client_branding_repository.dart';

class ClientBrandingScreen extends StatefulWidget {
  const ClientBrandingScreen({super.key});

  @override
  State<ClientBrandingScreen> createState() => _ClientBrandingScreenState();
}

class _ClientBrandingScreenState extends State<ClientBrandingScreen> {
  final _repo = ClientBrandingRepository();

  Map<String, dynamic>? _branding;
  bool _loading = true;
  String? _error;

  final _primaryColorCtrl = TextEditingController();
  final _accentColorCtrl = TextEditingController();
  bool _savingColors = false;
  String? _colorSaveError;
  String? _colorSaveSuccess;

  bool _uploadingLogo = false;
  bool _removingLogo = false;
  String? _logoError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _primaryColorCtrl.dispose();
    _accentColorCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.fetchBranding();
      if (!mounted) return;
      setState(() {
        _branding = data;
        _loading = false;
        _primaryColorCtrl.text = _str(data['primaryColor']) ?? '';
        _accentColorCtrl.text = _str(data['accentColor']) ?? '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load branding settings. Tap to retry.';
      });
    }
  }

  Future<void> _pickAndUploadLogo(String assetType) async {
    setState(() {
      _uploadingLogo = true;
      _logoError = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _uploadingLogo = false);
        return;
      }
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() {
          _uploadingLogo = false;
          _logoError = 'Could not read file. Try again.';
        });
        return;
      }
      final mimeType = _mimeTypeFor(file.extension?.toLowerCase() ?? '');
      final data = await _repo.uploadLogo(
        fileBytes: bytes,
        filename: file.name,
        mimeType: mimeType,
        assetType: assetType,
      );
      if (!mounted) return;
      final updated = Map<String, dynamic>.from(_branding ?? {});
      final key = _assetTypeToKey(assetType);
      final assetData = data['asset'] as Map?;
      if (assetData != null) updated[key] = Map<String, dynamic>.from(assetData);
      setState(() {
        _branding = updated;
        _uploadingLogo = false;
        _logoError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadingLogo = false;
        _logoError = _errorMessage(e);
      });
    }
  }

  Future<void> _removeLogo(String assetType) async {
    setState(() {
      _removingLogo = true;
      _logoError = null;
    });
    try {
      await _repo.removeLogo(assetType: assetType);
      if (!mounted) return;
      final updated = Map<String, dynamic>.from(_branding ?? {});
      updated[_assetTypeToKey(assetType)] = null;
      setState(() {
        _branding = updated;
        _removingLogo = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _removingLogo = false;
        _logoError = _errorMessage(e);
      });
    }
  }

  Future<void> _saveColors() async {
    final primary = _primaryColorCtrl.text.trim();
    final accent = _accentColorCtrl.text.trim();

    if (primary.isNotEmpty && !_isValidHex(primary)) {
      setState(() => _colorSaveError = 'Primary color must be a valid hex code like #176B5D');
      return;
    }
    if (accent.isNotEmpty && !_isValidHex(accent)) {
      setState(() => _colorSaveError = 'Accent color must be a valid hex code like #0D9488');
      return;
    }

    setState(() {
      _savingColors = true;
      _colorSaveError = null;
      _colorSaveSuccess = null;
    });
    try {
      final data = await _repo.updateBrandingConfig(
        primaryColor: primary.isNotEmpty ? primary : null,
        accentColor: accent.isNotEmpty ? accent : null,
      );
      if (!mounted) return;
      final updated = Map<String, dynamic>.from(_branding ?? {});
      updated['primaryColor'] = data['primaryColor'];
      updated['accentColor'] = data['accentColor'];
      setState(() {
        _branding = updated;
        _savingColors = false;
        _colorSaveSuccess = 'Colors saved.';
        _colorSaveError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _savingColors = false;
        _colorSaveError = _errorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 12, bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loading)
            const Center(child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(strokeWidth: 2),
            ))
          else if (_error != null)
            _ErrorCard(message: _error!, onRetry: _load)
          else ...[
            _LogoSection(
              branding: _branding!,
              uploading: _uploadingLogo,
              removing: _removingLogo,
              error: _logoError,
              onUpload: _pickAndUploadLogo,
              onRemove: _removeLogo,
            ),
            const SizedBox(height: 16),
            _ColorsSection(
              primaryColorCtrl: _primaryColorCtrl,
              accentColorCtrl: _accentColorCtrl,
              saving: _savingColors,
              error: _colorSaveError,
              success: _colorSaveSuccess,
              onSave: _saveColors,
            ),
          ],
        ],
      ),
    );
  }

  bool _isValidHex(String value) => RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value);

  String _mimeTypeFor(String ext) {
    if (ext == 'jpg' || ext == 'jpeg') return 'image/jpeg';
    if (ext == 'webp') return 'image/webp';
    return 'image/png';
  }

  String _assetTypeToKey(String assetType) {
    const map = {
      'logo_primary': 'logo',
      'logo_dark': 'logoDark',
      'logo_light': 'logoLight',
      'symbol': 'symbol',
      'symbol_dark': 'symbolDark',
      'symbol_light': 'symbolLight',
    };
    return map[assetType] ?? assetType;
  }

  String _errorMessage(Object e) {
    final msg = e.toString();
    if (msg.contains('file_too_large')) return 'File exceeds 5 MB limit.';
    if (msg.contains('unsupported_file_type')) return 'Only PNG, JPEG, or WebP files are accepted.';
    if (msg.contains('dimensions_too_small')) return 'Image must be at least 128×128 px.';
    if (msg.contains('dimensions_too_large')) return 'Image must be at most 4096×4096 px.';
    if (msg.contains('unsafe_content')) return 'File content could not be verified. Upload a standard image file.';
    if (msg.contains('invalid_asset_type')) return 'Invalid asset type.';
    return 'Something went wrong. Please try again.';
  }
}

String? _str(dynamic value) {
  if (value == null) return null;
  final s = value.toString().trim();
  return s.isEmpty ? null : s;
}

// ─── Logo section ─────────────────────────────────────────────────────────────

class _LogoSection extends StatelessWidget {
  const _LogoSection({
    required this.branding,
    required this.uploading,
    required this.removing,
    required this.error,
    required this.onUpload,
    required this.onRemove,
  });

  final Map<String, dynamic> branding;
  final bool uploading;
  final bool removing;
  final String? error;
  final void Function(String assetType) onUpload;
  final void Function(String assetType) onRemove;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Logo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload your primary logo. Use PNG or WebP with transparent background for best results. Minimum 128×128 px.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.publicMuted),
          ),
          const SizedBox(height: 20),
          _LogoSlot(
            label: 'Primary logo',
            assetType: 'logo_primary',
            assetData: branding['logo'] as Map?,
            uploading: uploading,
            removing: removing,
            onUpload: onUpload,
            onRemove: onRemove,
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red.shade700)),
          ],
        ],
      ),
    );
  }
}

class _LogoSlot extends StatelessWidget {
  const _LogoSlot({
    required this.label,
    required this.assetType,
    required this.assetData,
    required this.uploading,
    required this.removing,
    required this.onUpload,
    required this.onRemove,
  });

  final String label;
  final String assetType;
  final Map? assetData;
  final bool uploading;
  final bool removing;
  final void Function(String) onUpload;
  final void Function(String) onRemove;

  @override
  Widget build(BuildContext context) {
    final url = _str(assetData?['url']);
    final hasBusy = uploading || removing;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: AppTheme.publicBackground,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppTheme.publicLine),
          ),
          child: url != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radius - 1),
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                    ),
                  ),
                )
              : const Center(child: Icon(Icons.image_outlined, color: Colors.grey, size: 32)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              if (url != null) ...[
                Text(
                  'PNG · ${_str(assetData?['mimeType'])?.replaceFirst('image/', '').toUpperCase() ?? ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.publicMuted),
                ),
                const SizedBox(height: 10),
              ] else ...[
                Text('No logo uploaded', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.publicMuted)),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: hasBusy ? null : () => onUpload(assetType),
                    icon: hasBusy && uploading
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5))
                        : const Icon(Icons.upload_outlined, size: 16),
                    label: Text(url != null ? 'Replace' : 'Upload'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.publicAccent,
                      side: const BorderSide(color: AppTheme.publicAccent),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (url != null) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: hasBusy ? null : () => onRemove(assetType),
                      style: TextButton.styleFrom(foregroundColor: Colors.red.shade600),
                      child: hasBusy && removing
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5))
                          : const Text('Remove', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Colors section ────────────────────────────────────────────────────────────

class _ColorsSection extends StatelessWidget {
  const _ColorsSection({
    required this.primaryColorCtrl,
    required this.accentColorCtrl,
    required this.saving,
    required this.error,
    required this.success,
    required this.onSave,
  });

  final TextEditingController primaryColorCtrl;
  final TextEditingController accentColorCtrl;
  final bool saving;
  final String? error;
  final String? success;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Brand colors',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set the primary and accent hex colors for your brand. These are stored on your identity profile.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.publicMuted),
          ),
          const SizedBox(height: 20),
          _ColorField(
            label: 'Primary color',
            hint: '#176B5D',
            controller: primaryColorCtrl,
          ),
          const SizedBox(height: 12),
          _ColorField(
            label: 'Accent color',
            hint: '#0D9488',
            controller: accentColorCtrl,
          ),
          const SizedBox(height: 20),
          if (error != null) ...[
            Text(error!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red.shade700)),
            const SizedBox(height: 10),
          ],
          if (success != null) ...[
            Text(success!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.green.shade700)),
            const SizedBox(height: 10),
          ],
          ElevatedButton(
            onPressed: saving ? null : onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.publicAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            child: saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save colors'),
          ),
        ],
      ),
    );
  }
}

class _ColorField extends StatelessWidget {
  const _ColorField({required this.label, required this.hint, required this.controller});

  final String label;
  final String hint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        SizedBox(
          width: 260,
          child: TextFormField(
            controller: controller,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[#0-9A-Fa-f]')),
              LengthLimitingTextInputFormatter(7),
            ],
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppTheme.publicMuted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: AppTheme.publicLine),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: AppTheme.publicLine),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              prefixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (_, value, __) {
                  final color = _parseHex(value.text);
                  return Padding(
                    padding: const EdgeInsets.all(10),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: color ?? Colors.white,
                        border: Border.all(color: AppTheme.publicLine),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color? _parseHex(String value) {
    final hex = value.trim();
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) return null;
    return Color(int.parse('FF${hex.substring(1)}', radix: 16));
  }
}

// ─── Shared card ───────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRetry,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.publicLine),
        ),
        child: Text(message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red.shade700)),
      ),
    );
  }
}
