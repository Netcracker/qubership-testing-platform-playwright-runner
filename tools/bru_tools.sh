# ============================================
# check_env_var — ensure an env var is set or compute & export it.
#
# Usage:
#   check_env_var VAR_NAME [COMPUTE_EXPR]
#
# Args:
#   VAR_NAME      Name of the environment variable to check.
#   COMPUTE_EXPR  (optional) Bash expression/command to compute the value if
#                 VAR_NAME is empty. Evaluated with `eval`.
#
# Behavior:
#   - If VAR_NAME is unset/empty:
#       * If COMPUTE_EXPR is provided: evaluates it, exports the result to
#         VAR_NAME, and echoes "VAR_NAME = VALUE (Computed)".
#       * If COMPUTE_EXPR is missing: prints an error to stderr and exits 1.
#   - If VAR_NAME is already set: echoes "VAR_NAME = VALUE".
# ============================================
check_env_var() {
    local var_name="$1"
    local compute_expr="$2"
    local computed_value  # Announcing in advance

    # Check if the variable exists and if it is not empty
    if [[ -z "${!var_name:-}" ]]; then
        if [[ -z "$compute_expr" ]]; then
            echo "❗Error: Variable $var_name must be specified!" >&2
            exit 1
        else
            # Calculate the value
            computed_value=$(eval "$compute_expr" 2>/dev/null)

            # Checking for successful completion
            if [ $? -ne 0 ]; then
                echo "❗Error calculating the value for $var_name" >&2
                exit 1
            fi

            # Export variable
            declare -gx "$var_name"="$computed_value"
            echo "${var_name} = ${computed_value} (Computed)"
        fi
    else
        echo "${var_name} = ${!var_name}"
    fi
}

# ============================================
# Extract Bruno environment file from TEST_PARAMS: section "env"
# and convert them to a string like "environments/test_environment.json"
# Parameters:
#   $1 - JSON input string
#   $2 - Name of the output variable to store the result (optional)
# ============================================
extract_bruno_env() {
    local json_input="$1"
    local output_var_name="$2"
    local result=""

    # Extract the path to the environment
    result=$(echo "$json_input" | jq -r '.env')
    echo "➡️ Extracted Bruno environment: $result"

    # Export the result to a variable with a specified name
    eval "$output_var_name=\"$result\""
}

# ============================================
# Extract Bruno collections from TEST_PARAMS: section "collections"
# and convert them to an array like:"
#   "collections/system1/system1.postman_collection.json",
#   "collections/system2/system2.postman_collection.json"
# Parameters:
#   $1 - JSON input string
#   $2 - Name of the output variable to store the result (optional)
# ============================================
extract_bruno_collections() {
    local json_input="$1"
    local output_var_name="$2"
    local result_array=()

    # Retrieve the array of collections and save it to a temporary array
    readarray -t result_array < <(echo "$json_input" | jq -r '.collections[]')

    # Export the array to a variable with a specified name
    q=''
    for x in "${result_array[@]}"; do
        q+=$(printf ' %q' "$x")
    done
    eval "$output_var_name=(${q# })"

    # Log the result
    local output_message="➡️ Extracted Bruno collections:"
    for collection in "${result_array[@]}"; do
        output_message+="\n    - $collection"
    done
    echo -e "$output_message"
}

# ============================================
# Extract Bruno flags from TEST_PARAMS: section "flags"
# and convert them to a string like "--insecure --iteration-count 5"
# Parameters:
#   $1 - JSON input string
#   $2 - Name of the output variable to store the result (optional)
# ============================================
extract_bruno_flags() {
    local json_input="$1"
    local output_var_name="$2"
    local result=""

    # Extract the flags array from JSON and convert it to a string
    result=$(echo "$json_input" | jq -r '.flags | join(" ")')
    echo "➡️ Extracted Bruno flags: $result"

    # Export the result to a variable with a specified name
    eval "$output_var_name=\"$result\""
}

# ============================================
# Extract Bruno environment variables from TEST_PARAMS: section "env_vars"
# and convert them to a string like "--env-var key1=value1 --env-var key2=value2"
# Parameters:
#   $1 - JSON input string
#   $2 - Name of the output variable to store the result (optional)
# ============================================
extract_bruno_env_vars() {
    local json_input="$1"
    local output_var_name="$2"
    local result=""

    # Get the number of elements in env_vars
    local count
    count=$(jq '.env_vars | length' <<< "$json_input")

    # We go through the indices from 0 to count-1
    for ((i=0; i<count; i++)); do
        # Get the key by index
        local key
        key=$(jq -r ".env_vars | keys[$i]" <<< "$json_input")

        # Get the value by key (with proper escaping)
        local value
        value=$(jq -r ".env_vars[\"$key\"] | @sh" <<< "$json_input")

        # Remove single quotes added by @sh
        value=${value//\'/}

        # Add to the result
        result+=" --env-var $key=$value"

        # Debug output
        # echo "Processing: $key=$value"
    done

    echo "➡️ Extracted Bruno env_vars: $result"

    # Remove the first space and export the result
    if [ -n "$output_var_name" ]; then
        eval "$output_var_name=\"${result# }\""
    else
        echo "${result# }"
    fi
}

# Return:
#   0 — if LOCAL_RUN=true
#   1 — if LOCAL_RUN=false or value not set/empty
#   2 — if incorrect value (not true, not false)
local_run_enabled() {

  local val="${LOCAL_RUN:-}"

  if [ -z "$val" ]; then
    return 1
  fi

  # reduce it to lowercase
  val="$(printf '%s' "$val" | tr '[:upper:]' '[:lower:]')"

  case "$val" in
    true)  return 0 ;;
    false) return 1 ;;
    *)
      printf '❌ Incorrect value LOCAL_RUN=%s (expected true/false)\n' "$LOCAL_RUN" >&2
      return 2
      ;;
  esac
}

# Local test execution module
local_run_tests() {
    cd $TMP_DIR

    echo "▶ Starting test execution..."

    cp -r $WORK_DIR/tools $TMP_DIR/tools

     # Create Allure results directory
    echo "📁 Creating Allure results directory..."
    mkdir -p $TMP_DIR/allure-results

    # Execute test suite
    echo "🚀 Running test suite..."
    chmod +x start_tests.sh
    ./start_tests.sh || TEST_EXIT_CODE=$?

    TEST_EXIT_CODE=${TEST_EXIT_CODE:-0}
    echo "ℹ️ Test script exited with code: $TEST_EXIT_CODE (but continuing...)"
    
    echo "✅ Test execution completed"

    cd $WORK_DIR
}
