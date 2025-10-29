# Test Pass Rate Calculator

This set of scripts is designed to analyze test results from the
`allure-results` folder and generate reports with a pass rate.

## Files

### Main Scripts

1.  **`calculate-email-notification-variables.sh`** -- Main script for
    calculating test pass rate
2.  **`generate-email-notification-file.sh`** -- Script for generating a
    message from a template
3.  **`email-notification-body-template.txt`** -- Email notification
    template

### Auxiliary Files

-   **`message-template.msg`** -- Extended template with conditional
    blocks (not used in the final version)
-   **`generate-message.sh`** -- Script for generating a message from a
    template

## Requirements

-   Git Bash (for Windows) or Linux/macOS with bash
-   `jq` (for parsing JSON)
-   `awk` (for calculations and placeholder replacements)

## Usage

### 1. Calculating Pass Rate

``` bash
# Using Git Bash in Windows
& "C:\Program Files\Git\bin\bash.exe" email-notification/calculate-email-notification-variables.sh

# On Linux/macOS
./email-notification/calculate-email-notification-variables.sh
```

The script analyzes all `*-result.json` files in the `allure-results`
folder and outputs: - Overall status (PASSED/PARTIAL/FAILED) - Pass rate
percentage - Number of tests by status - Exports environment variables

### 2. Generating a Message

``` bash
# Using Git Bash in Windows
& "C:\Program Files\Git\bin\bash.exe" email-notification/generate-email-notification-file.sh

# With a specified template
& "C:\Program Files\Git\bin\bash.exe" email-notification/generate-email-notification-file.sh "./email-notification/email-notification-body-template.txt"

# On Linux/macOS
./email-notification/generate-email-notification-file.sh
```

### 3. Combined Usage

``` bash
# First, calculate pass rate
& "C:\Program Files\Git\bin\bash.exe" email-notification/calculate-email-notification-variables.sh

# Then generate the message
& "C:\Program Files\Git\bin\bash.exe" email-notification/generate-email-notification-file.sh
```

## Exported Variables

After running `calculate-email-notification-variables.sh`, the following
environment variables are available:

-   `TEST_PASS_RATE` -- Pass rate with two decimal places (e.g.,
    "50.00")
-   `TEST_PASS_RATE_ROUNDED` -- Rounded pass rate (e.g., "50")
-   `TEST_TOTAL_COUNT` -- Total number of tests
-   `TEST_PASSED_COUNT` -- Number of passed tests
-   `TEST_FAILED_COUNT` -- Number of failed tests
-   `TEST_SKIPPED_COUNT` -- Number of skipped tests
-   `TEST_OVERALL_STATUS` -- Overall status (PASSED/PARTIAL/FAILED)

After running `generate-email-notification-file.sh`, additionally
available:

-   `GENERATED_MESSAGE` -- Contents of the generated message
-   `MESSAGE_FILE` -- Path to the message file

## Template Placeholders

The file `email-notification-body-template.txt` uses the following
placeholders:

-   `{{TEST_OVERALL_STATUS}}` -- Overall status
-   `{{TEST_PASS_RATE}}` -- Pass rate percentage
-   `{{TEST_TOTAL_COUNT}}` -- Total number of tests
-   `{{TEST_PASSED_COUNT}}` -- Number of passed tests
-   `{{TEST_FAILED_COUNT}}` -- Number of failed tests
-   `{{TEST_SKIPPED_COUNT}}` -- Number of skipped tests
-   `{{TEST_FAILURE_RATE}}` -- Failure rate percentage
-   `{{TEST_COVERAGE}}` -- Test coverage
-   `{{EXECUTION_DATE}}` -- Execution date
-   `{{ENVIRONMENT_NAME}}` -- Environment name
-   `{{ATP_REPORT_VIEW_UI_URL}}` -- Host for viewing reports
-   `{{ALLURE_REPORT_URL}}` -- Path to the report folder
-   `{{TIMESTAMP}}` -- Timestamp
-   `{{TEST_DETAILS}}` -- List of all tests with their statuses

## Status Determination Logic

-   **PASSED** -- 100% of tests passed successfully
-   **PARTIAL** -- 80--99% of tests passed successfully
-   **FAILED** -- Less than 80% of tests passed successfully

## Example Output

    ℹ️ Analyzing test results from: /c/Projects/Cursor AI projects/atp3-common-scripts/allure-results
    ℹ️ Processing: 1903d409-587a-44ac-ba5d-b96dfda66c20-result.json
    ❌ ✗ Comprehensive Jira integration test - FAILING @pipeline_job
    ℹ️ Processing: 41085784-d601-466e-b9b3-929d73d12100-result.json
    ✅ ✓ Comprehensive Jira integration test @pipeline_job

    ℹ️ === Test Results Summary ===
    Overall Status: FAILED
    Pass Rate: 50.00%
    Total Tests: 2
    Passed: 1
    Failed: 1
    Skipped: 0

## Integration with Other Scripts

The scripts can be integrated into other bash scripts:

### Option 1: Using a Function (Recommended)

``` bash
#!/bin/bash

# Load the script with the function
source ./email-notification/generate-email-notification-file.sh

# Call the function with parameters
message_content=$(generate_email_notification_file     "./email-notification/email-notification-body-template.txt")

# Use the result
echo "$message_content"

# Or use exported variables
echo "Message file: $MESSAGE_FILE"
echo "Contents: $GENERATED_MESSAGE"

# The file will be saved in: ../email-notification-generated/email-notification-body-template-generated.txt
```

### Option 2: Using Source (Deprecated Method)

``` bash
#!/bin/bash

# Load test pass rate results
source ./email-notification/calculate-email-notification-variables.sh

# Use variables
echo "Pass rate: $TEST_PASS_RATE%"
echo "Status: $TEST_OVERALL_STATUS"

# Generate message
source ./email-notification/generate-email-notification-body-message.sh

# Use the generated message
echo "$GENERATED_MESSAGE"
```

### Function Parameters

The `generate_email_notification_file` function accepts the following
parameters:

1.  **template_file** (optional) -- path to the template file
   -   Default:
       `./email-notification/email-notification-body-template.txt`

**Note:** - The Allure results folder is always used by default:
`./allure-results` - The output file name is automatically generated
based on the template name. The file is saved in the
`email-notification-generated` directory one level above the
`email-notification` folder. For example, if the template is called
`my-template.txt`, the output file will be
`../email-notification-generated/my-template-generated.txt`.

### Return Values

The function returns: - **The content of the generated message** (output
to stdout) - **Environment variable `GENERATED_MESSAGE`** -- message
content - **Environment variable `MESSAGE_FILE`** -- path to the message
file
