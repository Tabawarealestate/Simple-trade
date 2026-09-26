# Asterion Markets Platform

Asterion is a financial-market platform foundation. It intentionally does **not** render synthetic quotes, balances, orders, deposits, withdrawals, profits, provider approvals, or licensing claims.

## Current milestone — platform foundation

This repository establishes reviewable contracts and persistence controls before an application is built:

- architecture and operational boundaries;
- a versioned API contract that makes data provenance, authentication, and idempotency explicit;
- an append-only PostgreSQL ledger schema with a deferred balance invariant;
- a local-only deployment topology and environment template;
- executable static checks for the baseline artifacts.

No market-data provider, payment processor, authentication authority, or production database is configured. Until those integrations are explicitly provisioned and reviewed, clients must present unavailable states rather than values.

## Prerequisites

- Node.js 20+ for repository checks.
- PostgreSQL 16+ and Redis 7+ for local integration work (optional at this milestone).

## Commands

```bash
npm run check
npm test
```

`docker compose up` is intentionally not a production deployment command. It starts only local infrastructure after an operator creates a local `.env` from `.env.example`.

## Project map

| Path | Purpose |
| --- | --- |
| `docs/architecture.md` | System boundaries, trust model, reliability and security decisions. |
| `docs/milestones.md` | Human approval gates and build sequence. |
| `api/openapi.yaml` | Initial versioned HTTP contract. |
| `database/migrations/001_financial_core.sql` | Financial records and audit schema. |
| `scripts/verify-foundation.mjs` | Fast, dependency-free baseline checks. |

## Non-negotiable operating rules

1. The server is the only authority for quotes, orders, balance movements, positions, and settlements.
2. A client confirmation is never evidence of a payment or an order outcome.
3. Financial movement is represented by immutable ledger entries and a balanced transaction, not an in-place balance update.
4. Every money-moving command requires an idempotency key and a durable audit trail.
5. Market-data loss is an explicit state; it cannot be filled with fallback or generated prices.
6. Contracts and Market Surge are jurisdiction-gated products and remain disabled until legal classification, rules, provider inputs, and controls are approved.

## Mobile preview

A real, mobile-first browser preview is included in `web/`. It deliberately shows unavailable and empty states until authorised providers and server-side services are implemented; it never generates financial prices, balances, or orders.

On a development computer, start it with:

```bash
npm run dev
```

Then open `http://localhost:4173` in the same computer’s browser. To open it from a phone, the preview must be deployed or securely port-forwarded by a developer; no public preview URL is configured in this repository.
