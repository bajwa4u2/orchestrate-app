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
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _showContactFields = false;

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
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || widget.isLoading) return;

    await widget.onSubmit(
      message,
      widget.publicMode ? _nameController.text.trim() : null,
      widget.publicMode ? _emailController.text.trim() : null,
    );

    if (!mounted) return;

    _messageController.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final heading =
        widget.publicMode ? 'Send your message' : 'Send a message';
    final supportingText = widget.publicMode
        ? 'Describe the question, issue, or setup need. Add contact details only if you want follow-up outside this conversation.'
        : 'Describe the question, issue, or setup need. Your current account context will be used where it helps.';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 24,
            spreadRadius: 0,
            offset: Offset(0, 10),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            supportingText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.70),
                ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _messageController,
            minLines: 5,
            maxLines: 8,
            enabled: !widget.isLoading,
            textInputAction: TextInputAction.newline,
            onChanged: widget.onChanged,
            decoration: InputDecoration(
              hintText: widget.publicMode
                  ? 'For example: I need help choosing a plan, understanding setup, clarifying billing, or resolving an issue.'
                  : 'Describe what you need. Include enough detail for a useful reply.',
              filled: true,
              fillColor: scheme.surfaceContainerLowest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.65),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: scheme.primary),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          if (widget.publicMode) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: widget.isLoading
                  ? null
                  : () => setState(() => _showContactFields = !_showContactFields),
              icon: Icon(
                _showContactFields
                    ? Icons.remove_circle_outline
                    : Icons.add_circle_outline,
                size: 18,
              ),
              label: Text(
                _showContactFields
                    ? 'Hide contact details'
                    : 'Add contact details',
              ),
            ),
            if (_showContactFields) ...[
              const SizedBox(height: 6),
              Text(
                'Only add these if you want follow-up outside this session.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.65),
                    ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                enabled: !widget.isLoading,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _emailController,
                enabled: !widget.isLoading,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                ),
              ),
            ],
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.publicMode
                      ? 'We’ll respond directly or move it into review if needed.'
                      : 'We’ll respond directly or continue the thread if more detail helps.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.70),
                      ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: widget.isLoading ? null : _submit,
                child: Text(
                  widget.isLoading ? 'Sending…' : 'Send message',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}