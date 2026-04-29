#!/usr/bin/env bash
# E2E smoke test for the playwright-runner Docker image.
#
# Builds the image from the repo root Dockerfile, then runs it with:
#   - tests/e2e/fixture/ mounted as /tmp/clone  (skips real git clone)
#   - UPLOAD_METHOD=none                         (skips inotify/S3 upload)
#   - ATP_STORAGE_PROVIDER=none                  (skips S3 in finalize_upload)
#   - dummy storage credentials                  (satisfies init_environment validation)
#
# Prerequisites: Docker must be running locally or in CI.
# Usage:
#   bash tests/e2e/smoke.sh
#   SKIP_BUILD=1 bash tests/e2e/smoke.sh   # reuse existing image

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IMAGE_NAME="${E2E_IMAGE_NAME:-playwright-runner:e2e-smoke}"
FIXTURE_DIR="$REPO_ROOT/tests/e2e/fixture"

echo "═══════════════════════════════════════════════"
echo " Playwright Runner — E2E Smoke Test"
echo "═══════════════════════════════════════════════"
echo " Repo root : $REPO_ROOT"
echo " Image     : $IMAGE_NAME"
echo " Fixture   : $FIXTURE_DIR"
echo "═══════════════════════════════════════════════"

# ── 1. Build ─────────────────────────────────────────────────────────────────

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
    echo ""
    echo "▶ Building Docker image (this may take a few minutes on first run)..."
    docker build \
        --tag "$IMAGE_NAME" \
        --file "$REPO_ROOT/Dockerfile" \
        "$REPO_ROOT"
    echo "✅ Image built: $IMAGE_NAME"
else
    echo "⏩ SKIP_BUILD=1 — skipping image build, using existing $IMAGE_NAME"
fi

# ── 2. Normalise fixture line endings ────────────────────────────────────────
# Fixture shell scripts are mounted into the Linux container at runtime.
# If git (or a Windows editor) wrote CRLF line endings, bash inside the
# container will fail with "$'\r': command not found".  Run dos2unix here so
# the fix applies regardless of git.autocrlf settings or OS.

echo ""
echo "▶ Normalising fixture line endings (dos2unix)..."
find "$FIXTURE_DIR" -type f \( -name "*.sh" -o -name "*.ts" -o -name "*.json" \) \
    -exec dos2unix --quiet {} \; 2>/dev/null \
  || find "$FIXTURE_DIR" -type f \( -name "*.sh" -o -name "*.ts" -o -name "*.json" \) \
       -exec sed -i 's/\r$//' {} \;
echo "✅ Line endings normalised"

# ── 3. Run ───────────────────────────────────────────────────────────────────

echo ""
echo "▶ Running smoke test inside container..."

docker run --rm \
    --name "playwright-runner-smoke-$$" \
    \
    `# Mount the fixture as the "cloned" test repo.` \
    `# clone_repository() already skips clone when TMP_DIR is non-empty.` \
    --volume "$FIXTURE_DIR:/tmp/clone" \
    \
    `# Tell init.sh / upload-monitor.sh / finalize_upload to skip S3 entirely.` \
    --env "UPLOAD_METHOD=none" \
    --env "ATP_STORAGE_PROVIDER=none" \
    \
    `# Dummy credentials — init_environment validates presence, not values.` \
    --env "ATP_STORAGE_USERNAME=smoke-test-user" \
    --env "ATP_STORAGE_PASSWORD=smoke-test-pass" \
    --env "ATP_STORAGE_BUCKET=smoke-bucket" \
    \
    `# Disable optional features that require external services.` \
    --env "ATP_ENVGENE_CONFIGURATION=" \
    --env "ENABLE_JIRA_INTEGRATION=false" \
    --env "ATP_MONITORING_ENABLED=false" \
    --env "DEBUG_MODE=false" \
    \
    `# Give the container a stable timestamp so paths are predictable.` \
    --env "CURRENT_DATE=2000-01-01" \
    --env "CURRENT_TIME=00-00-00" \
    --env "ENVIRONMENT_NAME=smoke" \
    \
    "$IMAGE_NAME"

EXIT_CODE=$?

echo ""
if [ "$EXIT_CODE" -eq 0 ]; then
    echo "✅ E2E smoke test passed (exit code 0)"
else
    echo "❌ E2E smoke test FAILED (exit code $EXIT_CODE)"
    exit "$EXIT_CODE"
fi
