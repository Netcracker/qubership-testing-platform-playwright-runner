#!/usr/bin/env bats
# Unit tests for retry-aware Allure result aggregation.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
FIXTURES_DIR="$REPO_ROOT/tests/unit/fixtures/allure-results"
CALCULATE_SCRIPT="$REPO_ROOT/scripts/email-notification/calculate-email-notification-variables.sh"
CLONE_SYMLINK=""

setup() {
    TMP_DIR="$(mktemp -d)"
    mkdir -p "$TMP_DIR/allure-results"
    mkdir -p "$TMP_DIR/scripts/email-notification-generated"
    CLONE_SYMLINK="$(mktemp -u /tmp/clone-test-XXXXXX)"
    ln -s "$TMP_DIR" "$CLONE_SYMLINK"
}

teardown() {
    rm -f "$CLONE_SYMLINK"
    rm -rf "$TMP_DIR"
}

_copy_fixture() {
    cp "$FIXTURES_DIR/$1/"*-result.json "$TMP_DIR/allure-results/"
}

_run_calculate() {
    bash -c "
        ln -sfn '$TMP_DIR' /tmp/clone
        source '$CALCULATE_SCRIPT' '$TMP_DIR/allure-results'
        echo \"TEST_TOTAL_COUNT=\$TEST_TOTAL_COUNT\"
        echo \"TEST_PASSED_COUNT=\$TEST_PASSED_COUNT\"
        echo \"TEST_PASS_RATE=\$TEST_PASS_RATE\"
        cat \"\$TEST_DETAILS_FILE\"
    "
}

@test "retry-pass deduplicates by historyId and counts one passed test" {
    _copy_fixture retry-pass
    run _run_calculate
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'TEST_TOTAL_COUNT=1'
    echo "$output" | grep -q 'TEST_PASSED_COUNT=1'
    echo "$output" | grep -q 'TEST_PASS_RATE=100.00'
    echo "$output" | grep -q '(1 retry)'
}

@test "no-retry detail line has no retry suffix" {
    _copy_fixture no-retry
    run _run_calculate
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '✅ PASSED | Single Test'
    ! echo "$output" | grep -qi 'retry'
}

@test "two-tests counts distinct historyIds separately" {
    _copy_fixture two-tests
    run _run_calculate
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'TEST_TOTAL_COUNT=2'
}
