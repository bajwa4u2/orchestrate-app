# Orchestrate customer acquisition

Started 2026-09-15, after the representation-correction program was marked COMPLETE.
This file is the working record for finding, contacting and converting Orchestrate's first
customers. It records facts only. Nothing moves to a later stage without evidence.

## Baseline (2026-09-15)

| Measure | Value | Evidence |
|---|---|---|
| Paying customers | 0 | Stripe: no completed payments (traction classification, 2026-09-04) |
| Pilots / design partners | 0 | same |
| External inbound inquiries | **0** | 14 `PublicInquiry` records read from the operator console (`/ops/inquiries`, read-only, 2026-09-15). Founder confirmed every one is related or internal |
| Human replies ever sent to an inquiry | 0 | every outbound message in all 14 threads is `AUTO_ACK` |

The 14 records: the founder's own onboarding tests (2), a related contact at Hamd Agro Chemicals (3),
a related named contact (1), anonymous one-line chat messages from April and May (7), and the
2026-09-06 communication-certification test (1). The earlier "13 public inquiries" prospect line is
retired: there is no warm inbound pipeline. The first customers come from new outreach.

Operational note: two inquiries still read `NEW` and several `IN_PROGRESS` with no human reply. They
are internal, so no customer is waiting, but the console states are stale.

## Target customer (from the public deck, current acquisition focus)

Owner-led commercial contractors and specialist service firms, roughly 5 to 50 people, Michigan
first. They win work through proposals or tenders, deliver in stages, invoice against work the
customer accepts, and keep the same clients across many jobs.

## Method

1. Target list: named Michigan firms, each with a public source for fit (size, bid or proposal work,
   owner-led). No machine-generated lead lists, no guessed email addresses.
2. Founder outreach from the founder's own mailbox, not through Orchestrate's sending path (the
   reply and meeting-handoff authority defect is still open). Every message approved by the founder
   before it is sent.
3. Discovery call, demo on the firm's own situation, founding use on one real job, conversion.
4. Pipeline stages: TARGET → CONTACTED → REPLIED → CALL HELD → TRYING → PAYING. A firm moves only
   on evidence (a sent message, a reply, a held call, an account in use, a completed payment).

## Founder decisions (2026-09-15)

- Sending mailbox: msbajwa@auraplatform.org, local Outlook app (new Outlook for Windows).
- Outreach direction and Taylor / Southeast Michigan local positioning approved.
- Founder-approved email body (fixed structure, one firm-specific opening sentence), subject lines
  plain; one follow-up only, 7 to 10 days after a sent first message; "no" or equivalent stops.
- First batch gate: five drafts reviewed before anything is sent.
- No mass-mail tooling, no BCC lists, no identical bulk mail. No Orchestrate customer record is
  created because an email was sent; a prospect enters the product only under its admission rules.

## Pipeline

Target list: `CUSTOMER_ACQUISITION_TARGETS.md` (Tier A 5, Tier B 12, Tier C 9, exclusions).

| Firm | Recipient | Stage | Date | Evidence |
|---|---|---|---|---|
| A.J. Miller Mechanical | contact@ajmillermechanical.com | CONTACTED | sent 2026-09-15 | founder reported sent from msbajwa@auraplatform.org; follow-up window 2026-09-22 to 2026-09-25 if no reply |
| Michigan Security Systems | Info@michigancamerasystems.com | CONTACTED | sent 2026-09-15 | founder reported sent from msbajwa@auraplatform.org; follow-up window 2026-09-22 to 2026-09-25 if no reply |
| Jackson Associates | sales@jacksonassociatesinc.com | CONTACTED | sent 2026-09-15 | founder reported sent from msbajwa@auraplatform.org; follow-up window 2026-09-22 to 2026-09-25 if no reply |
| Hennessey Engineers | info@hengineers.com | CONTACTED | sent 2026-09-15 | founder reported sent from msbajwa@auraplatform.org; follow-up window 2026-09-22 to 2026-09-25 if no reply |
| Hutch Paving | info@hutchpaving.com | CONTACTED | sent 2026-09-15 | founder reported sent from msbajwa@auraplatform.org; follow-up window 2026-09-22 to 2026-09-25 if no reply |

Stage moves to CONTACTED only when the founder has sent the message (sent date recorded).

Batch 1 counts (2026-09-15): contacted 5 · replied 0 · calls 0 · trying 0 · paying 0.

## Batch 2 prepared, not sent (2026-09-16)

Batch 1's follow-up window is 2026-09-22 to 09-25, so nothing there is due yet and no reply has been
reported. The unblocked work was Batch 2, and it is now ready for review.

**Four firms cleared, each with an email the firm itself publishes and a dated public fact to open
on:** Lutz Roofing (Shelby Twp., awarded Troy's Police/DPW roofs), Leadhead Construction (Detroit,
Proposal N demolition), Hartwell Cement (Oak Park, Harper Woods sidewalks), Royal Roofing (Orion
Twp.). Drafts are in `CUSTOMER_ACQUISITION_OUTREACH_DRAFT.md`; verification in
`CUSTOMER_ACQUISITION_TARGETS.md`. **Nothing is sent. Stage stays TARGET until the founder sends.**

**Two things need the founder, and neither is engineering judgement:**

1. **Four firms, or wait for five?** The Batch 1 gate was five drafts reviewed. Four cleared. Five
   is not a rule unless it is one.
2. **"Seventeen" or "nineteen" years?** The draft template says nineteen, Batch 1 was sent saying
   more than seventeen, the deck says nineteen. Batch 2 drafts follow what was actually sent. One
   answer fixes the template and the deck together.

**One correction to the record.** Tier B listed `Office@csmmechanical.com` for CSM Mechanical on
09-15. It cannot be confirmed on the firm's own site today and must not be used. Every other
broker-sourced address checked this session failed the same way.

**And one finding that should shape Batch 3.** Of nineteen firms checked against their own sites,
five publish an email address. Email-only outreach therefore reaches about a quarter of this
segment, and the quarter it reaches is not the better-fitting quarter — publishing an address
correlates with nothing. The phone script already exists and has never been used.
