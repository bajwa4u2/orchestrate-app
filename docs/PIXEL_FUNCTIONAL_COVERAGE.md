# Pixel runtime coverage — Business + Account estate

Physical Pixel 9a `53061JEBF08485`, 1080×2424 at 420dpi (≈411×923dp), release
APK, founder-authenticated session. Evidence is what the product did when it
was used, on this device. Nothing below is inferred from source.

Grouped by task rather than by tap target: the question this register answers
is what a real operator can do here.

| Surface | Task | Expected | Actual | Evidence | Defect | Fix | Retest |
|---|---|---|---|---|---|---|---|
| Business hub | See who this business is | Trading + legal name as stored | **Both reported unset in red** while Business identity showed "Aura Platform LLC" | Screens 21, 29 | Hub read `legalName` off the response envelope, not `envelope['profile']` — always null | Unwrapped; test asserts both surfaces agree on the shape | Owed on device |
| Business hub | See whether it can act | Sending verdict + blockers | "Nothing can be sent yet" / "Sending is held — not part of what your organisation has activated" | Screen 21 | — | — | PASS |
| Business hub | Reach owned configuration | Rows to each owned surface | Business identity, Branding, Market and targeting, Mailbox and sending, Credentials, Evidence, Artifacts | Screens 21-22 | Records, Support, Settings, Entitlement are not reachable from either hub | Not yet addressed | Open |
| Account layer | Orient and switch section | Three tabs + banded rows | Loads; breadcrumb "< Account / Security"; visible back arrow present | Screen 25 | Active "Account & security" chip is clipped at the right screen edge | Not yet fixed | Open |
| Account layer | Know where I am | Bottom nav reflects location | **Bottom nav highlights "Today"** while on /account/security and /client/settings | Screens 25, 26 | Nav misreports location on account surfaces | Not yet fixed | Open |
| Workspace settings | Orient to owned config | Router surface only (§13) | **Holds a full Signature identity form** — display name, role, business name, website, scheduling link, compliance footer, Save | Screen 27 | §13 FAIL: Settings owns configuration, incl. a business name separate from Business identity's | Not yet addressed — authority question for the founder | Open |
| Workspace settings | Return | Breadcrumb / visible return | **None** — no title, no breadcrumb, no back control | Screen 26 | `semanticParentOf('/client/settings')` yields no parent, so the shell draws no return | Not yet fixed | Open |
| Workspace settings | Read readiness | Correct plural | "1 readiness item**s** need attention" | Screen 26 | Copy defect | Not yet fixed | Open |
| Business identity | Load current state | Stored identity | Loads; "Required passed", Completeness 100/100, Legal name "Aura Platform LLC" | Screen 29 | — | — | PASS (load only) |
| Any workspace surface | System Back | Up to semantic parent | **Exited the app** from /client/settings and Business identity | Screens 26-30 | Open — in-process test says the shell claims Back and moves correctly; device disagrees | Cause not established | Blocked on session |
| Today | Load | Real attention state | Loads: "1 thing needs you", NEEDS YOU + CHANGED bands, real suppression and refusal records | Screen 20 | "NEEDS YOU" item reads "nothing is needed from you" — header and body contradict | Not yet fixed | Open |
| Outbound compliance | Follow the refusal's instruction | The named field exists where named | "Add one to your compliance footer under **Business identity**" — the compliance footer field is in **Workspace settings**; Business identity has a differently-named "compliance constraints" field | Screen 20 + `compliance-footer.ts:178` | Refusal names the wrong surface, and the wrong-but-similar field exists at the named one | Not yet fixed | Open |

## Session note

`flutter install` uninstalls the previous APK, which clears app data and signs
the device out. That is what ended the first authenticated pass — not an
errant tap. Any future device work should batch its rebuilds and expect to
re-authenticate after each install.

## Authenticated pass — second session

Founder-authenticated. `adb install -r -d` replaces the APK **in place** and
preserves the session; `flutter install` uninstalls first and signs the device
out. Use the former on a shared device.

| Surface | Task | Expected | Actual | Evidence | Defect | Fix | Retest |
|---|---|---|---|---|---|---|---|
| Business hub | See who this business is | Names as stored | "Aura Platform" / "Aura Platform LLC", neutral tone | Screen 41 | Was always "not set" (envelope read) | Unwrapped the profile | **PASS on device** |
| Business identity | Load | Stored identity | Required passed, 100/100, three identity classes each with its own Save | Screens 42, 51 | — | — | PASS |
| Business identity | Edit a field | Accepts input, right keyboard, stays visible | Select-all replace worked; view scrolled to keep the focused field above the IME | Screen 52 | — | — | PASS |
| Business identity | Save | Request occurs | Wrote successfully | Screens 54-55 | **No confirmation visible** — the "Latest save" panel renders at the top of the page, several screens above the button pressed | Confirmation now shown where the person is; errors still persist in a panel | Owed on device |
| Business identity | Persist | Reload shows authoritative value | `America/New_York` survived navigate-away-and-return; restored to `America/Detroit` and that survived too | Screens 57, 61 | — | — | **PASS — not optimistic state** |
| Business identity | Class isolation (§4) | One class must not mutate another | Legal name and trading name unchanged after saving "Where it operates" | Screen 58 + hub | — | — | **PASS** |
| Business identity | Return | Breadcrumb and system Back agree | Both land on Business hub | Screens 43, 56 | — | — | **PASS** |
| Mailbox readiness | Read the verdict | One coherent verdict → reason → consequence → action | **Three statements, two false.** Banner: correct cause. Card: "Next: Capture the correlationId and contact support". Chain row: "Each layer above must be verified" — while all four showed Attached/Connected/Authorized/Verified | Screens 63, 64 | Verdict duplicated; support fallback reached because the entitlement blocker had no branch; chain row asserted a cause it cannot know | Banner stands down when the card can speak; entitlement blocker now says "Activate it from Plan & billing"; chain row speaks only about the chain | Owed on device |
| Mailbox readiness | Refresh | Re-reads state | Ran, no error, state correctly unchanged | Screens 65-66 | — | — | PASS |
| Mailbox readiness | Operational identity | Real values | Business, sending domain, mailbox, provider Authorized, SPF/DKIM/DMARC Verified | Screen 64 | — | — | PASS |
| Trust / Credentials | Declaration vs verification (§11) | Business declares ≠ Orchestrate verifies | "Recorded as given. Orchestrate does not verify these, and the status beside each one is the business's own statement about it." | Screen 67 | — | — | **PASS** |
| Trust / Credentials | Empty state | Honest | "No credentials yet" with a route to add | Screen 67 | — | — | PASS |
| Trust, Evidence, Artifacts, Branding, Market and targeting | Return + location | Breadcrumb present, nav honest | **No breadcrumb; nav highlighted Today** | Screen 67 | The hub opens these on `/app/...` paths absent from the workspace map and the bar's absorbs — five surfaces | Mapped and absorbed; a test now asserts every hub destination is both | Owed on device |
| System Back | Whole workspace | Up to the semantic parent | Business identity → Business → Today → leaves the app | Screens 45-50 | Was closing the app from every workspace surface (predictive back) | Opted out of predictive back | **PASS on device** |
| Today | Group by what needs you | Only actionable items | Refusal moved to CHANGED; false "1 thing needs you" gone | Screen 44 | — | Honours `actionRequired` | **PASS on device** |

### Responsive check prompted by a peer report

Aura had a band of widths with no navigation: its rail and its replacement bar
asked different constants. Orchestrate does not have that shape — one
predicate, `phone ? bottomBar : rail`, decides both, and the rail collapses to
icons rather than disappearing. Checked rather than assumed.

## §13 / §14 — an ownership question, not a defect to fix unilaterally

Workspace settings is described as "Preferences for this workspace" and is
reached from Account & security. It currently holds at least three things that
belong to other owners:

- **Signature identity** — display name, role, **business name**, website,
  scheduling link and the **compliance footer**. The business name is a second
  naming authority alongside Business identity's legal and trading names, and
  the compliance footer is the field the postal-address refusal sends people to.
- **Trusted devices and Revoke** — a person's sessions, which is a security
  concern about the PERSON, not a preference of the workspace.
- **Readiness status cards** — Setup, Billing, Authorization, Mailbox, which
  restate what the Business hub and Mailbox already own.

The consequence for §14's distinction is that **Account & security contains no
security controls**. It is three links out, and the actual security surface sits
inside a screen labelled preferences.

Recorded rather than restructured. Where each of these belongs is an authority
decision about the estate, not a defect with an obvious right answer, and moving
a naming authority is not something to do as a side effect of a device pass.

## Canonical ownership — corrected

Founder decision. Workspace settings had become the screen everything landed
on, because it was the one nobody argued about. Accumulation is not ownership.

| Fact | Old owner | Canonical owner | Migration | Proof |
|---|---|---|---|---|
| Trusted devices, revoke | Workspace settings | **Account & security** | Controls moved; same repository, same endpoints, same revoke semantics | Suite; device owed |
| Business name (legal, trading) | Business identity **and** the signature card | **Business identity only** | Signature write path retired; renderer resolves the canonical name at render time; stored values left in place, no longer read for this field | `estate_ownership_test` |
| Postal / compliance address | A free-text "compliance footer" on the signature card | **Business identity** | New Registered address section writes the canonical designated-address record (structured, supersedes, records provenance) — no new table | `estate_ownership_test`; device owed |
| Outbound signature | Workspace settings | **Mailbox and sending** | Card rendered by Mailbox, beside the readiness that refuses without it | `estate_ownership_test` |
| Business readiness | Workspace settings restated it | **Business hub** | Metric strip, blocker list, setup and billing panels removed from Settings | `estate_ownership_test` |
| Records availability | Workspace settings | **Records** | Panel removed | `estate_ownership_test` |
| Billing state | Workspace settings | **Plan & billing** | Panel removed; Settings points at the owner | `estate_ownership_test` |

Workspace settings now owns: where things are configured (pointers), the legal
references, and sign-out. It fetches nothing. That is the honest size of what it
actually owns, and it is deliberately not padded — `screen_memory_test` exempts
it explicitly, because there is no longer a request to remember.

**Residual, stated rather than guessed.** `resolveComplianceAddress` still
accepts a signature authored block as a fallback address source when no
designated address exists. Retiring that fallback outright would newly refuse
any business whose block happens to be a usable address, and I cannot enumerate
those without reading other tenants' data. For this business the block is empty
and the designated record is now the only path, so the authority is single here;
the fallback remains for anyone already relying on it. Retiring it is a data
question, not a code one.

**Data check (§11).** `signatureJson.businessName` read "Aura Platform LLC" and
`client.legalName` reads "Aura Platform LLC" — SAME VALUE, unambiguous
duplicate, converged onto Business identity with nothing overwritten. The
compliance footer was empty, so no address conflict existed to resolve.

## Ownership correction — verified on the Pixel

| Requirement | Result | Evidence |
|---|---|---|
| Account & security owns trusted devices | **PASS** — "WHERE YOU ARE SIGNED IN" band renders the real device list with Revoke | Screens 71, 72 |
| Revoke affects only the intended device | **PASS** — the targeted row flipped to Inactive and lost its Revoke; every other device stayed Active, including the current session | Screens 73, 74 |
| Revoke ≠ delete account ≠ withdraw authority | **PASS** — still signed in, account intact, authority untouched, and the surface says so in words | Screen 76 |
| Inactive devices offer no Revoke | **PASS** — you cannot end what has already ended | Screen 73 |
| Devices are distinguishable | **PASS after fix** — every device was named "Current device"; new sign-ins carry a real name and rows now show trusted/expiry dates | Screens 71 → 72 |
| Workspace settings is preferences only | **PASS** — no devices, no readiness, no business name, no signature; states plainly that it holds no preferences yet | Screens 77, 78 |
| Workspace settings has a return | **PASS after fix** — breadcrumb "< Account / Workspace settings"; it previously had none | Screen 77 |
| Signature sits with communication | **PASS** — rendered on Mailbox and sending | Screens 82, 83 |
| Mailbox states its verdict once | **PASS after fix** — the duplicate banner is gone | Screen 80 |
| The chain row no longer asserts a false cause | **PASS after fix** — "Everything above is in place, so the reason is not the mail setup" | Screen 83 |
| Visible return = system Back | **PASS after fix** — the account frame hardcoded Today while system Back went to the semantic parent; both now ask the map | Screen 75 |
| Bottom bar honest on account surfaces | **PASS** — not drawn where none of its four destinations is current | Screen 77 |

### Not verifiable on the device yet — backend not deployed

The client changes ship in the APK. These are committed and test-green but run
on Railway, which has not been deployed, so the device still shows the old
behaviour:

- the entitlement blocker branch, so Mailbox still reads
  "Next: Capture the correlationId and contact support"
- the postal-address refusal naming Business identity
- the retired signature business-name writer
- the Registered address read/write path on Business identity

Deploying production is a founder decision and was not requested, so nothing
was pushed.

## Workspace identity — business primary

Founder observation: the shell presented the operator where the business should
lead. Frozen hierarchy: BUSINESS WORKSPACE primary, ACTING HUMAN secondary.

| Surface | Before | After |
|---|---|---|
| Phone app bar | Surface name ("Today") + person avatar | **Business mark + trading name**, person still in the account control |
| Desktop rail | Business name, no mark; nothing when collapsed | Mark beside the name; **mark survives collapse** |
| Account estate | — | **Person leads**, because there the person is the subject; leaving restores the business |
| Ownership | — | Shell reads Branding and Business identity, writes neither; logo presence keyed to the business it resolved for, so a second business shows its own mark |
| No-logo fallback | — | **Business initial, never the operator's** |

The app bar replaced the surface name rather than crowding beside it: every
screen already states its own name in its heading, its breadcrumb, and the
selected destination. The app bar was the fourth place saying "Today" and the
only place that could say whose Today it was.

**A defect of mine inside this fix.** The mark read `assets['logo_primary']`;
the response names the asset `logo` — `logo_primary` is the asset *type* in the
URL and upload field. So a business with a working logo got the fallback
initial. This is the same class as the Business hub envelope defect: assuming a
payload shape rather than reading the code that already works with it. Both fail
silently, because a missing key and an absent value are indistinguishable.
Fixed; a test asserts the shell and the Branding screen read the same key.

## Remaining surfaces — code-level pass while the device was occupied

| Surface | Checked | Result |
|---|---|---|
| Records | Payload shape against `/client/records` | **Correct** — `{agreements, billingDocuments:{invoices,receipts,statements,reminders}, authorizations, sourceRecords:{imports}}` matches every read |
| Branding | Colour save feedback and validation | Hex validated before save; success and error both reported next to the control |
| Personal account | Profile save | Dialog closes and the surface refreshes from the server — the changed values are the confirmation |
| Personal account | Delete account | **Exemplary, not executed.** Names permanence, cancellation, sign-out, and is honest that legally-required records are retained. Typed DELETE. Classified as a production actuation boundary per §15 |
| Whole client estate | Keys read that the backend never emits | 2 of 395, both operator/health, none in the client estate |

The key scan's limit, stated plainly: it finds keys absent *everywhere*, and
neither defect this session was that shape — `legalName` and `logo_primary` both
exist in the backend and were read at the wrong *level*. Nesting still has to be
checked per payload, which is why Records was verified by hand.

## Final device pass — remaining surfaces and deployed corrections

| Item | Result | Evidence |
|---|---|---|
| Workspace identity, business leads | **PASS** — real logo + "Aura Platform" in the app bar | Screen 100 |
| Identity on the account estate | **PASS** — person leads (M / Muhammad Sakhawat) | Screen 102 |
| Return restores the business | **PASS** — full cycle proven | Screen 103 |
| Entitlement guidance (deployed) | **PASS** — "Activate it from Plan & billing" replaces the correlationId instruction | Screen 101 |
| The named next step is reachable | **PASS** — the button navigates to Plan & billing | Screen 102 |
| Registered address (deployed) | **PASS** — populated designated address, with the DESIGNATED-source copy | Screen 106 |
| Mailbox states its verdict once | **PASS** — no duplicate banner | Screen 101 |
| Artifacts — generate | **PASS** — type choice, `Generating…` then `Ready`, no false success, persisted across navigation | Screens 109-112 |
| Artifacts — archive wording | **PASS** — "This record will be preserved, but it cannot be restored from this workspace", Keep it / Archive record | Screen 114 |
| Artifacts — archive executed | **PASS** — on a record generated for the purpose; production evidence untouched | Screen 115 |
| Evidence | **PASS (load)** — breadcrumb, filters, honest empty state. Archive not exercisable: no record exists and none was fabricated | Screen 107 |
| Records | **PASS** — ownership distinction leads the surface; honest empty classes | Screen 119 |
| Support | **PASS (load)** — honest empty state and response expectation. Submission deliberately not executed | Screen 117 |
| Plan & billing | **PASS** — honest commercial model; states that activating a plan never authorises anyone to act | Screen 118 |
| Branding | **PASS** — copy correction live on web; logo confirmed present by the founder | Founder screenshot |

### Defect found and fixed in this pass

**Support had no way in on a phone.** Its entry is a `_RailAction`, and the rail
exists only on desktop. On a phone it was reachable by knowing to search for it,
or from Billing — while the account menu offers "Tell us something", which is
feedback, not a support case. Somebody who needed help had nowhere obvious to
go. Added to the Settings pointer list, which is now the surface that says where
things live.

### Deliberately not executed

- **Support submission** — would reach a real destination (§10). The payload is
  proven at the canonical request path by test instead.
- **Delete / deactivate account** — verified by reading the confirmation, which
  names permanence, cancellation and sign-out and is honest about legally
  retained records, behind a typed DELETE. Classified as a production actuation
  boundary (§15).
- **Evidence archive** — no record exists, and none was fabricated to create one.

## Containment scope repair — acquisition stopped governing capability use

The founder asked why sending was blocked when billing and authority were both
fine. It was neither. `executionActivated` was a literal `false` for every
client, written when public commercial activation was closed on the reasoning
that nobody had bought anything — so GOVERNED_EXECUTION was refused
unconditionally, regardless of grant, state or readiness.

Three questions were being answered by one flag: may we SELL a plan, does this
client HOLD one, does a held plan INCLUDE a capability. Only the first was meant
to be closed.

| Gate caller | Class | Disposition |
|---|---|---|
| `billing.service.ts` — may a checkout be created | ACQUISITION | kept, still closed |
| `store-readiness.service.ts` — which store rails are offered | ACQUISITION | kept, still closed |
| `public-commercial-projection.ts` — what the public site says | UI PRESENTATION | kept, still closed |
| `commercial-entitlement.service.ts` — `executionActivated` | **CAPABILITY USE** | **repaired** — derived per client |

Inappropriate capability-use dependencies remaining: **0**.

Execution is now derived from the client's own entitlement source.
`PAID_SUBSCRIPTION`, `INTERNAL_OPERATIONAL` and `LEGACY_GRANTED_ACCESS` confer
it; `STORE_REVIEW` does not — on its own terms, being a reviewer fixture that
must not send commercial mail in a real business's name — and neither does
`NONE`. No client id is special-cased.

`CommercialGrant` carries no `expiresAt`, only `revokedAt`, so an unbounded
grant runs until somebody with authority ends it.

### Proven on the device after deploy

| Before | After |
|---|---|
| "Dispatch blocked · Orchestrate acting on your behalf is not part of what your organisation has activated" | **"Dispatch ready · hello@auraplatform.org · SPF / DKIM / DMARC verified"** |
| Dispatch eligibility: **Blocked** | Dispatch eligibility: **Eligible — granted** |
| Business hub: "Nothing can be sent yet" / "Sending is held" | **"Ready to write to counterparties. Sending is configured and working."** |
| Mailbox offered "Activate it from Plan & billing" | No commercial refusal shown at all |

Two independent surfaces reading the same backend authority agree, so the proof
reaches the execution decision rather than stopping at UI enablement. Nothing
was sent to any recipient.

Public commerce remains closed: Plan & billing still offers no purchase path and
still reads "Internal operational access — granted directly rather than
purchased, so it does not depend on a billing period".
