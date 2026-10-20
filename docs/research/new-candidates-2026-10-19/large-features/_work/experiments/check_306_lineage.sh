#!/bin/bash
cd /tmp/elx-exp/cachex-306
echo "=== 65a10ca full patch (the default flip) ==="
git show 65a10ca487dfe8f2c826748573a72cfa047edf3a
echo
echo "=== fc4f2a0 vs merge-base 8c55685 ==="
git log --oneline 8c556854f8889bf06a27cdab7524b592658b6a58..fc4f2a0d9ce30842ce2eb0d51d9c3f743fc5867e | head -20
echo
echo "=== is fc4f2a0 an ancestor of head? ==="
git merge-base --is-ancestor fc4f2a0d9ce30842ce2eb0d51d9c3f743fc5867e 65a10ca487dfe8f2c826748573a72cfa047edf3a; echo ancestor_rc:$?
echo "=== is merge-base ancestor of head? ==="
git merge-base --is-ancestor 8c556854f8889bf06a27cdab7524b592658b6a58 65a10ca487dfe8f2c826748573a72cfa047edf3a; echo mb_ancestor_rc:$?
echo
echo "=== pull/306.diff vs git diff merge-base..head file lists ==="
echo "--- pull diff files ---"
grep "^diff --git" /mnt/c/Users/44773/Documents/elixir-swe-bench/docs/research/new-candidates-2026-10-19/large-features/_work/experiments/cachex-306.diff
echo "--- full mb..head files ---"
git diff 8c556854f8889bf06a27cdab7524b592658b6a58 65a10ca487dfe8f2c826748573a72cfa047edf3a --name-only
echo
echo "=== lrw.ex hooks delegate at base fc4f2a0 ==="
git show fc4f2a0d9ce30842ce2eb0d51d9c3f743fc5867e:lib/cachex/policy/lrw.ex | head -50
echo
echo "=== 7b4062b merge commit full ==="
git log -1 --format="%H %ci %s%nparents %P" 7b4062bd8d139114ac865535a151165bc0c7d28d
git rev-list --parents -n 1 7b4062bd8d139114ac865535a151165bc0c7d28d
