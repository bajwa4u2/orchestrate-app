import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/layout/workspace.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/core/ui/governed_action.dart';
import 'package:orchestrate_app/data/repositories/client/client_relationship_workspace_repository.dart';
import 'package:orchestrate_app/features/client/widgets/engagement_lifecycle.dart';
import 'package:orchestrate_app/features/client/widgets/relationship_timeline.dart';

/// THE WORKSPACE CENTRE.
///
/// Relationship is the durable unit of account, so it is where the work
/// happens — not a list you visit and leave. Opportunities, replies, meetings
/// and outreach are gone as destinations: they were views of, or events
/// inside, this.
///
/// Pipeline survives as a first-class view rather than a second universe.
/// Clients who work a funnel still get a board; what they no longer get is two
/// lists of the same records disagreeing about which is authoritative.
///
/// One hierarchy: list → work → inspector. Panes when there is width, pushes
/// when there is not. Never two conceptual models.
class RelationshipsWorkspaceScreen extends StatefulWidget {
  const RelationshipsWorkspaceScreen({super.key, this.initialView, this.relationshipId});

  final String? initialView;
  final String? relationshipId;

  @override
  State<RelationshipsWorkspaceScreen> createState() =>
      _RelationshipsWorkspaceScreenState();
}

const _views = <String, String>{
  'all': 'All',
  'pipeline': 'Pipeline',
  'engaged': 'Engaged',
  'waiting': 'Waiting',
  'recent': 'Recent',
};

class _RelationshipsWorkspaceScreenState
    extends State<RelationshipsWorkspaceScreen> {
  final _repo = ClientRelationshipWorkspaceRepository();

  late String _view = widget.initialView ?? 'all';
  List<RelationshipSummary> _items = const [];
  String? _selectedId;
  RelationshipWorkspace? _detail;

  bool _loadingList = true;
  bool _loadingDetail = false;
  Refusal? _refusal;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.relationshipId;
    _loadList();
  }

  Future<void> _loadList() async {
    setState(() {
      _loadingList = true;
      _refusal = null;
    });
    try {
      final items = await _repo.list(view: _view);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loadingList = false;
      });
      // On a wide layout the work pane is most of the screen. Leaving it as
      // one centred sentence wastes it, so the first relationship opens and
      // the workspace arrives ready to work.
      final target = _selectedId ??
          (Workspace.sizeOf(context).canShowList && items.isNotEmpty
              ? items.first.id
              : null);
      if (target != null) _loadDetail(target);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _refusal = Refusal.unexpected(e);
        _loadingList = false;
      });
    }
  }

  Future<void> _loadDetail(String id) async {
    setState(() {
      _loadingDetail = true;
      _selectedId = id;
    });
    try {
      final detail = await _repo.detail(id);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loadingDetail = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _refusal = Refusal.unexpected(e);
        _loadingDetail = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = Workspace.sizeOf(context);

    // Narrow: one pane at a time, detail pushed over the list. Wide: side by
    // side. Same hierarchy either way.
    if (!size.canShowList) {
      if (_selectedId != null && _detail != null) {
        return _detailPane(onBack: () => setState(() {
              _selectedId = null;
              _detail = null;
            }));
      }
      return _listPane();
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 340, child: _listPane()),
        const VerticalDivider(width: 25, color: AppTheme.publicLine),
        Expanded(
          child: _selectedId == null
              ? const Center(
                  child: QuietState(
                      message: 'Choose a relationship to open it.'))
              : _detailPane(),
        ),
      ],
    );
  }

  Widget _listPane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorkspaceHeader(
          title: 'Relationships',
          context_: _loadingList ? null : '${_items.length} in this view',
        ),
        _ViewSwitcher(
          current: _view,
          onChanged: (v) {
            setState(() => _view = v);
            _loadList();
          },
        ),
        const SizedBox(height: 12),
        if (_refusal != null)
          RefusalNotice(refusal: _refusal!, onRetry: _loadList),
        Expanded(
          child: _loadingList
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? QuietState(
                      message: _view == 'all'
                          ? 'No relationships yet.'
                          : 'Nothing in this view.',
                      hint: _view == 'all'
                          ? 'They appear as discovery and communication '
                              'establish them.'
                          : null,
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _items.length,
                      itemBuilder: (context, i) {
                        final r = _items[i];
                        return WorkspaceRow(
                          title: r.counterparty,
                          detail: r.openEngagementRef ?? r.stageLabel,
                          meta: _ago(r.lastEventAt),
                          tone: r.closed
                              ? RowTone.neutral
                              : (r.hasHeardBack ? RowTone.good : RowTone.waiting),
                          onTap: () => _loadDetail(r.id),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _detailPane({VoidCallback? onBack}) {
    if (_loadingDetail) {
      return const Center(child: CircularProgressIndicator());
    }
    final d = _detail;
    if (d == null) return const SizedBox.shrink();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        WorkspaceHeader(
          title: d.counterparty,
          onBack: onBack,
          // Only what changes what to do next. The engagement names itself
          // directly below, so repeating it here is chrome, not orientation.
          context_: d.closed
              ? 'Closed${d.closedReason != null ? ' — ${d.closedReason}' : ''}'
              : (d.current == null && d.timeline.isNotEmpty
                  ? 'No engagement open'
                  : null),
        ),
        if (d.current != null) ...[
          EngagementLifecycle(
            engagement: d.current!,
            timeline: d.timeline,
          ),
          const SizedBox(height: 24),
        ] else
          const QuietState(
            message: 'No engagement opened yet.',
            hint: 'An engagement is where agreements, obligations and '
                'invoices for this relationship live.',
          ),
        RelationshipTimeline(
          events: d.timeline,
          correspondence: d.correspondence,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  static String? _ago(DateTime? at) {
    if (at == null) return null;
    final d = DateTime.now().difference(at);
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 30) return '${d.inDays}d';
    return '${at.day}/${at.month}/${at.year % 100}';
  }
}

/// Saved views of one set of records. Not separate domains.
class _ViewSwitcher extends StatelessWidget {
  const _ViewSwitcher({required this.current, required this.onChanged});

  final String current;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    // Wrapped, not scrolled. In a 340px list pane a horizontal scroller
    // clips the last view at the edge, which reads as a rendering fault
    // rather than as more content.
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final entry in _views.entries)
          _ViewChip(
            label: entry.value,
            selected: entry.key == current,
            onTap: () => onChanged(entry.key),
          ),
      ],
    );
  }
}

class _ViewChip extends StatelessWidget {
  const _ViewChip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppTheme.publicAccentSoft : Colors.transparent,
            border: Border.all(
                color: selected ? AppTheme.publicAccent : AppTheme.publicLine),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected ? AppTheme.publicAccent : AppTheme.publicMuted,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}
