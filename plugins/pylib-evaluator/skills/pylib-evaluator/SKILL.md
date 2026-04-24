---
name: pylib-evaluator
description: Evaluate a Python library's maintenance state and adoption viability via PyPI metadata, GitHub repo activity, and commit decomposition (bot-vs-human author classification). Produces a viability report for dependency-adoption decisions.
---

# Python Library Evaluator

Evaluates one or more Python libraries against three orthogonal signals that together answer "is this library worth adopting as a dependency":

1. PyPI metadata — version, release date, `requires-python`, Python classifiers, license, project URLs.
2. GitHub repo state — `pushed_at`, archived flag, open issue / open PR counts, stars, license.
3. Commit decomposition (last 20) — bot-authored, automated-subject, substantive.

Combined verdict: active, maintenance mode, legacy, effectively abandoned despite commit volume, or dead.

Three signals together catch the distinct failure modes a single signal misses:

- Published-but-abandoned — PyPI has a recent version but upstream is silent.
- Committed-but-unpublished — GitHub shows activity, nothing reaches PyPI.
- Committed-but-automated — high commit cardinality entirely bot/CI.

## When to invoke

- Considering a new PyPI package for a project's `pyproject.toml`.
- Re-evaluating an existing pinned dependency whose maintenance state is in question.
- Comparing alternatives for the same role (e.g. `charset_normalizer` vs `chardet`).

Do not invoke for stable-ecosystem libraries with no serious alternatives (e.g. `httpx`, `pytest`, `pydantic` at current major versions). This skill is for decisions where maintenance state is load-bearing.

## Prerequisites

This skill has hard dependencies. It cannot run without them.

### Required tools

- `gh` CLI — GitHub's official command-line tool.
  - Install: https://cli.github.com (binaries for Windows, macOS, Linux; package managers where available).
  - Authenticate: `gh auth login` (browser flow or personal access token paste).
  - Verify: `gh auth status` should show an active account.
- `uv` — Python runtime + dependency manager.
  - Install: https://docs.astral.sh/uv/getting-started/installation/
  - Script invokes as `uv run --with httpx python ...`; `httpx` is fetched ephemerally each run.

### GitHub access policy

- All GitHub access goes through `gh` CLI (`gh api`, `gh api graphql`).
- Do not call `api.github.com` directly via `curl`, `httpx`, `requests`, WebFetch, or browser automation.
- Rationale: `gh` handles keyring-backed auth, rate-limit backoff, API version headers, and enterprise-instance routing. Direct HTTP against `api.github.com` loses all of that.

### Failure posture

- If `gh` is missing or unauthenticated, the script exits 2 with a specific remedy (`[gh CLI not found]` or `[gh auth required]`).
- There is no fallback path. The three-signal methodology requires authenticated GitHub API access; partial evaluation without commit decomposition would be misleading. If `gh` cannot be installed in the environment, this skill cannot be used there.

### Network

- Outbound access to `pypi.org` and `api.github.com` (the latter via `gh`).

## How to invoke

Pass one or more package names:

```
/pylib-evaluator charset-normalizer
/pylib-evaluator trafilatura goose3 readability-lxml
```

Run the helper script from any directory:

```bash
uv run --with httpx python "${CLAUDE_PLUGIN_ROOT}/skills/pylib-evaluator/scripts/evaluate.py" <package-name> [<package-name> ...]
```

The script hits PyPI once per package, `gh api` twice per package (repo state + 20 commits), and `gh api graphql` once per package for split issue/PR counts. No other network activity.

## Output shape

For each library:

1. PyPI section — name, version, summary, `requires-python`, license, classifiers, `latest_py3`, release date + age, project URLs.
2. GitHub section — `pushed_at`, `updated_at`, archived flag, `open_issues`, `open_prs`, `open_total` (REST combined issues+PRs), stars, license.
3. Commit decomposition — window dates, bot count, human count, automated-subject count, substantive count, listing of 20 commits tagged `[BOT]`, `[CFG]`, or `[   ]`.
4. Interpretive verdict — written by the invoking agent, not dumped from the script.

The verdict addresses:

- Alive / maintenance mode / stale / dead.
- Maintainer posture — active development, occasional releases, external PRs welcomed, or neglect.
- Failure modes visible — commits without releases, releases without human commits, archived flag, license drift, Python version support gap.
- Scope fit for the current task.

## Interpretive patterns

- Commit count ≠ substantive activity. Dependabot bumps, pre-commit-ci autoupdates, and CI config changes are real commits but not signs of development. Count substantive commits, not raw cardinality.
- Release cadence matters as much as commit cadence. Human commits on master without a new PyPI release means work isn't shipping. PyPI version date is load-bearing, not `pushed_at`.
- Stars are a lagging indicator. Current maintenance comes from `pushed_at` + release date + commit decomposition, not star count.
- Python classifiers are a metadata-hygiene signal. Classifiers stuck at an old Python minor while master still sees bug fixes means the maintainer is functional but inattentive to package surface. Prefer `latest_py3` over hardcoded version checks.
- README-only human activity is a dead-project tell. If all recent human commits are README updates, ad-banner changes, or sponsor links, the project is in monetization mode, not development mode. The script can't detect this — the invoking agent scans subject lines.

## Limitations

- 20-commit window can mislead on low-cadence projects. For libraries shipping yearly or less, 20 commits may span multiple years. Note the window dates explicitly when this matters.
- Non-GitHub-hosted packages are partially supported — PyPI section works, GitHub + commit sections skipped.
- Private GitHub repos require local `gh` CLI authenticated with appropriate scopes.
- Commit subject classification is heuristic.
- README-only detection requires the invoking agent to visually scan subjects; the script cannot infer file-level changes.

## Evolution path

- This skill is intentionally Python-package scoped.
- Planned successor: a holistic package evaluator applying the same maintenance-signals framework across PyPI, NuGet, Go modules, and GitHub Actions.
- Verdict shape stays consistent across the successor so cross-ecosystem comparisons remain decision-usable.
