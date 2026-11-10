# ADR-0005: Document extraction: receipts on device, policies in the cloud

- **Status:** Accepted (receipt default to be re-checked in R1 against a receipt test set)
- **Date:** 2026-11-10

## Context

Two kinds of documents need to become structured data:

| | Receipts | Relocation policies |
|---|---|---|
| Volume | Dozens per move | One or two per move |
| Size | One image, short text | Multi-page PDF (Portable Document Format), legal language |
| Difficulty | Crumpled, faded, but a simple schema | Nuanced: conditions, proration, caps, ambiguity |
| Cost of a mistake | Low (user sees the amount immediately) | High (wrong allowance or clawback number) |
| Offline need | High (capture at the store or in the truck) | Low |
| Sensitivity | Moderate | High (names, salary references, signatures) |

## Decision

**Receipts: on device first.**
VisionKit document camera → Vision text recognition (OCR: Optical Character Recognition) → Apple's on-device Foundation Models framework with guided generation into a typed `ReceiptDraft` (merchant, date, total, tax, payment method, category suggestion). Private, free, offline. If the model is unavailable (device without Apple Intelligence), confidence is low, or the user taps "Improve", fall back to the cloud function `extract-receipt` with consent.

**Policies: cloud with verification and human confirmation.**
Supabase Edge Function `extract-policy` calls the Claude API (`claude-opus-5-5`, configurable) through the official TypeScript SDK (Software Development Kit):
- The PDF is sent as a document content block, with adaptive thinking and **structured outputs** (a JSON Schema in `output_config.format`) so the result always parses into `terms[]` and `open_questions[]`.
- Every term must include `source_page` and a verbatim `source_quote`. (The API's citations feature can't be combined with structured outputs, so provenance is part of the schema.)
- The function **verifies each quote** against the PDF's extracted text; unverified terms are flagged.
- Terms are stored as `pending`; only user-confirmed terms affect budgets or the clawback tracker.
- The server-side refusal fallback is enabled so a rare model refusal degrades gracefully.
- The Anthropic API key exists only as an Edge Function secret.

**Quality is measured, not assumed:** an evaluation set of fictional policies with expected terms (precision, recall, invented-term count) gates prompt or model changes. A receipt test set (photos of real-world-style receipts, with personal data removed) decides whether on-device stays the default.

## Alternatives

| Option | Why not |
|---|---|
| Cloud for everything | Simpler single pipeline, but receipts would need network and send more personal data off device than necessary. |
| On-device for everything | The on-device model is small; legal-language policies with conditions and proration need a frontier model. |
| Traditional OCR + regex/templates | Brittle across receipt layouts; can't interpret policy language at all. |
| Third-party receipt OCR APIs | Another vendor and data processor for a problem the device and Claude already cover. |
| Fully automatic policy extraction (no review) | Unacceptable risk: a wrong clawback or allowance number misleads the user. Human confirmation is the product feature. |

## Consequences

- Two extraction paths to build and test, sharing the `ReceiptDraft` schema from `schemas/`.
- Clear privacy story: receipts usually stay on the phone; policies leave only with explicit consent.
- Policy extraction costs a few cents per document; per-user quotas guard the endpoint.
- The eval harness becomes a lasting asset and a portfolio highlight.
