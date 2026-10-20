#!/bin/bash
# Snapshot applied trees to Windows-visible path for mix tests
DEST=/mnt/c/Users/44773/Documents/elixir-swe-bench/docs/research/new-candidates-2026-10-19/large-features/_work/experiments/trees
mkdir -p "$DEST"
for name in cachex-341 cachex-306 broadway-344 ecto_sql-703; do
  echo "=== snapshot $name ==="
  rm -rf "$DEST/$name"
  mkdir -p "$DEST/$name"
  # copy working tree without .git for smaller footprint? keep .git for SHA checks
  cp -a /tmp/elx-exp/$name/. "$DEST/$name/"
  echo "ok $(du -sh $DEST/$name | cut -f1)"
done
ls "$DEST"
