#!/usr/bin/env bats

setup() {
    load '../test_helper'
    load_libs
    setup_test_environment
    source_script "sync.sh"
}

teardown() {
    teardown_test_environment
}

@test "get_config_dir returns CONFIG_REPO/linux on Linux" {
    mock_uname "Linux"
    run get_config_dir
    assert_success
    assert_output "$CONFIG_REPO/linux"
}

@test "get_config_dir returns CONFIG_REPO/macos on macOS" {
    mock_uname "Darwin"
    run get_config_dir
    assert_success
    assert_output "$CONFIG_REPO/macos"
}
