#!/usr/bin/env bats

setup() {
    load '../test_helper'
    load_libs
    setup_test_environment
    source_script "sync.sh"

    # Set up a git repo with some config files
    init_config_git_repo

    local os_dir="$CONFIG_REPO/$(detect_os)"
    mkdir -p "$os_dir/plugins"
    install_fixture "settings.json" "$os_dir/settings.json"
    install_fixture "CLAUDE.md" "$os_dir/CLAUDE.md"

    # Stage and commit the files
    git -C "$CONFIG_REPO" add -A
    git -C "$CONFIG_REPO" commit -m "add configs" 2>/dev/null
}

teardown() {
    teardown_test_environment
}

@test "generate_readme creates README.md" {
    run generate_readme
    assert_success
    [[ -f "$CONFIG_REPO/README.md" ]]
}

@test "generate_readme contains header" {
    generate_readme
    run cat "$CONFIG_REPO/README.md"
    assert_output --partial "# Claude Code Configuration"
}

@test "generate_readme contains last updated timestamp" {
    generate_readme
    run cat "$CONFIG_REPO/README.md"
    assert_output --partial "last updated:"
}

@test "generate_readme includes settings.json stats" {
    generate_readme
    run cat "$CONFIG_REPO/README.md"
    assert_output --partial "settings.json"
    assert_output --partial "allowed commands"
}

@test "generate_readme includes CLAUDE.md stats" {
    generate_readme
    run cat "$CONFIG_REPO/README.md"
    assert_output --partial "CLAUDE.md"
    assert_output --partial "lines of custom instructions"
}

@test "generate_readme does not overwrite when only timestamp changes" {
    generate_readme

    local mtime_before
    mtime_before=$(stat -c %Y "$CONFIG_REPO/README.md" 2>/dev/null || stat -f %m "$CONFIG_REPO/README.md")
    sleep 1

    # Regenerate — only the timestamp should differ
    generate_readme

    local mtime_after
    mtime_after=$(stat -c %Y "$CONFIG_REPO/README.md" 2>/dev/null || stat -f %m "$CONFIG_REPO/README.md")
    [[ "$mtime_before" == "$mtime_after" ]]
}

@test "generate_readme overwrites when stats change" {
    generate_readme

    local mtime_before
    mtime_before=$(stat -c %Y "$CONFIG_REPO/README.md" 2>/dev/null || stat -f %m "$CONFIG_REPO/README.md")
    sleep 1

    # Add a new config file so stats change
    local os_dir="$CONFIG_REPO/$(detect_os)"
    mkdir -p "$os_dir/commands"
    echo "test command" > "$os_dir/commands/test.md"
    git -C "$CONFIG_REPO" add -A
    git -C "$CONFIG_REPO" commit -m "add command" 2>/dev/null

    generate_readme

    local mtime_after
    mtime_after=$(stat -c %Y "$CONFIG_REPO/README.md" 2>/dev/null || stat -f %m "$CONFIG_REPO/README.md")
    [[ "$mtime_before" != "$mtime_after" ]]
}
