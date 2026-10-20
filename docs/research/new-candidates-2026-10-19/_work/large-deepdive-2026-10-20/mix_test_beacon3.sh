#!/usr/bin/env bash
set -uo pipefail

SRC=/tmp/large-dd/classic-beacon
docker run --rm -v "$SRC":/app -w /app --network host --memory=6g elixir:1.14-otp-25 bash -lc '
  export MIX_ENV=test
  export DATABASE_URL=postgres://postgres:postgres@localhost:5432/beacon_test
  mix local.hex --force >/dev/null
  mix local.rebar --force >/dev/null
  mix deps.get >/dev/null 2>&1
  mix compile 2>&1 | tail -3
  echo COMPILE=$?
  mix esbuild.install 2>&1 | tail -8
  echo ESBUILD=$?
  mix tailwind.install --no-assets 2>&1 | tail -8
  echo TAILWIND=$?
  mix ecto.migrate 2>&1 | tail -5
  echo MIGRATE=$?
  mix test test/beacon_web/controllers/sitemap_controller_test.exs 2>&1 | tail -80
  echo TEST_SITEMAP=$?
  mix test test/beacon_web/controllers/media_library_controller_test.exs test/mix/tasks/install_test.exs 2>&1 | tail -50
  echo TEST_PRESERVE=$?
' 2>&1 | tail -120
