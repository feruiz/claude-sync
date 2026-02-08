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

@test "extract_relevant_fields extracts autoUpdates and githubRepoPaths" {
    run extract_relevant_fields "$FIXTURES_DIR/claude_full.json"
    assert_success

    local result="$output"
    assert_equal "$(echo "$result" | jq -r '.autoUpdates')" "true"
    assert_equal "$(echo "$result" | jq -r '.githubRepoPaths | length')" "2"
}

@test "extract_relevant_fields extracts project allowedTools and mcpServers" {
    run extract_relevant_fields "$FIXTURES_DIR/claude_full.json"
    assert_success

    local result="$output"
    local tools
    tools=$(echo "$result" | jq -r '.projects["/home/user/projects/repo1"].allowedTools | length')
    assert_equal "$tools" "3"

    local server
    server=$(echo "$result" | jq -r '.projects["/home/user/projects/repo1"].mcpServers.myserver.command')
    assert_equal "$server" "npx"
}

@test "extract_relevant_fields strips telemetry fields" {
    run extract_relevant_fields "$FIXTURES_DIR/claude_full.json"
    assert_success

    local result="$output"
    assert_equal "$(echo "$result" | jq 'has("numStartups")')" "false"
    assert_equal "$(echo "$result" | jq 'has("tipsHistory")')" "false"
    assert_equal "$(echo "$result" | jq 'has("userID")')" "false"
    assert_equal "$(echo "$result" | jq 'has("lastSessionId")')" "false"
    assert_equal "$(echo "$result" | jq 'has("lastCost")')" "false"
    assert_equal "$(echo "$result" | jq 'has("skillUsage")')" "false"
}

@test "extract_relevant_fields strips project-level non-relevant fields" {
    run extract_relevant_fields "$FIXTURES_DIR/claude_full.json"
    assert_success

    local result="$output"
    local has_onboarding
    has_onboarding=$(echo "$result" | jq '.projects["/home/user/projects/repo1"] | has("hasCompletedProjectOnboarding")')
    assert_equal "$has_onboarding" "false"
}

@test "extract_relevant_fields handles empty JSON" {
    run extract_relevant_fields "$FIXTURES_DIR/claude_empty.json"
    assert_success

    local result="$output"
    assert_equal "$(echo "$result" | jq -r '.autoUpdates')" "null"
    assert_equal "$(echo "$result" | jq -r '.projects | length')" "0"
}

@test "extract_relevant_fields output matches expected relevant-only fixture" {
    local actual expected
    actual=$(extract_relevant_fields "$FIXTURES_DIR/claude_full.json" | jq -S .)
    expected=$(jq -S . "$FIXTURES_DIR/claude_relevant_only.json")
    assert_equal "$actual" "$expected"
}
