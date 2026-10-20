#!/usr/bin/env bash
set -uo pipefail

echo "################ ABSINTHE full suite at BASE (no patch) ################"
SRC2=/tmp/large-dd/absinthe-base-only
docker run --rm -v "$SRC2":/app -w /app elixir:1.17-otp-27 bash -lc '
  mix test 2>&1 | tail -25
  echo EXIT_FULL_BASE=$?
' 2>&1 | tail -30

echo
echo "################ CRAFTPLAN mix test (needs postgres) ################"
SRC=/tmp/large-dd/classic-craftplan
# start postgres
docker rm -f cp-pg 2>/dev/null || true
docker run -d --name cp-pg -e POSTGRES_PASSWORD=postgres -e POSTGRES_USER=postgres -e POSTGRES_DB=craftplan_test -p 55432:5432 postgres:16 >/dev/null
sleep 4
# inspect craftplan config for db url
grep -n -i 'postgres\|database\|url\|Repo' /tmp/large-dd/classic-craftplan/config/test.exs 2>/dev/null | head -20
grep -n -i 'postgres\|database\|url' /tmp/large-dd/classic-craftplan/config/dev.exs 2>/dev/null | head -10
grep -n 'elixir\|deps' /tmp/large-dd/classic-craftplan/mix.exs | head -20
ls /tmp/large-dd/classic-craftplan/mix.lock >/dev/null && echo "mix.lock present"

docker run --rm -v "$SRC":/app -w /app --network host elixir:1.18-otp-27 bash -lc '
  export MIX_ENV=test
  export DATABASE_URL=ecto://postgres:postgres@localhost:55432/craftplan_test
  export POSTGRES_URL=$DATABASE_URL
  mix local.hex --force >/dev/null
  mix local.rebar --force >/dev/null
  # native deps may need build tools
  apt-get update -qq >/dev/null 2>&1 && apt-get install -y -qq build-essential >/dev/null 2>&1
  mix deps.get 2>&1 | tail -15
  echo DEPS_GET=$?
  mix compile 2>&1 | tail -20
  echo COMPILE=$?
  mix test test/craftplan/production_batching_test.exs 2>&1 | tail -40
  echo TEST_BATCH=$?
  mix test test/craftplan_web/production_batch_live_actions_test.exs 2>&1 | tail -40
  echo TEST_LIVE=$?
' 2>&1 | tail -100
echo "craftplan docker exit: $?"
