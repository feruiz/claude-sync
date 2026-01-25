# claude-sync

A simple tool to sync your Claude Code configuration across machines using Git.

## How it Works

This tool uses **symlinks** (symbolic links) to sync your Claude Code configuration.

### What are symlinks?

Symlinks are special files that act as shortcuts pointing to another file or folder. Think of them like a shortcut on Windows or an alias on macOS, but at the filesystem level.

When you run `./install.sh`, it replaces your Claude Code config files with symlinks pointing to this Git repository:

```
~/.claude/settings.json  →  ~/Projects/claude-config/linux/settings.json
        (symlink)                        (real file in git repo)
```

Any program (including Claude Code) that reads or writes to the symlink is actually accessing the real file in your Git repo. This means:

- Claude Code works normally - it doesn't know the difference
- Changes are automatically saved to your Git repo
- You can sync across machines with `git push` and `git pull`

### Does this conflict with Claude Code updates?

**No.** Claude Code updates typically update the application itself, not your personal configuration files. The symlinks remain intact and continue working after updates.

In rare cases where an update might replace a symlink with a real file, simply run `./install.sh` again to restore the symlinks.

## Features

- Sync Claude Code configs between Linux and macOS
- Automatic backups before any destructive operation
- Optional automation (systemd on Linux, launchd on macOS)
- Separate configs per OS (configs can differ between machines)

## Quick Start

```bash
# Clone this repo
git clone https://github.com/yourusername/claude-sync.git ~/Projects/claude-sync
cd ~/Projects/claude-sync

# Run the installer
./install.sh
```

The installer will:
1. Ask for your config repo location (default: `~/Projects/claude-config`)
2. Backup your existing Claude Code configs
3. Copy configs to the repo
4. Create symlinks
5. Optionally install automation

## Usage

```bash
# Check sync status
./sync.sh status

# Push changes to Git
./sync.sh push

# Pull changes from Git
./sync.sh pull

# Create a manual backup
./sync.sh backup

# Restore from last backup
./sync.sh undo

# List available backups
./sync.sh backups
```

## Structure

### Config Repo (your data - private)

```
claude-config/
├── linux/
│   ├── claude.json          # ~/.claude.json
│   ├── settings.json        # ~/.claude/settings.json
│   ├── CLAUDE.md            # ~/.claude/CLAUDE.md
│   ├── commands/            # Custom commands
│   └── plugins/
│       └── known_marketplaces.json
├── macos/
│   └── (same structure)
└── backups/                 # (gitignored)
```

### This Repo (the tool - can be public)

```
claude-sync/
├── install.sh               # Setup script
├── sync.sh                  # Main sync commands
├── uninstall.sh             # Remove everything
├── automation/
│   ├── linux/               # systemd units
│   └── macos/               # launchd plist
└── README.md
```

## What Gets Synced

| File | Description |
|------|-------------|
| `~/.claude/settings.json` | Command permissions |
| `~/.claude/CLAUDE.md` | Personal instructions |
| `~/.claude/commands/` | Custom commands |
| `~/.claude/plugins/known_marketplaces.json` | Installed marketplaces |

## What Does NOT Get Synced

- `~/.claude.json` - Contains sensitive data (account info, local paths, stats)
- `~/.claude/.credentials.json` - Authentication (sensitive)
- `~/.claude/plugins/marketplaces/` - Git repos cloned automatically
- `~/.claude/projects/` - Session history (local)
- Cache, logs, and temporary files

## Uninstall

```bash
./uninstall.sh
```

This will:
1. Remove symlinks
2. Optionally restore original files from backup
3. Remove automation (systemd/launchd)

## Inspiration

- [brianlovin/claude-config](https://github.com/brianlovin/claude-config)
- [sumchattering/claude-config](https://github.com/sumchattering/claude-config)
- [Sync Claude Code with chezmoi](https://www.arun.blog/sync-claude-code-with-chezmoi-and-age/)

## License

MIT
