#!/bin/bash
EXP=/mnt/c/Users/44773/Documents/elixir-swe-bench/docs/research/new-candidates-2026-10-19/large-features/_work/experiments

echo "======== BROADWAY-344 vs merge 1151db21 ========"
cd /tmp/elx-exp/broadway-344
git fetch origin pull/344/head:pr344head 2>&1 | tail -2
echo "pr344head: $(git rev-parse pr344head 2>/dev/null)"
git log -1 --format="%H %ci %s" pr344head 2>/dev/null
echo "--- applied(staged) vs merge commit ---"
git diff --cached 1151db21d51433b592b55421cd9689d8c81ca339 --stat
echo "--- residual names (empty=match) ---"
git diff --cached 1151db21d51433b592b55421cd9689d8c81ca339 --name-only
echo "--- PR body / commits via reflog of merge ---"
git log --oneline 8d29ca4e4d8e05eede10608a336ad70215d4886d..1151db21d51433b592b55421cd9689d8c81ca339 | head
echo "--- fetch PR head object ---"
git cat-file -t f370304c533fca35cbc225856c3a1764e00bd834 2>&1
git cat-file -t fb69a7a291877f5d3ed5e593db25d442aff90b56 2>&1

echo
echo "======== ECTO_SQL-703 vs merge af906441 ========"
cd /tmp/elx-exp/ecto_sql-703
git fetch origin pull/703/head:pr703head 2>&1 | tail -2
echo "pr703head: $(git rev-parse pr703head 2>/dev/null)"
git log -1 --format="%H %ci %s" pr703head 2>/dev/null
echo "--- applied(staged) vs merge commit ---"
git diff --cached af906441d22d369442354904c5127207bb72a58a --stat
echo "--- residual names (empty=match) ---"
git diff --cached af906441d22d369442354904c5127207bb72a58a --name-only
echo "--- commits base..merge ---"
git log --oneline 82e2eb36c8a5236876613fa9ec78d500a5e4288d..af906441d22d369442354904c5127207bb72a58a | head
echo "--- claimed head objects ---"
git cat-file -t a8e9f54d8389aa19d6343a64f2cb6631c8c39492 2>&1
git cat-file -t 8c7955df9dae7ed92959f2f7bdad814656a2bbef 2>&1
git cat-file -t cb3f237085abb8ec90e41e11e6449c98b94a34f7 2>&1
git cat-file -t 7fccc9f42317dfb3d60744594a92c9f31d786dc4 2>&1
