#!/usr/bin/env bats
# Unit tests for scripts/git-clone.sh — ATP_TESTS_PROJECT_ROOT / PROJECT_DIR resolution

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TMP_DIR="$(mktemp -d)"
    export TMP_DIR
    unset ATP_TESTS_PROJECT_ROOT PROJECT_DIR ATP_TESTS_IGNORE_STRUCTURE
    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/git-clone.sh"
}

teardown() {
    rm -rf "$TMP_DIR"
}

@test "unset ATP_TESTS_PROJECT_ROOT with markers at root sets PROJECT_DIR to TMP_DIR" {
    mkdir -p "$TMP_DIR/tests"
    _resolve_project_dir "$TMP_DIR"
    [ "$PROJECT_DIR" = "$TMP_DIR" ]
}

@test "unset ATP_TESTS_PROJECT_ROOT auto-detects TestGeneration" {
    mkdir -p "$TMP_DIR/TestGeneration/tests"
    _resolve_project_dir "$TMP_DIR"
    [ "$ATP_TESTS_PROJECT_ROOT" = "TestGeneration" ]
    [ "$PROJECT_DIR" = "$TMP_DIR/TestGeneration" ]
}

@test "explicit ATP_TESTS_PROJECT_ROOT wins over TestGeneration" {
    mkdir -p "$TMP_DIR/TestGeneration/tests"
    mkdir -p "$TMP_DIR/packages/e2e/tests"
    export ATP_TESTS_PROJECT_ROOT="packages/e2e"
    _resolve_project_dir "$TMP_DIR"
    [ "$PROJECT_DIR" = "$TMP_DIR/packages/e2e" ]
}

@test "nested relative path resolves under TMP_DIR" {
    mkdir -p "$TMP_DIR/packages/e2e/tests"
    export ATP_TESTS_PROJECT_ROOT="packages/e2e"
    _resolve_project_dir "$TMP_DIR"
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
    _finalize_clone
    [ "$PROJECT_DIR" = "$TMP_DIR/monorepo/pkg" ]
}

@test "_finalize_clone auto-detects TestGeneration and validates inside it" {
    mkdir -p "$TMP_DIR/TestGeneration/tests"
    _finalize_clone
    [ "$PROJECT_DIR" = "$TMP_DIR/TestGeneration" ]
    [ "$ATP_TESTS_PROJECT_ROOT" = "TestGeneration" ]
}

@test "_finalize_clone fails when PROJECT_DIR has no markers" {
    mkdir -p "$TMP_DIR/empty/nested"
    export ATP_TESTS_PROJECT_ROOT="empty/nested"
    run _finalize_clone
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "Neither 'app/'"
}

@test "_finalize_clone fails when no markers and no TestGeneration" {
    mkdir -p "$TMP_DIR/readme-only"
    echo "x" > "$TMP_DIR/readme-only/README.md"
    run _finalize_clone
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "Neither 'app/'"
}

@test "_finalize_clone proceeds when ATP_TESTS_IGNORE_STRUCTURE=true and no markers" {
    mkdir -p "$TMP_DIR/readme-only"
    echo "x" > "$TMP_DIR/readme-only/README.md"
    export ATP_TESTS_IGNORE_STRUCTURE=true
    _finalize_clone
    [ "$PROJECT_DIR" = "$TMP_DIR" ]
}
