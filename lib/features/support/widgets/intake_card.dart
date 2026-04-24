import 'package:flutter/material.dart';

class IntakeCard extends StatefulWidget {
  final bool publicMode;
  final bool isLoading;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final Future<void> Function(String message, String? name, String? email)
      onSubmit;

  const IntakeCard({
    super.key,
    required this.publicMode,
    required this.isLoading,
    required this.onSubmit,
    this.initialValue,
    this.onChanged,
  });

  @override
  State<IntakeCard> createState() => _IntakeCardState();
}

class _IntakeCardState extends State<IntakeCard> {
  late final TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void didUpdateWidget(covariant IntakeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.initialValue ?? '';

    if (incoming == _messageController.text) return;

    if (incoming.isEmpty && _messageController.text.isNotEmpty) {
      _messageController.clear();
      return;
    }

    if (incoming.isNotEmpty) {
      _messageController.text = incoming;
      _messageController.selection =
          TextSelection.collapsed(offset: incoming.length);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || widget.isLoading) return;

    await widget.onSubmit(message, null, null);

    if (!mounted) return;

    _messageController.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant.withOpacity(0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: !widget.isLoading,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                hintText: 'Write your message...',
                filled: true,
                fillColor: scheme.surfaceContainerLowest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: widget.isLoading ? null : _submit,
            child: Text(widget.isLoading ? '...' : 'Send'),
          ),
        ],
      ),
    );
  }
}
