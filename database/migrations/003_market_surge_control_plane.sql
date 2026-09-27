-- Market Surge control plane. Additive only; do not apply without legal, finance, security, compliance, and product approval.
-- Creates no rounds, entries, balances, payouts, participants, messages, or giveaway winners.
CREATE TYPE surge_round_status AS ENUM ('SCHEDULED', 'OPEN', 'ACTIVE', 'ENDED', 'SETTLING', 'SETTLED', 'PAUSED', 'SUSPENDED', 'CANCELLED', 'DATA_UNAVAILABLE');
CREATE TYPE surge_methodology AS ENUM ('MARKET_DATA_DERIVED', 'DETERMINISTIC', 'CRYPTOGRAPHICALLY_VERIFIABLE', 'OTHER_DISCLOSED');
CREATE TYPE surge_entry_status AS ENUM ('PROCESSING', 'ACTIVE', 'EXITED', 'SETTLED', 'REJECTED', 'CANCELLED');
CREATE TYPE surge_settlement_status AS ENUM ('PENDING', 'SETTLED', 'VOID', 'RECONCILIATION_REQUIRED');
CREATE TYPE surge_message_status AS ENUM ('VISIBLE', 'HIDDEN', 'DELETED');

CREATE TABLE surge_ruleset_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), product_version_id uuid NOT NULL REFERENCES product_versions(id), methodology surge_methodology NOT NULL,
  methodology_version text NOT NULL, methodology_document jsonb NOT NULL, limits jsonb NOT NULL, settlement_methodology jsonb NOT NULL,
  cryptographic_commitment_spec jsonb, status text NOT NULL CHECK (status IN ('DRAFT', 'APPROVED', 'RETIRED')),
  approved_by uuid REFERENCES users(id), approved_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (product_version_id, methodology_version),
  CHECK ((methodology = 'CRYPTOGRAPHICALLY_VERIFIABLE') = (cryptographic_commitment_spec IS NOT NULL))
);
CREATE TABLE surge_rounds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), public_round_code text NOT NULL UNIQUE, surge_ruleset_version_id uuid NOT NULL REFERENCES surge_ruleset_versions(id),
  instrument_id uuid NOT NULL REFERENCES instruments(id), provider_id uuid REFERENCES market_data_providers(id), reference_quote_id uuid REFERENCES market_quotes(id),
  status surge_round_status NOT NULL DEFAULT 'SCHEDULED', starts_at timestamptz NOT NULL, ends_at timestamptz, activated_at timestamptz,
  immutable_snapshot jsonb, outcome_reference jsonb, created_at timestamptz NOT NULL DEFAULT now(),
  CHECK ((status IN ('ACTIVE','ENDED','SETTLING','SETTLED')) = (immutable_snapshot IS NOT NULL))
);
CREATE INDEX surge_rounds_status_starts_idx ON surge_rounds (status, starts_at DESC);
CREATE TABLE surge_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), round_id uuid NOT NULL REFERENCES surge_rounds(id), user_id uuid NOT NULL REFERENCES users(id),
  masked_participant_id text NOT NULL, entry_minor bigint NOT NULL CHECK (entry_minor > 0), currency char(3) NOT NULL,
  status surge_entry_status NOT NULL DEFAULT 'PROCESSING', idempotency_key text NOT NULL, reservation_ledger_transaction_id uuid REFERENCES ledger_transactions(id),
  entered_at timestamptz NOT NULL DEFAULT now(), exited_at timestamptz, UNIQUE (user_id, round_id, idempotency_key), UNIQUE (round_id, masked_participant_id),
  CHECK (NOT (status IN ('ACTIVE','EXITED','SETTLED') AND reservation_ledger_transaction_id IS NULL))
);
CREATE TABLE surge_settlements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), entry_id uuid NOT NULL UNIQUE REFERENCES surge_entries(id), round_id uuid NOT NULL REFERENCES surge_rounds(id),
  status surge_settlement_status NOT NULL DEFAULT 'PENDING', result jsonb NOT NULL, ledger_transaction_id uuid REFERENCES ledger_transactions(id),
  settled_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(), CHECK (NOT (status = 'SETTLED' AND ledger_transaction_id IS NULL))
);
CREATE TABLE surge_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), round_id uuid NOT NULL REFERENCES surge_rounds(id), sender_user_id uuid NOT NULL REFERENCES users(id),
  ciphertext bytea NOT NULL, status surge_message_status NOT NULL DEFAULT 'VISIBLE', created_at timestamptz NOT NULL DEFAULT now(), moderated_by uuid REFERENCES users(id), moderated_at timestamptz
);
CREATE TABLE surge_message_reports (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), message_id uuid NOT NULL REFERENCES surge_messages(id), reporter_user_id uuid NOT NULL REFERENCES users(id), reason text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (message_id, reporter_user_id));
CREATE TABLE surge_user_blocks (blocker_user_id uuid NOT NULL REFERENCES users(id), blocked_user_id uuid NOT NULL REFERENCES users(id), created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (blocker_user_id, blocked_user_id), CHECK (blocker_user_id <> blocked_user_id));
CREATE TABLE surge_giveaways (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), rules jsonb NOT NULL, jurisdiction_restrictions jsonb NOT NULL, status text NOT NULL CHECK (status IN ('DRAFT','APPROVED','ACTIVE','CLOSED')), starts_at timestamptz NOT NULL, ends_at timestamptz NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), CHECK (ends_at > starts_at));
CREATE TABLE surge_giveaway_entries (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), giveaway_id uuid NOT NULL REFERENCES surge_giveaways(id), user_id uuid NOT NULL REFERENCES users(id), eligibility_snapshot jsonb NOT NULL, status text NOT NULL CHECK (status IN ('PENDING','ELIGIBLE','REJECTED','SELECTED')), created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (giveaway_id, user_id));

CREATE OR REPLACE FUNCTION prevent_surge_immutable_rewrite() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_TABLE_NAME = 'surge_rounds' AND OLD.status IN ('ACTIVE','ENDED','SETTLING','SETTLED') AND (NEW.surge_ruleset_version_id IS DISTINCT FROM OLD.surge_ruleset_version_id OR NEW.instrument_id IS DISTINCT FROM OLD.instrument_id OR NEW.provider_id IS DISTINCT FROM OLD.provider_id OR NEW.reference_quote_id IS DISTINCT FROM OLD.reference_quote_id OR NEW.immutable_snapshot IS DISTINCT FROM OLD.immutable_snapshot) THEN
    RAISE EXCEPTION 'active or completed Market Surge round % snapshot is immutable', OLD.id;
  END IF;
  IF TG_TABLE_NAME = 'surge_settlements' AND OLD.status = 'SETTLED' THEN RAISE EXCEPTION 'settled Market Surge record % is immutable; use reconciliation', OLD.id; END IF;
  RETURN NEW;
END; $$;
CREATE TRIGGER surge_round_snapshot_immutable BEFORE UPDATE OR DELETE ON surge_rounds FOR EACH ROW EXECUTE FUNCTION prevent_surge_immutable_rewrite();
CREATE TRIGGER surge_settlement_immutable BEFORE UPDATE OR DELETE ON surge_settlements FOR EACH ROW EXECUTE FUNCTION prevent_surge_immutable_rewrite();
REVOKE UPDATE, DELETE ON surge_messages FROM PUBLIC;
