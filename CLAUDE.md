# DubClaude

Claude Code plugin marketplace. Hosts multiple plugins under `plugins/` — each independently installable via `/plugin install <plugin-name>@dub-claude` after users add the marketplace with `/plugin marketplace add <repo-url>`.

## Stack

- JSON — `.claude-plugin/marketplace.json` at repo root (marketplace manifest); per-plugin `.claude-plugin/plugin.json`.
- Markdown — per-plugin `SKILL.md` files (under `plugins/<plugin>/skills/{name}/`) and per-plugin README.
- Python — skill helper scripts within plugins, invoked via `uv run --with <deps> python ...`.
- Additional stacks (pwsh, Go) expected as new plugins land.

## Conventions

- Layout: Claude Code multi-plugin marketplace convention.
  - `.claude-plugin/marketplace.json` at repo root declares every plugin in the marketplace.
  - Each plugin lives at `plugins/<plugin-name>/` with its own `.claude-plugin/plugin.json`, `skills/`, `agents/`, `hooks/`, `.mcp.json`, `.lsp.json` at the plugin's root. Never inside `.claude-plugin/` at any level.
- Per-skill layout (within a plugin): `skills/{name}/SKILL.md`, helper scripts under the skill's `scripts/` subdirectory.
- Namespacing: installed plugin skills resolve as `<plugin-name>:<skill-name>`.
- Versioning: per-plugin semver declared in each `plugin.json` `version` field; independent release cadence per plugin.
- License: MIT.
- Quality gate: no plugin ships until its failure modes have been exercised. Release-standard.
- Offline until shippable: plugins developed locally; marketplace remote is OneDrive during development, GitHub-public only when a plugin meets the shipping bar.

## External service dependencies

DubClaude plugins may reference MCP servers that live in their own repos, not inside DubClaude. sticky-fetch is the first such external dependency:

- Source: `c:\git\sticky-fetch\` (standalone repo, git history preserved via `git filter-repo` extraction from `.pmo`, offline until shippable).
- Eventual distribution: ghcr.io container image.
- DubClaude's role: a (future) plugin whose `.mcp.json` points at sticky-fetch's HTTP endpoint (`http://localhost:8765/mcp`). The plugin distributes the MCP *config* to users; users stand up the *server* themselves from the sticky-fetch repo or ghcr image.

## Situational awareness

- [ARCHITECTURE.md](../_situational_awareness/dub-claude/ARCHITECTURE.md) — timeless design.
- [POSTERITY.md](../_situational_awareness/dub-claude/POSTERITY.md) — decisions, deferred items, priorities.
