import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/network/api_client.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';
import 'package:orchestrate_app/features/support/services/support_service.dart';

class ClientSupportScreen extends StatefulWidget {
  const ClientSupportScreen({super.key});

  @override
  State<ClientSupportScreen> createState() => _ClientSupportScreenState();
}

class _ClientSupportScreenState extends State<ClientSupportScreen> {
  final SupportService _service = SupportService();
  final TextEditingController _newRequest = TextEditingController();
  final TextEditingController _reply = TextEditingController();
  final FocusNode _newRequestFocus = FocusNode();
  late Future<Map<String, dynamic>> _future;
  Map<String, dynamic>? _thread;
  String? _selectedId;
  bool _submitting = false;
  bool _loadingThread = false;

  @override
  void initState() {
    super.initState();
    _future = _service.listClientInquiries();
  }

  @override
  void dispose() {
    _newRequest.dispose();
    _reply.dispose();
    _newRequestFocus.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() => _future = _service.listClientInquiries());
  }

  Future<void> _loadThread(String id) async {
    setState(() {
      _selectedId = id;
      _loadingThread = true;
    });
    try {
      final thread = await _service.getClientInquiryThread(id);
      if (!mounted) return;
      setState(() => _thread = thread);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error is ApiException
              ? error.displayMessage
              : error.toString())));
    } finally {
      if (mounted) setState(() => _loadingThread = false);
    }
  }

  Future<void> _createRequest() async {
    final message = _newRequest.text.trim();
    if (message.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await _service.createSession(message: message, publicMode: false);
      _newRequest.clear();
      _thread = null;
      _selectedId = null;
      _retry();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error is ApiException
              ? error.displayMessage
              : error.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _replyToThread() async {
    final thread = _thread;
    final sessionId = readText(thread ?? const {}, 'sessionId');
    final message = _reply.text.trim();
    if (thread == null || sessionId.isEmpty || message.isEmpty || _submitting) {
      return;
    }
    setState(() => _submitting = true);
    try {
      await _service.reply(
        sessionId: sessionId,
        message: message,
        publicMode: false,
      );
      _reply.clear();
      await _loadThread(readText(thread, 'id'));
      _retry();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error is ApiException
              ? error.displayMessage
              : error.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ClientLoadingView(label: 'Loading support');
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          return ClientErrorView(
            message:
                error is ApiException ? error.displayMessage : error.toString(),
            onRetry: _retry,
          );
        }
        final inquiries =
            asList(asMap(snapshot.data)['items']).map(asMap).toList();
        final open = inquiries
            .where((item) => readText(item, 'status') != 'CLOSED')
            .length;

        return ClientPage(
          eyebrow: 'Support',
          title: 'Support requests and conversations',
          subtitle:
              'Create a request when you need help, then reopen prior threads without losing context after refresh.',
          banner: ClientStatusBanner(
            tone: open > 0 ? ClientBannerTone.info : ClientBannerTone.success,
            title: open > 0
                ? '$open open support requests'
                : 'No open support requests',
            message:
                'We typically respond within one business day. If you do nothing, open requests remain in the support queue.',
          ),
          actions: [
            FilledButton.icon(
              onPressed: () => _newRequestFocus.requestFocus(),
              icon: const Icon(Icons.add_comment_outlined, size: 18),
              label: const Text('Create request'),
            ),
          ],
          children: [
            ClientMetricStrip(metrics: [
              ClientMetric('Requests', '${inquiries.length}'),
              ClientMetric('Open', '$open'),
              ClientMetric('Closed',
                  '${inquiries.where((item) => readText(item, 'status') == 'CLOSED').length}'),
              ClientMetric('Escalated',
                  '${inquiries.where((item) => item['isEscalated'] == true).length}'),
            ]),
            const SizedBox(height: 18),
            LayoutBuilder(builder: (context, constraints) {
              final stacked = constraints.maxWidth < 1040;
              final list = ClientPanel(
                title: 'Previous requests',
                children: inquiries.isEmpty
                    ? const [
                        ClientEmptyState(
                            message:
                                'No support requests are on record yet. Start a new request below.')
                      ]
                    : [
                        for (final item in inquiries)
                          ClientInfoRow(
                            title: _shorten(readText(item, 'subject',
                                fallback: 'Support request')),
                            primary:
                                '${_ticketState(item)} · ${titleCase(readText(item, 'priority'))}',
                            secondary: [
                              titleCase(readText(item, 'category')),
                              'Last response ${relativeDateLabel(item['lastOutboundAt'] ?? item['lastActivityAt'] ?? item['submittedAt'])}',
                            ].where((part) => part.isNotEmpty).join(' · '),
                            trailing: OutlinedButton(
                              onPressed: _loadingThread &&
                                      _selectedId == readText(item, 'id')
                                  ? null
                                  : () => _loadThread(readText(item, 'id')),
                              child: Text(_selectedId == readText(item, 'id')
                                  ? 'Open'
                                  : 'View'),
                            ),
                          ),
                      ],
              );
              final detail = _SupportThreadPanel(
                thread: _thread,
                loading: _loadingThread,
                replyController: _reply,
                submitting: _submitting,
                onReply: _replyToThread,
              );
              if (stacked) {
                return Column(
                  children: [
                    list,
                    const SizedBox(height: 18),
                    detail,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: list),
                  const SizedBox(width: 18),
                  Expanded(flex: 6, child: detail),
                ],
              );
            }),
            const SizedBox(height: 18),
            ClientPanel(
              title: 'Create a new request',
              children: [
                TextField(
                  controller: _newRequest,
                  focusNode: _newRequestFocus,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'What do you need help with?',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _submitting ? null : _createRequest,
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined, size: 18),
                  label: Text(_submitting ? 'Sending' : 'Send request'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

String _ticketState(Map<String, dynamic> item) {
  final status = readText(item, 'status').toUpperCase();
  if (status == 'CLOSED') return 'Closed';
  if (item['isEscalated'] == true) return 'Escalated';
  return 'Open';
}

class _SupportThreadPanel extends StatelessWidget {
  const _SupportThreadPanel({
    required this.thread,
    required this.loading,
    required this.replyController,
    required this.submitting,
    required this.onReply,
  });

  final Map<String, dynamic>? thread;
  final bool loading;
  final TextEditingController replyController;
  final bool submitting;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const ClientPanel(
        title: 'Conversation',
        children: [ClientLoadingView(label: 'Loading conversation')],
      );
    }
    final current = thread;
    if (current == null) {
      return const ClientPanel(
        title: 'Conversation',
        children: [
          ClientEmptyState(
              message:
                  'Select a previous request to review its persisted support thread.')
        ],
      );
    }
    final messages = asList(current['messages']).map(asMap).toList();
    final closed = readText(current, 'status') == 'CLOSED';
    return ClientPanel(
      title: 'Conversation',
      subtitle:
          '${titleCase(readText(current, 'status'))} · ${titleCase(readText(current, 'priority'))}',
      children: [
        if (messages.isEmpty)
          const ClientEmptyState(message: 'No thread messages are visible yet.')
        else
          for (final message in messages)
            ClientInfoRow(
              title: titleCase(readText(message, 'authorType',
                  fallback: readText(message, 'direction'))),
              primary: readText(message, 'bodyText'),
              secondary: dateLabel(message['sentAt'] ??
                  message['receivedAt'] ??
                  message['createdAt']),
            ),
        const SizedBox(height: 12),
        if (closed)
          const ClientEmptyState(
              message:
                  'This request is closed. Start a new request if you need more help.')
        else ...[
          TextField(
            controller: replyController,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Reply to this request',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: submitting ? null : onReply,
            icon: submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.reply_outlined, size: 18),
            label: Text(submitting ? 'Sending' : 'Send reply'),
          ),
        ],
      ],
    );
  }
}

String _shorten(String value) {
  if (value.length <= 90) return value;
  return '${value.substring(0, 87)}...';
}
