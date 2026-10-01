import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/theme/ob.dart';
import 'package:orchestrate_app/core/ui/ob_widgets.dart';

/// THE PUBLIC READING PAGE, IN DIRECTION B (DD-26).
///
/// Every legal page and every remaining explainer is built from this one
/// template, so the whole public estate reads as one product: paper, a serif
/// title, a readable column, and the next step beside it. The old dark
/// "visual chapters" are no longer drawn here; they belonged to the retired
/// look and made each page half one design and half another.
class PublicContentScreen extends StatelessWidget {
  const PublicContentScreen({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.sections,
    this.sideNote,
    this.sideActions = const [],
    this.visualChapter,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final List<ContentSection> sections;
  final String? sideNote;
  final List<ContentAction> sideActions;

  /// Kept for the pages that still pass one; not drawn (see above).
  final Widget? visualChapter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final phone = c.maxWidth < 760;
      final wide = c.maxWidth >= 1040;
      final head = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow.toUpperCase(), style: Ob.eyebrow()),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ObHeadline(title, size: phone ? 34 : 48),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Text(subtitle, style: Ob.body(phone ? 16.5 : 18)),
          ),
        ],
      );
      final article = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < sections.length; i++)
            _SectionBlock(section: sections[i], first: i == 0),
        ],
      );
      final side = (sideNote == null && sideActions.isEmpty)
          ? null
          : _SidePanel(note: sideNote, actions: sideActions);
      return Padding(
        padding: EdgeInsets.symmetric(vertical: phone ? 28 : 56),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            head,
            SizedBox(height: phone ? 26 : 40),
            if (wide && side != null)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: article,
                  ),
                ),
                const SizedBox(width: 56),
                SizedBox(width: 340, child: side),
              ])
            else ...[
              Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: article,
                ),
              ),
              if (side != null) ...[const SizedBox(height: 28), side],
            ],
          ],
        ),
      );
    });
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({required this.section, required this.first});
  final ContentSection section;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: first ? 0 : 26, bottom: 26),
      decoration: BoxDecoration(
        border: first ? null : const Border(top: BorderSide(color: Ob.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.title, style: Ob.name(23)),
          const SizedBox(height: 10),
          SelectableText(section.body, style: Ob.body(16.5)),
          if (section.points.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final p in section.points)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10, right: 12),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: Ob.ink, shape: BoxShape.circle),
                  ),
                  Expanded(child: Text(p, style: Ob.body(16))),
                ]),
              ),
          ],
          if (section.highlight != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Ob.card,
                borderRadius: BorderRadius.circular(Ob.radiusCard),
              ),
              child: Text(section.highlight!,
                  style: Ob.body(15.5, color: Ob.ink)),
            ),
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
    final filled = actions.where((a) => a.filled).toList();
    final links = actions.where((a) => !a.filled).toList();
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Ob.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Ob.lift,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (note != null) ...[
            Text(note!, style: Ob.body(15, color: Ob.ink)),
            if (actions.isNotEmpty) const SizedBox(height: 18),
          ],
          for (final a in filled) ...[
            FilledButton(
                onPressed: () => context.go(a.path), child: Text(a.label)),
            const SizedBox(height: 10),
          ],
          if (links.isNotEmpty) ...[
            if (filled.isNotEmpty) const SizedBox(height: 4),
            Text('RELATED', style: Ob.eyebrow()),
            const SizedBox(height: 6),
            for (final a in links)
              InkWell(
                onTap: () => context.go(a.path),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(children: [
                    Expanded(child: Text(a.label, style: Ob.strong(15))),
                    const Icon(Icons.arrow_forward, size: 16, color: Ob.inkMuted),
                  ]),
                ),
              ),
          ],
        ],
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

// ── Policies (DD-26) ────────────────────────────────────────────────
//
// Rewritten 2026-10-01 in plain words. Every commitment, limit and right in
// the previous wording is kept at the same strength; nothing new is promised.
// The billing policy is corrected: Orchestrate is one plan, billed monthly or
// yearly, not the retired "Opportunity" and "Revenue" tiers.

PublicContentScreen buildTermsScreen() => const PublicContentScreen(
      eyebrow: 'Policy',
      title: 'Terms of use',
      subtitle:
          'These terms cover the public site, your workspace, and everything '
          'Orchestrate does for your business.',
      sideActions: [
        ContentAction(label: 'All policies', path: '/legal'),
        ContentAction(label: 'Acceptable use', path: '/legal/acceptable-use'),
        ContentAction(label: 'Billing', path: '/legal/billing'),
      ],
      sections: [
        ContentSection(
          title: 'Using Orchestrate',
          body:
              'You may use Orchestrate lawfully, with truthful account '
              'information, paying the fees you agreed to, and within the '
              'limits described on this site or in your agreement with us.',
        ),
        ContentSection(
          title: 'Your access',
          body:
              'We may limit, suspend or end access where there is misuse, '
              'non-payment, risk, or a breach of our policies that creates an '
              'operational or legal concern. Some people in a workspace may be '
              'given review-only access, depending on their role.',
        ),
        ContentSection(
          title: 'What Orchestrate does, and what it cannot promise',
          body:
              'Orchestrate finds businesses, writes and follows up on your '
              'behalf, hands meetings to you, and helps with agreements, '
              'invoices, reminders and records. It does not guarantee that '
              'anyone replies, books a meeting or pays, or that other '
              'companies\' systems are always available.',
          highlight:
              'Other systems, how recipients behave, the quality of data, and '
              'how quickly you respond are outside our direct control.',
        ),
        ContentSection(
          title: 'Suspension and ending service',
          body:
              'Service may be suspended or ended where use creates abuse risk, '
              'legal exposure or a security problem, where payment fails, or '
              'where it involves misuse of a sender\'s identity, harassment, '
              'fraud or other misuse that goes against what Orchestrate is for.',
        ),
      ],
    );

PublicContentScreen buildPrivacyScreen() => const PublicContentScreen(
      eyebrow: 'Policy',
      title: 'Privacy',
      subtitle:
          'To run Orchestrate we handle business contact details, the record '
          'of what was sent and agreed, billing records, technical logs, and '
          'a strictly limited part of your mailbox.',
      sideActions: [
        ContentAction(label: 'Mailbox access', path: '/legal/mailbox-access'),
        ContentAction(label: 'AI usage', path: '/legal/ai-usage'),
        ContentAction(label: 'Credential handling', path: '/legal/credentials'),
        ContentAction(label: 'All policies', path: '/legal'),
      ],
      sections: [
        ContentSection(
          title: 'What we handle',
          body:
              'Business names, contact details, customer records, the history '
              'of messages, payment status, agreements and statements, and the '
              'basic usage logs needed to keep accounts secure and the service '
              'running.',
        ),
        ContentSection(
          title: 'Your mailbox',
          body:
              'Orchestrate does not read your inbox. It looks only at the '
              'headers of incoming mail, and fetches a message\'s body only '
              'when that message is a reply to a note Orchestrate sent. '
              'Anything else is not stored, sorted, shown, or given to an AI '
              'system. The Mailbox access policy sets out exactly how.',
          highlight:
              'Headers first. A body is fetched only for a reply to a note '
              'Orchestrate sent.',
        ),
        ContentSection(
          title: 'Passwords and keys',
          body:
              'Mailbox passwords, sign-in tokens and signing keys are held in '
              'an encrypted vault. They never appear in any answer the system '
              'gives, in logs, in diagnostics, or in your browser. The '
              'Credential handling policy explains how they are stored and '
              'changed.',
        ),
        ContentSection(
          title: 'AI',
          body:
              'AI works only with notes Orchestrate wrote and replies to them. '
              'Other mailbox content never reaches an AI system. AI helps do '
              'the work; it never acts on its own as if it were a person. The '
              'AI usage policy sets the limits.',
        ),
        ContentSection(
          title: 'Why we use it',
          body:
              'To do the work you asked for, keep the record, support billing, '
              'keep your account working, show you what is happening, protect '
              'the service, and answer support, contractual or legal needs.',
        ),
        ContentSection(
          title: 'Who we share it with',
          body:
              'We do not share it casually. We may share it with the companies '
              'that run our infrastructure (database, vault, and the email '
              'providers you choose yourself), with payment providers, or with '
              'legal authorities, where that is needed to run the service, '
              'enforce agreements, take payment or meet the law.',
        ),
        ContentSection(
          title: 'How long we keep it',
          body:
              'Records may be kept for running the service, legal compliance, '
              'financial accountability, disputes, and service history. You '
              'can delete your account as described on the Account deletion '
              'page; some records may still be kept where there is a good '
              'reason, for the purposes listed here.',
        ),
      ],
    );

PublicContentScreen buildMailboxAccessPolicyScreen() =>
    const PublicContentScreen(
      eyebrow: 'Policy',
      title: 'Mailbox access',
      subtitle:
          'Orchestrate does not read your inbox. This sets out exactly when '
          'mail is read, kept, sorted, or given to AI.',
      sideActions: [
        ContentAction(label: 'Reply monitoring', path: '/legal/reply-monitoring'),
        ContentAction(label: 'Privacy', path: '/legal/privacy'),
        ContentAction(label: 'Trust', path: '/trust'),
      ],
      sections: [
        ContentSection(
          title: 'Only replies to Orchestrate\'s own notes',
          body:
              'Incoming mail is handled only when it can be tied to a note '
              'Orchestrate sent: its reply headers point to that note, or it '
              'carries the reference Orchestrate adds to every note it sends. '
              'Mail without one of these is not handled at all.',
        ),
        ContentSection(
          title: 'Headers first, and the body only for a match',
          body:
              'Orchestrate first reads only the envelope and a few headers '
              '(sender, recipient, subject, and the reply references). It asks '
              'for a message\'s body only after the message is matched to a '
              'note it sent.',
          highlight:
              'A message that does not match is never opened, kept, or '
              'processed.',
        ),
        ContentSection(
          title: 'Nothing from before you connected',
          body:
              'When you connect a mailbox, Orchestrate starts from that moment. '
              'Mail that was already there is not looked at, unless an '
              'operator deliberately runs a limited look-back, which is never '
              'offered as a one-click default.',
        ),
        ContentSection(
          title: 'Google and Microsoft',
          body:
              'When you connect Google Workspace or Microsoft 365, Orchestrate '
              'asks only for permission to send. If it ever reads replies '
              'there in future, it will be limited to the conversations it '
              'started, never broad access to your mailbox.',
        ),
        ContentSection(
          title: 'Your sent folder',
          body:
              'Orchestrate does not copy your sent folder. Only notes '
              'Orchestrate wrote are kept.',
        ),
        ContentSection(
          title: 'Shared mailboxes',
          body:
              'We recommend an address used only for this. If you connect a '
              'personal or shared mailbox, every rule above still applies and '
              'unrelated mail is not kept; a separate address simply keeps '
              'things clear.',
        ),
      ],
    );

PublicContentScreen buildAiUsagePolicyScreen() => const PublicContentScreen(
      eyebrow: 'Policy',
      title: 'AI usage',
      subtitle:
          'What AI does in Orchestrate, what it never does, and how that line '
          'is held.',
      sideActions: [
        ContentAction(label: 'Mailbox access', path: '/legal/mailbox-access'),
        ContentAction(label: 'Privacy', path: '/legal/privacy'),
        ContentAction(label: 'Trust', path: '/trust'),
      ],
      sections: [
        ContentSection(
          title: 'What AI helps with',
          body:
              'Judging whether a business fits what you sell, writing a note '
              'to a specific person, understanding what a reply to one of '
              'those notes means, and analysis for our own operators. Every '
              'use of AI is tied to a recorded decision.',
        ),
        ContentSection(
          title: 'What AI never does',
          body:
              'It never creates accounts on its own, pretends to be you where '
              'a person\'s judgement is needed, reads unrelated mail, opens a '
              'message that is not a reply to a note Orchestrate sent, or '
              'sends anything that has not passed Orchestrate\'s checks.',
          highlight:
              'AI is held to the same rule as everything else: only notes '
              'Orchestrate sent, and the replies to them.',
        ),
        ContentSection(
          title: 'A record of every AI-assisted note',
          body:
              'Each note written or helped by AI keeps a record of the '
              'decision, the model used, and what it was given. You can ask '
              'for that record for anything AI touched in your workspace.',
        ),
        ContentSection(
          title: 'You set the limits',
          body:
              'Your permission, your business details, your sending address '
              'and who must not be contacted are yours to set. AI works inside '
              'them and never overrides them. When a reply asks to stop, or '
              'shows a change of mind, AI-assisted sending to that person '
              'stops.',
        ),
        ContentSection(
          title: 'No pretending to be a person',
          body:
              'Orchestrate does not claim that an AI-assisted note was written '
              'by an individual. Notes are sent on behalf of your business, '
              'under the permission you gave, and identify the sender as the '
              'law on commercial messages requires.',
        ),
      ],
    );

PublicContentScreen buildCredentialHandlingScreen() =>
    const PublicContentScreen(
      eyebrow: 'Policy',
      title: 'Credential handling',
      subtitle:
          'Mailbox passwords, sign-in tokens and keys never appear in any '
          'answer the system gives, in logs, in diagnostics, in your browser, '
          'or unencrypted in our database. This is how they are kept.',
      sideActions: [
        ContentAction(label: 'Retention and deletion', path: '/legal/retention'),
        ContentAction(label: 'Trust', path: '/trust'),
      ],
      sections: [
        ContentSection(
          title: 'Where they are kept',
          body:
              'In an encrypted vault: either encrypted in our database with '
              'AES-256, with the key held apart from the data, or in a '
              'dedicated HashiCorp Vault. A test-only store exists for '
              'development, and the live service refuses to start if it is '
              'ever selected.',
        ),
        ContentSection(
          title: 'One way in',
          body:
              'Every read, change or removal goes through a single service. It '
              'records what was done, by whom, for which business and mailbox, '
              'and whether it worked, but never the secret itself.',
        ),
        ContentSection(
          title: 'What is protected this way',
          body:
              'Google and Microsoft sign-in tokens, mail server passwords, the '
              'signing keys Orchestrate creates for your domain, and the '
              'position Orchestrate has reached in your inbox. Our main '
              'database holds only references and harmless details such as '
              'the permissions granted and when they were last refreshed.',
        ),
        ContentSection(
          title: 'Changing and removing them',
          body:
              'They can be replaced in place, for example when you reconnect a '
              'mailbox. Removing one deletes it from the vault and keeps only '
              'the record that it was removed. Where the provider allows it, '
              'Orchestrate also revokes the access with them.',
        ),
        ContentSection(
          title: 'Where they never go',
          body:
              'Never to delivery vendors, analytics or logging services, and '
              'never into error messages. Records of activity hold only '
              'details such as the server, port and outcome: never a '
              'password, token, or the contents of a message.',
          highlight:
              'Activity records cannot hold secrets: the code that writes them '
              'has no access to them.',
        ),
      ],
    );

PublicContentScreen buildReplyMonitoringDisclosureScreen() =>
    const PublicContentScreen(
      eyebrow: 'Policy',
      title: 'Reply monitoring',
      subtitle:
          'When you let Orchestrate watch for replies, this is exactly what it '
          'does and does not do.',
      sideActions: [
        ContentAction(label: 'Mailbox access', path: '/legal/mailbox-access'),
        ContentAction(label: 'Suppression and opt-out', path: '/legal/suppression'),
      ],
      sections: [
        ContentSection(
          title: 'Only when you connect it',
          body:
              'Replies are watched only where you have connected incoming '
              'mail as well as sending. Today that is your own mail server '
              '(IMAP); with Google or Microsoft, Orchestrate only sends, so '
              'replies reach your inbox without Orchestrate seeing them.',
        ),
        ContentSection(
          title: 'How a reply is recognised',
          body:
              'Each incoming message is checked against the notes Orchestrate '
              'sent, using the reply headers or the reference Orchestrate adds '
              'to every note, which survives even when other systems strip '
              'the usual headers.',
        ),
        ContentSection(
          title: 'When it matches',
          body:
              'The reply is kept with the customer and the note it answers, '
              'any follow-ups still waiting for that person are cancelled, and '
              'it appears in your workspace. AI may read it to understand '
              'what the person wants.',
        ),
        ContentSection(
          title: 'When it does not match',
          body:
              'It stays in your mailbox untouched. Orchestrate does not '
              'download it, keep it, sort it, or give it to AI. At most, a '
              'count of unmatched messages may be recorded, with no content.',
        ),
        ContentSection(
          title: 'Never twice',
          body:
              'Each message is recognised by its own unique ID and Orchestrate '
              'only moves forward through your inbox, so the same message is '
              'never taken in twice, even after a restart or a reconnect.',
        ),
        ContentSection(
          title: 'A reply stops the follow-ups',
          body:
              'Once someone replies, every follow-up still waiting for them is '
              'cancelled, so Orchestrate never keeps writing to a person who '
              'has already answered.',
        ),
      ],
    );

PublicContentScreen buildSuppressionPolicyScreen() => const PublicContentScreen(
      eyebrow: 'Policy',
      title: 'Suppression and opt-out',
      subtitle:
          'Anyone can stop hearing from a business that uses Orchestrate. Two '
          'things make sure of it: a do-not-contact list, and replies that ask '
          'to stop.',
      sideActions: [
        ContentAction(label: 'Reply monitoring', path: '/legal/reply-monitoring'),
        ContentAction(label: 'Abuse', path: '/legal/abuse'),
        ContentAction(label: 'Trust', path: '/trust'),
      ],
      sections: [
        ContentSection(
          title: 'The do-not-contact list',
          body:
              'Each business has its own list, which can hold single addresses '
              'or whole domains. Entries come from people asking to stop, from '
              'our operators, or from lists you import. Every first note and '
              'every follow-up is checked against it; a match stops the send '
              'and marks that person as not to be contacted.',
        ),
        ContentSection(
          title: 'A reply that says stop',
          body:
              'When a reply asks to stop, the person is added to the list '
              'automatically, with the reason recorded. Nothing more is sent '
              'to them unless an operator deliberately removes the entry.',
        ),
        ContentSection(
          title: 'Four reasons, one effect',
          body:
              'An entry records why: the person unsubscribed, their address no '
              'longer exists, they reported a message as spam, or an operator '
              'blocked them. Every reason stops sending in the same way.',
        ),
        ContentSection(
          title: 'No way around it',
          body:
              'No button, setting or tool lets any send skip the check. It is '
              'built into the first note, every follow-up, and direct email.',
          highlight: 'Nothing is ever sent to someone on the list.',
        ),
        ContentSection(
          title: 'Where you see it',
          body:
              'Our operators see every entry with its reason and date. In your '
              'workspace, a person on the list shows clearly as not to be '
              'contacted.',
        ),
      ],
    );

PublicContentScreen buildProviderResponsibilityScreen() =>
    const PublicContentScreen(
      eyebrow: 'Policy',
      title: 'Provider boundaries',
      subtitle:
          'Who is responsible for what when Orchestrate sends through your '
          'email provider.',
      sideActions: [
        ContentAction(label: 'Deliverability', path: '/legal/deliverability'),
        ContentAction(label: 'Check your domain', path: '/diagnostics'),
      ],
      sections: [
        ContentSection(
          title: 'Your domain comes first',
          body:
              'What identifies you is your own domain and its records. The '
              'email provider underneath (Google, Microsoft, or your own mail '
              'server) can change without changing who you are.',
        ),
        ContentSection(
          title: 'Google Workspace and Microsoft 365',
          body:
              'You approve Orchestrate on the provider\'s own screen, and it '
              'asks only to send. The provider still carries the mail and '
              'applies its own limits and rules. If the provider ends that '
              'permission, Orchestrate asks you to reconnect rather than '
              'trying again with it.',
        ),
        ContentSection(
          title: 'Your own mail server',
          body:
              'You give the server details and from-address. Orchestrate '
              'checks them before saving, keeps the password in the vault, '
              'creates a signing key for your domain, and signs every note '
              'before handing it to your server. How that server delivers '
              'mail stays between you and its provider.',
        ),
        ContentSection(
          title: 'Reading replies from your own server',
          body:
              'If you connect incoming mail, Orchestrate reads headers first, '
              'opens only replies to its own notes, and keeps its place in the '
              'vault. A few servers do not report their position; they still '
              'work, with one wider header check on first connect.',
        ),
        ContentSection(
          title: 'Domain records',
          body:
              'You publish the records with whoever hosts your domain. '
              'Orchestrate checks them live, shows the history, re-checks '
              'records that are not found yet on its own, and holds sending '
              'until they are in place. The domain host is yours; the checks '
              'and the decision to send are ours.',
        ),
        ContentSection(
          title: 'How much Orchestrate sends',
          body:
              'Orchestrate decides how freely to send from what it can check: '
              'your domain records, the health of your mailbox, and recent '
              'delivery problems. Whether a note lands in an inbox is still up '
              'to the recipient\'s systems, for us as for anyone.',
        ),
      ],
    );

PublicContentScreen buildAbusePolicyScreen() => const PublicContentScreen(
      eyebrow: 'Policy',
      title: 'Abuse and complaints',
      subtitle:
          'Orchestrate is for genuine business communication. Abuse puts '
          'everyone at risk: the recipients, other businesses using '
          'Orchestrate, and the providers that carry the mail. This is how it '
          'is handled.',
      sideActions: [
        ContentAction(label: 'Acceptable use', path: '/legal/acceptable-use'),
        ContentAction(label: 'Suppression and opt-out', path: '/legal/suppression'),
      ],
      sections: [
        ContentSection(
          title: 'Not allowed',
          body:
              'Sending in bulk without a business relationship or the consent '
              'the law requires, fraudulent or misleading content, pretending '
              'to be someone else, harassing recipients, deliberately getting '
              'around providers\' controls, and sending malware or phishing.',
        ),
        ContentSection(
          title: 'Complaints',
          body:
              'Spam reports, bounces that signal abuse, provider feedback and '
              'reports to support all go to our operators. A confirmed '
              'complaint adds the person to the do-not-contact list, may change '
              'how mail is sent, and starts a review of the account.',
        ),
        ContentSection(
          title: 'What can happen to an account',
          body:
              'Repeated complaints, too many failed deliveries, or evidence of '
              'a breach can pause sending, disconnect a mailbox, suspend the '
              'account or end the service. When an account is suspended, the '
              'reason is recorded in its history.',
        ),
        ContentSection(
          title: 'Reporting abuse',
          body:
              'Anyone can report suspected abuse to support@orchestrateops.com. '
              'We check the report against the record of which account sent '
              'what, to whom, and with whose permission, and act as described '
              'above.',
        ),
      ],
    );

PublicContentScreen buildRetentionPolicyScreen() => const PublicContentScreen(
      eyebrow: 'Policy',
      title: 'Retention and deletion',
      subtitle:
          'What we keep, why, and how it is deleted. Records are kept to run '
          'the service, meet the law, and keep an honest history.',
      sideActions: [
        ContentAction(label: 'Account deletion', path: '/account-deletion'),
        ContentAction(label: 'Privacy', path: '/legal/privacy'),
      ],
      sections: [
        ContentSection(
          title: 'Working records',
          body:
              'Your account, workspace, business details, permission given, '
              'mailboxes, domains, notes sent, replies, meetings and invoices '
              'are kept while the account is active, and afterwards for '
              'disputes, financial accountability and an auditable history. '
              'No fixed period after the account ends is set yet.',
        ),
        ContentSection(
          title: 'Mailbox passwords and keys',
          body:
              'Kept while the mailbox is connected. When you disconnect, they '
              'are deleted from the vault; only the record that it happened '
              'remains, never the secret.',
        ),
        ContentSection(
          title: 'Activity records',
          body:
              'Records of activity, such as a mailbox connected or a reply '
              'received, are kept for as long as the account exists or as long '
              'as the law requires for security and audit, whichever is '
              'longer. They never contain message contents or secrets.',
        ),
        ContentSection(
          title: 'Replies',
          body:
              'Replies to Orchestrate\'s notes are kept with the customer they '
              'belong to. Other mail is never kept in the first place, so '
              'there is nothing to delete.',
        ),
        ContentSection(
          title: 'Deleting your account',
          body:
              'Follow the Account deletion page. Your sign-in, profile and '
              'access to the workspace are deleted. The records listed there '
              'are kept for billing, fraud prevention, activity history, legal '
              'compliance, disputes, or unpaid balances.',
        ),
      ],
    );

PublicContentScreen buildBillingPolicyScreen() => const PublicContentScreen(
      eyebrow: 'Policy',
      title: 'Billing',
      subtitle:
          'How paying for Orchestrate works.',
      sideActions: [
        ContentAction(label: 'Pricing', path: '/pricing'),
        ContentAction(label: 'Refunds', path: '/legal/refunds'),
      ],
      sections: [
        ContentSection(
          title: 'One plan',
          body:
              'Orchestrate is one plan for your whole business, paid monthly '
              'or yearly at the prices on the Pricing page. Setting up your '
              'workspace is free. Unusually heavy use, and any setup help we '
              'agree to provide, are priced separately.',
        ),
        ContentSection(
          title: 'When you are charged',
          body:
              'A monthly plan is billed each month and a yearly plan each '
              'year. Anything charged differently, such as setup help, follows '
              'what is stated in your agreement or accepted proposal.',
        ),
        ContentSection(
          title: 'Late payment',
          body:
              'If a payment is late, you may get reminders, and some or all of '
              'the service may be paused or limited until it is paid.',
          highlight:
              'Orchestrate helping with your own billing does not change what '
              'you owe Orchestrate.',
        ),
        ContentSection(
          title: 'Billing your own customers',
          body:
              'Where Orchestrate prepares agreements and invoices for your '
              'customers, it does so on your behalf. It does not become a party '
              'to the agreement between you and your customer unless that is '
              'agreed in writing.',
        ),
      ],
    );

PublicContentScreen buildRefundPolicyScreen() => const PublicContentScreen(
      eyebrow: 'Policy',
      title: 'Refunds',
      subtitle:
          'When a refund is possible, and when it is not.',
      sideActions: [
        ContentAction(label: 'Billing', path: '/legal/billing'),
        ContentAction(label: 'Contact', path: '/contact'),
      ],
      sections: [
        ContentSection(
          title: 'The general rule',
          body:
              'Fees for service already provided, work delivered, time on a '
              'plan already used, or notes already sent are not refunded, '
              'unless we have said otherwise in writing.',
        ),
        ContentSection(
          title: 'When we will look at a refund',
          body:
              'Where you were charged twice, a billing error is shown, setup '
              'work we agreed to was not delivered, or there is another clear '
              'mistake on your account.',
        ),
        ContentSection(
          title: 'Not reasons on their own',
          body:
              'Few replies, few meetings, customers who do not pay, spam '
              'filters, slow responses, or people who do not answer are not '
              'reasons for a refund by themselves: they depend on things no '
              'one fully controls.',
        ),
      ],
    );

PublicContentScreen buildAcceptableUseScreen() => const PublicContentScreen(
      eyebrow: 'Policy',
      title: 'Acceptable use',
      subtitle:
          'Orchestrate is for genuine business communication and honest '
          'records. It is not for bulk unsolicited sending or for disguising '
          'who is sending.',
      sideActions: [
        ContentAction(label: 'Abuse', path: '/legal/abuse'),
        ContentAction(label: 'Terms of use', path: '/legal/terms'),
      ],
      sections: [
        ContentSection(
          title: 'Not allowed',
          body:
              'Fraud, harassment, pretending to be someone else, unlawful '
              'targeting, misleading billing, misusing a sender\'s identity, '
              'sending malware, or handling data unlawfully.',
        ),
        ContentSection(
          title: 'Sending responsibly',
          body:
              'You may not deliberately damage a sender\'s reputation, switch '
              'identities to deceive, hide who is sending, or use Orchestrate '
              'in a way likely to get senders blocked or blacklisted.',
        ),
        ContentSection(
          title: 'Protecting everyone',
          body:
              'Access may be limited where behaviour threatens the service, '
              'payments, legal compliance, account security, or other '
              'businesses using Orchestrate.',
        ),
      ],
    );

PublicContentScreen buildServiceAgreementScreen() => const PublicContentScreen(
      eyebrow: 'Policy',
      title: 'Service agreement',
      subtitle:
          'The agreement between your business and Orchestrate, and what it '
          'covers.',
      sideActions: [
        ContentAction(label: 'Terms of use', path: '/legal/terms'),
        ContentAction(label: 'Billing', path: '/legal/billing'),
      ],
      sections: [
        ContentSection(
          title: 'What it sets out',
          body:
              'What Orchestrate will do for you, the plan and how often you '
              'pay, what is delivered, what you can see, how Orchestrate writes '
              'on your behalf, how reminders and records are handled, and any '
              'limits or exclusions.',
        ),
        ContentSection(
          title: 'Why it matters',
          body:
              'Orchestrate both finds customers and helps you get paid, so the '
              'agreement is where responsibilities are written down: what '
              'Orchestrate does, what stays yours (your business details and '
              'your sending address), and where the line between them is.',
          highlight:
              'This page does not replace the agreement itself. A signed '
              'agreement is required.',
        ),
      ],
    );

PublicContentScreen buildDeliverabilityScreen() => const PublicContentScreen(
      eyebrow: 'Policy',
      title: 'Deliverability',
      subtitle:
          'We work hard to get your notes delivered. No honest service can '
          'promise every note reaches an inbox, or that anyone replies or buys.',
      sideActions: [
        ContentAction(label: 'Check your domain', path: '/diagnostics'),
        ContentAction(label: 'Provider boundaries', path: '/legal/providers'),
      ],
      sections: [
        ContentSection(
          title: 'What delivery depends on',
          body:
              'The state of your domain and mailbox, the recipient\'s filters, '
              'the quality of the message, who it goes to, how clean the list '
              'is, whether people complain, and the systems of other companies '
              'along the way.',
        ),
        ContentSection(
          title: 'What Orchestrate does',
          body:
              'Checks your domain records live and keeps re-checking them, '
              'connects your mailbox securely with passwords held in a vault, '
              'checks every note before it is sent, and keeps watching your '
              'mailbox\'s health. It improves everything it can control.',
        ),
        ContentSection(
          title: 'What cannot be promised',
          body:
              'That every note reaches the inbox, gets a reply, becomes a '
              'meeting, or leads to payment.',
          highlight:
              'Good practice raises the odds. It does not take away other '
              'companies\' systems or the recipient\'s choice.',
        ),
      ],
    );
