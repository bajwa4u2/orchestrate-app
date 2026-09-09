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
| Client release commit | **`725f40f`** |
| Backend commit deployed | `c8ff0f0` (Railway, SUCCESS) |
| Flutter | **3.47.2**, framework `d3b14c8769` · Dart 3.13.2 |
| Toolchain record | `docs/RELEASE_TOOLCHAIN.md` — SDK revision proof, every version, every hash |
| Android compileSdk / targetSdk | **36 / 36**, read from the AAB manifest |
| Android minSdk | 24 |
| Play Billing | **`com.android.billingclient:billing:8.0.0`**, read from the AAB's dependency metadata |
| Windows package | `1.0.0.0`, read from `AppxManifest.xml` |
| Codemagic workflow | `ios-testflight`, `xcode: latest`, version from pubspec |

### Artifacts

| Artifact | SHA-256 | Bytes |
|---|---|---|
| `app-release.aab` | `8cc2db7018412890cf1f2d5f941b616209be958638154b97eda63fdc12f9353c` | 63,228,264 |
| `orchestrate_app.msix` | `45915bb43bfa48f8aa9d9dd3bde9db9055c3b9ba0951b2bac85d432b4ab34eec` | 15,940,401 |

Both built from `725f40f` on the pinned Flutter 3.47.2, from a tree cleaned of
every prior build product.

**Superseded — `PROVENANCE_SUPERSEDED — DO NOT SUBMIT`:** the AAB
(`0ce8ca0d…`) and MSIX (`8b23477e…`) built on Flutter 3.41.4. One release built
by two Flutter toolchains cannot say what produced it. Retained only as
comparison evidence.

Two further artifacts were discarded rather than recorded: an AAB built before
the header fix landed, and an AAB built while the Gradle migrator was writing
`android.builtInKotlin` mid-build. An artifact that cannot be said to match the
frozen source is not a candidate.

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

**Artifact PASS.** Built from `725f40f` on the pinned SDK and read directly:
`versionCode=14`, `versionName=1.0.0`, `targetSdkVersion=36`,
`compileSdkVersion=36`, `package=com.orchestrateops.app`. The Play requirement
to target Android 16 / API 36 is met **in the binary**, and Play Billing 8.0.0
is present in the shipped dependency set — re-verified in this artifact after
the toolchain move rather than carried over. Signed
`CN=Orchestrate, O=Aura Platform LLC`, SHA-256
`1E:91:61:8C:5F:CB:A5:55:00:A1:3C:6C:CA:9E:C4:A3:AB:C5:E4:F0:5C:A5:2A:66:CE:D6:70:53:B2:8C:70:C6`.

The bundle grew 46.7 MB → 60.3 MB across the SDK move. That is entirely
`BUNDLE-METADATA` — a new `proguard.map` and `libapp.so.sym` symbols for all
three ABIs — which Play strips and which never reaches a device. Same three
ABIs; nothing extra ships.

**Runtime NOT EXECUTED.** The physical Pixel is in use by another workstream.
Install/upgrade-from-released, startup, sign-in, navigation, system Back,
lifecycle/background-resume, network loss/recovery and notification/deep-link
behaviour are therefore unproven for this build. Prior Pixel evidence covers
build 13, not build 14, and **build 13 evidence does not transfer**: 60 commits
land between them, concentrated in exactly the navigation and shell code that
evidence would need to cover.

### iOS / iPadOS — EVIDENCE-LIMITED (simulator certified)

Certified on the Codemagic runner through a workflow that **cannot submit** —
`ios-simulator-certification` has no App Store Connect integration, no signing
block and no publishing section.

| | |
|---|---|
| Xcode / iOS SDK | **26.6 (17F113) / 26.5** — read from the runner, not inferred from `xcode: latest` |
| Flutter / Dart | 3.47.2 / 3.13.2 — same revision as the local release SDK |
| iPhone simulator | boots, workspace navigates, retired paths land; all tests passed |
| iPad simulator | same; an iPad is a separate layout and App Review opens one |
| Version read from the running app | `IOS 1.0.0 (14)` (`com.orchestrateops.app`) |

Apple's minimum is the iOS/iPadOS 26 SDK or later, so 26.5 satisfies that gate.

**NOT EXECUTED:** signed archive, real-device runtime, TestFlight upload. A
simulator proves the binary runs; it does not prove signing, provisioning, or
device behaviour, and none of those is claimed here.

### WINDOWS — EVIDENCE-LIMITED

**Package PASS.** MSIX produced from `725f40f` on the pinned SDK; identity,
version, publisher and display names verified in the manifest. Unsigned, which
is what a Store submission expects — no self-signed development package is used
as release evidence.

**Runtime PASS (unauthenticated).** Re-certified on the real binary after the
toolchain move: the app boots, the workspace navigates, retired paths land, and
the version reads `WINDOWS 1.0.0 (14)` from package metadata.

**NOT EXECUTED.** Clean install from this package, upgrade from the distributed
`0.2.3.0`, authenticated navigation, window resizing, keyboard operation,
high-DPI, network loss/recovery and uninstall/reinstall semantics. The
authenticated half of the harness reports `NOT exercised — no CERT_TOKEN`, and
no token will be minted to turn that into a PASS.

The currently distributed `AuraPlatformLLC.Orchestrateoperations_0.2.3.0` is
installed on this machine, so upgrade certification is possible once the
release package is signed.

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

1. **iOS signed archive not produced.** The simulator path is certified
   (Xcode 26.6, iOS SDK 26.5, iPhone and iPad, `IOS 1.0.0 (14)`), but no signed
   archive, real-device run or TestFlight upload exists. Superseded from the
   earlier claim that iOS could not be built at all — it can; the Codemagic
   session is available.
2. **Physical Android runtime unavailable.** The Pixel is in use by another
   workstream. Build 14 has no device evidence, and build 13's does not carry
   over across 60 commits of navigation and shell change — nor across a Flutter
   SDK change, which is a second independent reason the old evidence cannot be
   reused.
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
