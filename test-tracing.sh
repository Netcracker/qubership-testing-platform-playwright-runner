#!/bin/bash

# Local tracing verification script — Approach A (WSL native, no Docker)
#
# Run from the project root in WSL:
#   bash test-tracing.sh
#
# Optional environment overrides:
#   OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318  bash test-tracing.sh
#   ATP_PROJECT_ID=42  bash test-tracing.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared scripts (same order as entrypoint.sh)
source "${SCRIPT_DIR}/scripts/trace-init.sh"
source "${SCRIPT_DIR}/scripts/logging.sh"

# Generate TRACEPARENT + B3 env vars — same as entrypoint.sh does
generate_trace_id

echo ""
echo "========================================="
echo "  OTel Tracing — Local Verification"
echo "========================================="
echo "TRACEPARENT     = ${TRACEPARENT}"
echo "X_B3_TRACEID    = ${X_B3_TRACEID}"
echo "X_B3_SPANID     = ${X_B3_SPANID}"
echo "X_B3_SAMPLED    = ${X_B3_SAMPLED}"
echo ""

# Mirror the NODE_OPTIONS export from entrypoint.sh exactly
export NODE_OPTIONS="--require ${SCRIPT_DIR}/tracing.js${NODE_OPTIONS:+ $NODE_OPTIONS}"
log "NODE_OPTIONS: ${NODE_OPTIONS}"

# Default service name for local testing
export OTEL_SERVICE_NAME="${OTEL_SERVICE_NAME:-atp3-playwright-runner-local}"

# If OTEL_EXPORTER_OTLP_ENDPOINT is already set (e.g. pointing at a local
# Jaeger), tracing.js will export spans there automatically.
if [[ -n "${OTEL_EXPORTER_OTLP_ENDPOINT}" ]]; then
    log "OTLP exporter endpoint: ${OTEL_EXPORTER_OTLP_ENDPOINT}"
else
    log "OTEL_EXPORTER_OTLP_ENDPOINT not set — propagation only (no span export)"
fi

echo ""
log "Running Node.js header-injection verification..."
echo ""

node "${SCRIPT_DIR}/test-tracing.js"
