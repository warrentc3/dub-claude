# pylib-evaluator

Evaluate Python libraries against three orthogonal signals — PyPI publish cadence, GitHub repo state, and commit decomposition (bot vs. human, automated-subject vs. substantive) — and produce a structured report the invoking agent interprets into a dependency-adoption verdict.

One signal alone misleads. Combining three catches the failure modes any single signal misses: published-but-abandoned, committed-but-unpublished, committed-but-all-automated.

## Install

From the dub-claude marketplace:

```
/plugin marketplace add warrentc3/dub-claude
/plugin install pylib-evaluator@dub-claude
```

## What it does

For each package you pass it, the skill produces:

- **PyPI section** — version, release date + age, `requires-python`, Python classifiers, license, project URLs. Release date reflects the currently-published version's upload timestamp, not a stale file pick.
- **GitHub section** — `pushed_at`, `updated_at`, archived flag, open issues, open PRs (split via GraphQL because REST combines them), stars, license.
- **Commit decomposition** — last 20 commits tagged `[BOT]` (bot-authored, detected via login suffix, `type == "Bot"`, and rebased-bot name fallbacks), `[CFG]` (human author, automated subject like `chore(deps)` / `bump` / `ci:`), or `[   ]` (substantive: human author + non-automated subject).
- **Verdict** — written by the invoking agent, not dumped from the script. The script surfaces the evidence; interpretation is the agent's job.

## When to invoke

- Adding a new dependency to a project's `pyproject.toml`.
- Re-evaluating a pinned dependency whose maintenance state is in question.
- Comparing alternatives for the same role (e.g. `charset_normalizer` vs `chardet`, `trafilatura` vs `goose3`).

Don't invoke for stable-ecosystem libraries with no serious alternatives (`httpx`, `pytest`, `pydantic` at current majors). The skill is for decisions where maintenance state is load-bearing.

## Requirements

This skill has hard dependencies and no fallback path — the three-signal methodology requires authenticated GitHub access, and partial evaluation without commit decomposition would mislead.

| Tool  | Why                                                                     | Install                                                  |
| ----- | ----------------------------------------------------------------------- | -------------------------------------------------------- |
| `gh`  | All GitHub API access routes through it — keyring-backed auth, rate-limit backoff, enterprise routing. Direct `curl api.github.com` loses all of that. | https://cli.github.com → then `gh auth login` |
| `uv`  | Python runtime + ephemeral dependency resolution for `httpx`.            | https://docs.astral.sh/uv/getting-started/installation/  |

The script fetches `httpx` ephemerally each run via `uv run --with httpx`, so you don't need `httpx` installed system-wide.

If `gh` is missing or unauthenticated, the script exits `2` with a specific remedy (`[gh CLI not found]` or `[gh auth required]`). If you can't install `gh` in your environment, the skill can't be used there.

## Invocation

Slash-command form (primary):

```
/pylib-evaluator charset-normalizer
/pylib-evaluator trafilatura goose3 readability-lxml
```

Direct script form (for CI or ad-hoc use):

```bash
uv run --with httpx python "${CLAUDE_PLUGIN_ROOT}/skills/pylib-evaluator/scripts/evaluate.py" <package> [<package> ...]
```

Network cost per package: one PyPI HTTP call, two `gh api` REST calls (repo state + 20 commits), one `gh api graphql` call (split issue/PR counts). No other outbound traffic.

## Output interpretation

The script's output is evidence, not verdict. The invoking agent reads the three sections and writes one or two paragraphs addressing:

- **Alive / maintenance mode / stale / dead** — based on PyPI release age, GitHub `pushed_at`, and substantive-commit count together.
- **Maintainer posture** — active development, occasional releases, external PRs welcomed, or neglect.
- **Failure modes visible** — commits-without-releases, releases-without-human-commits, archived flag, license drift, Python version support gap.
- **Scope fit** — does this library match the responsibility the caller is about to hand it?

### Patterns worth watching for

- **Commit count ≠ substantive activity.** Dependabot bumps and pre-commit-ci autoupdates are real commits but not signs of development. Trust the `SUBSTANTIVE commits:` line, not raw cardinality.
- **Release cadence vs. commit cadence.** Human commits on master without a new PyPI release means work isn't shipping. PyPI version date is the load-bearing timestamp, not `pushed_at`.
- **Stars are a lagging indicator.** Current maintenance state comes from release date + `pushed_at` + commit decomposition.
- **README-only human activity is a dead-project tell.** If all substantive commits are README, ad-banner, or sponsor-link edits, the project is in monetization mode, not development mode. The script can't detect this — scan the subject listing yourself.

## Caveats

- **20-commit window misleads on low-cadence projects.** For libraries shipping yearly or less, 20 commits may span multiple years. The `window:` line shows the actual date range — state it explicitly when interpreting.
- **Non-GitHub-hosted packages are partially supported.** PyPI section works; GitHub and commit decomposition are skipped if no GitHub repo is discoverable from `project_urls` or `home_page`.
- **Private repos need `gh` authenticated with the appropriate scopes.** The skill inherits your local `gh` auth.
- **Commit subject classification is heuristic.** `AUTOMATED_SUBJECT_RE` catches the common patterns (`bump`, `chore(deps)`, `ci:`, `build:`) but a project using non-conventional subjects for automated work will look more active than it is.

## Evolution path

The skill is intentionally Python-package scoped. A planned successor will apply the same maintenance-signals framework across PyPI, NuGet, Go modules, and GitHub Actions, keeping the verdict shape consistent so cross-ecosystem comparisons stay decision-usable.

## Layout

```
plugins/pylib-evaluator/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── pylib-evaluator/
│       ├── SKILL.md                  # methodology, invocation, interpretive patterns
│       └── scripts/
│           └── evaluate.py           # PyPI + gh API fetch, commit decomposition
└── README.md                         # this file
```

## License

MIT. See the marketplace root `LICENSE`.
