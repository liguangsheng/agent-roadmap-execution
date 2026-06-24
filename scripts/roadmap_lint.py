#!/usr/bin/env python3
"""Validate roadmap structure used by the roadmap-driven skill."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path


MILESTONE_STATUSES = {"draft", "planned", "in-progress", "done"}
SPRINT_STATUSES = {"planned", "in-progress", "blocked", "done"}
MILESTONE_DIR_RE = re.compile(r"^M\d+(?:\.\d+)?-.+$")
SPRINT_FILE_RE = re.compile(r"^S\d+(?:\.\d+)?-.+\.md$")
STATUS_RE = re.compile(r"^Status:\s*`?([A-Za-z-]+)`?\s*$", re.MULTILINE)
LINK_RE = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
DEFAULT_ROADMAP = ".agents/roadmap"


@dataclass(frozen=True)
class Issue:
    severity: str
    path: Path
    message: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate roadmap layout, links, statuses, and resume points."
    )
    parser.add_argument(
        "repo_root",
        nargs="?",
        default=".",
        help="Repository root containing .agents/roadmap by default.",
    )
    parser.add_argument(
        "--roadmap",
        default=DEFAULT_ROADMAP,
        help=f"Roadmap path relative to repo root. Defaults to {DEFAULT_ROADMAP}.",
    )
    parser.add_argument(
        "--allow-missing",
        action="store_true",
        help="Exit successfully when the roadmap directory does not exist.",
    )
    parser.add_argument(
        "--strict-warnings",
        action="store_true",
        help="Treat warnings as errors.",
    )
    return parser.parse_args()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def rel(path: Path, base: Path) -> Path:
    try:
        return path.relative_to(base)
    except ValueError:
        return path


def extract_status(text: str) -> str | None:
    match = STATUS_RE.search(text)
    if not match:
        return None
    return match.group(1).lower()


def section(text: str, name: str) -> str:
    pattern = re.compile(
        rf"^##\s+{re.escape(name)}\s*$\n(?P<body>.*?)(?=^##\s+|\Z)",
        re.MULTILINE | re.DOTALL,
    )
    match = pattern.search(text)
    return match.group("body").strip() if match else ""


def is_external_link(href: str) -> bool:
    href = href.strip()
    return (
        not href
        or href.startswith("#")
        or "://" in href
        or href.startswith("mailto:")
    )


def clean_href(href: str) -> str:
    href = href.strip()
    href = href.split("#", 1)[0]
    href = href.split("?", 1)[0]
    return href


def markdown_links(text: str) -> list[str]:
    return [clean_href(match.group(1)) for match in LINK_RE.finditer(text)]


def check_links(path: Path, repo_root: Path, issues: list[Issue]) -> None:
    text = read_text(path)
    resolved_root = repo_root.resolve()
    for href in markdown_links(text):
        if is_external_link(href):
            continue
        target = (path.parent / href).resolve()
        try:
            target.relative_to(resolved_root)
        except ValueError:
            issues.append(Issue("WARN", path, f"link leaves repo root: {href}"))
            continue
        if not target.exists():
            issues.append(Issue("ERROR", path, f"broken markdown link: {href}"))


def check_layout(
    roadmap_root: Path, roadmap_label: str, issues: list[Issue]
) -> list[Path]:
    milestone_dirs: list[Path] = []
    for child in sorted(roadmap_root.iterdir()):
        if child.name == "README.md" and child.is_file():
            continue
        if child.is_dir() and MILESTONE_DIR_RE.match(child.name):
            milestone_dirs.append(child)
            continue
        issues.append(
            Issue(
                "ERROR",
                child,
                f"unexpected item in {roadmap_label}; only README.md and Mxx-* milestone directories are allowed",
            )
        )

    for milestone_dir in milestone_dirs:
        for child in sorted(milestone_dir.iterdir()):
            if child.name == "README.md" and child.is_file():
                continue
            if child.is_file() and SPRINT_FILE_RE.match(child.name):
                continue
            issues.append(
                Issue(
                    "ERROR",
                    child,
                    "unexpected item in milestone directory; only README.md and Sxxx-*.md sprint files are allowed",
                )
            )

    return milestone_dirs


def sprint_table_entries(text: str) -> list[tuple[str, str]]:
    entries: list[tuple[str, str]] = []
    in_table = False
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped.startswith("|"):
            if in_table:
                break
            continue
        cells = [cell.strip() for cell in stripped.strip("|").split("|")]
        if len(cells) < 2:
            continue
        if cells[0].lower() == "sprint" or set(cells[0]) <= {"-", ":"}:
            in_table = True
            continue
        links = markdown_links(cells[0])
        if not links:
            continue
        status = cells[1].strip("`").lower()
        entries.append((Path(links[0]).name, status))
        in_table = True
    return entries


def expected_milestone_status(statuses: list[str]) -> str:
    if not statuses:
        return "draft"
    if all(status == "done" for status in statuses):
        return "done"
    if all(status == "planned" for status in statuses):
        return "planned"
    return "in-progress"


def check_root_readme(
    roadmap_root: Path, milestone_dirs: list[Path], issues: list[Issue]
) -> None:
    root_readme = roadmap_root / "README.md"
    if not root_readme.exists():
        issues.append(Issue("ERROR", root_readme, "missing roadmap root README.md"))
        return

    linked_milestones: set[str] = set()
    for href in markdown_links(read_text(root_readme)):
        if is_external_link(href):
            continue
        parts = Path(href).parts
        if parts and MILESTONE_DIR_RE.match(parts[0]):
            linked_milestones.add(parts[0])

    for milestone_dir in milestone_dirs:
        if milestone_dir.name not in linked_milestones:
            issues.append(
                Issue(
                    "WARN",
                    root_readme,
                    f"milestone directory is not linked from root README: {milestone_dir.name}",
                )
            )


def check_milestone(
    milestone_dir: Path, roadmap_root: Path, active_sprints: list[Path], issues: list[Issue]
) -> None:
    readme = milestone_dir / "README.md"
    if not readme.exists():
        issues.append(Issue("ERROR", readme, "missing milestone README.md"))
        return

    text = read_text(readme)
    milestone_status = extract_status(text)
    if milestone_status is None:
        issues.append(Issue("ERROR", readme, "missing milestone Status line"))
    elif milestone_status not in MILESTONE_STATUSES:
        issues.append(
            Issue("ERROR", readme, f"invalid milestone status: {milestone_status}")
        )

    sprint_files = {
        path.name: path
        for path in sorted(milestone_dir.glob("S*.md"))
        if path.is_file() and SPRINT_FILE_RE.match(path.name)
    }
    table_entries = sprint_table_entries(text)
    table_status_by_file: dict[str, str] = {}
    table_order: list[str] = []

    for file_name, status in table_entries:
        if file_name in table_status_by_file:
            issues.append(Issue("ERROR", readme, f"duplicate sprint table entry: {file_name}"))
            continue
        table_status_by_file[file_name] = status
        table_order.append(file_name)
        if status not in SPRINT_STATUSES:
            issues.append(Issue("ERROR", readme, f"invalid sprint status for {file_name}: {status}"))
        if file_name not in sprint_files:
            issues.append(Issue("ERROR", readme, f"sprint table links missing file: {file_name}"))

    for file_name, sprint_file in sprint_files.items():
        sprint_status = extract_status(read_text(sprint_file))
        table_status = table_status_by_file.get(file_name)
        if table_status is None:
            issues.append(Issue("ERROR", readme, f"sprint file is not listed in Sprint Status table: {file_name}"))
        if sprint_status is None:
            issues.append(Issue("WARN", sprint_file, "missing sprint Status line"))
        elif sprint_status not in SPRINT_STATUSES:
            issues.append(Issue("ERROR", sprint_file, f"invalid sprint status: {sprint_status}"))
        elif table_status is not None and sprint_status != table_status:
            issues.append(
                Issue(
                    "ERROR",
                    sprint_file,
                    f"sprint Status line ({sprint_status}) does not match milestone table ({table_status})",
                )
            )

    effective_statuses: list[str] = []
    for file_name in table_order:
        status = table_status_by_file[file_name]
        if status in SPRINT_STATUSES:
            effective_statuses.append(status)
            if status == "in-progress" and file_name in sprint_files:
                active_sprints.append(sprint_files[file_name])

    expected_status = expected_milestone_status(effective_statuses)
    if milestone_status in MILESTONE_STATUSES and milestone_status != expected_status:
        issues.append(
            Issue(
                "ERROR",
                readme,
                f"milestone status is {milestone_status}, expected {expected_status} from sprint statuses",
            )
        )

    check_resume_point(readme, text, table_order, table_status_by_file, issues)


def check_resume_point(
    readme: Path,
    text: str,
    table_order: list[str],
    table_status_by_file: dict[str, str],
    issues: list[Issue],
) -> None:
    if not table_order:
        return

    in_progress = [
        file_name
        for file_name in table_order
        if table_status_by_file.get(file_name) == "in-progress"
    ]
    non_done = [
        file_name
        for file_name in table_order
        if table_status_by_file.get(file_name) != "done"
    ]
    if not non_done:
        return

    expected = in_progress[0] if in_progress else non_done[0]
    resume = section(text, "Resume Point")
    if not resume:
        issues.append(Issue("WARN", readme, "missing Resume Point section"))
        return

    resume_lower = resume.lower()
    has_generic_rule = "first sprint whose status is not" in resume_lower
    if expected not in resume and not has_generic_rule:
        issues.append(
            Issue(
                "WARN",
                readme,
                f"Resume Point does not mention expected next sprint: {expected}",
            )
        )


def main() -> int:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    roadmap_root = (repo_root / args.roadmap).resolve()
    issues: list[Issue] = []

    if not roadmap_root.exists():
        if args.allow_missing:
            print(f"roadmap-lint: {rel(roadmap_root, repo_root)} missing; skipped")
            return 0
        legacy_roadmap = repo_root / "docs/roadmap"
        suffix = ""
        if args.roadmap == DEFAULT_ROADMAP and legacy_roadmap.exists():
            suffix = "; legacy docs/roadmap exists, migrate it or rerun with --roadmap docs/roadmap"
        print(
            f"roadmap-lint: {rel(roadmap_root, repo_root)} does not exist{suffix}",
            file=sys.stderr,
        )
        return 1

    if not roadmap_root.is_dir():
        print(f"roadmap-lint: {rel(roadmap_root, repo_root)} is not a directory", file=sys.stderr)
        return 1

    milestone_dirs = check_layout(roadmap_root, args.roadmap, issues)
    check_root_readme(roadmap_root, milestone_dirs, issues)

    active_sprints: list[Path] = []
    for milestone_dir in milestone_dirs:
        check_milestone(milestone_dir, roadmap_root, active_sprints, issues)

    for md_file in sorted(roadmap_root.rglob("*.md")):
        check_links(md_file, repo_root, issues)

    if len(active_sprints) > 1:
        active_list = ", ".join(str(rel(path, repo_root)) for path in active_sprints)
        issues.append(
            Issue("ERROR", roadmap_root, f"multiple in-progress sprints: {active_list}")
        )

    errors = [issue for issue in issues if issue.severity == "ERROR"]
    warnings = [issue for issue in issues if issue.severity == "WARN"]

    for issue in issues:
        print(f"{issue.severity}: {rel(issue.path, repo_root)}: {issue.message}")

    if errors or (warnings and args.strict_warnings):
        print(
            f"roadmap-lint: {len(errors)} error(s), {len(warnings)} warning(s)",
            file=sys.stderr,
        )
        return 1

    if warnings:
        print(f"roadmap-lint: 0 error(s), {len(warnings)} warning(s)")
        return 0

    print("roadmap-lint: ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
