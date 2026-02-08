#!/bin/bash
# Shared test helper for claude-sync bats tests

# Project root (parent of test/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load bats libraries
load_libs() {
    load "${PROJECT_ROOT}/test/libs/bats-support/load"
    load "${PROJECT_ROOT}/test/libs/bats-assert/load"
}

# Create isolated temporary environment for a test
setup_test_environment() {
    # Create unique temp dir per test
    TEST_TEMP_DIR="$(mktemp -d)"

    # Override HOME so scripts don't touch real files
    export HOME="$TEST_TEMP_DIR/home"
    mkdir -p "$HOME/.claude/plugins"

    # Config repo location
    export CONFIG_REPO="$TEST_TEMP_DIR/config-repo"
    mkdir -p "$CONFIG_REPO"

    # Config file location
    export CONFIG_FILE="$TEST_TEMP_DIR/home/.claude-sync"

    # Mock bin directory (prepend to PATH for mocked commands)
    export MOCK_BIN="$TEST_TEMP_DIR/mock-bin"
    mkdir -p "$MOCK_BIN"
    export PATH="$MOCK_BIN:$PATH"

    # Fixtures directory
    export FIXTURES_DIR="${PROJECT_ROOT}/test/fixtures"
}

# Clean up temporary environment
teardown_test_environment() {
    if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Source a script safely (disable set -e which conflicts with bats)
source_script() {
    local script="$1"
    set +e
    source "${PROJECT_ROOT}/${script}"
}

# Initialize a git repo in CONFIG_REPO
init_config_git_repo() {
    git -C "$CONFIG_REPO" init -b main 2>/dev/null
    git -C "$CONFIG_REPO" config user.email "test@test.com"
    git -C "$CONFIG_REPO" config user.name "Test User"

    # Create OS directory structure
    local os
    os=$(uname -s)
    case "$os" in
        Linux*)  os="linux" ;;
        Darwin*) os="macos" ;;
    esac
    mkdir -p "$CONFIG_REPO/$os/plugins"

    # Initial commit
    touch "$CONFIG_REPO/.gitkeep"
    git -C "$CONFIG_REPO" add -A
    git -C "$CONFIG_REPO" commit -m "initial" --allow-empty 2>/dev/null
}

# Create a bare remote repo and connect it as origin
init_remote_repo() {
    export REMOTE_REPO="$TEST_TEMP_DIR/remote-repo.git"
    git init --bare "$REMOTE_REPO" -b main 2>/dev/null
    git -C "$CONFIG_REPO" remote add origin "$REMOTE_REPO" 2>/dev/null || true
    git -C "$CONFIG_REPO" push -u origin main 2>/dev/null
}

# Create a mock command in MOCK_BIN
mock_command() {
    local cmd="$1"
    local body="${2:-exit 0}"
    cat > "$MOCK_BIN/$cmd" << EOF
#!/bin/bash
$body
EOF
    chmod +x "$MOCK_BIN/$cmd"
}

# Mock uname to return a specific OS
mock_uname() {
    local os_string="$1"  # "Linux" or "Darwin"
    mock_command "uname" "echo '$os_string'"
}

# Mock systemctl (no-op)
mock_systemctl() {
    mock_command "systemctl" "exit 0"
}

# Mock launchctl (no-op)
mock_launchctl() {
    mock_command "launchctl" "exit 0"
}

# Copy a fixture file to a destination
install_fixture() {
    local fixture="$1"
    local dest="$2"
    mkdir -p "$(dirname "$dest")"
    cp "${FIXTURES_DIR}/${fixture}" "$dest"
}
