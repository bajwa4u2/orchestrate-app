import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/network/api_client.dart';
import 'package:orchestrate_app/core/widgets/backend_surface_screen.dart';

enum ClientBackendSurface {
  outreach,
  replies,
  invoices,
  receipts,
  agreements,
  statements,
  reminders,
  notifications,
  support,
  settings,
  trust,
}

class ClientBackendSurfaceScreen extends StatelessWidget {
  const ClientBackendSurfaceScreen({super.key, required this.surface});

  final ClientBackendSurface surface;

  @override
  Widget build(BuildContext context) {
    final spec = _spec(surface);
    return BackendSurfaceScreen(
      eyebrow: spec.eyebrow,
      title: spec.title,
      subtitle: spec.subtitle,
      surface: ApiSurface.client,
      sections: spec.sections,
    );
  }

  _ClientSpec _spec(ClientBackendSurface surface) {
    switch (surface) {
      case ClientBackendSurface.outreach:
        return const _ClientSpec(
          eyebrow: 'Outreach',
          title: 'Outreach, sent messages, and follow-up',
          subtitle:
              'This view shows outreach records your account can see: sent messages, replies, and follow-up progress when available.',
          sections: [
            BackendSurfaceSection(
              title: 'Dispatches and sent work',
              description: 'Sent outreach visible for this account.',
              endpoints: [
                BackendEndpoint('/client/email-dispatches',
                    label: 'dispatches'),
              ],
              emptyLabel:
                  'No client-visible email dispatches are available yet.',
            ),
            BackendSurfaceSection(
              title: 'Replies as outcome evidence',
              description:
                  'Replies are shown as real outcomes connected to outreach.',
              endpoints: [
                BackendEndpoint('/replies',
                    query: {'limit': '25'}, label: 'replies'),
              ],
              emptyLabel: 'No replies are visible yet.',
            ),
            BackendSurfaceSection(
              title: 'Follow-up availability',
              description:
                  'Separate queued and follow-up lists are not available for your account yet.',
              endpoints: [],
              emptyLabel:
                  'Follow-up records will appear here after your service starts and records are available for your account.',
            ),
          ],
        );
      case ClientBackendSurface.replies:
        return const _ClientSpec(
          eyebrow: 'Client replies',
          title: 'Replies and conversation outcomes',
          subtitle:
              'Client-visible replies come from system reply records only.',
          sections: [
            BackendSurfaceSection(
              title: 'Reply records',
              description: 'Inbound replies visible to this client.',
              endpoints: [
                BackendEndpoint('/replies',
                    query: {'limit': '50'}, label: 'replies'),
              ],
              emptyLabel: 'No replies are visible yet.',
            ),
          ],
        );
      case ClientBackendSurface.invoices:
        return const _ClientSpec(
          eyebrow: 'Client billing',
          title: 'Invoices and account billing record',
          subtitle:
              'Invoices are read from the client portal billing capabilities.',
          sections: [
            BackendSurfaceSection(
              title: 'Invoices',
              description: 'Client-visible invoices.',
              endpoints: [
                BackendEndpoint('/client/invoices', label: 'invoices')
              ],
              emptyLabel: 'No invoices are visible yet.',
            ),
            BackendSurfaceSection(
              title: 'Billing overview',
              description: 'Service account billing standing where available.',
              endpoints: [
                BackendEndpoint('/client/billing/overview',
                    label: 'billing overview'),
                BackendEndpoint('/billing/subscription', label: 'subscription'),
              ],
              emptyLabel: 'No billing overview is visible yet.',
            ),
          ],
        );
      case ClientBackendSurface.receipts:
        return const _ClientSpec(
          eyebrow: 'Client billing',
          title: 'Receipts',
          subtitle:
              'Receipts are shown only if the system exposes client-authorized receipt data.',
          sections: [
            BackendSurfaceSection(
              title: 'Receipt status',
              description: 'Receipts are not available for this account yet.',
              endpoints: [],
              emptyLabel: 'Client receipt browsing is not available.',
              gapLabel: 'Receipts not available',
            ),
          ],
        );
      case ClientBackendSurface.agreements:
        return const _ClientSpec(
          eyebrow: 'Client records',
          title: 'Agreements',
          subtitle: 'Client agreements come from system agreement records.',
          sections: [
            BackendSurfaceSection(
              title: 'Agreements',
              description: 'Client-visible agreement records.',
              endpoints: [
                BackendEndpoint('/client/agreements', label: 'agreements')
              ],
              emptyLabel: 'No agreements are visible yet.',
            ),
          ],
        );
      case ClientBackendSurface.statements:
        return const _ClientSpec(
          eyebrow: 'Client records',
          title: 'Statements',
          subtitle: 'Statements are read from client-visible system records.',
          sections: [
            BackendSurfaceSection(
              title: 'Statements',
              description: 'Client-visible statements.',
              endpoints: [
                BackendEndpoint('/client/statements', label: 'statements')
              ],
              emptyLabel: 'No statements are visible yet.',
            ),
          ],
        );
      case ClientBackendSurface.reminders:
        return const _ClientSpec(
          eyebrow: 'Client records',
          title: 'Reminders',
          subtitle: 'Reminder records are shown when exposed to this client.',
          sections: [
            BackendSurfaceSection(
              title: 'Reminders',
              description: 'Client-visible reminders.',
              endpoints: [
                BackendEndpoint('/client/reminders', label: 'reminders')
              ],
              emptyLabel: 'No reminders are visible yet.',
            ),
          ],
        );
      case ClientBackendSurface.notifications:
        return const _ClientSpec(
          eyebrow: 'Client notifications',
          title: 'Notifications',
          subtitle:
              'Notifications are read from the client portal notification capability.',
          sections: [
            BackendSurfaceSection(
              title: 'Notifications',
              description: 'Client-visible notices and alerts.',
              endpoints: [
                BackendEndpoint('/client/notifications', label: 'notifications')
              ],
              emptyLabel: 'No notifications are visible yet.',
            ),
          ],
        );
      case ClientBackendSurface.support:
        return const _ClientSpec(
          eyebrow: 'Client support',
          title: 'Support and account help',
          subtitle:
              'Use support to ask setup, billing, campaign, or service questions. Conversation lists will appear here when available.',
          sections: [
            BackendSurfaceSection(
              title: 'Support service availability',
              description:
                  'Support is available from the workspace. No support thread list is available for this account yet.',
              endpoints: [],
              emptyLabel:
                  'Use the support action in this workspace to start or continue a support conversation.',
            ),
          ],
        );
      case ClientBackendSurface.settings:
        return const _ClientSpec(
          eyebrow: 'Client settings',
          title: 'Account, setup, and representation authorization',
          subtitle:
              'Settings shows account profile, setup state, and authorization records when available.',
          sections: [
            BackendSurfaceSection(
              title: 'Client profile and setup',
              description: 'Account profile and setup state.',
              endpoints: [
                BackendEndpoint('/clients/me/profile', label: 'profile'),
                BackendEndpoint('/clients/me/setup', label: 'setup'),
              ],
              emptyLabel: 'No client profile or setup data is visible.',
            ),
            BackendSurfaceSection(
              title: 'Representation authorization',
              description:
                  'Representation authorization is captured during campaign activation and reflected when available.',
              endpoints: [],
              emptyLabel:
                  'Representation authorization will appear after your campaign requires or records it.',
            ),
          ],
        );
      case ClientBackendSurface.trust:
        return const _ClientSpec(
          eyebrow: 'Client trust',
          title: 'Client-safe AI activity and trust summary',
          subtitle:
              'Client trust uses campaign, execution, and notification data. Raw AI decisions are kept operator-only unless system exposes client-safe summaries.',
          sections: [
            BackendSurfaceSection(
              title: 'Campaign and execution signals',
              description: 'Client-safe campaign and operational view.',
              endpoints: [
                BackendEndpoint('/client/campaign/overview',
                    label: 'campaign overview'),
                BackendEndpoint('/client/campaign-profile/operational-view',
                    label: 'operational view'),
                BackendEndpoint('/client/notifications',
                    label: 'notifications'),
              ],
              emptyLabel: 'No AI trust summary data is visible yet.',
            ),
            BackendSurfaceSection(
              title: 'AI summary availability',
              description:
                  'Detailed AI governance stays operator-only. Client-safe summaries appear here when available.',
              endpoints: [],
              emptyLabel:
                  'AI trust details will appear after your service has available client-safe records.',
            ),
          ],
        );
    }
  }
}

class _ClientSpec {
  const _ClientSpec({
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
