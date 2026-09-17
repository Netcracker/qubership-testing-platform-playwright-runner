// Unit tests for packages/atp-b3-trace — run with: node --test tests/unit/atp-b3-trace.test.js
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const { traceIdForTest } = require(path.join('..', '..', 'packages', 'atp-b3-trace'));

test('traceIdForTest concatenates PROJECT_ID, RUN_ID and a 5-char hex testcase id', () => {
  process.env.PROJECT_ID = 'proj';
  process.env.RUN_ID = 'run1';
  const traceId = traceIdForTest({ testId: 'spec-1::creates an order' });
  assert.match(traceId, /^projrun1[0-9a-f]{5}$/);
});

test('traceIdForTest is stable for the same testId (retries share one trace)', () => {
  process.env.PROJECT_ID = 'proj';
  process.env.RUN_ID = 'run1';
  const testInfo = { testId: 'spec-1::creates an order' };
  assert.equal(traceIdForTest(testInfo), traceIdForTest(testInfo));
});

test('traceIdForTest differs across testId values', () => {
  process.env.PROJECT_ID = 'proj';
  process.env.RUN_ID = 'run1';
  const a = traceIdForTest({ testId: 'spec-1::test a' });
  const b = traceIdForTest({ testId: 'spec-1::test b' });
  assert.notEqual(a, b);
});

test('traceIdForTest returns null when PROJECT_ID is missing', () => {
  delete process.env.PROJECT_ID;
  process.env.RUN_ID = 'run1';
  assert.equal(traceIdForTest({ testId: 'spec-1::creates an order' }), null);
});

test('traceIdForTest returns null when RUN_ID is missing', () => {
  process.env.PROJECT_ID = 'proj';
  delete process.env.RUN_ID;
  assert.equal(traceIdForTest({ testId: 'spec-1::creates an order' }), null);
});
