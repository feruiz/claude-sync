#!/usr/bin/env bats

setup() {
    load '../test_helper'
    load_libs
    setup_test_environment
    source_script "sync.sh"

    # Create OS directory in config repo
    local os_dir
    os_dir=$(get_config_dir)
    mkdir -p "$os_dir"
}

teardown() {
    teardown_test_environment
}

@test "sync_claude_json does nothing when local file does not exist" {
    rm -f "$HOME/.claude.json"
    run sync_claude_json
    assert_success

    local os_dir
    os_dir=$(get_config_dir)
    [[ ! -f "$os_dir/claude.json" ]]
}

@test "sync_claude_json copies full file when repo has no claude.json" {
    install_fixture "claude_full.json" "$HOME/.claude.json"

    run sync_claude_json
    assert_success

    local os_dir
    os_dir=$(get_config_dir)
    [[ -f "$os_dir/claude.json" ]]

    # Verify it's the full file (has telemetry fields)
    local has_telemetry
    has_telemetry=$(jq 'has("numStartups")' "$os_dir/claude.json")
    assert_equal "$has_telemetry" "true"
}

@test "sync_claude_json skips when only telemetry fields changed" {
    local os_dir
    os_dir=$(get_config_dir)

    # Put full file in repo
    install_fixture "claude_full.json" "$os_dir/claude.json"

    # Local file has same relevant fields but different telemetry
    cp "$FIXTURES_DIR/claude_full.json" "$HOME/.claude.json"
    # Change a telemetry field
    local modified
    modified=$(jq '.numStartups = 999' "$HOME/.claude.json")
    echo "$modified" > "$HOME/.claude.json"

    # Record repo file timestamp
    local before_mtime
    before_mtime=$(stat -c %Y "$os_dir/claude.json" 2>/dev/null || stat -f %m "$os_dir/claude.json")

    sleep 1
    run sync_claude_json
    assert_success

    # File should NOT have been updated (same relevant fields)
    local after_mtime
    after_mtime=$(stat -c %Y "$os_dir/claude.json" 2>/dev/null || stat -f %m "$os_dir/claude.json")
    assert_equal "$before_mtime" "$after_mtime"
}

@test "sync_claude_json copies when relevant fields changed" {
    local os_dir
    os_dir=$(get_config_dir)

    # Put full file in repo
    install_fixture "claude_full.json" "$os_dir/claude.json"

    # Local file has different relevant fields
    install_fixture "claude_different.json" "$HOME/.claude.json"

    run sync_claude_json
    assert_success

    # Repo file should be updated to the different file
    local auto_updates
    auto_updates=$(jq -r '.autoUpdates' "$os_dir/claude.json")
    assert_equal "$auto_updates" "false"
}

@test "sync_claude_json preserves full file content on copy" {
    local os_dir
    os_dir=$(get_config_dir)

    install_fixture "claude_full.json" "$HOME/.claude.json"

    run sync_claude_json
    assert_success

    # The saved file should be the full file, not filtered
    local keys_count
    keys_count=$(jq 'keys | length' "$os_dir/claude.json")
    local full_keys_count
    full_keys_count=$(jq 'keys | length' "$FIXTURES_DIR/claude_full.json")
    assert_equal "$keys_count" "$full_keys_count"
}
