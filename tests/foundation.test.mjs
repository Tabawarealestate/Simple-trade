import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

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
