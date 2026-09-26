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
