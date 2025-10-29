# JSON Test Results Generator

This set of scripts is designed to analyze test results from the
`allure-results` folder and generate JSON files with test results in a
predefined format.

## Files

### Main Scripts

1.  **`calculate-email-notification-variables.sh`** -- Main script for
    calculating test pass rate (shared with the text version)
2.  **`generate-email-notification-json.sh`** -- Script for generating a
    JSON file with test results

## Requirements

-   Git Bash (for Windows) or Linux/macOS with bash
-   `jq` (for parsing JSON)
-   `awk` (for calculations and placeholder replacements)

## Usage

### 1. Generating JSON Results

``` bash
# Using Git Bash in Windows
& "C:\Program Files\Git\bin\bash.exe" email-notification/generate-email-notification-json.sh

# On Linux/macOS
./email-notification/generate-email-notification-json.sh
```

### 2. Combined Usage

``` bash
# First, calculate the pass rate
& "C:\Program Files\Git\bin\bash.exe" email-notification/calculate-email-notification-variables.sh

# Then generate the JSON
& "C:\Program Files\Git\bin\bash.exe" email-notification/generate-email-notification-json.sh
```

## Exported Variables

After running `generate-email-notification-json.sh`, the following
environment variables are available:

-   `GENERATED_JSON` -- Contents of the generated JSON file
-   `JSON_FILE` -- Path to the JSON results file

## Environment Variables

The script uses the following environment variables to generate the
JSON:

-   `TEST_OVERALL_STATUS` -- Overall status
-   `TEST_PASS_RATE` -- Pass rate percentage (number)
-   `TEST_PASS_RATE_ROUNDED` -- Rounded pass rate (number)
-   `TEST_TOTAL_COUNT` -- Total number of tests
-   `TEST_PASSED_COUNT` -- Number of passed tests
-   `TEST_FAILED_COUNT` -- Number of failed tests
-   `TEST_SKIPPED_COUNT` -- Number of skipped tests
-   `TEST_FAILURE_RATE` -- Failure rate percentage
-   `TEST_COVERAGE` -- Test coverage
-   `EXECUTION_DATE` -- Execution date
-   `ENV_NAME` -- Environment name
-   `REPORT_VIEW_HOST_URL` -- Host for viewing reports
-   `ALLURE_REPORT_URL` -- Path to the reports folder
-   `TIMESTAMP` -- Timestamp
-   `TEST_DETAILS_STRING` -- String containing all test details
    (converted into a JSON array)

## Generated JSON Structure

``` json
{
  "test_results": {
    "overall_status": "PARTIAL",
    "pass_rate": 85.50,
    "pass_rate_rounded": 86,
    "total_count": 20,
    "passed_count": 17,
    "failed_count": 2,
    "skipped_count": 1,
    "failure_rate": 10.00,
    "coverage": 100.00
  },
  "execution_info": {
    "execution_date": "2024-01-15 14:30:25",
    "timestamp": "2024-01-15 14:30:25 UTC",
    "env_name": "staging",
    "report_view_host_url": "https://reports.example.com",
    "allure_report_url": "https://reports.example.com/Report/staging/2024-01-15/14-30-25/allure-report/index.html"
  },
  "test_details": [
    {
      "status": "PASSED",
      "test_name": "User Login Test",
      "emoji": "✅"
    }
  ],
  "environment_variables": { ... },
  "environment_variables_description": { ... },
  "status_logic": { ... }
}
```

## Integration with Other Scripts

The scripts can be integrated into other bash scripts:

### Option 1: Using a Function (Recommended)

``` bash
#!/bin/bash

# Load the script with the function
source ./email-notification/generate-email-notification-json.sh

# Call the function
json_content=$(generate_email_notification_json)

# Use the result
echo "$json_content"

# Or use exported variables
echo "JSON file: $JSON_FILE"
echo "Contents: $GENERATED_JSON"

# The file will be saved in: ../email-notification-generated/email-notification-results-generated.json
```

### Function Parameters

The `generate_email_notification_json` function does not take any
parameters.

**Note:** - The Allure results folder is always used by default:
`./allure-results` - The output file is always named
`email-notification-results-generated.json` and is saved in the
`email-notification-generated` directory one level above the
`email-notification` folder.

### Return Values

The function returns: - **The content of the generated JSON** (output to
stdout) - **Environment variable `GENERATED_JSON`** -- JSON content -
**Environment variable `JSON_FILE`** -- Path to the JSON file

## Differences from the Text Version

1.  **Output Format:** JSON instead of text
2.  **Structured Data:** All data is organized into logical sections
3.  **Test Array:** Test details are represented as a JSON array of
    objects
4.  **Data Types:** Numeric values are stored as numbers, not strings
5.  **Metadata:** Includes descriptions of variables and status logic
6.  **No Templates:** JSON is generated directly without using template
    files
