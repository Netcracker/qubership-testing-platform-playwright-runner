#!/bin/bash
# # Copyright 2024-2025 NetCracker Technology Corporation
# #
# # Licensed under the Apache License, Version 2.0 (the "License");
# # you may not use this file except in compliance with the License.
# # You may obtain a copy of the License at
# #
# #      http://www.apache.org/licenses/LICENSE-2.0
# #
# # Unless required by applicable law or agreed to in writing, software
# # distributed under the License is distributed on an "AS IS" BASIS,
# # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# # See the License for the specific language governing permissions and
# # limitations under the License.


# YAML Configuration Utilities (Shell Script Version)
# 
# This script provides functions to read YAML configuration files
# and extract specific parameters like jira-integration
#
# Dependencies:
# - curl (for fetching YAML from GitLab)
# - grep, sed, awk (for YAML parsing)

set -euo pipefail

# Protect against undefined variables (but allow some flexibility)
set +u

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check ENV_NAME environment variable
if [[ -z "${ENV_NAME:-}" ]]; then
    echo -e "${RED}❌ ENV_NAME environment variable is not set!${NC}" >&2
    echo "Please set ENV_NAME to one of the available environments:" >&2
    echo "Example: export ENV_NAME=nd2154-dev" >&2
fi

echo -e "${BLUE}ℹ️ ENV_NAME is set to: ${ENV_NAME}${NC}" >&2

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️ $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Extract environment configurations from config.ts or environments.ts
get_environments_from_config() {
    local config_path="/tmp/clone/config/config.ts"
    local environments_path="/tmp/clone/config/environments.ts"
    
    # Try to load environments from config.ts first
    if [ -f "$config_path" ]; then
        log_info "Looking for environments in config.ts at: $config_path" >&2
        
        # Read config.ts content
        local config_content
        config_content=$(cat "$config_path")
        
        # Extract environments object using awk for better multi-line handling
        local environments_block
        environments_block=$(echo "$config_content" | awk '
            /export const environments: Config = {/ {
                in_environments = 1
                brace_count = 1
                next
            }
            in_environments {
                if ($0 ~ /{/) brace_count++
                if ($0 ~ /}/) brace_count--
                if (brace_count == 0) {
                    in_environments = 0
                    exit
                }
                print
            }
        ')
        
        if [[ -n "$environments_block" ]]; then
            log_success "Found environments configuration in config.ts" >&2
            log_info "Environments block preview:" >&2
            # Escape all potential variable references to prevent bash interpretation
            echo "$environments_block" | head -10 | sed 's/\$/\\$/g' | sed 's/nd2154-dev/nd2154-dev/g' >&2
            
            # Parse each environment
            while IFS= read -r line; do
                if [[ $line =~ \"([^\"]+)\":\ \{ ]]; then
                    local env_name="${BASH_REMATCH[1]}"
                    log_info "Found environment: $env_name" >&2
                    
                                         # Extract properties for this environment
                     local gitlab_url=$(echo "$environments_block" | grep -A 10 "\"$env_name\":" | grep "gitlabUrl:" | sed 's/.*gitlabUrl:\s*"\([^"]*\)".*/\1/')
                     local gitlab_token=$(echo "$environments_block" | grep -A 10 "\"$env_name\":" | grep "gitlabToken:" | sed 's/.*gitlabToken:\s*"\([^"]*\)".*/\1/')
                     local gitlab_branch=$(echo "$environments_block" | grep -A 10 "\"$env_name\":" | grep "gitlabBranch:" | sed 's/.*gitlabBranch:\s*"\([^"]*\)".*/\1/')
                     local gitlab_project=$(echo "$environments_block" | grep -A 10 "\"$env_name\":" | grep "gitlabProject:" | sed 's/.*gitlabProject:\s*"\([^"]*\)".*/\1/')
                     # Try gitlabParametersFilePath first, then gitlabFilePath for config.ts
                     local gitlab_file_path=$(echo "$environments_block" | grep -A 10 "\"$env_name\":" | grep "gitlabParametersFilePath:" | sed 's/.*gitlabParametersFilePath:\s*"\([^"]*\)".*/\1/')
                     
                     # If gitlabParametersFilePath not found, try gitlabFilePath
                     if [ -z "$gitlab_file_path" ]; then
                         gitlab_file_path=$(echo "$environments_block" | grep -A 10 "\"$env_name\":" | grep "gitlabFilePath:" | sed 's/.*gitlabFilePath:\s*"\([^"]*\)".*/\1/')
                     fi
                    
                                         if [ -n "$gitlab_url" ] && [ -n "$gitlab_token" ] && [ -n "$gitlab_branch" ] && [ -n "$gitlab_project" ] && [ -n "$gitlab_file_path" ]; then
                         ENVIRONMENTS["$env_name"]="$gitlab_url|$gitlab_token|$gitlab_branch|$gitlab_project|$gitlab_file_path"
                         log_success "Added environment: $env_name" >&2
                     else
                         log_warning "Incomplete configuration for environment: $env_name (config.ts)" >&2
                         log_info "  gitlab_url: '$gitlab_url'" >&2
                         log_info "  gitlab_token: '${gitlab_token:0:10}...'" >&2
                         log_info "  gitlab_branch: '$gitlab_branch'" >&2
                         log_info "  gitlab_project: '$gitlab_project'" >&2
                         log_info "  gitlab_file_path: '$gitlab_file_path'" >&2
                     fi
                fi
            done < <(echo "$environments_block" | grep -E '"[^"]+":\s*\{')
            
            if [ ${#ENVIRONMENTS[@]} -gt 0 ]; then
                log_success "Successfully loaded ${#ENVIRONMENTS[@]} environments from config.ts" >&2
                return 0
            else
                log_warning "No valid environments found in config.ts, trying environments.ts" >&2
            fi
        else
            log_warning "No environments configuration found in config.ts, trying environments.ts" >&2
        fi
    else
        log_warning "config.ts not found at: $config_path, trying environments.ts" >&2
    fi
    
    # Try to load environments from environments.ts if config.ts failed
    if [ -f "$environments_path" ]; then
        log_info "Looking for environments in environments.ts at: $environments_path" >&2
        
        # Read environments.ts content
        local environments_content
        environments_content=$(cat "$environments_path")
        
        # Extract environments object using awk for better multi-line handling
        local environments_block
        environments_block=$(echo "$environments_content" | awk '
            /export const environments: Config = {/ {
                in_environments = 1
                brace_count = 1
                next
            }
            /export const environments = {/ {
                in_environments = 1
                brace_count = 1
                next
            }
            in_environments {
                if ($0 ~ /{/) brace_count++
                if ($0 ~ /}/) brace_count--
                if (brace_count == 0) {
                    in_environments = 0
                    exit
                }
                print
            }
        ')
        
        if [[ -n "$environments_block" ]]; then
            log_success "Found environments configuration in environments.ts" >&2
            log_info "Environments block preview:" >&2
            # Escape all potential variable references to prevent bash interpretation
            echo "$environments_block" | head -10 | sed 's/\$/\\$/g' | sed 's/nd2154-dev/nd2154-dev/g' >&2
            
            # Parse each environment
            while IFS= read -r line; do
                if [[ $line =~ \"([^\"]+)\":\ \{ ]]; then
                    local env_name="${BASH_REMATCH[1]}"
                    log_info "Found environment: $env_name" >&2
                    
                                         # Extract properties for this environment
                     local gitlab_url=$(echo "$environments_block" | grep -A 10 "\"$env_name\":" | grep "gitlabUrl:" | sed 's/.*gitlabUrl:\s*"\([^"]*\)".*/\1/')
                     local gitlab_token=$(echo "$environments_block" | grep -A 10 "\"$env_name\":" | grep "gitlabToken:" | sed 's/.*gitlabToken:\s*"\([^"]*\)".*/\1/')
                     local gitlab_branch=$(echo "$environments_block" | grep -A 10 "\"$env_name\":" | grep "gitlabBranch:" | sed 's/.*gitlabBranch:\s*"\([^"]*\)".*/\1/')
                     local gitlab_project=$(echo "$environments_block" | grep -A 10 "\"$env_name\":" | grep "gitlabProject:" | sed 's/.*gitlabProject:\s*"\([^"]*\)".*/\1/')
                     # Try gitlabParametersFilePath first, then gitlabFilePath for environments.ts
                     local gitlab_file_path=$(echo "$environments_block" | grep -A 10 "\"$env_name\":" | grep "gitlabParametersFilePath:" | sed 's/.*gitlabParametersFilePath:\s*"\([^"]*\)".*/\1/')
                     
                     # If gitlabParametersFilePath not found, try gitlabFilePath
                     if [ -z "$gitlab_file_path" ]; then
                         gitlab_file_path=$(echo "$environments_block" | grep -A 10 "\"$env_name\":" | grep "gitlabFilePath:" | sed 's/.*gitlabFilePath:\s*"\([^"]*\)".*/\1/')
                     fi
                    
                    if [ -n "$gitlab_url" ] && [ -n "$gitlab_token" ] && [ -n "$gitlab_branch" ] && [ -n "$gitlab_project" ] && [ -n "$gitlab_file_path" ]; then
                        ENVIRONMENTS["$env_name"]="$gitlab_url|$gitlab_token|$gitlab_branch|$gitlab_project|$gitlab_file_path"
                        log_success "Added environment: $env_name" >&2
                    else
                        log_warning "Incomplete configuration for environment: $env_name (environments.ts)" >&2
                        log_info "  gitlab_url: '$gitlab_url'" >&2
                        log_info "  gitlab_token: '${gitlab_token:0:10}...'" >&2
                        log_info "  gitlab_branch: '$gitlab_branch'" >&2
                        log_info "  gitlab_project: '$gitlab_project'" >&2
                        log_info "  gitlab_file_path: '$gitlab_file_path'" >&2
                    fi
                fi
            done < <(echo "$environments_block" | grep -E '"[^"]+":\s*\{')
            
            if [ ${#ENVIRONMENTS[@]} -gt 0 ]; then
                log_success "Successfully loaded ${#ENVIRONMENTS[@]} environments from environments.ts" >&2
                return 0
            else
                log_error "No valid environments found in environments.ts" >&2
                return 1
            fi
        else
            log_error "No environments configuration found in environments.ts" >&2
            return 1
        fi
    else
        log_error "Neither config.ts nor environments.ts found" >&2
        log_info "Tried paths:" >&2
        log_info "  - $config_path" >&2
        log_info "  - $environments_path" >&2
        return 1
    fi
}

# Load environments from config.ts
declare -A ENVIRONMENTS
if ! get_environments_from_config >&2; then
    log_error "Failed to load environments from config.ts" >&2
    log_warning "Will use empty environments configuration" >&2
fi

# Get current environment from environment variables
get_current_environment() {
    local env_name="${ENV_NAME:-}"
    
    if [ -z "$env_name" ]; then
        log_error "ENV_NAME environment variable is not set!"
        return 1
    fi
    
    if [[ -n "${ENVIRONMENTS[$env_name]:-}" ]]; then
        echo "$env_name"
        return 0
    else
        log_error "Environment '$env_name' not found!"
        log_info "Available environments:"
        for env in "${!ENVIRONMENTS[@]}"; do
            echo "  - $env"
        done
        return 1
    fi
}

# Fetch YAML file from GitLab
fetch_yaml_from_gitlab() {
    local environment_name="$1"
    
    log_info "fetch_yaml_from_gitlab called with: $environment_name" >&2
    
    if [[ -z "${ENVIRONMENTS[$environment_name]:-}" ]]; then
        log_error "Environment '$environment_name' not found in configuration" >&2
        return 1
    fi
    
    # Parse environment configuration
    IFS='|' read -r gitlab_url gitlab_token gitlab_branch gitlab_project gitlab_file_path <<< "${ENVIRONMENTS[$environment_name]}"
    
    log_info "Parsed configuration for $environment_name:" >&2
    log_info "  URL: $gitlab_url" >&2
    log_info "  Project: $gitlab_project" >&2
    log_info "  Branch: $gitlab_branch" >&2
    log_info "  File path: $gitlab_file_path" >&2
    
    # Encode project path for URL
    local encoded_project
    encoded_project=$(echo "$gitlab_project" | sed 's/\//%2F/g')
    
    # Encode file path for URL
    local encoded_file_path
    encoded_file_path=$(echo "$gitlab_file_path" | sed 's/\//%2F/g')
    
    # Construct GitLab API URL
    local api_url="${gitlab_url}/api/v4/projects/${encoded_project}/repository/files/${encoded_file_path}/raw?ref=${gitlab_branch}"
    
    log_info "Fetching YAML from GitLab API: $api_url" >&2
    
    # Fetch YAML content using curl
    local yaml_content
    local curl_output
    local curl_exit_code
    
    log_info "Making curl request with token: ${gitlab_token:0:10}..." >&2
    
    curl_output=$(curl -s -w "%{http_code}" -H "PRIVATE-TOKEN: $gitlab_token" "$api_url" 2>&1)
    curl_exit_code=$?
    
    if [ $curl_exit_code -eq 0 ]; then
        # Extract HTTP status code (last line)
        local http_code="${curl_output: -3}"
        # Extract response body (everything except last 3 characters)
        yaml_content="${curl_output%???}"
        
        log_info "Curl exit code: $curl_exit_code, HTTP status: $http_code" >&2
        
        if [ "$http_code" = "200" ] && [[ -n "$yaml_content" ]]; then
            log_success "Successfully fetched YAML for environment: $environment_name" >&2
            echo "$yaml_content"
            return 0
        else
            log_error "HTTP $http_code response from GitLab API" >&2
            log_info "Response preview:" >&2
            echo "$yaml_content" | head -5 >&2
            return 1
        fi
    else
        log_error "Curl failed with exit code: $curl_exit_code" >&2
        log_info "Curl output:" >&2
        echo "$curl_output" >&2
        return 1
    fi
}

# Parse YAML and extract features section
parse_yaml_features() {
    local yaml_content="$1"
    
    # Extract features section using awk - handle both direct features and nested under atp_envgene_configuration
    local features_section
    features_section=$(echo "$yaml_content" | awk '
        /^features:/ { in_features = 1; print; next }
        /^atp_envgene_configuration:/ { in_atp = 1; next }
        in_atp && /^  features:/ { in_features = 1; print; next }
        /^[a-zA-Z][a-zA-Z0-9_-]*:/ && in_features && !/^  / { in_features = 0 }
        /^[a-zA-Z][a-zA-Z0-9_-]*:/ && in_atp && !/^  / { in_atp = 0; in_features = 0 }
        in_features { print }
    ')
    
    echo "$features_section"
}

# Check if jira-integration is enabled
is_jira_integration_enabled() {
    local environment_name="$1"
    
    log_info "Checking jira-integration for environment: $environment_name" >&2
    
    # Fetch YAML content
    local yaml_content
    if ! yaml_content=$(fetch_yaml_from_gitlab "$environment_name" 2>&1); then
        log_error "Failed to fetch YAML content - jira-integration will be considered DISABLED" >&2
        echo -n "false"
        return 0
    fi
    
    # Parse features section
    local features_section
    features_section=$(parse_yaml_features "$yaml_content")
    
    log_info "YAML content preview:" >&2
    echo "$yaml_content" | head -20 >&2
    
    if [[ -z "$features_section" ]]; then
        log_warning "No features section found in YAML - jira-integration will be considered DISABLED" >&2
        echo -n "false"
        return 0
    fi
    
    # Check for jira-integration in list format (jira-integration: true)
    if echo "$features_section" | grep -q "jira-integration:\s*true"; then
        log_success "jira-integration is ENABLED for environment: $environment_name" >&2
        echo -n "true"
        return 0
    elif echo "$features_section" | grep -q "jira-integration:\s*false"; then
        log_warning "jira-integration is DISABLED for environment: $environment_name" >&2
        echo -n "false"
        return 0
    else
        log_warning "jira-integration parameter not found in features section" >&2
        log_info "Features section content:" >&2
        echo "$features_section" >&2
        log_info "Add jira-integration: true/false to features section in YAML configuration" >&2
        echo -n "false"
        return 0
    fi
}

# Get current environment and check jira integration
check_current_environment_jira_integration() {
    local current_env
    if ! current_env=$(get_current_environment 2>&1); then
        log_error "Failed to get current environment" >&2
        echo "false"
        return 1
    fi
    
    # Get the result directly from is_jira_integration_enabled
    local result
    result=$(is_jira_integration_enabled "$current_env" 2>/dev/null)
    
    # If we got a result, use it; otherwise default to false
    if [ "$result" = "true" ]; then
        echo -n "true"
        return 0
    elif [ "$result" = "false" ]; then
        echo -n "false"
        return 0
    else
        log_warning "Could not determine jira-integration status, defaulting to false" >&2
        echo -n "false"
        return 0
    fi
}

# Main function for external use
main() {
    local command="${1:-check}"
    
    case "$command" in
        "check")
            check_current_environment_jira_integration
            ;;
        "env")
            get_current_environment
            ;;
        "fetch")
            local env="${2:-}"
            if [[ -z "$env" ]]; then
                env=$(get_current_environment)
            fi
            fetch_yaml_from_gitlab "$env"
            ;;
        "features")
            local env="${2:-}"
            if [[ -z "$env" ]]; then
                env=$(get_current_environment)
            fi
            local yaml_content
            yaml_content=$(fetch_yaml_from_gitlab "$env")
            parse_yaml_features "$yaml_content"
            ;;
        *)
            echo "Usage: $0 {check|env|fetch|features} [environment]"
            echo "  check   - Check if jira-integration is enabled (default)"
            echo "  env     - Get current environment name"
            echo "  fetch   - Fetch YAML content for environment"
            echo "  features - Extract features section from YAML"
            exit 1
            ;;
    esac
}

# Export functions for use in other scripts
export -f get_current_environment
export -f fetch_yaml_from_gitlab
export -f parse_yaml_features
export -f is_jira_integration_enabled
export -f check_current_environment_jira_integration

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
