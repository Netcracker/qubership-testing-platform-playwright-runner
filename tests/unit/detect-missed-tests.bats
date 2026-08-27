#!/usr/bin/env bats
# Unit tests for OOM/missed Allure stub suite-tree parity in detect-missed-tests.sh

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
FIXTURES="$REPO_ROOT/tests/unit/fixtures/detect-missed-tests"
SCRIPT="$REPO_ROOT/detect-missed-tests.sh"

setup() {
  export TMP_DIR="$(mktemp -d)"
  mkdir -p "$TMP_DIR/allure-results"
  export TEST_PASSED_COUNT=1
  export TEST_FAILED_COUNT=0
  export TEST_SKIPPED_COUNT=0
  export TEST_BROKEN_COUNT=0
}

teardown() {
  rm -rf "$TMP_DIR"
}

_write_log() {
  local expected="$1"
  cat > "$TMP_DIR/test-execution.log" <<EOF
Running ${expected} tests using 1 worker
Killed
EOF
}

_write_existing_frontend_result() {
  # Basename fullName matching allure-playwright; list file uses e2e/foo.test.ts
  cat > "$TMP_DIR/allure-results/existing-result.json" <<'EOF'
{
  "uuid": "existing-uuid",
  "name": "already ran test",
  "fullName": "foo.test.ts:10:5",
  "status": "passed",
  "labels": [
    {"name": "parentSuite", "value": "Frontend"},
    {"name": "suite", "value": "foo.test.ts"},
    {"name": "subSuite", "value": "AT-RI-0067 — Power Objects @smoke"}
  ],
  "parameters": [
    {"name": "Project", "value": "Frontend"}
  ]
}
EOF
}

_run_detect() {
  # Script auto-invokes _detect_missed_tests on source
  bash -c "source '$SCRIPT'"
}

_stub_files() {
  # Exclude the seeded existing-result.json
  find "$TMP_DIR/allure-results" -maxdepth 1 -name '*-result.json' ! -name 'existing-result.json'
}

_first_stub() {
  _stub_files | head -1
}

@test "named stub lands under Frontend with suite-tree labels and Project parameter" {
  _write_log 3
  _write_existing_frontend_result
  cp "$FIXTURES/playwright-test-list.json" "$TMP_DIR/playwright-test-list.json"

  run _run_detect
  [ "$status" -eq 0 ]

  # 1 existing + 2 missed stubs (foo:20:7 and bar:5:3)
  local stub_count
  stub_count=$(_stub_files | wc -l)
  [ "$stub_count" -eq 2 ]

  local nested
  nested=$(jq -s '
    .[] | select(.fullName == "foo.test.ts:20:7")
  ' "$TMP_DIR"/allure-results/*-result.json)

  [ -n "$nested" ]
  [ "$(echo "$nested" | jq -r '.status')" = "broken" ]
  [ "$(echo "$nested" | jq -r '.name')" = "missed nested test" ]
  [ "$(echo "$nested" | jq -r '.fullName')" = "foo.test.ts:20:7" ]
  [ "$(echo "$nested" | jq -r '.labels[] | select(.name=="parentSuite") | .value')" = "Frontend" ]
  [ "$(echo "$nested" | jq -r '.labels[] | select(.name=="suite") | .value')" = "foo.test.ts" ]
  [ "$(echo "$nested" | jq -r '.labels[] | select(.name=="subSuite") | .value')" = "AT-RI-0067 — Power Objects @smoke" ]
  [ "$(echo "$nested" | jq -r '.labels[] | select(.name=="package") | .value')" = "foo.test.ts" ]
  [ "$(echo "$nested" | jq -r '.labels[] | select(.name=="titlePath") | .value')" = \
    " > Frontend > foo.test.ts > AT-RI-0067 — Power Objects @smoke" ]
  [ "$(echo "$nested" | jq -r '.parameters[] | select(.name=="Project") | .value')" = "Frontend" ]
  [ "$(echo "$nested" | jq -c '.titlePath')" = \
    '["foo.test.ts","AT-RI-0067 — Power Objects @smoke"]' ]
}

@test "placeholder inherits majority project from existing results" {
  _write_log 3
  _write_existing_frontend_result
  # No playwright-test-list.json → placeholders

  run _run_detect
  [ "$status" -eq 0 ]

  local stub_count
  stub_count=$(_stub_files | wc -l)
  [ "$stub_count" -eq 2 ]

  local stub
  stub=$(jq -s '[.[] | select(.fullName | startswith("missed-test-"))][0]' \
    "$TMP_DIR"/allure-results/*-result.json)

  [ "$(echo "$stub" | jq -r '.labels[] | select(.name=="parentSuite") | .value')" = "Frontend" ]
  [ "$(echo "$stub" | jq -r '.parameters[] | select(.name=="Project") | .value')" = "Frontend" ]
  # Reuse majority suite from existing tree — no separate "OOM / Aborted" branch
  [ "$(echo "$stub" | jq -r '.labels[] | select(.name=="suite") | .value')" = "foo.test.ts" ]
  # No subSuite when empty
  [ "$(echo "$stub" | jq '[.labels[] | select(.name=="subSuite")] | length')" -eq 0 ]
}

@test "basename match skips already-written test (path in list vs basename fullName)" {
  _write_log 3
  _write_existing_frontend_result
  cp "$FIXTURES/playwright-test-list.json" "$TMP_DIR/playwright-test-list.json"

  run _run_detect
  [ "$status" -eq 0 ]

  # Must not invent a second stub for foo.test.ts:10:5
  local dup
  dup=$(jq -s '[.[] | select(.fullName == "foo.test.ts:10:5")] | length' \
    "$TMP_DIR"/allure-results/*-result.json)
  [ "$dup" -eq 1 ]

  # Path form must not appear
  local path_form
  path_form=$(jq -s '[.[] | select(.fullName | startswith("e2e/"))] | length' \
    "$TMP_DIR"/allure-results/*-result.json)
  [ "$path_form" -eq 0 ]
}
