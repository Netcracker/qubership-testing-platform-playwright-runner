'use strict';

const { test: base, expect } = require('@playwright/test');

// Extends the default Playwright test fixture to inject trace-propagation
// headers on every BrowserContext.  This covers page.goto() and all
// request.get/post() calls that go through the browser engine and therefore
// bypass Node's http module (which is handled automatically by tracing.js).
//
// Test repos opt in with a one-line change:
//   const { test, expect } = require('otel-playwright-fixture');
const test = base.extend({
  context: async ({ context }, use) => {
    const traceparent = process.env.TRACEPARENT;
    if (traceparent) {
      const headers = { traceparent };
      if (process.env.X_B3_TRACEID) {
        headers['X-B3-TraceId'] = process.env.X_B3_TRACEID;
        headers['trace-id'] = process.env.X_B3_TRACEID;
        headers['X-B3-SpanId'] = process.env.X_B3_SPANID || '';
        headers['span-id'] = process.env.X_B3_SPANID || '';
        headers['X-B3-Sampled'] = process.env.X_B3_SAMPLED || '1';
      }
      await context.setExtraHTTPHeaders(headers);
    }
    await use(context);
  },
});

module.exports = { test, expect };
