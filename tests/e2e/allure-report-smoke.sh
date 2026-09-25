#!/bin/bash
set -euo pipefail

TMP_DIR="$(mktemp -d)"
export TMP_DIR
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/allure-results"
cat > "$TMP_DIR/allure-results/smoke-result.json" <<'JSON'
{
  "uuid": "smoke-result",
  "historyId": "smoke-history",
  "name": "runner report smoke",
  "fullName": "runner report smoke",
  "status": "passed",
  "stage": "finished",
  "start": 1,
  "stop": 2,
  "labels": [{"name": "suite", "value": "Smoke"}]
}
JSON

# shellcheck disable=SC1091
source /scripts/allure-report.sh

generate_allure_report
test -s "$TMP_DIR/allure-report/index.html"
grep -q 'duration-trend' "$TMP_DIR/allure-report/index.html" ||
  grep -q 'duration-trend' "$TMP_DIR/allure-report/styles.css"
java -version
echo "Allure report image smoke test passed"
