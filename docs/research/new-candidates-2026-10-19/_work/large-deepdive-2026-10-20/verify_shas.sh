#!/usr/bin/env bash
set -uo pipefail
WORK=/tmp/large-dd/repos
mkdir -p "$WORK"

verify_repo() {
  local name="$1" url="$2" base="$3" merge="$4" head="$5"
  local dir="$WORK/$name"
  echo "========== $name =========="
  if [ ! -d "$dir/.git" ]; then
    echo "-- full clone (needed for merge parents / later commits) --"
    git clone --quiet "$url" "$dir" 2>&1 | tail -5
  else
    echo "-- clone already exists --"
  fi
  cd "$dir"
  echo "HEAD: $(git rev-parse HEAD)"
  echo "default branch: $(git rev-parse --abbrev-ref HEAD)"

  echo "-- merge commit --"
  if git cat-file -e "$merge" 2>/dev/null; then
    echo "merge exists: $merge"
    git log -1 --format='merge: %H%nparents: %P%nsubject: %s%nauthor: %an <%ae>%ndate: %ci' "$merge"
    fp=$(git rev-parse "$merge^1" 2>/dev/null)
    sp=$(git rev-parse "$merge^2" 2>/dev/null || echo "(no second parent)")
    echo "first_parent: $fp"
    echo "second_parent: $sp"
    echo "claimed_base: $base"
    if [ "$fp" = "$base" ]; then echo "BASE_MATCH_FIRST_PARENT: YES"; else echo "BASE_MATCH_FIRST_PARENT: NO"; fi
    if [ "$sp" = "$head" ]; then echo "HEAD_MATCH_SECOND_PARENT: YES"; else echo "HEAD_MATCH_SECOND_PARENT: NO ($sp vs $head)"; fi
  else
    echo "merge commit $merge NOT FOUND"
  fi

  echo "-- base commit --"
  if git cat-file -e "$base" 2>/dev/null; then
    git log -1 --format='base: %H%nsubject: %s%ndate: %ci' "$base"
  else
    echo "base $base NOT FOUND"
  fi

  echo "-- head commit --"
  if git cat-file -e "$head" 2>/dev/null; then
    git log -1 --format='head: %H%nsubject: %s%ndate: %ci' "$head"
  else
    echo "head $head NOT FOUND"
  fi

  echo "-- files changed first-parent..merge --"
  git diff --stat "$merge^1" "$merge" 2>/dev/null || echo "diff failed"
  echo "-- name-status --"
  git diff --name-status "$merge^1" "$merge" 2>/dev/null
}

verify_repo beacon https://github.com/BeaconCMS/beacon.git \
  78c0fef0f88a4b83a397533e0ad35224dbb246a9 \
  1aa11357746073f0f9e321e1cdf2ba1e62a51682 \
  3952b1287cde487cff7c4767d856aca13e8b847a

verify_repo craftplan https://github.com/puemos/craftplan.git \
  ad9fb484e9e19076aae2c8c4dc48a736535e3a3c \
  46c0a6fa88ed5bd195531460129ddddbe055b663 \
  ff52fcab4e9b804c426b0dea09ac049ff663c2fe

verify_repo absinthe https://github.com/absinthe-graphql/absinthe.git \
  8e451950ea87083f50a06abf7b4246284bbe347d \
  c029a611640a764b687f6e3b5ce647880eff99fd \
  65ce8ccf6caaf696f38cfa1c95f997836420b88a
