#!/bin/bash
cd /tmp/elx-exp/cachex-306
echo "=== base..head full diff stat ==="
git diff fc4f2a0d9ce30842ce2eb0d51d9c3f743fc5867e 65a10ca487dfe8f2c826748573a72cfa047edf3a --stat
echo "=== commits in base..head ==="
git log --oneline fc4f2a0d9ce30842ce2eb0d51d9c3f743fc5867e..65a10ca487dfe8f2c826748573a72cfa047edf3a
echo "=== pr306head vs 65a10ca ==="
git rev-parse pr306head
echo "=== pull/306.diff file list vs full base..head ==="
git diff fc4f2a0d9ce30842ce2eb0d51d9c3f743fc5867e 65a10ca487dfe8f2c826748573a72cfa047edf3a --name-only
echo "=== 3-file residual content (ci/README/mix) ==="
git diff fc4f2a0d9ce30842ce2eb0d51d9c3f743fc5867e 65a10ca487dfe8f2c826748573a72cfa047edf3a -- .github/workflows/ci.yml README.md mix.exs | head -80
