#!/bin/bash
set -e

# Source tracing and logging first so all subsequent output carries a trace-id
source /scripts/trace-init.sh
source /scripts/logging.sh
generate_trace_id

# Bootstrap OTel SDK for all Node.js processes so trace headers are propagated
# on outgoing HTTP requests.  Must be set after generate_trace_id so TRACEPARENT
# is already exported.  The ${NODE_OPTIONS:+ ...} idiom preserves any existing
# NODE_OPTIONS value set by the caller.
export NODE_OPTIONS="--require /app/tracing.js${NODE_OPTIONS:+ $NODE_OPTIONS}"
log "OTel tracing bootstrap configured via NODE_OPTIONS"

# Main test job entrypoint script - coordinates all modules
log "Starting test job entrypoint script..."
log "Working directory: $(pwd)"
log "Timestamp: $(date)"

# Set default upload method
export UPLOAD_METHOD="${UPLOAD_METHOD:-sync}"
log "Upload method: $UPLOAD_METHOD"

# Import modular components
source /scripts/init.sh
source /scripts/git-clone.sh
source /scripts/runtime-setup.sh
source /scripts/test-runner.sh
source /scripts/upload-monitor.sh
source /scripts/email-notification/generate-email-notification-json.sh
source /scripts/native-report.sh

# Execute main workflow
log "Starting test execution workflow..."

init_environment
clone_repository
setup_runtime_environment
start_upload_monitoring
run_tests
generate_email_notification_json
save_native_report $TMP_DIR/playwright-report
finalize_upload

sleep 15

log "Test job finished successfully!"
