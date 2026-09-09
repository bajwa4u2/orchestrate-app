# Orchestrate — Release Certification Record

**App:** Orchestrate · **Version:** `1.0.0 (14)` · **Certified:** 2026-09-09

One record for the whole release. It exists because "it builds" and "it works
on that platform" are different claims, and because the difference between
them is where a wasted store cycle comes from.

**Decision: `NOT READY`.** Every remaining blocker is listed at the end with
its evidence. None of them is a code defect.

## The words, and what each one means here

These are kept apart deliberately. A row that says BUILT does not say
INSTALLED, and nothing below claims more than was actually done.

| State | What it means |
|---|---|
| **PASS** | Exercised, and the result was read and judged. |
| **FAIL** | Exercised, and it was wrong. |
| **EVIDENCE-LIMITED** | Partly proven. The exact limit is named, never rounded up. |
| **NOT EXECUTED** | Not attempted, with the reason. Never a silent gap. |

**No platform inherits a result from another.** Runtime observation outranks a
green suite; a test that never reached its assertion is not certification.

---

## Identity

| | |
|---|---|
| Marketing version | `1.0.0` — from `pubspec.yaml`, nowhere else |
| Build number | `14` |
| iOS bundle | `com.orchestrateops.app` |
| Android package | `com.orchestrateops.app` |
| Windows identity | `AuraPlatformLLC.Orchestrateoperations`, MSIX `1.0.0.0` |
| Apple app id (for the Rate link) | `6772025079` |
| Seller of record | Aura Platform LLC |

### The Windows package version, and the value that was wrong

`1.0.14.0` was written first — major/minor carrying the product version, the
third part carrying the build number, revision zero as the Store requires. The
release-identity test rejected it.

The rule this repo already holds is that the Windows package states the *same
version the product does*, which with a zero revision leaves exactly one legal
value: **`1.0.0.0`**. Monotonic over the distributed `0.2.3.0` because the major
moved. Verified in the generated `AppxManifest.xml`, not inferred from config:

```xml
<Identity Name="AuraPlatformLLC.Orchestrateoperations" Version="1.0.0.0"
          Publisher="CN=3E4027A7-4D4D-4492-B8DE-BBE425E307E5"
          ProcessorArchitecture="x64" />
```

**Seller identity is not IP ownership.** Aura Platform LLC holds the store
accounts and appears as seller. Nothing here claims who owns the product.

---

## Build provenance

| | |
|---|---|
| Client release commit | `c180625` |
| Backend commit deployed | `9cde74b` (Railway, SUCCESS) |
| Flutter | 3.41.4 stable · Dart 3.11.1 |
| Android compileSdk / targetSdk | **36 / 36**, read from the AAB manifest |
| Android minSdk | 24 |
| Play Billing | **`com.android.billingclient:billing:8.0.0`**, read from the AAB's dependency metadata |
| Windows package | `1.0.0.0`, read from `AppxManifest.xml` |
| Codemagic workflow | `ios-testflight`, `xcode: latest`, version from pubspec |

### Artifacts

| Artifact | SHA-256 | Bytes |
|---|---|---|
| `app-release.aab` | `0ce8ca0dfef63f11c8e0fbc07d939c05a51cd07675b5011abbc1bca94683cd98` | 48,993,652 |
| `orchestrate_app.msix` | `8b23477ee6080ea6575c32b30410e95568fb45ece35d309e7163d3fef5b1d2fd` | 16,485,516 |

Both produced from the frozen release source. An earlier AAB was built before
the header fix landed and was discarded rather than submitted — an artifact that
does not trace to the release commit is not the release.

"Build succeeded" is not provenance. Each value above was read out of the
produced artifact, not out of the configuration that was supposed to produce it.

---

## Platform certification

### WEB — PASS (public + authenticated, this release's backend)

Walked in a real browser against production, not route tests.

- Public front door, `/account-deletion`, and the legal routes render and are
  reachable. Every legal/support URL answers.
- Authenticated workspace: Today, Market, Business all render with real data,
  correct return paths, no dead ends, no placeholder text, no operator
  vocabulary leaking into client surfaces.
- Market reads **"Checked 3 of 1544 areas in your market so far"** — the durable
  locality pool, surfaced to a person, after a cold backend restart.

### ANDROID — EVIDENCE-LIMITED

**Artifact PASS.** The AAB was produced and its manifest read directly:
`versionCode=14`, `versionName=1.0.0`, `targetSdkVersion=36`,
`compileSdkVersion=36`, `package=com.orchestrateops.app`. The Play requirement
to target Android 16 / API 36 is met **in the binary**, and Play Billing 8.0.0
is present in the shipped dependency set — Billing 7 is past its deadline and we
are not relying on an extension.

**Runtime NOT EXECUTED.** The physical Pixel is in use by another workstream.
Install/upgrade-from-released, startup, sign-in, navigation, system Back,
lifecycle/background-resume, network loss/recovery and notification/deep-link
behaviour are therefore unproven for this build. Prior Pixel evidence covers
build 13, not build 14, and **build 13 evidence does not transfer**: 60 commits
land between them, concentrated in exactly the navigation and shell code that
evidence would need to cover.

### iOS / iPadOS — NOT EXECUTED

No iOS artifact exists for build 14. Flutter cannot build one on Windows, and
the Codemagic path needs API credentials that are not present in this
environment. Nothing about iOS can be inferred from Flutter tests or Android
behaviour, so nothing is claimed.

The workflow config itself is sound: `xcode: latest`, version and build number
derived from `pubspec.yaml`, TestFlight submission wired. It has not been run.

### WINDOWS — EVIDENCE-LIMITED

**Package PASS.** MSIX produced from the frozen source revision; identity,
version, publisher and display names verified in the manifest.

**Runtime NOT EXECUTED.** Clean install, upgrade from the distributed package,
launch, authentication, window resizing, keyboard operation, high-DPI, network
loss/recovery and uninstall/reinstall semantics have not been exercised for this
build.

---

## Store policy

| Requirement | State | Evidence |
|---|---|---|
| In-app account deletion (Apple + Google) | **PASS** | `Client workspace → Account → Delete account` reaches `POST /clients/me/delete`; the server cancels subscriptions, deletes auth identities, trusted devices and login challenges, tombstones the email and deactivates membership. Real deletion, not deactivation. |
| External web deletion resource (Google) | **PASS** | `/account-deletion` is public and renders; verified live in a browser. |
| Privacy / support / legal URLs | **PASS** | All answer; routes mounted and rendering. |
| Android permissions | **PASS** | `INTERNET` only. Nothing declared that 1.0.0 does not use. |
| iOS purpose strings | **PASS, and deliberately so** | Camera, photo library and location strings are present because Apple analyses the shipped binary, not our source. Removing them earned **ITMS-90683** and cost a build number. Each string describes the one path that could reach it; the location string says plainly that Orchestrate does not ask for location. Pinned by a test. |
| App Privacy / Data Safety vs shipped SDKs | **EVIDENCE-LIMITED** | The manifest declares email, name, user id and user content, all linked, none tracking. `in_app_purchase` is now in the graph and purchase evidence is sent to our server for entitlement; whether that obliges a **Purchases** declaration has not been resolved against the shipped behaviour. Flagged, not guessed. |

---

## Billing and entitlement

The architecture is the one required: the device decides nothing.

```
store transaction → verified provider evidence → server-side entitlement
                  → authenticated principal → capability on every client
```

`store_purchase.dart` never grants a capability, never writes an entitlement,
and never believes `purchaseStatus == purchased` on its own. Intent is recorded
server-side *before* payment, because neither store knows which company a
person's store account belongs to.

**Proven without store rails (server-side, in suite):**

| | |
|---|---|
| One entitlement per organisation, whichever rail took the money | `store-lifecycle` — an Apple ACTIVE and a Google ACTIVE derive the same state through the one function every client reads |
| An unsigned claim is not a purchase | `store-verifiers` |
| The signing algorithm is ours to choose, not the payload's | `store-verifiers` — the `alg:none` class of forgery |
| The trust root is shipped, never supplied by the caller | `store-verifiers` |
| Purchase binds to an organisation decided before the store | `purchase-binding` |
| One subscription, one organisation; an already-paying business is not sold to again | `purchase-binding` |
| Sandbox is never service | `purchase-binding` |

**NOT EXECUTED — needs sandbox rails on real devices:** Apple purchase and
restore; Google purchase and reconciliation; cancellation/expiry observed end to
end; pending / payment-interruption; refund and revocation removing entitlement;
reinstall and re-login retaining access; duplicate provider callbacks proven
idempotent against the live handler; and the cross-device claim — buying on
mobile and signing in on Windows or web.

The derivation is shared, so the cross-device property is *structurally* sound.
That is a different claim from having watched it happen, and it is not upgraded
here.

---

## Reviewer access

**NOT EXECUTED.** Durable Apple and Google reviewer access for build 14 has not
been prepared or re-verified. The prior package was built for `0.1.3 (5)`.
Reviewers must reach billing surfaces and the complete product without founder
intervention, and no production customer, agreement, payment or reply will be
fabricated to populate their state.

---

## Blockers — what actually stands between here and submission

1. **iOS build cannot be produced.** No Codemagic credentials in this
   environment. Without it there is no archive, no SDK verification, no
   TestFlight build, and no iPhone/iPad evidence. *Authority boundary — needs
   the founder.*
2. **Physical Android runtime unavailable.** The Pixel is in use by another
   workstream. Build 14 has no device evidence, and build 13's does not carry
   over across 60 commits of navigation and shell change.
3. **Billing not certified end to end.** Every rail-dependent proof the release
   requires needs sandbox accounts on real devices.
4. **Store submissions require interactive console access** to App Store
   Connect, Play Console and Partner Center.
5. **App Privacy / Data Safety purchase declaration unresolved** — see above.
6. **Windows runtime unexercised** for this build.

None of these is a code defect, and none is waiting on further engineering.

---

## What this release contains

60 client commits since build 13: 73 files, +8840/−1181, concentrated in client
screens, the shared shell, routing and navigation. Treat it as a substantial
delta, not a patch.

Fixed during this certification:

- **Public header alignment.** The sign-in / start-setup / menu group sat short
  of the right edge. `[Flexible, Spacer, Flexible]` — three flex children each
  defaulting to `flex: 1`, so the spacer absorbed a third of the free space
  instead of all of it, and a loose Flexible does not return what it does not
  use. Now measured by a render test: 11px from the frame edge, which is the
  icon button's own padding.
- **Market survives a deploy.** See `orchestrate_backend`
  `docs/` and the commit *"A deploy should not cost us the map"*. Locality
  expansion has durable authority; a cold start no longer re-asks a shared
  public service for geography that has not moved.

## How to reproduce this

```
flutter analyze                       # clean
flutter test                          # 414 pass
flutter build appbundle --release     # then read base/manifest from the AAB
dart run msix:create --store          # then read AppxManifest.xml from the MSIX
```

Backend: `npm test` — 208 suites.
