#!/bin/bash
#
# capture-test-list.sh — sourced lazily by detect-missed-tests.sh when missed > 0,
# while TEST_PARAMS is still in the environment and node_modules are ready in $TMP_DIR.
#
# Runs `npx playwright test --list --reporter=json` with the same filter used
# by start_tests.sh, and saves the output to $TMP_DIR/playwright-test-list.json.
#
# detect-missed-tests.sh reads this file later to resolve real test names for
# any broken stubs it writes.  This script is always a no-op on failure — it
# never propagates errors to the caller.

_capture_test_list() {
  local tmp_dir="${TMP_DIR:-/tmp}"
  local project_dir="${PROJECT_DIR:-$tmp_dir}"
  local out_file="$tmp_dir/playwright-test-list.json"

  # ── Guard: need TEST_PARAMS and jq ──────────────────────────────────────────
  if [ -z "${TEST_PARAMS:-}" ]; then
    echo "ℹ️  [capture-test-list] TEST_PARAMS not set — skipping."
    return 0
  fi
  if ! command -v jq > /dev/null 2>&1; then
    echo "ℹ️  [capture-test-list] jq not available — skipping."
    return 0
  fi
  if ! command -v npx > /dev/null 2>&1; then
    echo "ℹ️  [capture-test-list] npx not available — skipping."
    return 0
  fi

  # ── Parse execution type and name from TEST_PARAMS ──────────────────────────
  local exec_type exec_name
  exec_type=$(echo "$TEST_PARAMS" | jq -r '.execution_list[0].type // empty' 2>/dev/null)
  exec_name=$(echo "$TEST_PARAMS" | jq -r '.execution_list[0].name // empty' 2>/dev/null)

  if [ -z "$exec_type" ]; then
    echo "ℹ️  [capture-test-list] Could not determine execution type from TEST_PARAMS — skipping."
    return 0
  fi

  # ── Build filter flags ───────────────────────────────────────────────────────
  local filter_flags=""
  if [ "$exec_type" = "scope" ]; then
    local tag_name="$exec_name"
    [[ "$tag_name" != @* ]] && tag_name="@${tag_name}"
    filter_flags="-g \"${tag_name}\""
  elif [ "$exec_type" = "test" ]; then
    # All items in execution_list are test file names
    local test_files
    test_files=$(echo "$TEST_PARAMS" | jq -r '.execution_list[].name' 2>/dev/null | \
      while IFS= read -r f; do printf '"%s" ' "$f"; done)
    filter_flags="$test_files"
  else
    echo "ℹ️  [capture-test-list] Unknown exec type '$exec_type' — skipping."
    return 0
  fi

  local shard_flags=""
  if [ -n "${PLAYWRIGHT_SHARD:-}" ]; then
    shard_flags="--shard=${PLAYWRIGHT_SHARD}"
  fi

  # ── Run --list in the cloned repo ───────────────────────────────────────────
  if [ ! -d "$project_dir" ]; then
    echo "ℹ️  [capture-test-list] PROJECT_DIR '$project_dir' does not exist — skipping."
    return 0
  fi

  echo "ℹ️  [capture-test-list] Capturing test list (type=$exec_type filter=$filter_flags) → $out_file"

  local list_output
  # eval is required to expand quoted filter_flags correctly.
  # Capture both stdout and stderr into list_output; --list exits non-zero even
  # on success when tests are filtered/skipped, so we cannot rely on exit code.
  list_output=$(cd "$project_dir" && eval npx playwright test --list --reporter=json "$filter_flags" "$shard_flags" 2>&1)

  if [ -z "$list_output" ]; then
    echo "⚠️  [capture-test-list] npx playwright test --list produced no output — skipping."
    return 0
  fi

  # The output may contain non-JSON lines before/after the JSON blob (Playwright
  # sometimes emits warnings or the config header to stdout).  Extract only the
  # JSON object that starts with '{'.
  local json_output
  json_output=$(echo "$list_output" | awk '/^\{/{found=1} found{print}')

  if [ -z "$json_output" ] || ! echo "$json_output" | jq empty 2>/dev/null; then
    echo "⚠️  [capture-test-list] --list output contains no valid JSON — skipping."
    echo "    Raw output (first 5 lines): $(echo "$list_output" | head -5)"
    return 0
  fi

  echo "$json_output" > "$out_file"
  local saved_count
  saved_count=$(echo "$json_output" | \
    jq '[.suites[]?.suites[]?.specs[]?] | length' 2>/dev/null || echo "?")
  echo "✅ [capture-test-list] Saved $saved_count spec entries to $out_file"

  if [ -n "${PLAYWRIGHT_SHARD:-}" ]; then
    local manifest_file="$tmp_dir/shard-manifest.json"
    local source_commit
    source_commit=$(cd "$project_dir" && git rev-parse HEAD 2>/dev/null || true)
    jq -n \
      --arg schemaVersion "1" \
      --arg shard "$PLAYWRIGHT_SHARD" \
      --arg sourceCommit "$source_commit" \
      --arg testParams "$TEST_PARAMS" \
      --slurpfile testList "$out_file" \
      '{
        schemaVersion: ($schemaVersion | tonumber),
        shard: $shard,
        sourceCommit: $sourceCommit,
        testParams: ($testParams | fromjson),
        expectedTests: [
          $testList[0] | .. | objects
          | select(has("title") and (has("file") or has("location")))
          | {name: .title, file: (.file // .location.file // "")}
        ],
        testList: $testList[0]
      }' > "$manifest_file"
    echo "✅ [capture-test-list] Saved shard manifest to $manifest_file"
  fi
}

_capture_test_list
