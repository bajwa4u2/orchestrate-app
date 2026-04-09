import 'package:flutter/material.dart';

class IntakeCard extends StatefulWidget {
  final bool publicMode;
  final bool isLoading;
  final void Function(String message, String? name, String? email) onSubmit;
  final void Function(String value)? onChanged;
  final String? initialValue;

  const IntakeCard({
    super.key,
    required this.publicMode,
    required this.isLoading,
    required this.onSubmit,
    this.onChanged,
    this.initialValue,
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
    if (incoming != _messageController.text && incoming.isNotEmpty) {
      _messageController.text = incoming;
      _messageController.selection = TextSelection.collapsed(offset: incoming.length);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    final message = _messageController.text.trim();
    if (message.isEmpty || widget.isLoading) return;

    widget.onSubmit(
      message,
      widget.publicMode ? _nameController.text.trim() : null,
      widget.publicMode ? _emailController.text.trim() : null,
    );

    _messageController.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.45)),
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
            widget.publicMode
                ? 'Describe what you’re trying to do or where you need help'
                : 'Describe what you need help with',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            minLines: 5,
            maxLines: 8,
            enabled: !widget.isLoading,
            onChanged: widget.onChanged,
            decoration: InputDecoration(
              hintText: 'Write your message here',
              filled: true,
              fillColor: scheme.surfaceContainerLowest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.65)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: scheme.primary),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          if (widget.publicMode) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => setState(() => _showContactFields = !_showContactFields),
              child: Text(_showContactFields ? 'Hide contact details' : 'Add contact details'),
            ),
            if (_showContactFields) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                enabled: !widget.isLoading,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _emailController,
                enabled: !widget.isLoading,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
            ],
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.publicMode
                      ? 'We’ll respond immediately or guide you forward.'
                      : 'We’ll use your current workspace context where it helps.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: widget.isLoading ? null : _submit,
                child: Text(widget.isLoading ? 'Working…' : 'Continue'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
