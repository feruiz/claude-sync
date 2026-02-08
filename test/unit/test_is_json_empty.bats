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

@test "is_json_empty returns true for non-existent file" {
    run is_json_empty "/nonexistent/file.json"
    assert_success
}

@test "is_json_empty returns true for empty file" {
    local f="$TEST_TEMP_DIR/empty.json"
    touch "$f"
    run is_json_empty "$f"
    assert_success
}

@test "is_json_empty returns true for {}" {
    local f="$TEST_TEMP_DIR/brackets.json"
    echo '{}' > "$f"
    run is_json_empty "$f"
    assert_success
}

@test "is_json_empty returns true for { } with whitespace" {
    local f="$TEST_TEMP_DIR/spaces.json"
    printf '{ \n }\n' > "$f"
    run is_json_empty "$f"
    assert_success
}

@test "is_json_empty returns false for file with content" {
    local f="$TEST_TEMP_DIR/content.json"
    echo '{"permissions": {"allow": ["Read"]}}' > "$f"
    run is_json_empty "$f"
    assert_failure
}
