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

@test "apply_overrides with action=local is a noop" {
    local merged='{"projects":{"/proj":{"mcpServers":{"srv":{"cmd":"local"}}}}}'
    local original='{"projects":{"/proj":{"mcpServers":{"srv":{"cmd":"repo"}}}}}'
    local overrides='[{"project":"/proj","field":"mcpServers","key":"srv","action":"local"}]'

    run apply_overrides "$merged" "$original" "$overrides"
    assert_success
    assert_equal "$(echo "$output" | jq -r '.projects["/proj"].mcpServers.srv.cmd')" "local"
}

@test "apply_overrides with action=repo restores repo value" {
    local merged='{"projects":{"/proj":{"mcpServers":{"srv":{"cmd":"local"}}}}}'
    local original='{"projects":{"/proj":{"mcpServers":{"srv":{"cmd":"repo"}}}}}'
    local overrides='[{"project":"/proj","field":"mcpServers","key":"srv","action":"repo"}]'

    run apply_overrides "$merged" "$original" "$overrides"
    assert_success
    assert_equal "$(echo "$output" | jq -r '.projects["/proj"].mcpServers.srv.cmd')" "repo"
}

@test "apply_overrides with action=both keeps local and adds _repo suffix" {
    local merged='{"projects":{"/proj":{"mcpServers":{"srv":{"cmd":"local"}}}}}'
    local original='{"projects":{"/proj":{"mcpServers":{"srv":{"cmd":"repo"}}}}}'
    local overrides='[{"project":"/proj","field":"mcpServers","key":"srv","action":"both"}]'

    run apply_overrides "$merged" "$original" "$overrides"
    assert_success
    assert_equal "$(echo "$output" | jq -r '.projects["/proj"].mcpServers.srv.cmd')" "local"
    assert_equal "$(echo "$output" | jq -r '.projects["/proj"].mcpServers.srv_repo.cmd')" "repo"
}

@test "apply_overrides with empty overrides returns merged unchanged" {
    local merged='{"projects":{"/proj":{"mcpServers":{"srv":{"cmd":"local"}}}}}'
    local original='{"projects":{"/proj":{"mcpServers":{"srv":{"cmd":"repo"}}}}}'
    local overrides='[]'

    run apply_overrides "$merged" "$original" "$overrides"
    assert_success
    assert_equal "$(echo "$output" | jq -r '.projects["/proj"].mcpServers.srv.cmd')" "local"
}

@test "apply_overrides handles multiple overrides" {
    local merged='{"projects":{"/proj":{"mcpServers":{"s1":{"cmd":"l1"},"s2":{"cmd":"l2"}}}}}'
    local original='{"projects":{"/proj":{"mcpServers":{"s1":{"cmd":"r1"},"s2":{"cmd":"r2"}}}}}'
    local overrides='[
        {"project":"/proj","field":"mcpServers","key":"s1","action":"repo"},
        {"project":"/proj","field":"mcpServers","key":"s2","action":"both"}
    ]'

    run apply_overrides "$merged" "$original" "$overrides"
    assert_success
    # s1 should be restored to repo value
    assert_equal "$(echo "$output" | jq -r '.projects["/proj"].mcpServers.s1.cmd')" "r1"
    # s2 should keep local and add _repo
    assert_equal "$(echo "$output" | jq -r '.projects["/proj"].mcpServers.s2.cmd')" "l2"
    assert_equal "$(echo "$output" | jq -r '.projects["/proj"].mcpServers.s2_repo.cmd')" "r2"
}
