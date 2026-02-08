# Claude Sync

## O que é

Ferramenta de sincronização de configurações do Claude Code entre máquinas via Git + copy/merge. Os arquivos ficam num repositório Git e são copiados de/para `~/.claude/` nos comandos push/pull.

## Arquitetura

- **Copy+merge** é o mecanismo central para arquivos individuais (evita problemas com atomic save de editores)
- **Symlink** apenas para `commands/` (diretório — editar arquivos dentro não quebra o symlink)
- Configurações separadas por OS: `linux/` e `macos/`
- Automação: systemd (Linux) / launchd (macOS) monitora mudanças e faz push automático
- Estado salvo em `~/.claude-sync` (contém `CONFIG_REPO`)

## Arquivos principais

| Arquivo | Função |
|---------|--------|
| `sync.sh` | CLI principal: status, push, pull, backup, undo, backups |
| `install.sh` | Setup: cria symlinks, backups, instala automação |
| `uninstall.sh` | Reverso: remove symlinks, restaura backups, remove automação |
| `automation/linux/` | Units systemd (path + service) |
| `automation/macos/` | LaunchAgent plist |

## Arquivos sincronizados

- `~/.claude.json` — **Arquivo completo** (filtragem usada só para detecção de mudanças). Copy+merge.
- `~/.claude/settings.json` — Permissões, env, hooks, modelo, sandbox, plugins (copy+merge)
- `~/.claude/CLAUDE.md` — Instruções pessoais (copy+merge)
- `~/.claude/commands/` — Comandos customizados (symlink de diretório)
- `~/.claude/plugins/known_marketplaces.json` — Plugins de marketplace (copy+merge)

### claude.json: filtragem e telemetria

O `~/.claude.json` é um arquivo legado (deprecated desde v2.0.8, migração para `settings.json`), mas o Claude Code continua escrevendo nele ativamente. Ele mistura configurações úteis com estado interno/telemetria que muda constantemente.

**Campos sincronizados (top-level):** `autoUpdates`, `githubRepoPaths`

**Campos sincronizados (dentro de `projects.*`):** `allowedTools`, `mcpServers`, `mcpContextUris`, `enabledMcpjsonServers`, `disabledMcpjsonServers`

**Campos ignorados (telemetria/estado):** `numStartups`, `tipsHistory`, `cachedGrowthBookFeatures`, `userID`, `s1mAccessCache`, `groveConfigCache`, `passesEligibilityCache`, `changelogLastFetched`, `skillUsage`, `lastPlanModeUse`, `*MigrationComplete`, `lastSessionId`, `lastCost`, `lastDuration`, `projectOnboardingSeenCount`, etc.

**Por que é seguro filtrar:** o Claude Code regenera campos faltantes automaticamente em segundos durante a sessão. O troubleshooting oficial recomenda `rm ~/.claude.json` como reset válido. Campos de telemetria são específicos por máquina e não devem ser sincronizados.

**Mecanismo:** No push, `sync.sh` usa `jq` para extrair campos relevantes do arquivo local e do repo — se forem iguais, ignora (evita commits de telemetria). Se houver diferença nos campos relevantes, copia o arquivo **completo** para o repo. No pull, extrai apenas campos relevantes do arquivo do repo e faz merge no local com `jq -s '.[0] * .[1]'` (evita sobrescrever telemetria local com dados de outra máquina).

### settings.json: arquivo atual

O `~/.claude/settings.json` é o arquivo de configuração recomendado pela Anthropic. Não contém telemetria nem estado interno — apenas configurações declarativas (permissões, env, hooks, modelo, sandbox, plugins). Usa copy+merge (não symlink) para compatibilidade com atomic save de editores (VS Code, vim escrevem em temp, deletam original, renomeiam — isso quebra symlinks).

## Convenções importantes

- Todos os scripts usam `set -e` (falha no primeiro erro)
- Output colorido com prefixos: `[INFO]`, `[OK]`, `[WARN]`, `[ERROR]`
- Backups com timestamp (`backups/backup_YYYYMMDD_HHMMSS/`), máximo 10 mantidos
- Commits seguem formato: `sync(os): YYYY-MM-DD HH:MM:SS`
- Pull usa `--rebase` para evitar merge commits
- Arquivos de automação usam placeholders (`SCRIPT_DIR`, `CONFIG_REPO`, `HOME_DIR`) substituídos via `sed` na instalação

## Cuidados ao editar

- macOS usa `sed -i ''` (diferente do Linux `sed -i`) — manter compatibilidade
- Checar symlinks com `-L` antes de sobrescrever
- O push do `sync.sh` gera README.md automaticamente — detectar e ignorar mudanças apenas no README para evitar commits espúrios
- Tratar remote Git ausente (nem todo setup tem origin configurado)
- Arquivos opcionais (`commands/`, `known_marketplaces.json`) podem não existir — usar `|| true`
- Automação: fazer reload/daemon-reload após copiar arquivos de serviço
