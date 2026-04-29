#!/bin/bash
# Entry point called by test-runner.sh inside the runner container.
# node_modules is pre-populated by the runtime setup (playwright-setup.sh copies
# /app/node_modules into $TMP_DIR), so no network install is needed.
set -euo pipefail

echo "▶ Running Playwright smoke tests..."
npx playwright test --reporter=line
