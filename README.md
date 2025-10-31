# Qubership Testing Platform Playwright Runner

## Deploy parameters

| Parameter                    | Type    | Mandatory | Default value | Description                                                           |
|------------------------------|---------|-----------|---------------|-----------------------------------------------------------------------|
| ENVIRONMENT_NAME             | string  | yes       | `"default"`   | Environment name (e.g., dev, test, prod)                              |
| ATP_TESTS_GIT_REPO_URL       | string  | yes       | `""`          | Git repository URL to read test sources. Git-URL-to-project-tests.git |
| ATP_TESTS_GIT_REPO_BRANCH    | string  | no        | `master`      | Git branch to checkout                                                |
| ATP_TESTS_GIT_TOKEN          | string  | yes       | `""`          | Access token for private Git repositories with tests                  |
| TEST_PARAMS                  | json    | no        | `{}`          | Additional test parameters to pass to test runner                     |
| ATP_ENVGENE_CONFIGURATION    | json    | no        | `{}`          | Additional test parameters to pass to test runner from EnvGene        |
| ATP_STORAGE_PROVIDER         | string  | no        | `"minio"`     | Type of S3 storage (e.g., minio, aws)                                 |
| ATP_STORAGE_BUCKET           | string  | yes       | `""`          | S3 bucket name for uploading results                                  |
| ATP_STORAGE_USERNAME         | string  | yes       | `""`          | Access key for S3 bucket                                              |
| ATP_STORAGE_PASSWORD         | string  | yes       | `""`          | Secret key for S3 bucket                                              |
| ATP_STORAGE_SERVER_URL       | string  | yes       | `""`          | API endpoint for accessing S3 storage                                 |
| ATP_STORAGE_SERVER_UI_URL    | string  | yes       | `""`          | Web UI endpoint for viewing files in the S3 bucket                    |
| ATP_REPORT_VIEW_UI_URL       | string  | yes       | `""`          | URL for viewing generated test reports                                |
| CURRENT_DATE                 | string  | no        | `""`          | Date to use in report naming (format: YYYY-MM-DD)                     |
| CURRENT_TIME                 | string  | no        | `""`          | Time to use in report naming (format: HH:MM:SS)                       |
| ATP_RUNNER_JOB_TTL           | integer | no        | `3600`        | Time-to-live for the test job in seconds                              |
| ATP_RUNNER_JOB_EXIT_STRATEGY | integer | no        | `0`           | Delay in seconds before job termination (for debugging)               |
| ENABLE_JIRA_INTEGRATION      | boolean | no        | `false `      | Enable Jira integration for tests                                     |
