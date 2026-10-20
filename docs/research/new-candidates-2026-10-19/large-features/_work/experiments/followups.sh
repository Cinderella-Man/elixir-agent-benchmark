#!/bin/bash
echo "======== BROADWAY follow-ups #345 #349 #346 ========"
cd /tmp/elx-exp/broadway-344
for c in 3305b1c b6eeef7 52d3276; do
  echo "---- $c ----"
  git log -1 --format="%H %ci %s" $c
  git show $c --stat
done

echo
echo "======== ECTO rename ignore_errors ========"
cd /tmp/elx-exp/ecto_sql-703
git log -1 --format="%H %ci %s" ca7c7f5
git show ca7c7f5 --stat
echo "---- rename patch snippet ----"
git show ca7c7f5 -- lib/ecto/adapters/myxql/connection.ex test/ecto/adapters/myxql_test.exs | head -80

echo
echo "======== CACEX warmer fix #403 ========"
cd /tmp/elx-exp/cachex-341
git log -1 --format="%H %ci %s" 688837f
git show 688837f --stat

echo
echo "======== CACEX #341 landing commits (squash?) ========"
cd /tmp/elx-exp/cachex-341
git rev-list --parents -n 1 e700e966da6017337318bea205058144c9d5d332
git log --oneline e700e966da6017337318bea205058144c9d5d332~3..e700e966da6017337318bea205058144c9d5d332
echo "--- 3a0d7a9 vs 3f62838 ---"
git log -1 --format="%H %ci %s" 3a0d7a9
git rev-list --parents -n 1 3a0d7a9
