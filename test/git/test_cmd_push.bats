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

@test "cmd_push commits and pushes changes" {
    local os_dir="$CONFIG_REPO/$(detect_os)"
    echo '{"new": true}' > "$os_dir/new_config.json"

    run cmd_push
    assert_success
    assert_output --partial "Changes pushed successfully"

    # Verify remote has the commit
    local remote_log
    remote_log=$(git -C "$CONFIG_REPO" log --oneline origin/main)
    [[ "$remote_log" == *"sync("* ]]
}

@test "cmd_push reports nothing to push when clean" {
    run cmd_push
    assert_success
    assert_output --partial "Nothing to push"
}

@test "cmd_push creates backup before pushing" {
    local os_dir="$CONFIG_REPO/$(detect_os)"
    echo '{"new": true}' > "$os_dir/another.json"

    run cmd_push
    assert_success

    # Check backup was created
    local backups
    backups=$(ls -d "$CONFIG_REPO/backups"/backup_* 2>/dev/null | wc -l)
    [[ "$backups" -ge 1 ]]
}

@test "cmd_push generates README.md" {
    local os_dir="$CONFIG_REPO/$(detect_os)"
    echo '{"new": true}' > "$os_dir/another.json"

    run cmd_push
    assert_success
    [[ -f "$CONFIG_REPO/README.md" ]]
}

@test "cmd_push ignores README-only changes" {
    # Generate a README (creates a change)
    generate_readme
    git -C "$CONFIG_REPO" add -A
    git -C "$CONFIG_REPO" commit -m "add readme" 2>/dev/null
    git -C "$CONFIG_REPO" push origin main 2>/dev/null

    # Now regenerate README with new timestamp — only README changes
    sleep 1
    generate_readme

    run cmd_push
    assert_success
    assert_output --partial "Nothing to push"
}

@test "cmd_push protects settings.json when local is empty" {
    local os_dir="$CONFIG_REPO/$(detect_os)"

    # Repo has settings.json with content (from setup)
    local original_content
    original_content=$(cat "$os_dir/settings.json")

    # Put empty settings.json in HOME (simulating Claude Code reset)
    echo '{}' > "$HOME/.claude/settings.json"

    # Also create another change so push has something to commit
    echo '{"extra": true}' > "$os_dir/extra.json"

    run cmd_push
    assert_success

    # settings.json in repo should still have original content (push_file skipped it)
    local current_content
    current_content=$(cat "$os_dir/settings.json")
    [[ "$current_content" == "$original_content" ]]
}

@test "cmd_push syncs claude.json before committing" {
    # Put a local claude.json with different relevant fields
    install_fixture "claude_different.json" "$HOME/.claude.json"

    run cmd_push
    assert_success

    # Verify claude.json was synced to repo
    local os_dir="$CONFIG_REPO/$(detect_os)"
    [[ -f "$os_dir/claude.json" ]]
}
