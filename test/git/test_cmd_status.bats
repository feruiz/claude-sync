#!/usr/bin/env bats

setup() {
    load '../test_helper'
    load_libs
    setup_test_environment
    source_script "sync.sh"

    init_config_git_repo
    init_remote_repo
}

teardown() {
    teardown_test_environment
}

@test "cmd_status shows clean when no changes" {
    run cmd_status
    assert_success
    assert_output --partial "No local changes"
    assert_output --partial "In sync with remote"
}

@test "cmd_status detects uncommitted changes" {
    echo "new content" > "$CONFIG_REPO/newfile.txt"
    run cmd_status
    assert_success
    assert_output --partial "Uncommitted changes"
}

@test "cmd_status detects ahead of remote" {
    echo "change" > "$CONFIG_REPO/newfile.txt"
    git -C "$CONFIG_REPO" add -A
    git -C "$CONFIG_REPO" commit -m "local change" 2>/dev/null

    run cmd_status
    assert_success
    assert_output --partial "Ahead of remote by 1 commit(s)"
}

@test "cmd_status detects behind remote" {
    # Make a change directly in the remote
    local clone_dir="$TEST_TEMP_DIR/clone"
    git clone "$REMOTE_REPO" "$clone_dir" 2>/dev/null
    git -C "$clone_dir" config user.email "test@test.com"
    git -C "$clone_dir" config user.name "Test User"
    echo "remote change" > "$clone_dir/remote_file.txt"
    git -C "$clone_dir" add -A
    git -C "$clone_dir" commit -m "remote change" 2>/dev/null
    git -C "$clone_dir" push origin main 2>/dev/null

    run cmd_status
    assert_success
    assert_output --partial "Behind remote by 1 commit(s)"
}

@test "cmd_status fails when repo does not exist" {
    CONFIG_REPO="$TEST_TEMP_DIR/nonexistent"
    run cmd_status
    assert_failure
    assert_output --partial "[ERROR]"
    assert_output --partial "Config repo not found"
}

@test "cmd_status fails when not a git repo" {
    CONFIG_REPO="$TEST_TEMP_DIR/not-git"
    mkdir -p "$CONFIG_REPO"
    run cmd_status
    assert_failure
    assert_output --partial "[ERROR]"
    assert_output --partial "Not a git repository"
}
