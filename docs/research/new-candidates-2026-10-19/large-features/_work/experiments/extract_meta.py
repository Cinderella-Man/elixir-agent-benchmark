#!/usr/bin/env python3
"""Extract PR metadata (SHAs, dates, titles) from saved GitHub PR HTML pages and .diff files."""
import re, html, os, json, glob

# Works under WSL (POSIX) and Windows
EXP = os.path.dirname(os.path.abspath(__file__))
# .../new-candidates-2026-10-19/large-features/_work/experiments -> up 3
_CAND = os.path.dirname(os.path.dirname(os.path.dirname(EXP)))
PRPAGES = os.path.join(_CAND, "_work", "prpages")
if not os.path.isdir(PRPAGES):
    PRPAGES = r"C:\Users\44773\Documents\elixir-swe-bench\docs\research\new-candidates-2026-10-19\_work\prpages"

def files_from_diff(path):
    files = []
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            if line.startswith("diff --git "):
                # diff --git a/path b/path
                m = re.match(r"diff --git a/(.*) b/(.*)", line.strip())
                if m:
                    files.append(m.group(2))
    return files

def extract_html(name):
    path = os.path.join(PRPAGES, name)
    t = open(path, encoding="utf-8", errors="replace").read()
    out = {"file": name, "len": len(t)}
    m = re.search(r"<title>(.*?)</title>", t, re.S)
    if m:
        out["title"] = html.unescape(re.sub(r"\s+", " ", m.group(1))).strip()[:250]
    # JSON embedded oids
    for key in ("baseRefOid", "headRefOid", "oid", "commitOid", "currentOid"):
        found = re.findall(r'"%s"\s*:\s*"([0-9a-f]{40})"' % key, t)
        if found:
            out[key] = list(dict.fromkeys(found))[:8]
    # commit links
    commits = re.findall(r"/commit/([0-9a-f]{40})", t)
    if commits:
        out["commit_links"] = list(dict.fromkeys(commits))[:20]
    # short shas in clipboard / css-truncate
    shorts = re.findall(r"\b([0-9a-f]{7})\b", t)
    # dates
    dates = re.findall(r"datetime=\"([^\"]+)\"", t)
    if dates:
        out["datetimes"] = list(dict.fromkeys(dates))[:12]
    # merged / closed wording
    for label, pat in [
        ("merged", r"merged this pull request"),
        ("closed", r"closed this"),
        ("commits_count", r"(\d+)\s+commits?"),
    ]:
        if re.search(pat, t, re.I):
            out.setdefault("flags", []).append(label)
    # conversation first line body
    m = re.search(r"pull_request_body[\s\S]{0,2000}?<p>([\s\S]{0,800}?)</p>", t)
    if m:
        body = re.sub(r"<[^>]+>", " ", m.group(1))
        out["body_snip"] = html.unescape(re.sub(r"\s+", " ", body)).strip()[:400]
    # look for "into <base>" branch names
    for m in re.finditer(r"into\s+<span[^>]*>([^<]+)</span>", t):
        out.setdefault("into", []).append(m.group(1))
    return out

def extract_diff_stats(path):
    adds = dels = 0
    files = []
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            if line.startswith("diff --git "):
                m = re.match(r"diff --git a/(.*) b/(.*)", line.strip())
                files.append(m.group(2) if m else "?")
            elif line.startswith("+") and not line.startswith("+++"):
                adds += 1
            elif line.startswith("-") and not line.startswith("---"):
                dels += 1
    return {"path": os.path.basename(path), "files": files, "adds": adds, "dels": dels,
            "nfiles": len(files), "bytes": os.path.getsize(path)}

def main():
    report = {"diffs": [], "html": []}
    for diff in sorted(glob.glob(os.path.join(EXP, "*.diff"))):
        report["diffs"].append(extract_diff_stats(diff))
    for name in ["cachex-341.html", "cachex-306.html", "broadway-344.html", "ecto_sql-703.html"]:
        try:
            report["html"].append(extract_html(name))
        except Exception as e:
            report["html"].append({"file": name, "error": str(e)})
    out = os.path.join(EXP, "pr_meta_extract.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
    print(json.dumps(report, indent=2)[:12000])
    print("\nWrote", out)

if __name__ == "__main__":
    main()
