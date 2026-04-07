import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

class PublicContentScreen extends StatelessWidget {
  const PublicContentScreen({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.sections,
    this.sideNote,
    this.sideActions = const [],
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final List<ContentSection> sections;
  final String? sideNote;
  final List<ContentAction> sideActions;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTheme.publicSurface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppTheme.publicLine),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 940;
                      final lead = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.publicAccentSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              eyebrow,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppTheme.publicAccent,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                    fontSize: stacked ? 40 : 46,
                                    height: 1.04,
                                    letterSpacing: -1.1,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 760),
                            child: Text(
                              subtitle,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppTheme.publicMuted,
                                    height: 1.45,
                                  ),
                            ),
                          ),
                        ],
                      );

                      final aside = _SidePanel(
                        note: sideNote,
                        actions: sideActions,
                      );

                      if (stacked) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            lead,
                            if (sideNote != null || sideActions.isNotEmpty) ...[
                              const SizedBox(height: 22),
                              aside,
                            ],
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: lead),
                          if (sideNote != null || sideActions.isNotEmpty) ...[
                            const SizedBox(width: 24),
                            Expanded(flex: 4, child: aside),
                          ],
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                for (final section in sections) ...[
                  _SectionCard(section: section),
                  const SizedBox(height: 18),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ContentSection {
  const ContentSection({
    required this.title,
    required this.body,
    this.points = const [],
    this.highlight,
  });

  final String title;
  final String body;
  final List<String> points;
  final String? highlight;
}

class ContentAction {
  const ContentAction({
    required this.label,
    required this.path,
    this.filled = false,
  });

  final String label;
  final String path;
  final bool filled;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});

  final ContentSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(
            section.body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.48),
          ),
          if (section.highlight != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.publicAccentSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                section.highlight!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.publicText,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
              ),
            ),
          ],
          if (section.points.isNotEmpty) ...[
            const SizedBox(height: 18),
            for (final point in section.points) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Icon(
                      Icons.circle,
                      size: 8,
                      color: AppTheme.publicAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      point,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({required this.note, required this.actions});

  final String? note;
  final List<ContentAction> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (note != null) ...[
            Text(
              note!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.publicMuted,
                    height: 1.45,
                  ),
            ),
            if (actions.isNotEmpty) const SizedBox(height: 18),
          ],
          for (int i = 0; i < actions.length; i++) ...[
            actions[i].filled
                ? FilledButton(
                    onPressed: () => context.go(actions[i].path),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: AppTheme.publicText,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(actions[i].label),
                  )
                : TextButton(
                    onPressed: () => context.go(actions[i].path),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: AppTheme.publicText,
                      backgroundColor: AppTheme.publicSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppTheme.publicLine),
                      ),
                    ),
                    child: Text(actions[i].label),
                  ),
            if (i != actions.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

PublicContentScreen buildHowItWorksScreen() => const PublicContentScreen(
      eyebrow: 'How it works',
      title: 'One operating flow from first contact to collected revenue',
      subtitle:
          'Orchestrate keeps lead generation, outreach, follow-through, meetings, billing, and records close enough that the work stays continuous.',
      sideNote:
          'This is built for businesses that want outbound work carried as an operating discipline, not scattered across separate tools and loose follow-up.',
      sideActions: [
        ContentAction(label: 'Create account', path: '/join', filled: true),
        ContentAction(label: 'View pricing', path: '/pricing'),
      ],
      sections: [
        ContentSection(
          title: 'Start with market direction',
          body:
              'The work begins by defining where Orchestrate should operate and how broad the initial market should be. Coverage, sequence, and pace all become clearer when the direction is set first.',
          points: [
            'Market scope stays attached to the account from the beginning.',
            'The same operating trail can widen later without rebuilding the flow.',
            'Client setup is framed around decisions, not technical configuration.',
          ],
        ),
        ContentSection(
          title: 'Carry outreach with control',
          body:
              'Lead sourcing, outreach execution, replies, and meeting movement stay inside the same operating rhythm. The point is not just sending messages. It is carrying momentum until the work becomes real conversation.',
          highlight:
              'Outreach is not complete when the first message goes out. The follow-through is part of the service.',
        ),
        ContentSection(
          title: 'Keep revenue operations attached',
          body:
              'When conversations turn into real business, invoices, agreements, reminders, statements, and records can stay connected to the same account trail. That is where continuity starts to matter most.',
          points: [
            'Client visibility stays separate from operator execution.',
            'Billing posture remains visible instead of drifting later.',
            'Records stay attached to the account rather than being rebuilt elsewhere.',
          ],
        ),
      ],
    );

PublicContentScreen buildTermsScreen() => const PublicContentScreen(
      eyebrow: 'Legal',
      title: 'Terms of use',
      subtitle:
          'These terms govern access to the public site, client surfaces, operator surfaces, and services provided through Orchestrate.',
      sideNote:
          'This page sets the general service boundaries. For billing, privacy, and deliverability posture, use the related pages in the legal section.',
      sideActions: [
        ContentAction(label: 'Privacy policy', path: '/privacy'),
        ContentAction(label: 'Service agreement', path: '/legal/service-agreement'),
      ],
      sections: [
        ContentSection(
          title: 'Use of the service',
          body:
              'Use of Orchestrate depends on lawful use, truthful account information, payment of agreed fees, and compliance with public and contractual service boundaries.',
        ),
        ContentSection(
          title: 'Account posture',
          body:
              'Operator access may be provisioned directly and may be limited, suspended, or revoked where misuse, non-payment, legal risk, or policy breaches create operational concern. Client access may be limited to the visibility and control surfaces appropriate to the service relationship.',
        ),
        ContentSection(
          title: 'Service boundaries',
          body:
              'Orchestrate provides structured support for outreach, follow-up, meetings, billing administration, reminders, records, and related operating functions. It does not guarantee recipient response, booked meetings, customer payment, or uninterrupted third-party system behavior.',
          highlight:
              'External systems, recipient behavior, data quality, and client responsiveness remain variables outside direct control.',
        ),
        ContentSection(
          title: 'Suspension and termination',
          body:
              'Service may be suspended or ended where use creates abuse risk, legal exposure, payment failure, harassment, fraud, sender-identity misuse, or other conduct inconsistent with the purpose of the system.',
        ),
      ],
    );

PublicContentScreen buildPrivacyScreen() => const PublicContentScreen(
      eyebrow: 'Legal',
      title: 'Privacy policy',
      subtitle:
          'Orchestrate handles business contact information, communication records, billing records, and service metadata in order to operate responsibly.',
      sideNote:
          'Privacy here is part of the operating model, not a detached afterthought. The service depends on handling records with discipline.',
      sideActions: [
        ContentAction(label: 'Terms of use', path: '/terms'),
        ContentAction(label: 'Deliverability notice', path: '/legal/deliverability'),
      ],
      sections: [
        ContentSection(
          title: 'Information handled',
          body:
              'The system may handle business names, contact details, lead and customer records, communication history, payment status information, agreements, statements, and basic usage logs needed for service continuity and account security.',
        ),
        ContentSection(
          title: 'Purpose of collection and use',
          body:
              'Information is used to operate outreach, preserve records, support billing workflows, maintain account access, provide client visibility, protect the service, and respond to support, contractual, or legal needs.',
        ),
        ContentSection(
          title: 'Sharing posture',
          body:
              'Information is not shared casually. It may be shared with service providers, infrastructure vendors, payment providers, deliverability vendors, or legal authorities where reasonably necessary to operate the service, enforce agreements, process payments, or meet legal obligations.',
        ),
        ContentSection(
          title: 'Retention and control',
          body:
              'Records may be retained for operational continuity, legal compliance, financial accountability, dispute handling, and service history. Deletion requests may be limited where retention is reasonably required for those purposes.',
        ),
      ],
    );

PublicContentScreen buildBillingPolicyScreen() => const PublicContentScreen(
      eyebrow: 'Legal',
      title: 'Billing policy',
      subtitle:
          'This page explains how service charges, invoicing, reminders, subscriptions, and payment responsibility are handled through Orchestrate.',
      sections: [
        ContentSection(
          title: 'Service plans',
          body:
              'Orchestrate is structured around Opportunity and Revenue. Revenue includes Opportunity and extends the service into billing administration, reminders, statements, agreements, and payment-accountability surfaces.',
        ),
        ContentSection(
          title: 'Billing cycle and charges',
          body:
              'Charges may be one-time, recurring, milestone-based, or contract-based depending on the service relationship. Applicable charges, due dates, and billing cadence should be stated in the governing service agreement or accepted proposal.',
        ),
        ContentSection(
          title: 'Late payment posture',
          body:
              'Late payment may result in reminder escalation, service pause, restricted access, or withholding of operating functions until the account is brought current.',
          highlight:
              'Billing support does not erase the client’s own responsibility for payment obligations owed to Orchestrate.',
        ),
        ContentSection(
          title: 'Client billing support',
          body:
              'Where the Revenue plan includes billing support for the client’s customers, Orchestrate acts as a structured operating intermediary. It does not become the underlying contractual counterparty between the client and the customer unless expressly agreed in writing.',
        ),
      ],
    );

PublicContentScreen buildRefundPolicyScreen() => const PublicContentScreen(
      eyebrow: 'Legal',
      title: 'Refund policy',
      subtitle:
          'Refund posture remains tied to actual service conditions rather than vague promises or unsupported expectations.',
      sections: [
        ContentSection(
          title: 'General rule',
          body:
              'Fees already earned for completed service, delivered work, used subscription periods, configured accounts, or executed outreach are generally non-refundable unless otherwise stated in writing.',
        ),
        ContentSection(
          title: 'When review may be appropriate',
          body:
              'Refund review may be appropriate where duplicate charges, proven billing error, material non-delivery of agreed setup work, or other clear account mistakes are established.',
        ),
        ContentSection(
          title: 'What is not a refund trigger by itself',
          body:
              'Low reply rates, low meeting conversion, customer non-payment, spam filtering, slow internal client response, or recipient silence are not by themselves grounds for refund because they depend on variables outside direct control.',
        ),
      ],
    );

PublicContentScreen buildAcceptableUseScreen() => const PublicContentScreen(
      eyebrow: 'Legal',
      title: 'Acceptable use',
      subtitle:
          'Orchestrate is meant for legitimate business communication, billing administration, records, and accountable client service operations.',
      sections: [
        ContentSection(
          title: 'Prohibited behavior',
          body:
              'Use of the service for fraud, harassment, impersonation, unlawful targeting, deceptive billing, abuse of sender identity, delivery of malware, or unlawful data handling is prohibited.',
        ),
        ContentSection(
          title: 'Sender and deliverability discipline',
          body:
              'Users must not use Orchestrate in ways that create spam risk, impersonation exposure, reputation abuse, or harmful message patterns that threaten sender standing or recipient trust.',
        ),
        ContentSection(
          title: 'Data and access discipline',
          body:
              'Account access, customer information, and communication trails must be handled with care. Attempts to bypass account boundaries, misuse records, or exploit the system for unauthorized activity are prohibited.',
        ),
      ],
    );

PublicContentScreen buildServiceAgreementScreen() => const PublicContentScreen(
      eyebrow: 'Legal',
      title: 'Service agreement',
      subtitle:
          'The service agreement governs the practical business relationship between Orchestrate and the client where work is being carried under paid service terms.',
      sections: [
        ContentSection(
          title: 'Scope and delivery',
          body:
              'The agreement should identify the service plan, market scope, billing cadence, responsibilities, and any custom operating terms attached to the engagement.',
        ),
        ContentSection(
          title: 'Client responsibility',
          body:
              'The client remains responsible for accurate information, lawful use, timely approvals where needed, and payment of agreed charges.',
        ),
        ContentSection(
          title: 'Operating responsibility',
          body:
              'Orchestrate is responsible for carrying the agreed operating work with reasonable discipline, maintaining records, and preserving service continuity within the boundaries of the service relationship.',
        ),
      ],
    );

PublicContentScreen buildDeliverabilityScreen() => const PublicContentScreen(
      eyebrow: 'Legal',
      title: 'Deliverability notice',
      subtitle:
          'Email delivery and sender reputation depend on factors that include infrastructure, message quality, sending behavior, and recipient-side filtering outside direct control.',
      sections: [
        ContentSection(
          title: 'No guarantee of inbox placement',
          body:
              'Orchestrate does not guarantee inbox placement, open rate, reply rate, meeting conversion, or continued access to any third-party email infrastructure.',
        ),
        ContentSection(
          title: 'Shared responsibility',
          body:
              'Deliverability depends partly on client domain posture, sender reputation, message discipline, list quality, and recipient systems. Those variables remain shared operational responsibilities even when Orchestrate is executing the work.',
        ),
        ContentSection(
          title: 'Why this matters',
          body:
              'Outbound work only stays effective when sender reputation and message discipline are treated seriously. Deliverability is not a decorative metric. It is part of responsible execution.',
        ),
      ],
    );
