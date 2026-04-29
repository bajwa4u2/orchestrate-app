# Outreach / Lead / Campaign Flow Audit

Date: 2026-04-29

## Scope

Audited the Flutter presentation/control path for public intake, client onboarding/campaign setup, campaign start/restart, client campaign overview, client lead visibility, operator command actions, lead send queueing, failed job visibility, and campaign execution status rendering.

## Frontend-To-Backend Flow Map

| Screen/surface | Repository/service | API endpoint | Backend owner | Status returned/displayed |
| --- | --- | --- | --- | --- |
| Public contact/support | support/public controllers | `/intake/public`, support routes | `IntakeController`, support services | Public session/support state with safe validation/errors |
| Client setup | setup repositories/screens | `/clients/me/setup` | `ClientsController`, `ClientsService` | Saved targeting/profile prerequisites |
| Client campaign screen | `ClientCampaignRepository.fetchCampaignProfile` | `/client/campaign/overview`, `/client/campaign-profile`, `/client/campaign-profile/operational-view`, `/client/leads` | `ClientPortalController`, `ClientCampaignController` | Profile, campaign, execution, mailbox, imports, permissions, lead blocking |
| Client save targeting | `ClientCampaignRepository.updateCampaignProfile` | `PATCH /client/campaign-profile` | `ClientCampaignController` | Saved profile/targeting |
| Client start | `ClientCampaignRepository.startCampaign` | `POST /client/campaign-profile/start` | `ClientCampaignController`, `ClientsService`, `CampaignsService` | Activation state, message, health, metrics, job/campaign IDs |
| Client restart | `ClientCampaignRepository.restartCampaign` | `POST /client/campaign-profile/restart` | `ClientCampaignController`, `ClientsService`, `CampaignsService` | Cooldown/governor/activation state and updated metrics |
| Client leads | `ClientContactsRepository`, campaign repo safe fetch | `/client/leads`, `/clients/me/campaign-overview` | `ClientPortalController`, `ClientsController` | Lead status, qualification, suppression/blocking summaries |
| Operator command | `OperatorRepository.fetchCommandWorkspace` | `/operator/command` | `OperatorController`, `OperatorService` | Campaign pressure, dispatches, failed jobs, blocking, mailbox health |
| Operator campaign activation | `OperatorRepository.activateCampaign` | `POST /campaigns/:id/activate` | `CampaignsController`, `CampaignsService` | Activation request/job state; command refreshes afterward |
| Operator job run | `OperatorRepository.runJob` | `POST /execution/jobs/:jobId/run` | `ExecutionController`, `ExecutionService` | Job run result or typed error with reference ID |
| Operator lead send queue | `OperatorRepository.queueLeadFirstSend/FollowUp` | `POST /execution/leads/:leadId/queue-first-send`, `queue-follow-up` | `ExecutionController`, `ExecutionService` | Queue result or typed error with reference ID |

## State Matrix Rendered

| Backend state | Frontend handling |
| --- | --- |
| Campaign activation `activation_requested`, `activation_in_progress`, `activation_retry_scheduled` | Client campaign state `ACTIVATING`, primary button disabled, activation message visible |
| Campaign activation `activation_completed`, campaign/generation `ACTIVE` | Client campaign state `ACTIVE`, leads action visible |
| Campaign activation `activation_failed` | Client campaign state `ERROR`, actionable error visible |
| Campaign governor paused/stalled/refilling/saturated | Client health chip/card subtitle reflects pause/refill/saturation/stall |
| Lead blocked/suppressed/message-generation metadata | Client campaign metrics can show blocked counts/reasons once returned by backend |
| Failed jobs | Operator command failed jobs list with run action and error text |
| API 401/403/errors | Shared API client throws `ApiException`; updated campaign/command screens show `displayMessage` including request/correlation ID |

## Discrepancies Found

- Operator repository sent `scheduledAt` for queued lead sends, but backend DTO accepts `scheduledFor`; scheduled operator send requests could silently miss intended timing.
- Client campaign screen caught API exceptions and replaced backend messages/request IDs with generic text, making campaign start/restart failures harder to act on.
- Operator command actions (`activate`, `run job`, `dispatch`) could fail without a persistent on-screen error banner.
- Client campaign blocked-lead summary expected lead metadata, but backend did not return it before this pass.

## Fixes Made

- Changed operator lead send queue payloads to send `scheduledFor`.
- Imported typed API errors into the client campaign screen and display backend messages with request/correlation IDs for load, save, start, and restart failures.
- Added an operator command action error banner that preserves typed backend error messages and reference IDs.
- Backend now returns lead metadata/suppression reason, allowing existing client blocking summary code to reflect real lead state.

## Files Changed

- `lib/data/repositories/operator_repository.dart`
- `lib/features/client/screens/campaigns_screen.dart`
- `lib/features/operator/screens/command_screen.dart`
- `docs/OUTREACH_LEAD_CAMPAIGN_FLOW_AUDIT.md`

## UX Verification

- Campaign setup/start screen:
  - loading state: `CircularProgressIndicator`
  - empty/setup state: ready-for-activation copy and targeting prompts
  - error/retry/actionable state: API `displayMessage` now shown with request/correlation ID when provided
  - active/in-progress/error states: `_resolveCampaignState` maps backend activation metadata into `ACTIVATING`, `ACTIVE`, `ERROR`, `READY`
- Operator command:
  - loading state: `FutureBuilder` spinner
  - empty states: command lists render `_EmptyState`
  - error/retry state: command load retry button; action failures now show banner
  - failed jobs: operator sees job error and can rerun from command

## Validation Results

- `flutter analyze` passed: `No issues found!`
- `flutter test` passed: `All tests passed!`

## Remaining Intentional Limitations

- No new product surfaces were invented; this pass hardened existing campaign/client/operator screens and endpoint alignment.
- Manual browser interaction was not launched from this environment. Static validation and widget tests passed, and the campaign start screen no longer swallows backend errors silently.
- Deep visual redesign and new lead detail drilldowns remain out of scope for this repair pass.
