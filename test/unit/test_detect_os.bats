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

@test "detect_os returns linux when uname is Linux" {
    mock_uname "Linux"
    run detect_os
    assert_success
    assert_output "linux"
}

@test "detect_os returns macos when uname is Darwin" {
    mock_uname "Darwin"
    run detect_os
    assert_success
    assert_output "macos"
}

@test "detect_os returns unknown for unsupported OS" {
    mock_uname "FreeBSD"
    run detect_os
    assert_success
    assert_output "unknown"
}
