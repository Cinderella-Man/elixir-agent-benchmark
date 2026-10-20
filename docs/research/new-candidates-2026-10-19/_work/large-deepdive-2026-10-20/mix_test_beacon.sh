#!/usr/bin/env bash
set -uo pipefail

echo "################ BEACON retry: free 5432, postgres:15 ################"
docker rm -f cp-pg be-pg 2>/dev/null || true
sleep 2
docker run -d --name be-pg -e POSTGRES_PASSWORD=postgres -e POSTGRES_USER=postgres -p 5432:5432 postgres:15 >/dev/null
sleep 6
docker exec be-pg psql -U postgres -c 'SELECT version();' 2>&1 | tail -3

echo "-- beacon test.exs repo block --"
sed -n '1,30p' /tmp/large-dd/classic-beacon/config/test.exs

SRC=/tmp/large-dd/classic-beacon
docker run --rm -v "$SRC":/app -w /app --network host --memory=4g elixir:1.14-otp-25 bash -lc '
  export MIX_ENV=test
  export ERL_MAX_ETS_TABLES=100000
  mix local.hex --force >/dev/null
  mix local.rebar --force >/dev/null
  mix deps.get >/dev/null 2>&1
  echo DEPS_OK
  # compile first
  mix compile 2>&1 | tail -8
  echo COMPILE=$?
  # create db and run tests
  mix ecto.create 2>&1 | tail -15
  echo CREATE=$?
  mix test test/beacon_web/controllers/sitemap_controller_test.exs 2>&1 | tail -60
  echo TEST_SITEMAP=$?
' 2>&1 | tail -100
