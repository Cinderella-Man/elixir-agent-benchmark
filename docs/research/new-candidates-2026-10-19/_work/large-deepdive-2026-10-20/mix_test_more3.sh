#!/usr/bin/env bash
set -uo pipefail

echo "################ ABSINTHE patched full suite RE-RUN (flaky check) ################"
SRC=/tmp/large-dd/classic-absinthe
docker run --rm -v "$SRC":/app -w /app elixir:1.17-otp-27 bash -lc '
  mix test 2>&1 | tail -35
' 2>&1 | tail -40

echo
echo "################ ABSINTHE patched: just the failing test file ################"
docker run --rm -v "$SRC":/app -w /app elixir:1.17-otp-27 bash -lc '
  mix test test/absinthe/phase/schema/inline_functions_test.exs 2>&1 | tail -25
' 2>&1 | tail -30

echo
echo "################ CRAFTPLAN on elixir:1.20-otp-28 + postgres ################"
# postgres on host port 5432 to match config hostname localhost
docker rm -f cp-pg 2>/dev/null || true
docker run -d --name cp-pg -e POSTGRES_PASSWORD=postgres -e POSTGRES_USER=postgres -p 5432:5432 postgres:16 >/dev/null
sleep 5
docker exec cp-pg psql -U postgres -c 'CREATE DATABASE craftplan_test;' 2>&1 | tail -3

SRC=/tmp/large-dd/classic-craftplan
docker run --rm -v "$SRC":/app -w /app --network host elixir:1.20-otp-28 bash -lc '
  export MIX_ENV=test
  mix local.hex --force >/dev/null
  mix local.rebar --force >/dev/null
  apt-get update -qq >/dev/null 2>&1 || true
  apt-get install -y -qq build-essential >/dev/null 2>&1 || true
  mix deps.get 2>&1 | tail -8
  echo DEPS_GET=$?
  mix compile 2>&1 | tail -25
  echo COMPILE=$?
  mix test test/craftplan/production_batching_test.exs 2>&1 | tail -50
  echo TEST_BATCH=$?
  mix test test/craftplan_web/production_batch_live_actions_test.exs 2>&1 | tail -50
  echo TEST_LIVE=$?
' 2>&1 | tail -120
