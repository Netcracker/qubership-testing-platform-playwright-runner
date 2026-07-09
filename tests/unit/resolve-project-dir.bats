#!/usr/bin/env bats
# Unit tests for scripts/git-clone.sh — ATP_TESTS_PROJECT_ROOT / PROJECT_DIR resolution

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TMP_DIR="$(mktemp -d)"
    export TMP_DIR
    unset ATP_TESTS_PROJECT_ROOT PROJECT_DIR
    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/git-clone.sh"
}

teardown() {
    rm -rf "$TMP_DIR"
}

@test "unset ATP_TESTS_PROJECT_ROOT sets PROJECT_DIR to TMP_DIR" {
    mkdir -p "$TMP_DIR/tests"
    run _resolve_project_dir "$TMP_DIR"
    [ "$status" -eq 0 ]
    [ "$PROJECT_DIR" = "$TMP_DIR" ]
}

@test "nested relative path resolves under TMP_DIR" {
    mkdir -p "$TMP_DIR/packages/e2e/tests"
    export ATP_TESTS_PROJECT_ROOT="packages/e2e"
    run _resolve_project_dir "$TMP_DIR"
    [ "$status" -eq 0 ]
    [ "$PROJECT_DIR" = "$TMP_DIR/packages/e2e" ]
}

@test "absolute ATP_TESTS_PROJECT_ROOT is rejected" {
    mkdir -p "$TMP_DIR/tests"
    export ATP_TESTS_PROJECT_ROOT="/etc"
    run _resolve_project_dir "$TMP_DIR"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "relative path"
}

@test "parent-segment ATP_TESTS_PROJECT_ROOT is rejected" {
    mkdir -p "$TMP_DIR/tests"
    export ATP_TESTS_PROJECT_ROOT="../escape"
    run _resolve_project_dir "$TMP_DIR"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "must not contain"
}

@test "missing ATP_TESTS_PROJECT_ROOT directory is rejected" {
    export ATP_TESTS_PROJECT_ROOT="does/not/exist"
    run _resolve_project_dir "$TMP_DIR"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "not found"
}

@test "_finalize_clone validates markers under PROJECT_DIR" {
    mkdir -p "$TMP_DIR/monorepo/pkg/tests"
    export ATP_TESTS_PROJECT_ROOT="monorepo/pkg"
    run _finalize_clone
    [ "$status" -eq 0 ]
    [ "$PROJECT_DIR" = "$TMP_DIR/monorepo/pkg" ]
    echo "$output" | grep -q "Found 'tests/'"
}

@test "_finalize_clone fails when PROJECT_DIR has no markers" {
    mkdir -p "$TMP_DIR/empty/nested"
    export ATP_TESTS_PROJECT_ROOT="empty/nested"
    run _finalize_clone
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "Neither 'app/'"
}
