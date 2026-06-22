#!/usr/bin/env bats
# Unit tests for scripts/email-notification/calculate-email-notification-variables.sh

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
CALCULATE_SCRIPT="$REPO_ROOT/scripts/email-notification/calculate-email-notification-variables.sh"
FIXTURES_ROOT="$REPO_ROOT/tests/unit/fixtures/allure-results"

run_calculate() {
    local fixture_dir="$1"
    bash -c "
        source '$CALCULATE_SCRIPT' '$fixture_dir' >/dev/null
        echo \"TEST_TOTAL_COUNT=\$TEST_TOTAL_COUNT\"
        echo \"TEST_PASSED_COUNT=\$TEST_PASSED_COUNT\"
        echo \"TEST_FAILED_COUNT=\$TEST_FAILED_COUNT\"
        echo \"TEST_SKIPPED_COUNT=\$TEST_SKIPPED_COUNT\"
        echo \"TEST_PASS_RATE=\$TEST_PASS_RATE\"
        echo \"TEST_PASS_RATE_ROUNDED=\$TEST_PASS_RATE_ROUNDED\"
        echo \"TEST_OVERALL_STATUS=\$TEST_OVERALL_STATUS\"
        printf '%s' \"\$TEST_DETAILS_STRING\"
    "
}

@test "retry-pass: failed then passed counts as one passed test at 100%" {
    run run_calculate "$FIXTURES_ROOT/retry-pass"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'TEST_TOTAL_COUNT=1'
    echo "$output" | grep -q 'TEST_PASSED_COUNT=1'
    echo "$output" | grep -q 'TEST_FAILED_COUNT=0'
    echo "$output" | grep -q 'TEST_PASS_RATE=100.00'
    echo "$output" | grep -q 'TEST_PASS_RATE_ROUNDED=100'
    echo "$output" | grep -q 'TEST_OVERALL_STATUS=PASSED'
    echo "$output" | grep -q '(1 retry)'
}

@test "no-retry: single passed file counts as one test" {
    run run_calculate "$FIXTURES_ROOT/no-retry"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'TEST_TOTAL_COUNT=1'
    echo "$output" | grep -q 'TEST_PASSED_COUNT=1'
    echo "$output" | grep -q 'TEST_PASS_RATE=100.00'
    echo "$output" | grep -Fq 'PASSED | stable test @smoke'
    echo "$output" | grep -vq '(1 retry)'
}

@test "two-tests: distinct historyId files count as two tests" {
    run run_calculate "$FIXTURES_ROOT/two-tests"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'TEST_TOTAL_COUNT=2'
    echo "$output" | grep -q 'TEST_PASSED_COUNT=1'
    echo "$output" | grep -q 'TEST_FAILED_COUNT=1'
    echo "$output" | grep -q 'TEST_PASS_RATE=50.00'
    echo "$output" | grep -q 'TEST_PASS_RATE_ROUNDED=50'
    echo "$output" | grep -q 'TEST_OVERALL_STATUS=FAILED'
}

@test "missing allure-results directory returns error" {
    run bash -c "source '$CALCULATE_SCRIPT' '/nonexistent/allure-results'"
    [ "$status" -eq 1 ]
    echo "$output" | grep -qi 'not found'
}

@test "empty allure-results directory returns error" {
    local empty_dir
    empty_dir="$(mktemp -d)"
    run bash -c "source '$CALCULATE_SCRIPT' '$empty_dir'"
    rm -rf "$empty_dir"
    [ "$status" -eq 1 ]
    echo "$output" | grep -qi 'No test results found'
}
