#!/bin/bash
#
# detect-missed-tests.sh — sourced by finalize_once() in error-handler.sh after
# generate_email_notification_json has already written $JSON_FILE.
#
# Detects OOM-killed (or otherwise missing) tests by comparing the expected
# count from Playwright's "Running N tests using M workers" log line against
# the number of *-result.json files actually written to allure-results/.
#
# When missed > 0 it:
#   1. Exports TEST_OVERALL_STATUS=FAILED
#   2. Exports TEST_MISSED_COUNT and TEST_EXPECTED_COUNT
#   3. Patches $JSON_FILE in-place via jq to reflect the correct status and
#      adds missed_count / expected_count fields for downstream consumers.
#
# Safe no-op when:
#   - $TMP_DIR/test-execution.log is absent (non-tee runner, legacy path)
#   - The log contains no "Running N tests" line (Bruno runner, etc.)
#   - actual >= expected (all tests produced result files)

_detect_missed_tests() {
  local log_file="${TMP_DIR:-/tmp}/test-execution.log"
  local results_dir="${TMP_DIR:-/tmp}/allure-results"

  # ── 1. Read expected count from tee log ─────────────────────────────────────
  if [ ! -f "$log_file" ]; then
    echo "ℹ️  [detect-missed-tests] Log file not found at $log_file — skipping."
    return 0
  fi

  # Playwright emits: "Running 109 tests using 4 workers"
  local expected_count
  expected_count=$(grep -oP 'Running \K[0-9]+(?= tests? using)' "$log_file" | tail -1)

  if [ -z "$expected_count" ]; then
    echo "ℹ️  [detect-missed-tests] No 'Running N tests' line in log — skipping."
    return 0
  fi

  # ── 2. Count actual result files ────────────────────────────────────────────
  local actual_count=0
  if compgen -G "${results_dir}/*-result.json" > /dev/null 2>&1; then
    actual_count=$(find "$results_dir" -maxdepth 1 -name '*-result.json' | wc -l)
  fi

  local missed=$(( expected_count - actual_count ))

  echo "ℹ️  [detect-missed-tests] expected=$expected_count  actual=$actual_count  missed=$missed"

  if [ "$missed" -le 0 ]; then
    echo "✅ [detect-missed-tests] All expected tests produced result files."
    return 0
  fi

  # ── 3. Force FAILED and export counts ───────────────────────────────────────
  echo "⚠️  [detect-missed-tests] $missed test(s) did not produce result files — forcing FAILED."
  local passed_count="${TEST_PASSED_COUNT:-0}"
  local prev_failed="${TEST_FAILED_COUNT:-0}"
  local failed_count=$(( missed + prev_failed ))

  pass_rate=$(awk -v p="$passed_count" -v t="$expected_count" \
    'BEGIN { if (t > 0) printf "%.2f", p * 100 / t; else print "0.00" }')
  pass_rate_rounded=$(awk -v p="$passed_count" -v t="$expected_count" \
    'BEGIN { if (t > 0) printf "%.0f", p * 100 / t; else print "0" }')
  failure_rate=$(awk -v f="$failed_count" -v t="$expected_count" \
    'BEGIN { if (t > 0) printf "%.2f", f * 100 / t; else print "0.00" }')

  export TEST_PASS_RATE="$pass_rate"
  export TEST_PASS_RATE_ROUNDED="$pass_rate_rounded"
  export TEST_TOTAL_COUNT="$expected_count"
  export TEST_PASSED_COUNT="$passed_count"
  export TEST_FAILED_COUNT="$failed_count"
  export TEST_OVERALL_STATUS="FAILED"

  echo "TEST_PASS_RATE=$TEST_PASS_RATE"
  echo "TEST_PASS_RATE_ROUNDED=$TEST_PASS_RATE_ROUNDED"
  echo "TEST_TOTAL_COUNT=$TEST_TOTAL_COUNT"
  echo "TEST_PASSED_COUNT=$TEST_PASSED_COUNT"
  echo "TEST_FAILED_COUNT=$TEST_FAILED_COUNT"
  echo "TEST_SKIPPED_COUNT=${TEST_SKIPPED_COUNT:-0}"
  echo "TEST_OVERALL_STATUS=$TEST_OVERALL_STATUS"
  echo "failure_rate=$failure_rate"

  # ── 4. Patch JSON_FILE in-place ─────────────────────────────────────────────
  if [ -n "${JSON_FILE:-}" ] && [ -f "$JSON_FILE" ] && command -v jq > /dev/null 2>&1; then
    local tmp_json
    tmp_json=$(mktemp)
  if jq \
    --arg   status        "FAILED" \
    --argjson missed       "$missed" \
    --argjson expected     "$expected_count" \
    --argjson passRate     "$pass_rate" \
    --argjson passRateR    "$pass_rate_rounded" \
    --argjson passedCount  "$passed_count" \
    --argjson failedCount  "$failed_count" \
    --argjson failureRate   "$failure_rate" \
    '
      .test_results.overall_status   = $status        |
      .test_results.pass_rate        = $passRate       |
      .test_results.pass_rate_rounded= $passRateR      |
      .test_results.total_count      = $expected       |
      .test_results.passed_count     = $passedCount    |
      .test_results.failed_count     = $failedCount    |
      .test_results.failure_rate     = $failureRate    |
      .test_results.missed_count     = $missed         |
      .test_results.expected_count   = $expected       |
      .environment_variables.TEST_OVERALL_STATUS    = $status                    |
      .environment_variables.TEST_PASS_RATE         = ($passRate | tostring)     |
      .environment_variables.TEST_PASS_RATE_ROUNDED = ($passRateR | tostring)    |
      .environment_variables.TEST_TOTAL_COUNT       = ($expected | tostring)     |
      .environment_variables.TEST_PASSED_COUNT      = ($passedCount | tostring)  |
      .environment_variables.TEST_FAILED_COUNT      = ($failedCount | tostring)  |
      .environment_variables.TEST_FAILURE_RATE      = ($failureRate | tostring)
    ' \
    "$JSON_FILE" > "$tmp_json" 2>/dev/null; then
      mv "$tmp_json" "$JSON_FILE"
      echo "✅ [detect-missed-tests] Patched $JSON_FILE: overall_status=FAILED, missed_count=$missed, expected_count=$expected_count"
    else
      rm -f "$tmp_json"
      echo "⚠️  [detect-missed-tests] jq patch failed — JSON_FILE left unchanged."
    fi
  else
    echo "ℹ️  [detect-missed-tests] JSON_FILE not set or jq unavailable — skipping JSON patch."
  fi
}

_detect_missed_tests
