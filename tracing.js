'use strict';

const { NodeSDK } = require('@opentelemetry/sdk-node');
const { HttpInstrumentation } = require('@opentelemetry/instrumentation-http');
const { UndiciInstrumentation } = require('@opentelemetry/instrumentation-undici');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
const { B3Propagator, B3InjectEncoding } = require('@opentelemetry/propagator-b3');
const { W3CTraceContextPropagator, CompositePropagator } = require('@opentelemetry/core');
const { AsyncLocalStorageContextManager } = require('@opentelemetry/context-async-hooks');
const { propagation, ROOT_CONTEXT, defaultTextMapGetter } = require('@opentelemetry/api');

const traceparent = process.env.TRACEPARENT;
if (!traceparent) {
  // No trace context from trace-init.sh -- skip OTel bootstrap entirely
  return;
}

// Extract TRACEPARENT directly with the W3C propagator — the global
// propagation API is still a no-op here because sdk.start() hasn't run yet.
const extractedCtx = new W3CTraceContextPropagator().extract(
  ROOT_CONTEXT,
  { traceparent },
  defaultTextMapGetter
);

// AsyncLocalStorage returns ROOT_CONTEXT when no explicit context is active.
// Override active() so that case falls back to extractedCtx, which carries
// the bash-generated trace-id.  Any explicitly-started span still wins.
class InheritedContextManager extends AsyncLocalStorageContextManager {
  active() {
    const ctx = super.active();
    return ctx === ROOT_CONTEXT ? extractedCtx : ctx;
  }
}

const compositePropagator = new CompositePropagator({
  propagators: [
    new W3CTraceContextPropagator(),
    new B3Propagator({ injectEncoding: B3InjectEncoding.MULTI_HEADER }),
  ],
});

const sdk = new NodeSDK({
  serviceName: process.env.OTEL_SERVICE_NAME || 'atp3-playwright-runner',
  traceExporter: process.env.OTEL_EXPORTER_OTLP_ENDPOINT
    ? new OTLPTraceExporter()
    : undefined,
  instrumentations: [
    new HttpInstrumentation(),
    new UndiciInstrumentation(),
  ],
  textMapPropagator: compositePropagator,
  contextManager: new InheritedContextManager().enable(),
});

sdk.start();

// NodeSDK only wires textMapPropagator from config when a traceExporter or
// spanProcessor is provided (guards on _tracerProviderConfig). Without them it
// falls back to env-default W3C+Baggage propagators, ignoring our B3 config.
//
// setGlobalPropagator() uses registerGlobal(allowOverride=false), so a second
// call silently fails once the SDK has already registered. We must unregister
// the SDK's propagator first, then install our CompositePropagator (W3C + B3).
propagation.disable();
propagation.setGlobalPropagator(compositePropagator);
