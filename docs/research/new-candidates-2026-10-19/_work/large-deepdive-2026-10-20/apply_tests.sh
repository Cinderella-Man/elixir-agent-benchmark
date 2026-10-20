#!/usr/bin/env bash
set -uo pipefail
WORK=/tmp/large-dd
REPOS=$WORK/repos

apply_test() {
  local name="$1" repo="$2" base="$3" diff="$4" label="$5"
  local dir="/tmp/large-dd/apply-$name-$label"
  rm -rf "$dir"
  echo "==== APPLY $name at $label ($base) ===="
  git clone --quiet --no-checkout "$repo" "$dir" 2>&1 | tail -3
  cd "$dir"
  git checkout --quiet "$base" 2>&1 | tail -3
  echo "checked out: $(git rev-parse HEAD) $(git log -1 --format=%s | head -c 80)"
  echo "-- git apply --check --verbose --3way --"
  git apply --check --verbose --3way "$diff" 2>&1 | tail -30
  echo "check exit: $?"
  echo "-- git apply --3way (real) --"
  git apply --3way "$diff" 2>&1 | tail -30
  echo "apply exit: $?"
  echo "-- git status --"
  git status --short | head -30
  echo "-- git diff --stat (applied) --"
  git diff --stat | tail -20
  echo
}

# Beacon: claimed base 78c0fef vs first parent 86c9ffd
apply_test beacon https://github.com/BeaconCMS/beacon.git \
  78c0fef0f88a4b83a397533e0ad35224dbb246a9 \
  /tmp/large-dd/BeaconCMS_beacon-687.diff claimed-base
apply_test beacon https://github.com/BeaconCMS/beacon.git \
  86c9ffd2c46558313725fa7ffddbf72bd926b2b3 \
  /tmp/large-dd/BeaconCMS_beacon-687.diff first-parent

# Craftplan: claimed base == first parent
apply_test craftplan https://github.com/puemos/craftplan.git \
  ad9fb484e9e19076aae2c8c4dc48a736535e3a3c \
  /tmp/large-dd/puemos_craftplan-51.diff first-parent

# Absinthe: claimed base 8e451950 vs first parent 8fba7023
apply_test absinthe https://github.com/absinthe-graphql/absinthe.git \
  8e451950ea87083f50a06abf7b4246284bbe347d \
  /tmp/large-dd/absinthe-graphql_absinthe-1404.diff claimed-base
apply_test absinthe https://github.com/absinthe-graphql/absinthe.git \
  8fba7023f944e093036b89131b9e47a4ad2f7ecc \
  /tmp/large-dd/absinthe-graphql_absinthe-1404.diff first-parent

echo "==== also try git apply WITHOUT --3way (classic) at first parents ===="
for spec in \
  "beacon https://github.com/BeaconCMS/beacon.git 86c9ffd2c46558313725fa7ffddbf72bd926b2b3 /tmp/large-dd/BeaconCMS_beacon-687.diff" \
  "craftplan https://github.com/puemos/craftplan.git ad9fb484e9e19076aae2c8c4dc48a736535e3a3c /tmp/large-dd/puemos_craftplan-51.diff" \
  "absinthe https://github.com/absinthe-graphql/absinthe.git 8fba7023f944e093036b89131b9e47a4ad2f7ecc /tmp/large-dd/absinthe-graphql_absinthe-1404.diff"
do
  set -- $spec
  name=$1; repo=$2; base=$3; diff=$4
  dir="/tmp/large-dd/classic-$name"
  rm -rf "$dir"
  git clone --quiet --depth 1 "$repo" "$dir" 2>&1 | tail -2
  # shallow clone won't have base; fetch base specifically
  cd "$dir"
  git fetch --quiet --depth 1 origin "$base" 2>&1 | tail -2
  git checkout --quiet "$base" 2>&1 | tail -2
  echo "==== classic apply $name at $(git rev-parse --short HEAD) ===="
  git apply --verbose --check "$diff" 2>&1 | tail -15
  echo "check exit: $?"
  git apply --verbose "$diff" 2>&1 | tail -15
  echo "apply exit: $?"
  git status --short | head -20
  echo
done
