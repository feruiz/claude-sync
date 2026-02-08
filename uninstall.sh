#!/bin/bash
# claude-sync uninstaller
# Removes symlinks and restores original files from backup

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CONFIG_FILE="$HOME/.claude-sync"

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Linux*)  echo "linux" ;;
        Darwin*) echo "macos" ;;
        *)       echo "unknown" ;;
    esac
}

# Load config
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    fi
}

# Remove symlinks
remove_symlinks() {
    # Remove ~/.claude.json if it's a symlink
    if [[ -L "$HOME/.claude.json" ]]; then
        rm "$HOME/.claude.json"
        success "Removed symlink: ~/.claude.json"
    fi

    # Remove ~/.claude/settings.json if it's a symlink
    if [[ -L "$HOME/.claude/settings.json" ]]; then
        rm "$HOME/.claude/settings.json"
        success "Removed symlink: ~/.claude/settings.json"
    fi

    # Remove ~/.claude/CLAUDE.md if it's a symlink
    if [[ -L "$HOME/.claude/CLAUDE.md" ]]; then
        rm "$HOME/.claude/CLAUDE.md"
        success "Removed symlink: ~/.claude/CLAUDE.md"
    fi

    # Remove plugins/known_marketplaces.json if it's a symlink
    if [[ -L "$HOME/.claude/plugins/known_marketplaces.json" ]]; then
        rm "$HOME/.claude/plugins/known_marketplaces.json"
        success "Removed symlink: known_marketplaces.json"
    fi

    # Remove commands if it's a symlink
    if [[ -L "$HOME/.claude/commands" ]]; then
        rm "$HOME/.claude/commands"
        success "Removed symlink: commands"
    fi
}

# Restore from backup
restore_from_backup() {
    if [[ -z "$CONFIG_REPO" ]]; then
        warn "Config repo not found. Cannot restore from backup."
        return
    fi

    local backup_dir="$CONFIG_REPO/backups"
    local latest_backup=$(ls -dt "$backup_dir"/pre_install_* 2>/dev/null | head -n 1)

    if [[ -z "$latest_backup" ]]; then
        warn "No pre-install backup found. Files will need to be recreated by Claude Code."
        return
    fi

    info "Restoring from: $latest_backup"

    # Restore files
    if [[ -f "$latest_backup/.claude.json" ]]; then
        cp "$latest_backup/.claude.json" "$HOME/.claude.json"
        success "Restored ~/.claude.json"
    fi

    if [[ -f "$latest_backup/settings.json" ]]; then
        cp "$latest_backup/settings.json" "$HOME/.claude/settings.json"
        success "Restored ~/.claude/settings.json"
    fi

    if [[ -f "$latest_backup/CLAUDE.md" ]]; then
        cp "$latest_backup/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
        success "Restored ~/.claude/CLAUDE.md"
    fi

    if [[ -f "$latest_backup/plugins/known_marketplaces.json" ]]; then
        mkdir -p "$HOME/.claude/plugins"
        cp "$latest_backup/plugins/known_marketplaces.json" "$HOME/.claude/plugins/"
        success "Restored known_marketplaces.json"
    fi

    if [[ -d "$latest_backup/commands" ]]; then
        cp -r "$latest_backup/commands" "$HOME/.claude/"
        success "Restored commands directory"
    fi
}

# Remove automation
remove_automation() {
    local os=$(detect_os)

    if [[ "$os" == "linux" ]]; then
        remove_systemd
    elif [[ "$os" == "macos" ]]; then
        remove_launchd
    fi
}

remove_systemd() {
    local service_dir="$HOME/.config/systemd/user"

    if [[ -f "$service_dir/claude-sync.path" ]]; then
        systemctl --user stop claude-sync.path 2>/dev/null || true
        systemctl --user disable claude-sync.path 2>/dev/null || true
        rm -f "$service_dir/claude-sync.path"
        rm -f "$service_dir/claude-sync.service"
        systemctl --user daemon-reload
        success "Removed systemd automation"
    fi
}

remove_launchd() {
    local plist="$HOME/Library/LaunchAgents/com.user.claude-sync.plist"

    if [[ -f "$plist" ]]; then
        launchctl unload "$plist" 2>/dev/null || true
        rm -f "$plist"
        success "Removed LaunchAgent"
    fi
}

# Main
main() {
    echo ""
    echo "========================================"
    echo "  claude-sync uninstaller"
    echo "========================================"
    echo ""

    load_config

    read -p "This will remove symlinks and automation. Continue? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        info "Aborted."
        exit 0
    fi

    echo ""
    info "Removing symlinks..."
    remove_symlinks

    echo ""
    read -p "Restore original files from backup? [y/N]: " restore
    if [[ "$restore" =~ ^[Yy]$ ]]; then
        restore_from_backup
    fi

    echo ""
    info "Removing automation..."
    remove_automation

    # Remove config file
    rm -f "$CONFIG_FILE"

    echo ""
    echo "========================================"
    success "Uninstall complete!"
    echo "========================================"
    echo ""
    echo "Note: The config repos were NOT deleted."
    echo "  - $CONFIG_REPO"
    echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
