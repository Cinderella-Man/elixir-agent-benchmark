#!/bin/bash
# Compare applied (staged) tree to claimed PR head for each case
set -e

check() {
  local dir="$1" head="$2" label="$3"
  echo "======== $label ========"
  cd "$dir"
  git add -A
  echo "--- staged vs HEAD (base) stat ---"
  git diff --cached --stat | tail -3
  echo "--- staged vs claimed PR head $head ---"
  git diff --cached "$head" --stat || true
  echo "--- name-only staged vs head (empty = match) ---"
  git diff --cached "$head" --name-only || true
  echo "--- head commit ---"
  git log -1 --format="%H %ci %s" "$head" || true
}

check /tmp/elx-exp/cachex-341 3f6283852e3cbdd335431f90f36fd2ea725bef34 "cachex-341"
check /tmp/elx-exp/cachex-306 65a10ca487dfe8f2c826748573a72cfa047edf3a "cachex-306"
