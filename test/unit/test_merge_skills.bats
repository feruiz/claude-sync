#!/usr/bin/env bats

setup() {
    load '../test_helper'
    load_libs
    setup_test_environment
    source_script "sync.sh"

    # Create OS directory in config repo
    local os_dir
    os_dir=$(get_config_dir)
    mkdir -p "$os_dir"
}

teardown() {
    teardown_test_environment
}

@test "merge_skills does nothing when repo has no skills directory" {
    local os_dir
    os_dir=$(get_config_dir)
    rm -rf "$os_dir/skills"

    run merge_skills
    assert_success

    [[ ! -d "$HOME/.claude/skills" ]]
}

@test "merge_skills copies skill directories from repo to local" {
    local os_dir
    os_dir=$(get_config_dir)
    mkdir -p "$os_dir/skills/my-skill"
    echo "# My Skill" > "$os_dir/skills/my-skill/SKILL.md"

    run merge_skills
    assert_success

    [[ -d "$HOME/.claude/skills/my-skill" ]]
    [[ -f "$HOME/.claude/skills/my-skill/SKILL.md" ]]
}

@test "merge_skills does not remove local skills absent from repo" {
    local os_dir
    os_dir=$(get_config_dir)

    # Repo has skill-a
    mkdir -p "$os_dir/skills/skill-a"
    echo "# A" > "$os_dir/skills/skill-a/SKILL.md"

    # Local has skill-b (not in repo)
    mkdir -p "$HOME/.claude/skills/skill-b"
    echo "# B" > "$HOME/.claude/skills/skill-b/SKILL.md"

    run merge_skills
    assert_success

    # Both should exist
    [[ -d "$HOME/.claude/skills/skill-a" ]]
    [[ -d "$HOME/.claude/skills/skill-b" ]]
}

@test "merge_skills overwrites existing local skill with repo version" {
    local os_dir
    os_dir=$(get_config_dir)

    # Repo has updated version
    mkdir -p "$os_dir/skills/my-skill"
    echo "# Updated" > "$os_dir/skills/my-skill/SKILL.md"

    # Local has old version
    mkdir -p "$HOME/.claude/skills/my-skill"
    echo "# Old" > "$HOME/.claude/skills/my-skill/SKILL.md"

    run merge_skills
    assert_success

    local content
    content=$(cat "$HOME/.claude/skills/my-skill/SKILL.md")
    [[ "$content" == "# Updated" ]]
}

@test "merge_skills creates skills directory if it does not exist locally" {
    local os_dir
    os_dir=$(get_config_dir)
    mkdir -p "$os_dir/skills/new-skill"
    echo "# New" > "$os_dir/skills/new-skill/SKILL.md"

    rm -rf "$HOME/.claude/skills"

    run merge_skills
    assert_success

    [[ -d "$HOME/.claude/skills/new-skill" ]]
    [[ -f "$HOME/.claude/skills/new-skill/SKILL.md" ]]
}
