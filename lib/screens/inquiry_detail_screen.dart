import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/async_surface.dart';

class InquiryDetailScreen extends StatefulWidget {
  const InquiryDetailScreen({super.key, required this.inquiryId});

  final String inquiryId;

  @override
  State<InquiryDetailScreen> createState() => _InquiryDetailScreenState();
}

class _InquiryDetailScreenState extends State<InquiryDetailScreen> {
  late Future<_InquiryDetailData> _future;
  final ApiClient _apiClient = ApiClient();
  final TextEditingController _replyController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<_InquiryDetailData> _load() async {
    final inquiry = await _apiClient.getJson(
      '/operator/inquiries/${widget.inquiryId}',
      surface: ApiSurface.operator,
    );

    dynamic thread;
    dynamic notes;
    try {
      thread = await _apiClient.getJson(
        '/operator/inquiries/${widget.inquiryId}/thread',
        surface: ApiSurface.operator,
      );
    } catch (_) {
      thread = const <String, dynamic>{'messages': []};
    }

    try {
      notes = await _apiClient.getJson(
        '/operator/inquiries/${widget.inquiryId}/notes',
        surface: ApiSurface.operator,
      );
    } catch (_) {
      notes = const [];
    }

    return _InquiryDetailData(
      inquiry: Map<String, dynamic>.from(inquiry as Map),
      messages: ((thread as Map?)?['messages'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
      notes: (notes as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _busy = true);
    try {
      await _apiClient.postJson(
        '/operator/inquiries/${widget.inquiryId}/status',
        body: {'status': status},
        surface: ApiSurface.operator,
      );
      await _refresh();
    } on ApiException {
      // ignore for now and let the screen reload state next time
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendReply() async {
    final content = _replyController.text.trim();
    if (content.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _apiClient.postJson(
        '/operator/inquiries/${widget.inquiryId}/reply',
        body: {'content': content},
        surface: ApiSurface.operator,
      );
      _replyController.clear();
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addNote() async {
    final content = _noteController.text.trim();
    if (content.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _apiClient.postJson(
        '/operator/inquiries/${widget.inquiryId}/notes',
        body: {'content': content},
        surface: ApiSurface.operator,
      );
      _noteController.clear();
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncSurface<_InquiryDetailData>(
      future: _future,
      builder: (context, data) {
        final detail = data;
        if (detail == null) return const SizedBox.shrink();
        final inquiry = detail.inquiry;
        final name = _read(inquiry, 'name', fallback: 'Unknown');
        final company = _read(inquiry, 'company');
        final email = _read(inquiry, 'email');
        final type = _read(inquiry, 'type', fallback: 'General');
        final status = _read(inquiry, 'status', fallback: 'NEW');
        final message = _read(inquiry, 'message');
        final timestamp = _formatDate(_read(inquiry, 'createdAt'));

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            [if (company.isNotEmpty) company, if (email.isNotEmpty) email, type, if (timestamp.isNotEmpty) timestamp].join('  ·  '),
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.slate),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    _StatusPill(status: status),
                  ],
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 1080;
                    if (stacked) {
                      return Column(
                        children: [
                          _buildConversationCard(context, message, detail.messages),
                          const SizedBox(height: 20),
                          _buildSidePanel(context, inquiry, detail.notes),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 8, child: _buildConversationCard(context, message, detail.messages)),
                        const SizedBox(width: 20),
                        Expanded(flex: 4, child: _buildSidePanel(context, inquiry, detail.notes)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConversationCard(BuildContext context, String initialMessage, List<Map<String, dynamic>> messages) {
    final timeline = <Map<String, dynamic>>[];
    if (initialMessage.isNotEmpty) {
      timeline.add({
        'type': 'USER',
        'content': initialMessage,
        'createdAt': null,
      });
    }
    timeline.addAll(messages);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Conversation',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          if (timeline.isEmpty)
            const Text('No messages yet.')
          else
            ...timeline.map((message) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MessageBubble(message: message),
                )),
          const SizedBox(height: 8),
          TextField(
            controller: _replyController,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Write a reply',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _busy ? null : _sendReply,
              child: Text(_busy ? 'Working...' : 'Send reply'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidePanel(BuildContext context, Map<String, dynamic> inquiry, List<Map<String, dynamic>> notes) {
    return Column(
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Control',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton(
                    onPressed: _busy ? null : () => _updateStatus('ACKNOWLEDGED'),
                    child: const Text('Acknowledge'),
                  ),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _updateStatus('IN_PROGRESS'),
                    child: const Text('In progress'),
                  ),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _updateStatus('CLOSED'),
                    child: const Text('Close'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _metaRow('Email', _read(inquiry, 'email')),
              _metaRow('Company', _read(inquiry, 'company')),
              _metaRow('Type', _read(inquiry, 'type')),
              _metaRow('Assigned', _read(inquiry, 'assignedToName', fallback: 'Unassigned')),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notes',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Add an internal note',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: _busy ? null : _addNote,
                  child: const Text('Save note'),
                ),
              ),
              const SizedBox(height: 16),
              if (notes.isEmpty)
                const Text('No notes yet.')
              else
                ...notes.map((note) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _read(note, 'content'),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatDate(_read(note, 'createdAt')),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.slate),
                            ),
                          ],
                        ),
                      ),
                    )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: child,
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value.isEmpty ? '—' : value),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final type = _read(message, 'type', fallback: 'USER').toUpperCase();
    final content = _read(message, 'content');
    final timestamp = _formatDate(_read(message, 'createdAt'));

    final background = switch (type) {
      'OPERATOR' => const Color(0xFFEFF4FF),
      'SYSTEM' => const Color(0xFFF3F4F6),
      _ => const Color(0xFFFAFAFA),
    };

    final title = switch (type) {
      'OPERATOR' => 'Operator',
      'SYSTEM' => 'System',
      _ => 'Inquiry',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              if (timestamp.isNotEmpty)
                Text(timestamp, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.slate)),
            ],
          ),
          const SizedBox(height: 8),
          Text(content),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

String _read(Map<String, dynamic> map, String key, {String fallback = ''}) {
  final value = map[key]?.toString().trim() ?? '';
  return value.isEmpty ? fallback : value;
}

String _formatDate(String raw) {
  if (raw.isEmpty) return '';
  final parsed = DateTime.tryParse(raw)?.toLocal();
  if (parsed == null) return raw;
  final month = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ][parsed.month - 1];
  final hour = parsed.hour == 0 ? 12 : (parsed.hour > 12 ? parsed.hour - 12 : parsed.hour);
  final minute = parsed.minute.toString().padLeft(2, '0');
  final meridiem = parsed.hour >= 12 ? 'PM' : 'AM';
  return '$month ${parsed.day}, $hour:$minute $meridiem';
}

class _InquiryDetailData {
  const _InquiryDetailData({
    required this.inquiry,
    required this.messages,
    required this.notes,
  });

  final Map<String, dynamic> inquiry;
  final List<Map<String, dynamic>> messages;
  final List<Map<String, dynamic>> notes;
}
