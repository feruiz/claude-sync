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

@test "remove_symlinks removes commands symlink" {
    ln -s "/some/target" "$HOME/.claude/commands"
    run remove_symlinks
    assert_success
    [[ ! -L "$HOME/.claude/commands" ]]
}

@test "remove_symlinks does not touch regular files" {
    echo "real file" > "$HOME/.claude/settings.json"
    run remove_symlinks
    assert_success
    [[ -f "$HOME/.claude/settings.json" ]]
}

@test "remove_symlinks is a no-op when no symlinks exist" {
    run remove_symlinks
    assert_success
}
