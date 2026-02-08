#!/usr/bin/env bats

setup() {
    load '../test_helper'
    load_libs
    setup_test_environment
    source_script "sync.sh"

    # Create OS directory with some content
    local os_dir
    os_dir=$(get_config_dir)
    mkdir -p "$os_dir"
    echo '{"test": true}' > "$os_dir/settings.json"
}

teardown() {
    teardown_test_environment
}

@test "create_backup creates a backup directory with timestamp" {
    run create_backup
    assert_success
    assert_output --partial "[OK]"
    assert_output --partial "Backup created"

    # Check backup directory exists
    local backups
    backups=$(ls -d "$CONFIG_REPO/backups"/backup_* 2>/dev/null)
    [[ -n "$backups" ]]
}

@test "create_backup copies config files to backup" {
    run create_backup
    assert_success

    local backup_dir
    backup_dir=$(ls -dt "$CONFIG_REPO/backups"/backup_* | head -n 1)
    [[ -f "$backup_dir/settings.json" ]]
}

@test "create_backup handles empty config directory" {
    local os_dir
    os_dir=$(get_config_dir)
    rm -f "$os_dir"/*

    run create_backup
    assert_success
}

@test "create_backup keeps only last 10 backups" {
    # Create 12 backups with different timestamps
    for i in $(seq 1 12); do
        mkdir -p "$CONFIG_REPO/backups/backup_20250101_$(printf '%06d' $i)"
    done

    run create_backup
    assert_success

    local count
    count=$(ls -d "$CONFIG_REPO/backups"/backup_* 2>/dev/null | wc -l)
    [[ "$count" -le 10 ]]
}
