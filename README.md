# Qubership Testing Platform Playwright Runner

- [Deploy parameters](#deploy-parameters)
- [Hardware / Resource Requirements (HWE)](#hardware--resource-requirements-hwe)
- [Playwright Native Report (Trace Configuration)](#playwright-native-report-trace-configuration)

## Deploy parameters

| Parameter                           | Type    | Mandatory | Default value                             | Description                                                                                                                                                                                                                                                  |
|-------------------------------------|---------|-----------|-------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ENVIRONMENT_NAME                    | string  | **yes**   | `"default"`                               | Environment name (e.g., dev, test, prod)                                                                                                                                                                                                                     |
| ENV_CONFIGURATION_TEMPLATE_FILENAME | string  | no        | `environment-configuration-template.json` | Environment configuration template filename used during runtime configuration rendering.                                                                                                                                                                     |
| ATP_TESTS_GIT_REPO_URL              | string  | **yes**   | `""`                                      | Git repository URL for cloning test sources. Git-URL-to-project-tests.git                                                                                                                                                                                    |
| ATP_STORAGE_BUCKET                  | string  | **yes**   | `""`                                      | S3 bucket name for uploading results.                                                                                                                                                                                                                        |
| ATP_STORAGE_USERNAME                | string  | **yes**   | `""`                                      | Access key for S3 bucket.                                                                                                                                                                                                                                    |
| ATP_STORAGE_PASSWORD                | string  | **yes**   | `""`                                      | Secret key for S3 bucket.                                                                                                                                                                                                                                    |
| ATP_STORAGE_SERVER_URL              | string  | **yes**   | `""`                                      | API endpoint for accessing S3 storage.                                                                                                                                                                                                                       |
| ATP_STORAGE_SERVER_UI_URL           | string  | **yes**   | `""`                                      | Web UI endpoint for viewing files in the S3 bucket.                                                                                                                                                                                                          |
| ATP_REPORT_VIEW_UI_URL              | string  | **yes**   | `""`                                      | URL for viewing generated test reports.                                                                                                                                                                                                                      |
| ATP_TESTS_GIT_TOKEN                 | string  | **yes**   | `""`                                      | Access token for private Git repositories with tests.                                                                                                                                                                                                        |
| TEST_PARAMS                         | JSON    | **yes**   | `{}`                                      | Specify what test or scope should be run, for example: `'{"execution_list":[{"type": "scope","name": "regression"}]}'`                                                                                                                                       |
| ATP_ENVGENE_CONFIGURATION           | JSON    | no        | `{}`                                      | Additional test parameters (Systems) to pass to test runner from EnvGene.                                                                                                                                                                                    |
| ATP_TESTS_GIT_REPO_BRANCH           | string  | no        | `main`                                    | Git branch to checkout.                                                                                                                                                                                                                                      |
| ATP_STORAGE_PROVIDER                | string  | no        | `"minio"`                                 | Type of S3 storage (e.g., minio, aws).                                                                                                                                                                                                                       |
| CURRENT_DATE                        | string  | no        | `""`                                      | Date to use in report naming (format: YYYY-MM-DD).                                                                                                                                                                                                           |
| CURRENT_TIME                        | string  | no        | `""`                                      | Time to use in report naming (format: HH:MM:SS).                                                                                                                                                                                                             |
| ATP_RUNNER_JOB_TTL                  | integer | no        | `43200`                                   | Time-to-live for the test job in seconds.                                                                                                                                                                                                                    |
| ATP_RUNNER_JOB_EXIT_STRATEGY        | integer | no        | `0`                                       | Delay in seconds before job termination (for debugging).                                                                                                                                                                                                     |
| ENABLE_JIRA_INTEGRATION             | boolean | no        | `false`                                   | Enable Jira integration for tests.                                                                                                                                                                                                                           |
| EXPECTED_PASS_RATE                  | string  | no        | `80`                                      | If Pass Rate >= EXPECTED_PASS_RATE < 100 then result status is PARTIAL                                                                                                                                                                                       |
| DEBUG_MODE                          | boolean | no        | `false`                                   | Enable additional debug behavior and logs in runner scripts.                                                                                                                                                                                                 |
| PLAYWRIGHT_TRACE_MODE               | string  | no        | `retain-on-failure`                       | Defines when Playwright should record execution traces (trace.zip) for debugging. Supported values: `on`, `off`, `retain-on-failure`, `on-first-retry`. See [Playwright Native Report (Trace Configuration)](#playwright-native-report-trace-configuration). |
| ATP_MONITORING_ENABLED              | boolean | no        | `false`                                   | Enable creation monitoring objects for runners.                                                                                                                                                                                                              |
| ATP_METRICS_ENABLED                 | boolean | no        | `false`                                   | To enable metrics push; any other value skips (exit 0).                                                                                                                                                                                                      |
| ATP_METRICS_URL                     | string  | no        | ``                                        | Base URL for VictoriaMetrics / vmagent.                                                                                                                                                                                                                      |
| ATP_METRICS_TYPE                    | string  | no        | `pushgateway`                             | Possible values  `pushgateway` (default) or `vm-native` (POST to `/api/v1/import/prometheus` with `extra_label` query params).                                                                                                                               |
| ATP_METRICS_AUTH_TYPE               | string  | no        | `none`                                    | Possible values `none` (default), `basic`, or `bearer`.                                                                                                                                                                                                      |
| ATP_METRICS_USER                    | string  | no        | ``                                        | Login for metrics service                                                                                                                                                                                                                                    |
| ATP_METRICS_PASS                    | string  | no        | ``                                        | HTTP Basic credentials when `ATP_METRICS_AUTH_TYPE=basic`.                                                                                                                                                                                                   |
| ATP_METRICS_TOKEN                   | string  | no        | ``                                        | Bearer token when `ATP_METRICS_AUTH_TYPE=bearer`.                                                                                                                                                                                                            |
| EXTRA_VARS                          | string  | no        | ``                                        | Extra Variables propagation from job. Example:`var1=value1,var2=value2,` or EXTRA_VARS=`var1=value1; var2=value2;.                                                                                                                                           |
| POD_SECURITY_CONTEXT                | object  | no        | `{ runAsUser: 1007, fsGroup: 1007 }`      | UID/GID pin merged with chart defaults (`runAsNonRoot`, `seccompProfile`). `runAsUser`/`runAsGroup`/`fsGroup` are omitted when Helm sees `security.openshift.io/v1` (OpenShift `restricted-v2`). Always applied to the runner Job. |
| CONTAINER_SECURITY_CONTEXT          | object  | no        | `{}`                                      | Optional overrides merged with chart defaults (`allowPrivilegeEscalation: false`, drop `ALL`). Always applied to the runner Job. |
| TRIGGER_AUTHOR                      | string  | no        | `""`                                      | Optional technical parameter. Used to display the test run author in the report.                                                                                                                                                                             |

The Job always gets a pod and container `securityContext` (`runAsNonRoot`, `RuntimeDefault` seccomp, drop `ALL` capabilities). 
On vanilla Kubernetes, `POD_SECURITY_CONTEXT` pins UID/GID **1007**. 
On OpenShift Helm detects `security.openshift.io/v1` and omits `runAsUser`/`runAsGroup`/`fsGroup` so `restricted-v2` can assign the project UID range. Offline `helm template` without `--api-versions security.openshift.io/v1` looks like Kubernetes and keeps the UID pin.

## EXTRA_VARS additional variables

The variables below can be only passed via EXTRA_VARS deployment variable

| Parameter                           | Type    | Mandatory | Default value | Description                                                              |
|-------------------------------------|---------|-----------|---------------|--------------------------------------------------------------------------|
| ATP_TESTS_IGNORE_STRUCTURE          | string  | no        | `""`          | When `true`, skip the error if no standard repository markers (`app`/`tests`/`collections`/`postman_collection`) are found. |

Example when the repository has a non-standard layout:

```bash
EXTRA_VARS=ATP_TESTS_IGNORE_STRUCTURE=true
```

> **How is the root test project directory selected?**

When the runner clones the test repository, it determines the project root from a hardcoded ordered allowlist in `scripts/git-clone.sh` (`PROJECT_ROOT_CANDIDATES`, currently `.` then `TestGeneration`). Nested relative paths may be added to that list later.

For each candidate, in order:

1. Skip if the directory does not exist under the clone.
2. Skip if it has no standard repository markers (`app/`, `tests/`, `collections/`, or `*postman_collection*` files).
3. First candidate that exists **and** has markers becomes `PROJECT_DIR`.

If no candidate matches, the clone root is used. Structure validation then runs on `PROJECT_DIR`:

- If markers are missing and `ATP_TESTS_IGNORE_STRUCTURE=true`, validation is skipped (warning).
- Otherwise missing markers cause the job to fail.

Malformed allowlist entries (absolute paths or paths containing `..`) are treated as a configuration bug and hard-fail.

**Summary Table:**

| Priority | Condition                                                         | Outcome                       |
|----------|-------------------------------------------------------------------|-------------------------------|
| 1        | `.` (clone root) has repository markers                                 | Use repository root                 |
| 2        | `TestGeneration/` exists and has repository markers                     | Use `TestGeneration/`         |
| 3        | None matched; `ATP_TESTS_IGNORE_STRUCTURE=true`                   | Use repository root (with warning)  |
| 4        | None matched; no ignore flag                                      | Error, job fails              |

See `scripts/git-clone.sh` for implementation details.


## Hardware / Resource Requirements (HWE)

Supported 2 profiles: `dev`, `prod`.

| Parameter      | Dev    | Prod   |
|----------------|--------|--------|
| MEMORY_REQUEST | 1000Mi | 2000Mi |
| MEMORY_LIMIT   | 2000Mi | 3000Mi |
| CPU_REQUEST    | 100m   | 100m   |
| CPU_LIMIT      | 500m   | 1000m  |

## Playwright Native Report (Trace Configuration)

The Playwright test runner supports configurable tracing through the environment variable `PLAYWRIGHT_TRACE_MODE`.
It defines when Playwright should record execution traces (`trace.zip`) for debugging.

### Possible Values

| Value               | Description                                                                  |
|---------------------|------------------------------------------------------------------------------|
| `on`                | Record traces for **all tests** (useful for local debugging).                |
| `off`               | **Disable tracing** entirely (fastest test execution).                       |
| `retain-on-failure` | Record traces **only for failed tests** — *recommended for CI environments*. |
| `on-first-retry`    | Record traces **only when a test is retried** after failure.                 |

### Configuration in playwright.config.js

To make the environment variable effective, ensure your test configuration uses it:

```bazaar
// playwright.config.js
import { defineConfig } from '@playwright/test';

export default defineConfig({
  use: {
    trace: process.env.PLAYWRIGHT_TRACE_MODE || 'retain-on-failure',
  },
});
```

### Checking Playwright Trace

To debug a test using Playwright trace:

1. Go to your S3 bucket → open the Report folder → go to your run → `attachments` folder → select test.

2. Download the file `trace.zip`.

3. Open the trace locally: `npx playwright show-trace trace.zip` or `playwright show-trace trace.zip`.

4. Inspect the test execution. The trace viewer will open in your browser, allowing you to: replay test steps, view
   console logs & network requests, inspect DOM snapshots at each action.

## Metrics (VictoriaMetrics)

### Summary

Set `ATP_METRICS_ENABLED=true` to enable metrics push; other parameters from the table are injected into the Job only in
this case. When disabled, only `ATP_METRICS_ENABLED` is set and push is skipped (exit 0). Exit code `1` if metrics are
enabled but no target is configured or every push fails.

| Parameter             | Type    | Default value | Description                                                                                                              |
|-----------------------|---------|---------------|--------------------------------------------------------------------------------------------------------------------------|
| ATP_METRICS_ENABLED   | boolean | `false`       | Enables metrics push to VictoriaMetrics / vmagent. When `false`, metrics scripts skip push (exit 0).                     |
| ATP_METRICS_URL       | string  | `""`          | Base URL for VictoriaMetrics / vmagent.                                                                                  |
| ATP_METRICS_TYPE      | string  | `pushgateway` | Push mode: `pushgateway` (default) or `vm-native` (POST to `/api/v1/import/prometheus` with `extra_label` query params). |
| ATP_METRICS_AUTH_TYPE | string  | `none`        | Authentication type: `none` (default), `basic`, or `bearer`.                                                             |
| ATP_METRICS_USER      | string  | `""`          | Login for metrics service when `ATP_METRICS_AUTH_TYPE=basic`.                                                            |
| ATP_METRICS_PASS      | string  | `""`          | Password for metrics service when `ATP_METRICS_AUTH_TYPE=basic`.                                                         |
| ATP_METRICS_TOKEN     | string  | `""`          | Bearer token when `ATP_METRICS_AUTH_TYPE=bearer`.                                                                        |

**URL shapes**

- **pushgateway** (Prometheus or VM): `{BASE}/metrics/job/atp_playwright_runner/instance/{ENV}/{DATE}/{TIME}`
- **vm-native**: `{BASE}/api/v1/import/prometheus?extra_label=...` (run identity via `extra_label` for `job`,
  `instance`, `run_date`, `run_time`)

---

### Proposed Metrics

#### `atp_test_case_result` (gauge, per test case)

Binary result per individual test case — ideal for single-test failure alerts.

```text
atp_test_case_result{test_name="Login smoke test", environment="prod", suite="Auth", status="failed"} 0
atp_test_case_result{test_name="Create order",     environment="prod", suite="Orders", status="passed"} 1  
```

* Value: `1` = passed, `0` = failed/skipped
* Labels: `test_name`, `environment`, `suite` (Allure suite label, if present), `status` (passed/failed/skipped — lets
  you distinguish skipped from failed without extra metric)
* Alert example: `atp_test_case_result{environment="prod"} == 0`

#### `atp_test_suite_pass_rate` (gauge, per run)

Aggregated pass rate for the whole execution scope — for threshold-based alerts.

```text
atp_test_suite_pass_rate{environment="prod", overall_status="PARTIAL"} 87.50  
```

* Value: `0.0 – 100.0`
* Labels: `environment`, `overall_status` (PASSED / PARTIAL / FAILED)
* Alert example: `atp_test_suite_pass_rate{environment="prod"} < 80`

#### `atp_test_suite_total` / `_passed` / `_failed` / `_skipped` (gauge)

Count metrics per run — useful for dashboards and trend panels.

```text
atp_test_suite_total{environment="prod"}   24
atp_test_suite_passed{environment="prod"}  21
atp_test_suite_failed{environment="prod"}   2
atp_test_suite_skipped{environment="prod"}  1  
```

#### `atp_test_case_duration_seconds` (gauge, optional)

Per-test execution time from Allure `start`/`stop` timestamps — for performance regression alerts.

```text
atp_test_case_duration_seconds{test_name="Login smoke test", environment="prod", suite="Auth"} 3.412  
```
