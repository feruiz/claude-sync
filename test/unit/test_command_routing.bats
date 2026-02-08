#!/usr/bin/env bats

setup() {
    load '../test_helper'
    load_libs
    setup_test_environment
    source_script "sync.sh"

    # Override command functions with stubs
    cmd_status()  { echo "CALLED_STATUS"; }
    cmd_push()    { echo "CALLED_PUSH"; }
    cmd_pull()    { echo "CALLED_PULL"; }
    cmd_backup()  { echo "CALLED_BACKUP"; }
    cmd_undo()    { echo "CALLED_UNDO"; }
    cmd_backups() { echo "CALLED_BACKUPS"; }
    cmd_help()    { echo "CALLED_HELP"; }
}

teardown() {
    teardown_test_environment
}

@test "main routes 'status' to cmd_status" {
    run main status
    assert_success
    assert_output --partial "CALLED_STATUS"
}

@test "main routes 'push' to cmd_push" {
    run main push
    assert_success
    assert_output --partial "CALLED_PUSH"
}

@test "main routes 'pull' to cmd_pull" {
    run main pull
    assert_success
    assert_output --partial "CALLED_PULL"
}

@test "main routes 'backup' to cmd_backup" {
    run main backup
    assert_success
    assert_output --partial "CALLED_BACKUP"
}

@test "main routes 'undo' to cmd_undo" {
    run main undo
    assert_success
    assert_output --partial "CALLED_UNDO"
}

@test "main routes 'backups' to cmd_backups" {
    run main backups
    assert_success
    assert_output --partial "CALLED_BACKUPS"
}

@test "main routes 'help' to cmd_help" {
    run main help
    assert_success
    assert_output --partial "CALLED_HELP"
}

@test "main defaults to help when no argument" {
    run main
    assert_success
    assert_output --partial "CALLED_HELP"
}

@test "main shows error for unknown command" {
    run main nonexistent
    assert_failure
    assert_output --partial "[ERROR]"
    assert_output --partial "Unknown command: nonexistent"
}
