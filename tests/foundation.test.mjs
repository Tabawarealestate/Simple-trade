import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createApplication } from '../scripts/server.mjs';

const migration = await readFile(new URL('../database/migrations/001_financial_core.sql', import.meta.url), 'utf8');
const contract = await readFile(new URL('../api/openapi.yaml', import.meta.url), 'utf8');

test('ledger entries are append-only and transaction balance is checked at commit', () => {
  assert.match(migration, /REVOKE UPDATE, DELETE ON ledger_entries FROM PUBLIC/);
  assert.match(migration, /CREATE CONSTRAINT TRIGGER ledger_transaction_must_balance/);
  assert.match(migration, /DEFERRABLE INITIALLY DEFERRED/);
});

test('order creation requires an idempotency key and server-derived request fields', () => {
  assert.match(contract, /name: Idempotency-Key/);
  assert.match(contract, /client values are never authoritative/i);
  assert.match(contract, /\/api\/v1\/orders:/);
});

test('mobile preview never presents fabricated financial values', async () => {
  const preview = await readFile(new URL('../web/index.html', import.meta.url), 'utf8');
  assert.match(preview, /Market data unavailable/);
  assert.match(preview, /No orders to show/);
  assert.doesNotMatch(preview, /football|basketball|casino|sports odds/i);
});

async function withServer(callback) {
  const app = createApplication();
  await new Promise((resolve) => app.listen(0, '127.0.0.1', resolve));
  const { port } = app.address();
  try { await callback(`http://127.0.0.1:${port}`); } finally { await new Promise((resolve, reject) => app.close((error) => error ? reject(error) : resolve())); }
}

test('runtime reports liveness but fails readiness without configured dependencies', async () => {
  await withServer(async (origin) => {
    const live = await fetch(`${origin}/live`, { headers: { 'X-Request-Id': 'client-request-001' } });
    assert.equal(live.status, 200);
    assert.equal((await live.json()).requestId, 'client-request-001');
    const ready = await fetch(`${origin}/ready`);
    assert.equal(ready.status, 503);
    assert.match((await ready.json()).reason, /not configured/i);
  });
});

test('market API never manufactures an instrument when no authorized provider is configured', async () => {
  await withServer(async (origin) => {
    const response = await fetch(`${origin}/api/v1/markets`);
    assert.equal(response.status, 200);
    assert.match(response.headers.get('content-security-policy'), /default-src 'self'/);
    const payload = await response.json();
    assert.deepEqual(payload.data, []);
    assert.equal(payload.status, 'DATA_UNAVAILABLE');
    assert.match(payload.asOf, /T/);
    assert.match(payload.requestId, /^[a-z0-9-]+$/i);
  });
});

const v3Migration = await readFile(new URL('../database/migrations/002_v3_platform_extensions.sql', import.meta.url), 'utf8');

test('V3 records preserve server-authoritative and ledger-linked financial controls', () => {
  assert.match(v3Migration, /CREATE TABLE referral_rewards/);
  assert.match(v3Migration, /ledger_transaction_id uuid REFERENCES ledger_transactions/);
  assert.match(v3Migration, /CHECK \(referrer_user_id <> invited_user_id\)/);
  assert.match(v3Migration, /CREATE TABLE agent_transactions/);
  assert.match(v3Migration, /UNIQUE \(user_id, kind, idempotency_key\)/);
  assert.match(v3Migration, /CREATE TABLE product_versions/);
  assert.match(v3Migration, /CREATE TABLE bet_slip_selections/);
  assert.match(v3Migration, /CREATE TABLE reconciliation_cases/);
  assert.match(v3Migration, /CREATE TRIGGER referral_rewards_immutable_when_posted/);
  assert.match(v3Migration, /CREATE TRIGGER agent_transactions_immutable_when_completed/);
  assert.match(v3Migration, /CREATE TRIGGER approved_product_rules_immutable/);
});

test('unimplemented V3 financial API namespaces explicitly fail closed', async () => {
  await withServer(async (origin) => {
    const response = await fetch(`${origin}/api/v1/agents`);
    assert.equal(response.status, 503);
    const payload = await response.json();
    assert.equal(payload.title, 'Feature unavailable');
    assert.match(payload.detail, /authenticated, authorized, audited, provider-backed/i);
  });
});

const surgeMigration = await readFile(new URL('../database/migrations/003_market_surge_control_plane.sql', import.meta.url), 'utf8');

test('Market Surge control plane requires immutable snapshots and ledger-linked settlement', () => {
  assert.match(surgeMigration, /CREATE TABLE surge_rounds/);
  assert.match(surgeMigration, /immutable_snapshot jsonb/);
  assert.match(surgeMigration, /CREATE TABLE surge_entries/);
  assert.match(surgeMigration, /reservation_ledger_transaction_id uuid REFERENCES ledger_transactions/);
  assert.match(surgeMigration, /CREATE TABLE surge_settlements/);
  assert.match(surgeMigration, /CREATE TRIGGER surge_round_snapshot_immutable/);
  assert.match(surgeMigration, /CREATE TRIGGER surge_settlement_immutable/);
  assert.match(surgeMigration, /CREATE TABLE surge_message_reports/);
  assert.match(surgeMigration, /CREATE TABLE surge_giveaways/);
});

test('Market Surge API fails closed without its approved backend', async () => {
  await withServer(async (origin) => {
    const response = await fetch(`${origin}/api/v1/surge`);
    assert.equal(response.status, 503);
    assert.equal((await response.json()).title, 'Feature unavailable');
  });
});
