#!/usr/bin/env bash
set -uo pipefail

echo "################ MIX TEST: ABSINTHE (pure library) ################"
# use the classic-absinthe tree which has the patch applied at first parent
SRC=/tmp/large-dd/classic-absinthe
# copy to a docker-friendly path without /tmp perms issues - use /tmp
docker run --rm -v "$SRC":/app -w /app elixir:1.17-otp-27 bash -lc '
  set -x
  elixir --version
  mix local.hex --force
  mix local.rebar --force
  mix deps.get
  mix compile
  mix test test/absinthe/document_description_test.exs
  echo EXIT_DOC=$?
  mix test
  echo EXIT_FULL=$?
' 2>&1 | tail -80
echo "docker absinthe exit: $?"

echo
echo "################ MIX TEST: ABSINTHE BASELINE (no patch) ################"
SRC2=/tmp/large-dd/absinthe-base-only
if [ ! -d "$SRC2/.git" ]; then
  git clone --quiet https://github.com/absinthe-graphql/absinthe.git "$SRC2"
  cd "$SRC2"
  git checkout --quiet 8fba7023f944e093036b89131b9e47a4ad2f7ecc
fi
docker run --rm -v "$SRC2":/app -w /app elixir:1.17-otp-27 bash -lc '
  mix local.hex --force >/dev/null
  mix local.rebar --force >/dev/null
  mix deps.get
  mix compile
  # run only an existing parse-related test to confirm baseline green
  mix test test/absinthe/language 2>&1 | tail -30
  echo EXIT_LANG=$?
' 2>&1 | tail -40
echo "docker absinthe-base exit: $?"
