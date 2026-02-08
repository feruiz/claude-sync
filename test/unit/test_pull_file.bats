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

@test "pull_file copies file from source to dest" {
    local source="$TEST_TEMP_DIR/source.json"
    local dest="$TEST_TEMP_DIR/dest.json"
    echo '{"key": "value"}' > "$source"

    run pull_file "$source" "$dest"
    assert_success
    [[ -f "$dest" ]]
    diff -q "$source" "$dest"
}

@test "pull_file skips when source does not exist" {
    local dest="$TEST_TEMP_DIR/dest.json"

    run pull_file "$TEST_TEMP_DIR/nonexistent" "$dest"
    assert_success
    [[ ! -f "$dest" ]]
}

@test "pull_file creates parent directories" {
    local source="$TEST_TEMP_DIR/source.json"
    local dest="$TEST_TEMP_DIR/nested/dir/dest.json"
    echo '{"key": "value"}' > "$source"

    run pull_file "$source" "$dest"
    assert_success
    [[ -f "$dest" ]]
}
