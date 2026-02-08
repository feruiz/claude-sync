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

@test "load_config uses default when no config file exists" {
    rm -f "$CONFIG_FILE"
    unset CONFIG_REPO
    load_config
    assert_equal "$CONFIG_REPO" "$DEFAULT_CONFIG_REPO"
}

@test "load_config reads CONFIG_REPO from config file" {
    echo 'CONFIG_REPO="/custom/path"' > "$CONFIG_FILE"
    unset CONFIG_REPO
    load_config
    assert_equal "$CONFIG_REPO" "/custom/path"
}

@test "load_config handles empty config file" {
    touch "$CONFIG_FILE"
    unset CONFIG_REPO
    load_config
    assert_equal "$CONFIG_REPO" "$DEFAULT_CONFIG_REPO"
}
