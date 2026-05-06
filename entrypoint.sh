#!/bin/bash

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
source /scripts/error-handler.sh
# shellcheck disable=SC1091
source /scripts/init.sh
# shellcheck disable=SC1091
source /scripts/git-clone.sh
# shellcheck disable=SC1091
source /scripts/runtime-setup.sh
# shellcheck disable=SC1091
source /scripts/test-runner.sh
# shellcheck disable=SC1091
source /scripts/test-runner-bruno.sh
# shellcheck disable=SC1091
source /scripts/upload-monitor.sh
# shellcheck disable=SC1091
source /scripts/email-notification/generate-email-notification-json.sh
# shellcheck disable=SC1091
source /scripts/native-report.sh
# shellcheck disable=SC1091
source /scripts/envgene.sh
# shellcheck disable=SC1091
source /scripts/render-environment-configuration.sh
# shellcheck disable=SC1091
source /scripts/push-metrics.sh
# shellcheck disable=SC1091
source /scripts/push-metrics-start.sh

# Execute main workflow
log "🚀 Starting test execution workflow..."

# Runner-specific report directory consumed by finalize_once() in error-handler.sh.
# Override this in other runners (e.g. python-runner) before the trap fires.
# shellcheck disable=SC2034
NATIVE_REPORT_DIR="playwright-report"

# finalize_once() is defined in error-handler.sh (sourced above).
# Register it here after all scripts are sourced so every function it calls is available.
trap 'finalize_once' EXIT

init_environment              || fail "Environment initialization failed"
clone_repository              || fail "Repository clone failed"
render_environment_configuration || fail "Render Environment Configuration Failed"
load_envgene || fail "Load Envgen Failed"
setup_runtime_environment     || fail "Runtime setup failed"
start_upload_monitoring
push_metrics_start || true
run_tests                     || fail "Test runner failed"

log "✅ Test job finished successfully!"