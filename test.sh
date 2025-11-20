#!/bin/bash

# ==============================================================================
# CloudCom Blog Circle - Unified Test Script
# ==============================================================================

set -e
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "Running CloudCom Test Suite"
echo "=========================================="

cd "${ROOT_DIR}"

# Check if tests directory exists and has the main script
if [ -f "tests/run-all-tests.sh" ]; then
    echo "Delegating to tests/run-all-tests.sh..."
    cd tests
    bash run-all-tests.sh
else
    echo "Error: Test suite not found in tests/run-all-tests.sh"
    exit 1
fi
