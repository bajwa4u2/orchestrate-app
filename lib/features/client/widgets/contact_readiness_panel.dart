import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/core/ui/governed_action.dart';
import 'package:orchestrate_app/data/repositories/client/client_contact_repository.dart';

/// WHETHER WE HAVE A WAY TO REACH THEM.
///
/// Contextual by design. Contact identity supports Market, Relationship and
/// communication — it is not a place a business navigates to, and giving
/// recipient integrity its own destination would turn Orchestrate into a CRM
/// because its addresses needed repair.
///
/// A counterparty with no contact is shown as an honest gap rather than an
/// error: knowing a company is worth pursuing long before knowing how to reach
/// them is the normal order of things.
class ContactReadinessPanel extends StatefulWidget {
  const ContactReadinessPanel({
    super.key,
    required this.counterpartyKey,
    required this.counterpartyName,
    this.onChanged,
    this.repository,
  });

  final String counterpartyKey;
  final String counterpartyName;
  final VoidCallback? onChanged;

  /// So the states can be rendered and read without a server. Every judgement
  /// still comes from the answer — the test supplies one, it does not compose
  /// its own.
  @visibleForTesting
  final ClientContactRepository? repository;

  @override
  State<ContactReadinessPanel> createState() => _ContactReadinessPanelState();
}

class _ContactReadinessPanelState extends State<ContactReadinessPanel> {
  late final ClientContactRepository _repository =
      widget.repository ?? ClientContactRepository();

  ContactReadiness? _readiness;
  Object? _error;
  bool _adding = false;
  Refusal? _refusal;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _readiness = null;
    });
    try {
      final r = await _repository.forCounterparty(widget.counterpartyKey);
      if (mounted) setState(() => _readiness = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    if (_error != null) {
      return _Panel(
        icon: Icons.cloud_off_outlined,
        accent: AppTheme.publicMuted,
        title: 'We could not check the contact',
        body: 'What we know about reaching them is unchanged.',
      );
    }
    final r = _readiness;
    if (r == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: SizedBox(
          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Panel(
          icon: switch (r.state) {
            ContactReadinessState.ready => Icons.alternate_email,
            ContactReadinessState.suppressed => Icons.do_not_disturb_on_outlined,
            ContactReadinessState.belongsToYou => Icons.business_outlined,
            ContactReadinessState.ambiguous => Icons.help_outline,
            _ => Icons.person_search_outlined,
          },
          accent: r.state == ContactReadinessState.ready
              ? AppTheme.publicAccent
              : r.state.terminal
                  ? AppTheme.rose
                  : AppTheme.publicMuted,
          title: r.says,
          // The server's own sentence, verbatim. It explains what the address
          // does and does not establish, which is the whole point.
          body: r.because,
          footnote: r.selected != null
              ? [
                  r.selected!.displayName,
                  if (r.selected!.address != null &&
                      r.selected!.address != r.selected!.displayName)
                    r.selected!.address!,
                ].join(' · ')
              : null,
        ),

        // Several real people, and no way to tell which. Shown rather than
        // guessed between.
        if (r.state == ContactReadinessState.ambiguous) ...[
          const SizedBox(height: 10),
          for (final c in r.alternatives)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${c.displayName} — ${c.provenanceSays}',
                style: text.bodySmall?.copyWith(color: AppTheme.publicMuted),
              ),
            ),
        ],

        if (_refusal != null) RefusalNotice(refusal: _refusal!),

        // The server decides whether a person may record a contact, and this
        // asks it rather than holding a second opinion. An earlier version also
        // required a non-terminal state, which silently refused the replacement
        // path: a suppressed address is one destination refusing, not the
        // counterparty becoming unreachable forever.
        if (r.canProvideContact) ...[
          const SizedBox(height: 12),
          if (_adding)
            _AddContact(
              counterpartyName: widget.counterpartyName,
              busy: false,
              onCancel: () => setState(() => _adding = false),
              onSubmit: _submit,
            )
          else
            OutlinedButton.icon(
              onPressed: () => setState(() => _adding = true),
              icon: const Icon(Icons.add, size: 18),
              label: Text(r.state == ContactReadinessState.noContact
                  ? 'Add a contact you know'
                  : 'Add a different contact'),
            ),
        ],
      ],
    );
  }

  Future<void> _submit(String address, String? name, String? role, String? note) async {
    setState(() => _refusal = null);
    try {
      final result = await _repository.provide(
        counterpartyKey: widget.counterpartyKey,
        address: address,
        personName: name,
        role: role,
        sourceNote: note,
      );
      if (!mounted) return;
      final refusal = Refusal.fromResponse(result);
      if (refusal != null) {
        setState(() => _refusal = refusal);
        return;
      }
      setState(() => _adding = false);
      widget.onChanged?.call();
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _refusal = Refusal.unexpected(e));
    }
  }
}

/// What the business knows, in its own words.
///
/// Deliberately not a CRM record editor. Four fields, and only the address is
/// required — a role mailbox with no name behind it is a legitimate business
/// contact, and asking for a person would invite someone to invent one.
class _AddContact extends StatefulWidget {
  const _AddContact({
    required this.counterpartyName,
    required this.busy,
    required this.onCancel,
    required this.onSubmit,
  });

  final String counterpartyName;
  final bool busy;
  final VoidCallback onCancel;
  final Future<void> Function(String address, String? name, String? role, String? note)
      onSubmit;

  @override
  State<_AddContact> createState() => _AddContactState();
}

class _AddContactState extends State<_AddContact> {
  final _address = TextEditingController();
  final _name = TextEditingController();
  final _role = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _address.dispose();
    _name.dispose();
    _role.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.publicLine),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('A contact you already know at ${widget.counterpartyName}',
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          // Said before they type, not after. This records where an address
          // came from; it cannot make a mailbox exist.
          Text(
            'This records that your business knows this address. It does not '
            'confirm the mailbox works — that is only ever learned by writing '
            'to it, and nothing is sent from here.',
            style: text.bodySmall?.copyWith(color: AppTheme.publicMuted),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _address,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email address'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Their name (optional)',
              helperText: 'Leave blank for a general or role inbox.',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _role,
            decoration: const InputDecoration(labelText: 'Their role (optional)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'How you know this (optional)',
              helperText: 'Recorded with the address, so later this can be checked.',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              GovernedAction(
                label: 'Record this contact',
                // Internal. Nothing leaves the business by recording what it
                // already knows.
                consequence: Consequence.reversibleInternal,
                busy: _busy,
                onPressed: _busy ? null : _submit,
              ),
              const SizedBox(width: 10),
              TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_address.text.trim().isEmpty) return;
    setState(() => _busy = true);
    await widget.onSubmit(
      _address.text, _name.text, _role.text, _note.text,
    );
    if (mounted) setState(() => _busy = false);
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
    this.footnote,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String body;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(body,
                    style: text.bodySmall?.copyWith(color: AppTheme.publicMuted)),
                if (footnote != null) ...[
                  const SizedBox(height: 6),
                  Text(footnote!, style: text.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
