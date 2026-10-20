#!/bin/bash
cd /tmp/elx-exp/cachex-306 || exit 1
echo "=== head 65a10ca ==="
git log -1 --format="%H %ci %s" 65a10ca487dfe8f2c826748573a72cfa047edf3a
echo "=== merge 7b4062b ==="
git log -1 --format="%H %ci %s" 7b4062bd8d139114ac865535a151165bc0c7d28d
echo "=== other b0d0e45 ==="
git log -1 --format="%H %ci %s" b0d0e45be65d048b538a4cf46819449dc1798d98
echo "=== parents head ==="
git rev-list --parents -n 1 65a10ca487dfe8f2c826748573a72cfa047edf3a
echo "=== parents merge ==="
git rev-list --parents -n 1 7b4062bd8d139114ac865535a151165bc0c7d28d
echo "=== applied vs head ==="
git diff 65a10ca487dfe8f2c826748573a72cfa047edf3a --stat
echo "=== pr306head ==="
git log -1 --format="%H %ci %s" pr306head
echo "=== done ==="
