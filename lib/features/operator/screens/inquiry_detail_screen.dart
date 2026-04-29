import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/network/api_client.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/operator_repository.dart';

class InquiryDetailScreen extends StatefulWidget {
  const InquiryDetailScreen({super.key, required this.inquiryId});
  final String inquiryId;

  @override
  State<InquiryDetailScreen> createState() => _InquiryDetailScreenState();
}

class _InquiryDetailScreenState extends State<InquiryDetailScreen> {
  final _replyController = TextEditingController();
  final _noteController = TextEditingController();

  bool _loading = true;
  bool _sendingReply = false;
  bool _savingNote = false;
  bool _updatingStatus = false;
  String? _error;

  Map<String, dynamic> _inquiry = const {};
  List<Map<String, dynamic>> _thread = const [];
  List<Map<String, dynamic>> _notes = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = OperatorRepository();
      final inquiry = await repo.fetchInquiryById(widget.inquiryId);
      final thread = await repo.fetchInquiryThread(widget.inquiryId);
      final notes = await repo.fetchInquiryNotes(widget.inquiryId);
      if (!mounted) return;
      setState(() {
        _inquiry = inquiry;
        _thread = thread;
        _notes = notes;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _errorMessage(error, 'This inquiry could not load at the moment.');
      });
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _updatingStatus = true);
    try {
      await OperatorRepository()
          .updateInquiryStatus(inquiryId: widget.inquiryId, status: status);
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _error = _errorMessage(error, 'Status could not be updated.'));
      }
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<void> _sendReply() async {
    if (_replyController.text.trim().isEmpty) return;
    setState(() => _sendingReply = true);
    try {
      await OperatorRepository().sendInquiryReply(
          inquiryId: widget.inquiryId, content: _replyController.text.trim());
      _replyController.clear();
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _error = _errorMessage(error, 'Reply could not be sent.'));
      }
    } finally {
      if (mounted) setState(() => _sendingReply = false);
    }
  }

  Future<void> _addNote() async {
    if (_noteController.text.trim().isEmpty) return;
    setState(() => _savingNote = true);
    try {
      await OperatorRepository().addInquiryNote(
          inquiryId: widget.inquiryId, content: _noteController.text.trim());
      _noteController.clear();
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _error = _errorMessage(error, 'Note could not be saved.'));
      }
    } finally {
      if (mounted) setState(() => _savingNote = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _inquiry.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: AppTheme.panel,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(color: AppTheme.line)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_read(_inquiry, 'name', fallback: 'Inquiry'),
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 10),
              Text(_read(_inquiry, 'message'),
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              Wrap(spacing: 10, runSpacing: 10, children: [
                _Pill(label: _read(_inquiry, 'status', fallback: 'NEW')),
                _Pill(label: _read(_inquiry, 'email', fallback: 'No email')),
                _Pill(label: 'SLA: ${_read(_inquiry, 'slaState', fallback: 'not_set')}'),
                _Pill(label: 'Escalation: ${_read(_inquiry, 'escalationState', fallback: 'standard')}'),
                _Pill(label: 'Assigned: ${_read(_inquiry, 'assignedToName', fallback: 'Unassigned')}'),
                if (_read(_inquiry, 'company').isNotEmpty)
                  _Pill(label: _read(_inquiry, 'company')),
                if (_read(_inquiry, 'type').isNotEmpty)
                  _Pill(label: _read(_inquiry, 'type')),
              ]),
            ]),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
                child: _ActionButton(
                    label: _updatingStatus ? 'Working...' : 'Acknowledge',
                    onTap: _updatingStatus
                        ? null
                        : () => _updateStatus('ACKNOWLEDGED'))),
            const SizedBox(width: 12),
            Expanded(
                child: _ActionButton(
                    label: 'Start work',
                    onTap: _updatingStatus
                        ? null
                        : () => _updateStatus('IN_PROGRESS'))),
            const SizedBox(width: 12),
            Expanded(
                child: _ActionButton(
                    label: 'Close',
                    onTap: _updatingStatus
                        ? null
                        : () => _updateStatus('CLOSED'))),
          ]),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _InlineError(message: _error!, onRetry: _load),
          ],
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 980;
              final left = _Card(
                title: 'Conversation',
                child: _thread.isEmpty
                    ? Text('No thread messages are available yet.',
                        style: Theme.of(context).textTheme.bodyMedium)
                    : Column(
                        children: [
                          for (int i = 0; i < _thread.length; i++) ...[
                            _ThreadMessage(item: _thread[i]),
                            if (i != _thread.length - 1)
                              const Divider(height: 22, color: AppTheme.line),
                          ],
                        ],
                      ),
              );
              final right = Column(children: [
                _Card(
                  title: 'Reply',
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                            controller: _replyController,
                            minLines: 4,
                            maxLines: 8,
                            decoration: const InputDecoration(
                                hintText: 'Write a direct reply')),
                        const SizedBox(height: 12),
                        FilledButton(
                            onPressed: _sendingReply ? null : _sendReply,
                            child: Text(
                                _sendingReply ? 'Sending...' : 'Send reply')),
                      ]),
                ),
                const SizedBox(height: 18),
                _Card(
                  title: 'Notes',
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_notes.isEmpty)
                          Text('No internal notes are available yet.',
                              style: Theme.of(context).textTheme.bodyMedium)
                        else ...[
                          for (int i = 0; i < _notes.length; i++) ...[
                            _NoteRow(item: _notes[i]),
                            if (i != _notes.length - 1)
                              const Divider(height: 22, color: AppTheme.line),
                          ],
                          const SizedBox(height: 14),
                        ],
                        TextField(
                            controller: _noteController,
                            minLines: 3,
                            maxLines: 6,
                            decoration: const InputDecoration(
                                hintText: 'Add an internal note')),
                        const SizedBox(height: 12),
                        FilledButton(
                            onPressed: _savingNote ? null : _addNote,
                            child:
                                Text(_savingNote ? 'Saving...' : 'Add note')),
                      ]),
                ),
              ]);

              if (stacked) {
                return Column(
                    children: [left, const SizedBox(height: 18), right]);
              }
              return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: left),
                    const SizedBox(width: 18),
                    Expanded(flex: 5, child: right)
                  ]);
            },
          ),
        ],
      ),
    );
  }
}

String _errorMessage(Object error, String fallback) {
  if (error is ApiException) return error.displayMessage;
  return fallback;
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF3A1F23),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: const Color(0xFF7A3A43)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(message)),
          const SizedBox(width: 12),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(onPressed: onTap, child: Text(label));
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: AppTheme.panel,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: AppTheme.panelRaised,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.line)),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _ThreadMessage extends StatelessWidget {
  const _ThreadMessage({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
          _read(item, 'senderName',
              fallback: _read(item, 'senderEmail', fallback: 'Message')),
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 6),
      Text(_read(item, 'content'),
          style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 6),
      Text(_read(item, 'createdAt'),
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppTheme.subdued)),
    ]);
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_read(item, 'content'),
          style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 6),
      Text(_read(item, 'createdAt'),
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppTheme.subdued)),
    ]);
  }
}

String _read(dynamic source, String key, {String fallback = ''}) {
  if (source is! Map) return fallback;
  final value = source[key];
  if (value == null) return fallback;
  return value.toString();
}
