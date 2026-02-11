#!/bin/bash
set -e

# Main test job entrypoint script - coordinates all modules
echo "🔧 Starting test job entrypoint script..."
echo "📁 Working directory: $(pwd)"
echo "📅 Timestamp: $(date)"

# Set default upload method
export UPLOAD_METHOD="${UPLOAD_METHOD:-sync}"
echo "📤 Upload method: $UPLOAD_METHOD"

# Generate trace ID and export B3 headers (job-level correlation)
if [ -f "$WORK_DIR/scripts/trace-id-generator.sh" ]; then
  # shellcheck disable=SC1091
  source $WORK_DIR/scripts/trace-id-generator.sh
  echo "🔍 B3 Trace ID (X-B3-TraceId): ${X_B3_TRACE_ID:-<not set>}"
  echo "🔍 B3 Span ID  (X-B3-SpanId):  ${X_B3_SPAN_ID:-<not set>}"
  echo "🔍 B3 Sampled  (X-B3-Sampled): ${X_B3_SAMPLED:-<not set>}"
else
  echo "⚠️ $WORK_DIR/scripts/trace-id-generator.sh not found; skipping B3 trace generation"
fi

# Initialize OpenTelemetry in Node processes (if enabled)
if [ "${OTEL_ENABLED:-true}" = "true" ]; then
  if [ -f "$WORK_DIR/scripts/otel-init.js" ]; then
    export NODE_OPTIONS="${NODE_OPTIONS:-} --require $WORK_DIR/scripts/otel-init.js"
    echo "✅ OpenTelemetry enabled (NODE_OPTIONS updated)"
  else
    echo "⚠️ $WORK_DIR/scripts/otel-init.js not found; OpenTelemetry not initialized"
  fi
else
  echo "ℹ️ OpenTelemetry disabled (OTEL_ENABLED=$OTEL_ENABLED)"
fi

# Import modular components
source /scripts/init.sh
source /scripts/git-clone.sh
source /scripts/runtime-setup.sh
source /scripts/test-runner.sh
source /scripts/upload-monitor.sh
source /scripts/email-notification/generate-email-notification-json.sh
source /scripts/native-report.sh

# Execute main workflow
echo "🚀 Starting test execution workflow..."

init_environment
clone_repository
setup_runtime_environment
start_upload_monitoring
run_tests
generate_email_notification_json
save_native_report $TMP_DIR/playwright-report
finalize_upload

sleep 15

echo "✅ Test job finished successfully!"