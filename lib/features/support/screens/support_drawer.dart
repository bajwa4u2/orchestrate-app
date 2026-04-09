import 'package:flutter/material.dart';

import '../services/support_service.dart';
import '../state/support_controller.dart';
import '../widgets/intake_card.dart';
import '../widgets/response_stream.dart';
import '../widgets/support_footer.dart';

class SupportDrawer extends StatefulWidget {
  final bool publicMode;
  final String baseUrl;
  final String? sourcePage;
  final String? inquiryTypeHint;
  final SupportController? controllerOverride;
  final Future<Map<String, String>> Function()? authHeadersBuilder;

  const SupportDrawer({
    super.key,
    required this.publicMode,
    required this.baseUrl,
    this.sourcePage,
    this.inquiryTypeHint,
    this.controllerOverride,
    this.authHeadersBuilder,
  });

  @override
  State<SupportDrawer> createState() => _SupportDrawerState();
}

class _SupportDrawerState extends State<SupportDrawer> {
  SupportController? _ownedController;
  String _draft = '';

  SupportController get _controller => widget.controllerOverride ?? _ownedController!;
  bool get _ownsController => widget.controllerOverride == null;

  @override
  void initState() {
    super.initState();
    _ensureController();
    _controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant SupportDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldController = oldWidget.controllerOverride ?? _ownedController;

    if (oldWidget.controllerOverride != widget.controllerOverride) {
      oldController?.removeListener(_refresh);
      if (_ownsController && _ownedController == null) {
        _ensureController();
      }
      _controller.addListener(_refresh);
      return;
    }

    if (_ownsController &&
        oldWidget.baseUrl != widget.baseUrl) {
      _controller.removeListener(_refresh);
      _ownedController?.dispose();
      _ownedController = null;
      _ensureController();
      _controller.addListener(_refresh);
    }
  }

  void _ensureController() {
    if (_ownsController && _ownedController == null) {
      _ownedController = SupportController(
        publicMode: widget.publicMode,
        sourcePage: widget.sourcePage,
        inquiryTypeHint: widget.inquiryTypeHint,
        service: SupportService(
          baseUrl: widget.baseUrl,
          authHeadersBuilder: widget.authHeadersBuilder,
        ),
      );
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.of(context).size.width;
    final drawerWidth = availableWidth < 560 ? availableWidth : 460.0;

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          child: SizedBox(
            width: drawerWidth,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Help & Support',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.publicMode
                        ? 'Describe what you need and we’ll guide you forward.'
                        : 'Continue from the same support thread without leaving your workspace.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  IntakeCard(
                    publicMode: widget.publicMode,
                    isLoading: _controller.session.isLoading,
                    initialValue: _draft,
                    onChanged: (value) => setState(() => _draft = value),
                    onSubmit: (message, name, email) async {
                      setState(() => _draft = '');
                      await _controller.sendMessage(
                        message: message,
                        name: name,
                        email: email,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: ResponseStream(
                        messages: _controller.session.messages,
                        isLoading: _controller.session.isLoading,
                        onFollowUpTap: (value) async {
                          await _controller.sendMessage(message: value);
                        },
                      ),
                    ),
                  ),
                  SupportFooter(showStripe: false),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
