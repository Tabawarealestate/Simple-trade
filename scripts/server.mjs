import { createReadStream, existsSync } from 'node:fs';
import { createServer } from 'node:http';
import { extname, relative, resolve } from 'node:path';
import { randomUUID } from 'node:crypto';

const staticRoot = resolve(process.cwd(), 'web');
const mimeTypes = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8' };
const securityHeaders = {
  'Cache-Control': 'no-store',
  'Content-Security-Policy': "default-src 'self'; style-src 'self'; script-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'",
  'Referrer-Policy': 'no-referrer',
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'DENY',
};

function requestId(request) {
  const value = request.headers['x-request-id'];
  return typeof value === 'string' && /^[a-zA-Z0-9-]{8,128}$/.test(value) ? value : randomUUID();
}

function respond(response, status, body, id, method = 'GET') {
  response.writeHead(status, { ...securityHeaders, 'Content-Type': 'application/json; charset=utf-8', 'X-Request-Id': id });
  response.end(method === 'HEAD' ? undefined : JSON.stringify(body));
}

function dependenciesReady() {
  return Boolean(process.env.DATABASE_URL && process.env.REDIS_URL);
}

function serveStatic(pathname, response, id, method) {
  const requested = pathname === '/' ? 'index.html' : pathname.slice(1);
  const file = resolve(staticRoot, requested);
  const pathInsideRoot = relative(staticRoot, file) && !relative(staticRoot, file).startsWith('..') && !relative(staticRoot, file).includes('/../');
  if (!pathInsideRoot || !existsSync(file)) {
    respond(response, 404, { type: 'https://asterion.invalid/problems/not-found', title: 'Not found', status: 404, requestId: id }, id, method);
    return;
  }
  response.writeHead(200, { ...securityHeaders, 'Content-Type': mimeTypes[extname(file)] || 'application/octet-stream', 'X-Request-Id': id });
  if (method === 'HEAD') { response.end(); return; }
  createReadStream(file).pipe(response);
}

export function createApplication() {
  return createServer((request, response) => {
    const id = requestId(request);
    const url = new URL(request.url || '/', 'http://localhost');
    if (!['GET', 'HEAD'].includes(request.method || '')) {
      respond(response, 405, { type: 'https://asterion.invalid/problems/method-not-allowed', title: 'Method not allowed', status: 405, requestId: id }, id, request.method);
      return;
    }
    if (url.pathname === '/live') {
      respond(response, 200, { status: 'live', requestId: id }, id, request.method);
      return;
    }
    if (url.pathname === '/ready') {
      const ready = dependenciesReady();
      respond(response, ready ? 200 : 503, ready ? { status: 'ready', requestId: id } : { status: 'not_ready', reason: 'Required runtime dependencies are not configured.', requestId: id }, id, request.method);
      return;
    }
    if (url.pathname === '/health') {
      respond(response, 200, { status: 'degraded', dependencies: { database: Boolean(process.env.DATABASE_URL), redis: Boolean(process.env.REDIS_URL), marketData: false }, requestId: id }, id, request.method);
      return;
    }
    if (url.pathname === '/api/v1/markets') {
      respond(response, 200, { data: [], status: 'DATA_UNAVAILABLE', asOf: new Date().toISOString(), requestId: id }, id, request.method);
      return;
    }
    if (['/api/v1/account', '/api/v1/settings', '/api/v1/referrals', '/api/v1/agents', '/api/v1/crypto', '/api/v1/surge', '/api/v1/contracts', '/api/v1/betslips'].includes(url.pathname)) {
      respond(response, 503, { type: 'https://asterion.invalid/problems/feature-unavailable', title: 'Feature unavailable', status: 503, detail: 'This feature requires an authenticated, authorized, audited, provider-backed implementation and is not enabled.', requestId: id }, id, request.method);
      return;
    }
    if (url.pathname.startsWith('/api/')) {
      respond(response, 404, { type: 'https://asterion.invalid/problems/not-found', title: 'API route not found', status: 404, requestId: id }, id, request.method);
      return;
    }
    serveStatic(url.pathname, response, id, request.method);
  });
}
