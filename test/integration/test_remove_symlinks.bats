#!/usr/bin/env bats

setup() {
    load '../test_helper'
    load_libs
    setup_test_environment
    source_script "uninstall.sh"
}

teardown() {
    teardown_test_environment
}

@test "remove_symlinks removes settings.json symlink" {
    ln -s "/some/target" "$HOME/.claude/settings.json"
    run remove_symlinks
    assert_success
    [[ ! -L "$HOME/.claude/settings.json" ]]
}

@test "remove_symlinks removes CLAUDE.md symlink" {
    ln -s "/some/target" "$HOME/.claude/CLAUDE.md"
    run remove_symlinks
    assert_success
    [[ ! -L "$HOME/.claude/CLAUDE.md" ]]
}

@test "remove_symlinks removes known_marketplaces.json symlink" {
    ln -s "/some/target" "$HOME/.claude/plugins/known_marketplaces.json"
    run remove_symlinks
    assert_success
    [[ ! -L "$HOME/.claude/plugins/known_marketplaces.json" ]]
}

@test "remove_symlinks removes commands symlink" {
    ln -s "/some/target" "$HOME/.claude/commands"
    run remove_symlinks
    assert_success
    [[ ! -L "$HOME/.claude/commands" ]]
}

@test "remove_symlinks does not remove regular files" {
    echo "real file" > "$HOME/.claude/settings.json"
    run remove_symlinks
    assert_success
    [[ -f "$HOME/.claude/settings.json" ]]
}
