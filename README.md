# Relo

**A relocation companion: know your relocation policy, track every dollar against it, and know where every box is.**

Native SwiftUI iPhone app + Next.js web companion, backed by Supabase. Built for, and dogfooded on, a real job relocation.

> **Status:** Planning (M0). See the [roadmap](docs/roadmap.md).

## Features (planned)

- **Relocation policy, understood.** Enter your package terms, or upload the PDF and let AI (Artificial Intelligence) extract them. Every term links to the quote it came from, and nothing counts until you confirm it.
- **Receipts and allowance.** Scan receipts with on-device text recognition and extraction. See allowance remaining, spend by category, and what you'd owe under a clawback (early-departure repayment) clause.
- **Boxes and items.** QR (Quick Response) code labels, photos, rooms, status from packing to unpacked, offline search.
- **Move checklist, mileage, mover quotes, and a private document vault.**
- **Offline-first.** Works in the truck, the storage unit, and the new apartment before the internet is installed.

## Tech stack

| Layer | Technology |
|---|---|
| iPhone | Swift 6, SwiftUI, Observation, VisionKit, Vision, Foundation Models, local SQLite with sync |
| Web | Next.js, TypeScript, Tailwind CSS, Vercel |
| Backend | Supabase: Postgres with RLS (Row-Level Security), Auth, Storage, Edge Functions |
| AI | Claude API for policy extraction (structured outputs, quote verification, human review) |
| Quality | Swift Testing, XCUITest, Vitest, Playwright, pgTAP, GitHub Actions, Sentry |

## Documentation

| Doc | What's in it |
|---|---|
| [PRD](docs/PRD.md) | PRD (Product Requirements Document): problem, users, requirements with IDs, metrics, release plan |
| [Architecture](docs/architecture.md) | System design, data model, extraction pipelines, sync, security, testing, CI/CD (Continuous Integration / Continuous Delivery) |
| [Roadmap](docs/roadmap.md) | Milestones, dates, done criteria, working practices |
| [ADRs](docs/adr/) | ADRs (Architecture Decision Records): why each major technical choice was made |

## Getting started

Prerequisites: Xcode 26+, Node 24 (see `.nvmrc`), [XcodeGen](https://github.com/yonaskolb/XcodeGen), the [Supabase CLI](https://supabase.com/docs/guides/local-development), and a Docker runtime (e.g. Colima: `colima start`).

```bash
make help          # list commands
make db-start      # local Supabase (Postgres, Auth, Storage)
make db-test       # schema lint + pgTAP RLS tests
make web-install && make web-test
make ios-project   # generate apps/ios/Relo.xcodeproj, then open it in Xcode
make ios-test      # RelocDomain unit tests
```

For device builds, copy `apps/ios/Config/Local.xcconfig.example` to `Local.xcconfig` and set your Apple team ID.

## Repository layout

```text
apps/ios/      SwiftUI app + local Swift packages
apps/web/      Next.js web companion
supabase/      Migrations, RLS policies, Edge Functions, database tests
schemas/       Shared JSON Schemas (codegen to Swift + TypeScript)
docs/          Product and engineering docs
```

## Privacy

Relocation documents contain sensitive personal data. Real documents are never committed: `private/` is git-ignored, and all fixtures and demo data are fictional.
