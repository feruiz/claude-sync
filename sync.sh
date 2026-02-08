#!/bin/bash
# claude-sync - Sync Claude Code configuration with Git
# Inspired by brianlovin/claude-config

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CONFIG_FILE="$HOME/.claude-sync"
DEFAULT_CONFIG_REPO="$HOME/Projects/claude-config"

# Load config
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    fi
    CONFIG_REPO="${CONFIG_REPO:-$DEFAULT_CONFIG_REPO}"
}

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Linux*)  echo "linux" ;;
        Darwin*) echo "macos" ;;
        *)       echo "unknown" ;;
    esac
}

# Print with color
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if a JSON file is empty (non-existent, empty file, or just {})
is_json_empty() {
    local file="$1"
    if [[ ! -f "$file" ]]; then return 0; fi
    local content
    content=$(tr -d '[:space:]' < "$file")
    [[ -z "$content" || "$content" == "{}" ]]
}

# Get current OS config directory
get_config_dir() {
    local os=$(detect_os)
    echo "$CONFIG_REPO/$os"
}

# Extract only relevant fields from a claude.json file (stdout, no side effects)
extract_relevant_fields() {
    local file="$1"
    jq '{
        autoUpdates,
        githubRepoPaths,
        projects: (.projects // {} | to_entries | map({
            key,
            value: {
                allowedTools: .value.allowedTools,
                mcpServers: .value.mcpServers,
                mcpContextUris: .value.mcpContextUris,
                enabledMcpjsonServers: .value.enabledMcpjsonServers,
                disabledMcpjsonServers: .value.disabledMcpjsonServers
            }
        }) | from_entries)
    }' "$file"
}

# Detect conflicting object entries between local and repo filtered JSON
# Returns JSON array: [{"project": "...", "field": "mcpServers", "key": "my-server"}]
detect_conflicts() {
    local local_json="$1"
    local repo_json="$2"
    jq -n --argjson l "$local_json" --argjson r "$repo_json" '
        ["mcpServers"] as $fields |
        [
            $l.projects // {} | to_entries[] |
            .key as $proj | .value as $lproj |
            $fields[] as $field |
            ($lproj[$field] // {}) | to_entries[] |
            .key as $key | .value as $lval |
            (($r.projects[$proj] // {})[$field] // {})[$key] as $rval |
            select($rval) | select(($rval == $lval) | not) |
            {project: $proj, field: $field, key: $key}
        ]
    '
}

# Check if running interactively (stdin is a terminal)
is_interactive() { [[ -t 0 ]]; }

# Prompt user to resolve a single conflict
# Outputs: local|repo|both
resolve_conflict() {
    local project="$1"
    local field="$2"
    local key="$3"
    local local_json="$4"
    local repo_json="$5"

    local local_val repo_val
    local_val=$(jq -n --argjson j "$local_json" --arg p "$project" --arg f "$field" --arg k "$key" \
        '$j.projects[$p][$f][$k]')
    repo_val=$(jq -n --argjson j "$repo_json" --arg p "$project" --arg f "$field" --arg k "$key" \
        '$j.projects[$p][$f][$k]')

    warn "Conflict in project \"$project\" → $field → \"$key\"" >&2
    echo "  Local:" >&2
    echo "$local_val" | jq -C . >&2
    echo "  Repo:" >&2
    echo "$repo_val" | jq -C . >&2
    echo "" >&2
    echo "  1) Keep local (overwrite repo)" >&2
    echo "  2) Keep repo (don't push this entry)" >&2
    echo "  3) Keep both (repo version saved as \"${key}_repo\")" >&2
    echo -n "  Choice [1/2/3]: " >&2

    local choice
    read -r choice </dev/tty
    case "$choice" in
        2) echo "repo" ;;
        3) echo "both" ;;
        *) echo "local" ;;
    esac
}

# Iterate over all conflicts and resolve each one
# Returns JSON array: [{"project", "field", "key", "action"}]
resolve_all_conflicts() {
    local conflicts="$1"
    local local_json="$2"
    local repo_json="$3"

    local count
    count=$(echo "$conflicts" | jq 'length')

    local results="[]"
    for ((i=0; i<count; i++)); do
        local project field key
        project=$(echo "$conflicts" | jq -r ".[$i].project")
        field=$(echo "$conflicts" | jq -r ".[$i].field")
        key=$(echo "$conflicts" | jq -r ".[$i].key")

        local action
        action=$(resolve_conflict "$project" "$field" "$key" "$local_json" "$repo_json")

        results=$(echo "$results" | jq \
            --arg p "$project" --arg f "$field" --arg k "$key" --arg a "$action" \
            '. + [{project: $p, field: $f, key: $k, action: $a}]')
    done
    echo "$results"
}

# Apply conflict resolution overrides to the merged JSON
# "local" → noop (local already wins in merge)
# "repo"  → restore original repo value
# "both"  → add {key}_repo with repo value
apply_overrides() {
    local merged="$1"
    local dest_original="$2"
    local overrides="$3"

    jq -n --argjson m "$merged" --argjson d "$dest_original" --argjson o "$overrides" '
        reduce $o[] as $ov ($m;
            if $ov.action == "repo" then
                .projects[$ov.project][$ov.field][$ov.key] = $d.projects[$ov.project][$ov.field][$ov.key]
            elif $ov.action == "both" then
                .projects[$ov.project][$ov.field]["\($ov.key)_repo"] = $d.projects[$ov.project][$ov.field][$ov.key]
            else
                .
            end
        )
    '
}

# Sync claude.json: detect changes via filtered comparison, merge on save
sync_claude_json() {
    local source="$HOME/.claude.json"
    local dest="$(get_config_dir)/claude.json"

    if [[ ! -f "$source" ]]; then return 0; fi

    local local_filtered repo_filtered
    local_filtered=$(extract_relevant_fields "$source")

    if [[ -f "$dest" ]]; then
        repo_filtered=$(extract_relevant_fields "$dest")
    else
        repo_filtered="{}"
    fi

    # Compare only relevant fields — skip if no meaningful change
    if [[ "$local_filtered" == "$repo_filtered" ]]; then
        return 0
    fi

    # Meaningful change detected — merge repo with local (local prevails)
    # Preserves configs from other machines while keeping local telemetry
    if [[ -f "$dest" ]]; then
        local merged
        merged=$(jq -s '.[0] * .[1]' "$dest" "$source")

        # Detect conflicts (same key, different value in object fields)
        local conflicts
        conflicts=$(detect_conflicts "$local_filtered" "$repo_filtered")
        local conflict_count
        conflict_count=$(echo "$conflicts" | jq 'length')

        if [[ "$conflict_count" -gt 0 ]]; then
            if is_interactive; then
                local overrides
                overrides=$(resolve_all_conflicts "$conflicts" "$local_filtered" "$repo_filtered")
                local dest_original
                dest_original=$(cat "$dest")
                merged=$(apply_overrides "$merged" "$dest_original" "$overrides")
            else
                info "Non-interactive: $conflict_count conflict(s) detected, local version wins"
            fi
        fi

        echo "$merged" > "$dest"
    else
        cp "$source" "$dest"
    fi
}

# Merge claude.json from repo into local file (only relevant fields)
merge_claude_json() {
    local source="$(get_config_dir)/claude.json"
    local target="$HOME/.claude.json"

    if [[ ! -f "$source" ]]; then return 0; fi
    if [[ ! -f "$target" ]]; then
        cp "$source" "$target"
        return 0
    fi

    # Extract only relevant fields from repo to avoid overwriting local telemetry
    local filtered
    filtered=$(extract_relevant_fields "$source")

    local merged
    merged=$(echo "$filtered" | jq -s '.[0] * .[1]' "$target" -)
    echo "$merged" > "$target"
}

# Push a single file from local to repo (skip if identical or empty-overwrite)
push_file() {
    local source="$1"
    local dest="$2"

    if [[ ! -f "$source" ]]; then return 0; fi
    if [[ -f "$dest" ]] && diff -q "$source" "$dest" >/dev/null 2>&1; then return 0; fi
    if is_json_empty "$source" && [[ -f "$dest" ]] && ! is_json_empty "$dest"; then return 0; fi

    mkdir -p "$(dirname "$dest")"
    cp "$source" "$dest"
}

# Pull a single file from repo to local
pull_file() {
    local source="$1"
    local dest="$2"

    if [[ ! -f "$source" ]]; then return 0; fi

    mkdir -p "$(dirname "$dest")"
    cp "$source" "$dest"
}

# Sync skills directory: copy resolved content to repo (follows symlinks)
sync_skills() {
    local source="$HOME/.claude/skills"
    local dest="$(get_config_dir)/skills"

    if [[ ! -d "$source" ]]; then return 0; fi

    mkdir -p "$dest"

    # Copy each skill dir (cp -rL follows symlinks, stores actual content)
    for skill_dir in "$source"/*/; do
        [[ -d "$skill_dir" ]] || continue
        local name
        name=$(basename "$skill_dir")
        rm -rf "$dest/$name"
        cp -rL "$skill_dir" "$dest/$name"
    done

    # Remove skills from repo that no longer exist locally
    for repo_skill in "$dest"/*/; do
        [[ -d "$repo_skill" ]] || continue
        local name
        name=$(basename "$repo_skill")
        if [[ ! -d "$source/$name" ]]; then
            rm -rf "$repo_skill"
        fi
    done
}

# Merge skills from repo into local directory (additive, does not remove local skills)
merge_skills() {
    local source="$(get_config_dir)/skills"
    local target="$HOME/.claude/skills"

    if [[ ! -d "$source" ]]; then return 0; fi

    mkdir -p "$target"

    for skill_dir in "$source"/*/; do
        [[ -d "$skill_dir" ]] || continue
        local name
        name=$(basename "$skill_dir")
        # Overwrite existing skill with repo version, or add new ones
        rm -rf "$target/$name"
        cp -r "$skill_dir" "$target/$name"
    done
}

# Create backup
create_backup() {
    local backup_dir="$CONFIG_REPO/backups"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_path="$backup_dir/backup_$timestamp"

    mkdir -p "$backup_path"

    local os=$(detect_os)
    if [[ -d "$CONFIG_REPO/$os" ]]; then
        cp -r "$CONFIG_REPO/$os"/* "$backup_path/" 2>/dev/null || true
        success "Backup created at: $backup_path"
    fi

    # Keep only last 10 backups
    ls -dt "$backup_dir"/backup_* 2>/dev/null | tail -n +11 | xargs rm -rf 2>/dev/null || true
}

# Show status (differences)
cmd_status() {
    info "Checking status..."

    if [[ ! -d "$CONFIG_REPO" ]]; then
        error "Config repo not found at $CONFIG_REPO"
        exit 1
    fi

    cd "$CONFIG_REPO"

    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        error "Not a git repository: $CONFIG_REPO"
        exit 1
    fi

    # Check for uncommitted changes
    if [[ -n $(git status --porcelain) ]]; then
        warn "Uncommitted changes:"
        git status --short
    else
        success "No local changes"
    fi

    # Check if behind/ahead of remote
    local branch=$(get_branch)
    git fetch origin &>/dev/null || true
    local behind=$(git rev-list HEAD..origin/"$branch" --count 2>/dev/null || echo "0")
    local ahead=$(git rev-list origin/"$branch"..HEAD --count 2>/dev/null || echo "0")

    if [[ "$behind" -gt 0 ]]; then
        warn "Behind remote by $behind commit(s)"
    fi
    if [[ "$ahead" -gt 0 ]]; then
        info "Ahead of remote by $ahead commit(s)"
    fi
    if [[ "$behind" -eq 0 && "$ahead" -eq 0 ]]; then
        success "In sync with remote"
    fi
}

# Get current branch name
get_branch() {
    git rev-parse --abbrev-ref HEAD
}

# Generate README.md for the config repo
generate_readme() {
    local readme="$CONFIG_REPO/README.md"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    cat > "$readme" << 'HEADER'
# Claude Code Configuration

My Claude Code settings synced across machines.

## Structure

```
HEADER

    # Add directory tree (only tracked files)
    cd "$CONFIG_REPO"
    git ls-files -- '*.json' '*.md' | grep -v "README.md" | sort | while read -r file; do
        echo "$file"
    done >> "$readme"

    cat >> "$readme" << 'MIDDLE'
```

## Configs by OS

MIDDLE

    # Linux section
    if [[ -d "$CONFIG_REPO/linux" ]]; then
        echo "### Linux" >> "$readme"
        echo "" >> "$readme"

        if [[ -f "$CONFIG_REPO/linux/settings.json" ]]; then
            local perms=$(jq -r '.permissions.allow // [] | length' "$CONFIG_REPO/linux/settings.json" 2>/dev/null || echo "0")
            echo "- **settings.json**: $perms allowed commands" >> "$readme"
        fi

        if [[ -f "$CONFIG_REPO/linux/CLAUDE.md" ]]; then
            local lines=$(wc -l < "$CONFIG_REPO/linux/CLAUDE.md")
            echo "- **CLAUDE.md**: $lines lines of custom instructions" >> "$readme"
        fi

        if [[ -d "$CONFIG_REPO/linux/commands" ]]; then
            local cmds=$(ls "$CONFIG_REPO/linux/commands" 2>/dev/null | wc -l)
            echo "- **commands/**: $cmds custom commands" >> "$readme"
        fi

        if [[ -f "$CONFIG_REPO/linux/plugins/known_marketplaces.json" ]]; then
            local mkts=$(jq -r 'keys | length' "$CONFIG_REPO/linux/plugins/known_marketplaces.json" 2>/dev/null || echo "0")
            echo "- **plugins/**: $mkts marketplace(s) installed" >> "$readme"
        fi

        if [[ -d "$CONFIG_REPO/linux/skills" ]]; then
            local skills_count=$(ls -d "$CONFIG_REPO/linux/skills"/*/ 2>/dev/null | wc -l)
            echo "- **skills/**: $skills_count skill(s) synced" >> "$readme"
        fi
        echo "" >> "$readme"
    fi

    # macOS section (only if has tracked files)
    if git ls-files -- 'macos/*' | grep -q .; then
        echo "### macOS" >> "$readme"
        echo "" >> "$readme"

        if [[ -f "$CONFIG_REPO/macos/settings.json" ]]; then
            local perms=$(jq -r '.permissions.allow // [] | length' "$CONFIG_REPO/macos/settings.json" 2>/dev/null || echo "0")
            echo "- **settings.json**: $perms allowed commands" >> "$readme"
        fi

        if [[ -f "$CONFIG_REPO/macos/CLAUDE.md" ]]; then
            local lines=$(wc -l < "$CONFIG_REPO/macos/CLAUDE.md")
            echo "- **CLAUDE.md**: $lines lines of custom instructions" >> "$readme"
        fi

        if [[ -d "$CONFIG_REPO/macos/commands" ]]; then
            local cmds=$(ls "$CONFIG_REPO/macos/commands" 2>/dev/null | wc -l)
            echo "- **commands/**: $cmds custom commands" >> "$readme"
        fi

        if [[ -f "$CONFIG_REPO/macos/plugins/known_marketplaces.json" ]]; then
            local mkts=$(jq -r 'keys | length' "$CONFIG_REPO/macos/plugins/known_marketplaces.json" 2>/dev/null || echo "0")
            echo "- **plugins/**: $mkts marketplace(s) installed" >> "$readme"
        fi

        if [[ -d "$CONFIG_REPO/macos/skills" ]]; then
            local skills_count=$(ls -d "$CONFIG_REPO/macos/skills"/*/ 2>/dev/null | wc -l)
            echo "- **skills/**: $skills_count skill(s) synced" >> "$readme"
        fi
        echo "" >> "$readme"
    fi

    cat >> "$readme" << FOOTER
## Synced with

[claude-sync](https://github.com/feruiz/claude-sync) - last updated: $timestamp
FOOTER

    info "README.md updated"
}

# Push changes to git
cmd_push() {
    info "Pushing changes..."

    cd "$CONFIG_REPO"

    # Sync claude.json (detect changes via filter, save full file)
    sync_claude_json

    # Sync skills directory (copy resolved content, follows symlinks)
    sync_skills

    # Copy config files from local to repo
    local config_dir=$(get_config_dir)
    push_file "$HOME/.claude/settings.json" "$config_dir/settings.json"
    push_file "$HOME/.claude/CLAUDE.md" "$config_dir/CLAUDE.md"
    push_file "$HOME/.claude/plugins/known_marketplaces.json" "$config_dir/plugins/known_marketplaces.json"

    local branch=$(get_branch)

    # Check for changes BEFORE generating README (exclude README.md from check)
    if [[ -z $(git status --porcelain | grep -v "README.md") ]]; then
        success "Nothing to push"
        return 0
    fi

    # Only generate README if there are real changes
    generate_readme

    # Pull first to avoid conflicts (if remote exists)
    if git remote get-url origin &>/dev/null; then
        info "Pulling latest changes..."
        # Stash local changes, pull, then pop
        git stash push -m "claude-sync auto-stash" 2>/dev/null || true
        git pull --rebase origin "$branch" 2>/dev/null || {
            git stash pop 2>/dev/null || true
            error "Failed to pull. Resolve conflicts manually."
            exit 1
        }
        git stash pop 2>/dev/null || true
    fi

    # Create backup before push
    create_backup

    # Add, commit and push
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local os=$(detect_os)

    git add -A
    git commit -m "sync($os): $timestamp" || {
        warn "Nothing to commit"
        return 0
    }

    git push origin "$branch"
    success "Changes pushed successfully"
}

# Pull changes from git
cmd_pull() {
    info "Pulling changes..."

    cd "$CONFIG_REPO"

    local branch=$(get_branch)

    # Create backup before pull
    create_backup

    git pull --rebase origin "$branch"

    # Merge filtered claude.json into local file
    merge_claude_json

    # Copy config files from repo to local
    local config_dir=$(get_config_dir)
    pull_file "$config_dir/settings.json" "$HOME/.claude/settings.json"
    pull_file "$config_dir/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
    pull_file "$config_dir/plugins/known_marketplaces.json" "$HOME/.claude/plugins/known_marketplaces.json"

    # Merge skills from repo into local directory
    merge_skills

    success "Changes pulled successfully"
}

# Manual backup
cmd_backup() {
    info "Creating manual backup..."
    create_backup
}

# Undo (restore from last backup)
cmd_undo() {
    local backup_dir="$CONFIG_REPO/backups"
    local latest_backup=$(ls -dt "$backup_dir"/backup_* 2>/dev/null | head -n 1)

    if [[ -z "$latest_backup" ]]; then
        error "No backups found"
        exit 1
    fi

    info "Restoring from: $latest_backup"

    local os=$(detect_os)
    local config_dir="$CONFIG_REPO/$os"

    # Create backup of current state first
    create_backup

    # Restore
    rm -rf "$config_dir"/*
    cp -r "$latest_backup"/* "$config_dir/"

    success "Restored from backup"
}

# List backups
cmd_backups() {
    local backup_dir="$CONFIG_REPO/backups"

    if [[ ! -d "$backup_dir" ]]; then
        info "No backups found"
        return 0
    fi

    info "Available backups:"
    ls -dt "$backup_dir"/backup_* 2>/dev/null | while read -r backup; do
        echo "  - $(basename "$backup")"
    done
}

# Show help
cmd_help() {
    echo "claude-sync - Sync Claude Code configuration with Git"
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  status    Show sync status and differences"
    echo "  push      Commit and push changes to remote"
    echo "  pull      Pull changes from remote"
    echo "  backup    Create a manual backup"
    echo "  undo      Restore from the last backup"
    echo "  backups   List available backups"
    echo "  help      Show this help message"
    echo ""
    echo "Configuration:"
    echo "  Config repo: $CONFIG_REPO"
    echo "  OS detected: $(detect_os)"
}

# Main
main() {
    load_config

    local command="${1:-help}"

    case "$command" in
        status)  cmd_status ;;
        push)    cmd_push ;;
        pull)    cmd_pull ;;
        backup)  cmd_backup ;;
        undo)    cmd_undo ;;
        backups) cmd_backups ;;
        help)    cmd_help ;;
        *)
            error "Unknown command: $command"
            cmd_help
            exit 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
