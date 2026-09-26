-- V3 additive platform extensions. Do not apply without database, security, finance, and compliance review.
-- This migration creates configuration and record structures only; it creates no balance, reward, order, payment, or settlement.
CREATE TYPE platform_role AS ENUM ('SUPER_ADMIN', 'ADMIN', 'FINANCE', 'RISK', 'COMPLIANCE', 'SUPPORT', 'MARKET_OPERATOR', 'ANALYST', 'READ_ONLY', 'PAYMENT_AGENT');
CREATE TYPE referral_status AS ENUM ('PENDING', 'ACTIVE', 'ELIGIBLE', 'REJECTED', 'REWARDED');
CREATE TYPE reward_status AS ENUM ('PENDING', 'UNDER_REVIEW', 'APPROVED', 'POSTED', 'REJECTED', 'REVERSED');
CREATE TYPE agent_status AS ENUM ('PENDING_VERIFICATION', 'ACTIVE', 'OFFLINE', 'SUSPENDED', 'CLOSED');
CREATE TYPE agent_transaction_status AS ENUM ('REQUESTED', 'PENDING', 'UNDER_REVIEW', 'APPROVED', 'PROCESSING', 'COMPLETED', 'FAILED', 'REVERSED', 'INVESTIGATION');
CREATE TYPE slip_status AS ENUM ('DRAFT', 'VALIDATING', 'REQUIRES_REVIEW', 'ACCEPTED', 'REJECTED', 'CANCELLED', 'SETTLED');
CREATE TYPE account_deletion_status AS ENUM ('REQUESTED', 'ELIGIBILITY_CHECK', 'FINANCIAL_OBLIGATION_CHECK', 'COMPLIANCE_RETENTION_CHECK', 'APPROVED', 'DEACTIVATED', 'ANONYMIZED', 'REJECTED');

CREATE TABLE roles (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code platform_role NOT NULL UNIQUE, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE user_roles (user_id uuid NOT NULL REFERENCES users(id), role_id uuid NOT NULL REFERENCES roles(id), assigned_by uuid REFERENCES users(id), assigned_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (user_id, role_id));
CREATE TABLE user_profiles (user_id uuid PRIMARY KEY REFERENCES users(id), username text UNIQUE, display_name text, phone text, country_code char(2), language_code text NOT NULL DEFAULT 'en', timezone text NOT NULL DEFAULT 'Etc/UTC', display_currency char(3) NOT NULL DEFAULT 'NGN', profile_photo_key text, updated_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE account_settings (user_id uuid PRIMARY KEY REFERENCES users(id), notification_preferences jsonb NOT NULL DEFAULT '{}'::jsonb, privacy_preferences jsonb NOT NULL DEFAULT '{}'::jsonb, marketing_consent boolean NOT NULL DEFAULT false, updated_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE sessions (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES users(id), token_hash char(64) NOT NULL UNIQUE, device_id uuid, expires_at timestamptz NOT NULL, revoked_at timestamptz, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE devices (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES users(id), device_fingerprint_hash char(64) NOT NULL, platform text NOT NULL CHECK (platform IN ('WEB', 'ANDROID', 'IOS')), label text, last_seen_at timestamptz NOT NULL DEFAULT now(), revoked_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (user_id, device_fingerprint_hash));
ALTER TABLE sessions ADD CONSTRAINT sessions_device_fk FOREIGN KEY (device_id) REFERENCES devices(id);
CREATE TABLE account_deletion_requests (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES users(id), status account_deletion_status NOT NULL DEFAULT 'REQUESTED', requested_at timestamptz NOT NULL DEFAULT now(), reviewed_by uuid REFERENCES users(id), reviewed_at timestamptz, rationale text, UNIQUE (user_id, status) DEFERRABLE INITIALLY IMMEDIATE);

CREATE TABLE referral_campaigns (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL, reward_rule jsonb NOT NULL, eligibility_rule jsonb NOT NULL, country_restrictions jsonb NOT NULL DEFAULT '[]'::jsonb, product_restrictions jsonb NOT NULL DEFAULT '[]'::jsonb, starts_at timestamptz NOT NULL, ends_at timestamptz, status text NOT NULL CHECK (status IN ('DRAFT', 'ACTIVE', 'PAUSED', 'CLOSED')), created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE referrals (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), campaign_id uuid NOT NULL REFERENCES referral_campaigns(id), referrer_user_id uuid NOT NULL REFERENCES users(id), invited_user_id uuid NOT NULL REFERENCES users(id), referral_code text NOT NULL, status referral_status NOT NULL DEFAULT 'PENDING', fraud_state text NOT NULL DEFAULT 'PENDING_REVIEW', created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (campaign_id, invited_user_id), CHECK (referrer_user_id <> invited_user_id));
CREATE INDEX referrals_referrer_idx ON referrals (referrer_user_id, created_at DESC);
CREATE TABLE referral_rewards (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), referral_id uuid NOT NULL REFERENCES referrals(id), currency char(3) NOT NULL, amount_minor bigint NOT NULL CHECK (amount_minor > 0), status reward_status NOT NULL DEFAULT 'PENDING', ledger_transaction_id uuid REFERENCES ledger_transactions(id), review_reason text, created_at timestamptz NOT NULL DEFAULT now(), posted_at timestamptz, UNIQUE (referral_id), CHECK (NOT (status = 'POSTED' AND ledger_transaction_id IS NULL)));
REVOKE UPDATE, DELETE ON referral_rewards FROM PUBLIC;

CREATE TABLE payment_agents (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid UNIQUE REFERENCES users(id), public_code text NOT NULL UNIQUE, display_name text NOT NULL, country_code char(2) NOT NULL, status agent_status NOT NULL DEFAULT 'PENDING_VERIFICATION', verification_metadata jsonb NOT NULL DEFAULT '{}'::jsonb, contact_policy jsonb NOT NULL DEFAULT '{}'::jsonb, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE agent_capabilities (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), agent_id uuid NOT NULL REFERENCES payment_agents(id), currency char(3) NOT NULL, transaction_kind text NOT NULL CHECK (transaction_kind IN ('DEPOSIT', 'WITHDRAWAL')), minimum_minor bigint NOT NULL CHECK (minimum_minor > 0), maximum_minor bigint NOT NULL CHECK (maximum_minor >= minimum_minor), fee_rule jsonb NOT NULL, active boolean NOT NULL DEFAULT false, UNIQUE (agent_id, currency, transaction_kind));
CREATE TABLE agent_availability (agent_id uuid PRIMARY KEY REFERENCES payment_agents(id), is_online boolean NOT NULL DEFAULT false, updated_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE agent_transactions (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES users(id), agent_id uuid NOT NULL REFERENCES payment_agents(id), kind text NOT NULL CHECK (kind IN ('DEPOSIT', 'WITHDRAWAL')), currency char(3) NOT NULL, amount_minor bigint NOT NULL CHECK (amount_minor > 0), status agent_transaction_status NOT NULL DEFAULT 'REQUESTED', idempotency_key text NOT NULL, ledger_transaction_id uuid REFERENCES ledger_transactions(id), external_reference text, created_at timestamptz NOT NULL DEFAULT now(), completed_at timestamptz, UNIQUE (user_id, kind, idempotency_key), CHECK (NOT (status = 'COMPLETED' AND ledger_transaction_id IS NULL)));
CREATE INDEX agent_transactions_agent_status_idx ON agent_transactions (agent_id, status, created_at DESC);
CREATE TABLE agent_messages (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), agent_transaction_id uuid NOT NULL REFERENCES agent_transactions(id), sender_user_id uuid NOT NULL REFERENCES users(id), message_ciphertext bytea NOT NULL, created_at timestamptz NOT NULL DEFAULT now());
REVOKE UPDATE, DELETE ON agent_messages FROM PUBLIC;
CREATE TABLE agent_disputes (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), agent_transaction_id uuid NOT NULL REFERENCES agent_transactions(id), opened_by uuid NOT NULL REFERENCES users(id), status text NOT NULL CHECK (status IN ('OPEN', 'IN_REVIEW', 'RESOLVED', 'CLOSED')), reason text NOT NULL, resolution text, created_at timestamptz NOT NULL DEFAULT now(), resolved_at timestamptz);

CREATE TABLE crypto_wallets (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES users(id), asset_code text NOT NULL, network_code text NOT NULL, provider_reference text, status text NOT NULL CHECK (status IN ('ACTIVE', 'DISABLED')), created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (user_id, asset_code, network_code));
CREATE TABLE crypto_transactions (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), crypto_wallet_id uuid NOT NULL REFERENCES crypto_wallets(id), kind text NOT NULL CHECK (kind IN ('DEPOSIT', 'WITHDRAWAL')), amount_atomic numeric(78,0) NOT NULL CHECK (amount_atomic > 0), destination_hash char(64), chain_transaction_hash text UNIQUE, confirmations integer NOT NULL DEFAULT 0 CHECK (confirmations >= 0), status text NOT NULL CHECK (status IN ('REQUESTED', 'PENDING', 'CONFIRMED', 'COMPLETED', 'FAILED', 'REVERSED', 'INVESTIGATION')), ledger_transaction_id uuid REFERENCES ledger_transactions(id), idempotency_key text, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE NULLS NOT DISTINCT (crypto_wallet_id, kind, idempotency_key));

CREATE TABLE product_versions (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), product_code text NOT NULL, version integer NOT NULL CHECK (version > 0), rules jsonb NOT NULL, status text NOT NULL CHECK (status IN ('DRAFT', 'APPROVED', 'RETIRED')), approved_by uuid REFERENCES users(id), approved_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (product_code, version));
CREATE TABLE financial_contracts (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), product_version_id uuid NOT NULL REFERENCES product_versions(id), instrument_id uuid NOT NULL REFERENCES instruments(id), contract_type text NOT NULL CHECK (contract_type IN ('HIGHER', 'LOWER', 'ABOVE', 'BELOW', 'TOUCH', 'NO_TOUCH', 'RANGE')), expires_at timestamptz NOT NULL, status text NOT NULL CHECK (status IN ('SCHEDULED', 'OPEN', 'SUSPENDED', 'EXPIRED', 'SETTLED', 'VOID')), reference_quote_id uuid REFERENCES market_quotes(id), created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE bet_slips (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES users(id), status slip_status NOT NULL DEFAULT 'DRAFT', idempotency_key text, accepted_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE NULLS NOT DISTINCT (user_id, idempotency_key));
CREATE TABLE bet_slip_selections (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), bet_slip_id uuid NOT NULL REFERENCES bet_slips(id), financial_contract_id uuid NOT NULL REFERENCES financial_contracts(id), selection_type text NOT NULL, quote_snapshot_id uuid REFERENCES market_quotes(id), validation_status text NOT NULL CHECK (validation_status IN ('PENDING', 'VALID', 'STALE', 'UNAVAILABLE', 'EXPIRED', 'REJECTED')), created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (bet_slip_id, financial_contract_id, selection_type));
CREATE TABLE reconciliation_cases (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), source_type text NOT NULL, source_id uuid NOT NULL, status text NOT NULL CHECK (status IN ('PENDING', 'INVESTIGATION', 'RESOLVED')), opened_at timestamptz NOT NULL DEFAULT now(), resolved_at timestamptz, resolution text, UNIQUE (source_type, source_id));

-- Posted rewards, completed agent transactions, and approved product rules are not silently rewritten.
CREATE OR REPLACE FUNCTION prevent_v3_immutable_record_rewrite()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_TABLE_NAME = 'referral_rewards' AND OLD.status = 'POSTED' THEN
    RAISE EXCEPTION 'posted referral reward % is immutable; use an audited reversal/reconciliation flow', OLD.id;
  END IF;
  IF TG_TABLE_NAME = 'agent_transactions' AND OLD.status = 'COMPLETED' THEN
    RAISE EXCEPTION 'completed agent transaction % is immutable; use reconciliation', OLD.id;
  END IF;
  IF TG_TABLE_NAME = 'product_versions' AND OLD.status = 'APPROVED' AND NEW.rules IS DISTINCT FROM OLD.rules THEN
    RAISE EXCEPTION 'approved product version % rules are immutable', OLD.id;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER referral_rewards_immutable_when_posted BEFORE UPDATE OR DELETE ON referral_rewards FOR EACH ROW EXECUTE FUNCTION prevent_v3_immutable_record_rewrite();
CREATE TRIGGER agent_transactions_immutable_when_completed BEFORE UPDATE OR DELETE ON agent_transactions FOR EACH ROW EXECUTE FUNCTION prevent_v3_immutable_record_rewrite();
CREATE TRIGGER approved_product_rules_immutable BEFORE UPDATE OR DELETE ON product_versions FOR EACH ROW EXECUTE FUNCTION prevent_v3_immutable_record_rewrite();
