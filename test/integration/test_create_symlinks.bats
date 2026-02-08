#!/usr/bin/env bats

setup() {
    load '../test_helper'
    load_libs
    setup_test_environment
    source_script "install.sh"

    # Create OS config dir with files
    local os_dir="$CONFIG_REPO/$(detect_os)"
    mkdir -p "$os_dir/plugins" "$os_dir/commands"
    install_fixture "settings.json" "$os_dir/settings.json"
    install_fixture "CLAUDE.md" "$os_dir/CLAUDE.md"
    install_fixture "known_marketplaces.json" "$os_dir/plugins/known_marketplaces.json"
    echo '{"cmd": true}' > "$os_dir/commands/test.json"
}

teardown() {
    teardown_test_environment
}

@test "create_symlinks creates symlink for settings.json" {
    run create_symlinks
    assert_success
    [[ -L "$HOME/.claude/settings.json" ]]
}

@test "create_symlinks creates symlink for CLAUDE.md" {
    run create_symlinks
    assert_success
    [[ -L "$HOME/.claude/CLAUDE.md" ]]
}

@test "create_symlinks creates symlink for known_marketplaces.json" {
    run create_symlinks
    assert_success
    [[ -L "$HOME/.claude/plugins/known_marketplaces.json" ]]
}

@test "create_symlinks creates symlink for commands directory" {
    run create_symlinks
    assert_success
    [[ -L "$HOME/.claude/commands" ]]
}

@test "create_symlinks points to correct target" {
    create_symlinks

    local os_dir="$CONFIG_REPO/$(detect_os)"
    local target
    target=$(readlink "$HOME/.claude/settings.json")
    assert_equal "$target" "$os_dir/settings.json"
}

@test "create_symlinks replaces existing regular file" {
    echo "old content" > "$HOME/.claude/settings.json"
    run create_symlinks
    assert_success
    [[ -L "$HOME/.claude/settings.json" ]]
}

@test "create_symlinks skips missing files in repo" {
    local os_dir="$CONFIG_REPO/$(detect_os)"
    rm -f "$os_dir/settings.json"

    run create_symlinks
    assert_success
    [[ ! -L "$HOME/.claude/settings.json" ]]
}
