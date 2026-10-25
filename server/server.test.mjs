import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createAiServer, redactReceipt, validateSuggestion } from './server.mjs';

const token = 'test-pairing-token-12345678901234567890';
async function run(options, work) {
  const server = createAiServer({ apiKey: 'fake-key-never-sent', token, ...options });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const url = `http://127.0.0.1:${server.address().port}`;
  try { await work(url); } finally { server.closeAllConnections(); await new Promise(resolve => server.close(resolve)); }
}
const request = (url, body, bearer = token) => fetch(`${url}/v1/category`, {
  method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${bearer}` }, body: JSON.stringify(body),
});
const input = { merchant: 'QUAN CA PHE', receiptText: 'CA PHE SUA 65000' };
test('redacts email and phone without changing grouped VND', () => {
  const s = redactReceipt('Email a@example.com Tel 0901234567 Tổng 65.000');
  assert(!s.includes('a@example.com')); assert(!s.includes('0901234567')); assert(s.includes('65.000'));
});
test('rejects category outside the fixed list', () => {
  assert.throws(() => validateSuggestion({ category: 'Unknown', reason: 'x' }));
});
test('unauthorised request never calls Gemini', async () => {
  await run({ fetchImpl: () => { throw new Error('must not call'); } }, async url => {
    assert.equal((await request(url, input, 'bad')).status, 401);
  });
});
test('uses schema, returns only validated fields and redacts outbound text', async () => {
  let outbound;
  await run({ fetchImpl: async (url, opts) => {
    outbound = JSON.parse(opts.body);
    return Response.json({ candidates: [{ content: { parts: [{ text: JSON.stringify({ category: 'Ăn uống', reason: 'Hóa đơn cà phê.' }) }] } }] });
  } }, async url => {
    const r = await request(url, { ...input, receiptText: 'Email a@example.com' });
    assert.equal(r.status, 200); assert.equal((await r.json()).category, 'Ăn uống');
    assert.equal(outbound.generationConfig.responseMimeType, 'application/json');
    assert(!outbound.contents[0].parts[0].text.includes('a@example.com'));
  });
});
test('rejects invalid and oversized inputs', async () => {
  await run({}, async url => {
    assert.equal((await request(url, {})).status, 400);
    assert.equal((await request(url, { ...input, receiptText: 'a'.repeat(21000) })).status, 413);
  });
});
test('does not leak upstream error body or key', async () => {
  await run({ fetchImpl: async () => new Response('fake-key-never-sent secret details', { status: 403 }) }, async url => {
    const r = await request(url, input); const text = await r.text();
    assert.equal(r.status, 502); assert(!text.includes('secret')); assert(!text.includes('fake-key')); assert(text.includes('AI_KEY_DENIED'));
  });
});
test('rejects malformed AI output without pretending a suggestion succeeded', async () => {
  await run({ fetchImpl: async () => Response.json({ candidates: [{ content: { parts: [{ text: '{bad}' }] } }] }) }, async url => {
    const r = await request(url, input); assert.equal(r.status, 502); assert.equal((await r.json()).error, 'AI_INVALID_RESPONSE');
  });
});
test('limits authenticated requests before calling upstream', async () => {
  await run({ requestsPerMinute: 1, fetchImpl: async () => new Response('', { status: 429 }) }, async url => {
    assert.equal((await request(url, input)).status, 502); assert.equal((await request(url, input)).status, 429);
  });
});
test('rejects missing or too-short pairing secret', () => {
  assert.throws(() => createAiServer({ apiKey: 'x', token: 'short' }));
});
