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

## Observed, not a defect

- **cupertino_icons font warning** on web and Android builds. Nothing in this
  product references `CupertinoIcons`, and the package is in neither the
  pubspec nor the lockfile — it is a transitive declaration. Recorded rather
  than dismissed: a dependency could render one on iOS, which cannot be
  verified from Windows.

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
