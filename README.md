# DubClaude

A Claude Code plugin marketplace. Tools and skills for agent-assisted development, each independently installable and independently versioned.

## Install the marketplace

```
/plugin marketplace add warrentc3/dub-claude
```

Then browse or install specific plugins:

```
/plugin install <plugin-name>@dub-claude
```

Skills resolve as `<plugin-name>:<skill-name>` once installed.

## Plugins

| Plugin                                                 | Purpose                                                                                                        |
| ------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------- |
| [divergence](plugins/divergence/README.md)             | Capture agent correction events as structured preference-pair artifacts. Session-owned: write-once, owner-read-only. |
| [pylib-evaluator](plugins/pylib-evaluator/README.md)   | Evaluate Python libraries against PyPI metadata, GitHub repo state, and commit decomposition. Produces a maintenance-state report for dependency-adoption decisions. |
| [session-retro](plugins/session-retro/README.md)       | Write a structured session retrospective — 4-section format with session metrics header extracted from the transcript. |

Each plugin is independently versioned and independently installable — install only what you need.

## Layout

```
dub-claude/
├── .claude-plugin/
│   └── marketplace.json          # marketplace manifest; declares every plugin
├── plugins/
│   ├── divergence/               # see plugins/divergence/README.md
│   ├── pylib-evaluator/          # see plugins/pylib-evaluator/README.md
│   └── session-retro/            # see plugins/session-retro/README.md
├── LICENSE                       # MIT
└── README.md                     # this file
```

## Design posture

- **Release-standard, not work-in-progress.** No plugin ships until its failure modes have been exercised. "Good enough for private use" is not the bar.
- **Offline until shippable.** Plugins develop locally against a private remote; the marketplace goes GitHub-public only when its contents meet the shipping bar.
- **Per-plugin independence.** Each plugin has its own `plugin.json`, its own semver, its own hooks/skills/scripts. No shared runtime, no cross-plugin coupling.
- **External dependencies stay external.** Some plugins reference MCP servers that live in their own repos (e.g. `sticky-fetch`). DubClaude distributes the MCP *config*; users stand up the *server* themselves.

## Authoring a plugin

The Claude Code plugin reference is authoritative — see https://code.claude.com/docs/en/plugins-reference. Conventions followed here:

- Every plugin lives at `plugins/<plugin-name>/` with its own `.claude-plugin/plugin.json`.
- Skills at `skills/<skill-name>/SKILL.md`; helper scripts under `scripts/`.
- Hooks at `hooks/hooks.json` with command scripts under `hooks/`.
- Never place plugin components inside `.claude-plugin/` at any level — that directory is for manifests only.
- `${CLAUDE_PLUGIN_ROOT}` resolves to the plugin's installed directory; `${CLAUDE_PLUGIN_DATA}` to its per-user data directory; `${user_config.<key>}` substitutes values the user set at enable time.
- Cross-platform hook scripts self-guard on platform (pwsh on Windows, bash on Unix) so registering both in `hooks.json` is safe.

## License

MIT. See [LICENSE](LICENSE). Individual plugins inherit this license unless their own `plugin.json` declares otherwise (none currently do).
