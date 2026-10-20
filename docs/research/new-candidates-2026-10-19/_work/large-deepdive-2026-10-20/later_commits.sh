#!/usr/bin/env bash
set -uo pipefail

echo "################ BEACON later commits detail ################"
cd /tmp/large-dd/repos/beacon
for c in c951d31 98ed94e c243a49 0f0817f e721fac; do
  echo "==== $c ===="
  git log -1 --format='%H%n%s%n%an %ci%n' $c
  git show --stat --format='' $c | head -25
  echo
done

echo "-- #746 full message --"
git log -1 --format='%B' c951d31 | head -40
echo "-- #749 full message --"
git log -1 --format='%B' 98ed94e | head -40

echo
echo "################ CRAFTPLAN later / head reachability ################"
cd /tmp/large-dd/repos/craftplan
echo "-- is ff52fcab reachable from any ref? --"
git branch -a --contains ff52fcab4e9b804c426b0dea09ac049ff663c2fe 2>&1 | head
git name-rev ff52fcab4e9b804c426b0dea09ac049ff663c2fe 2>&1 | head
echo "-- batching.ex change 024ceb7 --"
git show --stat --format='%H %s' 024ceb7 | head -20
git log -1 --format='%B' 024ceb7 | head -20
echo "-- any later commits mentioning batch/production --"
git log --oneline 46c0a6fa88ed5bd195531460129ddddbe055b663..HEAD | head -30

echo
echo "################ ABSINTHE later + Inspect chain ################"
cd /tmp/large-dd/repos/absinthe
echo "-- render.ex Inspect impl at merge --"
git show c029a611640a764b687f6e3b5ce647880eff99fd:lib/absinthe/language/render.ex | head -40
echo "-- document.ex Inspect impl at merge --"
git show c029a611640a764b687f6e3b5ce647880eff99fd:lib/absinthe/language/document.ex | tail -20
echo "-- 20dacc6c later render change --"
git log -1 --format='%H %s%n%b' 20dacc6c | head -25
git show --stat --format='' 20dacc6c | head -15
echo "-- put_description in grammar at merge --"
git show c029a611640a764b687f6e3b5ce647880eff99fd:src/absinthe_parser.yrl | grep -n -A2 -B2 'put_description\|DescriptionDefinition' | head -40

echo
echo "################ classic apply at claimed base for beacon (expect fail) ################"
dir=/tmp/large-dd/classic-beacon-claimed
rm -rf "$dir"
git clone --quiet --depth 1 https://github.com/BeaconCMS/beacon.git "$dir"
cd "$dir"
git fetch --quiet --depth 1 origin 78c0fef0f88a4b83a397533e0ad35224dbb246a9
git checkout --quiet 78c0fef0f88a4b83a397533e0ad35224dbb246a9
echo "classic apply at claimed base:"
git apply --verbose --check /tmp/large-dd/BeaconCMS_beacon-687.diff 2>&1 | tail -25
echo "check exit: $?"
