# Client workspace reconstruction — findings register

A running record of what was found, what caused it, and what proved the fix.
Its purpose is continuity: so a later pass does not rediscover the same thing,
and so a claim in a commit message can be checked against evidence.

Findings are numbered `CW-n`. Anything still open says so.

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

## CW-7 — A capture artifact that looked exactly like a content overflow

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

## Open

- **CW-8 — Today shows no meeting.** A meeting exists at 13:16Z, bound, ahead,
  and `needsYou` renders empty. `_safeList` swallows the failure, so the screen
  cannot say whether the request failed or the list was genuinely empty. Not yet
  diagnosed; the swallowing is itself a finding.
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
