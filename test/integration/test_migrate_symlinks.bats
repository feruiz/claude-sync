#!/usr/bin/env bats

setup() {
    load '../test_helper'
    load_libs
    setup_test_environment
    source_script "install.sh"

    # Create OS config dir with files (symlink targets)
    local os_dir="$CONFIG_REPO/$(detect_os)"
    mkdir -p "$os_dir/plugins"
    install_fixture "settings.json" "$os_dir/settings.json"
    install_fixture "CLAUDE.md" "$os_dir/CLAUDE.md"
    install_fixture "known_marketplaces.json" "$os_dir/plugins/known_marketplaces.json"
}

teardown() {
    teardown_test_environment
}

@test "migrate_symlinks converts symlink to regular file" {
    local os_dir="$CONFIG_REPO/$(detect_os)"

    # Create symlinks like the old install.sh would
    ln -sf "$os_dir/settings.json" "$HOME/.claude/settings.json"
    [[ -L "$HOME/.claude/settings.json" ]]

    run migrate_symlinks
    assert_success

    # Should no longer be a symlink
    [[ ! -L "$HOME/.claude/settings.json" ]]
    # Should still be a regular file with content
    [[ -f "$HOME/.claude/settings.json" ]]
    diff -q "$HOME/.claude/settings.json" "$os_dir/settings.json"
}

@test "migrate_symlinks handles all three files" {
    local os_dir="$CONFIG_REPO/$(detect_os)"

    ln -sf "$os_dir/settings.json" "$HOME/.claude/settings.json"
    ln -sf "$os_dir/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
    ln -sf "$os_dir/plugins/known_marketplaces.json" "$HOME/.claude/plugins/known_marketplaces.json"

    run migrate_symlinks
    assert_success

    [[ ! -L "$HOME/.claude/settings.json" ]]
    [[ ! -L "$HOME/.claude/CLAUDE.md" ]]
    [[ ! -L "$HOME/.claude/plugins/known_marketplaces.json" ]]
    [[ -f "$HOME/.claude/settings.json" ]]
    [[ -f "$HOME/.claude/CLAUDE.md" ]]
    [[ -f "$HOME/.claude/plugins/known_marketplaces.json" ]]
}

@test "migrate_symlinks is a no-op for regular files" {
    echo '{"existing": true}' > "$HOME/.claude/settings.json"

    run migrate_symlinks
    assert_success

    [[ -f "$HOME/.claude/settings.json" ]]
    local content
    content=$(cat "$HOME/.claude/settings.json")
    [[ "$content" == '{"existing": true}' ]]
}
