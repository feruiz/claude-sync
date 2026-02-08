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

@test "sync_claude_json preserves full file content on first copy" {
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

@test "sync_claude_json merges repo configs with local on push" {
    local os_dir
    os_dir=$(get_config_dir)

    # Repo has configs from another machine (repo2 with mcpServers)
    cat > "$os_dir/claude.json" << 'EOF'
{
  "autoUpdates": true,
  "numStartups": 20,
  "projects": {
    "/home/user/projects/repo2": {
      "allowedTools": ["Read", "Write"],
      "mcpServers": {
        "remote-server": {
          "command": "npx",
          "args": ["-y", "remote-mcp"]
        }
      }
    }
  }
}
EOF

    # Local has different project with different config
    cat > "$HOME/.claude.json" << 'EOF'
{
  "autoUpdates": false,
  "numStartups": 50,
  "userID": "local-user",
  "projects": {
    "/home/user/projects/repo1": {
      "allowedTools": ["Bash"],
      "mcpServers": {}
    }
  }
}
EOF

    run sync_claude_json
    assert_success

    # Local telemetry should prevail
    local num_startups
    num_startups=$(jq '.numStartups' "$os_dir/claude.json")
    assert_equal "$num_startups" "50"

    local user_id
    user_id=$(jq -r '.userID' "$os_dir/claude.json")
    assert_equal "$user_id" "local-user"

    # Local relevant fields should prevail
    local auto_updates
    auto_updates=$(jq '.autoUpdates' "$os_dir/claude.json")
    assert_equal "$auto_updates" "false"

    # Repo-only project should be preserved (not lost)
    local repo2_tools
    repo2_tools=$(jq -r '.projects["/home/user/projects/repo2"].allowedTools[0]' "$os_dir/claude.json")
    assert_equal "$repo2_tools" "Read"

    local remote_server
    remote_server=$(jq -r '.projects["/home/user/projects/repo2"].mcpServers["remote-server"].command' "$os_dir/claude.json")
    assert_equal "$remote_server" "npx"

    # Local project should also be present
    local repo1_tools
    repo1_tools=$(jq -r '.projects["/home/user/projects/repo1"].allowedTools[0]' "$os_dir/claude.json")
    assert_equal "$repo1_tools" "Bash"
}
