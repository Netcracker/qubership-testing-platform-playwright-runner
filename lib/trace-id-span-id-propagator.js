'use strict';

const { trace } = require('@opentelemetry/api');

/**
 * Minimal propagator that injects trace-id and span-id headers (lowercase, hyphenated).
 * Duplicates the values from B3 (X-B3-TraceId, X-B3-SpanId) for services that expect
 * these header names.
 *
 * extract() is a no-op: we do not extract context from these headers.
 */
class TraceIdSpanIdPropagator {
  inject(context, carrier, setter) {
    const spanContext = trace.getSpanContext(context);
    if (!spanContext || !trace.isSpanContextValid(spanContext)) {
      return;
    }
    setter.set(carrier, 'trace-id', spanContext.traceId);
    setter.set(carrier, 'span-id', spanContext.spanId);
  }

  extract(context, carrier, getter) {
    return context;
  }

  fields() {
    return ['trace-id', 'span-id'];
  }
}

module.exports = { TraceIdSpanIdPropagator };
