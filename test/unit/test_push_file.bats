#!/usr/bin/env bats

setup() {
    load '../test_helper'
    load_libs
    setup_test_environment
    source_script "sync.sh"
}

teardown() {
    teardown_test_environment
}

@test "push_file copies file from source to dest" {
    local source="$TEST_TEMP_DIR/source.json"
    local dest="$TEST_TEMP_DIR/dest.json"
    echo '{"key": "value"}' > "$source"

    run push_file "$source" "$dest"
    assert_success
    [[ -f "$dest" ]]
    diff -q "$source" "$dest"
}

@test "push_file skips when source does not exist" {
    local dest="$TEST_TEMP_DIR/dest.json"

    run push_file "$TEST_TEMP_DIR/nonexistent" "$dest"
    assert_success
    [[ ! -f "$dest" ]]
}

@test "push_file skips when files are identical" {
    local source="$TEST_TEMP_DIR/source.json"
    local dest="$TEST_TEMP_DIR/dest.json"
    echo '{"key": "value"}' > "$source"
    echo '{"key": "value"}' > "$dest"

    # Record mtime before
    local mtime_before
    mtime_before=$(stat -c %Y "$dest" 2>/dev/null || stat -f %m "$dest")
    sleep 1

    run push_file "$source" "$dest"
    assert_success

    # mtime should not change (file was not overwritten)
    local mtime_after
    mtime_after=$(stat -c %Y "$dest" 2>/dev/null || stat -f %m "$dest")
    [[ "$mtime_before" == "$mtime_after" ]]
}

@test "push_file protects against empty overwrite" {
    local source="$TEST_TEMP_DIR/source.json"
    local dest="$TEST_TEMP_DIR/dest.json"
    echo '{}' > "$source"
    echo '{"key": "value"}' > "$dest"

    run push_file "$source" "$dest"
    assert_success

    # dest should still have original content
    local content
    content=$(cat "$dest")
    [[ "$content" == '{"key": "value"}' ]]
}

@test "push_file creates parent directories" {
    local source="$TEST_TEMP_DIR/source.json"
    local dest="$TEST_TEMP_DIR/nested/dir/dest.json"
    echo '{"key": "value"}' > "$source"

    run push_file "$source" "$dest"
    assert_success
    [[ -f "$dest" ]]
}

# --- lastUpdated filtering for JSON files ---

@test "push_file skips JSON when only lastUpdated changed" {
    local source="$TEST_TEMP_DIR/source.json"
    local dest="$TEST_TEMP_DIR/dest.json"

    cat > "$dest" << 'EOF'
{
  "marketplace-a": {
    "source": {"source": "github", "repo": "org/repo"},
    "installLocation": "/home/user/.claude/plugins/marketplaces/a",
    "lastUpdated": "2026-01-01T00:00:00.000Z"
  }
}
EOF

    cat > "$source" << 'EOF'
{
  "marketplace-a": {
    "source": {"source": "github", "repo": "org/repo"},
    "installLocation": "/home/user/.claude/plugins/marketplaces/a",
    "lastUpdated": "2026-02-08T19:40:27.380Z"
  }
}
EOF

    local mtime_before
    mtime_before=$(stat -c %Y "$dest" 2>/dev/null || stat -f %m "$dest")
    sleep 1

    run push_file "$source" "$dest"
    assert_success

    local mtime_after
    mtime_after=$(stat -c %Y "$dest" 2>/dev/null || stat -f %m "$dest")
    [[ "$mtime_before" == "$mtime_after" ]]
}

@test "push_file skips JSON when multiple entries have only lastUpdated changes" {
    local source="$TEST_TEMP_DIR/source.json"
    local dest="$TEST_TEMP_DIR/dest.json"

    cat > "$dest" << 'EOF'
{
  "marketplace-a": {
    "source": {"source": "github", "repo": "org/repo-a"},
    "lastUpdated": "2026-01-01T00:00:00.000Z"
  },
  "marketplace-b": {
    "source": {"source": "github", "repo": "org/repo-b"},
    "lastUpdated": "2026-01-01T00:00:00.000Z"
  }
}
EOF

    cat > "$source" << 'EOF'
{
  "marketplace-a": {
    "source": {"source": "github", "repo": "org/repo-a"},
    "lastUpdated": "2026-02-08T10:00:00.000Z"
  },
  "marketplace-b": {
    "source": {"source": "github", "repo": "org/repo-b"},
    "lastUpdated": "2026-02-08T11:00:00.000Z"
  }
}
EOF

    local mtime_before
    mtime_before=$(stat -c %Y "$dest" 2>/dev/null || stat -f %m "$dest")
    sleep 1

    run push_file "$source" "$dest"
    assert_success

    local mtime_after
    mtime_after=$(stat -c %Y "$dest" 2>/dev/null || stat -f %m "$dest")
    [[ "$mtime_before" == "$mtime_after" ]]
}

@test "push_file copies JSON when meaningful field changes alongside lastUpdated" {
    local source="$TEST_TEMP_DIR/source.json"
    local dest="$TEST_TEMP_DIR/dest.json"

    cat > "$dest" << 'EOF'
{
  "marketplace-a": {
    "source": {"source": "github", "repo": "org/repo"},
    "installLocation": "/old/path",
    "lastUpdated": "2026-01-01T00:00:00.000Z"
  }
}
EOF

    cat > "$source" << 'EOF'
{
  "marketplace-a": {
    "source": {"source": "github", "repo": "org/repo"},
    "installLocation": "/new/path",
    "lastUpdated": "2026-02-08T19:40:27.380Z"
  }
}
EOF

    run push_file "$source" "$dest"
    assert_success

    run jq -r '.["marketplace-a"].installLocation' "$dest"
    assert_output "/new/path"
}

@test "push_file copies JSON when a new entry is added (with lastUpdated)" {
    local source="$TEST_TEMP_DIR/source.json"
    local dest="$TEST_TEMP_DIR/dest.json"

    cat > "$dest" << 'EOF'
{
  "marketplace-a": {
    "source": {"source": "github", "repo": "org/repo-a"},
    "lastUpdated": "2026-01-01T00:00:00.000Z"
  }
}
EOF

    cat > "$source" << 'EOF'
{
  "marketplace-a": {
    "source": {"source": "github", "repo": "org/repo-a"},
    "lastUpdated": "2026-02-08T10:00:00.000Z"
  },
  "marketplace-b": {
    "source": {"source": "github", "repo": "org/repo-b"},
    "lastUpdated": "2026-02-08T11:00:00.000Z"
  }
}
EOF

    run push_file "$source" "$dest"
    assert_success

    run jq -r 'keys | length' "$dest"
    assert_output "2"
}

@test "push_file still works normally for non-JSON files" {
    local source="$TEST_TEMP_DIR/source.md"
    local dest="$TEST_TEMP_DIR/dest.md"
    echo "# New content" > "$source"
    echo "# Old content" > "$dest"

    run push_file "$source" "$dest"
    assert_success

    local content
    content=$(cat "$dest")
    [[ "$content" == "# New content" ]]
}

# --- trailing newline differences ---

@test "push_file skips when only trailing newline differs (source has, dest missing)" {
    local source="$TEST_TEMP_DIR/source.json"
    local dest="$TEST_TEMP_DIR/dest.json"

    printf '{"key": "value"}\n' > "$source"
    printf '{"key": "value"}' > "$dest"

    local mtime_before
    mtime_before=$(stat -c %Y "$dest" 2>/dev/null || stat -f %m "$dest")
    sleep 1

    run push_file "$source" "$dest"
    assert_success

    local mtime_after
    mtime_after=$(stat -c %Y "$dest" 2>/dev/null || stat -f %m "$dest")
    [[ "$mtime_before" == "$mtime_after" ]]
}

@test "push_file skips when only trailing newline differs (dest has, source missing)" {
    local source="$TEST_TEMP_DIR/source.md"
    local dest="$TEST_TEMP_DIR/dest.md"

    printf '# Title' > "$source"
    printf '# Title\n' > "$dest"

    local mtime_before
    mtime_before=$(stat -c %Y "$dest" 2>/dev/null || stat -f %m "$dest")
    sleep 1

    run push_file "$source" "$dest"
    assert_success

    local mtime_after
    mtime_after=$(stat -c %Y "$dest" 2>/dev/null || stat -f %m "$dest")
    [[ "$mtime_before" == "$mtime_after" ]]
}

@test "push_file skips when only extra blank lines at end differ" {
    local source="$TEST_TEMP_DIR/source.md"
    local dest="$TEST_TEMP_DIR/dest.md"

    printf '# Title\n\nContent\n' > "$source"
    printf '# Title\n\nContent\n\n' > "$dest"

    local mtime_before
    mtime_before=$(stat -c %Y "$dest" 2>/dev/null || stat -f %m "$dest")
    sleep 1

    run push_file "$source" "$dest"
    assert_success

    local mtime_after
    mtime_after=$(stat -c %Y "$dest" 2>/dev/null || stat -f %m "$dest")
    [[ "$mtime_before" == "$mtime_after" ]]
}

@test "push_file copies when content differs (not just trailing newline)" {
    local source="$TEST_TEMP_DIR/source.md"
    local dest="$TEST_TEMP_DIR/dest.md"

    printf '# New Title\n' > "$source"
    printf '# Old Title' > "$dest"

    run push_file "$source" "$dest"
    assert_success

    local content
    content=$(cat "$dest")
    [[ "$content" == "# New Title" ]]
}

@test "push_file handles lastUpdated at top-level JSON" {
    local source="$TEST_TEMP_DIR/source.json"
    local dest="$TEST_TEMP_DIR/dest.json"

    cat > "$dest" << 'EOF'
{
  "key": "value",
  "lastUpdated": "2026-01-01T00:00:00.000Z"
}
EOF

    cat > "$source" << 'EOF'
{
  "key": "value",
  "lastUpdated": "2026-02-08T19:40:27.380Z"
}
EOF

    local mtime_before
    mtime_before=$(stat -c %Y "$dest" 2>/dev/null || stat -f %m "$dest")
    sleep 1

    run push_file "$source" "$dest"
    assert_success

    local mtime_after
    mtime_after=$(stat -c %Y "$dest" 2>/dev/null || stat -f %m "$dest")
    [[ "$mtime_before" == "$mtime_after" ]]
}
