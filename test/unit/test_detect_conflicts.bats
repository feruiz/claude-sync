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

@test "detect_conflicts returns empty array when no conflicts" {
    local local_json='{"projects":{"/proj":{"mcpServers":{"srv":{"cmd":"a"}}}}}'
    local repo_json='{"projects":{"/proj":{"mcpServers":{"srv":{"cmd":"a"}}}}}'

    run detect_conflicts "$local_json" "$repo_json"
    assert_success
    assert_equal "$(echo "$output" | jq 'length')" "0"
}

@test "detect_conflicts detects mcpServers conflict with same key different value" {
    local local_json='{"projects":{"/proj":{"mcpServers":{"srv":{"cmd":"local"}}}}}'
    local repo_json='{"projects":{"/proj":{"mcpServers":{"srv":{"cmd":"repo"}}}}}'

    run detect_conflicts "$local_json" "$repo_json"
    assert_success
    assert_equal "$(echo "$output" | jq 'length')" "1"
    assert_equal "$(echo "$output" | jq -r '.[0].project')" "/proj"
    assert_equal "$(echo "$output" | jq -r '.[0].field')" "mcpServers"
    assert_equal "$(echo "$output" | jq -r '.[0].key')" "srv"
}

@test "detect_conflicts ignores keys only in local" {
    local local_json='{"projects":{"/proj":{"mcpServers":{"srv":{"cmd":"local"}}}}}'
    local repo_json='{"projects":{"/proj":{"mcpServers":{}}}}'

    run detect_conflicts "$local_json" "$repo_json"
    assert_success
    assert_equal "$(echo "$output" | jq 'length')" "0"
}

@test "detect_conflicts ignores keys only in repo" {
    local local_json='{"projects":{"/proj":{"mcpServers":{}}}}'
    local repo_json='{"projects":{"/proj":{"mcpServers":{"srv":{"cmd":"repo"}}}}}'

    run detect_conflicts "$local_json" "$repo_json"
    assert_success
    assert_equal "$(echo "$output" | jq 'length')" "0"
}

@test "detect_conflicts handles multiple projects with conflicts" {
    local local_json='{"projects":{"/p1":{"mcpServers":{"s":{"v":"l"}}},"/p2":{"mcpServers":{"s":{"v":"l"}}}}}'
    local repo_json='{"projects":{"/p1":{"mcpServers":{"s":{"v":"r"}}},"/p2":{"mcpServers":{"s":{"v":"r"}}}}}'

    run detect_conflicts "$local_json" "$repo_json"
    assert_success
    assert_equal "$(echo "$output" | jq 'length')" "2"
}

@test "detect_conflicts handles missing projects field" {
    local local_json='{}'
    local repo_json='{}'

    run detect_conflicts "$local_json" "$repo_json"
    assert_success
    assert_equal "$(echo "$output" | jq 'length')" "0"
}

@test "detect_conflicts handles project without mcpServers" {
    local local_json='{"projects":{"/proj":{"allowedTools":["Bash"]}}}'
    local repo_json='{"projects":{"/proj":{"allowedTools":["Read"]}}}'

    run detect_conflicts "$local_json" "$repo_json"
    assert_success
    assert_equal "$(echo "$output" | jq 'length')" "0"
}
