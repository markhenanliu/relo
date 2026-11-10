# ADR-0004: Offline-first storage and sync on iPhone

- **Status:** Proposed. To be accepted or revised after the R0 sync spike (time-boxed to 3 days).
- **Date:** 2026-11-10

## Context

The PRD (Product Requirements Document) requires every P0 feature to work with no network (G5, ACCT-2). Real moments where this matters: inside a moving truck, a storage unit, a garage, and a new apartment before internet is installed. Data loss (a receipt or a box's contents) is the worst failure.

Supabase's client libraries are online-first; they don't provide an offline database with sync.

## Decision (proposed)

- The iPhone app reads and writes a **local SQLite database**. The UI never waits on the network.
- Use **PowerSync** (a sync engine that keeps an on-device SQLite database in sync with Postgres, with a Swift SDK (Software Development Kit) and Supabase integration) for the sync layer:
  - Download: sync rules stream "rows where `user_id` = me" to the device.
  - Upload: local writes go into a durable queue; our connector sends them to Supabase, where RLS (Row-Level Security) and validation still apply.
- Conflict policy: last-write-wins per row by `updated_at` (single-user app).
- Client-generated UUIDs (Universally Unique Identifiers) and soft deletes, so offline creates and deletes sync cleanly.

**Spike exit criteria** (must all pass, or we take the fallback):
1. Swift SDK builds under Swift 6 strict concurrency in our package layout.
2. Create 50 expenses and 20 boxes in airplane mode, kill the app, reopen, go online: server matches the device with zero loss.
3. Edit the same row on web and on a phone that is offline: the result follows last-write-wins and the user sees the final state on both.
4. Free-tier limits and pricing are acceptable for personal use.

## Alternatives

| Option | Trade-off |
|---|---|
| **GRDB + custom outbox sync** (fallback) | GRDB is a mature Swift SQLite library. We write the sync ourselves: an outbox table of pending mutations, push with retries and idempotency keys, and pull changes since a cursor (`updated_at` + ID). More code and more risk, but no extra service, and a strong portfolio story if done well. |
| **SwiftData + custom sync** | Apple-native and pleasant for UI binding, but SwiftData's sync is designed around CloudKit; syncing to Postgres means fighting its model, and migrations have been less predictable. |
| **Core Data + CloudKit** | Works offline with free sync, but ties us to CloudKit (rejected in ADR-0003). |
| **Online-first with a cache** | Simplest, but fails the offline requirement exactly when it matters. |

## Consequences

- Adds a sync service dependency (if PowerSync) or roughly 1–2 weeks of sync engineering (if fallback).
- The web app stays online-only and reads Postgres directly; the server is the source of truth for both clients.
- Sync behavior needs its own automated tests (offline → reconnect, conflicts, partial failures).
- Household sharing (later) will need a revisit: some tables need per-field merge rather than last-write-wins.
