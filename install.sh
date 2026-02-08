#!/bin/bash
# claude-sync installer
# Creates symlinks from ~/.claude to the config repo

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$HOME/.claude-sync"
DEFAULT_CONFIG_REPO="$HOME/Projects/claude-config"

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

# Create backup of existing files
backup_existing() {
    local backup_dir="$CONFIG_REPO/backups/pre_install_$(date +%Y%m%d_%H%M%S)"
    local backed_up=false

    mkdir -p "$backup_dir"

    # Backup ~/.claude.json if exists and is not a symlink
    if [[ -f "$HOME/.claude.json" && ! -L "$HOME/.claude.json" ]]; then
        cp "$HOME/.claude.json" "$backup_dir/"
        backed_up=true
    fi

    # Backup ~/.claude/settings.json if exists and is not a symlink
    if [[ -f "$HOME/.claude/settings.json" && ! -L "$HOME/.claude/settings.json" ]]; then
        cp "$HOME/.claude/settings.json" "$backup_dir/"
        backed_up=true
    fi

    # Backup ~/.claude/CLAUDE.md if exists and is not a symlink
    if [[ -f "$HOME/.claude/CLAUDE.md" && ! -L "$HOME/.claude/CLAUDE.md" ]]; then
        cp "$HOME/.claude/CLAUDE.md" "$backup_dir/"
        backed_up=true
    fi

    # Backup plugins/known_marketplaces.json if exists and is not a symlink
    if [[ -f "$HOME/.claude/plugins/known_marketplaces.json" && ! -L "$HOME/.claude/plugins/known_marketplaces.json" ]]; then
        mkdir -p "$backup_dir/plugins"
        cp "$HOME/.claude/plugins/known_marketplaces.json" "$backup_dir/plugins/"
        backed_up=true
    fi

    # Backup commands directory if exists and is not a symlink
    if [[ -d "$HOME/.claude/commands" && ! -L "$HOME/.claude/commands" ]]; then
        cp -r "$HOME/.claude/commands" "$backup_dir/"
        backed_up=true
    fi

    if $backed_up; then
        success "Existing files backed up to: $backup_dir"
    fi
}

# Copy current configs to repo (first time setup)
copy_configs_to_repo() {
    local os=$(detect_os)
    local config_dir="$CONFIG_REPO/$os"

    mkdir -p "$config_dir/plugins"

    # Copy ~/.claude.json (full file — filtering is only for change detection in sync.sh)
    if [[ -f "$HOME/.claude.json" ]]; then
        cp "$HOME/.claude.json" "$config_dir/claude.json"
        info "Copied ~/.claude.json"
    fi

    # Copy ~/.claude/settings.json
    if [[ -f "$HOME/.claude/settings.json" && ! -L "$HOME/.claude/settings.json" ]]; then
        cp "$HOME/.claude/settings.json" "$config_dir/settings.json"
        info "Copied ~/.claude/settings.json"
    fi

    # Copy ~/.claude/CLAUDE.md or create template
    if [[ -f "$HOME/.claude/CLAUDE.md" && ! -L "$HOME/.claude/CLAUDE.md" ]]; then
        cp "$HOME/.claude/CLAUDE.md" "$config_dir/CLAUDE.md"
        info "Copied ~/.claude/CLAUDE.md"
    elif [[ ! -f "$config_dir/CLAUDE.md" ]]; then
        cat > "$config_dir/CLAUDE.md" << 'EOF'
# Claude Code - Personal Instructions

## Preferences
- Preferred language: Portuguese (Brazil)
- Code style: [define]

## Context
- Setup: Linux and macOS
- Main projects: [list]

## Custom Instructions
[Add your custom instructions here]
EOF
        info "Created CLAUDE.md template"
    fi

    # Copy plugins/known_marketplaces.json
    if [[ -f "$HOME/.claude/plugins/known_marketplaces.json" && ! -L "$HOME/.claude/plugins/known_marketplaces.json" ]]; then
        cp "$HOME/.claude/plugins/known_marketplaces.json" "$config_dir/plugins/"
        info "Copied known_marketplaces.json"
    fi

    # Copy commands directory if exists
    if [[ -d "$HOME/.claude/commands" && ! -L "$HOME/.claude/commands" ]]; then
        cp -r "$HOME/.claude/commands" "$config_dir/"
        info "Copied commands directory"
    fi
}

# Create symlinks
create_symlinks() {
    local os=$(detect_os)
    local config_dir="$CONFIG_REPO/$os"

    # Ensure directories exist
    mkdir -p "$HOME/.claude/plugins"

    # claude.json is managed by copy+filter (not symlink) — see sync.sh

    # ~/.claude/settings.json -> repo/os/settings.json
    if [[ -f "$config_dir/settings.json" ]]; then
        rm -f "$HOME/.claude/settings.json"
        ln -s "$config_dir/settings.json" "$HOME/.claude/settings.json"
        success "Linked ~/.claude/settings.json"
    fi

    # ~/.claude/CLAUDE.md -> repo/os/CLAUDE.md
    if [[ -f "$config_dir/CLAUDE.md" ]]; then
        rm -f "$HOME/.claude/CLAUDE.md"
        ln -s "$config_dir/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
        success "Linked ~/.claude/CLAUDE.md"
    fi

    # ~/.claude/plugins/known_marketplaces.json -> repo/os/plugins/known_marketplaces.json
    if [[ -f "$config_dir/plugins/known_marketplaces.json" ]]; then
        rm -f "$HOME/.claude/plugins/known_marketplaces.json"
        ln -s "$config_dir/plugins/known_marketplaces.json" "$HOME/.claude/plugins/known_marketplaces.json"
        success "Linked known_marketplaces.json"
    fi

    # ~/.claude/commands -> repo/os/commands (if exists)
    if [[ -d "$config_dir/commands" ]]; then
        rm -rf "$HOME/.claude/commands"
        ln -s "$config_dir/commands" "$HOME/.claude/commands"
        success "Linked commands directory"
    fi
}

# Save configuration
save_config() {
    cat > "$CONFIG_FILE" << EOF
# claude-sync configuration
CONFIG_REPO="$CONFIG_REPO"
EOF
    success "Configuration saved to $CONFIG_FILE"
}

# Install automation (systemd/launchd)
install_automation() {
    local os=$(detect_os)

    if [[ "$os" == "linux" ]]; then
        install_systemd
    elif [[ "$os" == "macos" ]]; then
        install_launchd
    fi
}

install_systemd() {
    local service_dir="$HOME/.config/systemd/user"
    mkdir -p "$service_dir"

    # Copy service files
    if [[ -f "$SCRIPT_DIR/automation/linux/claude-sync.service" ]]; then
        cp "$SCRIPT_DIR/automation/linux/claude-sync.service" "$service_dir/"
        cp "$SCRIPT_DIR/automation/linux/claude-sync.path" "$service_dir/"

        # Update paths in service file
        sed -i "s|SCRIPT_DIR|$SCRIPT_DIR|g" "$service_dir/claude-sync.service"
        sed -i "s|CONFIG_REPO|$CONFIG_REPO|g" "$service_dir/claude-sync.path"

        # Enable and start
        systemctl --user daemon-reload
        systemctl --user enable claude-sync.path
        systemctl --user start claude-sync.path

        success "Systemd automation installed and started"
    else
        warn "Systemd service files not found. Skipping automation."
    fi
}

install_launchd() {
    local launch_dir="$HOME/Library/LaunchAgents"
    mkdir -p "$launch_dir"

    if [[ -f "$SCRIPT_DIR/automation/macos/com.user.claude-sync.plist" ]]; then
        local plist="$launch_dir/com.user.claude-sync.plist"
        cp "$SCRIPT_DIR/automation/macos/com.user.claude-sync.plist" "$plist"

        # Update paths in plist
        sed -i '' "s|SCRIPT_DIR|$SCRIPT_DIR|g" "$plist"
        sed -i '' "s|HOME_DIR|$HOME|g" "$plist"

        # Load the agent
        launchctl unload "$plist" 2>/dev/null || true
        launchctl load "$plist"

        success "LaunchAgent installed and loaded"
    else
        warn "LaunchAgent plist not found. Skipping automation."
    fi
}

# Main installation
main() {
    echo ""
    echo "========================================"
    echo "  claude-sync installer"
    echo "========================================"
    echo ""

    local os=$(detect_os)
    info "Detected OS: $os"

    if [[ "$os" == "unknown" ]]; then
        error "Unsupported operating system"
        exit 1
    fi

    # Ask for config repo location
    echo ""
    read -p "Config repo location [$DEFAULT_CONFIG_REPO]: " input_repo
    CONFIG_REPO="${input_repo:-$DEFAULT_CONFIG_REPO}"

    if [[ ! -d "$CONFIG_REPO" ]]; then
        warn "Config repo does not exist. Creating it..."
        mkdir -p "$CONFIG_REPO"/{linux/plugins,macos/plugins,backups}
    fi

    info "Using config repo: $CONFIG_REPO"

    # Backup existing files
    echo ""
    info "Backing up existing files..."
    backup_existing

    # Copy configs to repo (first time)
    echo ""
    info "Copying current configs to repo..."
    copy_configs_to_repo

    # Create symlinks
    echo ""
    info "Creating symlinks..."
    create_symlinks

    # Save configuration
    save_config

    # Ask about automation
    echo ""
    read -p "Install automation (sync on file change)? [y/N]: " install_auto
    if [[ "$install_auto" =~ ^[Yy]$ ]]; then
        install_automation
    else
        info "Skipping automation. You can run './sync.sh push' manually."
    fi

    # Done
    echo ""
    echo "========================================"
    success "Installation complete!"
    echo "========================================"
    echo ""
    echo "Next steps:"
    echo "  1. cd $CONFIG_REPO"
    echo "  2. git init (if not already a git repo)"
    echo "  3. git add . && git commit -m 'Initial config'"
    echo "  4. git remote add origin <your-repo-url>"
    echo "  5. git push -u origin main"
    echo ""
    echo "Usage:"
    echo "  ./sync.sh status   # Check sync status"
    echo "  ./sync.sh push     # Push changes"
    echo "  ./sync.sh pull     # Pull changes"
    echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
