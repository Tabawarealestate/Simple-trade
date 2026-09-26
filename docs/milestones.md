# Delivery milestones and approval gates

## Milestone 0 — foundation (this change)

- Record the trust model, production constraints, operational boundaries, and human approval gates.
- Define initial versioned API vocabulary and PostgreSQL financial schema.
- Provide local dependency topology and static invariant checks.

**Explicitly not delivered:** UI, authentication implementation, market-data integration, payments, user wallets, quotes, orders, deposits, withdrawals, settlements, or production deployment. None can be represented with invented values.

## Milestone 1 — identity and platform runtime

Implement authenticated API runtime, sessions, email/phone verification adapters, RBAC, request IDs, structured logs, `/live`, `/ready`, `/health`, rate limiting, audit middleware, and CI. Require threat-model and security review before public access.

## Milestone 2 — authorized market-data ingestion

After a licensed/authorized provider and symbol entitlement are supplied, implement `MarketDataProvider`, quote provenance, staleness detection, historical data, instrument configuration, and WebSocket publication. Test provider disconnect/failover and show unavailable/suspended states. Human approval: provider contract, symbol policy, and data-retention policy.

## Milestone 3 — wallet, payments, and reconciliation

Implement wallets as ledger projections, reservation/release postings, provider-specific payment initiation and signed webhook verification, reconciliation jobs, withdrawal review workflow, and finance tooling. Human approval: payment sandbox credentials, accounting chart, reconciliation runbook, limits, and fraud policy.

## Milestone 4 — orders and risk

Implement server-authoritative order state machine, idempotency, configurable risk limits, market status gating, positions, event outbox, and WebSocket events. Test duplicate, concurrent, stale-price, outage, and restart cases. Human approval: execution venue/broker arrangement and risk policy.

## Milestone 5 — regulated contract products

Build only products approved for each jurisdiction. The product builder must version rules, disclosure, payout/exposure limits, eligible instruments, and operational state. Human approval: legal classification, compliance configuration, settlement formula, provider selection, and customer disclosures.

## Milestone 6 — Market Surge (optional)

Implement only after Milestone 5 and a separate documented product approval. It must be market-data-driven or use a documented auditable mechanism; browser randomness is prohibited. Perform reproducibility, outage, extreme-volatility, and concurrency testing.

## Release gates

Production requires human sign-off for migrations, provider credentials, legal/compliance, risk, financial reconciliation, penetration testing, incident response, backup restoration, monitoring, and deployment. This repository must never imply that such approval has occurred.
