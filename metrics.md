## Environment variables (metrics push)

| Variable | Description |
|----------|-------------|
| `ATP_METRICS_ENABLED` | `true` to run push; any other value skips (exit 0). |
| `ATP_METRICS_URL` | Base URL for VictoriaMetrics / vmagent. |
| `ATP_METRICS_TYPE` | `pushgateway` (default) or `vm-native` (POST to `/api/v1/import/prometheus` with `extra_label` query params). |
| `ATP_METRICS_AUTH_TYPE` | `none` (default), `basic`, or `bearer`. |
| `ATP_METRICS_USER` / `ATP_METRICS_PASS` | HTTP Basic credentials when `ATP_METRICS_AUTH_TYPE=basic`. |
| `ATP_METRICS_TOKEN` | Bearer token when `ATP_METRICS_AUTH_TYPE=bearer`. |

When `ATP_METRICS_ENABLED=true`, `ATP_METRICS_URL` must be set. The script pushes the same payload to each configured target; it returns `1` if no target is configured or if every configured push fails.

**URL shapes**

- **pushgateway** (Prometheus or VM): `{BASE}/metrics/job/atp_playwright_runner/instance/{ENV}/{DATE}/{TIME}`
- **vm-native**: `{BASE}/api/v1/import/prometheus?extra_label=...` (run identity via `extra_label` for `job`, `instance`, `run_date`, `run_time`)

---

## Proposed Metrics
### `atp_test_case_result` (gauge, per test case)
Binary result per individual test case — ideal for single-test failure alerts.

```
atp_test_case_result{test_name="Login smoke test", environment="prod", suite="Auth", status="failed"} 0
atp_test_case_result{test_name="Create order",     environment="prod", suite="Orders", status="passed"} 1  
```
* Value: `1` = passed, `0` = failed/skipped
* Labels: `test_name`, `environment`, `suite` (Allure suite label, if present), `status` (passed/failed/skipped — lets you distinguish skipped from failed without extra metric)
* Alert example: `atp_test_case_result{environment="prod"} == 0`

### `atp_test_suite_pass_rate` (gauge, per run)
Aggregated pass rate for the whole execution scope — for threshold-based alerts.

```
atp_test_suite_pass_rate{environment="prod", overall_status="PARTIAL"} 87.50  
```
* Value: `0.0 – 100.0`
* Labels: `environment`, `overall_status` (PASSED / PARTIAL / FAILED)
* Alert example: `atp_test_suite_pass_rate{environment="prod"} < 80`

### `atp_test_suite_total` / `_passed` / `_failed` / `_skipped` (gauge)
Count metrics per run — useful for dashboards and trend panels.

```
atp_test_suite_total{environment="prod"}   24
atp_test_suite_passed{environment="prod"}  21
atp_test_suite_failed{environment="prod"}   2
atp_test_suite_skipped{environment="prod"}  1  
```
### `atp_test_case_duration_seconds` (gauge, optional)
Per-test execution time from Allure `start`/`stop` timestamps — for performance regression alerts.

```
atp_test_case_duration_seconds{test_name="Login smoke test", environment="prod", suite="Auth"} 3.412  
```