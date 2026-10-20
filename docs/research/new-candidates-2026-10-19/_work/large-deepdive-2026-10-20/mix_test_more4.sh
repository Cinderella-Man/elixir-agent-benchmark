#!/usr/bin/env bash
set -uo pipefail

echo "################ ABSINTHE patched full suite RE-RUN #2 ################"
SRC=/tmp/large-dd/classic-absinthe
docker run --rm -v "$SRC":/app -w /app elixir:1.17-otp-27 bash -lc '
  mix local.hex --force >/dev/null
  mix local.rebar --force >/dev/null
  mix deps.get >/dev/null
  mix test 2>&1 | tail -30
' 2>&1 | tail -35

echo
echo "################ ABSINTHE patched: inline_functions_test alone ################"
docker run --rm -v "$SRC":/app -w /app elixir:1.17-otp-27 bash -lc '
  mix local.hex --force >/dev/null
  mix local.rebar --force >/dev/null
  mix deps.get >/dev/null
  mix test test/absinthe/phase/schema/inline_functions_test.exs 2>&1 | tail -25
' 2>&1 | tail -30

echo
echo "################ BEACON mix test (needs postgres) ################"
docker rm -f be-pg 2>/dev/null || true
docker run -d --name be-pg -e POSTGRES_PASSWORD=postgres -e POSTGRES_USER=postgres -p 5432:5432 postgres:15 >/dev/null
sleep 5
# inspect beacon test config
grep -n 'Repo\|database\|hostname\|username\|password\|port' /tmp/large-dd/classic-beacon/config/test.exs 2>/dev/null | head -20
grep -n 'elixir\|@version' /tmp/large-dd/classic-beacon/mix.exs | head -10
ls /tmp/large-dd/classic-beacon/mix.lock >/dev/null && echo "mix.lock present"

SRC=/tmp/large-dd/classic-beacon
docker run --rm -v "$SRC":/app -w /app --network host elixir:1.14-otp-25 bash -lc '
  export MIX_ENV=test
  mix local.hex --force >/dev/null
  mix local.rebar --force >/dev/null
  apt-get update -qq >/dev/null 2>&1 || true
  apt-get install -y -qq build-essential >/dev/null 2>&1 || true
  mix deps.get 2>&1 | tail -10
  echo DEPS_GET=$?
  mix compile 2>&1 | tail -25
  echo COMPILE=$?
  mix test test/beacon_web/controllers/sitemap_controller_test.exs 2>&1 | tail -50
  echo TEST_SITEMAP=$?
  mix test test/beacon_web/controllers/media_library_controller_test.exs test/mix/tasks/install_test.exs 2>&1 | tail -40
  echo TEST_PRESERVE=$?
' 2>&1 | tail -120
