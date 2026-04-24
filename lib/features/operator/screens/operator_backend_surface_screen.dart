import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/network/api_client.dart';
import 'package:orchestrate_app/core/widgets/backend_surface_screen.dart';

enum OperatorBackendSurface {
  system,
  organizations,
  leads,
  jobs,
  workers,
  queues,
  aiGovernance,
  sources,
  reachability,
  qualification,
  signals,
  emails,
  billing,
  documents,
  analytics,
  activity,
}

class OperatorBackendSurfaceScreen extends StatelessWidget {
  const OperatorBackendSurfaceScreen({super.key, required this.surface});

  final OperatorBackendSurface surface;

  @override
  Widget build(BuildContext context) {
    final spec = _spec(surface);
    return BackendSurfaceScreen(
      eyebrow: spec.eyebrow,
      title: spec.title,
      subtitle: spec.subtitle,
      surface: ApiSurface.operator,
      dark: true,
      sections: spec.sections,
    );
  }

  _OperatorSpec _spec(OperatorBackendSurface surface) {
    switch (surface) {
      case OperatorBackendSurface.system:
        return const _OperatorSpec(
          eyebrow: 'System',
          title: 'Health, command, and control overview',
          subtitle:
              'System truth is read from health, control, command, and auth context capabilities.',
          sections: [
            BackendSurfaceSection(
              title: 'Runtime health',
              description: 'Service health and resolved operator context.',
              endpoints: [
                BackendEndpoint('/health', label: 'health'),
                BackendEndpoint('/auth/context', label: 'auth context'),
              ],
              emptyLabel: 'No health data is visible.',
            ),
            BackendSurfaceSection(
              title: 'Control overview',
              description: 'Control and command summaries.',
              endpoints: [
                BackendEndpoint('/control/overview', label: 'control'),
                BackendEndpoint('/operator/command/overview',
                    label: 'command overview'),
              ],
              emptyLabel: 'No control overview is visible.',
            ),
          ],
        );
      case OperatorBackendSurface.organizations:
        return const _OperatorSpec(
          eyebrow: 'Identity',
          title: 'Organizations and users',
          subtitle: 'Tenant and membership surfaces remain system-owned.',
          sections: [
            BackendSurfaceSection(
              title: 'Organizations',
              description: 'Organizations visible to the operator context.',
              endpoints: [
                BackendEndpoint('/organizations', label: 'organizations')
              ],
              emptyLabel: 'No organizations are visible.',
            ),
            BackendSurfaceSection(
              title: 'Users data gap',
              description:
                  'The system exposes user creation and membership creation actions, but no user list capability is present.',
              endpoints: [BackendEndpoint('/users', label: 'users')],
              emptyLabel: 'No user list data is available.',
              gapLabel: 'Missing users list capability',
            ),
          ],
        );
      case OperatorBackendSurface.leads:
        return const _OperatorSpec(
          eyebrow: 'Leads',
          title: 'Lead records, reachability, and qualification cues',
          subtitle:
              'Lead truth comes from system lead records; entity-specific enrichment capabilities require an entity id.',
          sections: [
            BackendSurfaceSection(
              title: 'Lead records',
              description: 'Leads visible to operator context.',
              endpoints: [BackendEndpoint('/leads', label: 'leads')],
              emptyLabel: 'No leads are visible.',
            ),
            BackendSurfaceSection(
              title: 'Entity-specific gap',
              description:
                  'Reachability and qualification capabilities are entity-specific and need selected lead/entity ids before they can be queried.',
              endpoints: [],
              emptyLabel:
                  'Select a lead detail workflow before calling /reachability/entities/:entityId or /qualification/entities/:entityId/evaluate.',
            ),
          ],
        );
      case OperatorBackendSurface.jobs:
        return const _OperatorSpec(
          eyebrow: 'Execution',
          title: 'Jobs and execution controls',
          subtitle:
              'The system exposes execution actions, but no general jobs list capability is present right now.',
          sections: [
            BackendSurfaceSection(
              title: 'Execution summary',
              description:
                  'Command overview is the current readable execution summary.',
              endpoints: [
                BackendEndpoint('/operator/command/overview',
                    label: 'command overview'),
                BackendEndpoint('/control/overview', label: 'control overview'),
              ],
              emptyLabel: 'No execution summary is visible.',
            ),
            BackendSurfaceSection(
              title: 'Jobs list gap',
              description:
                  'Run and dispatch capabilities exist as action controls; a read capability is not exposed.',
              endpoints: [BackendEndpoint('/execution/jobs', label: 'jobs')],
              emptyLabel: 'No jobs list capability data is available.',
              gapLabel: 'Missing jobs list capability',
            ),
          ],
        );
      case OperatorBackendSurface.workers:
        return const _OperatorSpec(
          eyebrow: 'Execution',
          title: 'Workers',
          subtitle:
              'Worker registration exists in system runtime, but the right now has no worker registry capability.',
          sections: [
            BackendSurfaceSection(
              title: 'Worker registry gap',
              description:
                  'Registered workers are system runtime truth, but no read capability is exposed to the frontend.',
              endpoints: [BackendEndpoint('/workers', label: 'workers')],
              emptyLabel: 'No worker registry capability data is available.',
              gapLabel: 'Missing workers capability',
            ),
          ],
        );
      case OperatorBackendSurface.queues:
        return const _OperatorSpec(
          eyebrow: 'Execution',
          title: 'Queues and dispatch pressure',
          subtitle:
              'Queue actions are available through execution capabilities; readable queue snapshots are not exposed as a dedicated capability.',
          sections: [
            BackendSurfaceSection(
              title: 'Queue summary',
              description:
                  'Use command and control summaries as readable queue proxies.',
              endpoints: [
                BackendEndpoint('/operator/command/overview',
                    label: 'command overview'),
                BackendEndpoint('/control/overview', label: 'control overview'),
              ],
              emptyLabel: 'No queue summary is visible.',
            ),
            BackendSurfaceSection(
              title: 'Queue list gap',
              description: 'No read capability is present.',
              endpoints: [
                BackendEndpoint('/execution/queues', label: 'queues')
              ],
              emptyLabel: 'No queue list capability data is available.',
              gapLabel: 'Missing queues capability',
            ),
          ],
        );
      case OperatorBackendSurface.aiGovernance:
        return const _OperatorSpec(
          eyebrow: 'AI governance',
          title: 'AI trust, readiness, authority, and enforcement boundary',
          subtitle:
              'AI governance is shown from available AI status capabilities; decision and enforcement logs are reported as gaps when no read capability exists.',
          sections: [
            BackendSurfaceSection(
              title: 'Trust and readiness',
              description: 'Readable AI capability and readiness capabilities.',
              endpoints: [
                BackendEndpoint('/ai/capabilities/status',
                    label: 'capabilities'),
                BackendEndpoint('/ai/trust/status', label: 'trust'),
                BackendEndpoint('/ai/trust/readiness', label: 'readiness'),
                BackendEndpoint('/ai/trust/evaluation-sets',
                    label: 'evaluation sets'),
              ],
              emptyLabel: 'No AI trust status is visible.',
            ),
            BackendSurfaceSection(
              title: 'Decision and enforcement gaps',
              description:
                  'The system has durable AI decision/enforcement models and action authority capabilities, but no readable decision or enforcement log capability is exposed.',
              endpoints: [
                BackendEndpoint('/ai/authority/snapshot',
                    label: 'authority snapshot'),
                BackendEndpoint('/ai/governance/decisions',
                    label: 'decision log'),
                BackendEndpoint('/ai/governance/enforcements',
                    label: 'enforcement log'),
              ],
              emptyLabel: 'No AI governance log data is available.',
              gapLabel: 'Missing AI governance read capabilities',
            ),
          ],
        );
      case OperatorBackendSurface.sources:
        return const _OperatorSpec(
          eyebrow: 'Sourcing',
          title: 'Providers, sources, and source runs',
          subtitle:
              'Provider status is globally readable. Source planning and runs require a campaign id.',
          sections: [
            BackendSurfaceSection(
              title: 'Provider status',
              description: 'Configured sourcing provider posture.',
              endpoints: [
                BackendEndpoint('/providers/status', label: 'providers')
              ],
              emptyLabel: 'No provider status is visible.',
            ),
            BackendSurfaceSection(
              title: 'Campaign source run gap',
              description:
                  'Source plans, discovery, provider usage, and source runs are campaign-specific and need campaign selection.',
              endpoints: [],
              emptyLabel:
                  'Use a campaign detail workflow before calling /sources/campaigns/:campaignId/runs or /providers/usage/campaigns/:campaignId.',
            ),
          ],
        );
      case OperatorBackendSurface.reachability:
        return const _OperatorSpec(
          eyebrow: 'Qualification',
          title: 'Reachability',
          subtitle: 'Reachability is entity-specific in the system.',
          sections: [
            BackendSurfaceSection(
              title: 'Reachability data boundary',
              description:
                  'The system exposes /reachability/entities/:entityId, but no aggregate reachability list capability.',
              endpoints: [
                BackendEndpoint('/reachability/entities',
                    label: 'reachability list')
              ],
              emptyLabel:
                  'No aggregate reachability capability data is available.',
              gapLabel: 'Missing aggregate reachability capability',
            ),
          ],
        );
      case OperatorBackendSurface.qualification:
        return const _OperatorSpec(
          eyebrow: 'Qualification',
          title: 'Qualification',
          subtitle:
              'Qualification reads are campaign-specific or entity-specific.',
          sections: [
            BackendSurfaceSection(
              title: 'Qualification data boundary',
              description:
                  'The system exposes campaign and entity qualification capabilities, but no aggregate qualification list.',
              endpoints: [
                BackendEndpoint('/qualification', label: 'qualification list')
              ],
              emptyLabel:
                  'No aggregate qualification capability data is available.',
              gapLabel: 'Missing aggregate qualification capability',
            ),
          ],
        );
      case OperatorBackendSurface.signals:
        return const _OperatorSpec(
          eyebrow: 'Adaptation',
          title: 'Signals and adaptation',
          subtitle:
              'Signals and adaptation are campaign-specific system capabilities.',
          sections: [
            BackendSurfaceSection(
              title: 'Campaign signal boundary',
              description:
                  'Signal detection, signal reads, and adaptation runs require a campaign id right now.',
              endpoints: [BackendEndpoint('/signals', label: 'signals list')],
              emptyLabel: 'No aggregate signals capability data is available.',
              gapLabel: 'Missing aggregate signals capability',
            ),
          ],
        );
      case OperatorBackendSurface.emails:
        return const _OperatorSpec(
          eyebrow: 'Emails',
          title: 'Email dispatches and inbound mail',
          subtitle:
              'Dispatch history is readable. Inbound mail and templates are action capabilities unless a list capability is present.',
          sections: [
            BackendSurfaceSection(
              title: 'Dispatches',
              description: 'Outbound email dispatch records.',
              endpoints: [
                BackendEndpoint('/emails/dispatches', label: 'dispatches')
              ],
              emptyLabel: 'No email dispatches are visible.',
            ),
            BackendSurfaceSection(
              title: 'Templates',
              description: 'Email and document templates where configured.',
              endpoints: [BackendEndpoint('/templates', label: 'templates')],
              emptyLabel: 'No templates are visible.',
            ),
          ],
        );
      case OperatorBackendSurface.billing:
        return const _OperatorSpec(
          eyebrow: 'Revenue',
          title: 'Billing, subscriptions, invoices, and receipts',
          subtitle:
              'Revenue records are read from billing and subscription capabilities.',
          sections: [
            BackendSurfaceSection(
              title: 'Billing overview',
              description: 'Revenue and billing summary.',
              endpoints: [
                BackendEndpoint('/billing/overview', label: 'billing overview'),
                BackendEndpoint('/subscriptions', label: 'subscriptions'),
              ],
              emptyLabel: 'No billing overview is visible.',
            ),
            BackendSurfaceSection(
              title: 'Invoices and receipts',
              description: 'Financial records exposed by billing.',
              endpoints: [
                BackendEndpoint('/billing/invoices', label: 'billing invoices'),
                BackendEndpoint('/billing/receipts', label: 'receipts'),
                BackendEndpoint('/invoices', label: 'invoice records'),
              ],
              emptyLabel: 'No invoices or receipts are visible.',
            ),
          ],
        );
      case OperatorBackendSurface.documents:
        return const _OperatorSpec(
          eyebrow: 'Records',
          title: 'Documents, agreements, statements, reminders, and templates',
          subtitle:
              'Formal document records are kept separate from execution views.',
          sections: [
            BackendSurfaceSection(
              title: 'Formal records',
              description: 'Agreements, statements, reminders, and templates.',
              endpoints: [
                BackendEndpoint('/agreements', label: 'agreements'),
                BackendEndpoint('/statements', label: 'statements'),
                BackendEndpoint('/reminders', label: 'reminders'),
                BackendEndpoint('/templates', label: 'templates'),
              ],
              emptyLabel: 'No document records are visible.',
            ),
          ],
        );
      case OperatorBackendSurface.analytics:
        return const _OperatorSpec(
          eyebrow: 'Analytics',
          title: 'Analytics',
          subtitle: 'Analytics capabilities are campaign-specific right now.',
          sections: [
            BackendSurfaceSection(
              title: 'Analytics boundary',
              description:
                  'Source-yield and conversion analytics require a campaign id. No aggregate operator analytics capability is exposed.',
              endpoints: [
                BackendEndpoint('/analytics', label: 'analytics list')
              ],
              emptyLabel:
                  'No aggregate analytics capability data is available.',
              gapLabel: 'Missing aggregate analytics capability',
            ),
          ],
        );
      case OperatorBackendSurface.activity:
        return const _OperatorSpec(
          eyebrow: 'Records',
          title: 'Activity, audit, and system records',
          subtitle:
              'Records overview is available, but there is no dedicated audit/activity event stream capability right now.',
          sections: [
            BackendSurfaceSection(
              title: 'Records overview',
              description: 'Operator records summary and notifications.',
              endpoints: [
                BackendEndpoint('/operator/records/overview',
                    label: 'records overview'),
                BackendEndpoint('/notifications/alerts', label: 'alerts'),
              ],
              emptyLabel: 'No records overview is visible.',
            ),
            BackendSurfaceSection(
              title: 'Audit stream gap',
              description:
                  'No read capability or read capability is exposed for durable activity stream browsing.',
              endpoints: [
                BackendEndpoint('/audit', label: 'audit'),
                BackendEndpoint('/activity', label: 'activity'),
              ],
              emptyLabel:
                  'No audit/activity stream capability data is available.',
              gapLabel: 'Missing audit/activity stream capabilities',
            ),
          ],
        );
    }
  }
}

class _OperatorSpec {
  const _OperatorSpec({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.sections,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final List<BackendSurfaceSection> sections;
}
