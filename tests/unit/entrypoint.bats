#!/usr/bin/env bats
# Unit tests for entrypoint.sh orchestration logic.
#
# Strategy:
#   1. Load mock_scripts.bash — stubs every function sourced from /scripts/*.sh
#   2. Load source_interceptor — overrides `source` builtin so `/scripts/*.sh`
#      paths become no-ops (mocks already loaded)
#   3. Source entrypoint.sh in a sub-shell or via `run bash` so we can assert
#      exit codes without killing the test process

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    load "helpers/mock_scripts"
    load "helpers/source_interceptor"
}

# ── UPLOAD_METHOD default ────────────────────────────────────────────────────

@test "UPLOAD_METHOD defaults to sync when unset" {
    unset UPLOAD_METHOD
    # Source entrypoint.sh; the interceptor silences /scripts/* sources
    # and mocks handle the function calls.
    source "$REPO_ROOT/entrypoint.sh"
    [ "$UPLOAD_METHOD" = "sync" ]
}

@test "UPLOAD_METHOD is preserved when already set" {
    export UPLOAD_METHOD="cp"
    source "$REPO_ROOT/entrypoint.sh"
    [ "$UPLOAD_METHOD" = "cp" ]
}

# ── NATIVE_REPORT_DIR ────────────────────────────────────────────────────────

@test "NATIVE_REPORT_DIR is set to playwright-report" {
    source "$REPO_ROOT/entrypoint.sh"
    [ "$NATIVE_REPORT_DIR" = "playwright-report" ]
}

# ── Orchestration: happy path ─────────────────────────────────────────────────

@test "entrypoint.sh exits 0 when all steps succeed" {
    run bash -c "
        source '$REPO_ROOT/tests/unit/helpers/mock_scripts.bash'
        source '$REPO_ROOT/tests/unit/helpers/source_interceptor.bash'
        source '$REPO_ROOT/entrypoint.sh'
    "
    [ "$status" -eq 0 ]
}

@test "entrypoint.sh calls init_environment" {
    run bash -c "
        source '$REPO_ROOT/tests/unit/helpers/mock_scripts.bash'
        source '$REPO_ROOT/tests/unit/helpers/source_interceptor.bash'
        source '$REPO_ROOT/entrypoint.sh'
    "
    echo "$output" | grep -q "mock: init_environment"
}

@test "entrypoint.sh calls clone_repository" {
    run bash -c "
        source '$REPO_ROOT/tests/unit/helpers/mock_scripts.bash'
        source '$REPO_ROOT/tests/unit/helpers/source_interceptor.bash'
        source '$REPO_ROOT/entrypoint.sh'
    "
    echo "$output" | grep -q "mock: clone_repository"
}

@test "entrypoint.sh calls render_environment_configuration" {
    run bash -c "
        source '$REPO_ROOT/tests/unit/helpers/mock_scripts.bash'
        source '$REPO_ROOT/tests/unit/helpers/source_interceptor.bash'
        source '$REPO_ROOT/entrypoint.sh'
    "
    echo "$output" | grep -q "mock: render_environment_configuration"
}

@test "entrypoint.sh calls load_envgene" {
    run bash -c "
        source '$REPO_ROOT/tests/unit/helpers/mock_scripts.bash'
        source '$REPO_ROOT/tests/unit/helpers/source_interceptor.bash'
        source '$REPO_ROOT/entrypoint.sh'
    "
    echo "$output" | grep -q "mock: load_envgene"
}

@test "entrypoint.sh calls setup_runtime_environment" {
    run bash -c "
        source '$REPO_ROOT/tests/unit/helpers/mock_scripts.bash'
        source '$REPO_ROOT/tests/unit/helpers/source_interceptor.bash'
        source '$REPO_ROOT/entrypoint.sh'
    "
    echo "$output" | grep -q "mock: setup_runtime_environment"
}

@test "entrypoint.sh calls start_upload_monitoring" {
    run bash -c "
        source '$REPO_ROOT/tests/unit/helpers/mock_scripts.bash'
        source '$REPO_ROOT/tests/unit/helpers/source_interceptor.bash'
        source '$REPO_ROOT/entrypoint.sh'
    "
    echo "$output" | grep -q "mock: start_upload_monitoring"
}

@test "entrypoint.sh calls run_tests" {
    run bash -c "
        source '$REPO_ROOT/tests/unit/helpers/mock_scripts.bash'
        source '$REPO_ROOT/tests/unit/helpers/source_interceptor.bash'
        source '$REPO_ROOT/entrypoint.sh'
    "
    echo "$output" | grep -q "mock: run_tests"
}

# ── Orchestration: failure paths ─────────────────────────────────────────────

@test "init_environment failure causes non-zero exit" {
    run bash -c "
        source '$REPO_ROOT/tests/unit/helpers/mock_scripts.bash'
        source '$REPO_ROOT/tests/unit/helpers/source_interceptor.bash'
        init_environment() { return 1; }
        export -f init_environment
        source '$REPO_ROOT/entrypoint.sh'
    "
    [ "$status" -ne 0 ]
}

@test "clone_repository failure causes non-zero exit" {
    run bash -c "
        source '$REPO_ROOT/tests/unit/helpers/mock_scripts.bash'
        source '$REPO_ROOT/tests/unit/helpers/source_interceptor.bash'
        clone_repository() { return 1; }
        export -f clone_repository
        source '$REPO_ROOT/entrypoint.sh'
    "
    [ "$status" -ne 0 ]
}

@test "render_environment_configuration failure causes non-zero exit" {
    run bash -c "
        source '$REPO_ROOT/tests/unit/helpers/mock_scripts.bash'
        source '$REPO_ROOT/tests/unit/helpers/source_interceptor.bash'
        render_environment_configuration() { return 1; }
        export -f render_environment_configuration
        source '$REPO_ROOT/entrypoint.sh'
    "
    [ "$status" -ne 0 ]
}

@test "load_envgene failure causes non-zero exit" {
    run bash -c "
        source '$REPO_ROOT/tests/unit/helpers/mock_scripts.bash'
        source '$REPO_ROOT/tests/unit/helpers/source_interceptor.bash'
        load_envgene() { return 1; }
        export -f load_envgene
        source '$REPO_ROOT/entrypoint.sh'
    "
    [ "$status" -ne 0 ]
}

@test "setup_runtime_environment failure causes non-zero exit" {
    run bash -c "
        source '$REPO_ROOT/tests/unit/helpers/mock_scripts.bash'
        source '$REPO_ROOT/tests/unit/helpers/source_interceptor.bash'
        setup_runtime_environment() { return 1; }
        export -f setup_runtime_environment
        source '$REPO_ROOT/entrypoint.sh'
    "
    [ "$status" -ne 0 ]
}

@test "run_tests failure causes non-zero exit" {
    run bash -c "
        source '$REPO_ROOT/tests/unit/helpers/mock_scripts.bash'
        source '$REPO_ROOT/tests/unit/helpers/source_interceptor.bash'
        run_tests() { return 1; }
        export -f run_tests
        source '$REPO_ROOT/entrypoint.sh'
    "
    [ "$status" -ne 0 ]
}

@test "start_upload_monitoring is called even when preceding steps set vars" {
    # start_upload_monitoring must always be called (no || fail guard on it)
    run bash -c "
        source '$REPO_ROOT/tests/unit/helpers/mock_scripts.bash'
        source '$REPO_ROOT/tests/unit/helpers/source_interceptor.bash'
        called=0
        start_upload_monitoring() { called=1; echo 'mock: start_upload_monitoring'; }
        export -f start_upload_monitoring
        source '$REPO_ROOT/entrypoint.sh'
        [ \"\$called\" -eq 1 ]
    "
    [ "$status" -eq 0 ]
}
