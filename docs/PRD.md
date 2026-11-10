# Relo: Product Requirements Document

| | |
|---|---|
| **Status** | Draft v0.1 |
| **Last updated** | 2026-11-10 |
| **Platforms** | iPhone (native SwiftUI) + web companion (desktop browser) |
| **Working name** | "Relo" (placeholder, easy to rename) |

> A PRD (Product Requirements Document) defines *what* we are building and *why*, so that design and engineering decisions can be checked against it. The *how* lives in [architecture.md](architecture.md) and the ADRs (Architecture Decision Records) in [adr/](adr/).

---

## 1. Problem

Moving for a job means juggling three jobs at once, each in a different tool (or none):

1. **Money.** Relocation packages come in many shapes: lump sums, itemized reimbursement, vendor-paid services, or a mix. People lose receipts, don't know how much of an allowance is left, miss submission deadlines, and forget that relocation money is usually taxable and may come with a repayment ("clawback") clause.
2. **Stuff.** Dozens of boxes leave one home and arrive at another, sometimes via storage. "Which box is the kettle in?" becomes a real question at 11 p.m. on moving night.
3. **Logistics.** Address changes, utilities, movers, DMV (Department of Motor Vehicles) deadlines, and the paperwork of the policy itself.

Existing tools solve one slice each: expense apps (Expensify, Smart Receipts) assume a corporate approval flow; inventory apps (Sortly, Homebox) don't know about moves; moving checklists (Updater) don't track money or boxes. Nobody reads your relocation policy for you.

## 2. Vision

**One app that knows your relocation policy, tracks every dollar against it, and knows where every box is, from the first cardboard purchase to the last unpacked box.**

## 3. Target users

| Persona | Description | Primary needs |
|---|---|---|
| **Lump-sum relocatee** (primary) | Gets a fixed allowance (e.g. $8,500, sometimes "grossed up", meaning the employer covers the tax withholding) and spends it however they like | Budget against the allowance, keep tax-deduction evidence, understand clawback exposure |
| **Itemized-reimbursement relocatee** | Submits receipts to an employer or relocation vendor against category caps | Capture receipts, enforce caps and deadlines, export a submission-ready report |
| **Managed-move relocatee** | Employer's vendor pays the movers directly; employee covers incidentals | Track what's vendor-paid vs. out of pocket, document damage claims |
| **Self-funded mover** (secondary) | No employer package | Box tracking, checklist, budget |

The data model must handle all four package types from day one, even though the first release is tuned for the primary persona.

## 4. Goals and non-goals

### Goals
- **G1.** A user can capture a receipt in under 10 seconds and never re-type merchant, date, or amount by hand in the common case.
- **G2.** A user always knows *allowance remaining*, *spend by category*, and *current clawback exposure*.
- **G3.** A user can find any packed item in under 15 seconds (search, or scan a box's QR (Quick Response) code label).
- **G4.** A user can upload a relocation policy and get structured, human-confirmed terms, each one linked to where it appears in the document.
- **G5.** The app works fully offline (moving trucks, storage units, a new apartment before internet is installed) and syncs when back online.
- **G6.** The project demonstrates production-grade engineering: tests, CI/CD (Continuous Integration / Continuous Delivery), security, accessibility, documented decisions.

### Non-goals (for now)
- Tax or legal advice. The app tags and summarizes; it tells users to confirm with a professional.
- Submitting expenses directly into employer or vendor systems (export only).
- A mover marketplace or booking.
- Android app. The web companion covers non-iPhone access.
- Multi-household or team accounts (sharing with a partner is a v2 candidate, see §9).

## 5. Success metrics

Measured on the author's own move (n = 1, dogfooding) and early TestFlight (Apple's beta-testing service) testers:

| Metric | Target |
|---|---|
| Expenses captured in-app vs. found later on bank statements | ≥ 95% |
| Receipt fields auto-extracted correctly with no edits (merchant, date, total) | ≥ 85% |
| Policy terms extracted correctly on the evaluation set (see [architecture.md §7](architecture.md)) | ≥ 90% of terms, 0 invented terms after verification |
| Median time to locate an item after the move | < 15 s |
| Crash-free sessions | ≥ 99.5% |
| Data-loss incidents after offline use | 0 |

## 6. Domain concepts

| Term | Meaning |
|---|---|
| **Move** | One relocation: origin, destination, key dates. A user may have several over time. |
| **Policy** | The relocation package terms for a move: type, amounts, caps, deadlines, vendor rules, clawback. |
| **Policy term** | One structured fact from a policy (e.g. "Lump sum: $8,500, grossed up"), with a link back to its source page and quote. |
| **Expense** | Money spent on the move, with category, payer (me / employer / vendor), and attached receipt. |
| **Allowance** | Money available under the policy: a lump sum, or per-category caps. |
| **Clawback** | Repayment owed if the user leaves the employer early, usually prorated by month. |
| **Box** | A physical container with a short code, QR label, status, origin room, destination room, and current location. |
| **Item** | A thing inside a box (or loose), optionally with photo, value, and a keep/sell/donate/toss decision. |
| **Location** | Where a box physically is: an origin room, a truck, a storage unit, a destination room. |

## 7. Functional requirements

Priorities: **P0** = needed before the author's move, **P1** = needed during or right after the move, **P2** = later.

Each requirement has an ID so issues, PRs (pull requests), and tests can trace back to it.

### 7.1 Move setup (MOVE)

| ID | Requirement | Priority |
|---|---|---|
| MOVE-1 | Create a move with origin and destination addresses, move date, new-job start date | P0 |
| MOVE-2 | Dashboard shows days until move, allowance remaining, open tasks, boxes packed vs. total | P0 |
| MOVE-3 | Support multiple moves per account; one is "active" | P2 |

### 7.2 Relocation policy (POL)

| ID | Requirement | Priority |
|---|---|---|
| POL-1 | Enter policy terms manually through a guided form (package type → amounts → caps → deadlines → vendor rules → clawback) | P0 |
| POL-2 | Supported package types: **lump sum**, **itemized reimbursement**, **vendor-managed**, **hybrid** | P0 |
| POL-3 | Upload a policy document (PDF (Portable Document Format) or photo) from iPhone Files, camera scan, or web drag-and-drop | P1 |
| POL-4 | AI (Artificial Intelligence) extraction turns the document into draft policy terms; each draft term shows the **source page and verbatim quote** it came from | P1 |
| POL-5 | The user must confirm, edit, or reject every extracted term before it becomes active (human-in-the-loop). Unconfirmed terms never drive budgets or alerts | P1 |
| POL-6 | Extraction flags **ambiguities and questions to ask HR (Human Resources) or the relocation vendor** (e.g. "Does the gross-up count toward clawback costs?") | P1 |
| POL-7 | Explicit consent screen before a document is sent to the cloud extraction service, stating what is sent and how it is handled | P1 |
| POL-8 | Original document stored in the user's private document vault (see DOC) | P1 |

**Acceptance criteria (POL-4/5), using the fictional evaluation fixtures (see [architecture.md §7](architecture.md)):** for each sample policy, extraction produces every term in its expected-terms file (package type and amount, gross-up, required vendor and its conditions, approval requirement, start date, clawback window, proration rule, cap, triggers, repayment deadline, late interest) and flags the ambiguities planted in the fixture as open questions. No term may appear that is not supported by a quote.

### 7.3 Expenses and receipts (EXP)

| ID | Requirement | Priority |
|---|---|---|
| EXP-1 | Capture a receipt with the camera (edge detection, multi-page) or import from Photos/Files/email PDF | P0 |
| EXP-2 | Auto-extract merchant, date, total, tax, and payment method; user confirms or edits | P0 |
| EXP-3 | Suggest a category from the merchant (e.g. U-Haul → Truck rental). Default categories: Packing supplies, Movers, Truck rental, Shipping, Storage, Fuel, Lodging, Meals, Travel, Utilities setup, Deposits, Cleaning, Other; user-editable | P0 |
| EXP-4 | Record who paid: me, employer, or vendor-direct (vendor-direct counts toward clawback "Relocation Costs" but not toward my allowance) | P0 |
| EXP-5 | Manual expense entry with no receipt (with a "missing receipt" flag) | P0 |
| EXP-6 | Allowance view: remaining lump sum, or spend vs. cap per category, with warnings at 80% and 100% | P0 |
| EXP-7 | Tax tags: mark expenses that may qualify for California's moving-expense deduction (FTB (Franchise Tax Board) Form 3913) | P1 |
| EXP-8 | Export: CSV (Comma-Separated Values) and a PDF report with receipt images, filterable by date, category, payer, tax tag | P1 |
| EXP-9 | Submission deadline reminders for itemized policies | P2 |

### 7.4 Clawback tracker (CLAW)

| ID | Requirement | Priority |
|---|---|---|
| CLAW-1 | Show the clawback window (start date → end date) and a countdown | P0 |
| CLAW-2 | Show "If I left today I'd owe ~$X", computed from the policy's proration rule, the relocation-cost basis (allowance + vendor-paid costs, with/without gross-up per the policy), and the cap | P0 |
| CLAW-3 | Clearly label the estimate as informational, with the assumptions used | P0 |

### 7.5 Boxes, items, locations (BOX)

| ID | Requirement | Priority |
|---|---|---|
| BOX-1 | Create a box in ≤ 2 taps; it gets a short human-readable code (e.g. `K-014`, prefix from room) and a QR code | P0 |
| BOX-2 | Assign origin room, destination room, and fragility/priority flags ("open first", "fragile", "heavy") | P0 |
| BOX-3 | Add items by name, photo, or quick multi-photo of the open box; optional value | P0 |
| BOX-4 | Print QR labels: on web, generate a printable sheet (standard label sizes); on iPhone, share to AirPrint | P0 |
| BOX-5 | Scan a QR label with the in-app scanner **or the system Camera app** (the QR encodes a universal link that opens the app, or the web page if the app is not installed) | P0 |
| BOX-6 | Global search across boxes and items, works offline | P0 |
| BOX-7 | Box status lifecycle: packing → sealed → loaded → in storage → delivered → unpacked; bulk status updates by scanning a run of boxes | P0 |
| BOX-8 | Item disposition while packing: keep / sell / donate / toss, with a list view per disposition | P1 |
| BOX-9 | Unpack mode: per destination room, progress and "open first" boxes on top | P1 |
| BOX-10 | Value summary per box for insurance or mover damage claims | P2 |

### 7.6 Move checklist and timeline (TASK)

| ID | Requirement | Priority |
|---|---|---|
| TASK-1 | Generated checklist from a template keyed to the move date (8 weeks out → move day → first 30 days), editable | P0 |
| TASK-2 | Template includes: book movers, notify landlord, USPS (United States Postal Service) mail forwarding, utilities stop/start, DMV address update (California: within 10 days of moving), renter's insurance, update employer/payroll address, voter registration | P0 |
| TASK-3 | Local notifications for due tasks | P1 |
| TASK-4 | Tasks can link to an expense, document, or quote | P2 |

### 7.7 Mileage (MILE)

| ID | Requirement | Priority |
|---|---|---|
| MILE-1 | Log a trip by start/end odometer, or record a GPS (Global Positioning System) route for the moving drive | P1 |
| MILE-2 | Mileage appears in reports and can be tagged for tax | P1 |

### 7.8 Movers, quotes, claims (VEND)

| ID | Requirement | Priority |
|---|---|---|
| VEND-1 | Record mover quotes side by side (price, date window, insurance coverage, required/approved vendor flag from the policy) | P1 |
| VEND-2 | Warn when a chosen vendor is not the policy's required vendor | P1 |
| VEND-3 | Damage claim: photos before packing and after delivery per box/item, exportable claim packet | P2 |

### 7.9 Document vault (DOC)

| ID | Requirement | Priority |
|---|---|---|
| DOC-1 | Store relocation agreement, offer letter, lease, mover contract, insurance; tag by type | P1 |
| DOC-2 | Documents are private to the user, viewable offline once downloaded | P1 |

### 7.10 Account, sync, data (ACCT)

| ID | Requirement | Priority |
|---|---|---|
| ACCT-1 | Sign in with Apple and email magic link (passwordless) | P0 |
| ACCT-2 | All features work offline on iPhone; changes sync when online, with no data loss | P0 |
| ACCT-3 | Web companion: full read access; edit expenses, boxes, policy; print labels; upload documents; export reports | P0 (read, labels) / P1 (rest) |
| ACCT-4 | Export all my data (JSON (JavaScript Object Notation) + files) and delete my account and all data | P1 |

## 8. Non-functional requirements

| Area | Requirement |
|---|---|
| **Privacy** | Documents and receipts contain PII (Personally Identifiable Information): names, salary references, signatures. Store private by default; per-user access enforced in the database, not just the app. No third-party analytics on content. Cloud AI processing only with explicit consent (POL-7). |
| **Security** | No API (Application Programming Interface) secrets in the app binary. Authorization enforced by database row-level security. Short-lived signed URLs for files. |
| **Offline** | Every P0 feature usable with no network. Photos captured offline upload later. |
| **Performance** | Cold start < 1.5 s on a recent iPhone; search results < 200 ms for 1,000 items. |
| **Accessibility** | Dynamic Type, VoiceOver labels, sufficient contrast, meets WCAG (Web Content Accessibility Guidelines) 2.2 AA on web. |
| **Reliability** | Crash-free sessions ≥ 99.5%; sync retries with backoff; idempotent writes. |
| **Cost** | Runs within free/low tiers for a single user (target < $10/month at personal scale). |

## 9. Release plan (summary)

Full plan and dates: [roadmap.md](roadmap.md).

| Release | Theme | Key requirements |
|---|---|---|
| **R0** Foundations | Repo, CI, auth, sync spike | ACCT-1 |
| **R1** Money | Policy (manual), expenses, receipts, allowance, clawback | MOVE-1/2, POL-1/2, EXP-1–6, CLAW-1–3, ACCT-2 |
| **R2** Boxes | Boxes, items, QR labels, search, web labels | BOX-1–7, ACCT-3 (read + labels) |
| **R3** Move ops | Checklist, mileage, documents, quotes, offline hardening | TASK-1–3, MILE-1–2, DOC-1–2, VEND-1–2, BOX-8 |
| **R4** Post-move | AI policy extraction, unpack mode, tax report, claims, polish | POL-3–8, BOX-9, EXP-7/8, ACCT-3/4 |
| **Later** | Household sharing, itemized submission workflow, App Store launch | MOVE-3, EXP-9, BOX-10, VEND-3 |

AI policy extraction (POL-3–8) is deliberately scheduled *after* the first real move: a known policy can be entered manually (POL-1), while boxes and receipts are needed in real life before moving day.

## 10. Open questions

| # | Question | Owner | Status |
|---|---|---|---|
| Q1 | Policies differ on whether a tax gross-up counts toward clawback "relocation costs". Should the user set this per policy, or should extraction infer it? | Product | Open |
| Q2 | Which California FTB 3913 expense categories apply to lump-sum relocatees (affects default tax tags)? | Tax professional | Open |
| Q3 | Is household sharing (partner co-editing) needed before R1? | Product | Open |

## 11. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Scope too large for one developer before January | Features not ready when needed | Priorities tied to real-life dates; R1/R2 first; freeze during move week |
| Offline sync bugs cause data loss | Lost receipts/box contents | Sync spike in R0 before committing (ADR-0004); local-first writes; sync tests |
| AI invents or misreads a policy term | User relies on a wrong number | Quote-verified extraction, mandatory human confirmation, evaluation set (ADR-0005) |
| Real PII leaks into the public portfolio repo | Privacy harm | `private/` is git-ignored; fictional sample policies in fixtures; secret scanning in CI |
