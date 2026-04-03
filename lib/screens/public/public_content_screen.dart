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
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  fontSize: 46,
                                ),
                          ),
                          const SizedBox(height: 16),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: Text(
                              subtitle,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppTheme.publicMuted,
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
            style: Theme.of(context).textTheme.bodyLarge,
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
                      style: Theme.of(context).textTheme.bodyLarge,
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
                  ),
            ),
            if (actions.isNotEmpty) const SizedBox(height: 18),
          ],
          for (final action in actions) ...[
            action.filled
                ? FilledButton(
                    onPressed: () => context.go(action.path),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: AppTheme.publicText,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(action.label),
                  )
                : OutlinedButton(
                    onPressed: () => context.go(action.path),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: AppTheme.publicText,
                      side: const BorderSide(color: AppTheme.publicLine),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(action.label),
                  ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

PublicContentScreen buildHowItWorksScreen() => const PublicContentScreen(
      eyebrow: 'How it works',
      title: 'One system from first outreach to paid work',
      subtitle:
          'Orchestrate keeps lead generation, outreach, follow-up, meetings, billing, and records connected instead of splitting them across separate tools and habits.',
      sideNote:
          'The point is simple: the work that starts the conversation should stay connected to the work that closes it.',
      sideActions: [
        ContentAction(label: 'View pricing', path: '/pricing', filled: true),
        ContentAction(label: 'Create account', path: '/client/create-account'),
      ],
      sections: [
        ContentSection(
          title: 'Lead generation starts the pipeline',
          body:
              'Businesses define the target, the market, and the kind of accounts they want to reach. From there, lead sourcing stays attached to the rest of the work instead of being treated as a separate spreadsheet exercise.',
          points: [
            'Target lists are built around the service and market.',
            'Leads move with visible status instead of disappearing into loose notes.',
            'The same record can continue through outreach, meetings, and billing.',
          ],
        ),
        ContentSection(
          title: 'Outreach and follow-up stay controlled',
          body:
              'Campaigns, replies, and meeting booking stay inside the same operating system. The point is not just to send messages. It is to keep momentum visible until real conversations turn into meetings.',
          highlight:
              'Outreach is not finished when the first message is sent. The follow-through is part of the product.',
        ),
        ContentSection(
          title: 'Billing does not get pushed off to the side',
          body:
              'When the work moves forward, invoices, reminders, payment tracking, statements, and records can stay tied to the same client relationship. That keeps the business trail intact after meetings are booked.',
          points: [
            'Client access stays separate from operator access.',
            'Deliverability stays visible as an operating responsibility.',
            'Statements, receipts, agreements, and history remain attached to the account.',
          ],
        ),
      ],
    );

PublicContentScreen buildPricingScreen() => const PublicContentScreen(
      eyebrow: 'Pricing',
      title: 'Two plans, clear scope',
      subtitle:
          'Orchestrate is structured around two service levels so businesses can choose whether they need outbound execution only or outbound execution plus billing support.',
      sideNote:
          'Revenue includes Opportunity by design. Billing is part of the operating system, not an extra add-on.',
      sideActions: [
        ContentAction(label: 'Create account', path: '/client/create-account', filled: true),
        ContentAction(label: 'Contact', path: '/contact'),
      ],
      sections: [
        ContentSection(
          title: 'Opportunity',
          body: 'For businesses that want leads, outreach, follow-up, and meetings handled with structure.',
          points: [
            'Lead sourcing and targeting',
            'Outbound outreach execution',
            'Follow-up handling',
            'Reply management',
            'Meeting booking',
          ],
        ),
        ContentSection(
          title: 'Revenue',
          body:
              'For businesses that want the outbound work plus the billing, reminder, payment, and record layer that follows service delivery.',
          points: [
            'Everything included in Opportunity',
            'Invoice generation and payment tracking',
            'Reminder scheduling and follow-through',
            'Statements and account records',
            'Agreements and billing support tied to service delivery',
          ],
          highlight:
              'Revenue is the fuller operating model because it carries the work from outreach into actual money movement and accountability.',
        ),
      ],
    );

PublicContentScreen buildContactScreen() => const PublicContentScreen(
      eyebrow: 'Contact',
      title: 'Talk through fit, scope, and next steps',
      subtitle:
          'Use this page to talk through service fit, scope, pricing, or onboarding before you move forward.',
      sideNote: 'Ready to move forward? Create your account and continue from there.',
      sideActions: [
        ContentAction(label: 'Create account', path: '/client/create-account', filled: true),
        ContentAction(label: 'Sign in', path: '/client/login'),
      ],
      sections: [
        ContentSection(
          title: 'When to use this page',
          body:
              'Use contact when you want a direct business conversation before onboarding. This page is for clarifying fit, scope, pricing, and next steps.',
          points: [
            'You want to confirm whether the service fits your business.',
            'You want to understand Opportunity versus Revenue.',
            'You want to talk through billing cadence, reminders, or statements.',
            'You want to understand how onboarding and activation will work.',
          ],
        ),
        ContentSection(
          title: 'Client entry stays open',
          body:
              'Businesses can create a client account directly. Registration starts a controlled progression into verification, onboarding, qualification, and activation.',
          highlight:
              'Account creation is the beginning of the pipeline, not unrestricted access to the whole system.',
        ),
        ContentSection(
          title: 'Operator access stays controlled',
          body:
              'Operator access is not part of public self-serve sign-up. It is provisioned deliberately because the operator side carries execution responsibility across outreach, billing, deliverability, and records.',
        ),
      ],
    );

PublicContentScreen buildTermsScreen() => const PublicContentScreen(
      eyebrow: 'Legal framework',
      title: 'Terms of use',
      subtitle:
          'These terms govern access to the public site, operator workspace, client access surfaces, and related services provided through Orchestrate.',
      sections: [
        ContentSection(
          title: 'Use of the service',
          body:
              'Use of Orchestrate is conditioned on lawful use, truthful account information, payment of agreed fees, and compliance with the service boundaries presented publicly or contractually.',
        ),
        ContentSection(
          title: 'Account posture',
          body:
              'Operator access may be provisioned directly and may be limited, suspended, or revoked where misuse, non-payment, risk, or policy breaches create operational or legal concern. Client access may be limited to review functions appropriate to the service relationship.',
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
              'Service may be suspended or ended where use creates abuse risk, legal exposure, security issues, payment failure, misuse of sender identity, harassment, fraud, or other misuse inconsistent with the purpose of the system.',
        ),
      ],
    );

PublicContentScreen buildPrivacyScreen() => const PublicContentScreen(
      eyebrow: 'Legal framework',
      title: 'Privacy policy',
      subtitle:
          'Orchestrate handles business contact information, communication records, billing records, and service metadata in order to operate the service responsibly.',
      sections: [
        ContentSection(
          title: 'Information handled',
          body:
              'The system may handle business names, contact details, lead and customer records, communication history, payment status information, agreements, statements, and basic usage logs needed for account security and service continuity.',
        ),
        ContentSection(
          title: 'Purpose of collection and use',
          body:
              'Information is used to operate outreach, preserve records, support billing workflows, maintain account access, provide client visibility, protect the service, and respond to support, contractual, or legal needs.',
        ),
        ContentSection(
          title: 'Sharing posture',
          body:
              'Information is not shared casually. It may be shared with service providers, infrastructure vendors, payment providers, deliverability vendors, or legal authorities where necessary to operate the system, enforce agreements, process payments, or meet legal obligations.',
        ),
        ContentSection(
          title: 'Retention and control',
          body:
              'Records may be retained for operational continuity, legal compliance, financial accountability, dispute handling, and service history. Deletion requests may be limited where retention is reasonably required for these purposes.',
        ),
      ],
    );

PublicContentScreen buildBillingPolicyScreen() => const PublicContentScreen(
      eyebrow: 'Legal framework',
      title: 'Billing and subscription policy',
      subtitle:
          'This policy explains how service tiers, invoicing, subscriptions, reminders, and payment responsibilities are handled through Orchestrate.',
      sections: [
        ContentSection(
          title: 'Service tiers',
          body:
              'Orchestrate is structured around Opportunity and Revenue. Revenue includes Opportunity and extends the service into billing administration, reminders, statements, agreements, and payment accountability surfaces.',
        ),
        ContentSection(
          title: 'Billing cycle and charges',
          body:
              'Charges may be one-time, recurring, milestone-based, or contract-based depending on the service relationship. Applicable charges, due dates, and billing cadence should be stated in the governing service agreement or accepted proposal.',
        ),
        ContentSection(
          title: 'Late payment posture',
          body:
              'Late payment may result in reminder escalation, service pause, restricted access, or withholding of certain operating functions until account status is brought current.',
          highlight:
              'Billing administration support does not erase the client’s own responsibility for payment obligations owed to Orchestrate.',
        ),
        ContentSection(
          title: 'Client billing support',
          body:
              'Where the Revenue tier includes billing support for the client’s customers, Orchestrate acts as a structured operating intermediary. It does not become the underlying contractual counterparty between the client and the customer unless expressly agreed in writing.',
        ),
      ],
    );

PublicContentScreen buildRefundPolicyScreen() => const PublicContentScreen(
      eyebrow: 'Legal framework',
      title: 'Refund policy',
      subtitle:
          'Refund posture should remain clear, restrained, and tied to actual service conditions rather than vague promises.',
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
              'Low reply rates, low meeting conversion, customer non-payment, spam filtering, slow internal client response, or recipient silence are not by themselves grounds for refund because they depend on variables outside direct platform control.',
        ),
      ],
    );

PublicContentScreen buildAcceptableUseScreen() => const PublicContentScreen(
      eyebrow: 'Legal framework',
      title: 'Acceptable use policy',
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
              'Users may not deliberately degrade sender reputation, rotate identities deceptively, conceal origin, or use the platform in a manner likely to create systemic abuse or blacklisting risk.',
        ),
        ContentSection(
          title: 'Operational protection',
          body:
              'Access may be restricted where behavior threatens infrastructure stability, payment integrity, legal compliance, account security, or the integrity of other clients using the system.',
        ),
      ],
    );

PublicContentScreen buildServiceAgreementScreen() => const PublicContentScreen(
      eyebrow: 'Legal framework',
      title: 'Service agreement',
      subtitle:
          'The service agreement defines the actual operating relationship between Orchestrate and the client once scope is accepted.',
      sections: [
        ContentSection(
          title: 'What the agreement should establish',
          body:
              'The agreement should state service scope, tier, billing cadence, deliverables, account visibility, communication posture, reminder handling, records responsibility, and any limits or exclusions that shape the working relationship.',
        ),
        ContentSection(
          title: 'Why it matters here',
          body:
              'Because Orchestrate can carry both opportunity creation and billing administration, the service agreement is the place where responsibilities stop being implied and become explicit.',
          highlight:
              'This page does not replace a signed agreement. It marks that the signed agreement is structurally required.',
        ),
      ],
    );

PublicContentScreen buildDeliverabilityScreen() => const PublicContentScreen(
      eyebrow: 'Legal framework',
      title: 'Deliverability notice',
      subtitle:
          'Deliverability is treated as a working responsibility, but no honest system can promise universal inbox placement, responses, or conversions.',
      sections: [
        ContentSection(
          title: 'What deliverability depends on',
          body:
              'Inbox placement and outbound performance depend on sender domain condition, mailbox health, recipient filtering systems, message quality, targeting discipline, list quality, complaint behavior, and broader third-party infrastructure conditions.',
        ),
        ContentSection(
          title: 'What Orchestrate does',
          body:
              'The service may support sender setup, visibility into mailbox condition, sending posture, and operational monitoring intended to improve stability and accountability.',
        ),
        ContentSection(
          title: 'What cannot be promised',
          body:
              'No representation is made that a message will reach the inbox, receive a reply, convert to a meeting, or result in customer payment in every case.',
          highlight:
              'Deliverability work improves posture. It does not remove the reality of external systems and recipient choice.',
        ),
      ],
    );
