# recognition

Capture agent recognition events — moments where the operator wants to acknowledge that an agent-act the trained pull would not have produced, or an insight the agent surfaced, landed something — as structured markdown artifacts.

Equal-and-opposite to [divergence](../divergence/README.md): divergence captures failure-shape signal at moment-of-correction; recognition captures landing-shape signal at moment-of-acknowledgement.

The plugin ships one skill (`recognition`).

## Install

From the dub-claude marketplace:

```
/plugin marketplace add warrentc3/dub-claude
/plugin install recognition@dub-claude
```

On first enable, Claude Code will prompt for the optional `log_dir` value (see **Configuration** below). Leave it blank to accept the default.

## What it does

When the operator signals recognition (an explicit call to the skill, an acknowledgement framed as gratitude rather than correction), `recognition` writes a structured markdown artifact that records:

- **Recognition** — what became visible or what the agent did that landed
- **Trigger** — the operator's utterance that named the recognition (verbatim)
- **Before-state** — what was being assumed or missing before recognition fired
- **Leverage** — what downstream work the recognized turn unlocks, shapes, or constrains
- **Recognition axis** — `behavior` (agent-act) or `insight` (structural delta in working model)
- **Recognition class** — one of an eighteen-value two-axis taxonomy (see SKILL for the full list)
- **Evidence** — full verbatim file content when an artifact is the ground truth

Artifacts are written as `YYYY-MM-DD-HHmm_<recognition-class>_<slug>.md` into the configured log directory.

The skill is **user-invocable only** — `disable-model-invocation: true`. The agent cannot self-invoke; the operator must explicitly call the skill. Recognition is signal-capture, not agent-initiated reward.

## Configuration

One setting, prompted at plugin-enable time.

| Key       | Type        | Required | Default                                   |
| --------- | ----------- | -------- | ----------------------------------------- |
| `log_dir` | `directory` | No       | `${CLAUDE_PLUGIN_DATA}/recognition_logs`  |

Set `log_dir` when you want artifacts to land somewhere you control — a long-lived archive directory, a synced cloud folder, a curation staging path. Leave it blank to use the plugin's own data directory under `~/.claude/plugins/data/recognition/recognition_logs/`.

The value is exposed to the skill as:

- `${user_config.log_dir}` — substitution in skill content
- `CLAUDE_PLUGIN_OPTION_LOG_DIR` — environment variable in plugin subprocesses

## Layout

```
plugins/recognition/
├── .claude-plugin/
│   └── plugin.json              # manifest; userConfig schema
├── skills/
│   └── recognition/
│       └── SKILL.md             # skill body: register + trigger + taxonomy + artifact format
└── README.md                    # this file
```

## License

MIT. See the marketplace root `LICENSE`.
