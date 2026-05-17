import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/public_repository.dart';
import 'package:orchestrate_app/features/system/widgets/governance_primitives.dart';

/// Public answers surface.
///
/// Doctrine
/// --------
/// This is NOT a chatbot. There is no AI generating answer text. The
/// backend matches the visitor's question deterministically against a
/// curated knowledge catalog and returns one or more catalog entries
/// verbatim, or — honestly — `unanswered: true` with a /contact
/// escalation when no entry crosses the matcher threshold.
///
/// UX feels operational + procurement-grade, not "AI assistant":
///   - A search input + filter pills, not a chat thread.
///   - Canonical question chips so a visitor can see the closed set
///     of intents the system can answer authoritatively.
///   - Answer cards render the catalog entry verbatim with named
///     "read more" links into the relevant Orchestrate surfaces.
///   - Confidence badges (authoritative / best_effort) so evaluators
///     know what is contractual vs. directional.
class PublicAnswersScreen extends StatefulWidget {
  const PublicAnswersScreen({super.key});

  @override
  State<PublicAnswersScreen> createState() => _PublicAnswersScreenState();
}

class _PublicAnswersScreenState extends State<PublicAnswersScreen> {
  final PublicRepository _repository = PublicRepository();
  final TextEditingController _input = TextEditingController();

  List<Map<String, dynamic>> _catalog = const [];
  bool _loadingCatalog = true;
  String? _catalogError;

  bool _searching = false;
  String? _searchError;
  Map<String, dynamic>? _result;
  String? _activeTopic;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loadingCatalog = true;
      _catalogError = null;
    });
    try {
      final data = await _repository.fetchSupportCatalog();
      _catalog = (data['entries'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList();
    } catch (error) {
      _catalogError = error.toString();
    } finally {
      if (mounted) setState(() => _loadingCatalog = false);
    }
  }

  Future<void> _ask({String? questionOverride}) async {
    final question = (questionOverride ?? _input.text).trim();
    if (question.isEmpty) {
      setState(() => _searchError = 'Enter an operational question.');
      return;
    }
    if (questionOverride != null) _input.text = questionOverride;
    setState(() {
      _searching = true;
      _searchError = null;
      _result = null;
    });
    try {
      _result = await _repository.askSupport(
        question: question,
        topic: _activeTopic,
      );
    } catch (error) {
      _searchError = error.toString();
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Hero(),
              const SizedBox(height: 24),
              _searchBlock(context),
              const SizedBox(height: 18),
              _topicFilterRow(context),
              const SizedBox(height: 18),
              if (_searching)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_searchError != null)
                _errorRow(context, _searchError!)
              else if (_result != null)
                _renderResult(context, _result!),
              const SizedBox(height: 24),
              _canonicalQuestionsBlock(context),
              const SizedBox(height: 24),
              _crossLinksBlock(context),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Blocks
  // ------------------------------------------------------------------

  Widget _searchBlock(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 640;
          final field = TextField(
            controller: _input,
            onSubmitted: (_) => _ask(),
            decoration: InputDecoration(
              labelText: 'Ask an operational question',
              hintText:
                  'e.g. "Does Orchestrate read my inbox?" / "How is AI bounded?"',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          );
          final button = FilledButton(
            onPressed: _searching ? null : () => _ask(),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.publicText,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
            ),
            child: Text(_searching ? 'Searching…' : 'Find answer'),
          );
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [field, const SizedBox(height: 10), button],
            );
          }
          return Row(
            children: [
              Expanded(child: field),
              const SizedBox(width: 12),
              button,
            ],
          );
        },
      ),
    );
  }

  Widget _topicFilterRow(BuildContext context) {
    final topics = (_result?['availableTopics'] as List?)
            ?.map((t) => t.toString())
            .toList() ??
        _topicsFromCatalog();
    if (topics.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _topicChip(context, label: 'All', value: null),
        for (final t in topics)
          _topicChip(context, label: _humanize(t), value: t),
      ],
    );
  }

  List<String> _topicsFromCatalog() {
    final set = <String>{};
    for (final e in _catalog) {
      final t = e['topic']?.toString();
      if (t != null && t.isNotEmpty) set.add(t);
    }
    return set.toList()..sort();
  }

  Widget _topicChip(BuildContext context,
      {required String label, required String? value}) {
    final active = _activeTopic == value;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) {
        setState(() {
          _activeTopic = value;
        });
        if (_input.text.trim().isNotEmpty) _ask();
      },
      backgroundColor: AppTheme.publicSurfaceSoft,
      selectedColor: AppTheme.publicAccentSoft,
      labelStyle: TextStyle(
        color: active ? AppTheme.publicAccent : AppTheme.publicMuted,
        fontWeight: FontWeight.w600,
        fontSize: 12.5,
      ),
      side: BorderSide(
        color: active ? AppTheme.publicAccent : AppTheme.publicLine,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  Widget _renderResult(BuildContext context, Map<String, dynamic> result) {
    final unanswered = result['unanswered'] == true;
    final matched = (result['matched'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => m.cast<String, dynamic>())
        .toList();
    final suggestedTopics = (result['suggestedTopics'] as List? ?? const [])
        .map((t) => t.toString())
        .toList();

    if (unanswered) {
      return _unansweredCard(context, suggestedTopics);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final m in matched) _answerCard(context, m),
      ],
    );
  }

  Widget _answerCard(BuildContext context, Map<String, dynamic> match) {
    final entry = (match['entry'] as Map?)?.cast<String, dynamic>();
    if (entry == null) return const SizedBox.shrink();
    final question = entry['question']?.toString() ?? '';
    final answer = entry['answer']?.toString() ?? '';
    final topic = entry['topic']?.toString() ?? '';
    final confidence = entry['confidence']?.toString() ?? 'best_effort';
    final linkedSurfaces = (entry['linkedSurfaces'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => m.cast<String, dynamic>())
        .toList();
    final paragraphs = answer.split('\n\n');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (topic.isNotEmpty)
                GovernanceBadge(label: 'topic', value: _humanize(topic)),
              GovernanceBadge(
                label: 'confidence',
                value:
                    confidence == 'authoritative' ? 'authoritative' : 'best effort',
                tone: confidence == 'authoritative'
                    ? GovernanceTone.positive
                    : GovernanceTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            question,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          for (final p in paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                p,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.publicText,
                      height: 1.55,
                    ),
              ),
            ),
          if (linkedSurfaces.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final surface in linkedSurfaces)
                  OutlinedButton(
                    onPressed: () =>
                        context.go(surface['path']?.toString() ?? '/'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.publicText,
                      side: BorderSide(color: AppTheme.publicLine),
                    ),
                    child: Text(surface['label']?.toString() ?? ''),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _unansweredCard(BuildContext context, List<String> suggested) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GovernanceBadge(
            label: 'no definitive answer',
            tone: GovernanceTone.cautious,
          ),
          const SizedBox(height: 12),
          Text(
            'I don\'t have a curated, operationally-truthful answer for that question.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Rather than guess, the support system honestly returns "no match" when a question falls outside the curated catalog. If you need an answer, contact us directly — a human will reply.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.publicMuted,
                  height: 1.5,
                ),
          ),
          if (suggested.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'You may be looking for one of these areas:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.publicMuted,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final topic in suggested)
                  _topicChip(context, label: _humanize(topic), value: topic),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: () => context.go('/contact'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.publicText,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Contact support'),
              ),
              OutlinedButton(
                onPressed: () => context.go('/for-evaluators'),
                child: const Text('For evaluators'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _canonicalQuestionsBlock(BuildContext context) {
    if (_loadingCatalog) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_catalogError != null) {
      return _errorRow(context, _catalogError!);
    }
    final visible = _activeTopic == null
        ? _catalog
        : _catalog.where((e) => e['topic']?.toString() == _activeTopic).toList();
    if (visible.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Canonical questions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'The closed set of operational questions this catalog can answer authoritatively. Tap one to see the curated answer.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in visible)
                ActionChip(
                  label: Text(e['question']?.toString() ?? ''),
                  onPressed: () =>
                      _ask(questionOverride: e['question']?.toString()),
                  backgroundColor: AppTheme.publicSurfaceSoft,
                  labelStyle: const TextStyle(
                    color: AppTheme.publicText,
                    fontWeight: FontWeight.w500,
                    fontSize: 12.5,
                  ),
                  side: BorderSide(color: AppTheme.publicLine),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _crossLinksBlock(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Operational reference surfaces',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => context.go('/diagnostics'),
                child: const Text('Run DNS readiness check'),
              ),
              OutlinedButton(
                onPressed: () => context.go('/trust-architecture'),
                child: const Text('Trust architecture'),
              ),
              OutlinedButton(
                onPressed: () => context.go('/how-orchestrate-operates'),
                child: const Text('How Orchestrate operates'),
              ),
              OutlinedButton(
                onPressed: () => context.go('/for-evaluators'),
                child: const Text('For evaluators'),
              ),
              FilledButton(
                onPressed: () => context.go('/activation'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.publicText,
                  foregroundColor: Colors.white,
                ),
                child: const Text('See activation progression'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _errorRow(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  String _humanize(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .map((t) => t.isEmpty
            ? t
            : '${t[0].toUpperCase()}${t.substring(1)}')
        .join(' ');
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.publicAccentSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Operational answers',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.publicAccent,
                  ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Ask Orchestrate an operational question.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'No chatbot. No generated text. Every answer is sourced verbatim from a curated knowledge catalog grounded in the system\'s actual behavior. When a question falls outside the catalog, the system says so honestly and routes you to /contact instead of inventing an answer.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
        ],
      ),
    );
  }
}
