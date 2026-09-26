import { readFile } from 'node:fs/promises';

const required = {
  'database/migrations/001_financial_core.sql': [
    'CREATE CONSTRAINT TRIGGER ledger_transaction_must_balance',
    'DEFERRABLE INITIALLY DEFERRED',
    'REVOKE UPDATE, DELETE ON ledger_entries FROM PUBLIC',
    'UNIQUE (user_id, idempotency_key)',
  ],
  'api/openapi.yaml': ['openapi: 3.1.0', 'name: Idempotency-Key', '/api/v1/orders:', 'UNAVAILABLE'],
  'docs/architecture.md': ['The API returns server-derived values only', 'must not scrape sources'],
};
for (const [path, terms] of Object.entries(required)) {
  const contents = await readFile(path, 'utf8');
  for (const term of terms) {
    if (!contents.toLowerCase().includes(term.toLowerCase())) throw new Error(`${path} is missing required control: ${term}`);
  }
}
console.log('Foundation contracts and financial-control invariants verified.');
