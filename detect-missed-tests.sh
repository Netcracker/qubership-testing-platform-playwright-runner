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
  local failed_count="${TEST_FAILED_COUNT:-0}"
  local user_skipped_count="${TEST_SKIPPED_COUNT:-0}"
  # Missed (OOM/aborted) tests are counted as broken, not skipped.
  local broken_count=$(( ${TEST_BROKEN_COUNT:-0} + missed ))
  # Skipped-by-user tests are excluded from the denominator; broken/missed tests
  # remain in it so they still penalise the pass rate.
  local effective_total=$(( expected_count - user_skipped_count ))

  pass_rate=$(awk -v p="$passed_count" -v t="$effective_total" \
    'BEGIN { if (t > 0) printf "%.2f", p * 100 / t; else print "0.00" }')
  pass_rate_rounded=$(awk -v p="$passed_count" -v t="$effective_total" \
    'BEGIN { if (t > 0) printf "%.0f", p * 100 / t; else print "0" }')
  failure_rate=$(awk -v f="$failed_count" -v b="$broken_count" -v t="$effective_total" \
    'BEGIN { if (t > 0) printf "%.2f", (f + b) * 100 / t; else print "0.00" }')

  export TEST_PASS_RATE="$pass_rate"
  export TEST_PASS_RATE_ROUNDED="$pass_rate_rounded"
  export TEST_TOTAL_COUNT="$expected_count"
  export TEST_PASSED_COUNT="$passed_count"
  export TEST_FAILED_COUNT="$failed_count"
  export TEST_SKIPPED_COUNT="$user_skipped_count"
  export TEST_BROKEN_COUNT="$broken_count"
  export TEST_OVERALL_STATUS="FAILED"

  echo "TEST_PASS_RATE=$TEST_PASS_RATE"
  echo "TEST_PASS_RATE_ROUNDED=$TEST_PASS_RATE_ROUNDED"
  echo "TEST_TOTAL_COUNT=$TEST_TOTAL_COUNT"
  echo "TEST_PASSED_COUNT=$TEST_PASSED_COUNT"
  echo "TEST_FAILED_COUNT=$TEST_FAILED_COUNT"
  echo "TEST_SKIPPED_COUNT=$TEST_SKIPPED_COUNT"
  echo "TEST_BROKEN_COUNT=$TEST_BROKEN_COUNT"
  echo "TEST_OVERALL_STATUS=$TEST_OVERALL_STATUS"
  echo "failure_rate=$failure_rate"

  # ── 4. Patch JSON_FILE in-place ─────────────────────────────────────────────
  if [ -n "${JSON_FILE:-}" ] && [ -f "$JSON_FILE" ] && command -v jq > /dev/null 2>&1; then
    local tmp_json
    tmp_json=$(mktemp)
  if jq \
    --arg   status        "FAILED" \
    --argjson expected     "$expected_count" \
    --argjson passRate     "$pass_rate" \
    --argjson passRateR    "$pass_rate_rounded" \
    --argjson passedCount  "$passed_count" \
    --argjson failedCount  "$failed_count" \
    --argjson skippedCount "$user_skipped_count" \
    --argjson brokenCount  "$broken_count" \
    --argjson failureRate   "$failure_rate" \
    '
      .test_results.overall_status   = $status        |
      .test_results.pass_rate        = $passRate       |
      .test_results.pass_rate_rounded= $passRateR      |
      .test_results.total_count      = $expected       |
      .test_results.passed_count     = $passedCount    |
      .test_results.failed_count     = $failedCount    |
      .test_results.failure_rate     = $failureRate    |
      .test_results.skipped_count    = $skippedCount   |
      .test_results.broken_count     = $brokenCount    |
      .test_results.expected_count   = $expected       |
      .environment_variables.TEST_OVERALL_STATUS    = $status                    |
      .environment_variables.TEST_PASS_RATE         = ($passRate | tostring)     |
      .environment_variables.TEST_PASS_RATE_ROUNDED = ($passRateR | tostring)    |
      .environment_variables.TEST_TOTAL_COUNT       = ($expected | tostring)     |
      .environment_variables.TEST_PASSED_COUNT      = ($passedCount | tostring)  |
      .environment_variables.TEST_FAILED_COUNT      = ($failedCount | tostring)  |
      .environment_variables.TEST_BROKEN_COUNT      = ($brokenCount | tostring)  |
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

  # ── 5. Write broken Allure stubs for every missed test ───────────────────────
  _write_missed_test_stubs "$results_dir" "$expected_count" "$actual_count" "$missed"
}

# ---------------------------------------------------------------------------
# _write_missed_test_stubs
#
# Writes N broken *-result.json files into allure-results/ — one per missed
# test — so the Allure report lists the missing tests explicitly.
#
# Real test names are resolved from $TMP_DIR/playwright-test-list.json (written
# by capture-test-list.sh).  When that file is absent or unusable, placeholder
# names "Missed test #N" are used instead.
#
# Args:
#   $1  results_dir     — path to allure-results/
#   $2  expected_count  — total tests Playwright intended to run
#   $3  actual_count    — number of *-result.json files found
#   $4  missed          — expected_count - actual_count
# ---------------------------------------------------------------------------
_write_missed_test_stubs() {
  local results_dir="$1"
  local expected_count="$2"
  local actual_count="$3"
  local missed="$4"
  local list_file="${TMP_DIR:-/tmp}/playwright-test-list.json"
  local ts
  ts=$(date +%s)
  local ts_ms="${ts}000"
  local status_msg="Test did not produce an Allure result file. Expected: ${expected_count}, actual: ${actual_count}, missed: ${missed}. Process was likely OOM-killed or aborted."

  # ── Try real-name resolution via playwright-test-list.json ──────────────────
  if command -v jq > /dev/null 2>&1 && [ -f "$list_file" ] && jq empty "$list_file" 2>/dev/null; then

    # Collect fullNames that already exist in allure-results
    local existing_full_names
    existing_full_names=$(jq -rs '[.[].fullName // empty] | sort | unique | .[]' \
      "$results_dir"/*-result.json 2>/dev/null || true)

    # Extract every spec entry from the list JSON.
    # Playwright --list --reporter=json structure:
    #   suites[]           ← project  (.title = "chromium")
    #     suites[]         ← file     (.file = "kill-test.spec.ts", .title = filename)
    #       specs[]        ← test/describe  (.title, .line, .column)
    #
    # fullName = file:line:column  (matches Allure's fullName format)
    # Each TSV line: fullName<TAB>testName<TAB>parentSuite<TAB>subSuite<TAB>suite
    local all_tests_tsv
    all_tests_tsv=$(jq -r '
      .suites[]? as $project |
      $project.suites[]? as $fileSuite |
      ($fileSuite.file // $fileSuite.title // "") as $file |
      $fileSuite.specs[]? |
      [
        ($file + ":" + (.line|tostring) + ":" + (.column|tostring)),
        (.title // "Unknown test"),
        ($project.title // "Unknown project"),
        ($fileSuite.title // $file)
      ] | @tsv
    ' "$list_file" 2>/dev/null || true)

    if [ -n "$all_tests_tsv" ]; then
      # Filter out tests that already have a result file, keep only missed ones
      local stub_index=0
      local written=0
      while IFS=$'\t' read -r full_name test_name parent_suite suite_name; do
        [ -z "$full_name" ] && continue

        # Skip if this test already produced a result
        if echo "$existing_full_names" | grep -qxF "$full_name" 2>/dev/null; then
          continue
        fi

        stub_index=$(( stub_index + 1 ))
        [ "$stub_index" -gt "$missed" ] && break

        local uuid
        uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || \
               od -x /dev/urandom | head -1 | awk '{print $2$3"-"$4"-"$5"-"$6"-"$7$8$9}')

        cat > "${results_dir}/${uuid}-result.json" <<EOF
{
  "uuid": "${uuid}",
  "name": "${test_name}",
  "fullName": "${full_name}",
  "status": "broken",
  "stage": "finished",
  "labels": [
    {"name": "language",    "value": "javascript"},
    {"name": "framework",   "value": "playwright"},
    {"name": "parentSuite", "value": "${parent_suite}"},
    {"name": "suite",       "value": "${suite_name}"}
  ],
  "statusDetails": {
    "message": "${status_msg}",
    "trace": ""
  },
  "start": ${ts_ms},
  "stop":  ${ts_ms},
  "steps": [],
  "attachments": [],
  "parameters": [],
  "links": []
}
EOF
        written=$(( written + 1 ))
        echo "✅ [detect-missed-tests] Wrote broken stub: ${full_name} → ${uuid}-result.json"
      done <<< "$all_tests_tsv"

      # If we resolved fewer stubs than missed (e.g. list was incomplete), fill with placeholders
      local remaining=$(( missed - written ))
      if [ "$remaining" -gt 0 ]; then
        echo "ℹ️  [detect-missed-tests] $remaining stub(s) could not be resolved by name — using placeholders."
        _write_placeholder_stubs "$results_dir" "$remaining" "$(( written + 1 ))" "$ts_ms" "$status_msg"
      fi

      echo "✅ [detect-missed-tests] Wrote $written named broken stub(s) into $results_dir"
      return 0
    fi
  fi

  # ── Fallback: placeholder stubs ──────────────────────────────────────────────
  echo "ℹ️  [detect-missed-tests] playwright-test-list.json unavailable — writing $missed placeholder stub(s)."
  _write_placeholder_stubs "$results_dir" "$missed" 1 "$ts_ms" "$status_msg"
}

# ---------------------------------------------------------------------------
# _write_placeholder_stubs
#
# Writes N placeholder broken stubs named "Missed test #start_index" …
#
# Args:
#   $1  results_dir   — path to allure-results/
#   $2  count         — number of stubs to write
#   $3  start_index   — first stub number (for label continuity when called after named stubs)
#   $4  ts_ms         — epoch-milliseconds timestamp
#   $5  status_msg    — statusDetails.message
# ---------------------------------------------------------------------------
_write_placeholder_stubs() {
  local results_dir="$1"
  local count="$2"
  local start_index="$3"
  local ts_ms="$4"
  local status_msg="$5"

  local i
  for (( i = 0; i < count; i++ )); do
    local idx=$(( start_index + i ))
    local uuid
    uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || \
           od -x /dev/urandom | head -1 | awk '{print $2$3"-"$4"-"$5"-"$6"-"$7$8$9}')

    cat > "${results_dir}/${uuid}-result.json" <<EOF
{
  "uuid": "${uuid}",
  "name": "Missed test #${idx}",
  "fullName": "missed-test-${idx}",
  "status": "broken",
  "stage": "finished",
  "labels": [
    {"name": "language",    "value": "javascript"},
    {"name": "framework",   "value": "playwright"},
    {"name": "parentSuite", "value": "Missed Tests"},
    {"name": "suite",       "value": "OOM / Aborted"}
  ],
  "statusDetails": {
    "message": "${status_msg}",
    "trace": ""
  },
  "start": ${ts_ms},
  "stop":  ${ts_ms},
  "steps": [],
  "attachments": [],
  "parameters": [],
  "links": []
}
EOF
    echo "✅ [detect-missed-tests] Wrote placeholder stub #${idx} → ${uuid}-result.json"
  done
}

_detect_missed_tests
