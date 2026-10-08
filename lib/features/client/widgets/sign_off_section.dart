import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/ob.dart';
import 'package:orchestrate_app/core/ui/ob_widgets.dart';
import 'package:orchestrate_app/data/repositories/client/client_portal_repository.dart';

/// HOW YOU SIGN OFF (DD-34).
///
/// The signature was edited only on the retired Mailbox page, in words about
/// "governed outbound" and "dispatch infrastructure". It belongs beside the
/// address notes are sent from. The same record and the same endpoint; the
/// fields this section does not show are kept exactly as they were, because
/// the save replaces the whole signature.
class SignOffSection extends StatefulWidget {
  const SignOffSection({super.key, this.repository});

  final ClientPortalRepository? repository;

  @override
  State<SignOffSection> createState() => _SignOffSectionState();
}

class _SignOffSectionState extends State<SignOffSection> {
  late final _repo = widget.repository ?? ClientPortalRepository();
  final _role = TextEditingController();
  final _phone = TextEditingController();
  final _booking = TextEditingController();
  final _logo = TextEditingController();
  Map<String, dynamic> _kept = const {};
  String _preview = '';
  bool _loading = true;
  bool _saving = false;
  String? _note;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _role.dispose();
    _phone.dispose();
    _booking.dispose();
    _logo.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _repo.fetchSignature();
      final sig = (data['signature'] as Map?)?.cast<String, dynamic>() ?? const {};
      _kept = sig;
      _role.text = '${sig['role'] ?? ''}';
      _phone.text = '${sig['phone'] ?? ''}';
      _booking.text = '${sig['schedulingUrl'] ?? ''}';
      _logo.text = '${sig['logoUrl'] ?? ''}';
      _preview = '${data['preview'] ?? ''}'.trim();
    } catch (_) {
      _failed = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _v(String s) => s.trim().isEmpty ? null : s.trim();
  String? _k(String key) => _v('${_kept[key] ?? ''}');

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _note = null;
    });
    try {
      final data = await _repo.updateSignature(
        displayName: _k('displayName'),
        websiteUrl: _k('websiteUrl'),
        complianceFooter: _k('complianceFooter'),
        role: _v(_role.text),
        phone: _v(_phone.text),
        schedulingUrl: _v(_booking.text),
        logoUrl: _v(_logo.text),
      );
      _preview = '${data['preview'] ?? ''}'.trim();
      _note = 'Saved. Every note you approve ends this way.';
    } catch (_) {
      _note = 'Your sign-off could not be saved just now. Try again in a moment.';
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_failed) {
      return Text('Your sign-off could not be loaded just now.',
          style: Ob.body(13.5, color: Ob.inkMuted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('How you sign off', style: Ob.strong(15)),
        const SizedBox(height: 4),
        Text('Under your name and your business, at the end of every note.',
            style: Ob.body(13.5, color: Ob.inkMuted)),
        const SizedBox(height: 10),
        ObField(label: 'Your role (optional)', controller: _role, placeholder: 'Owner'),
        const SizedBox(height: 12),
        ObField(
            label: 'Phone (optional)',
            controller: _phone,
            keyboardType: TextInputType.phone),
        const SizedBox(height: 12),
        ObField(
            label: 'Booking link (optional)',
            controller: _booking,
            keyboardType: TextInputType.url,
            placeholder: 'https://calendly.com/yourname',
            hint: 'Where a buyer can pick a time with you.'),
        const SizedBox(height: 12),
        ObField(
            label: 'Your logo, for answers (optional)',
            controller: _logo,
            keyboardType: TextInputType.url,
            placeholder: 'https://yourbusiness.com/logo.png',
            hint: 'An image link. It sits under your name when you answer someone who wrote to you. First notes stay plain, the way a person writes.'),
        if (_logo.text.trim().startsWith('https://')) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(_logo.text.trim(),
                  width: 40,
                  height: 40,
                  errorBuilder: (_, __, ___) => Text('That link did not open as an image.',
                      style: Ob.body(13, color: Ob.refused))),
            ),
          ),
        ],
        if (_preview.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Ob.cardSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_preview, style: Ob.body(14, color: Ob.ink)),
          ),
        ],
        const SizedBox(height: 10),
        Row(children: [
          OutlinedButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save sign-off'),
          ),
          if (_note != null) ...[
            const SizedBox(width: 12),
            Expanded(child: Text(_note!, style: Ob.body(13.5, color: Ob.inkMuted))),
          ],
        ]),
      ],
    );
  }
}
