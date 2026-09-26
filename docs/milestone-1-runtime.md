# Milestone 1: safe runtime spine

## Purpose

This milestone makes the foundation observable in development without pretending that financial services exist. It provides a single HTTP process for the web shell and a very small versioned API surface, while keeping all financial actions unavailable.

## Files changed in this milestone

- `scripts/server.mjs` — HTTP routing, static assets, response security headers, request IDs, and liveness/readiness endpoints.
- `scripts/serve-preview.mjs` — development launcher for the server.
- `api/openapi.yaml` — contract additions for diagnostics and the empty market catalogue response.
- `web/*` — navigation and accessibility improvements for the source-aware product shell.
- `tests/*` — regression tests for the runtime’s unavailable-state and security behavior.

## Explicit boundaries

No database migration is applied. No user, session, wallet, payment, order, contract, quote, or financial posting is created. The market catalogue endpoint returns an empty list until an authorised provider and configured instruments are present. Its response must never be populated with the example symbols in the UI.

`/live` answers only whether the process can receive traffic. `/ready` answers whether required runtime dependencies are configured and reachable; in this repository it intentionally returns `503` because PostgreSQL and Redis are not configured. `/health` is a public, non-sensitive diagnostic response and must not expose environment values, connection strings, secrets, or internal stack traces.

## Acceptance criteria

1. The server generates or propagates an `X-Request-Id` on every response.
2. `/live` returns `200`; `/ready` returns `503` with a clear dependency reason in this unconfigured environment.
3. `/api/v1/markets` returns no invented instruments and identifies its unavailable state.
4. Static content receives CSP, `nosniff`, referrer policy, and no-store headers.
5. Tests verify the above. Financial work remains blocked pending: PostgreSQL/Redis runtime, authorised market-data provider agreement/credentials, identity provider choice, payment/crypto provider agreements, and legal/compliance approvals.
