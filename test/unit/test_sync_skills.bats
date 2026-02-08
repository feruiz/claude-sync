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

@test "sync_skills does nothing when skills directory does not exist" {
    rm -rf "$HOME/.claude/skills"
    run sync_skills
    assert_success

    local os_dir
    os_dir=$(get_config_dir)
    [[ ! -d "$os_dir/skills" ]]
}

@test "sync_skills copies skill directories to repo" {
    mkdir -p "$HOME/.claude/skills/my-skill"
    echo "# My Skill" > "$HOME/.claude/skills/my-skill/SKILL.md"

    run sync_skills
    assert_success

    local os_dir
    os_dir=$(get_config_dir)
    [[ -d "$os_dir/skills/my-skill" ]]
    [[ -f "$os_dir/skills/my-skill/SKILL.md" ]]
}

@test "sync_skills resolves symlinks (stores actual content)" {
    # Create a real skill directory elsewhere (simulating ~/.agents/skills/)
    local agents_dir="$TEST_TEMP_DIR/agents/skills/marketplace-skill"
    mkdir -p "$agents_dir"
    echo "# Marketplace Skill" > "$agents_dir/SKILL.md"
    mkdir -p "$agents_dir/rules"
    echo "rule1" > "$agents_dir/rules/rule1.md"

    # Create symlink in skills directory
    mkdir -p "$HOME/.claude/skills"
    ln -s "$agents_dir" "$HOME/.claude/skills/marketplace-skill"

    run sync_skills
    assert_success

    local os_dir
    os_dir=$(get_config_dir)
    # Should be a regular directory in repo, not a symlink
    [[ -d "$os_dir/skills/marketplace-skill" ]]
    [[ ! -L "$os_dir/skills/marketplace-skill" ]]
    [[ -f "$os_dir/skills/marketplace-skill/SKILL.md" ]]
    [[ -f "$os_dir/skills/marketplace-skill/rules/rule1.md" ]]
}

@test "sync_skills removes skills from repo that no longer exist locally" {
    local os_dir
    os_dir=$(get_config_dir)

    # Skill exists in repo but not locally
    mkdir -p "$os_dir/skills/old-skill"
    echo "# Old" > "$os_dir/skills/old-skill/SKILL.md"

    # Create skills dir locally (empty, no old-skill)
    mkdir -p "$HOME/.claude/skills"

    run sync_skills
    assert_success

    [[ ! -d "$os_dir/skills/old-skill" ]]
}

@test "sync_skills copies multiple skills" {
    mkdir -p "$HOME/.claude/skills/skill-a"
    echo "# A" > "$HOME/.claude/skills/skill-a/SKILL.md"

    mkdir -p "$HOME/.claude/skills/skill-b"
    echo "# B" > "$HOME/.claude/skills/skill-b/SKILL.md"
    echo "ref" > "$HOME/.claude/skills/skill-b/LICENSE.txt"

    run sync_skills
    assert_success

    local os_dir
    os_dir=$(get_config_dir)
    [[ -d "$os_dir/skills/skill-a" ]]
    [[ -d "$os_dir/skills/skill-b" ]]
    [[ -f "$os_dir/skills/skill-b/LICENSE.txt" ]]
}

@test "sync_skills overwrites existing skill in repo with updated local" {
    local os_dir
    os_dir=$(get_config_dir)

    # Old version in repo
    mkdir -p "$os_dir/skills/my-skill"
    echo "# Old Version" > "$os_dir/skills/my-skill/SKILL.md"

    # Updated version locally
    mkdir -p "$HOME/.claude/skills/my-skill"
    echo "# New Version" > "$HOME/.claude/skills/my-skill/SKILL.md"

    run sync_skills
    assert_success

    local content
    content=$(cat "$os_dir/skills/my-skill/SKILL.md")
    [[ "$content" == "# New Version" ]]
}
