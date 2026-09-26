# Architecture Decision Record: financial source of truth

## Scope and current status

This is a **foundation**, not a release-ready trading system. No provider credentials, licensed market-data entitlement, payment integration, KYC vendor, or legal product approval is present. Therefore, the future web and mobile clients must display an explicit unavailable state for unavailable financial information and disable financial actions.

## System boundaries

```text
Web / Android / iOS
        │ authenticated HTTPS + WebSocket
API gateway ── Auth & session service
        │
        ├── Order service ── Risk service ── Product configuration
        ├── Wallet service ── PostgreSQL ledger
        ├── Market-data adapter ── authorized providers
        ├── Payments adapter ── verified webhooks + reconciliation
        └── Realtime publisher ── Redis stream/pubsub ── WebSocket gateway
```

Each external provider is an adapter behind a named interface. A provider response is stored with source, provider timestamp, receipt timestamp, quality state, and provider reference. The platform must not scrape sources or silently substitute a generated quote.

## Authority and write path

1. The client submits an authenticated command with a request ID and `Idempotency-Key`.
2. The API validates schema, authorization, compliance eligibility, product status, market availability, and risk limits.
3. A database transaction writes the idempotency record, business record/event, audit event, and any required ledger transaction.
4. A transactional outbox record is committed in the same transaction.
5. Workers publish committed outbox messages; consumers are idempotent by event ID.
6. The API returns server-derived values only. The client receives updates but never settles or computes balances.

A database unique key binds `(actor_user_id, route, idempotency_key)` to a request hash. Reuse with a different payload is rejected; reuse with the same payload returns the original result. Payment webhooks similarly deduplicate on provider and provider event ID.

## Ledger model

The general ledger is append-only. A `ledger_transactions` header is linked to two or more `ledger_entries`. The migration uses a deferred constraint trigger, so each committed transaction must sum to zero by currency. Balances are projections of entries, not mutable columns. Funds reservation moves value between customer available and customer reserved accounts; it is never implemented as `balance = balance - amount`.

Every posting has a currency, amount in minor units, account, reference, effective time, and immutable audit context. Money changes must be executed serially for the affected wallet accounts using row locks or advisory locks, with all records committed atomically.

## Order and settlement safety

Orders, contract entries, rounds, and settlements each have durable IDs and events. Settlement uses the configured, versioned product rule and an authoritative quote selected before settlement. The transaction must atomically claim settlement (`UNSETTLED → SETTLING`) and write a unique settlement record. Cancelled orders are ineligible. Late entries are rejected using server time. Feed outage, stale quote, volatility halt, and provider disagreement move the affected product to a defined suspended/void/review workflow—never to a generated result.

Market Surge is a separately configured financial product, not a game clone. It remains disabled unless an approved jurisdiction-specific ruleset specifies: the selected instrument, reference-price source, entry cut-off, formula version, outage/void policy, exposure caps, disclosure text, and independently reproducible settlement record. A displayed multiplier must be explicitly labelled as a contract formula output, never as the underlying price movement unless mathematically true.

## Security controls

- TLS at the edge; HSTS, CSP, secure cookies, CSRF protection for cookie-authenticated mutation routes, tight CORS allowlist, and request-size limits.
- Password hashes use Argon2id; sessions are revocable, rotated, device-bound where feasible, and stored server-side.
- RBAC is deny-by-default. Privileged writes require a reason and create immutable audit events.
- Secrets are injected through a managed secret store; no provider key is exposed to web or mobile applications.
- Rate limits apply by account, session, IP, route, and sensitive action. Logs redact credentials and payment data.

## Operations and recovery

Readiness fails closed when dependencies needed for a requested action are unavailable. Health endpoints are separate: `/live` proves process liveness, `/ready` proves dependencies, and `/health` offers an authenticated diagnostic view. PostgreSQL is the source of truth; Redis is not. Outbox retries use exponential backoff and a dead-letter queue. Reconciliation compares provider settlements with durable payment/order/quote records. Backups, restore drills, migration review, alerting, and production deploy approval are mandatory release gates.
