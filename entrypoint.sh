#!/bin/bash

# Main test job entrypoint script - coordinates all modules
echo "🔧 Starting test job entrypoint script..."
echo "📁 Working directory: $(pwd)"
echo "📅 Timestamp: $(date)"

# Set default upload method
export UPLOAD_METHOD="${UPLOAD_METHOD:-sync}"
echo "📤 Upload method: $UPLOAD_METHOD"

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
# shellcheck disable=SC1091
source /scripts/parse-extra-vars.sh

# Execute main workflow
echo "🚀 Starting test execution workflow..."

# Runner-specific report directory consumed by finalize_once() in error-handler.sh.
# Override this in other runners (e.g. python-runner) before the trap fires.
# shellcheck disable=SC2034
NATIVE_REPORT_DIR="playwright-report"

# Log ephemeral disk usage at exit (success or failure) to tune EPHEMERAL_STORAGE_* limits.
# finalize_once() is defined in error-handler.sh (sourced above).
# Register it here after all scripts are sourced so every function it calls is available.
trap 'finalize_once' EXIT

# Log ephemeral disk usage (tune EPHEMERAL_STORAGE_* from this). Runs as the first step
# of the trap-independent path; a trailing `du` on each exit is not reachable because
# finalize_once always exits 0, so it is printed right after the test run instead.
log_disk_usage() {
    echo "Disk usage: tmp=$(du -sh "${TMP_DIR:-/tmp}" 2>/dev/null | cut -f1) app=$(du -sh /app 2>/dev/null | cut -f1) project=$(du -sh "${PROJECT_DIR:${TMP_DIR:-/tmp}}" 2>/dev/null | cut -f1)"
}

init_environment              || fail "Environment initialization failed"
parse_extra_vars              || fail "EXTRA_VARS parsing failed"
clone_repository              || fail "Repository clone failed"
render_environment_configuration || fail "Render Environment Configuration Failed"
setup_runtime_environment     || fail "Runtime setup failed"
start_upload_monitoring
push_metrics_start || true
run_tests                     || fail "Test runner failed"
log_disk_usage

echo "✅ Test job finished successfully!"