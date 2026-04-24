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
          eyebrow: 'Client outreach',
          title: 'Outreach queue, sent mail, and follow-up truth',
          subtitle:
              'This client-safe view reads dispatch and reply capabilities directly. If queued or follow-up data is not exposed separately, the gap is shown instead of inferred.',
          sections: [
            BackendSurfaceSection(
              title: 'Dispatches and sent work',
              description:
                  'Client-visible outbound dispatches from the system.',
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
              title: 'Capability boundary',
              description:
                  'Separate client-safe queue and follow-up list capabilities are not exposed right now.',
              endpoints: [],
              emptyLabel:
                  'Queue and follow-up stages are available to operators through execution controls, but no dedicated client list capability is exposed.',
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
              description:
                  'Operator billing receipts exist, but client-safe receipt browsing is not enabled for this account yet.',
              endpoints: [],
              emptyLabel: 'Client receipt browsing is not enabled.',
              gapLabel: 'Client-safe receipts not enabled',
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
              'Support intake is an action capability. Existing support conversations are not exposed as a client list capability right now.',
          sections: [
            BackendSurfaceSection(
              title: 'Support capability boundary',
              description:
                  'Support intake and session replies are available. A client support thread list is not enabled yet.',
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
              'Settings surfaces account profile, setup state, and authorization truth from system capabilities.',
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
                  'The system supports accepting representation authorization; no separate read-only authorization capability is exposed.',
              endpoints: [],
              emptyLabel:
                  'Representation authorization is controlled by action capability and reflected in profile or campaign data when system returns it.',
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
              title: 'AI governance data boundary',
              description:
                  'The system exposes AI governance to operators. No dedicated client-safe AI decision summary capability is present.',
              endpoints: [],
              emptyLabel:
                  'Client-safe AI governance should remain summarized from campaign state until a dedicated capability exists.',
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
