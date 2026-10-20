#!/bin/bash
# Later commits on the same files after each PR merge
echo "======== CACEX-341 later commits on touched files ========"
cd /tmp/elx-exp/cachex-341
git fetch origin main 2>&1 | tail -1
# merge landed as e700e96 on main; find that and log after
git fetch origin e700e966da6017337318bea205058144c9d5d332 2>&1 | tail -1
echo "--- is e700e96 on main? ---"
git merge-base --is-ancestor e700e966da6017337318bea205058144c9d5d332 origin/main && echo YES || echo NO
echo "--- log after e700e96 touching PR files ---"
git log e700e966da6017337318bea205058144c9d5d332..origin/main --oneline -- \
  lib/cachex.ex lib/cachex/actions/warm.ex lib/cachex/services.ex \
  lib/cachex/services/incubator.ex lib/cachex/services/informant.ex \
  lib/cachex/services/steward.ex lib/cachex/spec.ex lib/cachex/spec/validator.ex \
  test/cachex/actions/warm_test.exs test/cachex/options_test.exs | head -40
echo "--- count ---"
git log e700e966da6017337318bea205058144c9d5d332..origin/main --oneline -- \
  lib/cachex.ex lib/cachex/actions/warm.ex lib/cachex/services.ex \
  lib/cachex/services/incubator.ex lib/cachex/services/informant.ex \
  lib/cachex/services/steward.ex lib/cachex/spec.ex lib/cachex/spec/validator.ex | wc -l

echo
echo "======== CACEX-306 later commits on touched files ========"
cd /tmp/elx-exp/cachex-306
git fetch origin main 2>&1 | tail -1
echo "--- is 7b4062b on main? ---"
git merge-base --is-ancestor 7b4062bd8d139114ac865535a151165bc0c7d28d origin/main && echo YES || echo NO
echo "--- log after 7b4062b touching PR files ---"
git log 7b4062bd8d139114ac865535a151165bc0c7d28d..origin/main --oneline -- \
  lib/cachex/policy.ex lib/cachex/policy/lrw.ex lib/cachex/policy/lrw/evented.ex \
  lib/cachex/policy/lrw/scheduled.ex lib/cachex/services.ex \
  test/cachex/policy/lrw/evented_test.exs test/cachex/policy/lrw/scheduled_test.exs \
  test/cachex/policy_test.exs test/cachex/services_test.exs | head -40

echo
echo "======== BROADWAY-344 later commits ========"
cd /tmp/elx-exp/broadway-344
git fetch origin main 2>&1 | tail -1
echo "--- log after 1151db2 touching PR files ---"
git log 1151db21d51433b592b55421cd9689d8c81ca339..origin/main --oneline -- \
  lib/broadway.ex lib/broadway/config_storage.ex lib/broadway/config_storage/ets.ex \
  lib/broadway/config_storage/persistent_term.ex lib/broadway/topology.ex \
  test/broadway/config_storage_test.exs | head -40

echo
echo "======== ECTO_SQL-703 later commits ========"
cd /tmp/elx-exp/ecto_sql-703
git fetch origin master 2>&1 | tail -1
git fetch origin main 2>&1 | tail -1
echo "--- log after af90644 touching PR files ---"
git log af906441d22d369442354904c5127207bb72a58a..origin/master --oneline -- \
  integration_test/myxql/upsert_all_test.exs lib/ecto/adapters/myxql.ex \
  lib/ecto/adapters/myxql/connection.ex lib/ecto/adapters/postgres/connection.ex \
  lib/ecto/adapters/sql.ex lib/ecto/adapters/sql/connection.ex \
  lib/ecto/adapters/tds/connection.ex test/ecto/adapters/myxql_test.exs 2>/dev/null | head -40
git log af906441d22d369442354904c5127207bb72a58a..origin/main --oneline -- \
  lib/ecto/adapters/myxql/connection.ex lib/ecto/adapters/sql.ex \
  test/ecto/adapters/myxql_test.exs 2>/dev/null | head -20
