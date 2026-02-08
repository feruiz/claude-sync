#!/bin/bash
# Runner script for claude-sync test suite

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BATS="$SCRIPT_DIR/libs/bats-core/bin/bats"

# Initialize submodules if needed
if [[ ! -f "$BATS" ]]; then
    echo "Initializing bats submodules..."
    git -C "$PROJECT_ROOT" submodule update --init --recursive
fi

# Check dependencies
if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is required but not installed"
    exit 1
fi

# Determine what to run
if [[ -n "$1" ]]; then
    echo "Running tests in: $1"
    echo ""
    "$BATS" --recursive "$1"
else
    echo "Running all tests..."
    echo ""
    "$BATS" --recursive "$SCRIPT_DIR/unit" "$SCRIPT_DIR/integration" "$SCRIPT_DIR/git"
fi
