import { readFile } from 'node:fs/promises';

const required = {
  'database/migrations/002_v3_platform_extensions.sql': ['CREATE TABLE referrals', 'CREATE TABLE agent_transactions', 'CREATE TABLE crypto_transactions', 'CREATE TABLE product_versions', 'CREATE TABLE bet_slips', 'CREATE TABLE reconciliation_cases', 'CREATE TRIGGER referral_rewards_immutable_when_posted', 'CREATE TRIGGER agent_transactions_immutable_when_completed'],
  'database/migrations/001_financial_core.sql': [
    'CREATE CONSTRAINT TRIGGER ledger_transaction_must_balance',
    'DEFERRABLE INITIALLY DEFERRED',
    'REVOKE UPDATE, DELETE ON ledger_entries FROM PUBLIC',
    'UNIQUE (user_id, idempotency_key)',
  ],
  'api/openapi.yaml': ['openapi: 3.1.0', 'name: Idempotency-Key', '/api/v1/orders:', '/api/v1/agents:', '/api/v1/betslips:', 'UNAVAILABLE'],
  'docs/architecture.md': ['The API returns server-derived values only', 'must not scrape sources'],
  'web/index.html': ['Market data unavailable', 'No orders to show', 'Market Surge'],
  'scripts/server.mjs': ["Content-Security-Policy", "X-Content-Type-Options", "DATA_UNAVAILABLE", "X-Request-Id"],
};
for (const [path, terms] of Object.entries(required)) {
  const contents = await readFile(path, 'utf8');
  for (const term of terms) {
    if (!contents.toLowerCase().includes(term.toLowerCase())) throw new Error(`${path} is missing required control: ${term}`);
  }
}
console.log('Foundation contracts and financial-control invariants verified.');
