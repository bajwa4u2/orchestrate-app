# Public conversion path — finding, verification and correction

**Date:** 2026-09-16
**Source:** Applicant diagnostic, Ali Haseeb (Founding Commercialization & Strategic Partnerships
Lead candidate), independently verified against the live site.
**Status:** Partly implemented. One decision outstanding — see §4.

This finding was **surfaced by an external applicant, not by our prior GTM doctrine.** It is
recorded that way deliberately. It was not something we already knew.

---

## 1. What he said

> "Right now a contractor who hears about Orchestrate has nowhere to land that converts, and that is
> fixable in weeks not quarters."

Also, on language:

> "Pre-revenue companies almost always describe their product the way the founder thinks about it
> rather than the way the buyer experiences the pain… A contractor does not care about any of that
> framing. He cares that the quote goes out same day and the invoice does not sit for two weeks."

## 2. First verification was WRONG, and the error is recorded

The claim was first checked with `curl` against `https://orchestrateops.com/`, which returned no
form, no contact CTA, no mailto and no store links. That was reported internally as confirmation.

**It was not.** `curl` executes no JavaScript, so what came back was the `<noscript>` fallback, not
the page. Orchestrate's root is a Flutter application; the rendered page is a different surface
entirely. This is precisely the failure the repo's own rule warns about — *served HTML is not the
output* — and it was repeated here.

**What the rendered public page actually has, verified in source:**

- Primary CTA **"Run the Free Diagnostic"** → `/diagnostics`
- Secondary CTA **"Talk to Orchestrate"** → opens the support drawer → submits name, email and
  message into the **PublicInquiry** system that feeds the operator console
- `PublicAppAcquisition` is mounted in `PublicShell`, so **all three store links appear on every
  public page**

All three store URLs were checked live on 2026-09-16 and return HTTP 200:

| Store | URL | Status |
|---|---|---|
| Apple App Store | `apps.apple.com/us/app/orchestrate-operations/id6772025079` | 200 |
| Google Play | `play.google.com/store/apps/details?id=com.orchestrateops.app` | 200 |
| Microsoft Store | `apps.microsoft.com/detail/9P811J2LTNVG` | 200 |

**So "no CTA, no contact path, no store links" was false of the rendered page.** It was true only of
the `<noscript>` fallback.

## 3. The real defect, which is larger

The rendered public home page and every other buyer-facing surface **describe two different
products**.

| Surface | What it sells |
|---|---|
| Outreach emails (Batch 1 & 2), `<noscript>`, structured data, `/deck` | Customer work **from opportunity to payment** — quote, agreement, delivery, sign-off, invoice — for service businesses and owner-led contractors |
| **The rendered public home page** | **"Governed Revenue Automation"** — market-signal discovery, governed outbound under a verified sending identity, SPF/DKIM/DMARC, mailbox OAuth, deliverability posture |

Evidence, from `lib/features/public/screens/public_home_screen.dart` (1,068 lines):

- the word **"contractor" appears 0 times**
- invoice / sign-off / agreement appear **once in total**
- the headline is *"Governed Revenue Automation"* and the hero promises *"qualified B2B opportunities
  and governed outreach without building a revenue operations team"*

**Why:** the representation-correction programme (2026-09-15) updated `web/index.html` metadata and
noscript (`eaba637`) and the deck (`4e55ba6`). The rendered page was last touched by `eaf04ac`,
which predates it. **The correction never reached the screen a buyer actually sees.**

Nine cold emails are currently in flight telling contractors we handle the line from opportunity to
payment. A recipient who visits the site lands on a page about DNS records and mailbox OAuth.

## 4. Decision required — not taken unilaterally

Reconciling those two descriptions is a **positioning and product-doctrine change**, which the
implementation brief explicitly reserved. Three options, none chosen here:

1. Bring the rendered page in line with the approved representation (opportunity → payment, service
   businesses and contractors), matching the outreach, noscript, deck and structured data.
2. Keep the governed-outbound positioning on the page and change the outreach to match it.
3. Establish that they are two genuine offers and separate them onto distinct surfaces.

**Nothing on the rendered page has been changed.**

## 5. What was implemented

- **`web/index.html` noscript rewritten** so the crawler- and assistant-facing fallback carries a
  real buyer path: *See how it works* (`/demo`), *Talk to us* (`mailto:hello@orchestrateops.com`,
  with the plain statement that Orchestrate is live and we are working directly with first
  customers), and *Get Orchestrate* (all three verified store links). The **investor overview and
  company overview are demoted** below a rule, presented as an investors-and-partners line rather
  than a buyer exit.
- **`docs/strategy/CUSTOMER_DISCOVERY.md`** opened as the durable record for real buyer
  conversations. It contains **zero rows**; no synthetic conversations were created.

## 6. Not done, deliberately

- Pricing unchanged at $29.99 / $299.99 — recorded as **unvalidated by any real buyer**.
- No discounts, pilots, free tiers or new packages.
- No site redesign, no funnel, no testimonials, no claimed customers.
- No change to the commercial-lead decision; SBDC, accelerator, investor and partnership activity
  continue in parallel.
- **`hello@orchestrateops.com`** was used as the contact address because it is a live, signed-in
  mailbox. Confirm it is the address you want published, or name another.
