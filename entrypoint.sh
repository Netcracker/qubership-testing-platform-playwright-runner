#!/bin/bash
set -e

# Source tracing and logging first so all subsequent output carries a trace-id
source /scripts/trace-init.sh
source /scripts/logging.sh

# Main test job entrypoint script - coordinates all modules
log "Starting test job entrypoint script..."
log "Working directory: $(pwd)"
log "Timestamp: $(date)"

# Set default upload method
export UPLOAD_METHOD="${UPLOAD_METHOD:-sync}"
log "Upload method: $UPLOAD_METHOD"

# Import modular components
# shellcheck disable=SC1091
source /scripts/init.sh
# shellcheck disable=SC1091
source /scripts/git-clone.sh
# shellcheck disable=SC1091
source /scripts/runtime-setup.sh
# shellcheck disable=SC1091
source /scripts/test-runner.sh
# shellcheck disable=SC1091
source /scripts/upload-monitor.sh
# shellcheck disable=SC1091
source /scripts/email-notification/generate-email-notification-json.sh
# shellcheck disable=SC1091
source /scripts/native-report.sh
# shellcheck disable=SC1091
source /scripts/envgene.sh
# shellcheck disable=SC1091
source /scripts/push-metrics.sh
# shellcheck disable=SC1091
source /scripts/push-metrics-start.sh

FINALIZE_DONE=false
#shellcheck disable=SC2329
finalize_once() {
  local rc=$?

  if [ "$FINALIZE_DONE" != "true" ]; then
    FINALIZE_DONE=true
    echo "🔄 EXIT trap triggered with rc=$rc"

    set +e
    generate_email_notification_json
    push_metrics || true
    save_native_report "$TMP_DIR/playwright-report"
    finalize_upload
    sleep 15
    set -e
  fi
}

trap 'finalize_once' EXIT

# Execute main workflow
log "Starting test execution workflow..."

init_environment
load_envgene
clone_repository
setup_runtime_environment
start_upload_monitoring
push_metrics_start || true

set +e
run_tests
TEST_EXIT_CODE=$?
set -e

log "✅ Test job finished successfully!"
log "Tests finished with code: $TEST_EXIT_CODE"
exit 0