import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/public_repository.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();
  final _messageController = TextEditingController();
  final _repository = PublicRepository();

  static const List<_InquiryOption> _inquiryTypes = <_InquiryOption>[
    _InquiryOption(label: 'Service fit', value: 'SERVICE_FIT'),
    _InquiryOption(label: 'Pricing', value: 'PRICING'),
    _InquiryOption(label: 'Billing support', value: 'BILLING_SUPPORT'),
    _InquiryOption(label: 'Onboarding', value: 'ONBOARDING'),
    _InquiryOption(label: 'Partnership', value: 'PARTNERSHIP'),
    _InquiryOption(label: 'General inquiry', value: 'GENERAL_INQUIRY'),
  ];

  String _selectedInquiry = _inquiryTypes.first.value;
  bool _submitting = false;
  bool _submitted = false;
  String? _successMessage;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _submitting = true;
      _submitted = false;
      _successMessage = null;
      _errorMessage = null;
    });

    try {
      final response = await _repository.submitContact(
        name: _nameController.text,
        email: _emailController.text,
        company: _companyController.text,
        inquiryType: _selectedInquiry,
        message: _messageController.text,
      );

      final message = (response['message'] as String?)?.trim();

      if (!mounted) return;

      setState(() {
        _submitting = false;
        _submitted = true;
        _successMessage =
            (message != null && message.isNotEmpty)
                ? message
                : 'Thanks. Your inquiry has been received and routed.';
        _errorMessage = null;
      });

      _formKey.currentState?.reset();
      _nameController.clear();
      _emailController.clear();
      _companyController.clear();
      _messageController.clear();
      if (mounted) {
        setState(() {
          _selectedInquiry = _inquiryTypes.first.value;
        });
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = false;
        _errorMessage = _messageFromApiException(error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = false;
        _errorMessage =
            'We could not send your inquiry right now. Please try again in a moment or email hello@orchestrateops.com.';
      });
    }
  }

  String _messageFromApiException(ApiException error) {
    try {
      final decoded = jsonDecode(error.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
        if (message is List && message.isNotEmpty) {
          return message.first.toString();
        }
      }
    } catch (_) {}

    if (error.statusCode >= 500) {
      return 'Your inquiry was not sent because the server had a problem. Please try again in a moment.';
    }

    return 'Please review the form and try again.';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 980;
                final intro = const _IntroPanel();
                final form = _FormCard(
                  formKey: _formKey,
                  nameController: _nameController,
                  emailController: _emailController,
                  companyController: _companyController,
                  messageController: _messageController,
                  inquiryTypes: _inquiryTypes,
                  selectedInquiry: _selectedInquiry,
                  onInquiryChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedInquiry = value;
                    });
                  },
                  onSubmit: _submit,
                  submitting: _submitting,
                  submitted: _submitted,
                  successMessage: _successMessage,
                  errorMessage: _errorMessage,
                );

                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      intro,
                      const SizedBox(height: 20),
                      form,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: intro),
                    const SizedBox(width: 24),
                    Expanded(flex: 6, child: form),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _InquiryOption {
  const _InquiryOption({required this.label, required this.value});

  final String label;
  final String value;
}

class _IntroPanel extends StatelessWidget {
  const _IntroPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _Eyebrow(label: 'Contact'),
          SizedBox(height: 18),
          _IntroTitle(),
          SizedBox(height: 16),
          _IntroBody(),
          SizedBox(height: 28),
          _InfoCard(
            title: 'When to use this page',
            body:
                'Use this page when you want to talk through fit, scope, pricing, onboarding, or billing support before moving forward.',
          ),
          SizedBox(height: 16),
          _InfoCard(
            title: 'What to include',
            body:
                'Tell us what your business needs, what stage you are in, and any useful context that can help shape the conversation.',
          ),
          SizedBox(height: 16),
          _InfoCard(
            title: 'What happens next',
            body:
                'Your inquiry is saved inside Orchestrate first, then routed to the operating inbox for follow-up.',
          ),
        ],
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.publicAccentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.publicAccent,
            ),
      ),
    );
  }
}

class _IntroTitle extends StatelessWidget {
  const _IntroTitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Talk through fit, scope, and next steps',
      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontSize: 42,
            height: 1.04,
            letterSpacing: -0.8,
          ),
    );
  }
}

class _IntroBody extends StatelessWidget {
  const _IntroBody();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Use this page to start a direct business conversation with Orchestrate. This is the right place for service fit, pricing, onboarding, billing support, or partnership inquiries.',
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppTheme.publicMuted,
          ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.publicText,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.companyController,
    required this.messageController,
    required this.inquiryTypes,
    required this.selectedInquiry,
    required this.onInquiryChanged,
    required this.onSubmit,
    required this.submitting,
    required this.submitted,
    required this.successMessage,
    required this.errorMessage,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController companyController;
  final TextEditingController messageController;
  final List<_InquiryOption> inquiryTypes;
  final String selectedInquiry;
  final ValueChanged<String?> onInquiryChanged;
  final Future<void> Function() onSubmit;
  final bool submitting;
  final bool submitted;
  final String? successMessage;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send an inquiry',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Share a few details and we will use that to begin the conversation.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.publicMuted,
                  ),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 640;
                if (stacked) {
                  return Column(
                    children: [
                      _FieldBlock(
                        label: 'Name',
                        child: _AppTextField(
                          controller: nameController,
                          hintText: 'Your full name',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your name.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      _FieldBlock(
                        label: 'Email',
                        child: _AppTextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          hintText: 'name@company.com',
                          validator: (value) {
                            final trimmed = value?.trim() ?? '';
                            if (trimmed.isEmpty) {
                              return 'Please enter your email.';
                            }
                            final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                            if (!emailPattern.hasMatch(trimmed)) {
                              return 'Please enter a valid email address.';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _FieldBlock(
                        label: 'Name',
                        child: _AppTextField(
                          controller: nameController,
                          hintText: 'Your full name',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your name.';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _FieldBlock(
                        label: 'Email',
                        child: _AppTextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          hintText: 'name@company.com',
                          validator: (value) {
                            final trimmed = value?.trim() ?? '';
                            if (trimmed.isEmpty) {
                              return 'Please enter your email.';
                            }
                            final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                            if (!emailPattern.hasMatch(trimmed)) {
                              return 'Please enter a valid email address.';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            _FieldBlock(
              label: 'Company',
              child: _AppTextField(
                controller: companyController,
                hintText: 'Company name',
              ),
            ),
            const SizedBox(height: 18),
            _FieldBlock(
              label: 'Inquiry type',
              child: DropdownButtonFormField<String>(
                value: selectedInquiry,
                items: inquiryTypes
                    .map(
                      (type) => DropdownMenuItem<String>(
                        value: type.value,
                        child: Text(type.label),
                      ),
                    )
                    .toList(),
                onChanged: submitting ? null : onInquiryChanged,
                decoration: _inputDecoration(context),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            const SizedBox(height: 18),
            _FieldBlock(
              label: 'Message',
              child: _AppTextField(
                controller: messageController,
                hintText:
                    'Tell us what you need, what stage you are in, and anything useful for the conversation.',
                maxLines: 7,
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return 'Please enter a message.';
                  }
                  if (trimmed.length < 20) {
                    return 'Please add a little more detail.';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: submitting ? null : onSubmit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: AppTheme.publicText,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.publicLine,
                disabledForegroundColor: AppTheme.publicMuted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              child: Text(submitting ? 'Sending inquiry...' : 'Send inquiry'),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              _FeedbackBanner(
                message: errorMessage!,
                accent: const Color(0xFFB42318),
                background: const Color(0xFFFEE4E2),
              ),
            ],
            if (submitted && successMessage != null) ...[
              const SizedBox(height: 16),
              _FeedbackBanner(
                message: successMessage!,
                accent: AppTheme.publicText,
                background: AppTheme.publicAccentSoft,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({
    required this.message,
    required this.accent,
    required this.background,
  });

  final String message;
  final Color accent;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: accent,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _FieldBlock extends StatelessWidget {
  const _FieldBlock({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.publicText,
              ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _AppTextField extends StatelessWidget {
  const _AppTextField({
    required this.controller,
    required this.hintText,
    this.validator,
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final String? Function(String?)? validator;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: _inputDecoration(context).copyWith(hintText: hintText),
    );
  }
}

InputDecoration _inputDecoration(BuildContext context) {
  return InputDecoration(
    filled: true,
    fillColor: AppTheme.publicBackground,
    hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: AppTheme.publicMuted,
        ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppTheme.publicLine),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppTheme.publicAccent),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
  );
}
