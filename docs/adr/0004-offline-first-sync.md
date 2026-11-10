# ADR-0004: Offline-first storage and sync on iPhone

- **Status:** Accepted (after the R0 sync spike, 2026-11-10)
- **Date:** 2026-11-10

## Context

The PRD (Product Requirements Document) requires every P0 feature to work with no network (G5, ACCT-2). Real moments where this matters: inside a moving truck, a storage unit, a garage, and a new apartment before internet is installed. Data loss (a receipt or a box's contents) is the worst failure.

Supabase's client libraries are online-first; they don't provide an offline database with sync.

## Decision

- The iPhone app reads and writes a **local SQLite database**. The UI never waits on the network.
- **PowerSync** keeps that database in sync with Supabase Postgres. PowerSync is a sync engine: a service that reads Postgres changes through logical replication and streams each user's rows to their devices, plus a Swift SDK (Software Development Kit) that owns the on-device SQLite database and a durable upload queue.
  - **Download:** sync config streams "rows where `user_id` = me" (mirrors the RLS (Row-Level Security) rule).
  - **Upload:** our connector replays the local write queue against PostgREST (Supabase's generated REST API (Representational State Transfer)), so RLS and database constraints still apply.
- Client-generated UUIDs (Universally Unique Identifiers), so offline creates never collide.
- **Hosting:** self-hosted PowerSync in Docker for local development (`spike/powersync/docker-compose.yaml`); PowerSync Cloud free tier for staging; self-hosting the Apache-2.0 service is the exit route if hosted pricing or terms stop fitting.

## Spike results

Harness: `spike/powersync/` (a Swift command-line tool plus `run-spike.sh`, which reruns everything from a fresh user). Each step runs as a separate process so a "force-quit" is a real `SIGKILL`. "Offline" points every endpoint at a closed port while the SDK is connected and retrying, like an app running with no signal. Run twice, identical results.

| # | Exit criterion | Result |
|---|---|---|
| 1 | Swift SDK builds under Swift 6 strict concurrency in our package layout | **Pass.** PowerSync Swift 1.17.0 alongside `RelocKit`, Swift 6 language mode: 0 errors, 0 warnings in our code (one packaging warning inside the SDK). Built for macOS; iOS build happens when it moves into the app. |
| 2 | Offline writes survive a kill; zero loss after reconnecting | **Pass.** Offline: 1 move + 50 expenses created, 20 edited, 5 deleted (76 queued writes), then `SIGKILL`. After reopening, all 76 were still queued. Online: uploaded and confirmed in ~2 s; device, server, and a second fresh device held identical rows (45 expenses, 1 move). *Boxes don't exist yet, so edits and deletes stood in for the 20 boxes.* |
| 3 | Concurrent web + offline-phone edit converges | **Pass, with semantics to note.** Phone (offline) set `merchant` and `amount`; web later set `merchant` and `notes`; phone synced. Both devices and the server converged to `merchant` = phone's value, `amount` = phone's value, `notes` = web's value. |
| 4 | Pricing and limits acceptable | **Pass.** Service and Swift SDK are Apache-2.0. PowerSync Cloud Free (pricing page, 2026-11-10): 2 GB synced/month, 500 MB hosted, 50 peak concurrent clients, 2 instances. Caveat: free projects are deactivated after 1–2 weeks of inactivity (the page states both) and must be reactivated manually. Pro starts at $49/month. |

Web-to-device sync also worked (an expense inserted through PostgREST appeared on the phone after sync).

## Findings that shape the app

1. **Conflicts merge per field; the last edit to *reach the server* wins.** Uploads send only changed columns, so edits to different fields both survive. For the same field, a stale offline edit uploaded later overwrites a newer web edit. Acceptable for a single-user app. If household sharing (v2) needs true "newest edit wins", upload through a Postgres function that compares a client edit timestamp.
2. **Rejected writes disappear from the device.** A write that violates a constraint is rejected (HTTP 400). The connector logs it and moves on so it can't block the queue, and the next sync removes the row locally to match the server. So: validate in `RelocDomain` before writing locally (mirroring database constraints), keep a local "rejected uploads" record, and tell the user.
3. **Deletes are hard deletes by default.** A local `DELETE` uploads as a server `DELETE`. Plan: the app soft-deletes (sets `deleted_at`), sync config excludes deleted rows, and a scheduled job purges after 30 days, so deletions are recoverable.
4. **`updated_at` is upload time, not edit time** (set by the server trigger). Fine for display; don't use it for conflict decisions.
5. **Types:** SQLite has text/integer/real only. UUIDs, dates, and enums are text; booleans are 0/1 (PostgREST accepted `1` for a `boolean` column); Postgres arrays arrive as JSON text.
6. **Ops:** self-hosting needs a second Postgres (or MongoDB) for PowerSync's own storage, plus a publication on the synced tables (migration `20261111000000_powersync_publication.sql`).

Not covered by the spike, to verify during M1: SDK on a real iPhone, behavior when the access token expires during a long offline period (refresh path exists, untested), local schema changes between app versions, and background sync when the app is suspended.

## Alternatives

| Option | Trade-off |
|---|---|
| **GRDB + custom outbox sync** (former fallback) | GRDB is a mature Swift SQLite library; we'd write the outbox, retries, idempotency, and change pulls ourselves. 1–2 weeks of work and the riskiest code in the app. Not needed: PowerSync passed. |
| **SwiftData + custom sync** | Apple-native, but its sync is designed around CloudKit; syncing to Postgres means fighting its model. |
| **Core Data + CloudKit** | Free sync, but ties us to CloudKit (rejected in ADR-0003). |
| **Online-first with a cache** | Simplest, but fails the offline requirement exactly when it matters. |

## Consequences

- One more service to run: Docker locally, PowerSync Cloud (or self-hosted) in staging and production.
- Free-tier deactivation after inactivity would pause sync (local data stays on the phone). Revisit hosting after the move: reactivate as needed, self-host, or pay.
- The web app stays online-only and reads Postgres directly; the server is the source of truth for both clients.
- App work items from the findings: local validation mirroring constraints, a rejected-uploads banner, soft deletes in sync config.
