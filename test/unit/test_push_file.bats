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

@test "push_file copies file from source to dest" {
    local source="$TEST_TEMP_DIR/source.json"
    local dest="$TEST_TEMP_DIR/dest.json"
    echo '{"key": "value"}' > "$source"

    run push_file "$source" "$dest"
    assert_success
    [[ -f "$dest" ]]
    diff -q "$source" "$dest"
}

@test "push_file skips when source does not exist" {
    local dest="$TEST_TEMP_DIR/dest.json"

    run push_file "$TEST_TEMP_DIR/nonexistent" "$dest"
    assert_success
    [[ ! -f "$dest" ]]
}

@test "push_file skips when files are identical" {
    local source="$TEST_TEMP_DIR/source.json"
    local dest="$TEST_TEMP_DIR/dest.json"
    echo '{"key": "value"}' > "$source"
    echo '{"key": "value"}' > "$dest"

    # Record mtime before
    local mtime_before
    mtime_before=$(stat -c %Y "$dest" 2>/dev/null || stat -f %m "$dest")
    sleep 1

    run push_file "$source" "$dest"
    assert_success

    # mtime should not change (file was not overwritten)
    local mtime_after
    mtime_after=$(stat -c %Y "$dest" 2>/dev/null || stat -f %m "$dest")
    [[ "$mtime_before" == "$mtime_after" ]]
}

@test "push_file protects against empty overwrite" {
    local source="$TEST_TEMP_DIR/source.json"
    local dest="$TEST_TEMP_DIR/dest.json"
    echo '{}' > "$source"
    echo '{"key": "value"}' > "$dest"

    run push_file "$source" "$dest"
    assert_success

    # dest should still have original content
    local content
    content=$(cat "$dest")
    [[ "$content" == '{"key": "value"}' ]]
}

@test "push_file creates parent directories" {
    local source="$TEST_TEMP_DIR/source.json"
    local dest="$TEST_TEMP_DIR/nested/dir/dest.json"
    echo '{"key": "value"}' > "$source"

    run push_file "$source" "$dest"
    assert_success
    [[ -f "$dest" ]]
}
