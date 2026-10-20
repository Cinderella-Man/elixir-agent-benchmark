#!/bin/bash
# Apply broadway-344 and ecto_sql-703 diffs at claimed bases
EXP=/mnt/c/Users/44773/Documents/elixir-swe-bench/docs/research/new-candidates-2026-10-19/large-features/_work/experiments

echo "======== BROADWAY-344 ========"
cd /tmp/elx-exp/broadway-344 || exit 1
git checkout --quiet 8d29ca4e4d8e05eede10608a336ad70215d4886d
echo "BASE: $(git rev-parse HEAD) $(git log -1 --format='%ci %s')"
git apply --check "$EXP/broadway-344.diff"; echo CHECK:$?
git apply "$EXP/broadway-344.diff"; echo APPLY:$?
git add -A
echo "--- staged vs head f370304 ---"
git diff --cached f370304c533fca35cbc225856c3a1764e00bd834 --stat
echo "--- name-only residual (empty=match) ---"
git diff --cached f370304c533fca35cbc225856c3a1764e00bd834 --name-only
echo "--- head/merge commits ---"
git log -1 --format="%H %ci %s" f370304c533fca35cbc225856c3a1764e00bd834
git log -1 --format="%H %ci %s" 1151db21d51433b592b55421cd9689d8c81ca339
git rev-list --parents -n 1 f370304c533fca35cbc225856c3a1764e00bd834
git rev-list --parents -n 1 1151db21d51433b592b55421cd9689d8c81ca339
echo "--- PR commits ---"
git log --oneline 8d29ca4e4d8e05eede10608a336ad70215d4886d..f370304c533fca35cbc225856c3a1764e00bd834 2>/dev/null | head
echo "--- merge-base ---"
git merge-base 8d29ca4e4d8e05eede10608a336ad70215d4886d f370304c533fca35cbc225856c3a1764e00bd834

echo
echo "======== ECTO_SQL-703 ========"
cd /tmp/elx-exp/ecto_sql-703 || exit 1
git checkout --quiet 82e2eb36c8a5236876613fa9ec78d500a5e4288d
echo "BASE: $(git rev-parse HEAD) $(git log -1 --format='%ci %s')"
git apply --check "$EXP/ecto_sql-703.diff"; echo CHECK:$?
git apply "$EXP/ecto_sql-703.diff"; echo APPLY:$?
git add -A
echo "--- staged vs head a8e9f54 ---"
git diff --cached a8e9f54d8389aa19d6343a64f2cb6631c8c39492 --stat
echo "--- name-only residual (empty=match) ---"
git diff --cached a8e9f54d8389aa19d6343a64f2cb6631c8c39492 --name-only
echo "--- head/merge commits ---"
git log -1 --format="%H %ci %s" a8e9f54d8389aa19d6343a64f2cb6631c8c39492
git log -1 --format="%H %ci %s" af906441d22d369442354904c5127207bb72a58a
git rev-list --parents -n 1 a8e9f54d8389aa19d6343a64f2cb6631c8c39492
git rev-list --parents -n 1 af906441d22d369442354904c5127207bb72a58a
echo "--- PR commits ---"
git log --oneline 82e2eb36c8a5236876613fa9ec78d500a5e4288d..a8e9f54d8389aa19d6343a64f2cb6631c8c39492 2>/dev/null | head
echo "--- merge-base ---"
git merge-base 82e2eb36c8a5236876613fa9ec78d500a5e4288d a8e9f54d8389aa19d6343a64f2cb6631c8c39492
