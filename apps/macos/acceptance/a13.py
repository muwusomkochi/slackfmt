"""A13: every upstream test name at V6 (551c592) is present and passes on each branch given.

Run from the repo root, with a worktree to switch between branches in:
  python3 -I apps/macos/acceptance/a13.py <worktree> main fix/hard-breaks ...
"""
import json, pathlib, subprocess, sys, tempfile

V6 = "551c592"
worktree, branches = pathlib.Path(sys.argv[1]), sys.argv[2:]


def run(*command, **options):
    return subprocess.run(command, cwd=worktree, capture_output=True, text=True, **options)


def tests(branch):
    run("git", "switch", "-q", "--detach", branch, check=True)
    run("npx", "--yes", "pnpm@10.30.1", "install", "--frozen-lockfile", "--ignore-scripts", check=True)
    with tempfile.NamedTemporaryFile(suffix=".json") as out:
        run("npx", "--yes", "pnpm@10.30.1", "exec", "vitest", "run", "--project", "@slackfmt/core",
            "--reporter=json", f"--outputFile={out.name}")
        report = json.load(open(out.name))
    broken = [pathlib.Path(file["name"]).name for file in report["testResults"] if not file["assertionResults"]]
    if broken:
        sys.exit(f"{branch}: these test files didn't run: {broken}")
    return {
        " > ".join([pathlib.Path(file["name"]).name, *test["ancestorTitles"], test["title"]]): test["status"]
        for file in report["testResults"] for test in file["assertionResults"]
    }


upstream = tests(V6)
print(f"V6 {V6}: {len(upstream)} tests, {sum(s == 'passed' for s in upstream.values())} passing")
for branch in branches:
    found = tests(branch)
    missing = sorted(upstream.keys() - found.keys())
    failing = sorted(name for name, status in found.items() if status != "passed")
    changed = run("git", "diff", "--name-status", "--diff-filter=MD", V6, branch, "--", "packages/core/tests").stdout.split()
    sha = run("git", "rev-parse", "--short", branch).stdout.strip()
    print(f"{branch} {sha}: {len(found)} tests, {len(failing)} failing; {len(upstream) - len(missing)} of V6's {len(upstream)} names present; "
          f"upstream test files changed: {changed or 'none'}" + (f"; missing {missing}" if missing else "") + (f"; failing {failing}" if failing else ""))
