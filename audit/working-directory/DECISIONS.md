# Decisions — orchestrate_app

Last updated: 4 Oct 2026

Founder-approved decisions governing this repository. Design decisions are recorded in full in `company/docs/design/DESIGN_DECISIONS.md`; this is the short list an agent needs.

## 30 Sep – 4 Oct 2026: the current product

- **DD-26 (30 Sep):** Direction B, "the path to paid", across every screen. Paper, white cards, ink; amber only for "waiting for your yes", green only for money. Places: Today, Customers, Market, Money, plus Setup.
- **DD-27 (1 Oct):** first-time onboarding is one path from sign-up to Today.
- **DD-29 (1 Oct):** "Who acts for this business" is a setup step; the owner attaches the registration document.
- **DD-30 (1 Oct):** Market shows only businesses that passed every check.
- **DD-31 (1 Oct):** the morning digest on Today and by email at 8 AM.
- **DD-32 (2 Oct):** worldwide reach; Customers lists only real customers.
- **DD-34 (2 Oct):** Setup by kind of business (33 kinds, choices from the server playbook); the old Business pages retired.
- **DD-35 (2 Oct):** Support that knows the business; Account in the current design.
- **DD-36 (2 Oct):** legacy addresses retired outright, not redirected; the old screens deleted.
- **DD-37 (2 Oct):** the visitor assistant on Home and Contact.
- **DD-38 (3 Oct):** the operator work queue answers in place.
- **DD-39 (3 Oct):** a yes writes to them; the business sheet asks one decision (Yes, write to them / Not now / Not for us).
- **4 Oct (in commits, release 2.1.0):** "Write automatically", the owner's standing yes within a daily limit (`32997fb`); each business put as a proposal (`0db4184`); Setup's plan step is last (`d5553ad`); a newer server needs no release (`6fbcaf9`).

## Standing

- The founder is Head of Product Design; agents carry out design work and never hold design authority (charter `PDF-2026-09-27.1`).
- Truthful states only: no surface claims activity or numbers the backend did not report (from the 13 Jul 2026 ROS Phase II ruling, still in force).
- The public category refusals are doctrine, not copy. Do not soften them.

## Superseded

- 13 Jul 2026 ROS Phase II verdict (CLOSED, VERIFIED) is history; its record is in `../orchestrate_backend/representation/inventory/`.
- The "Client sidebar IA" of Home / Operations / Opportunities / Replies / Meetings / Infrastructure / Representation / Records and the seven-faculty operator IA are superseded by DD-26 and DD-36.
