'use strict';

/**
 * OTel tracing verification script.
 *
 * Run via test-tracing.sh (which sets TRACEPARENT + NODE_OPTIONS first).
 * Directly runnable for quick Node-only checks too, but TRACEPARENT must be set.
 *
 * What it checks:
 *  1. TRACEPARENT env var is present (trace-init.sh ran)
 *  2. An in-process HTTP server receives a request that carries:
 *     - traceparent  (W3C Trace Context)
 *     - x-b3-traceid (B3 multi-header)
 *     - x-b3-spanid
 *     - x-b3-sampled
 *  3. The trace-id in "traceparent" matches X_B3_TRACEID from the env
 *
 * Exits 0 on success, 1 on failure.
 */

const http = require('http');

const TRACEPARENT = process.env.TRACEPARENT;
const X_B3_TRACEID = (process.env.X_B3_TRACEID || '').toLowerCase();

// ── Helpers ──────────────────────────────────────────────────────────────────

function pass(msg) {
  console.log(`  ✅ PASS  ${msg}`);
}

function fail(msg) {
  console.error(`  ❌ FAIL  ${msg}`);
}

function section(title) {
  console.log(`\n─── ${title} ${'─'.repeat(Math.max(0, 50 - title.length))}`);
}

// ── Guard ─────────────────────────────────────────────────────────────────────

section('Prerequisites');

if (!TRACEPARENT) {
  fail('TRACEPARENT env var is not set. Run via test-tracing.sh, not directly.');
  process.exit(1);
}
pass(`TRACEPARENT is set: ${TRACEPARENT}`);

if (!X_B3_TRACEID) {
  fail('X_B3_TRACEID env var is not set. Run via test-tracing.sh.');
  process.exit(1);
}
pass(`X_B3_TRACEID is set: ${X_B3_TRACEID}`);

// ── Server + request ──────────────────────────────────────────────────────────

section('HTTP header injection test (Node http module)');

let failures = 0;

/**
 * Start an in-process echo server, send one GET request to it, inspect
 * the received headers, assert OTel injected the expected values, then shut down.
 */
function runHttpTest() {
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      res.writeHead(200);
      res.end('ok');

      const headers = req.headers;

      console.log('\n  Captured request headers:');
      for (const [k, v] of Object.entries(headers)) {
        console.log(`    ${k}: ${v}`);
      }
      console.log('');

      // ── Assertions ───────────────────────────────────────────────────────

      // 1. traceparent header is present
      if (headers['traceparent']) {
        pass(`"traceparent" header present: ${headers['traceparent']}`);
      } else {
        fail('"traceparent" header is MISSING — OTel W3C propagation did not inject it');
        failures++;
      }

      // 2. traceparent trace-id segment matches TRACEPARENT env var trace-id
      //    Format: 00-<traceId>-<spanId>-<flags>
      if (headers['traceparent']) {
        const parts = headers['traceparent'].split('-');
        const headerTraceId = parts[1] || '';
        const envTraceId = TRACEPARENT.split('-')[1] || '';
        if (headerTraceId === envTraceId) {
          pass(`"traceparent" trace-id matches TRACEPARENT env var: ${headerTraceId}`);
        } else {
          fail(`"traceparent" trace-id mismatch — header: ${headerTraceId}, env: ${envTraceId}`);
          failures++;
        }
      }

      // 3. B3 multi-header: x-b3-traceid
      if (headers['x-b3-traceid']) {
        pass(`"x-b3-traceid" header present: ${headers['x-b3-traceid']}`);
      } else {
        fail('"x-b3-traceid" header is MISSING — OTel B3 propagation did not inject it');
        failures++;
      }

      // 4. x-b3-traceid matches X_B3_TRACEID env var
      if (headers['x-b3-traceid']) {
        const headerB3 = headers['x-b3-traceid'].toLowerCase();
        if (headerB3 === X_B3_TRACEID) {
          pass(`"x-b3-traceid" matches X_B3_TRACEID env var: ${X_B3_TRACEID}`);
        } else {
          fail(`"x-b3-traceid" mismatch — header: ${headerB3}, env: ${X_B3_TRACEID}`);
          failures++;
        }
      }

      // 5. x-b3-spanid present
      if (headers['x-b3-spanid']) {
        pass(`"x-b3-spanid" header present: ${headers['x-b3-spanid']}`);
      } else {
        fail('"x-b3-spanid" header is MISSING');
        failures++;
      }

      // 6. x-b3-sampled present
      if (headers['x-b3-sampled']) {
        pass(`"x-b3-sampled" header present: ${headers['x-b3-sampled']}`);
      } else {
        fail('"x-b3-sampled" header is MISSING');
        failures++;
      }

      server.close(() => resolve());
    });

    server.listen(0, '127.0.0.1', () => {
      const { port } = server.address();
      console.log(`  Echo server listening on 127.0.0.1:${port}`);
      http.get(`http://127.0.0.1:${port}/trace-check`, (res) => {
        res.resume(); // drain response
      }).on('error', (err) => {
        fail(`HTTP request failed: ${err.message}`);
        failures++;
        server.close(() => resolve());
      });
    });
  });
}

// ── Main ──────────────────────────────────────────────────────────────────────

// When tracing.js is loaded via NODE_OPTIONS --require, the sdk is exported so
// we can call sdk.shutdown() here.  This flushes the BatchSpanProcessor queue
// to Jaeger before the process exits; without it process.exit() discards buffered spans.
const tracingModule = (() => {
  try { return require('./tracing.js'); } catch { return null; }
})();

async function main() {
  await runHttpTest();

  section('Result');
  const passed = failures === 0;

  if (passed) {
    console.log('\n  🎉  All checks passed — OTel trace header injection is working correctly.\n');
  } else {
    console.error(`\n  ⛔  ${failures} check(s) failed.\n`);
    console.error('  Possible reasons:');
    console.error('   • NODE_OPTIONS --require ./tracing.js was not applied before this process started');
    console.error('   • TRACEPARENT was not set when tracing.js was required');
    console.error('   • OTel SDK did not start (check for errors above)\n');
  }

  // Flush pending spans to the OTLP exporter (Jaeger) before exit.
  if (tracingModule?.sdk) {
    try {
      await tracingModule.sdk.shutdown();
    } catch (err) {
      console.error('  ⚠️  OTel SDK shutdown error:', err.message);
    }
  }

  process.exit(passed ? 0 : 1);
}

main();
