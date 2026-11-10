# ADR-0002: Native SwiftUI iPhone app plus a Next.js web companion

- **Status:** Accepted
- **Date:** 2026-11-10

## Context

The PRD (Product Requirements Document) requires a phone app that works offline and uses the camera heavily (receipts, QR (Quick Response) code labels), plus browser access from a computer for desktop tasks (printing label sheets, reviewing expenses in a table, uploading PDFs).

The author uses an iPhone and wants a native app, and wants the project to show native iOS skills in a portfolio.

## Decision

- **iPhone:** native Swift 6 + SwiftUI, minimum iOS 26.
- **Web:** a separate Next.js + TypeScript companion app, online-only, focused on desktop-shaped tasks rather than duplicating every phone screen.

## Alternatives

| Option | Why not (for this project) |
|---|---|
| **Expo / React Native** (one TypeScript codebase for iOS, Android, web) | Less code to maintain and adds Android, but weaker access to the newest Apple frameworks (on-device Foundation Models, VisionKit document scanning, universal links work but need native modules), and a weaker native-iOS portfolio signal. |
| **Progressive Web App only** (a website installable to the home screen) | Fastest to build, but iOS limits background upload, offline storage size, and camera ergonomics. Doesn't meet the "native app" goal. |
| **SwiftUI everywhere** (Mac Catalyst or a macOS app instead of web) | Works only on Apple computers and needs installation; a browser is more universal for "check from any computer". |
| **Kotlin Multiplatform shared logic** | Adds a third language and toolchain for little benefit with one client platform. |

## Consequences

- Two UI codebases (Swift and TypeScript). Kept manageable by giving the web a deliberately smaller scope and sharing contracts through Postgres types and JSON Schemas (`schemas/`).
- Business rules that both clients show (allowance remaining, clawback estimate) must be implemented twice. Mitigation: shared JSON test vectors that both the Swift and SQL/TypeScript implementations must pass.
- No Android app; Android users would use the web companion.
- iOS 26 minimum excludes older iPhones; acceptable for a personal and portfolio app.
