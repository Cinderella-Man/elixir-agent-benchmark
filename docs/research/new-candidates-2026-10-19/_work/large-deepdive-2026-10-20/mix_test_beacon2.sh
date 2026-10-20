#!/usr/bin/env bash
set -uo pipefail

echo "################ BEACON: manual DB create + test ################"
docker exec be-pg psql -U postgres -c 'DROP DATABASE IF EXISTS beacon_test;' 2>&1 | tail -2
docker exec be-pg psql -U postgres -c 'CREATE DATABASE beacon_test;' 2>&1 | tail -2

SRC=/tmp/large-dd/classic-beacon
# try with explicit DATABASE_URL and larger memory
docker run --rm -v "$SRC":/app -w /app --network host --memory=6g elixir:1.14-otp-25 bash -lc '
  export MIX_ENV=test
  export DATABASE_URL=postgres://postgres:postgres@localhost:5432/beacon_test
  mix local.hex --force >/dev/null
  mix local.rebar --force >/dev/null
  mix deps.get >/dev/null 2>&1
  mix compile 2>&1 | tail -5
  echo COMPILE=$?
  mix ecto.migrate 2>&1 | tail -20
  echo MIGRATE=$?
  mix test test/beacon_web/controllers/sitemap_controller_test.exs 2>&1 | tail -80
  echo TEST_SITEMAP=$?
' 2>&1 | tail -100

echo
echo "################ BEACON: diagnose the killed (maybe ecto.create NIF) ################"
docker run --rm -v "$SRC":/app -w /app --network host elixir:1.14-otp-25 bash -lc '
  export MIX_ENV=test
  export DATABASE_URL=postgres://postgres:postgres@localhost:5432/beacon_test
  mix local.hex --force >/dev/null
  mix local.rebar --force >/dev/null
  mix deps.get >/dev/null 2>&1
  mix run -e "IO.inspect(Application.ensure_all_started(:postgrex)); IO.inspect(Application.ensure_all_started(:ecto_sql)); r = Beacon.BeaconTest.Repo; IO.inspect(r.__adapter__()); IO.inspect(r.config())" 2>&1 | tail -30
' 2>&1 | tail -40
