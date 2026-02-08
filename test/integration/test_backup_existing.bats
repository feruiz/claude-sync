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

@test "backup_existing backs up regular claude.json" {
    echo '{"test": true}' > "$HOME/.claude.json"
    run backup_existing
    assert_success

    local backup_dir
    backup_dir=$(ls -d "$CONFIG_REPO/backups"/pre_install_* 2>/dev/null | head -n 1)
    [[ -f "$backup_dir/.claude.json" ]]
}

@test "backup_existing backs up regular settings.json" {
    install_fixture "settings.json" "$HOME/.claude/settings.json"
    run backup_existing
    assert_success

    local backup_dir
    backup_dir=$(ls -d "$CONFIG_REPO/backups"/pre_install_* 2>/dev/null | head -n 1)
    [[ -f "$backup_dir/settings.json" ]]
}

@test "backup_existing skips symlinks" {
    ln -s "/some/target" "$HOME/.claude/settings.json"
    run backup_existing
    assert_success

    # No backup should contain settings.json (it was a symlink)
    local backup_dir
    backup_dir=$(ls -d "$CONFIG_REPO/backups"/pre_install_* 2>/dev/null | head -n 1)
    [[ -z "$backup_dir" ]] || [[ ! -f "$backup_dir/settings.json" ]]
}

@test "backup_existing backs up commands directory" {
    mkdir -p "$HOME/.claude/commands"
    echo '{}' > "$HOME/.claude/commands/test.json"
    run backup_existing
    assert_success

    local backup_dir
    backup_dir=$(ls -d "$CONFIG_REPO/backups"/pre_install_* 2>/dev/null | head -n 1)
    [[ -d "$backup_dir/commands" ]]
}

@test "backup_existing backs up skills directory" {
    mkdir -p "$HOME/.claude/skills/my-skill"
    echo '# My Skill' > "$HOME/.claude/skills/my-skill/SKILL.md"
    run backup_existing
    assert_success

    local backup_dir
    backup_dir=$(ls -d "$CONFIG_REPO/backups"/pre_install_* 2>/dev/null | head -n 1)
    [[ -d "$backup_dir/skills" ]]
    [[ -f "$backup_dir/skills/my-skill/SKILL.md" ]]
}

@test "backup_existing skips skills directory when it is a symlink" {
    ln -s "/some/target" "$HOME/.claude/skills"
    run backup_existing
    assert_success

    local backup_dir
    backup_dir=$(ls -d "$CONFIG_REPO/backups"/pre_install_* 2>/dev/null | head -n 1)
    [[ -z "$backup_dir" ]] || [[ ! -d "$backup_dir/skills" ]]
}
