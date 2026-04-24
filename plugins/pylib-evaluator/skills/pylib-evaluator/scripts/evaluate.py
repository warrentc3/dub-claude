"""Python library maintenance-state evaluator.

Evaluates one or more Python libraries against three orthogonal signals:
PyPI metadata, GitHub repo state, and commit decomposition. Produces a
structured report that the invoking agent interprets into a verdict.

See SKILL.md in the parent directory for full methodology and interpretive
patterns.

Run:
    uv run --with httpx python "${CLAUDE_PLUGIN_ROOT}/skills/pylib-evaluator/scripts/evaluate.py" <package> [<package> ...]
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from urllib.parse import urlparse

try:
    import httpx
except ImportError:  # pragma: no cover
    print("ERROR: httpx is required. Run via: uv run --with httpx python evaluate.py <package>", file=sys.stderr)
    sys.exit(2)


sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")


BOT_LOGIN_RE = re.compile(r"\[bot\]$", re.IGNORECASE)
BOT_NAME_RE = re.compile(
    r"(?:\b|\[)(?:bot|dependabot|renovate|github-actions|pre-commit-ci)(?:\b|\])",
    re.IGNORECASE,
)
AUTOMATED_SUBJECT_RE = re.compile(
    r"^(?::\w+:\s*)?(?:bump|chore\(deps\)|chore\(ci\)|ci:|deps:|build\(deps\)|build:)\b",
    re.IGNORECASE,
)
GITHUB_URL_RE = re.compile(r"github\.com/([^/]+)/([^/#?]+)", re.IGNORECASE)
REPO_LABEL_RE = re.compile(r"(source|repository|repo|code|github)", re.IGNORECASE)
RESERVED_GITHUB_PATH_SEGMENTS = {
    "about",
    "apps",
    "collections",
    "enterprise",
    "events",
    "explore",
    "features",
    "gist",
    "gists",
    "issues",
    "login",
    "marketplace",
    "new",
    "notifications",
    "orgs",
    "organizations",
    "pricing",
    "pulls",
    "search",
    "security",
    "sessions",
    "settings",
    "sponsors",
    "teams",
    "topics",
    "users",
}


def print_header(title: str, char: str = "=") -> None:
    print("\n" + char * 100)
    print(title)
    print(char * 100)


def parse_iso_timestamp(iso_timestamp: str | None) -> datetime | None:
    if not iso_timestamp:
        return None
    try:
        ts = iso_timestamp.replace("Z", "+00:00")
        dt = datetime.fromisoformat(ts)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc)
    except Exception:  # noqa: BLE001
        return None


def format_age(iso_timestamp: str | None) -> str:
    dt = parse_iso_timestamp(iso_timestamp)
    if dt is None:
        return "?"
    now = datetime.now(timezone.utc)
    days = (now - dt).days
    if days < 31:
        return f"{days}d ago"
    months = days // 30
    if months < 24:
        return f"{months}mo ago"
    return f"{days // 365}y ago"


def fetch_pypi(package: str) -> dict | None:
    url = f"https://pypi.org/pypi/{package}/json"
    try:
        r = httpx.get(url, timeout=30.0)
    except Exception as exc:  # noqa: BLE001
        print(f"[pypi fetch error] {package}: {exc}", file=sys.stderr)
        return None
    if r.status_code != 200:
        print(f"[pypi not found] {package}: status {r.status_code}", file=sys.stderr)
        return None
    return r.json()


def extract_github_repo(info: dict) -> tuple[str, str] | None:
    candidates: list[tuple[int, str]] = []
    project_urls = info.get("project_urls") or {}
    for label, url in project_urls.items():
        if not url:
            continue
        if REPO_LABEL_RE.search(label or ""):
            priority = 0
        elif (label or "").strip().lower() in {"homepage", "home"}:
            priority = 1
        else:
            priority = 2
        candidates.append((priority, url))

    home_page = info.get("home_page")
    if home_page:
        candidates.append((3, home_page))

    for _, url in sorted(candidates, key=lambda x: x[0]):
        parsed = urlparse(url)
        host = parsed.netloc.lower()
        if host not in {"github.com", "www.github.com"}:
            continue
        path = parsed.path.strip("/")
        segments = [s for s in path.split("/") if s]
        if len(segments) < 2:
            continue

        owner = segments[0]
        repo = segments[1].removesuffix(".git")
        if owner.lower() in RESERVED_GITHUB_PATH_SEGMENTS:
            continue
        if repo.lower() in RESERVED_GITHUB_PATH_SEGMENTS:
            continue
        if not repo:
            continue
        return (owner, repo)

    # Compatibility fallback for unusual but valid repository URL strings.
    for _, url in sorted(candidates, key=lambda x: x[0]):
        m = GITHUB_URL_RE.search(url)
        if not m:
            continue
        owner = m.group(1)
        repo = m.group(2).removesuffix(".git")
        if owner.lower() in RESERVED_GITHUB_PATH_SEGMENTS or repo.lower() in RESERVED_GITHUB_PATH_SEGMENTS:
            continue
        if repo:
            return (owner, repo)
    return None


def gh_api(endpoint: str) -> dict | list | None:
    try:
        result = subprocess.run(
            ["gh", "api", endpoint],
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=60,
        )
    except FileNotFoundError:
        print("[gh CLI not found] install from https://cli.github.com and authenticate", file=sys.stderr)
        return None
    except Exception as exc:  # noqa: BLE001
        print(f"[gh api error] {endpoint}: {exc}", file=sys.stderr)
        return None
    if result.returncode != 0:
        print(f"[gh api error] {endpoint}: {result.stderr.strip()}", file=sys.stderr)
        return None
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        print(f"[gh api json error] {endpoint}: {exc}", file=sys.stderr)
        return None


def gh_graphql(owner: str, repo: str, query: str) -> dict | None:
    try:
        result = subprocess.run(
            [
                "gh",
                "api",
                "graphql",
                "-f",
                f"query={query}",
                "-F",
                f"owner={owner}",
                "-F",
                f"name={repo}",
            ],
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=60,
        )
    except FileNotFoundError:
        print("[gh CLI not found] install from https://cli.github.com and authenticate", file=sys.stderr)
        return None
    except Exception as exc:  # noqa: BLE001
        print(f"[gh graphql error] {owner}/{repo}: {exc}", file=sys.stderr)
        return None
    if result.returncode != 0:
        print(f"[gh graphql error] {owner}/{repo}: {result.stderr.strip()}", file=sys.stderr)
        return None
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        print(f"[gh graphql json error] {owner}/{repo}: {exc}", file=sys.stderr)
        return None


def ensure_gh_ready() -> bool:
    """Require GitHub access through authenticated gh CLI. No direct-HTTP fallback."""
    try:
        version = subprocess.run(
            ["gh", "--version"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=15,
        )
    except FileNotFoundError:
        print("[gh CLI not found] install from https://cli.github.com", file=sys.stderr)
        return False
    except Exception as exc:  # noqa: BLE001
        print(f"[gh check error] {exc}", file=sys.stderr)
        return False

    if version.returncode != 0:
        print(f"[gh check error] {version.stderr.strip()}", file=sys.stderr)
        return False

    auth = subprocess.run(
        ["gh", "auth", "status"],
        capture_output=True,
        text=True,
        encoding="utf-8",
        timeout=20,
    )
    if auth.returncode != 0:
        print("[gh auth required] run: gh auth login", file=sys.stderr)
        return False
    return True


def extract_release_date(pypi: dict, info: dict, urls: list[dict]) -> str | None:
    """Pick latest upload timestamp among files of the current version.

    Using releases[version] ensures we report when the currently-published
    version shipped, not just the first file returned by the PyPI API.
    """
    candidates: list[tuple[datetime, str]] = []

    version = info.get("version")
    releases = pypi.get("releases") or {}
    if version and isinstance(releases, dict):
        files = releases.get(version) or []
        if isinstance(files, list):
            for file_info in files:
                if not isinstance(file_info, dict):
                    continue
                ts = file_info.get("upload_time_iso_8601") or file_info.get("upload_time")
                if not isinstance(ts, str):
                    continue
                dt = parse_iso_timestamp(ts)
                if dt is not None:
                    candidates.append((dt, ts))

    if not candidates:
        for file_info in urls:
            if not isinstance(file_info, dict):
                continue
            ts = file_info.get("upload_time_iso_8601") or file_info.get("upload_time")
            if not isinstance(ts, str):
                continue
            dt = parse_iso_timestamp(ts)
            if dt is not None:
                candidates.append((dt, ts))

    if not candidates:
        return None
    return max(candidates, key=lambda item: item[0])[1]


def parse_py3_classifiers(classifiers: list[str]) -> tuple[bool, list[str]]:
    py3_declared = False
    minors: set[str] = set()
    for c in classifiers:
        if not c.startswith("Programming Language :: Python :: 3"):
            continue
        py3_declared = True
        leaf = c.split("::")[-1].strip()
        if re.fullmatch(r"3\.\d+", leaf):
            minors.add(leaf)
    sorted_minors = sorted(minors, key=lambda v: tuple(int(p) for p in v.split(".")))
    return py3_declared, sorted_minors


def infer_is_bot(commit_obj: dict, author_login: str) -> bool:
    """Detect bot-authored commits across all available signals.

    GitHub exposes bot identity in several non-equivalent places: the
    `[bot]` login suffix, `author.type == "Bot"`, `committer.type == "Bot"`,
    and name fields when a commit was rebased/squashed away from the bot
    login. Checking only the login suffix misses rebased-bot commits.
    """
    author = commit_obj.get("author") or {}
    committer = commit_obj.get("committer") or {}
    commit_info = commit_obj.get("commit") or {}
    commit_author = commit_info.get("author") or {}
    commit_committer = commit_info.get("committer") or {}

    if BOT_LOGIN_RE.search(author_login):
        return True
    if (author.get("type") or "").lower() == "bot":
        return True
    if (committer.get("type") or "").lower() == "bot":
        return True

    name_candidates = [
        author_login,
        (committer.get("login") or ""),
        (commit_author.get("name") or ""),
        (commit_committer.get("name") or ""),
    ]
    return any(BOT_NAME_RE.search(candidate) for candidate in name_candidates if candidate)


def print_pypi_section(pypi: dict, info: dict, urls: list[dict]) -> None:
    print_header("PyPI", "-")
    print(f"  name:            {info.get('name')}")
    print(f"  version:         {info.get('version')}")
    print(f"  summary:         {(info.get('summary') or '').strip()}")
    print(f"  requires-python: {info.get('requires_python') or '(unspecified)'}")
    print(f"  license:         {info.get('license') or '(none declared in legacy field)'}")

    classifiers = info.get("classifiers") or []
    py3_declared, py3_minors = parse_py3_classifiers(classifiers)
    print(f"  py classifiers:  {py3_minors or '(none specific)'}")
    print(f"  py3 declared:    {'YES' if py3_declared else 'no'}")
    if py3_minors:
        print(f"  latest_py3:      {py3_minors[-1]}")
    else:
        print("  latest_py3:      (unavailable)")

    release_date = extract_release_date(pypi, info, urls)
    if release_date:
        print(f"  released:        {release_date}  ({format_age(release_date)})")
        print("  release_basis:   PyPI publish timestamp for current package version")
    else:
        print("  released:        (unavailable)")

    project_urls = info.get("project_urls") or {}
    if project_urls:
        print("  project_urls:")
        for label, url in project_urls.items():
            print(f"    {label:<16} {url}")


def fetch_issue_pr_counts(owner: str, repo: str) -> tuple[int | None, int | None]:
    query = (
        "query($owner: String!, $name: String!) { "
        "repository(owner: $owner, name: $name) { "
        "issues(states: OPEN) { totalCount } "
        "pullRequests(states: OPEN) { totalCount } "
        "} }"
    )
    response = gh_graphql(owner, repo, query)
    if not isinstance(response, dict):
        return (None, None)
    repo_data = (((response.get("data") or {}).get("repository")) or {})
    issues = (((repo_data.get("issues") or {}).get("totalCount")))
    prs = (((repo_data.get("pullRequests") or {}).get("totalCount")))
    return (
        issues if isinstance(issues, int) else None,
        prs if isinstance(prs, int) else None,
    )


def print_github_section(
    owner: str,
    repo: str,
    data: dict,
    open_issues: int | None,
    open_prs: int | None,
) -> None:
    print_header(f"GitHub ({owner}/{repo})", "-")
    print(f"  default_branch:  {data.get('default_branch')}")
    pushed = data.get("pushed_at")
    updated = data.get("updated_at")
    print(f"  pushed_at:       {pushed}  ({format_age(pushed)})")
    print(f"  updated_at:      {updated}  ({format_age(updated)})")
    print(f"  archived:        {'YES (warn)' if data.get('archived') else 'no'}")
    if open_issues is None:
        print("  open_issues:     (unavailable)")
    else:
        print(f"  open_issues:     {open_issues}")
    if open_prs is None:
        print("  open_prs:        (unavailable)")
    else:
        print(f"  open_prs:        {open_prs}")
    print(f"  open_total:      {data.get('open_issues_count')}  (GitHub REST combined issues+PRs)")
    print(f"  stars:           {data.get('stargazers_count')}")
    license_info = data.get("license") or {}
    print(f"  license:         {license_info.get('name') if isinstance(license_info, dict) else '(unknown)'}")


def print_commit_decomposition(commits: list[dict]) -> None:
    print_header("Commit decomposition (last 20)", "-")
    if not commits:
        print("  (no commits returned)")
        return

    bot_count = 0
    human_count = 0
    automated_subject_count = 0
    substantive_count = 0
    rows: list[tuple[str, str, str, str, str]] = []

    for c in commits:
        sha = c.get("sha", "")[:7]
        author = (c.get("author") or {}).get("login") or "<no-login>"
        is_bot = infer_is_bot(c, author)
        commit_info = c.get("commit", {}) or {}
        message = (commit_info.get("message") or "").split("\n", 1)[0]
        date = ((commit_info.get("author") or {}).get("date") or "")[:10]
        is_auto_subject = bool(AUTOMATED_SUBJECT_RE.match(message))

        # Count automated-subject commits regardless of bot/human tagging so
        # the displayed figure matches its label. A bot-authored
        # `chore(deps): bump X` is both a bot and an automated-subject commit.
        if is_auto_subject:
            automated_subject_count += 1

        if is_bot:
            bot_count += 1
            tag = "BOT"
        elif is_auto_subject:
            human_count += 1
            tag = "CFG"
        else:
            human_count += 1
            substantive_count += 1
            tag = "   "

        rows.append((tag, sha, date, author, message[:68]))

    newest = rows[0][2] if rows else "?"
    oldest = rows[-1][2] if rows else "?"
    print(f"  window:                 {newest} .. {oldest}")
    print(f"  bot authors:            {bot_count:>3d}")
    print(f"  human authors:          {human_count:>3d}")
    print(f"  automated subject:      {automated_subject_count:>3d}  (bump/chore(deps)/ci:/build:)")
    print(f"  SUBSTANTIVE commits:    {substantive_count:>3d}  (human author + non-automated subject)")
    print()
    for tag, sha, date, author, message in rows:
        print(f"  [{tag}] {sha}  {date}  {author:<28} {message}")
    print()
    print("  Note: 'substantive' here means 'human-authored + non-automated subject'.")
    print("  It does not detect README-only commits — the invoking agent should")
    print("  visually scan the subject listing for that pattern.")


def evaluate(package: str) -> None:
    print("\n" + "=" * 100)
    print(f"EVALUATING: {package}")
    print("=" * 100)

    pypi = fetch_pypi(package)
    if pypi is None:
        print(f"  pypi lookup failed for {package}; skipping")
        return

    info = pypi.get("info", {}) or {}
    urls = pypi.get("urls", []) or []
    print_pypi_section(pypi, info, urls)

    repo = extract_github_repo(info)
    if repo is None:
        print_header("GitHub", "-")
        print("  no GitHub repo discoverable from PyPI metadata project_urls or home_page")
        print("  skipping GitHub and commit-decomposition sections")
        return

    owner, name = repo
    repo_data = gh_api(f"repos/{owner}/{name}")
    if repo_data is None:
        print_header("GitHub", "-")
        print(f"  gh api failed for repos/{owner}/{name}")
        return
    open_issues, open_prs = fetch_issue_pr_counts(owner, name)
    print_github_section(owner, name, repo_data, open_issues, open_prs)

    commits = gh_api(f"repos/{owner}/{name}/commits?per_page=20")
    if commits is None or not isinstance(commits, list):
        print_header("Commit decomposition (last 20)", "-")
        print(f"  gh api failed for commits/{owner}/{name}")
        return
    print_commit_decomposition(commits)


def main() -> None:
    if len(sys.argv) < 2:
        print("usage: evaluate.py <package-name> [<package-name> ...]", file=sys.stderr)
        sys.exit(2)

    if not ensure_gh_ready():
        sys.exit(2)

    print(f"Captured: {datetime.now(timezone.utc).isoformat(timespec='seconds')}")

    for package in sys.argv[1:]:
        evaluate(package)


if __name__ == "__main__":
    main()
