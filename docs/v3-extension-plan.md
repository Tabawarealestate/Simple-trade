# V3 extension plan: financial market prediction and contract platform

## Positioning

Asterion is a **global real-time financial market prediction and contract platform**. It is not a traditional broker, a sports product, a traditional casino, or a clone of another product. It may use a rapid selection and slip interaction pattern, but every available product must be backed by an approved financial instrument, configured product rules, an authoritative source, and a server-side record.

## Inspection result

The repository has no Prisma schema; it uses raw PostgreSQL migrations in `database/migrations/`. It has no authentication implementation, payment service, crypto service, configured database runtime, authorized market-data provider, or payment-agent provider. The V3 migration therefore defines persistent boundaries only and is not applied by this change.

## Files in this increment

- `database/migrations/002_v3_platform_extensions.sql`: additive V3 persistence schema. It does not alter or remove the existing ledger architecture.
- `api/openapi.yaml`: V3 API namespaces documented as unavailable until their vertical slices are implemented.
- `web/*`: navigational and explanatory changes only; no referral, agent, crypto, or contract activity is fabricated.
- `tests/*`: regression checks for append-only settlement/reward/agent communication design and unavailable API behavior.

## Vertical-slice delivery order

1. **Identity, settings, roles, sessions, and device security.** Requires an authentication implementation, email/phone/2FA choices, privacy policy, and database runtime.
2. **Payment-agent center.** Requires agent onboarding policy, verification/review workflow, jurisdiction rules, fraud controls, secure communications policy, and reconciliation runbook. No request may credit or debit a wallet outside the existing ledger.
3. **Direct crypto.** Requires a custody/wallet provider, supported asset/network policy, address-screening and confirmation policy, and reconciliation process.
4. **Financial contract center and selection slip.** Requires licensed/authorized market data, approved product classification/rules, a pricing engine, risk limits, and an execution/settlement design.
5. **Referral rewards.** Requires a campaign policy, eligibility/fraud rules, and a ledger posting/review workflow. A reward cannot become available merely from an invite.
6. **Market Surge, administration, support, native mobile, and production rollout.** Each follows only after its server-side control plane, audit trail, operational runbook, and tests are approved.

## Non-negotiable controls

- All financial mutations require authentication, authorization, idempotency, audit events, and a database transaction.
- A payment-agent or crypto confirmation is evidence to review, not a client-side command to change a balance.
- A reward or settlement is immutable once posted; corrections use a separate audited correction/reconciliation workflow.
- A slip is an intent until the server validates every selection against current authorized data, product state, jurisdiction, risk, and pricing.
- Started contract rounds reference an immutable product/ruleset version.

## Approval and external blockers

No production migration or financial product should be approved from this repository alone. The founders must select and approve: authentication/identity vendors, licensed market-data and execution arrangements, payment-agent onboarding/settlement rules, crypto infrastructure/custody, jurisdictional legal advice, KYC/AML provider, retention policy, risk limits, and hosting/monitoring.
