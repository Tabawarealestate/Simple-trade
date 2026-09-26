# Market Surge: methodology and control requirements

## Product boundary

Market Surge is an original, optional financial-contract module. It is not a broker execution feature, traditional casino product, sports product, or copy of another crash-style product. The visual graph is an explanation of an active round’s backend-calculated value; it must not suggest predictable future movement.

## No fabricated round data

Until an approved product, ruleset, market-data source, settlement methodology, and real-time engine are configured, the UI must show `DATA_UNAVAILABLE` and no multiplier, player, entry, history, winner, or payout. A static 2x value is prohibited. The active ruleset determines any displayed min/max including whether a 2x level is meaningful.

## Server state machine

`SCHEDULED → OPEN → ACTIVE → ENDED → SETTLING → SETTLED`

A round may additionally be `PAUSED`, `SUSPENDED`, `CANCELLED`, or `DATA_UNAVAILABLE`. Only the backend transitions financial states. An entry is separately `PROCESSING`, `ACTIVE`, `EXITED`, `SETTLED`, or rejected. A user interface event is never evidence of an accepted entry, exit, or settlement.

## Immutable active-round snapshot

At activation, a round records the ruleset version, outcome-methodology version, instrument, data provider/reference, start time, limits, and settlement methodology snapshot. These fields are immutable while active or later. Any correction must create a linked reconciliation case and audited correction record; it must not rewrite historical truth.

## Outcome transparency

Every ruleset declares one accurate methodology: `MARKET_DATA_DERIVED`, `DETERMINISTIC`, `CRYPTOGRAPHICALLY_VERIFIABLE`, or `OTHER_DISCLOSED`. “Provably fair” can be displayed only when an independently verifiable cryptographic commitment/reveal design is actually implemented and records sufficient inputs to verify it. Until then, the interface calls this **Outcome Methodology**, never “provably fair.”

## Privacy, message room, and giveaways

Participant displays use a server-generated masked public identifier, never contact, account, device, payment, or government identity data. Messages are isolated from financial records, stored encrypted, rate-limited, reportable, blockable, and moderation-audited. The product must warn against posting secrets. Giveaways are configuration/eligibility records only; a winner is not created without an approved, reproducible selection process and legal review.

## Entry and settlement gate

A real-money entry needs authenticated identity, eligibility/jurisdiction/account checks, availability, product/round status, fresh data, ruleset, available funds, limits/exposure, idempotency, risk decision, atomic ledger reservation, audit event, and durable outbox event. Settlement links the entry to the ledger and immutable round snapshot. A Market Surge module may not create a separate balance system.

## Release blockers

Before enabling even a single round: approved product/legal classification, compliance configuration, risk limits, authorized data source and staleness policy, methodology documentation, settlement/reconciliation runbook, WebSocket/outbox infrastructure, audit access controls, moderation policy/tooling, responsible-use controls, and security review are required.
