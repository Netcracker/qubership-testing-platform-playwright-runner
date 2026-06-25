#!/usr/bin/env bats
# Unit tests for ARG_MAX-safe email notification file flow.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
FIXTURES_DIR="$REPO_ROOT/tests/unit/fixtures/allure-results"
CLONE_SYMLINK=""

setup() {
    TMP_DIR="$(mktemp -d)"
    mkdir -p "$TMP_DIR/allure-results"
    mkdir -p "$TMP_DIR/scripts/email-notification-generated"
    CLONE_SYMLINK="$(mktemp -u /tmp/clone-test-XXXXXX)"
    ln -s "$TMP_DIR" "$CLONE_SYMLINK"
    export CLONE_ROOT="$CLONE_SYMLINK"
}

teardown() {
    rm -f "$CLONE_SYMLINK"
    rm -rf "$TMP_DIR"
}

_clone_allure_fixtures() {
    local fixture="${1:-no-retry}"
    cp "$FIXTURES_DIR/$fixture/"*-result.json "$TMP_DIR/allure-results/"
}

@test "calculate streams test details to TEST_DETAILS_FILE and unsets TEST_DETAILS_STRING" {
    _clone_allure_fixtures
    run bash -c "
        source '$REPO_ROOT/scripts/email-notification/calculate-email-notification-variables.sh' '$TMP_DIR/allure-results'
        echo \"TEST_DETAILS_FILE=\${TEST_DETAILS_FILE:-}\"
        if [ -n \"\${TEST_DETAILS_STRING+x}\" ]; then echo STRING_STILL_SET; fi
        wc -l < \"\$TEST_DETAILS_FILE\"
    "
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'TEST_DETAILS_FILE='
    ! echo "$output" | grep -q 'STRING_STILL_SET'
}

@test "generate_email_notification_json builds deduplicated test_details from allure files" {
    _clone_allure_fixtures no-retry
    run bash -c "
        ln -sfn '$TMP_DIR' /tmp/clone
        source '$REPO_ROOT/scripts/email-notification/generate-email-notification-json.sh'
        generate_email_notification_json
        jq '.test_details | length' \"\$JSON_FILE\"
    "
    [ "$status" -eq 0 ]
    [ "${lines[-1]}" -eq 1 ]
}
