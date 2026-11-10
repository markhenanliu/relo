# ADR-0001: Record architecture decisions

- **Status:** Accepted
- **Date:** 2026-11-10

## Context

This project is built by one developer but is meant to read like a team project: reviewers (and future me) should be able to see *why* the system looks the way it does, not just *what* it is.

## Decision

Record significant decisions as ADRs (Architecture Decision Records), short Markdown files in `docs/adr/`, numbered sequentially, using this template:

```markdown
# ADR-NNNN: Title
- Status: Proposed | Accepted | Superseded by ADR-XXXX
- Date: YYYY-MM-DD

## Context        — the forces at play
## Decision       — what we chose
## Alternatives   — what else we considered and why not
## Consequences   — what gets easier, what gets harder, follow-ups
```

An ADR is written when a decision is hard to reverse, affects more than one part of the system, or a reasonable engineer might have chosen differently. ADRs are never edited after acceptance except to change status; a new ADR supersedes an old one.

## Consequences

- Decision history is reviewable in pull requests alongside the code.
- Small cost per decision (about 15 minutes of writing).
