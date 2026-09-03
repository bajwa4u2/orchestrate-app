import 'package:flutter/material.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/client/client_representative_repository.dart';

/// WHERE A PERSON NAMES THEMSELVES AS AUTHORISED TO ACT FOR THE BUSINESS.
///
/// The backend chain behind this has been complete for some time: a designation
/// is submitted, an operator admits it (narrowing what was asked for, never
/// widening it), and the commercial spine then refuses acts the business has
/// not authorised. None of it was reachable, because this screen did not exist
/// — no route, and nothing calling the endpoint. `AuthorityRequest = 0` in
/// production was a missing screen, not a missing capability.
///
/// Two things this screen must be careful about.
///
///   IT DOES NOT AUTHOR THE DESIGNATION. Every word of what a person is
///   agreeing to comes from the backend artifact, including the per-capability
///   wording. Restating any of it here would create a second copy, and the text
///   someone agrees to is exactly the text that must not drift.
///
///   IT SAYS WHAT IS BEING CLAIMED, NOT WHAT IS BEING GRANTED. The business
///   authorises the person; Orchestrate records that. Language like "grant
///   yourself financial authority" would describe the software doing something
///   it does not do.
class ClientAuthorisedPeopleScreen extends StatefulWidget {
  const ClientAuthorisedPeopleScreen({super.key, this.embedded = false});

  /// True when the account layer supplies the heading, so this does not render
  /// a second one directly beneath it.
  final bool embedded;

  @override
  State<ClientAuthorisedPeopleScreen> createState() =>
      _ClientAuthorisedPeopleScreenState();
}

class _ClientAuthorisedPeopleScreenState
    extends State<ClientAuthorisedPeopleScreen> {
  final _repo = ClientRepresentativeRepository();

  Map<String, dynamic>? _designation;
  Map<String, dynamic>? _readiness;
  Map<String, dynamic>? _identity;
  List<Map<String, dynamic>> _people = const [];
  String? _peopleNote;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final current = await _repo.fetchCurrent();
      final people = await _repo.fetchPeople();
      if (!mounted) return;
      setState(() {
        _designation = Map<String, dynamic>.from(current['designation'] as Map);
        _readiness = Map<String, dynamic>.from(current['readiness'] as Map);
        // Read from the server, not from a value cached at sign-in. Those are
        // different records, which is how a person with a confirmed address
        // was being told to confirm it.
        _identity = current['identity'] is Map
            ? Map<String, dynamic>.from(current['identity'] as Map)
            : null;
        _people = (people['people'] as List? ?? const [])
            .map((p) => Map<String, dynamic>.from(p as Map))
            .toList();
        _peopleNote = people['note'] as String?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!widget.embedded) ...[
          Text(
            'Authorised people',
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Who your business recognises as able to make decisions on its '
            'behalf, and what each of them is recognised for.',
            style: text.bodyMedium?.copyWith(color: AppTheme.publicMuted),
          ),
          const SizedBox(height: 24),
        ],
        if (_loading)
          const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: CircularProgressIndicator(),
          ))
        else if (_error != null)
          _ErrorCard(message: _error!, onRetry: _load)
        else ...[
          if (_identity != null && _identity!['emailConfirmed'] != true)
            _ConfirmEmailBand(
              identity: _identity!,
              repo: _repo,
              onDone: _load,
            ),
          _ReadinessCard(readiness: _readiness!),
          const SizedBox(height: 20),
          if (_people.isEmpty)
            _NobodyYetCard(
              readiness: _readiness!,
              onStart: _openDesignationForm,
              onInvite: _openInviteForm,
            )
          else ...[
            ..._people.map((p) => _PersonCard(
                  person: p,
                  onWithdraw: (area) => _withdraw(p, area),
                )),
            if (_peopleNote != null) ...[
              const SizedBox(height: 12),
              Text(
                _peopleNote!,
                style: text.bodySmall?.copyWith(color: AppTheme.publicMuted),
              ),
            ],
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _openDesignationForm,
                  icon: const Icon(Icons.badge_outlined, size: 18),
                  label: const Text('Name yourself as authorised'),
                ),
                OutlinedButton.icon(
                  onPressed: _openInviteForm,
                  icon: const Icon(Icons.person_add_alt, size: 18),
                  label: const Text('Invite someone'),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _openDesignationForm() async {
    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DesignationDialog(
        designation: _designation!,
        repo: _repo,
      ),
    );
    if (submitted == true) await _load();
  }

  Future<void> _openInviteForm() async {
    final invited = await showDialog<bool>(
      context: context,
      builder: (ctx) => _InviteDialog(designation: _designation!, repo: _repo),
    );
    if (invited == true) await _load();
  }

  Future<void> _withdraw(Map<String, dynamic> person, String areaLabel) async {
    // The label a person reads and the value the API takes are deliberately
    // different: the backend speaks in capabilities, the screen speaks in what
    // those capabilities are for.
    const areaValue = {
      'Communication': 'COMMUNICATION',
      'Agreements': 'CONTRACTUAL',
      'Invoices and payments': 'FINANCIAL',
    };
    final value = areaValue[areaLabel];
    if (value == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Withdraw ${areaLabel.toLowerCase()} authority?'),
        content: Text(
          '${person['name'] ?? 'This person'} will no longer be able to authorise '
          'anything further in this area.\n\n'
          'This does not undo what was already done. Decisions made while the '
          'authority was valid stay valid, and stay on the record.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Withdraw', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final userId = person['userId'] as String?;
      if (userId == null) {
        throw StateError('This person has no id on record, so they cannot be addressed.');
      }
      await _repo.withdraw(userId: userId, area: value);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not withdraw: $e')),
      );
    }
  }
}

/// Where the business stands, in its own three parts.
///
/// Shown before anything else because the most common question here is not
/// "how do I do this" but "do I need to". Deliberately not framed as a failure:
/// a business that has not done this has not done anything wrong.
class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({required this.readiness});

  final Map<String, dynamic> readiness;

  @override
  Widget build(BuildContext context) {
    final rows = <Map<String, dynamic>>[
      {'title': 'Your account', ...?_section('clientAccount')},
      {'title': 'Authorised people', ...?_section('organizationalAuthority')},
      {'title': 'What Orchestrate may do', ...?_section('orchestrateDelegation')},
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.publicMuted.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in rows) ...[
            _ReadinessRow(
              title: r['title'] as String,
              state: r['state'] as String? ?? 'UNKNOWN',
              meaning: r['meaning'] as String? ?? '',
              areas: (r['recognisedAreas'] ?? r['areas']) as List? ?? const [],
              nextStep: r['nextStep'] as String?,
            ),
            if (r != rows.last)
              const Divider(height: 28, color: AppTheme.publicLine, thickness: 1),
          ],
        ],
      ),
    );
  }

  Map<String, dynamic>? _section(String key) {
    final v = readiness[key];
    return v is Map ? Map<String, dynamic>.from(v) : null;
  }
}

class _ReadinessRow extends StatelessWidget {
  const _ReadinessRow({
    required this.title,
    required this.state,
    required this.meaning,
    required this.areas,
    required this.nextStep,
  });

  final String title;
  final String state;
  final String meaning;
  final List<dynamic> areas;
  final String? nextStep;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StateDot(state: state),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(meaning,
                  style:
                      text.bodySmall?.copyWith(color: AppTheme.publicMuted)),
              if (areas.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: areas
                      .map((a) => Chip(
                            label: Text(a.toString()),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ))
                      .toList(),
                ),
              ],
              if (nextStep != null) ...[
                const SizedBox(height: 8),
                Text(nextStep!, style: text.bodySmall),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StateDot extends StatelessWidget {
  const _StateDot({required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    // UNDER_REVIEW is deliberately not a warning colour. Waiting on us is not
    // something the business needs to act on.
    final color = switch (state) {
      'READY' || 'ESTABLISHED' => Colors.green,
      'UNDER_REVIEW' => Colors.blue,
      _ => AppTheme.publicMuted,
    };
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _NobodyYetCard extends StatelessWidget {
  const _NobodyYetCard({
    required this.readiness,
    required this.onStart,
    required this.onInvite,
  });

  final Map<String, dynamic> readiness;
  final VoidCallback onStart;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final org = readiness['organizationalAuthority'];
    final underReview =
        org is Map && org['state'] == 'UNDER_REVIEW';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.publicMuted.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            underReview
                ? 'We are reviewing what you sent'
                : 'Nobody is named yet',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            underReview
                ? 'You do not need to do anything else for now. We will let you '
                    'know if we need something more.'
                : 'Agreements and invoices are consequential enough that '
                    'Orchestrate will not act on them just because someone is '
                    'signed in. Until a person is named, those stay unavailable '
                    '— which is deliberate.',
            style: text.bodyMedium?.copyWith(color: AppTheme.publicMuted),
          ),
          if (!underReview) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton(
                  onPressed: onStart,
                  child: const Text('Name yourself as authorised'),
                ),
                OutlinedButton(
                  onPressed: onInvite,
                  child: const Text('Invite someone'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.person, required this.onWithdraw});

  final Map<String, dynamic> person;
  final void Function(String area) onWithdraw;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final areas = (person['authorizedFor'] as List? ?? const [])
        .map((a) => Map<String, dynamic>.from(a as Map))
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.publicMuted.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(person['name']?.toString() ?? person['email']?.toString() ?? '',
              style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
          if (person['describedAs'] != null)
            Text(person['describedAs'].toString(),
                style: text.bodySmall?.copyWith(color: AppTheme.publicMuted)),
          const SizedBox(height: 14),
          for (final a in areas) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a['area']?.toString() ?? '',
                          style: text.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      // Three independent permissions, listed separately
                      // because holding one has never implied holding another.
                      _Permission(
                          on: a['canApprove'] == true,
                          label: 'Can approve this for the business'),
                      _Permission(
                          on: a['canAllowOrchestrate'] == true,
                          label: 'Can let Orchestrate act in this area'),
                      _Permission(
                          on: a['canRecogniseOthers'] == true,
                          label: 'Can recognise other people here'),
                      if (a['establishedFrom'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Recorded from: ${a['establishedFrom']}',
                            style: text.bodySmall
                                ?.copyWith(color: AppTheme.publicMuted),
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => onWithdraw(a['area']?.toString() ?? ''),
                  child: const Text('Withdraw'),
                ),
              ],
            ),
            if (a != areas.last)
              const Divider(height: 24, color: AppTheme.publicLine, thickness: 1),
          ],
        ],
      ),
    );
  }
}

class _Permission extends StatelessWidget {
  const _Permission({required this.on, required this.label});

  final bool on;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(on ? Icons.check : Icons.remove,
              size: 14,
              color: on ? Colors.green : AppTheme.publicMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: on ? null : AppTheme.publicMuted,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The designation itself.
///
/// Every word here except the field labels comes from the backend artifact.
class _DesignationDialog extends StatefulWidget {
  const _DesignationDialog({required this.designation, required this.repo});

  final Map<String, dynamic> designation;
  final ClientRepresentativeRepository repo;

  @override
  State<_DesignationDialog> createState() => _DesignationDialogState();
}

class _DesignationDialogState extends State<_DesignationDialog> {
  final _role = TextEditingController();
  final _reference = TextEditingController();

  /// capability -> {exercise, delegate, subdelegate}
  final Map<String, Map<String, bool>> _selected = {};
  bool _acknowledged = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _role.dispose();
    _reference.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _copy =>
      Map<String, dynamic>.from(widget.designation['capabilityCopy'] as Map);

  bool get _anythingSelected => _selected.values.any((v) => v.values.any((b) => b));

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final establishes = (widget.designation['establishes'] as List? ?? const []);
    final doesNot = (widget.designation['doesNotEstablish'] as List? ?? const []);

    return AlertDialog(
      title: Text(widget.designation['title']?.toString() ?? 'Authorized representative'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Bullets(title: 'What this establishes', items: establishes),
              const SizedBox(height: 16),
              _Bullets(title: 'What it does not', items: doesNot),
              const SizedBox(height: 20),
              Text('What you are authorised to decide',
                  style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                'Ask only for what is true. Whoever reviews this can reduce it '
                'and cannot increase it, so asking for more costs you time '
                'rather than gaining anything.',
                style: text.bodySmall?.copyWith(color: AppTheme.publicMuted),
              ),
              const SizedBox(height: 12),
              for (final entry in _copy.entries)
                _CapabilityBlock(
                  capability: entry.key,
                  copy: Map<String, dynamic>.from(entry.value as Map),
                  selection: _selected[entry.key] ??= {
                    'exercise': false,
                    'delegate': false,
                    'subdelegate': false,
                  },
                  onChanged: () => setState(() {}),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _role,
                decoration: const InputDecoration(
                  labelText: 'Your role at the business (optional)',
                  helperText:
                      'Recorded as what the business calls you. It carries no '
                      'authority by itself.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reference,
                decoration: const InputDecoration(
                  labelText: 'Supporting document reference (optional)',
                  helperText:
                      'If the business has something on file that shows this, '
                      'say where it is.',
                ),
              ),
              const SizedBox(height: 20),
              CheckboxListTile(
                value: _acknowledged,
                onChanged: (v) => setState(() => _acknowledged = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  widget.designation['representation']?.toString() ?? '',
                  style: text.bodyMedium,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: text.bodySmall?.copyWith(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          // Both conditions are the backend's rules, mirrored here only so the
          // button explains itself before the request rather than after it.
          onPressed: (_submitting || !_acknowledged || !_anythingSelected)
              ? null
              : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Submit'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final requested = _selected.entries
        .where((e) => e.value.values.any((b) => b))
        .map((e) => {
              'capability': e.key,
              'mayExercise': e.value['exercise'] ?? false,
              'mayDelegate': e.value['delegate'] ?? false,
              'maySubdelegate': e.value['subdelegate'] ?? false,
            })
        .toList();

    try {
      final result = await widget.repo.submit(
        requested: requested,
        acknowledgedRepresentation: _acknowledged,
        // Submitted unchanged, so the record says which wording was shown.
        artifactHash: widget.designation['artifactHash']?.toString() ?? '',
        roleTitleText: _role.text,
        supportingReference: _reference.text,
      );
      if (!mounted) return;
      if (result['ok'] == false) {
        // The backend refuses for reasons a person can act on — an unconfirmed
        // email, a missing legal name. Showing its reason is better than
        // inventing a generic one.
        setState(() {
          _submitting = false;
          _error = result['reason']?.toString() ?? 'This could not be submitted.';
        });
        return;
      }
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }
}

class _CapabilityBlock extends StatelessWidget {
  const _CapabilityBlock({
    required this.capability,
    required this.copy,
    required this.selection,
    required this.onChanged,
  });

  final String capability;
  final Map<String, dynamic> copy;
  final Map<String, bool> selection;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.publicMuted.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(copy['label']?.toString() ?? capability,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(copy['meaning']?.toString() ?? '',
              style: text.bodySmall?.copyWith(color: AppTheme.publicMuted)),
          const SizedBox(height: 8),
          // Three separate choices, never one. Being able to approve something
          // yourself and being able to let software do it are different
          // decisions, and the backend treats them as such.
          for (final k in const ['exercise', 'delegate', 'subdelegate'])
            if (copy[k] != null)
              CheckboxListTile(
                value: selection[k] ?? false,
                onChanged: (v) {
                  selection[k] = v ?? false;
                  onChanged();
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
                visualDensity: VisualDensity.compact,
                title: Text(copy[k].toString(), style: text.bodySmall),
              ),
        ],
      ),
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets({required this.title, required this.items});

  final String title;
  final List<dynamic> items;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        for (final i in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: text.bodySmall),
                Expanded(child: Text(i.toString(), style: text.bodySmall)),
              ],
            ),
          ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This could not be loaded.'),
          const SizedBox(height: 6),
          Text(message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.publicMuted)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

/// A confirmed address is a precondition, so this says so where the person is
/// standing — and gives them the way out of it.
///
/// The state comes from the server. The value cached at sign-in and the record
/// the gate actually checks are different things, and disagreeing about them is
/// how someone gets told to confirm an address they already confirmed.
class _ConfirmEmailBand extends StatefulWidget {
  const _ConfirmEmailBand({
    required this.identity,
    required this.repo,
    required this.onDone,
  });

  final Map<String, dynamic> identity;
  final ClientRepresentativeRepository repo;
  final VoidCallback onDone;

  @override
  State<_ConfirmEmailBand> createState() => _ConfirmEmailBandState();
}

class _ConfirmEmailBandState extends State<_ConfirmEmailBand> {
  bool _sending = false;
  String? _result;

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _result = null;
    });
    try {
      final r = await widget.repo.resendVerification();
      if (!mounted) return;
      setState(() {
        _sending = false;
        _result = r['message']?.toString() ?? 'Confirmation sent.';
      });
      if (r['alreadyConfirmed'] == true) widget.onDone();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _result = 'Could not send it: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final email = widget.identity['email']?.toString();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.amber.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Confirm your email first',
              style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            widget.identity['meaning']?.toString() ??
                'Someone stating that they can commit a business needs to be '
                    'reachable at a confirmed address.',
            style: text.bodySmall?.copyWith(color: AppTheme.publicMuted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: _sending ? null : _send,
                child: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(email == null
                        ? 'Send confirmation'
                        : 'Send confirmation to $email'),
              ),
              if (_result != null)
                Text(_result!,
                    style:
                        text.bodySmall?.copyWith(color: AppTheme.publicMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Invite a colleague, and say what the business believes they can decide.
///
/// INVITING IS NOT GRANTING. This proposes a person; they acknowledge the
/// designation themselves and an operator admits it. The wording says so
/// plainly, because a form collecting an email and a list of powers looks
/// exactly like one that hands them over.
class _InviteDialog extends StatefulWidget {
  const _InviteDialog({required this.designation, required this.repo});

  final Map<String, dynamic> designation;
  final ClientRepresentativeRepository repo;

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _role = TextEditingController();
  final Set<String> _areas = {};
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _role.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _copy =>
      Map<String, dynamic>.from(widget.designation['capabilityCopy'] as Map);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('Invite someone to be recognised'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You are telling us who your business believes can decide for '
                'it. They confirm it themselves, and nothing changes until they '
                'do, so this gives them nothing on its own.',
                style: text.bodySmall?.copyWith(color: AppTheme.publicMuted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Their work email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration:
                    const InputDecoration(labelText: 'Their name (optional)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _role,
                decoration: const InputDecoration(
                  labelText: 'Their role at the business (optional)',
                  helperText: 'Recorded as what you call them. It carries no '
                      'authority by itself.',
                ),
              ),
              const SizedBox(height: 18),
              Text('What you believe they can decide',
                  style:
                      text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              for (final entry in _copy.entries)
                CheckboxListTile(
                  value: _areas.contains(entry.key),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _areas.add(entry.key);
                    } else {
                      _areas.remove(entry.key);
                    }
                  }),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    Map<String, dynamic>.from(entry.value as Map)['label']
                            ?.toString() ??
                        entry.key,
                    style: text.bodySmall,
                  ),
                  subtitle: Text(
                    Map<String, dynamic>.from(entry.value as Map)['meaning']
                            ?.toString() ??
                        '',
                    style:
                        text.bodySmall?.copyWith(color: AppTheme.publicMuted),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: text.bodySmall?.copyWith(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (_sending || _email.text.trim().isEmpty || _areas.isEmpty)
              ? null
              : _send,
          child: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Send invitation'),
        ),
      ],
    );
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final r = await widget.repo.invite(
        email: _email.text,
        name: _name.text,
        roleTitleText: _role.text,
        suggested: _areas
            .map((c) => {
                  'capability': c,
                  // What the business believes they can approve. Letting
                  // Orchestrate act stays a separate decision they make later.
                  'mayExercise': true,
                  'mayDelegate': false,
                  'maySubdelegate': false,
                })
            .toList(),
      );
      if (!mounted) return;
      if (r['ok'] == false) {
        setState(() {
          _sending = false;
          _error = r['reason']?.toString() ?? 'This could not be sent.';
        });
        return;
      }
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.toString();
      });
    }
  }
}
