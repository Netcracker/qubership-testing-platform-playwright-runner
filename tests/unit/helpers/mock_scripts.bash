#!/usr/bin/env bash
# Stub implementations of all functions sourced by entrypoint.sh from /scripts/*.sh
# These replace the real implementations during unit tests so entrypoint.sh
# can be sourced without a container environment.

# ── error-handler.sh ────────────────────────────────────────────────────────
FAIL_MESSAGE=""
FINALIZE_DONE=false

fail() {
    local msg="${1:-Unknown error}"
    echo "FAIL: $msg" >&2
    FAIL_MESSAGE="$msg"
    exit 1
}

finalize_once() {
    echo "mock: finalize_once"
}

# ── init.sh ─────────────────────────────────────────────────────────────────
init_environment() { echo "mock: init_environment"; }

# ── git-clone.sh ────────────────────────────────────────────────────────────
clone_repository() { echo "mock: clone_repository"; }

# ── render-environment-configuration.sh ─────────────────────────────────────
render_environment_configuration() { echo "mock: render_environment_configuration"; }

# ── envgene.sh ───────────────────────────────────────────────────────────────
load_envgene() { echo "mock: load_envgene"; }

# ── runtime-setup.sh ─────────────────────────────────────────────────────────
setup_runtime_environment() { echo "mock: setup_runtime_environment"; }

# ── upload-monitor.sh ────────────────────────────────────────────────────────
start_upload_monitoring() { echo "mock: start_upload_monitoring"; }
finalize_upload()         { echo "mock: finalize_upload"; }
clear_sensitive_vars()    { echo "mock: clear_sensitive_vars"; }
restore_aws_credentials() { echo "mock: restore_aws_credentials"; }
final_cleanup()           { echo "mock: final_cleanup"; }

# ── test-runner.sh ───────────────────────────────────────────────────────────
run_tests() { echo "mock: run_tests"; }

# ── test-runner-bruno.sh ─────────────────────────────────────────────────────
run_bruno_from_test_params() { echo "mock: run_bruno_from_test_params"; }

# ── email-notification/generate-email-notification-json.sh ───────────────────
generate_email_notification_json() { echo "mock: generate_email_notification_json"; }

# ── native-report.sh ─────────────────────────────────────────────────────────
save_native_report() { echo "mock: save_native_report"; }

export -f fail finalize_once
export -f init_environment clone_repository render_environment_configuration
export -f load_envgene setup_runtime_environment
export -f start_upload_monitoring finalize_upload clear_sensitive_vars
export -f restore_aws_credentials final_cleanup run_tests
export -f run_bruno_from_test_params generate_email_notification_json
export -f save_native_report
