"""Write loop 1's fixtures to a folder outside this repo, read at run time from the PRD.

fixture.md is the PRD's Appendix A and fixture.html its Appendix E, taken from the precedent clone
at the ratified sha. fixture-20k.md is fixture.md repeated and cut at a line end at or under
20,000 characters (PRD section 8). Their text is never committed to this public fork, so this
prints only lengths and sha256s.

Run: python3 -I probes/loop1/fixtures.py
Env: PRECEDENT (default ~/Development/precedent), PRD_SHA (default 2377f6e),
     SLACKFMT_FIXTURES (default $TMPDIR/slackfmt-loop1-fixtures)
"""
import hashlib, os, pathlib, subprocess, tempfile

PRECEDENT = os.environ.get("PRECEDENT", os.path.expanduser("~/Development/precedent"))
SHA = os.environ.get("PRD_SHA", "2377f6e")
OUT = pathlib.Path(os.environ.get("SLACKFMT_FIXTURES", pathlib.Path(tempfile.gettempdir()) / "slackfmt-loop1-fixtures"))
LIMIT = 20_000

prd = subprocess.run(
    ["git", "-C", PRECEDENT, "show", f"{SHA}:docs/engagements/slackfmt/PRD.md"],
    check=True, capture_output=True, text=True,
).stdout.split("\n")


def appendix(heading: str, opener: str) -> str:
    start = prd.index(heading)
    end = next((i for i in range(start + 1, len(prd)) if prd[i].startswith("## ")), len(prd))
    section = prd[start + 1:end]
    first = section.index(opener) + 1
    last = max(i for i, line in enumerate(section) if line == "```")
    return "\n".join(section[first:last]) + "\n"


def cut_20k(text: str) -> str:
    repeated = text * (LIMIT // len(text) + 2)
    return repeated[: repeated.rfind("\n", 0, LIMIT + 1) + 1]


fixture_md = appendix("## Appendix A: fixture.md", "```")
fixture_html = appendix("## Appendix E: fixture.html", "```html")
files = {
    "fixture.md": fixture_md,
    "fixture.html": fixture_html,
    "fixture-20k.md": cut_20k(fixture_md),
}

OUT.mkdir(parents=True, exist_ok=True)
print(f"PRD {SHA} read from {PRECEDENT}; fixtures written to {OUT}")
for name, text in files.items():
    (OUT / name).write_text(text, encoding="utf-8")
    utf16 = len(text.encode("utf-16-le")) // 2
    digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
    print(f"{name}: {len(text.splitlines())} lines, {utf16} UTF-16 units, sha256 {digest}")
