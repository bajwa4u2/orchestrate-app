import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_session.dart';

class ClientSetupScreen extends StatefulWidget {
  const ClientSetupScreen({super.key});

  @override
  State<ClientSetupScreen> createState() => _ClientSetupScreenState();
}

class _ClientSetupScreenState extends State<ClientSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _country = TextEditingController();
  final _area = TextEditingController();
  final _industry = TextEditingController();

  final List<String> _scope = [];

  bool _busy = false;
  String? _error;

  final scopeOptions = [
    'lead_generation',
    'outreach',
    'follow_up',
    'meeting_booking',
    'billing_collections',
  ];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_scope.isEmpty) {
      setState(() => _error = 'Select at least one scope.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    /// TEMPORARY: simulate backend success
    await Future.delayed(const Duration(milliseconds: 500));

    await AuthSessionController.instance.markSetupComplete();

    if (!mounted) return;
    context.go('/client/workspace');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Client setup')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Text(
                    'Define your operating scope before service activation.',
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: _country,
                    decoration: const InputDecoration(labelText: 'Country'),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),

                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _area,
                    decoration:
                        const InputDecoration(labelText: 'Target area'),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),

                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _industry,
                    decoration:
                        const InputDecoration(labelText: 'Industry'),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),

                  const SizedBox(height: 16),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: const Text('Scope of work'),
                  ),

                  Wrap(
                    spacing: 8,
                    children: scopeOptions.map((s) {
                      final selected = _scope.contains(s);
                      return FilterChip(
                        label: Text(s),
                        selected: selected,
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _scope.add(s);
                            } else {
                              _scope.remove(s);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(
                          _busy ? 'Saving...' : 'Save and continue'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}