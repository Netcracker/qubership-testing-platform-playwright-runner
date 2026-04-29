#!/usr/bin/env bash
# Intercepts `source /scripts/*.sh` calls in entrypoint.sh so they become
# no-ops. All real functions are already stubbed in mock_scripts.bash which
# is loaded before entrypoint.sh is sourced.
#
# Usage (in a bats setup() helper):
#   load "helpers/source_interceptor"
#
# This redefines the shell builtin `source` / `.` as a bash function so that
# any path under /scripts/ is silently skipped (the mocks are already loaded).

source() {
    local path="${1:-}"
    # Let non-/scripts paths through (e.g. bats internal loads)
    if [[ "$path" == /scripts/* ]] || [[ "$path" == /app/scripts/* ]]; then
        return 0
    fi
    # Fall back to the real builtin for everything else
    builtin source "$@"
}
