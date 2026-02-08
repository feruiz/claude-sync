#!/usr/bin/env bats

setup() {
    load '../test_helper'
    load_libs
    setup_test_environment
    source_script "sync.sh"

    init_config_git_repo
    init_remote_repo

    # Create OS dir with a config file
    local os_dir="$CONFIG_REPO/$(detect_os)"
    mkdir -p "$os_dir"
    install_fixture "settings.json" "$os_dir/settings.json"
    git -C "$CONFIG_REPO" add -A
    git -C "$CONFIG_REPO" commit -m "add settings" 2>/dev/null
    git -C "$CONFIG_REPO" push origin main 2>/dev/null
}

teardown() {
    teardown_test_environment
}

@test "cmd_pull pulls remote changes" {
    # Push a change from another clone
    local clone_dir="$TEST_TEMP_DIR/clone"
    git clone "$REMOTE_REPO" "$clone_dir" 2>/dev/null
    git -C "$clone_dir" config user.email "test@test.com"
    git -C "$clone_dir" config user.name "Test User"
    echo '{"updated": true}' > "$clone_dir/$(detect_os)/settings.json"
    git -C "$clone_dir" add -A
    git -C "$clone_dir" commit -m "remote update" 2>/dev/null
    git -C "$clone_dir" push origin main 2>/dev/null

    run cmd_pull
    assert_success
    assert_output --partial "Changes pulled successfully"
}

@test "cmd_pull creates backup before pulling" {
    run cmd_pull
    assert_success

    local backups
    backups=$(ls -d "$CONFIG_REPO/backups"/backup_* 2>/dev/null | wc -l)
    [[ "$backups" -ge 1 ]]
}

@test "cmd_pull merges claude.json from repo" {
    local os_dir="$CONFIG_REPO/$(detect_os)"

    # Put a claude.json in the repo
    install_fixture "claude_different.json" "$os_dir/claude.json"
    git -C "$CONFIG_REPO" add -A
    git -C "$CONFIG_REPO" commit -m "add claude.json" 2>/dev/null
    git -C "$CONFIG_REPO" push origin main 2>/dev/null

    # Put a local claude.json with telemetry
    install_fixture "claude_full.json" "$HOME/.claude.json"

    run cmd_pull
    assert_success

    # Local file should have merged relevant fields from repo
    local auto_updates
    auto_updates=$(jq -r '.autoUpdates' "$HOME/.claude.json")
    assert_equal "$auto_updates" "false"

    # But local telemetry should be preserved
    local num_startups
    num_startups=$(jq -r '.numStartups' "$HOME/.claude.json")
    assert_equal "$num_startups" "42"
}

@test "cmd_pull uses --rebase" {
    # Make a local commit
    echo "local" > "$CONFIG_REPO/local_file.txt"
    git -C "$CONFIG_REPO" add -A
    git -C "$CONFIG_REPO" commit -m "local" 2>/dev/null

    # Make a remote commit
    local clone_dir="$TEST_TEMP_DIR/clone"
    git clone "$REMOTE_REPO" "$clone_dir" 2>/dev/null
    git -C "$clone_dir" config user.email "test@test.com"
    git -C "$clone_dir" config user.name "Test User"
    echo "remote" > "$clone_dir/remote_file.txt"
    git -C "$clone_dir" add -A
    git -C "$clone_dir" commit -m "remote" 2>/dev/null
    git -C "$clone_dir" push origin main 2>/dev/null

    run cmd_pull
    assert_success

    # Should not have merge commits (rebase makes linear history)
    local merge_count
    merge_count=$(git -C "$CONFIG_REPO" log --merges --oneline | wc -l)
    assert_equal "$merge_count" "0"
}
