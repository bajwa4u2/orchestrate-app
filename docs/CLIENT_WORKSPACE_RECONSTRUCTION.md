# Client workspace reconstruction — findings register

A running record of what was found, what caused it, and what proved the fix.
Its purpose is continuity: so a later pass does not rediscover the same thing,
and so a claim in a commit message can be checked against evidence.

Findings are numbered `CW-n`. Anything still open says so.

**Withdrawn findings stay in this register.** A claim that runtime evidence
disproved is not an embarrassment to be deleted — it is the most useful entry
here, because it records how a certification went wrong and what kind of
evidence corrected it. Two are marked WITHDRAWN below: one where a premise went
stale between measuring and looking, and one where the measuring instrument
itself was lying. Deleting either would leave the next pass free to make the
same mistake with the same confidence.

---

## CW-1 — The workspace had no theme of its own

**Finding.** The authenticated client workspace rendered with
`AppTheme.lightTheme`: the same `ThemeData` as the public marketing site.

**Evidence.** `client_shell.dart` and `public_shell.dart` both called
`Theme(data: AppTheme.lightTheme)`. The rich layered palette that exists in
`AppTheme` — `panel`, `panelRaised`, `accent`, `amber`, `emerald` — was wired
only to `operator_shell.dart`.

**Root cause.** Not styling drift. There were three shells and only two themes,
so the client workspace inherited whichever of the other two it was closest to.
It also inherited marketing PROPORTIONS: a 54px `headlineLarge`, 16px of
vertical padding inside every button, and a 16px body — written for a page read
once at a distance, not an environment worked in all day.

**Fix.** `lib/core/theme/workspace_theme.dart` (`Ws`). Its own palette, its own
operational type scale, its own control density. Identity carries across
through the things that signify — the teal, Inter, and the deep field — while
the working surfaces get denser and genuinely layered.

**Why the rail is a deep field.** The public product already puts its most
deliberate moments on `publicCanvas`. Using that field for the rail is what
makes signing in read as descending into the same product rather than arriving
at a different one, and it gives the work area a ground to be light against. It
is deliberately NOT the operator console's near-black: a client's commercial
workspace that looked like their supplier's internal instrument would blur a
boundary the product is careful about everywhere else.

**Runtime proof.** Rendered on Windows against the founder's live session.

**Affected surfaces.** Every authenticated client surface — screens take their
sizes from `Theme.of(context)` and override only colour, so the type scale
propagates without touching 44 files.

**Platform consequences.** None specific; the theme is shared.

---

## CW-2 — A desktop window classified itself as a phone

**Finding.** The workspace served a phone layout — bottom navigation bar, app
bar, no rail, one stacked column — on a desktop monitor.

**Evidence.** Measured from inside the running client rather than inferred:

```
maxW = 1265.6 logical   dpr = 1.25   textScale = 1.75
eff  = 1265.6 / 1.75 = 723.2   →  below the 760 phone boundary
size = WorkspaceSize.phone
```

**Root cause.** `Workspace.sizeOf` measured every boundary in *effective* width
— real width divided by the OS text scale. For the upper boundaries that is
right: how many panes fit genuinely depends on type size. For the phone
boundary it is wrong. Whether there is a pointer, a keyboard and a window
manager is not a function of type size.

This is the root of the enlarged-phone feeling. It was never a styling problem:
the layout system had decided the machine *was* a phone.

**Fix.** Structure follows the real viewport; density still follows the text.
`test/workspace_structure_test.dart` pins both halves, including that enlarged
text must still reduce how many panes fit.

**Runtime proof.** Reverting only the `sizeOf` rule fails
`the founder’s own window is not a phone`; the corrected rule passes all eight.

**Affected surfaces.** The whole authenticated shell.

**Platform consequences.** Web inherits the same correction. Android and iOS
are unaffected — a real phone is still under the boundary by shape, verified by
test at 390pt with the text scale at both 1.0 and 1.75.

---

## CW-3 — The rail collapsed on a wide monitor

**Finding.** At 1600px the rail showed icons only, hiding the destination
labels and the business identity.

**Root cause.** Two compounding: it collapsed on `WorkspaceSize.compact`, which
inherited CW-2's effective-width measure; and its width was a fixed 232px while
its labels followed the text scale, so enlarged labels had nowhere to go.

**Fix.** `Workspace.railWidth` scales with the text and is capped — at 1.75x an
uncapped rail took 27% of the window, which is a navigation bar wearing the
work area's clothes. `Workspace.railIsCollapsed` asks whether the work beside
it still has room, in real pixels.

**Runtime proof.** Captured before and after on the live client.

---

## CW-4 — The shell never said whose business was being operated

**Finding.** The first question anybody entering a workspace has, answered
nowhere. The rail said "Orchestrate", which is the supplier, not the business
being operated.

**Fix.** The rail leads with `session.workspaceName` and "Commercial
workspace". The account row at the foot now identifies the PERSON — it
previously repeated the workspace name, spending the one place in the shell
that could say who you are signed in as on saying the same thing twice.

**Runtime proof.** Renders "Orchestrate (Aura Platform LLC)" over
"Muhammad Sakhawat / support@orchestrateops.com" against the live session.

---

## CW-5 — Bands were headings, not surfaces

**Finding.** The work area read as a flat document however carefully the rows
were composed.

**Root cause.** `WorkspaceBand` painted a label and a list straight onto the
page. Nothing was contained by anything, so nothing had weight and the eye had
no structure to move between.

**Fix.** The band is a surface: working surface, recessed header strip,
hairline close, canvas showing around it. No shadow — at this density a shadow
under every group blurs the grid it is meant to clarify.

Separation moved from the row to the band. A row that drew its own bottom rule
put one against the panel edge when it happened to be last; the band knows
which row is last, a row does not.

**Affected surfaces.** Every surface using `WorkspaceBand` — Today,
Relationships, relationship depth, and others as they are reached.

---

## CW-6 — The brand mark followed the theme, not its surface

**Finding.** `BrandAssets.symbolFor` chose its asset from
`Theme.of(context).brightness`, so a light theme placing the mark on a deep
field would have used the light-background mark.

**Fix.** An explicit `onDark` override. The caller says which surface the mark
sits on rather than faking a brightness to get the right file.

---

## CW-7 — Text clipping — **WITHDRAWN: CAPTURE ARTIFACT**

**Finding.** Screenshots showed workspace text clipped mid-sentence at the
right edge. It reproduced across captures, so it was not a stale raster.

**It was not a product defect.** Measured from inside the running app, the
content pane was 873.2 logical points and rows were 849.2 — consistent, wrapping
correctly, no overflow.

**Root cause.** PowerShell is not per-monitor DPI aware, so `GetWindowRect`
returned logical coordinates while the app — which is DPI aware — painted at
device pixels. On a 125% display a 1265-point window paints 1582 pixels, and a
bitmap sized from the rect clipped the right 300 of them.

**Fix.** The capture tool scales its bitmap by `GetDpiForWindow`.

**Why this is recorded.** It cost a build cycle, and it nearly produced a
"fix" to a layout that was already correct. Screenshots are evidence about the
capture as well as about the product, and when a picture and a measurement
disagree the measurement wins.

---

## CW-8 — Today upcoming-meeting defect — **WITHDRAWN: NOT PROVEN**

**Claimed twice as a defect. It was not one.**

**What I asserted.** That a meeting existed, bound and ahead, and Today
rendered nothing — a functional gap.

**What the evidence says.** Every meeting was already settled before any
screenshot was taken:

```
created  scheduled  completed  status     meeting
08:01    11:01      08:09      COMPLETED  single meeting
08:27    11:27      09:33      COMPLETED  second attempt
10:16    13:16      10:23      COMPLETED  third attempt
```

The first workspace capture was taken after 10:23. Nothing was ahead at any
point I looked, so an empty meetings section was the correct rendering.

**Why I got it wrong.** I checked the database at 10:18 — when the third
meeting genuinely was ahead — and then read screenshots taken later as though
they showed the same moment. A stale premise, not a stale screen.

**What it did produce, which was worth having.** Diagnosing it exposed a real
defect: every Today source returned an empty list on failure and said nothing,
so a source that was failing looked exactly like a source with nothing in it.
"Nothing needs a decision from you" could mean either, and neither a business
nor anyone debugging could tell which. Today now names which parts did not
load and says plainly that the rest is still true. It was that change which
proved the meetings fetch was succeeding, and therefore that CW-8 was not real.

**Standing observation, not a claim.** All three meetings reached COMPLETED
between seven and twelve minutes after creation, roughly three hours before
their scheduled time. That may be the founder exercising them, or it may be
the stranded-session path Aura addressed in 62d09ca. Not investigated here,
and not asserted as a defect. It does raise a presentation question for this
product: a meeting filed under MEETINGS HELD with a scheduled time still in
the future is a strange commercial record, however true.

---

## CW-10 — Today led with last week — CLOSED

**Finding.** Three five-day-old refusals filled the first screen of the day
under a heading that reads as news, while the day itself had nothing in it.

**Fix.** Change is bounded to four days — four rather than one, because a
business does not work every day and a Monday should still show Friday. Older
activity is relocated rather than deleted: it stays on the relationship and
message surfaces that own it.

**The second half, which was the harder one.** An absent CHANGED band and a
quiet stretch rendered identically, so narrowing the window would have made a
working product look like an empty one. The surface now distinguishes them and
says where the earlier activity lives.

---

## CW-12 — Every object was ordered by one timestamp

**Finding.** Today sorted a day as though every object's time meant the same
thing. None of them do: a meeting has a time it is DUE, a delivery a time it
HAPPENED, and a blocked provider no time at all — it is true until somebody
fixes it.

**Root cause.** A single `date` field nothing actually had. Ranking a standing
condition against events requires inventing a timestamp for it, which is how a
permanent blocker ends up buried under yesterday's deliveries.

**Fix.** Items declare which kind of time they carry. Standing conditions lead,
then what is due soonest first, then what happened most recent first — opposite
directions for opposite reasons.

---

## CW-13 — Commercial objects had models and no home

**Finding.** Agreement, obligation, invoice and payment carry real
`relationshipId` keys and appear on no client surface. Production holds zero of
each, for every client.

**Why it was composed anyway.** Zero rows is not the same as no place to put
them. Without a home the first agreement a business signs arrives into a
product with nowhere to show it, and the answer at that point is six empty
cards added in a hurry.

**Treatment.** One continuity rather than four modules, because the sequence is
the point. The empty case is a sentence answering what belongs here, what
creates it and why none exists — and offers no action, because drafting and
issuing are operator work and a button that does nothing is worse than saying
so.

---

## CW-14 — The depth tests were only ever seeing the first screenful

**Finding.** Adding a band above the history made three passing tests fail,
looking exactly like content disappearing.

**It was not a product defect.** A `ListView` builds lazily, and the tests
rendered into the default 800x600 surface, so content that moved below the fold
was never built. They assert about the whole composition and were only ever
seeing part of it.

**Fix.** The depth tests render a viewport tall enough for what they claim to
check. Recorded because it is the third time a measuring instrument, not the
product, produced the failure.

---

## Evidence classification

Kept distinct, because blurring them is how a certification comes to claim more
than it proved.

- **WIDGET / INTEGRATION PROOF** — 314 client tests, 187 backend suites.
- **RUNTIME AUTOMATION PROOF** — `flutter test integration_test -d windows`
  drives the real executable: it boots, resolves its version from package
  metadata, and lands on the front door unauthenticated. **The authenticated
  shell and the Today→Relationships→depth journey are NOT exercised**: without
  a `CERT_TOKEN` the first authenticated call is answered 401 and the app
  correctly signs itself out. The tests say so rather than asserting against a
  login screen.
- **FOUNDER-OBSERVED RUNTIME PROOF** — the workspace rendered against the
  founder's live session: rail identity, banded surfaces, view tabs with
  counts, and meeting lines reading "Held 06:17 today · ran 6 min · was due
  09:16 today".

**Coordinate-driven mouse input is no longer used as product evidence.** One
navigation landed and later identical attempts did not, and moving the window
broke the coordinates outright. A harness that fails to click produces a
failure indistinguishable from a product that fails to respond.

---

## CW-15 — The breakpoint rule audited across the client family

**What was audited.** The Phase-1 separation — structural layout from actual
composition space, accessibility scale from typography — against thirteen real
machine profiles rather than only the one where the defect was found.

**Profiles.** Windows desktop at 1.0x and at 1.75x; a narrow Windows window;
web desktop; web desktop at 200% browser zoom; web narrow; Android phone at
1.0x and at largest text; Android tablet; iPhone; iPhone with Dynamic Type;
iPad; iPad with Dynamic Type.

**A distinction the original defect depended on.** Browser zoom changes the
logical viewport; it is not a text scaler. At 200% a 1440 window presents 720
logical pixels, and that genuinely is a narrow composition space and correctly
becomes phone structure. Android and iOS accessibility text is a scaler on a
viewport that does not change, and correctly changes nothing structural.
Confusing those two is how the original rule was written.

**Result.** All nineteen assertions pass, including that enlarging text never
changes structure on a given machine while still reducing how many panes fit,
and that the rail never exceeds a quarter of a desktop at any scale.

**Evidence class.** WIDGET PROOF of the rule across profiles. Web and Android
release builds compile; neither is exercised at runtime, and iOS cannot be
built from Windows.

---

## CW-16 — Today lost the operator's place

**Finding.** A Today item opened the relationships surface without carrying
where it came from, so going back from a relationship landed on the list
rather than on the day the person was working through.

**Root cause.** The relationships surface already honours a return path. It was
simply never given one from Today.

---

## CW-17 — cupertino_icons warning — HARMLESS TRANSITIVE BUILD WARNING

**Classified, with the chain that proves it.**

1. `cupertino_icons` appears in neither `pubspec.yaml`, `pubspec.lock`, nor
   `.dart_tool/package_config.json`. It is not a dependency at any depth.
2. The built web bundle's `FontManifest.json` declares only MaterialIcons, and
   no font file is bundled under `assets/packages/`.
3. No package this product depends on references `CupertinoIcons` anywhere in
   its `lib/`.
4. This product never imports `package:flutter/cupertino.dart` and never
   constructs a Cupertino widget.
5. In the Flutter SDK, only `lib/src/cupertino/*` references `CupertinoIcons`.
   `lib/src/material/` never does — so nothing renders one without opting in.
6. The icon-rendering references live inside widgets this product does not
   instantiate, such as `CupertinoTextField`'s clear button.

**Why the warning appears anyway.** The icon tree-shaker over-approximates.
Material links parts of the cupertino library for platform-adaptive text
selection, so the `IconData` constants exist in the compiled kernel even though
no reachable widget renders one. The shaker sees a declared family with no font
and says so.

**Is iOS actually exempt, given it cannot be built here?** The reachability
argument is platform-independent: it is about which widgets exist in the
program, not which platform runs it. The one genuinely platform-specific path —
Material text selection adopting Cupertino controls on iOS — lives in
`cupertino/text_selection.dart`, which is not among the files that reference
`CupertinoIcons`. Selection handles are painted shapes and the toolbar buttons
are text.

**Decision.** `cupertino_icons` is NOT added. Adding a dependency to silence a
warning about a font nothing renders would put a megabyte of glyphs into every
build to make a message go away.

---

## Open
- **CW-9 — Orphaned empty state.** "Nothing needs a decision from you." renders
  outside any surface, below the CHANGED band rather than where the missing
  band would be.
- **CW-10 — Today shows five-day-old refusals as change.** Truthful, but a
  temporal surface that leads with last week is not answering "what requires my
  attention today".
- **CW-11 — Retirement verdict owed** on `client_contacts_screen`,
  `client_replies_screen`, `client_outreach_screen`, `leads_screen`,
  `client_notifications_screen`. Their paths are absorbed and their content is
  surfaced elsewhere, but "the content is elsewhere" is not the same as "this
  screen has no place in the product promise", and the reading needed to say
  that has not been done.

---

# Business + Account estate — live inventory

Fifteen surfaces. **None used the workspace system before this pass** — zero
`Ws.` references across all of them — which is what confirmed the estate had
genuinely been left outside the reconstruction rather than merely looking dated.

Status is updated as work proceeds. It is meant to tell the next pass exactly
what remains, not to be read once.

| Surface | Lines | Status |
|---|---|---|
| `business_screen` | 137 | **RECOMPOSED** — says who the business is and whether it can act |
| `account_layer_screen` | 316 | **RECOMPOSED** — grouped by what a person is asking |
| `client_mailbox_screen` | 2084 | **RECOMPOSED** — verdict and reason reunited, one panel removed |
| `client_business_identity_screen` | 807 | **FORM SIMPLIFIED** — split by consequence, semantic widths |
| `client_settings_screen` | 419 | **RECOMPOSED** — readiness leads; restatements name their owner |
| `client_records_screen` | 197 | **RECOMPOSED** — says whose records these are |
| `client_support_screen` | 351 | **STATE/COPY FIX** + backend: request carries the business |
| `client_artifacts_screen` | 403 | **DESTRUCTIVE FLOW FIX** — archive stated as irreversible |
| `client_evidence_screen` | 501 | **DESTRUCTIVE FLOW FIX** — archive stated as irreversible |
| `client_trust_screen` | 464 | **STATE/COPY FIX** — stopped implying verification |
| `client_branding_screen` | 610 | **RECOMPOSED** — says where branding actually appears |
| `client_subscribe_screen` | 874 | **STATE/COPY FIX** — in-workspace path leads with entitlement, not pricing |
| `/account/people` | — | **REVIEWED, ALREADY CORRECT** — withdraw-authority states consequence exactly |
| `/account/plan` | — | **RECOMPOSED** — banded; entitlement already server-derived |
| `/account-deletion` | — | **REVIEWED, ALREADY CORRECT** — the delete flow is exemplary |

## What complexity was real

- **Personal-provider mailboxes.** A `gmail.com` mailbox genuinely cannot
  publish SPF, DKIM or DMARC. The mailbox screen branches on this and never
  renders an impossible task. Left exactly as it was.
- **Transport authority vs operational identity.** Who may send and who is
  seen to send are different questions with different answers.
- **Section-scoped saves on business identity.** Already correct, and the split
  by consequence depended on it.
- **Readiness as a dependent chain.** Layers genuinely depend on the one above,
  and waiting rows genuinely unblock themselves.

## What complexity was accidental

- **The verdict eight panels from its reason.** The mailbox status card led the
  page while the chain explaining it sat below five configuration panels.
- **A panel holding three numbers.** "Activity summary" — dispatches, replies,
  notices — none the subject of an action. Removed; the numbers now caption the
  list they describe.
- **One block treating a legal name and a timezone as the same edit.**
- **Every field full width**, because a stretched Column makes that the default.
- **A "Required" badge on five of six fields**, which is not emphasis.
- **Settings restating three surfaces it does not own**, with its own subject
  fourth.

## What was removed

- The `Activity summary` panel (mailbox).
- The duplicate readiness position (settings).
- Per-field required badges, inverted to mark the rarer `optional`.

## Domain defects the forms exposed

None yet in this estate. The composition problems here were presentation and
information architecture, not domain truth — unlike the meetings work, where
`startedAt` was a genuine gap in the record. Recorded plainly rather than
inflated: not every pass finds a domain defect, and reporting one that is not
there would make the register useless.

## The "Subscribe" concept, questioned before it was styled

**Asked first: is this still the right product concept?**

The backend authority never says "subscribe". `commercial-policy` exposes
`offerings`, `purchase-intent`, `purchase`, `capabilities` and `management`;
`billing` exposes `subscription`. So the domain models this as
**offering → purchase → capability**, and "subscribe" is the funnel's word for
the middle step.

**Verdict: not stale, but doing two jobs.** As an acquisition funnel — choose a
plan, see the price, activate — the screen is correct and stays. What it could
not do is answer the question somebody already inside the workspace arrives
with: *what do I have access to, and what is blocked?* A plan chooser cannot
answer that, and `insideWorkspace` previously changed only the back-links.

**The answer already existed and was never shown.** `/client/capabilities`
reports every capability with `permitted`, `why` and `resolution`, and it is
the same authority that gates the workspace. The in-workspace path now leads
with it — refusals first, since they are why the screen was opened — and the
funnel follows.

**Not renamed.** Renaming the route would have been the cheap half of the
observation and would have changed nothing about what the screen could answer.

**No new domain defect.** The entitlement authority was correct and complete;
it simply had no surface. Recorded as STATE/COPY FIX rather than DOMAIN FIX,
because inflating the category would make the register useless.

## Destructive-action audit — every consequential action in the estate

Traced rather than assumed. For each: what changes, what stops, what is kept,
and whether it can be undone.

| Action | Verdict |
|---|---|
| Delete account | **Already exemplary.** States what is destroyed, that it cannot be undone, that the subscription is cancelled and the session ends, and which records are legally retained. Requires typing DELETE. Untouched. |
| Remove CSV / Google contact source | **Already correct.** Offers a real choice — keep the contacts, or remove only those that came exclusively from that source — with each option's consequence stated. Untouched. |
| Archive artifact | **FIXED.** Said "will be removed from the list", which reads as tidying. |
| Archive evidence | **FIXED.** Said the record is preserved, which is true, and implied a way back, which there is not. |
| Remove branding logo | **Correct as-is, deliberately.** No confirmation, because re-uploading restores it. Ceremony here would be noise, and §10 of the standing brief says confirmation belongs where reversal is difficult or harm is material. |

**The finding behind both fixes.** `archive` sets `archivedAt` and **no endpoint
anywhere clears it**. So archiving is one-way from the client's side: the record
is preserved in the database and the person cannot bring it back. Both dialogs
described the preservation and neither described the permanence, which is the
half that should change somebody's mind.

Both now say both things — the document is kept, and this cannot be undone from
here — and the action reads "Archive permanently" rather than "Archive". The
cancel option says "Keep it", because naming the safe choice is more useful than
labelling it "Cancel".

**Not classified as a domain defect.** The backend behaves exactly as designed;
the surfaces described it inaccurately. STATE/COPY, not DOMAIN.

## Responsive proof — what was actually obtained

Exercised rather than postponed, and classified rather than blurred.

**WIDGET PROOF — obtained.** `responsive_form_composition_test.dart` renders the
primitives introduced during this pass across seven real viewports: web narrow
at 1.0x and 1.3x, Android phone at 1.0x and largest text, iPhone with Dynamic
Type, small tablet, and desktop at 1.75x. Twenty-three assertions, all passing.
It covers the field row, a long legal name with a long consequence line, and
the archive confirmation — which must never clip, because a person who cannot
read the consequence still believes they have.

Primitives rather than screens, deliberately: `_FieldRow` decides every form's
column behaviour, and fixing it in five screens independently is how five
screens come to disagree.

**WEB RUNTIME — obtained at desktop width only.** The built web client was
served and driven in Chrome. It boots, the public surface renders, and its
failure state is already disciplined: *"The public authority could not be
reached. This is different from an empty operating record."*

**WEB NARROW RUNTIME — NOT obtained.** `resize_window` reported success and the
rendered viewport stayed at 1142px across repeated attempts. That is the
instrument failing to do what it claims, and it is the third time in this
program that a measuring tool produced what would have looked like a product
result. No narrow-web runtime claim is made.

**ANDROID RUNTIME — NOT obtained.** `flutter devices` lists Windows, Chrome and
Edge. `flutter emulators` reports no AVD images available. There is no handset
and no emulator on this machine, so system Back, keyboard behaviour, scroll-to-
error and gesture navigation are unexercised. Widget proof covers composition at
Android viewport sizes; it says nothing about any of those behaviours.

**Standing rule reaffirmed:** a harness that cannot observe the thing it claims
to certify is not evidence. Widget proof is not runtime proof, viewport
arithmetic is not a handset, and a resize that silently does nothing is not a
narrow screen.

## CW-18 — The Android emulator cannot be installed on this machine

**Authorized, attempted, and blocked by the host architecture — not by effort
or permission.**

This machine is **Windows on ARM 64-bit** (Snapdragon X Elite X1E80100).
PowerShell reports `PROCESSOR_ARCHITECTURE=AMD64` because it runs under x64
emulation; `Win32_OperatingSystem.OSArchitecture` reports `ARM 64-bit
Processor`, which is the truth.

The SDK repository offers **561 packages to this host and `emulator` is not
one of them**, on any channel including canary. The only emulator-adjacent
entry is `extras;google;Android_Emulator_Hypervisor_Driver`, which is the
x86 AEHD driver and irrelevant here. Google does not ship an Android Emulator
host build for Windows/ARM64.

Checked and working: `adb` 36.0.2 runs, and `arm64-v8a` system images for API
34, 35 and 36 are all downloadable. The images exist; the thing that would run
them does not.

**Consequence.** ANDROID_RUNTIME, SYSTEM_BACK, ANDROID_KEYBOARD,
ANDROID_SCROLL_TO_ERROR and LARGE_TEXT_ANDROID_RUNTIME cannot be obtained on
this machine. They are not deferred by choice.

**What would unblock it**, in order of directness: a physical Android handset
over USB — `adb` is present and would find it; or a cloud device farm; or an
x86_64 machine. None of these is mine to decide.

---

## CW-19 — A real viewport authority for narrow web — PROVEN

**The instrument problem, solved rather than worked around.**

`resize_window` reported success while `window.innerWidth` stayed at 1142
across repeated attempts. Confirmed by asking the page instead of the tool —
which is the standing rule this program keeps rediscovering.

**The mechanism.** `tool/web_viewport_harness.html` loads the built client in a
frame of a controlled width, on the same origin so the frame's own window can be
interrogated. Flutter inside it genuinely lays out against that width; nothing
is scaled after the fact.

**Proven from inside the page**, at every width §5 names:

| requested | innerWidth | scrollWidth | clientWidth | horizontal overflow |
|---|---|---|---|---|
| 1142 | 1142 | 1142 | 1142 | none |
| 834 | 834 | 834 | 834 | none |
| 720 | 720 | 720 | 720 | none |
| 420 | 420 | 420 | 420 | none |
| 390 | 390 | 390 | 390 | none |

`devicePixelRatio` 2.1875 throughout.

Overflow is asserted from `documentElement.scrollWidth > clientWidth` inside the
frame rather than read off a screenshot, because a screenshot is a picture of a
capture and not of a layout — which this program has now been misled by once.

**Scope, stated honestly.** This exercises the PUBLIC surface. The reconstructed
authenticated surfaces are not reachable without a session, so narrow-web
runtime proof of Business Identity, Mailbox readiness, Entitlement, Artifacts
and Evidence is blocked by the same constraint as authenticated automation.
Composition at those widths remains WIDGET PROOF.

## CW-20 — Trust implied verification it does not perform

**Finding.** The credentials surface described itself as holding "other
verifiable credentials", and rendered each one with a coloured status chip —
green for ACTIVE beside things like public liability insurance.

**Traced.** `clientTrustRecord` stores exactly what the business submits. The
status is whatever it picked from a dropdown, validated only against a list of
allowed words. Nothing verifies an issuer, an identifier or an expiry, and
there is no verification code anywhere in the service.

**Why it matters more than most copy.** Trust that overstates itself is worse
than trust not recorded at all, because somebody could rely on it. "Verifiable"
reads as verified; a green chip reads as checked.

**Fix.** The surface now says what is true: what this business DECLARES it
holds, recorded as given, not verified by Orchestrate, with the status being
the business's own statement. Recording declarations is legitimate and useful —
what was wrong was the certainty implied around them.

**Classified STATE/COPY, not DOMAIN.** The service behaves exactly as designed;
the surface described it as something stronger.

---

## CW-21 — My own destructive audit was scoped wrong, twice

**Recorded because the method failed, not the product.**

The first sweep matched destructive dialogs by their title text and reported
the audit complete at five actions. It had missed `'Archive record?'` on the
credentials surface — a third dialog with the identical understatement — and
two more on relationships. A grep that matches the titles it already knows
about finds the cases it already knows about.

**Complete audit, eight actions:**

| Action | Verdict |
|---|---|
| Delete account | Already exemplary — untouched |
| Remove a contact from Orchestrate | Already exemplary — names what is removed, what is NOT affected, that re-discovery can occur, and offers suppression as the better alternative |
| Remove mailbox as a source | Already correct — real choice with each option's consequence |
| Remove CSV / Google source | Already correct — same pattern |
| Archive artifact | FIXED |
| Archive evidence | FIXED |
| Archive credential | FIXED — found only on the third pass |
| Remove branding logo | Correct with no ceremony — trivially reversible |

Five of eight were already right. The lesson is about the sweep, not the
estate: an audit that finds what it went looking for is not an audit.

## The estate is complete — 11 / 11 Business, 4 / 4 Account

**The four acts §13 names, kept distinct.** Checked rather than assumed:

- **Delete my account** — exemplary already. What is destroyed, that it cannot
  be undone, that the subscription ends and the session closes, which records
  are legally retained, and a typed DELETE.
- **Withdraw someone's authority** — exemplary already, and it draws the
  hardest line correctly: the person can authorise nothing further, *and*
  "this does not undo what was already done. Decisions made while the authority
  was valid stay valid, and stay on the record."
- **Revoke a trusted device** — the mildest of the four, and it read more final
  than it is. No confirmation added, because trusting the device again restores
  it and ceremony where reversal is trivial trains people to dismiss the
  dialogs that matter. The consequence is now stated instead.
- **Leave a business** — does not exist as an act in this product. Recorded as
  absent rather than invented.

**Branding.** Opened straight into a logo uploader and never said what a logo
or a colour changes. Traced before claiming: branding is read by artifact
generation and by the email templates, so it appears on documents produced for
the business and on mail sent on its behalf. It says so now, and stays
subordinate to Business Identity — this is how the business LOOKS; what it is
called is decided there.


---

## CW-22 — Physical Pixel, unauthenticated estate

Evidence level: **RUNTIME — PHYSICAL DEVICE**. Pixel 9a, `53061JEBF08485`,
1080×2424 at 420dpi (≈411×923dp, phone class), font_scale 1.0, gesture
navigation, release APK. Everything below was performed on the device by
operating the product, not read out of the code.

Three defects. All three were invisible to static analysis, and the first two
were invisible on desktop because desktop has neither an IME action key nor a
system Back gesture.

### CW-22.1 — The two ways into the product looked disabled — FIXED, VERIFIED

The public navigation menu styles its six browsing links explicitly for the
dark panel. `Sign in` and `Start setup` were the only items with no style at
all, so their text fell through to the ambient light theme's default ink and
rendered visibly dimmer than everything above them — on a dark surface, the
visual language of a disabled control.

Both worked. They only looked unavailable, which is worse than broken: nothing
tells a visitor to try. Proven by tapping `Sign in` and arriving at the sign-in
surface.

They are not browsing links and no longer share that styling. `Sign in` is now
the brightest item, `Start setup` carries the accent as the primary act.
Re-verified on the device after rebuild.

### CW-22.2 — Typing was discarded on the sign-in path — FIXED, VERIFIED

The `Save email on this device` checkbox sat between the email field and the
password field. Typing an email and pressing the keyboard's NEXT key — which is
the key the keyboard offers, and the one people press — moved focus to the
**checkbox**. Everything typed after that went nowhere. The password field
stayed empty, with no error and nothing to explain it, on the way into the
product.

Every handler on that screen is non-null and every field has a controller, so
no reading of the file would have surfaced this. It took using the form on a
phone.

Two causes, both fixed. The option no longer interrupts the credential pair —
it concerns what happens *after* signing in, so it belongs beside the act, not
inside it. And the email field now names its successor rather than trusting
ambient focus traversal to find it.

Verified on the device: NEXT lands in Password, the typed text arrives there,
and the action key becomes `done`.

Checked and **not** systemic: the register form is six fields in sequence with
nothing between them, and the verify-code form is a single field. Only sign-in
had a non-text control inside a field run.

### CW-22.3 — System Back closed the app from every page — FIXED, VERIFIED

From the marketing site and from the sign-in page both, the Android Back
gesture left Orchestrate entirely instead of returning to the previous surface.
Public navigation is `go`, which replaces rather than pushes, so there was
nothing on the Flutter stack to pop. On a phone Back is the primary way people
move; this was most visitors' second gesture.

**The first repair was wrong, and the device proved it.** A custom
`BackButtonDispatcher` is the documented mechanism and it never ran at all —
instrumented and confirmed silent in logcat. Android asks an app whether it
handles Back *before* delivering it, and Flutter answers from the route stack:
one route deep, it registers a null callback and the OS closes the task without
Dart hearing anything. Logcat states it directly:
`CoreBackPreview ... Setting back callback null`. The app has to claim the
gesture in advance, which is what `PopScope` does and a dispatcher cannot.

Back now means **up**. `UpBackHandler` wraps the three shells — public, auth,
workspace — and resolves the parent surface.

Inside the workspace it asks `semanticParentOf`, the same map the visible
return already uses, rather than holding a second opinion: the on-screen Back
and the system Back have to agree about what contains a surface, or one gesture
means two things depending on where a thumb lands. A test asserts that
agreement rather than trusting it.

At an area landing, and at the public front door, Back keeps its real meaning
and leaves.

Verified on the device: home → Pricing → Back returns to home and stays in the
app; Back again at the front door leaves. Eight assertions in
`test/system_back_test.dart`.

### Also proven working, unchanged

- **Field validation refuses correctly.** An invalid email and an empty
  password mark both fields, name both faults, and send no request.
- **The email field summons the right keyboard** — email layout with `@` and
  `.` on the base layer, and a `next` action key rather than `go`.
- **Focused fields clear the IME.** The password field scrolled above the
  keyboard rather than sitting behind it.
- **Back dismisses the keyboard first** and consumes that press, before any
  navigation.
- **Cold start is clean** — no exception, no dropped frame warning in logcat.

### Not yet proven

The fifteen Business and Account surfaces are behind authentication and were
not reached. `AUTHENTICATED_RUNTIME_AUTOMATION = WAITING` still holds: no token
was minted, recovered, or fabricated to get past it.
