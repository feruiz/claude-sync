#!/usr/bin/env bats

setup() {
    load '../test_helper'
    load_libs
    setup_test_environment
    source_script "sync.sh"

    init_config_git_repo

    # Create OS dir with a config file
    local os_dir="$CONFIG_REPO/$(detect_os)"
    mkdir -p "$os_dir"
    install_fixture "settings.json" "$os_dir/settings.json"
}

teardown() {
    teardown_test_environment
}

@test "cmd_undo restores from last backup" {
    local os_dir="$CONFIG_REPO/$(detect_os)"

    # Create a backup with the original settings
    create_backup

    # Ensure different timestamp so backup dirs don't collide
    sleep 1

    # Modify the current settings
    echo '{"modified": true}' > "$os_dir/settings.json"

    run cmd_undo
    assert_success
    assert_output --partial "Restored from backup"

    # settings.json should be restored (has original content)
    local content
    content=$(cat "$os_dir/settings.json")
    [[ "$content" != '{"modified": true}' ]]
}

@test "cmd_undo fails when no backups exist" {
    # Ensure no backups
    rm -rf "$CONFIG_REPO/backups"

    run cmd_undo
    assert_failure
    assert_output --partial "No backups found"
}

@test "cmd_undo creates backup of current state before restoring" {
    local os_dir="$CONFIG_REPO/$(detect_os)"

    # Create initial backup
    create_backup
    sleep 1

    # Modify config
    echo '{"modified": true}' > "$os_dir/settings.json"

    run cmd_undo
    assert_success

    # Should have at least 2 backups now (original + pre-undo)
    local backup_count
    backup_count=$(ls -d "$CONFIG_REPO/backups"/backup_* 2>/dev/null | wc -l)
    [[ "$backup_count" -ge 2 ]]
}
