import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/client/client_authority_repository.dart';

/// WHAT SUPPORTS THIS CLAIM.
///
/// A person designated themselves, was told "we are reviewing what you sent",
/// and was never told what "what you sent" was — while the operator's own
/// screen read "Supporting reference: none supplied". Both were true, and
/// together they were unanswerable: nobody had asked for anything, so nothing
/// had been supplied, so an operator saw an absence that looked like the
/// business had declined to answer.
///
/// There is always an answer. Today it is the designation itself, confirmed
/// against exact wording, from an account whose address we verified, against a
/// business whose legal name is on record. Those are shown as being RELIED
/// UPON, not requested again — nobody should be asked to upload a document we
/// do not require. When an operator does ask for more, this is where it goes,
/// and answering returns the submission to review.
class AuthorityEvidencePanel extends StatefulWidget {
  const AuthorityEvidencePanel({super.key, this.onChanged});

  /// Called after something is added, so the surrounding surface can re-read
  /// its own state rather than guess at the new one.
  final VoidCallback? onChanged;

  @override
  State<AuthorityEvidencePanel> createState() => _AuthorityEvidencePanelState();
}

class _AuthorityEvidencePanelState extends State<AuthorityEvidencePanel> {
  final _repo = ClientAuthorityRepository();
  final _reference = TextEditingController();

  EvidenceStanding? _standing;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _refusal;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final standing = await _repo.evidence();
      if (!mounted) return;
      setState(() {
        _standing = standing;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Not a blocker: this panel explains a submission, and failing to explain
      // it should not take the surrounding screen down with it.
      setState(() {
        _error = 'We could not read what this claim rests on just now.';
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    final reference = _reference.text.trim();
    if (reference.isEmpty) return;
    setState(() {
      _saving = true;
      _refusal = null;
    });
    final result = await _repo.addSupport(reference);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _refusal = result.ok ? null : result.reason;
    });
    if (result.ok) {
      _reference.clear();
      await _load();
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final standing = _standing;

    if (_loading) {
      return const SizedBox(
        height: 40,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_error != null) {
      return Text(_error!,
          style: text.bodySmall?.copyWith(color: AppTheme.publicMuted));
    }
    if (standing == null || standing.state == SubmissionState.notSubmitted) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.publicLine),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What supports this',
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),

          // What we already rely on. Listed so nobody is asked to supply
          // something we are not asking for.
          for (final item in standing.reliedUpon) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(Icons.check, size: 13, color: AppTheme.publicAccent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.what,
                          style: text.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 1),
                      Text(item.detail,
                          style: text.bodySmall
                              ?.copyWith(color: AppTheme.publicMuted, height: 1.45)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // Partial admission, said as one. The areas admitted and the areas
          // that were not are both facts about the decision.
          if (standing.notAdmitted.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Admitted for ${standing.admitted.join(', ')}. '
              'Not admitted for ${standing.notAdmitted.join(', ')}.',
              style: text.bodySmall?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 10),
          ],

          // The one thing being asked of this person, when there is one.
          if (standing.asking != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.amber.withValues(alpha: 0.45)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('We asked for something more',
                      style:
                          text.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(standing.asking!.what,
                      style: text.bodySmall?.copyWith(height: 1.5)),
                  const SizedBox(height: 6),
                  Text(standing.asking!.why,
                      style: text.bodySmall
                          ?.copyWith(color: AppTheme.publicMuted, height: 1.5)),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (standing.mayAddSupport) ...[
            Text(
              standing.asking?.how ??
                  'If there is something else that supports this — where the '
                      'authorisation lives, who signed it, a record we can check — '
                      'you can add it. It does not have to be a document.',
              style: text.bodySmall
                  ?.copyWith(color: AppTheme.publicMuted, height: 1.5),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _reference,
              minLines: 2,
              maxLines: 4,
              style: text.bodySmall,
              decoration: const InputDecoration(
                hintText: 'Board resolution of 12 March, signed by the two members',
                isDense: true,
              ),
            ),
            if (_refusal != null) ...[
              const SizedBox(height: 8),
              Text(_refusal!,
                  style: text.bodySmall?.copyWith(color: AppTheme.amber)),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: Text(_saving ? 'Adding…' : 'Add this'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
