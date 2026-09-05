# Orchestrate — Release Certification Record

**App:** Orchestrate · **Version:** `0.2.3 (12)` · **Certified:** 2026-09-05
**Deployed:** backend and web client, 2026-09-05, verified live.

One record for the whole release. It exists because "it builds" and "it works
on that platform" are different claims, and because the difference between
them is where a wasted store cycle comes from.

## The words, and what each one means here

These are kept apart deliberately. A row that says BUILT does not say
INSTALLED, and nothing below claims more than was actually done.

| State | What it means |
|---|---|
| **BUILT** | An artifact exists for the platform. |
| **INSTALLED** | That artifact is on a real target and launches. |
| **EXERCISED** | A person or a driver moved through the product on it. |
| **CERTIFIED** | Exercised, and the result was read and judged. |
| **SUBMITTED** | Handed to a store. Not claimed anywhere in this document. |
| **IN REVIEW / APPROVED / PUBLICLY AVAILABLE** | Store states. None reached. |

---

## Identity

| | |
|---|---|
| Marketing version | `0.2.3` — from `pubspec.yaml`, nowhere else |
| Build number | `12` |
| iOS bundle | `com.orchestrateops.app` |
| Android package | `com.orchestrateops.app` |
| Windows identity | `AuraPlatformLLC.Orchestrateoperations`, MSIX `0.2.3.0` |
| Apple app id (for the Rate link) | `6772025079` |
| Seller of record | Aura Platform LLC |

The version a person can read in the account menu comes from package metadata
on every platform — `ReleaseIdentity.load()`, never a constant. Certified on
Windows and Android by printing it from the running app: `WINDOWS 0.2.3 (12)`
and `ANDROID 0.2.3 (12) (com.orchestrateops.app)`. On iOS `Info.plist` carries
`$(FLUTTER_BUILD_NAME)` / `$(FLUTTER_BUILD_NUMBER)`, so the same pubspec is
the only source.

**Seller identity is not IP ownership.** Aura Platform LLC is the entity that
holds the store accounts and appears as seller. Nothing in this record makes a
claim about who owns the product.

---

## Platform certification

### WEB — CERTIFIED

- 39 client surfaces opened as a signed-in business, at four viewports
  (1680×1050, 1366×900, 1180×820, 900×1180). Zero page errors; every redirect
  landed where the IA intends.
- Chrome and Edge, full round trip: sign in → Today; move through the rail;
  reload holds the page; sign out returns to the front door; the workspace is
  gated behind it carrying the destination; signing back in returns to the
  workspace.
- Screens were judged from pixels, not from the widget tree. Everything in
  "What this found" below came out of looking at them.

### WINDOWS — CERTIFIED

- `build/windows/x64/runner/Release/orchestrate_app.exe` — BUILT, INSTALLED
  (launched, window titled, responding), EXERCISED and CERTIFIED through
  `integration_test` on the real desktop target.
- Boots and produces frames; every workspace destination navigates without
  redirecting; every retired path lands where intended; a business with no plan
  reaches its workspace; version resolves from package metadata.

### ANDROID — CERTIFIED (physical device)

- Physical Pixel 9a (`53061JEBF08485`, Android 17 / API 37).
- Release APK BUILT (61.0 MB, signed from `android/key.properties`) and
  INSTALLED — `versionName=0.2.3`, `versionCode=12`, `minSdk=24`,
  `targetSdk=36` read back from the device.
- EXERCISED and CERTIFIED through `integration_test` on the device itself.
- **Not** visually certified on the device: the phone was locked, and
  unlocking it is the founder's action. What ran, ran headlessly against the
  real Android build.

### iOS — NOT BUILT

No iOS artifact exists. Flutter cannot build one on Windows, and this machine
is Windows. Everything that *can* be prepared without macOS has been; see
"What is owed before a TestFlight cycle".

---

## Commercial state

**One policy governs every rail.** `COMMERCIAL_ACTIVATION_OPEN = false`,
frozen closed by founder decision on 2026-09-04. Stripe honoured it at the
service boundary; Apple and Google did not, because rail readiness had been
built as a purely technical question. It now governs all three.

| Rail | State | Why |
|---|---|---|
| Stripe (web) | Closed | Commercial policy |
| Apple App Store | Closed | Commercial policy — the rail itself verifies |
| Google Play | Closed | Commercial policy — *and* `ACCESS_REFUSED` beneath it |

`VISIBLE_BUT_NONFUNCTIONAL_PURCHASE_PATHS = 0`. Nothing in the product offers a
purchase that cannot complete. Where a business would have met a checkout, it
now meets the policy's own words and an invitation to agree terms directly.

Google Play separately answers `401 permissionDenied` from `androidpublisher`:
the service account authenticates but is not linked to the Play listing. That
is a founder action (Play Console → Users and permissions, and the Android
Publisher API enabled for its project). It is currently moot, because policy
closes the rail anyway.

---

## What this certification found

Defects that only appear when the product is used. Each is fixed, and each has
a test that fails if it returns.

1. **Every sign-in landed on the retired home.** `/app/home` — the
   pre-reconstruction home, rendered inside the new shell with none of its four
   destinations selected. Reported by the founder; the route sweep could not
   have found it, because nothing in the current IA links there.
2. **Signing in without a plan forced checkout.** The router gate had been
   corrected; the login screen kept its own copy of the decision and overruled
   it at the one moment that mattered.
3. **The workspace animated between its own screens.** Every shell route used
   `builder:`, so the content area slid and faded and the two screens were
   painted over each other. 63 routes converted to `NoTransitionPage`.
4. **Today re-fetched and blanked on every visit.** Market and Relationships
   held their answers across a visit; Today did not.
5. **Enter did not submit any form.** Sign in, create a workspace, the emailed
   code, password reset, and the operator screen.
6. **The account row was a 30 px circle.** The only door to People & authority,
   Plan & billing, Account & security, feedback and sign out.
7. **A member could not sign in to their own organisation.** Client resolution
   matched only by email; anyone added after the founding registration matched
   nothing, and sign-in answered 500.
8. **Commercial surfaces contradicted each other.** "Plan: Focused" beside
   "Status: None"; "Billing review" for a business that never subscribed; a
   billing portal offered for a subscription that does not exist.
9. **Platform vocabulary reached customers.** "this tenant", "platform
   bootstrap transport", `IMAP_SMTP`, `Section: business_identity`,
   "no client document render endpoint is exposed for this category".
10. **Navigation promised what did not exist.** A pipeline view, a waiting
    view, three section anchors nothing reads, and a "Credentials" entry that
    opened a diagnostic while the real Credentials screen sat unlinked.
11. **Migration replay did not reproduce production.** Recorded drift, closed
    with guarded DDL. `/client/market` answered 500 on any environment built
    from the migration history.
12. **CI would have failed at its second step.** `flutter analyze` exits
    non-zero on any issue; twelve lint infos would have stopped the iOS build
    before the IPA.

---

## What is owed before a TestFlight cycle

Everything here is a founder action. None of it can be done from this machine.

1. ~~Deploy the backend and the web client.~~ **Done, 2026-09-05.** Both are
   live and verified: the drift reconciliation migration applied cleanly (every
   statement a no-op where the object already existed), the reconciled foreign
   key carries `ON UPDATE CASCADE`, `POST /auth/me` answers, and the live web
   bundle contains this session's work and none of the copy it replaced.

2. ~~Confirm the App Store Connect record exists~~ **Done.** The record and
   the Codemagic integration named `Aura Platform LLC` are connected. Two
   signing failures were spent proving it: the App ID was missing Associated
   Domains, and then Codemagic reused its own stale stored profile, which had
   to be re-fetched and the old copy deleted.
3. ~~Decide the build number.~~ **Done.** `12` was consumed by an upload Apple
   rejected in processing (ITMS-90683), so `pubspec.yaml` carries `0.2.3+13`.
   A build number is spent even when the build fails.
4. ~~Trigger the Codemagic `ios-testflight` workflow.~~ **Done, 2026-09-05.**
   Build 13 passed analysis, unit tests, simulator certification and signing,
   and is attached to the 0.2.3 version record in App Store Connect.
5. ~~App Store Connect metadata.~~ **Done, 2026-09-05**, and it was further
   out of date than the release notes were. See
   `store_assets/release_notes/0.2.3.md` for the field-by-field record. Two
   items were not merely stale but wrong: the App Privacy questionnaire
   declared two of the four data types the shipped `PrivacyInfo.xcprivacy`
   declares, and the age rating was 17+ on an `Unrestricted Web Access`
   answer that no code in this repository supports. Both corrected; the
   rating is now 4+.
6. **Optional, and currently moot:** link the Play service account, if Android
   commerce is ever to open.

---

## Prepared for iOS without macOS

- **All three purpose strings present, and each says what it is for.** They
  were removed once, on the reasoning that the product uses none of them.
  Apple rejected the upload (ITMS-90683) because it analyses the *binary*, and
  `file_picker` links the camera and location frameworks whether or not our
  code calls them. Photo library, camera and location descriptions are all
  restored, and pinned by `test/ios_purpose_strings_test.dart`.
- **`PrivacyInfo.xcprivacy` added and registered in the Xcode project**, so it
  is copied into the bundle rather than sitting in the folder. No tracking, no
  tracking domains; email, name, account id and the business's own records,
  all linked, all for app functionality. The App Store Connect questionnaire
  now declares the same four types, in the same terms.
- **`ITSAppUsesNonExemptEncryption`** already declared, so export compliance is
  not asked at upload.
- **iOS route policy** keeps the entire acquisition funnel unreachable in the
  App Store build and refuses `/client/subscribe` — App Store Guideline 3.1.1.
  Pinned by test.

---

## How to reproduce this

The native certification lives in the repository and runs anywhere. The web
harness — a Playwright driver plus a seeded local instance — is session
scratch and is described rather than committed, because it carries local
credentials and a disposable database.

```
# Windows and Android — the real application on the real platform
flutter test integration_test -d windows
flutter test integration_test -d <android device id>

# With an authenticated session, against a local instance
flutter test integration_test -d windows \
  --dart-define=API_BASE_URL=http://localhost:4310/v1 \
  --dart-define=CERT_TOKEN=<token>
```

Without `CERT_TOKEN` the platform half still runs and the authenticated half
skips with a message. It does not invent a verdict — a made-up token is
answered 401 and the app correctly signs itself out, which would otherwise look
like a product failure.
