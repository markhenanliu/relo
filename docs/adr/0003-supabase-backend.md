# ADR-0003: Supabase as the backend

- **Status:** Accepted
- **Date:** 2026-11-10

## Context

We need authentication (Sign in with Apple, email magic link), a relational database (moves → policies → terms; boxes → items; expenses → attachments), private file storage for receipts and documents, and a place to run server-side code that holds secrets (the Claude API key). Both an iPhone app and a web app must use it. One developer, low budget, production-quality security.

## Decision

Use **Supabase**: hosted Postgres with RLS (Row-Level Security: database rules restricting each user to their own rows), Supabase Auth, Supabase Storage, and Edge Functions (TypeScript on Deno). Schema changes are SQL migrations in the repo; local development uses the Supabase CLI (Command-Line Interface) in Docker.

## Alternatives

| Option | Why not |
|---|---|
| **Firebase** (Firestore) | Mature offline support, but the document model fits our relational data poorly (reports joining expenses, categories, and policy caps), and security rules are less expressive and harder to test than SQL. |
| **CloudKit** | Free, great on Apple devices, built-in sync, but web access (CloudKit JS) is limited and awkward, server-side code for AI extraction would need a separate backend anyway, and the data is hard to query for reports. |
| **Custom backend** (e.g. Node or Swift Vapor on a cloud host + managed Postgres) | Maximum control and a good portfolio signal, but auth, storage, and file security become my problem. Too much undifferentiated work before January. |
| **AWS Amplify** | Capable but heavier to set up and operate for one developer. |

## Consequences

- **Authorization lives in the database** (RLS), so both clients and any future client are protected by the same rules. Every table needs policies and pgTAP tests.
- Postgres is portable: if we outgrow Supabase, the schema and data move to any Postgres host.
- Supabase's own offline story is limited; offline sync is a separate decision ([ADR-0004](0004-offline-first-sync.md)).
- Vendor dependency on Supabase Auth and Storage APIs (Application Programming Interfaces); acceptable at this scale.
