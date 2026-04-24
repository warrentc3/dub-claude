# divergence

Capture agent divergence events — moments where an agent produced the wrong output and the operator corrected it — as structured preference-pair artifacts for training data, red-teaming review, or longitudinal pattern analysis.

The plugin ships one skill (`divergence`) and a session-ownership `PreToolUse` hook that guarantees artifacts are write-once-per-session and not readable by any later session, different skill, or ad-hoc tool call.

## Install

From the dub-claude marketplace:

```
/plugin marketplace add warrentc3/dub-claude
/plugin install divergence@dub-claude
```

On first enable, Claude Code will prompt for the optional `log_dir` value (see **Configuration** below). Leave it blank to accept the default.

## What it does

When the operator signals that an agent output was wrong (a correction, a "no, that's not right", an explicit call to the skill), `divergence` writes a structured markdown artifact that records:

- **Bad output** — what the agent produced
- **Correction** — what the operator said in response
- **Right output** — what it should have been, or what was produced after correction
- **Failure class** — one of a ten-value taxonomy (`evidence-ignored`, `premature-implementation`, `selective-reading`, `authoritative-speculation`, `burndown-compulsion`, `single-source-overreach`, `inherited-convention`, `context-loss`, `silent-averaging`, `adverse-autonomy`)
- **Why** — which assumption failed, what evidence was available and not used
- **Code evidence** — full verbatim file content when code is the ground truth (no excerpts, no paraphrase)

Artifacts are written as `YYYY-MM-DD-HHmm_<failure-class>_<slug>.md` into the configured log directory.

## Configuration

One setting, prompted at plugin-enable time.

| Key       | Type        | Required | Default                                   |
| --------- | ----------- | -------- | ----------------------------------------- |
| `log_dir` | `directory` | No       | `${CLAUDE_PLUGIN_DATA}/divergence_logs`   |

Set `log_dir` when you want artifacts to land somewhere you control — a long-lived archive directory, a synced cloud folder, a training-data staging path. Leave it blank to use the plugin's own data directory under `~/.claude/plugins/data/divergence/divergence_logs/`.

The value is exposed to the hook and skill as:

- `${user_config.log_dir}` — substitution in skill content and hook commands
- `CLAUDE_PLUGIN_OPTION_LOG_DIR` — environment variable in plugin subprocesses

## Session-ownership model

The PreToolUse hook gates the configured log directory with a session-identity rule rather than a blanket read-only policy. The effect:

| Action on a file under the log dir         | Policy                                                                   |
| ------------------------------------------ | ------------------------------------------------------------------------ |
| `Write` from any session                   | **Allow.** Append `(session_id, file_path)` to the ownership ledger.     |
| `Read` / `Edit` by the session that wrote it | **Allow.** Same-session amendments are how the skill iterates on drafts. |
| `Read` / `Edit` by any other session       | **Deny.** No cross-session reads, ever.                                  |
| `Grep` / `Glob` anywhere under the dir     | **Deny.** No enumeration across sessions.                                |
| `Bash` referencing the dir (literal path, env-var form, or default subdir name) | **Deny.** Agents interact with the dir exclusively through `Write`/`Read`/`Edit`. |
| `WebFetch` with a `file://` URL into the dir | **Deny.**                                                                |
| MCP tool calls whose string args resolve under the dir or reference it by name | **Deny.**                                                                |
| The ownership ledger itself                | **Deny** all tool access. Hook reads/writes it directly.                 |

Ownership is persisted in `<log_dir>/.ownership.jsonl` — append-only, one line per Write: `{session_id, file_path, ts}`. Lookups are exact-match on `(session_id, file_path)`.

**Why this shape.** Divergence artifacts are preference data. If an agent could read its own prior divergences (or another agent's), the correction record becomes input that shapes future outputs — contaminating the ground truth the artifacts were meant to capture. Session-ownership keeps each record pinned to the moment and agent that produced it.

## Requirements

| Platform       | Runtime                                      |
| -------------- | -------------------------------------------- |
| Windows        | PowerShell 7+ (`pwsh`)                       |
| macOS / Linux  | `bash` 4+, `jq`, GNU coreutils (`realpath`)  |

Both hook implementations ship in `hooks/` and self-guard on platform, so installing on any OS is safe — the right script runs, the other no-ops.

## Caveats

- **The guard is plugin-scoped, not skill-scoped.** It fires whenever the plugin is enabled in the session, not only while the `divergence` skill is being invoked. If a user disables the plugin, subsequent sessions have no hook enforcing ownership. That is a deliberate user action — not a bypass — but worth understanding if you rely on long-term artifact protection.
- **No automatic ledger cleanup.** Entries for ended sessions remain in the ledger forever. This is intentional (they're the proof of ownership) but grows linearly with the number of writes. Operational cleanup is out of scope for v1.
- **MCP surface is best-effort.** Newly installed MCP servers that expose file-reading tools are denied when their string arguments resolve under the log dir or contain the dir name. The hook does not know every MCP server's argument schema; extend the check in `session_ownership.{ps1,sh}` if you install a server with unconventional arg shapes.
- **Skill-content variable substitution is an observed-pending-live-test detail.** Per plugin docs, non-sensitive userConfig values substitute inside skill markdown at load time; this has been validated against the docs but not yet against a live Claude Code install.

## Layout

```
plugins/divergence/
├── .claude-plugin/
│   └── plugin.json              # manifest; userConfig schema
├── hooks/
│   ├── hooks.json               # PreToolUse registration
│   ├── session_ownership.ps1    # Windows (pwsh)
│   └── session_ownership.sh     # Unix (bash + jq)
├── skills/
│   └── divergence/
│       └── SKILL.md             # skill body: process + artifact format
└── README.md                    # this file
```

## License

MIT. See the marketplace root `LICENSE`.
