import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/async_surface.dart';
import '../data/repositories/operator_repository.dart';

class InquiryDetailScreen extends StatefulWidget {
  const InquiryDetailScreen({super.key, required this.inquiryId});

  final String inquiryId;

  @override
  State<InquiryDetailScreen> createState() => _InquiryDetailScreenState();
}

class _InquiryDetailScreenState extends State<InquiryDetailScreen> {
  late Future<_InquiryDetailData> _future;
  final OperatorRepository _repo = OperatorRepository();

  final TextEditingController _replyController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  bool _sendingReply = false;
  bool _savingNote = false;
  bool _updatingStatus = false;

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
    final inquiry = await _repo.fetchInquiryById(widget.inquiryId);
    final messages = await _repo.fetchInquiryThread(widget.inquiryId);
    final notes = await _repo.fetchInquiryNotes(widget.inquiryId);

    return _InquiryDetailData(
      inquiry: inquiry,
      messages: messages,
      notes: notes,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _updatingStatus = true);
    try {
      await _repo.updateInquiryStatus(
        inquiryId: widget.inquiryId,
        status: status,
      );
      await _refresh();
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<void> _sendReply() async {
    final content = _replyController.text.trim();
    if (content.isEmpty) return;

    setState(() => _sendingReply = true);
    try {
      await _repo.sendInquiryReply(
        inquiryId: widget.inquiryId,
        content: content,
      );
      _replyController.clear();
      await _refresh();
    } finally {
      if (mounted) setState(() => _sendingReply = false);
    }
  }

  Future<void> _addNote() async {
    final content = _noteController.text.trim();
    if (content.isEmpty) return;

    setState(() => _savingNote = true);
    try {
      await _repo.addInquiryNote(
        inquiryId: widget.inquiryId,
        content: content,
      );
      _noteController.clear();
      await _refresh();
    } finally {
      if (mounted) setState(() => _savingNote = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncSurface<_InquiryDetailData>(
      future: _future,
      builder: (context, data) {
        if (data == null) return const SizedBox.shrink();

        final inquiry = data.inquiry;
        final name = _read(inquiry, 'name', fallback: 'Unknown');
        final company = _read(inquiry, 'company');
        final email = _read(inquiry, 'email');
        final type = _read(inquiry, 'type', fallback: 'General');
        final status = _read(inquiry, 'status', fallback: 'RECEIVED');
        final message = _read(inquiry, 'message');
        final createdAt = _formatDate(_read(inquiry, 'createdAt'));

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                            [
                              if (company.isNotEmpty) company,
                              if (email.isNotEmpty) email,
                              type,
                              if (createdAt.isNotEmpty) createdAt,
                            ].join('  ·  '),
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: AppTheme.slate,
                                ),
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

                    final conversation = _buildConversationCard(
                      context,
                      message,
                      data.messages,
                    );
                    final side = _buildSidePanel(context, inquiry, data.notes);

                    if (stacked) {
                      return Column(
                        children: [
                          conversation,
                          const SizedBox(height: 20),
                          side,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 8, child: conversation),
                        const SizedBox(width: 20),
                        Expanded(flex: 4, child: side),
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

  Widget _buildConversationCard(
    BuildContext context,
    String initialMessage,
    List<Map<String, dynamic>> messages,
  ) {
    final timeline = <Map<String, dynamic>>[
      if (initialMessage.isNotEmpty)
        {
          'type': 'USER',
          'content': initialMessage,
          'createdAt': null,
        },
      ...messages,
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Conversation',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          if (timeline.isEmpty)
            const Text('No messages yet.')
          else
            ...timeline.map(
              (msg) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _MessageBubble(message: msg),
              ),
            ),
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
              onPressed: _sendingReply ? null : _sendReply,
              child: Text(_sendingReply ? 'Sending...' : 'Send reply'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidePanel(
    BuildContext context,
    Map<String, dynamic> inquiry,
    List<Map<String, dynamic>> notes,
  ) {
    return Column(
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Control',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton(
                    onPressed: _updatingStatus ? null : () => _updateStatus('ACKNOWLEDGED'),
                    child: Text(_updatingStatus ? 'Working...' : 'Acknowledge'),
                  ),
                  OutlinedButton(
                    onPressed: _updatingStatus ? null : () => _updateStatus('CLOSED'),
                    child: const Text('Close'),
                  ),
                  OutlinedButton(
                    onPressed: _updatingStatus ? null : () => _updateStatus('SPAM'),
                    child: const Text('Mark spam'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _metaRow('Email', _read(inquiry, 'email')),
              _metaRow('Company', _read(inquiry, 'company')),
              _metaRow('Type', _read(inquiry, 'type')),
              _metaRow(
                'Assigned',
                _read(inquiry, 'assignedToName', fallback: 'Unassigned'),
              ),
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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
                  onPressed: _savingNote ? null : _addNote,
                  child: Text(_savingNote ? 'Saving...' : 'Save note'),
                ),
              ),
              const SizedBox(height: 16),
              if (notes.isEmpty)
                const Text('No notes yet.')
              else
                ...notes.map(
                  (note) => Padding(
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
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.slate,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
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
              Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              if (timestamp.isNotEmpty)
                Text(
                  timestamp,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.slate,
                      ),
                ),
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
    final normalized = status.toUpperCase();

    final background = switch (normalized) {
      'RECEIVED' => const Color(0xFFFFF4DB),
      'NOTIFIED' => const Color(0xFFEFF4FF),
      'ACKNOWLEDGED' => const Color(0xFFE8F8F0),
      'CLOSED' => const Color(0xFFF3F4F6),
      'SPAM' => const Color(0xFFFDECEC),
      _ => const Color(0xFFF3F4F6),
    };

    final foreground = switch (normalized) {
      'RECEIVED' => const Color(0xFF8A5A00),
      'NOTIFIED' => const Color(0xFF1D4ED8),
      'ACKNOWLEDGED' => const Color(0xFF0F766E),
      'CLOSED' => const Color(0xFF4B5563),
      'SPAM' => const Color(0xFF991B1B),
      _ => const Color(0xFF4B5563),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        normalized.replaceAll('_', ' '),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
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
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][parsed.month - 1];

  final hour = parsed.hour == 0
      ? 12
      : (parsed.hour > 12 ? parsed.hour - 12 : parsed.hour);

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