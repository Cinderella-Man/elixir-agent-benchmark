#!/bin/bash
cd /tmp/elx-exp/cachex-306
echo "=== each PR commit ==="
git log --format="%h %ci %s" fc4f2a0d9ce30842ce2eb0d51d9c3f743fc5867e..65a10ca487dfe8f2c826748573a72cfa047edf3a
echo
echo "=== final commit 65a10ca patch ==="
git show 65a10ca487dfe8f2c826748573a72cfa047edf3a --stat
echo
echo "=== default policy references at head ==="
git grep -n "LRW" 65a10ca487dfe8f2c826748573a72cfa047edf3a -- lib/ | head -30
echo
echo "=== lrw.ex default at head ==="
git show 65a10ca487dfe8f2c826748573a72cfa047edf3a:lib/cachex/policy/lrw.ex | head -80
echo
echo "=== merge-base base vs head ==="
git merge-base fc4f2a0d9ce30842ce2eb0d51d9c3f743fc5867e 65a10ca487dfe8f2c826748573a72cfa047edf3a
echo
echo "=== merge commit 7b4062b vs head tree ==="
git diff 65a10ca487dfe8f2c826748573a72cfa047edf3a 7b4062bd8d139114ac865535a151165bc0c7d28d --stat
