-- Asterion financial core. Review with finance/security before applying anywhere.
-- This migration creates no user funds and performs no financial posting.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TYPE account_kind AS ENUM ('CUSTOMER_AVAILABLE', 'CUSTOMER_RESERVED', 'CUSTOMER_WITHDRAWABLE', 'PLATFORM_CLEARING', 'PLATFORM_FEES', 'PLATFORM_PAYABLE');
CREATE TYPE financial_transaction_status AS ENUM ('PENDING', 'POSTED', 'REVERSED', 'FAILED');
CREATE TYPE order_status AS ENUM ('PENDING', 'OPEN', 'PARTIALLY_FILLED', 'FILLED', 'CANCELLED', 'EXPIRED', 'SETTLED', 'REJECTED');
CREATE TYPE quote_status AS ENUM ('AVAILABLE', 'STALE', 'UNAVAILABLE', 'HALTED');
CREATE TYPE audit_actor_type AS ENUM ('USER', 'ADMIN', 'SYSTEM', 'PROVIDER');

CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL UNIQUE,
  password_hash text NOT NULL,
  status text NOT NULL CHECK (status IN ('PENDING_VERIFICATION', 'ACTIVE', 'RESTRICTED', 'SUSPENDED', 'CLOSED')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE instruments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  symbol text NOT NULL UNIQUE,
  display_name text NOT NULL,
  asset_class text NOT NULL CHECK (asset_class IN ('FOREX', 'CRYPTO', 'STOCK', 'INDEX', 'COMMODITY', 'METAL')),
  status text NOT NULL CHECK (status IN ('ACTIVE', 'SUSPENDED', 'CLOSED')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE market_data_providers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  status text NOT NULL CHECK (status IN ('ACTIVE', 'DEGRADED', 'DISABLED')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE market_quotes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  instrument_id uuid NOT NULL REFERENCES instruments(id),
  provider_id uuid NOT NULL REFERENCES market_data_providers(id),
  provider_symbol text NOT NULL,
  bid numeric(24,10),
  ask numeric(24,10),
  last numeric(24,10),
  quote_status quote_status NOT NULL,
  provider_timestamp timestamptz NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  CHECK (bid IS NULL OR bid >= 0), CHECK (ask IS NULL OR ask >= 0), CHECK (last IS NULL OR last >= 0)
);
CREATE INDEX market_quotes_instrument_received_idx ON market_quotes (instrument_id, received_at DESC);

CREATE TABLE wallets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id),
  currency char(3) NOT NULL CHECK (currency IN ('NGN', 'USD', 'EUR', 'GBP')),
  status text NOT NULL CHECK (status IN ('ACTIVE', 'RESTRICTED', 'CLOSED')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, currency)
);

CREATE TABLE wallet_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id uuid REFERENCES wallets(id),
  currency char(3) NOT NULL CHECK (currency IN ('NGN', 'USD', 'EUR', 'GBP')),
  kind account_kind NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE NULLS NOT DISTINCT (wallet_id, kind, currency)
);

CREATE TABLE ledger_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference_type text NOT NULL,
  reference_id uuid NOT NULL,
  status financial_transaction_status NOT NULL DEFAULT 'PENDING',
  idempotency_key text,
  request_hash char(64),
  created_at timestamptz NOT NULL DEFAULT now(),
  posted_at timestamptz,
  UNIQUE NULLS NOT DISTINCT (reference_type, reference_id),
  CHECK ((idempotency_key IS NULL) = (request_hash IS NULL))
);

CREATE TABLE ledger_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id uuid NOT NULL REFERENCES ledger_transactions(id),
  account_id uuid NOT NULL REFERENCES wallet_accounts(id),
  currency char(3) NOT NULL CHECK (currency IN ('NGN', 'USD', 'EUR', 'GBP')),
  amount_minor bigint NOT NULL CHECK (amount_minor <> 0),
  effective_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX ledger_entries_transaction_idx ON ledger_entries (transaction_id);
CREATE INDEX ledger_entries_account_idx ON ledger_entries (account_id, created_at DESC);
REVOKE UPDATE, DELETE ON ledger_entries FROM PUBLIC;

CREATE OR REPLACE FUNCTION verify_ledger_transaction_balance()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE imbalance_count integer;
DECLARE entry_count integer;
BEGIN
  SELECT count(*) INTO entry_count FROM ledger_entries WHERE transaction_id = NEW.transaction_id;
  SELECT count(*) INTO imbalance_count
  FROM (
    SELECT currency, sum(amount_minor) AS total
    FROM ledger_entries WHERE transaction_id = NEW.transaction_id
    GROUP BY currency HAVING sum(amount_minor) <> 0
  ) imbalances;
  IF entry_count < 2 OR imbalance_count <> 0 THEN
    RAISE EXCEPTION 'ledger transaction % must contain at least two balanced entries', NEW.transaction_id;
  END IF;
  RETURN NULL;
END;
$$;
CREATE CONSTRAINT TRIGGER ledger_transaction_must_balance
AFTER INSERT OR UPDATE ON ledger_entries
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION verify_ledger_transaction_balance();

CREATE OR REPLACE FUNCTION verify_posted_ledger_transaction_balance()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status = 'POSTED' AND OLD.status IS DISTINCT FROM 'POSTED' THEN
    PERFORM 1 FROM ledger_entries WHERE transaction_id = NEW.id LIMIT 1;
    IF NOT FOUND THEN RAISE EXCEPTION 'posted ledger transaction % has no entries', NEW.id; END IF;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER posted_ledger_transaction_must_have_entries
BEFORE UPDATE OF status ON ledger_transactions
FOR EACH ROW EXECUTE FUNCTION verify_posted_ledger_transaction_balance();

CREATE TABLE orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id),
  instrument_id uuid NOT NULL REFERENCES instruments(id),
  product_type text NOT NULL,
  direction text NOT NULL CHECK (direction IN ('BUY', 'SELL')),
  notional_minor bigint NOT NULL CHECK (notional_minor > 0),
  currency char(3) NOT NULL CHECK (currency IN ('NGN', 'USD', 'EUR', 'GBP')),
  status order_status NOT NULL DEFAULT 'PENDING',
  entry_reference_price numeric(24,10), execution_price numeric(24,10), settlement_price numeric(24,10),
  fee_minor bigint NOT NULL DEFAULT 0 CHECK (fee_minor >= 0),
  provider_reference text, expires_at timestamptz, opened_at timestamptz, settled_at timestamptz,
  idempotency_key text NOT NULL, request_hash char(64) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, idempotency_key),
  CHECK (NOT (status = 'SETTLED' AND settled_at IS NULL))
);
CREATE INDEX orders_user_status_idx ON orders (user_id, status, created_at DESC);

CREATE TABLE order_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), order_id uuid NOT NULL REFERENCES orders(id),
  event_type text NOT NULL, payload jsonb NOT NULL DEFAULT '{}'::jsonb, created_at timestamptz NOT NULL DEFAULT now()
);
REVOKE UPDATE, DELETE ON order_events FROM PUBLIC;

CREATE TABLE idempotency_keys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), actor_user_id uuid REFERENCES users(id), route text NOT NULL,
  key text NOT NULL, request_hash char(64) NOT NULL, response_status integer, response_body jsonb,
  created_at timestamptz NOT NULL DEFAULT now(), expires_at timestamptz NOT NULL,
  UNIQUE NULLS NOT DISTINCT (actor_user_id, route, key)
);

CREATE TABLE audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), actor_type audit_actor_type NOT NULL, actor_id uuid,
  action text NOT NULL, resource_type text NOT NULL, resource_id uuid, request_id uuid,
  ip inet, user_agent text, before_state jsonb, after_state jsonb, reason text, created_at timestamptz NOT NULL DEFAULT now()
);
REVOKE UPDATE, DELETE ON audit_logs FROM PUBLIC;

CREATE TABLE outbox_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), aggregate_type text NOT NULL, aggregate_id uuid NOT NULL,
  event_type text NOT NULL, payload jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
  published_at timestamptz, attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0)
);
CREATE INDEX outbox_events_pending_idx ON outbox_events (created_at) WHERE published_at IS NULL;
