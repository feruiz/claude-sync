#!/usr/bin/env bats

setup() {
    load '../test_helper'
    load_libs
    setup_test_environment
    source_script "sync.sh"

    # Create a git repo to test get_branch
    init_config_git_repo
}

teardown() {
    teardown_test_environment
}

@test "get_branch returns main for default branch" {
    cd "$CONFIG_REPO"
    run get_branch
    assert_success
    assert_output "main"
}

@test "get_branch returns correct name for custom branch" {
    cd "$CONFIG_REPO"
    git checkout -b my-feature 2>/dev/null
    run get_branch
    assert_success
    assert_output "my-feature"
}
