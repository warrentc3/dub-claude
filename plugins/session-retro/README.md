# session-retro

Write a structured session retrospective at the end of a Claude Code work session. Produces a dated markdown file with a session metrics header and four reflective sections, written in explanatory mode with ★ Insight blocks.

## Install

From the dub-claude marketplace:

```
/plugin marketplace add warrentc3/dub-claude
/plugin install session-retro@dub-claude
```

On first enable, Claude Code will prompt for the optional `retro_dir` value. Leave it blank to accept the default.

## What it does

When invoked at session end, `session-retro` writes a retrospective file containing:

- **Session metrics header** — ModelID, OutputStyle, Claude version, entry point, message count, start/end timestamps, context usage percentage
- **Four sections**, each referencing a concrete moment from the session:
  1. One thing done well together
  2. One thing the operator did that made the work harder or slower
  3. One thing the agent got wrong or could have handled better
  4. One thing that would make the project better
- **★ Insight blocks** — 2–3 educational points per retrospective, written with explanatory depth

Files are named `YYYY-MM-DD-HH_(three-word-topic).md` and written to the configured `retro_dir`.

## Configuration

One setting, prompted at plugin-enable time.

| Key        | Type        | Required | Default                              |
| ---------- | ----------- | -------- | ------------------------------------ |
| `retro_dir` | `directory` | No       | `${CLAUDE_PLUGIN_DATA}/retrospectives` |

## How the transcript path works

The plugin ships a `SessionStart` hook that reads the transcript path from session startup data and injects it into the session context. The skill reads this value when it runs the metrics bash block.

If you already have a `session-init`-style hook that injects `TranscriptPath:` into context, the plugin hook is redundant but harmless — it will emit the same line and the skill reads whichever appears first.

## Requirements

| Platform       | Runtime                          |
| -------------- | -------------------------------- |
| macOS / Linux  | `bash`, `jq`                     |
| Windows        | Git Bash (`bash`), `jq`          |

The plugin hook and skill both run under bash. On Windows, Git Bash is required. `jq` must be on `PATH`.

## Invoking the skill

```
/session-retro
```

Or when invoked as part of a larger session-close workflow:

```
/session-retro:session-retro
```

## Layout

```
plugins/session-retro/
├── .claude-plugin/
│   └── plugin.json              # manifest; userConfig schema
├── hooks/
│   ├── hooks.json               # SessionStart registration
│   └── session-retro.sh         # injects TranscriptPath into context
├── skills/
│   └── session-retro/
│       └── SKILL.md             # retrospective format + inlined bash
└── README.md                    # this file
```

## License

MIT. See the marketplace root `LICENSE`.
