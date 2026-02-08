# Roadmap

## Current state

claude-sync currently syncs:
- `~/.claude.json` → copy + merge (jq) + interactive conflict detection
- `~/.claude/settings.json` → symlink
- `~/.claude/CLAUDE.md` → symlink
- `~/.claude/commands/` → symlink (directory)
- `~/.claude/plugins/known_marketplaces.json` → symlink

**Not synced yet:**
- `~/.claude/skills/` → symlinks to `~/.agents/skills/*/` (each skill is a folder with `SKILL.md`)
- `~/.claude/plugins/installed_plugins.json`

## Roadmap (one PR per item)

1. ~~**Conflict detection on claude.json**~~ (done) — detect conflicts in object fields (mcpServers) on push, interactive prompt when TTY, local wins silently in automation.
2. **Sync `skills/`** — each skill is a folder with files (`SKILL.md`, etc.). Decision: symlink entire directory or copy + merge per skill?
3. **Sync `installed_plugins.json`** — JSON with installed plugin list. Decision: symlink or merge (like claude.json)?
4. **Conflict detection for directories** (commands/, skills/) — compare files with same name but different content between local and repo. Same UX as item 1.
