# Store Listing Draft

## App Name

Orchestrate

## Short Description

AI-governed revenue operations workspace for campaigns, outreach, replies, meetings, billing, and records.

## Long Description

Orchestrate helps teams manage revenue operations from a governed workspace. The app gives clients a clear view of setup status, campaign activity, outreach progress, replies, meeting handoffs, billing records, support, and account readiness.

The product is designed around controlled execution: backend state drives the workspace, operational views avoid invented metrics, and AI is presented as a governance and decision-support layer rather than a decorative assistant.

## Key Features

- Client workspace for setup, campaign profile, targeting, and service status.
- Campaign and lead visibility based on backend records.
- Outreach, follow-up, replies, and meeting handoff views where data is available.
- Billing, invoices, receipts, agreements, statements, reminders, and support surfaces.
- Settings and mailbox readiness views for account and deliverability context.
- Operator-oriented system surfaces are available in the broader Orchestrate platform when authorized.

## Privacy And Security Notes

- Orchestrate uses authenticated access for workspace data.
- Operational states are backed by backend endpoints and account permissions.
- Client-facing views should show loading, empty, and error states rather than fabricated activity.
- Release submission still requires final privacy policy URL, data safety answers, and platform-specific disclosures.

## Android Asset Checklist

- `store_assets/android/play-icon-512.png`: generated, 512x512 PNG.
- `store_assets/android/feature-graphic-1024x500.png`: generated, 1024x500 PNG.
- `store_assets/android/screenshots/`: folder created for real screenshots.
- Android launcher icons: generated in `android/app/src/main/res/mipmap-*`.
- Android adaptive icon: configured via `mipmap-anydpi-v26/ic_launcher.xml`.
- Release signing: not configured; current release build uses debug signing.

## iOS Asset Checklist

- `store_assets/ios/app-store-icon-1024.png`: generated, 1024x1024 PNG.
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/`: generated icon set.
- `store_assets/ios/screenshots/`: folder created for real screenshots.
- iOS signing/profiles: not validated on Windows host.

## Windows Asset Checklist

- `windows/runner/resources/app_icon.ico`: generated Windows app icon.
- `store_assets/windows/store-tile-300.png`: generated, 300x300 PNG.
- `store_assets/windows/screenshots/`: folder created for real screenshots.
- MSIX packaging: not configured in `pubspec.yaml`; setup remains before Microsoft Store submission.

## Screenshot Shot List

- Client overview: service standing, setup state, and key workspace navigation.
- Campaign: campaign profile, targeting, status, and meaningful empty/error states if no campaign exists.
- Outreach: queued/sent outreach view backed by real dispatch data.
- Replies: reply list, classification/status, and response context.
- Meetings: calendar/provider readiness, handoff queue, upcoming and past meetings.
- Billing: subscription standing, invoices, receipts, statements, and agreements.
- Records: activity/audit records surfaced for client clarity.
- Settings/Mailbox readiness: account profile, representation authorization, mailbox/domain readiness, and support access.

## Screenshot Capture Instructions

Use real seeded or authenticated data only. Do not create screenshots with fake campaign outcomes, fake revenue metrics, fabricated meetings, or invented activity timelines. If a state has no real data, capture the designed empty/loading/error state and label it accurately in store metadata.
