/* global require, module, process */
// atp-b3-trace — B3 trace/span header propagation for Playwright test suites.
//
// Header contract (shared with the other ATP runners):
//   X-B3-TraceId: <PROJECT_ID><RUN_ID><testcase_id>   fixed for one Playwright test
//   X-B3-SpanId:  16 lowercase hex characters          fresh for every intercepted request
//   X-B3-Sampled: 1                                    always
//
// PROJECT_ID and RUN_ID come from the orchestrator and are used as-is. testcase_id is derived
// from Playwright's own testInfo.testId, so it stays the same across retries of one test.

const crypto = require('crypto');
const base = require('@playwright/test');

function randomHex16() {
  return crypto.randomBytes(8).toString('hex');
}

/**
 * Returns the X-B3-TraceId for one Playwright test, or null when PROJECT_ID/RUN_ID is unset.
 * @param {import('@playwright/test').TestInfo} testInfo
 * @returns {string | null}
 */
function traceIdForTest(testInfo) {
  const projectId = process.env.PROJECT_ID;
  const runId = process.env.RUN_ID;
  if (!projectId || !runId) {
    return null;
  }
  const testcaseId = crypto.createHash('sha1').update(testInfo.testId).digest('hex').slice(0, 5);
  return `${projectId}${runId}${testcaseId}`;
}

function b3HeadersForStep(traceId) {
  return {
    'X-B3-TraceId': traceId,
    'X-B3-SpanId': randomHex16(),
    'X-B3-Sampled': '1',
  };
}

const METHODS_WITH_HEADERS = ['get', 'post', 'put', 'patch', 'delete', 'head', 'fetch'];

/**
 * `test` from `@playwright/test`, extended so every request the `page` and `request` fixtures
 * make carries B3 trace/span headers. Import this instead of `@playwright/test` to opt in; no
 * other change is required.
 */
const test = base.test.extend({
  context: async ({ context }, use, testInfo) => {
    const traceId = traceIdForTest(testInfo);
    if (traceId) {
      await context.route('**/*', (route) =>
        route.continue({ headers: { ...route.request().headers(), ...b3HeadersForStep(traceId) } })
      );
    }
    await use(context);
  },

  request: async ({ request }, use, testInfo) => {
    const traceId = traceIdForTest(testInfo);
    if (!traceId) {
      await use(request);
      return;
    }
    const wrapped = new Proxy(request, {
      get(target, prop, receiver) {
        if (typeof prop === 'string' && METHODS_WITH_HEADERS.includes(prop)) {
          return (urlOrRequest, options = {}) =>
            target[prop](urlOrRequest, { ...options, headers: { ...options.headers, ...b3HeadersForStep(traceId) } });
        }
        return Reflect.get(target, prop, receiver);
      },
    });
    await use(wrapped);
  },
});

module.exports = { test, expect: base.expect, traceIdForTest };
