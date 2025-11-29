# Qubership Testing Platform Playwright Runner

## Deploy parameters

| Parameter                    | Type     | Mandatory | Default value       | Description                                                                                                                                                                                                           |
|------------------------------|----------|-----------|---------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ENVIRONMENT_NAME             | string   | yes       | `"default"`         | Environment name (e.g., dev, test, prod)                                                                                                                                                                              |
| ATP_TESTS_GIT_REPO_URL       | string   | yes       | `""`                | it repository URL to read test sources. Git-URL-to-project-tests.git                                                                                                                                                  |
| ATP_TESTS_GIT_REPO_BRANCH    | string   | no        | `main`              | Git branch to checkout.                                                                                                                                                                                               |
| ATP_TESTS_GIT_TOKEN          | string   | yes       | `""`                | Access token for private Git repositories with tests.                                                                                                                                                                 |
| TEST_PARAMS                  | JSON     | no        | `{}`                | Additional test parameters to pass to test runner                                                                                                                                                                     |
| ATP_ENVGENE_CONFIGURATION    | JSON     | no        | `{}`                | Additional test parameters to pass to test runner from EnvGene.                                                                                                                                                       |
| ATP_STORAGE_PROVIDER         | string   | no        | `"minio"`           | Type of S3 storage (e.g., minio, aws).                                                                                                                                                                                |
| ATP_STORAGE_BUCKET           | string   | yes       | `""`                | S3 bucket name for uploading results.                                                                                                                                                                                 |
| ATP_STORAGE_USERNAME         | string   | yes       | `""`                | Access key for S3 bucket.                                                                                                                                                                                             |
| ATP_STORAGE_PASSWORD         | string   | yes       | `""`                | Secret key for S3 bucket.                                                                                                                                                                                             |
| ATP_STORAGE_SERVER_URL       | string   | yes       | `""`                | API endpoint for accessing S3 storage.                                                                                                                                                                                |
| ATP_STORAGE_SERVER_UI_URL    | string   | no        | `""`                | Web UI endpoint for viewing files in the S3 bucket.                                                                                                                                                                   |
| ATP_REPORT_VIEW_UI_URL       | string   | yes       | `""`                | URL for viewing generated test reports.                                                                                                                                                                               |
| CURRENT_DATE                 | string   | no        | `""`                | Date to use in report naming (format: YYYY-MM-DD).                                                                                                                                                                    |
| CURRENT_TIME                 | string   | no        | `""`                | Time to use in report naming (format: HH:MM:SS).                                                                                                                                                                      |
| ATP_RUNNER_JOB_TTL           | integer  | no        | `3600`              | Time-to-live for the test job in seconds.                                                                                                                                                                             |
| ATP_RUNNER_JOB_EXIT_STRATEGY | integer  | no        | `0`                 | Delay in seconds before job termination (for debugging).                                                                                                                                                              |
| ENABLE_JIRA_INTEGRATION      | boolean  | no        | `false`             | Enable Jira integration for tests.                                                                                                                                                                                    |
| PLAYWRIGHT_TRACE_MODE        | string   | no        | `retain-on-failure` | Defines when Playwright should record execution traces (trace.zip) for debugging. Supported values: `on`, `off`, `retain-on-failure`, `on-first-retry`. See **Playwright Native Report (Trace Configuration)** below. |
| MONITORING_ENABLED           | boolean  | no        | `true`              | Enable creation monitoring objects for runners.                                                                                                                                                                       |
| SECURITY_CONTEXT_ENABLED     | boolean  | no        | `false`             | Flag to enable or disable the security context for the Playwright Runner service .                                                                                                                                    |

## Hardware / Resource Requirements (HWE)

2 profiles - `dev` and `prod` - are supported.

| Parameter        | Dev    | Prod   |
|------------------|--------|--------|
| MEMORY_REQUEST   | 1000Mi | 2000Mi |
| MEMORY_LIMIT     | 2000Mi | 3000Mi |
| CPU_REQUEST      | 100m   | 100m   |
| CPU_LIMIT        | 500m   | 1000m  |


## Playwright Native Report (Trace Configuration)

The Playwright test runner supports configurable tracing through the environment variable `PLAYWRIGHT_TRACE_MODE`.
It defines when Playwright should record execution traces (`trace.zip`) for debugging.

### Possible Values

| Value               | Description                                                                  |
| ------------------- | ---------------------------------------------------------------------------- |
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

4. Inspect the test execution. The trace viewer will open in your browser, allowing you to: replay test steps, view console logs & network requests, inspect DOM snapshots at each action.
