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

@test "merge_claude_json does nothing when repo file does not exist" {
    rm -f "$(get_config_dir)/claude.json"
    run merge_claude_json
    assert_success
}

@test "merge_claude_json copies repo file when local does not exist" {
    local os_dir
    os_dir=$(get_config_dir)
    install_fixture "claude_full.json" "$os_dir/claude.json"
    rm -f "$HOME/.claude.json"

    run merge_claude_json
    assert_success
    [[ -f "$HOME/.claude.json" ]]
}

@test "merge_claude_json preserves local telemetry fields" {
    local os_dir
    os_dir=$(get_config_dir)

    # Repo has different relevant fields
    install_fixture "claude_different.json" "$os_dir/claude.json"

    # Local file has its own telemetry
    install_fixture "claude_full.json" "$HOME/.claude.json"

    run merge_claude_json
    assert_success

    # Local telemetry should be preserved
    local num_startups
    num_startups=$(jq -r '.numStartups' "$HOME/.claude.json")
    assert_equal "$num_startups" "42"
}

@test "merge_claude_json updates relevant fields from repo" {
    local os_dir
    os_dir=$(get_config_dir)

    # Repo has autoUpdates=false
    install_fixture "claude_different.json" "$os_dir/claude.json"

    # Local has autoUpdates=true
    install_fixture "claude_full.json" "$HOME/.claude.json"

    run merge_claude_json
    assert_success

    # Relevant field should come from repo (merged on top)
    local auto_updates
    auto_updates=$(jq -r '.autoUpdates' "$HOME/.claude.json")
    assert_equal "$auto_updates" "false"
}

@test "merge_claude_json merges project-level relevant fields" {
    local os_dir
    os_dir=$(get_config_dir)

    # Repo has limited tools for repo1
    install_fixture "claude_different.json" "$os_dir/claude.json"

    # Local has full tools for repo1
    install_fixture "claude_full.json" "$HOME/.claude.json"

    run merge_claude_json
    assert_success

    # Repo's allowedTools should override local
    local tools_count
    tools_count=$(jq -r '.projects["/home/user/projects/repo1"].allowedTools | length' "$HOME/.claude.json")
    assert_equal "$tools_count" "1"
}
