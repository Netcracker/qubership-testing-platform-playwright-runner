#!/usr/bin/env bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TMP_DIR="$(mktemp -d)"
    export TMP_DIR
    mkdir -p "$TMP_DIR/allure-results" "$TMP_DIR/attachments" \
        "$TMP_DIR/scripts/email-notification-generated"
    export ATP_STORAGE_PROVIDER=aws
    export ATP_STORAGE_BUCKET=bucket
    export ENVIRONMENT_NAME=env
    export CURRENT_DATE=2026-09-25
    export CURRENT_TIME=12-00-00
    export ATP_REPORT_VIEW_UI_URL=https://viewer.example
    export RESULTS_S3_PATH=s3://bucket/Result/env/2026-09-25/12-00-00/
    export REPORTS_S3_PATH=s3://bucket/Report/env/2026-09-25/12-00-00/
    export ENABLE_JIRA_INTEGRATION=false
    export _LOCAL_S3_KEY=key
    export _LOCAL_S3_SECRET=secret

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/allure-report.sh"
    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/jira-integration.sh"
    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/upload-monitor.sh"

    s3_sync_directory() { echo "SYNC:$1:$2"; }
    s3_upload_file() { echo "UPLOAD:$1:$2"; }
    generate_and_upload_allure_report() { echo "GENERATE"; }
    run_jira_integration() { echo "JIRA:$1"; }
    notify_allure_proc() { echo "NOTIFY"; }
    restore_aws_credentials() { :; }
    generate_result_urls() {
        RESULTS_URL=results
        REPORTS_URL=reports
        REPORTS_FOLDER_PATH=Report/env/date/time/allure-report/
    }
    final_cleanup() { :; }
}

teardown() {
    rm -rf "$TMP_DIR"
}

@test "runner mode wins over configured allure-proc and emits no marker" {
    export ATP_ALLURE_REPORT_GENERATE_IN_RUNNER=true
    export ATP_ALLURE_PROC_HOST=https://allure-proc.example

    run finalize_upload

    [ "$status" -eq 0 ]
    [[ "$output" == *"Allure report mode: runner"* ]]
    [[ "$output" == *"GENERATE"* ]]
    [[ "$output" == *"JIRA:$TMP_DIR/allure-report"* ]]
    [[ "$output" != *"allure-results.uploaded"* ]]
    [[ "$output" != *"NOTIFY"* ]]
}

@test "external mode uploads marker and notifies allure-proc" {
    export ATP_ALLURE_REPORT_GENERATE_IN_RUNNER=false
    export ATP_ALLURE_PROC_HOST=https://allure-proc.example

    run finalize_upload

    [ "$status" -eq 0 ]
    [[ "$output" == *"Allure report mode: external allure-proc"* ]]
    [[ "$output" == *"allure-results.uploaded"* ]]
    [[ "$output" == *"NOTIFY"* ]]
    [[ "$output" != *"GENERATE"* ]]
}

@test "upload-only mode keeps marker without direct generation or notification" {
    export ATP_ALLURE_REPORT_GENERATE_IN_RUNNER=false
    unset ATP_ALLURE_PROC_HOST

    run finalize_upload

    [ "$status" -eq 0 ]
    [[ "$output" == *"Allure report mode: upload-only"* ]]
    [[ "$output" == *"allure-results.uploaded"* ]]
    [[ "$output" != *"NOTIFY"* ]]
    [[ "$output" != *"GENERATE"* ]]
}

@test "report URL uses the stable Report prefix" {
    run allure_report_url
    [ "$status" -eq 0 ]
    [ "$output" = "https://viewer.example/Report/env/2026-09-25/12-00-00/allure-report/index.html" ]
}

@test "style patch injects CSS into generated index" {
    mkdir -p "$TMP_DIR/report"
    printf '<html><head></head><body></body></html>' > "$TMP_DIR/report/index.html"

    patch_allure_report_styles "$TMP_DIR/report"

    grep -q 'duration-trend' "$TMP_DIR/report/index.html"
}

@test "generation failure is returned to finalization" {
    printf '{}\n' > "$TMP_DIR/allure-results/test-result.json"
    cat > "$TMP_DIR/allure" <<'EOF'
#!/bin/sh
echo "generation failed"
exit 1
EOF
    chmod +x "$TMP_DIR/allure"
    ALLURE_CLI="$TMP_DIR/allure"

    run generate_allure_report

    [ "$status" -eq 1 ]
    [[ "$output" == *"Allure report generation failed"* ]]
}

@test "viewer link is uploaded beside results" {
    mkdir -p "$TMP_DIR/allure-report"

    run upload_allure_report

    [ "$status" -eq 0 ]
    [[ "$output" == *"SYNC:$TMP_DIR/allure-report:s3://bucket/Report/env/2026-09-25/12-00-00/allure-report/"* ]]
    [[ "$output" == *"UPLOAD:$TMP_DIR/link_to_report_viewer.txt:s3://bucket/Result/env/2026-09-25/12-00-00/link_to_report_viewer.txt"* ]]
    [ "$(cat "$TMP_DIR/link_to_report_viewer.txt")" = \
        "https://viewer.example/Report/env/2026-09-25/12-00-00/allure-report/index.html" ]
}

@test "MinIO s5cmd commands include configured endpoint" {
    export ATP_STORAGE_PROVIDER=minio
    export ATP_STORAGE_SERVER_URL=https://minio.example
    s5cmd() { printf 'S5CMD:%s\n' "$*"; }

    run s5cmd_storage cp source destination

    [ "$status" -eq 0 ]
    [[ "$output" == *"--endpoint-url https://minio.example cp source destination"* ]]
}

@test "Jira integration skips cleanly when configuration is missing" {
    unset JIRA_BASE_URL JIRA_USERNAME JIRA_PASSWORD JIRA_PROJECT_KEY

    run validate_jira_configuration

    [ "$status" -eq 1 ]
    [[ "$output" == *"Jira integration skipped; missing:"* ]]
}

@test "Jira ticket label is extracted from generated Allure test case" {
    cat > "$TMP_DIR/test-case.json" <<'JSON'
{"name":"test","labels":[{"name":"jiraTicketId","value":"ATP-123"}]}
JSON

    run extract_jira_ticket_id "$TMP_DIR/test-case.json"

    [ "$status" -eq 0 ]
    [ "$output" = "ATP-123" ]
}

@test "Jira update adds comment and executes matching transition" {
    jira_request() {
        printf '%s|%s\n' "$1" "${2:-GET}" >> "$TMP_DIR/jira-requests"
        if [[ "$1" == */transitions && "${2:-GET}" == "GET" ]]; then
            printf '{"transitions":[{"id":"31","name":"Pass"}]}'
        fi
    }

    run update_jira_ticket "ATP-123" "test name" "PASSED" "https://viewer/report"

    [ "$status" -eq 0 ]
    grep -q '/comment|POST' "$TMP_DIR/jira-requests"
    grep -q '/transitions|POST' "$TMP_DIR/jira-requests"
}
