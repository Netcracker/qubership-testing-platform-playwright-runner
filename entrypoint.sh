#!/bin/bash
set -e

# Main test job entrypoint script - coordinates all modules
echo "🔧 Starting test job entrypoint script..."
echo "📁 Working directory: $(pwd)"
echo "📅 Timestamp: $(date)"

# Set default upload method
export UPLOAD_METHOD="${UPLOAD_METHOD:-sync}"
echo "📤 Upload method: $UPLOAD_METHOD"

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
load_envgene
clone_repository
setup_runtime_environment
start_upload_monitoring
run_tests
generate_email_notification_json
save_native_report $TMP_DIR/playwright-report
finalize_upload

sleep 15

echo "✅ Test job finished successfully!"