#!/usr/bin/env bats

setup() {
    load '../test_helper'
    load_libs
    setup_test_environment
    source_script "install.sh"
}

teardown() {
    teardown_test_environment
}

@test "copy_configs_to_repo copies claude.json to repo" {
    install_fixture "claude_full.json" "$HOME/.claude.json"
    run copy_configs_to_repo
    assert_success

    local os_dir="$CONFIG_REPO/$(detect_os)"
    [[ -f "$os_dir/claude.json" ]]
}

@test "copy_configs_to_repo copies settings.json to repo" {
    install_fixture "settings.json" "$HOME/.claude/settings.json"
    run copy_configs_to_repo
    assert_success

    local os_dir="$CONFIG_REPO/$(detect_os)"
    [[ -f "$os_dir/settings.json" ]]
}

@test "copy_configs_to_repo creates CLAUDE.md template when missing" {
    # No CLAUDE.md in HOME
    run copy_configs_to_repo
    assert_success

    local os_dir="$CONFIG_REPO/$(detect_os)"
    [[ -f "$os_dir/CLAUDE.md" ]]
    assert_output --partial "Created CLAUDE.md template"
}

@test "copy_configs_to_repo copies existing CLAUDE.md instead of template" {
    install_fixture "CLAUDE.md" "$HOME/.claude/CLAUDE.md"
    run copy_configs_to_repo
    assert_success

    local os_dir="$CONFIG_REPO/$(detect_os)"
    [[ -f "$os_dir/CLAUDE.md" ]]
    assert_output --partial "Copied ~/.claude/CLAUDE.md"
}

@test "copy_configs_to_repo skips symlinked settings.json" {
    ln -sf "/some/target" "$HOME/.claude/settings.json"
    run copy_configs_to_repo
    assert_success

    local os_dir="$CONFIG_REPO/$(detect_os)"
    [[ ! -f "$os_dir/settings.json" ]]
}

@test "copy_configs_to_repo keeps repo settings.json when local is empty" {
    local os_dir="$CONFIG_REPO/$(detect_os)"
    mkdir -p "$os_dir"

    # Repo already has settings.json with content
    echo '{"permissions": {"allow": ["Bash", "Read"]}}' > "$os_dir/settings.json"

    # Local settings.json is empty
    echo '{}' > "$HOME/.claude/settings.json"

    run copy_configs_to_repo
    assert_success

    # Repo should still have the original content
    local perms
    perms=$(jq '.permissions.allow | length' "$os_dir/settings.json")
    [[ "$perms" == "2" ]]
    assert_output --partial "keeping repo version"
}

@test "copy_configs_to_repo copies skills directory with resolved symlinks" {
    # Create a real skill
    mkdir -p "$HOME/.claude/skills/real-skill"
    echo "# Real Skill" > "$HOME/.claude/skills/real-skill/SKILL.md"

    # Create a symlinked skill (simulating marketplace install)
    local agents_dir="$TEST_TEMP_DIR/agents/skills/market-skill"
    mkdir -p "$agents_dir"
    echo "# Market Skill" > "$agents_dir/SKILL.md"
    ln -s "$agents_dir" "$HOME/.claude/skills/market-skill"

    run copy_configs_to_repo
    assert_success

    local os_dir="$CONFIG_REPO/$(detect_os)"
    [[ -d "$os_dir/skills/real-skill" ]]
    [[ -d "$os_dir/skills/market-skill" ]]
    # Symlink should be resolved (regular directory in repo)
    [[ ! -L "$os_dir/skills/market-skill" ]]
    [[ -f "$os_dir/skills/market-skill/SKILL.md" ]]
    assert_output --partial "Copied skills directory"
}
