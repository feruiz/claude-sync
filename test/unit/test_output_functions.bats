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

@test "info outputs with [INFO] prefix" {
    run info "test message"
    assert_success
    assert_output --partial "[INFO]"
    assert_output --partial "test message"
}

@test "success outputs with [OK] prefix" {
    run success "test message"
    assert_success
    assert_output --partial "[OK]"
    assert_output --partial "test message"
}

@test "warn outputs with [WARN] prefix" {
    run warn "test message"
    assert_success
    assert_output --partial "[WARN]"
    assert_output --partial "test message"
}

@test "error outputs with [ERROR] prefix" {
    run error "test message"
    assert_success
    assert_output --partial "[ERROR]"
    assert_output --partial "test message"
}
