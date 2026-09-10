# Orchestrate — Release Certification Record

**App:** Orchestrate · **Version:** `1.0.0 (14)` · **Certified:** 2026-09-09

One record for the whole release. It exists because "it builds" and "it works
on that platform" are different claims, and because the difference between
them is where a wasted store cycle comes from.

**Decision: `SUBMITTED`.** All three clients are built from one frozen commit on
one pinned Flutter toolchain, certified on real hardware where hardware exists,
and handed to their stores. What remains open is listed at the end; none of it
is a code defect, and one item is a Google account gate no artifact can move.

| Store | State |
|---|---|
| App Store | **1.0.0 (14) Waiting for Review** — submitted 2026-09-09 |
| Google Play | **build 14 sent for review**, closed testing Alpha |
| Microsoft Store | submitted by the founder |

**Google Play production is not available to this account.** It is a personal
developer account, so Play requires 12 opted-in testers running a closed test
for 14 continuous days before production access can be applied for. The console
reads 8 opted-in and `Apply for production` is disabled. Play production is
therefore no sooner than 14 days after a 12th tester opts in.

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

---

# Orchestrate 1.0.1 (15) — certification and release record

**App:** Orchestrate · **Version:** `1.0.1 (15)` · **Commit:** `856a53d` · **Date:** 2026-09-10

Supersedes the 1.0.0 (14) record above. Where that document lists six blockers
"between here and submission", five are now closed and the sixth is stated
honestly below rather than quietly dropped.

## Where 1.0.1 (15) actually went

Read from the consoles, not from memory.

| Channel | Result |
|---|---|
| App Store | **1.0.1 Waiting for Review** — submitted 2026-09-10 05:02, 4 items: iOS App 1.0.1 (15), the Orchestrate Platform subscription group, and both subscriptions |
| TestFlight | **1.0.1 (15) Complete**, uploaded 03:15 by the Codemagic `ios-testflight` workflow |
| Google Play | **15 (1.0.1)** on Closed testing (Alpha), status `completed`, full rollout |
| Google Play production | **not touched, and not available** — the console requires applying for production access; the release service account is scoped to testing tracks and cannot reach production by design |
| Microsoft Store | submitted by the founder |

1.0.0 (14) was **removed from review** to make way, and now reads
`Developer Rejected`. That was a deliberate, founder-authorised supersede: it
forfeited 14's queue position, held since 2026-09-09 13:14.

## Why the release identity is 1.0.1, not 1.0.0

Build 15 carries `CFBundleShortVersionString 1.0.1`, and a build cannot attach
to an App Store version record whose number differs. 1.0.0 already existed as
the submitted version, so the marketing version had to move with the build. The
version record was retitled 1.0.0 → 1.0.1 after 14 was removed.

Checked for consistency across every artifact rather than assumed:

| Surface | Reports |
|---|---|
| `pubspec.yaml` | `version: 1.0.1+15`, `msix_version: 1.0.1.0` |
| Android package | `versionCode=15`, `versionName=1.0.1` (read with `aapt2 dump badging`) |
| MSIX | `<Identity … Version="1.0.1.0">` (read from `AppxManifest.xml`) |
| TestFlight | Version 1.0.1, Build (15) |
| Play alpha | `15 (1.0.1)` |
| The running app | account menu renders `Orchestrate 1.0.1 (15)` |

No artifact still presents 1.0.0.

## Artifacts, verified from the packages

| Artifact | Size | Verified as |
|---|---|---|
| AAB | 60.2 MB | built 02:24 from `856a53d` |
| APK | 63 MB | `versionCode=15 versionName=1.0.1` |
| MSIX | 15 MB | `Identity Version="1.0.1.0"` |
| web | 43 MB | serves, `<title>Orchestrate</title>` |
| IPA | Codemagic | uploaded to TestFlight, processed Complete |

**Every artifact on disk before this work was build 14** — the AAB and MSIX
predated the 23:13 build-15 commit, and the APK read `versionCode=14`. Reading
the version out of the package, rather than trusting a file timestamp, is what
exposed that.

## Evidence

| Check | Result |
|---|---|
| `flutter analyze` | PASS, no issues (57.6s) |
| Client suite | PASS, **426 tests** |
| Pixel 9a `53061JEBF08485` | build 15 installed and launched; app reports `Orchestrate 1.0.1 (15)` |
| Plan & billing on device | correct — the duplicate sentence from 14 is gone |
| In-app `/pricing` on device | `$29.99 USD` monthly, `$299.99 USD` annual, and the same-subscription note |
| Support marks on device | Microsoft for Startups badge + **Google for Startups** and **AWS Activate** as word marks |
| Windows desktop | release built, launched, header and footer render (captured DPI-aware via `PrintWindow`) |
| iOS simulator certification | PASS on Codemagic, 4m 23s, before signing |

## What device certification found that tests did not

**The subscription card shows a period that ended 5/13/2026 beside
"Status: Active".** Investigated and **not** reported as a defect: it sits under
a panel headed *"Subscription record — What the payment provider holds.
Entitlement is stated above and is what the product acts on."* The framing is
deliberate and correct. Recorded here because it looks like a defect on a
screenshot and will be re-found by anyone who does not scroll up.

## Apple subscription catalogue — configured this session

Founder-frozen rule applied throughout: `SUBSCRIPTION_AVAILABILITY = APP_AVAILABILITY`,
and monthly versus annual is cadence only.

| Field | Monthly | Annual |
|---|---|---|
| Product ID | `…platform.monthly` | `…platform.annual` |
| US price | **$29.99** | **$299.99** |
| Territories | 175 (= app availability) | 175 |
| Level | **1** | **1** |
| Localization | Orchestrate Platform Monthly | Orchestrate Platform Annual |
| Review screenshot | ✅ 1242×2208 | ✅ same |
| Review notes | 518 chars | 518 chars |

Other territories were derived by Apple's own price-point system from the US
base ("Recalculate prices for all countries or regions"), not hand-set:
Canada $39.99 / $399.99, Europe €29.99, India ₹2,999.

### THE DEFECT THIS SESSION EXISTS TO RECORD

**The monthly subscription was priced at $0.99, not $29.99.** All 175
territories sat on the $0.99 tier while the app's own pricing page told the
customer $29.99. Submitting that pair would have had the App Store charging 97%
less than the published price for a product the binary describes correctly.

It was found by reading the live price out of App Store Connect instead of
assuming an earlier session had set it. **`$29.99` appeared nowhere on the
page.** Everything else about the product looked finished, which is exactly why
it survived that long.

Two secondary gaps found the same way: the annual product had **no availability
configured at all**, and the monthly was restricted to **1 of 175** territories.

### Why the price could not be fixed for over an hour

The browser was at **~219% page zoom** (viewport 691×371 CSS px,
`devicePixelRatio` 2.19). At that zoom the **"Edit Price" button is clipped out
of the Starting Subscription Price dialog entirely** — the dialog renders, is
readable, and simply has no visible way to change the price. Five approaches
were tried and reported as a genuine blocker. After the founder reset zoom to
100%, the button was there and the change took two minutes.

The same zoom is the documented cause of an earlier ASC picker failure in this
estate. **Check `devicePixelRatio` before concluding an App Store Connect
control does not exist.**

## Near-misses worth knowing about

- **A `Delete` control adjacent to the build row is the screenshots' "Delete
  All".** Both carry `aria-label="Delete"`. The build-row one was identified by
  checking its ancestor text (`Build | BUILD | … | 15 | 1.0.1`) before clicking.
  A label-only match would have wiped the six app screenshots.
- **Three processes were listening on port 8899.** A local serve of `build/web`
  silently lost the port and the page that answered was a peer's *Aura* build.
  Certifying it would have certified the wrong product. Moved to 8917 and
  confirmed `<title>Orchestrate</title>` before trusting it.
- The subscription level control is a react-beautiful-dnd list whose *combine*
  gesture no synthetic or scripted drag would drive; the founder performed it.

## Still open

1. **Review screenshots are the fallback, not the preference.** They show the
   in-app pricing screen from build 15 on Android — real, unentitled, both
   prices, not fabricated — but not the iOS purchase sheet from a sandbox
   account. No sandbox tester exists, and creating one needs credentials this
   session will not handle. Prepare one before the next submission.
2. **Google Play production access** has not been applied for. Alpha is the only
   live track.
3. **Billing is not certified end to end.** No purchase has been exercised on a
   real device against either rail.
4. Once an item is added to an App Store review submission its review screenshot
   and notes go **read-only**; the only way back is removing the item, which
   un-stages it. Metadata has to be right before staging, not after.

---

# Google Play production unlocked, and 1.0.1 (15) submitted — 2026-09-10

The 1.0.1 record above ends with Play production "not available". It became
available, and the reason is worth stating precisely because it was not a
release problem at all.

## The gate was the ACCOUNT TYPE, not the app

Play production was refused with "You don't have access to production yet". That
is the **personal developer account** rule: an account registered to an
individual must run a closed test with 12+ testers for 14 continuous days before
it may apply for production. It has nothing to do with the app's readiness.

**Organization accounts are exempt.** The account was registered to
`Muhammad Sakhawat` as a Personal account, while the product branding, the
Microsoft publisher identity (`AuraPlatformLLC.Orchestrateoperations`) and the
app copyright all said Aura Platform LLC. Two of three stores were on personal
identities while the products presented as the company.

Converting the account resolved it in one step. Read from the console after:

| Field | Value |
|---|---|
| Account type | **Organization** |
| Organization | **AURA PLATFORM LLC** |
| Registered address | 25426 Goddard Rd, Taylor 48180-6200, US |
| Developer name (public) | **Aura Platform LLC** (was `Muhammad Sakhawat`) |
| Website | `https://company.auraplatform.org/` verified |

Production unlocked for **every app on the account**, not per app — Orchestrate
and Aura both.

### What the conversion actually required

Google's dialog: a **D-U-N-S number** for the organization, plus a phone and
email for the public developer profile. **No payment tier removes the testing
requirement** — it is account type, not money, and both types cost the same.

A D-U-N-S may already exist without ever being applied for; D&B auto-creates
records for many registered entities. Check `my.dnb.com/lookup` before applying.

**A Google Workspace or Cloud organization does NOT confer a Play organization
account, and Play accounts cannot be merged.** Verified: `gcloud organizations
list` returns 0 items for the personal identity and all four GCP projects are
parentless. They are separate registrations.

## The website should be the COMPANY page, not a product or personal one

Measured, not assumed:

```
auraplatform.org            200  no title, no description - bare
www.auraplatform.org        000  does not resolve: no DNS, no TLS
company.auraplatform.org    200  "Aura Platform LLC - Products"
bajwa.auraplatform.org      200  "Muhammad Sakhawat Bajwa - Founder..."  PERSONAL
finance.auraplatform.org    200  "Aura Finance"
```

The verified website on the account had been `bajwa.auraplatform.org`, which is
the founder's **personal** bio site. On a profile reading "Aura Platform LLC"
that is the same individual/company ambiguity the conversion exists to remove.
Now `company.auraplatform.org`, which already served the right content.

**Open, and outside this session's working set:** the apex serves nothing and
`www` does not resolve. A Play reviewer, a D&B verifier or an investor typing
the obvious domain meets a blank page. Pointing apex + www at the company page
is a small DNS change. Relayed to the peer sessions.

## Orchestrate 15 (1.0.1) — submitted to production

| | |
|---|---|
| Track | **Production**, full rollout (100%) |
| Bundle | 15 (1.0.1), 11 MB, 6s download |
| Countries | **177** |
| Release notes | en-US, same text as alpha |
| State | Sent to Google for review, ~7 days typical |

A brand-new production track has **no countries selected** and refuses to save
with "No countries or regions have been selected for this track". The country
picker uses `role="checkbox"` custom elements, not `input[type=checkbox]`, and
the header control is `aria-label="Select all rows"`.

## Play billing was already correct — verified, not assumed

Read from the Play Developer API before publishing:

```
orchestrate_platform
  monthly  ACTIVE  173 regions   US $29.99   GB £26.49   IN ₹3,350
  annual   ACTIVE  173 regions   US $299.99  GB £264.99  IN ₹33,700
```

Both base plans ACTIVE and anchored on the frozen prices. **Nothing resembling
the $0.99 defect Apple carried.** The Play console's subscription list renders
the "Active base plans" column empty, which is a UI artifact — the API shows
both plans active. Do not read that column as state.

## Aura 1.4.2 (37) — staged, not submitted

Production track created, bundle 37 attached, release notes copied **verbatim
from its own alpha track via the API** rather than written by this session,
which does not know that product's changes. Blocked at country selection: the
console returned `unexpected error (66A89484)` and the picker then rendered zero
checkboxes across repeated attempts. The draft survived — `Draft release:
37 (1.4.2), 0 countries / regions`.

To finish: Aura > Production > Countries / regions > Add countries / regions >
tick "Select all rows" > Save, then Publishing overview > Submit for review.

**Two things decided by the founder, recorded because they were deliberate:**
37 was promoted rather than 1.4.3 (38), because 38 is still under certification
and needs a rebuild — so 38 becomes an update to a live audience rather than a
first release. And "all countries" was chosen for Aura despite this session
holding no certification evidence for that product and notes referencing a China
CallKit jurisdiction gate and an App Store 1.4.1 China rejection.

## A correction owed to the record

While searching for the LLC's registered address this session dismissed
"25426 Goddard Rd, Taylor, Michigan" as grep noise. It was the LLC's actual
registered address. It then typed ZIP `48187` into the D&B lookup over a
pre-filled `48180`; **48180 was correct** — 48187 is the founder's personal
Canton ZIP. The estate contains no Articles of Organization, EIN, formation date
or registered agent, which is why the address had to come from the console
rather than the repositories.
