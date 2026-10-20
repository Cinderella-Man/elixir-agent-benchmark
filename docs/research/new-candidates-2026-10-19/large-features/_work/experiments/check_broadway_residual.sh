#!/bin/bash
echo "======== BROADWAY residual detail ========"
cd /tmp/elx-exp/broadway-344
echo "--- pull/344.diff files ---"
grep "^diff --git" "$EXP/broadway-344.diff" 2>/dev/null || grep "^diff --git" /mnt/c/Users/44773/Documents/elixir-swe-bench/docs/research/new-candidates-2026-10-19/large-features/_work/experiments/broadway-344.diff
echo "--- full base..pr-head files ---"
git diff 8d29ca4e4d8e05eede10608a336ad70215d4886d f370304c533fca35cbc225856c3a1764e00bd834 --name-only
echo "--- base..pr-head stat ---"
git diff 8d29ca4e4d8e05eede10608a336ad70215d4886d f370304c533fca35cbc225856c3a1764e00bd834 --stat
echo "--- applied vs pr-head (empty=match) ---"
git diff --cached f370304c533fca35cbc225856c3a1764e00bd834 --stat
echo "--- PR commits ---"
git log --oneline 8d29ca4e4d8e05eede10608a336ad70215d4886d..f370304c533fca35cbc225856c3a1764e00bd834
echo "--- merge commit 1151db2 full stat vs base ---"
git diff 8d29ca4e4d8e05eede10608a336ad70215d4886d 1151db21d51433b592b55421cd9689d8c81ca339 --stat
echo "--- residual content applied vs merge ---"
git diff --cached 1151db21d51433b592b55421cd9689d8c81ca339 -- lib/broadway.ex lib/broadway/topology/producer_stage.ex | head -100

echo
echo "======== ECTO claimed intermediate SHAs ========"
cd /tmp/elx-exp/ecto_sql-703
echo "pr703head: $(git rev-parse pr703head)"
git log --oneline 82e2eb36c8a5236876613fa9ec78d500a5e4288d..pr703head | head
echo "--- 7fccc9f ---"
git log -1 --format="%H %ci %s" 7fccc9f42317dfb3d60744594a92c9f31d786dc4 2>&1
