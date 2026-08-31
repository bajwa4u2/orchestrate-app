import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shared public-web acquisition contract. Product configuration supplies
/// verified distribution destinations; the canonical HTTPS URL remains the
/// web/share/search/native destination identity.
class PublicAppAcquisitionConfig {
  const PublicAppAcquisitionConfig({
    required this.productName,
    required this.canonicalHost,
    required this.eligiblePaths,
    this.androidOpenSupported = false,
    this.androidStoreUrl,
    this.iosOpenSupported = false,
    this.iosStoreUrl,
    this.windowsOpenSupported = false,
    this.windowsStoreUrl,
  });

  final String productName;
  final String canonicalHost;
  final Set<String> eligiblePaths;
  final bool androidOpenSupported;
  final Uri? androidStoreUrl;
  final bool iosOpenSupported;
  final Uri? iosStoreUrl;
  final bool windowsOpenSupported;
  final Uri? windowsStoreUrl;
}

/// A non-blocking public continuation rail. It never performs installed-app
/// detection or redirects the page to a store; native association owns open
/// behavior and a verified store URL owns acquisition behavior.
class PublicAppAcquisition extends StatefulWidget {
  const PublicAppAcquisition({
    super.key,
    required this.config,
    required this.currentPath,
  });

  final PublicAppAcquisitionConfig config;
  final String currentPath;

  static const _dismissedKey = 'public_app_acquisition.dismissed.v1';

  @override
  State<PublicAppAcquisition> createState() => _PublicAppAcquisitionState();
}

class _PublicAppAcquisitionState extends State<PublicAppAcquisition> {
  bool _loaded = false;
  bool _dismissed = false;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _loadDismissal();
  }

  Future<void> _loadDismissal() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _dismissed = preferences.getBool(PublicAppAcquisition._dismissedKey) ?? false;
      _loaded = true;
    });
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(PublicAppAcquisition._dismissedKey, true);
  }

  Future<void> _open(Uri destination) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await launchUrl(destination, mode: LaunchMode.externalApplication);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !_loaded || _dismissed) return const SizedBox.shrink();
    if (!widget.config.eligiblePaths.contains(widget.currentPath)) {
      return const SizedBox.shrink();
    }

    final platform = defaultTargetPlatform;
    final canOpen = switch (platform) {
      TargetPlatform.android => widget.config.androidOpenSupported,
      TargetPlatform.iOS => widget.config.iosOpenSupported,
      TargetPlatform.windows => widget.config.windowsOpenSupported,
      _ => false,
    };
    final storeUrl = switch (platform) {
      TargetPlatform.android => widget.config.androidStoreUrl,
      TargetPlatform.iOS => widget.config.iosStoreUrl,
      TargetPlatform.windows => widget.config.windowsStoreUrl,
      _ => null,
    };
    if (!canOpen && storeUrl == null) return const SizedBox.shrink();

    final destination = canOpen
        ? Uri(scheme: 'https', host: widget.config.canonicalHost, path: widget.currentPath)
        : storeUrl!;
    final actionLabel = canOpen
        ? 'Open in ${widget.config.productName}'
        : 'Get ${widget.config.productName}';

    return Semantics(
      container: true,
      label: '${widget.config.productName} app options',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Material(
            color: const Color(0xFFE7F0EC),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 9, 8, 9),
              child: Row(
                children: [
                  const Icon(Icons.open_in_new_rounded, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'This page can continue in the app.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: _opening ? null : () => _open(destination),
                    child: Text(actionLabel),
                  ),
                  IconButton(
                    tooltip: 'Dismiss',
                    onPressed: _dismiss,
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final orchestratePublicAppAcquisitionConfig = PublicAppAcquisitionConfig(
  productName: 'Orchestrate',
  canonicalHost: 'orchestrateops.com',
  eligiblePaths: {
    '/',
    '/product',
    '/how-it-works',
    '/ai-governed-revenue',
    '/lead-sourcing',
    '/trust-compliance',
    '/pricing',
    '/about',
    '/contact',
    '/terms',
    '/privacy',
    '/legal/terms',
    '/legal/privacy',
    '/why-orchestrate',
    '/how-orchestrate-operates',
    '/trust-architecture',
    '/for-evaluators',
    '/security-evaluation',
    '/faq',
  },
  androidStoreUrl: Uri.parse(
      'https://play.google.com/store/apps/details?id=com.orchestrateops.app'),
  iosStoreUrl: Uri.parse(
      'https://apps.apple.com/us/app/orchestrate-operations/id6772025079'),
  windowsStoreUrl: Uri.parse('https://apps.microsoft.com/detail/9P811J2LTNVG'),
);
