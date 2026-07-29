#!/usr/bin/env bats
# Unit tests for scripts/git-clone.sh — PROJECT_ROOT_CANDIDATES / PROJECT_DIR resolution

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TMP_DIR="$(mktemp -d)"
    export TMP_DIR
    unset ATP_TESTS_PROJECT_ROOT PROJECT_DIR ATP_TESTS_IGNORE_STRUCTURE
    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/git-clone.sh"
    # Reset allowlist to production default after source (tests may override).
    PROJECT_ROOT_CANDIDATES=("." "TestGeneration")
}

teardown() {
    rm -rf "$TMP_DIR"
}

@test "markers at root set PROJECT_DIR to TMP_DIR" {
    mkdir -p "$TMP_DIR/tests"
    _resolve_project_dir "$TMP_DIR"
    [ "$PROJECT_DIR" = "$TMP_DIR" ]
}

@test "TestGeneration with markers is selected when root has none" {
    mkdir -p "$TMP_DIR/TestGeneration/tests"
    _resolve_project_dir "$TMP_DIR"
    [ "$PROJECT_DIR" = "$TMP_DIR/TestGeneration" ] || [ "$PROJECT_DIR" = "$(realpath "$TMP_DIR/TestGeneration")" ]
}

@test "root markers win over TestGeneration" {
    mkdir -p "$TMP_DIR/tests"
    mkdir -p "$TMP_DIR/TestGeneration/tests"
    _resolve_project_dir "$TMP_DIR"
    [ "$PROJECT_DIR" = "$TMP_DIR" ]
}

@test "TestGeneration without markers falls back to root" {
    mkdir -p "$TMP_DIR/TestGeneration"
    _resolve_project_dir "$TMP_DIR"
    [ "$PROJECT_DIR" = "$TMP_DIR" ]
}

@test "nested allowlist candidate is selected when present with markers" {
    mkdir -p "$TMP_DIR/Template/Folder/Tests/tests"
    PROJECT_ROOT_CANDIDATES=("." "Template/Folder/Tests")
    _resolve_project_dir "$TMP_DIR"
    expected="$TMP_DIR/Template/Folder/Tests"
    [ "$PROJECT_DIR" = "$expected" ] || [ "$PROJECT_DIR" = "$(realpath "$expected")" ]
}

@test "absolute allowlist entry hard-fails" {
    mkdir -p "$TMP_DIR/tests"
    PROJECT_ROOT_CANDIDATES=("/etc")
    run _resolve_project_dir "$TMP_DIR"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "relative path"
}

@test "parent-segment allowlist entry hard-fails" {
    mkdir -p "$TMP_DIR/tests"
    PROJECT_ROOT_CANDIDATES=("../escape")
    run _resolve_project_dir "$TMP_DIR"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "must not contain"
}

@test "ATP_TESTS_PROJECT_ROOT is ignored; auto-detect still runs" {
    mkdir -p "$TMP_DIR/TestGeneration/tests"
    mkdir -p "$TMP_DIR/packages/e2e/tests"
    export ATP_TESTS_PROJECT_ROOT="packages/e2e"
    _resolve_project_dir "$TMP_DIR"
    [ "$PROJECT_DIR" = "$TMP_DIR/TestGeneration" ] || [ "$PROJECT_DIR" = "$(realpath "$TMP_DIR/TestGeneration")" ]
}

@test "_finalize_clone validates markers under TestGeneration" {
    mkdir -p "$TMP_DIR/TestGeneration/tests"
    _finalize_clone
    [ "$PROJECT_DIR" = "$TMP_DIR/TestGeneration" ] || [ "$PROJECT_DIR" = "$(realpath "$TMP_DIR/TestGeneration")" ]
}

@test "_finalize_clone fails when no markers and no qualifying candidate" {
    mkdir -p "$TMP_DIR/readme-only"
    echo "x" > "$TMP_DIR/readme-only/README.md"
    run _finalize_clone
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "Neither 'app/'"
}

@test "_finalize_clone fails when TestGeneration exists but has no markers" {
    mkdir -p "$TMP_DIR/TestGeneration/empty"
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
