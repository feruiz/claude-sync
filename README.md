<h1 align="center">claude-sync</h1>

<p align="center">
  <strong>Keep your Claude Code config in sync across every machine</strong>
</p>

<p align="center">
  <a href="https://github.com/feruiz/claude-sync/actions/workflows/test.yml"><img src="https://img.shields.io/github/actions/workflow/status/feruiz/claude-sync/test.yml?branch=main&label=CI" alt="CI"></a>
  <img src="https://img.shields.io/badge/tests-145%20passing-brightgreen" alt="Tests: 145 passing">
  <a href="https://github.com/feruiz/claude-sync/blob/main/LICENSE"><img src="https://img.shields.io/github/license/feruiz/claude-sync" alt="License"></a>
  <img src="https://img.shields.io/badge/made%20with-Bash-1f425f" alt="Bash">
  <img src="https://img.shields.io/badge/platform-Linux%20%7C%20macOS-blue" alt="Platform: Linux | macOS">
</p>

---

Claude Code stores its configuration in `~/.claude/` — permissions, MCP servers, personal instructions, custom commands, and more. **claude-sync** keeps all of that in a Git repo and synchronizes it across machines with a single command.

No symlink hacks, no dotfile manager required. Just `push` and `pull`.

## Features

- **Copy + merge architecture** — files are copied (not symlinked), so editor atomic saves never break anything
- **Smart JSON filtering** — `~/.claude.json` contains telemetry mixed with config; only relevant fields are compared and synced
- **Conflict detection** — warns you before overwriting local changes that haven't been pushed
- **Per-OS configs** — separate `linux/` and `macos/` directories so machines can differ
- **Automatic backups** — every destructive operation creates a timestamped backup first
- **Optional automation** — systemd (Linux) or launchd (macOS) watches for changes and pushes automatically
- **One-command install/uninstall** — `./install.sh` sets everything up, `./uninstall.sh` tears it down cleanly
- **145 tests** — unit, integration, and git-level tests via [Bats](https://github.com/bats-core/bats-core)

## Quick Start

### Prerequisites

- Git
- Bash 4+
- [jq](https://jqlang.github.io/jq/)

### Install

```bash
git clone https://github.com/feruiz/claude-sync.git ~/Projects/claude-sync
cd ~/Projects/claude-sync
./install.sh
```

The installer will:

1. Create a **config repo** (default `~/Projects/claude-config`) to store your files
2. Back up your existing Claude Code configuration
3. Copy current configs into the repo
4. Set up a `commands/` symlink for custom slash commands
5. Optionally install automation (systemd / launchd)

## Usage

```bash
./sync.sh status    # Show sync status and pending changes
./sync.sh push      # Commit and push config changes to Git
./sync.sh pull      # Pull latest config from Git and merge locally
./sync.sh backup    # Create a manual backup
./sync.sh undo      # Restore from the most recent backup
./sync.sh backups   # List all available backups
```

## How It Works

claude-sync uses a **two-repo model**:

| Repo | Purpose | Visibility |
|------|---------|------------|
| **claude-sync** (this repo) | The tool itself — scripts, automation, tests | Public (safe) |
| **claude-config** (your data) | Your actual config files, organized by OS | Private (recommended) |

### Sync mechanism

Most files use **copy + merge**: on `push`, files are copied from `~/.claude/` into the config repo; on `pull`, they're copied back. This avoids the symlink fragility that editors with atomic save (VS Code, Vim) can cause.

The exception is `~/.claude/commands/` — it's a **symlink** to the config repo directory. Editing files inside a symlinked directory works fine, so this gives you real-time sync for custom commands.

### JSON filtering (`~/.claude.json`)

`~/.claude.json` mixes real configuration with machine-specific telemetry (`numStartups`, `tipsHistory`, `userID`, etc.). claude-sync extracts only the relevant fields for comparison:

- **Top-level:** `autoUpdates`, `githubRepoPaths`
- **Per-project:** `allowedTools`, `mcpServers`, `mcpContextUris`, `enabledMcpjsonServers`, `disabledMcpjsonServers`

If only telemetry changed, the push is skipped. On pull, relevant fields are merged into your local file without overwriting machine-specific data.

## What Gets Synced

| File | Method | Description |
|------|--------|-------------|
| `~/.claude.json` | filtered merge | MCP servers, allowed tools, project paths (telemetry ignored) |
| `~/.claude/settings.json` | copy | Permissions, env, hooks, model, sandbox, plugins |
| `~/.claude/CLAUDE.md` | copy | Personal instructions |
| `~/.claude/commands/` | symlink | Custom slash commands |
| `~/.claude/plugins/known_marketplaces.json` | copy | Registered plugin marketplaces |
| `~/.claude/skills/` | copy | Installed skills |

## What Doesn't Get Synced

| File | Reason |
|------|--------|
| `~/.claude/.credentials.json` | Authentication tokens — sensitive and machine-specific |
| `~/.claude/plugins/marketplaces/` | Git repos cloned automatically per machine |
| `~/.claude/projects/` | Session history — local to each machine |
| Cache, logs, temp files | Ephemeral and machine-specific |

## Automation

### Linux (systemd)

A `path` unit watches the config repo for changes and triggers a push automatically:

```bash
# Installed by ./install.sh — files in automation/linux/
systemctl --user status claude-sync.path
```

### macOS (launchd)

A `LaunchAgent` watches the config repo using `WatchPaths`:

```bash
# Installed by ./install.sh — file in automation/macos/
launchctl list | grep claude-sync
```

## Project Structure

```
claude-sync/
├── install.sh              # Setup: backup, copy, symlink, automation
├── sync.sh                 # CLI: status, push, pull, backup, undo, backups
├── uninstall.sh            # Teardown: restore backups, remove automation
├── Makefile                # Test runner shortcuts
├── automation/
│   ├── linux/              # systemd path + service units
│   └── macos/              # launchd plist
└── test/
    ├── run_tests.sh        # Test runner
    ├── test_helper.bash    # Shared fixtures and helpers
    ├── unit/               # 14 unit test files
    ├── integration/        # 9 integration test files
    └── git/                # 4 git-level test files
```

## Testing

The test suite uses [Bats](https://github.com/bats-core/bats-core) (Bash Automated Testing System) with **145 tests** across three categories:

| Category | Tests | What they cover |
|----------|-------|-----------------|
| Unit | `test/unit/` | Individual functions: OS detection, JSON filtering, conflict detection, file operations |
| Integration | `test/integration/` | End-to-end workflows: backup, copy, merge, symlink creation/removal |
| Git | `test/git/` | Full push/pull/status/undo cycles with real Git repos |

```bash
make test              # Run all tests
make test-unit         # Unit tests only
make test-integration  # Integration tests only
make test-git          # Git tests only
```

## Security

Your config repo may contain:

- Local file paths (in `~/.claude.json`)
- MCP server configurations
- Custom tool permissions

**Keep your config repo private.** The tool itself (this repo) is safe to be public.

## Uninstall

```bash
./uninstall.sh
```

This removes symlinks, optionally restores original files from backup, and removes automation services.

## Inspiration

- [brianlovin/claude-config](https://github.com/brianlovin/claude-config)
- [sumchattering/claude-config](https://github.com/sumchattering/claude-config)
- [Sync Claude Code with chezmoi](https://www.arun.blog/sync-claude-code-with-chezmoi-and-age/)

## License

[MIT](LICENSE) &copy; feruiz
