#!/usr/bin/env bash
set -euo pipefail
WORK=${WORK:-/tmp/large-dd}
mkdir -p "$WORK"
cd "$WORK"

fetch_one() {
  local repo="$1" pr="$2"
  local slug="${repo//\//_}"
  echo "===== $repo #$pr ====="
  curl -sL "https://api.github.com/repos/$repo/pulls/$pr" -o "${slug}-${pr}.json"
  curl -sL "https://github.com/$repo/pull/$pr.diff" -o "${slug}-${pr}.diff"
  curl -sL "https://github.com/$repo/pull/$pr.patch" -o "${slug}-${pr}.patch"
  python3 - "$slug" "$pr" <<'PY'
import json, sys
slug, pr = sys.argv[1], sys.argv[2]
d = json.load(open(f"{slug}-{pr}.json"))
print("title:", d.get("title"))
print("state:", d.get("state"), "merged:", d.get("merged"))
print("created:", d.get("created_at"), "merged_at:", d.get("merged_at"), "closed_at:", d.get("closed_at"))
print("user:", (d.get("user") or {}).get("login"))
b = d.get("base") or {}
h = d.get("head") or {}
print("base_sha:", b.get("sha"))
print("base_ref:", b.get("ref"))
print("head_sha:", h.get("sha"))
print("head_ref:", h.get("ref"))
print("merge_commit_sha:", d.get("merge_commit_sha"))
print("commits:", d.get("commits"), "additions:", d.get("additions"), "deletions:", d.get("deletions"), "changed_files:", d.get("changed_files"))
body = d.get("body") or ""
print("body_len:", len(body))
print("--- body ---")
print(body[:2500])
print("--- end body ---")
PY
  echo "--- file sizes ---"
  wc -c "${slug}-${pr}.diff" "${slug}-${pr}.patch"
  echo "--- diffstat (paths) ---"
  grep -E '^diff --git ' "${slug}-${pr}.diff" | sed 's|diff --git a/||; s| b/.*||' || true
  echo "--- patch commit headers ---"
  grep -E '^(From |Subject:|Date:)' "${slug}-${pr}.patch" | head -80 || true
  echo
}

fetch_one BeaconCMS/beacon 687
fetch_one puemos/craftplan 51
fetch_one absinthe-graphql/absinthe 1404
