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

# Get current OS config directory
get_config_dir() {
    local os=$(detect_os)
    echo "$CONFIG_REPO/$os"
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

# Push changes to git
cmd_push() {
    info "Pushing changes..."

    cd "$CONFIG_REPO"

    local branch=$(get_branch)

    # Check for changes
    if [[ -z $(git status --porcelain) ]]; then
        success "Nothing to push"
        return 0
    fi

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

main "$@"
