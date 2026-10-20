#!/usr/bin/env bash
set -uo pipefail

echo "################ ABSINTHE full suite at BASE (retry with hex) ################"
SRC2=/tmp/large-dd/absinthe-base-only
docker run --rm -v "$SRC2":/app -w /app elixir:1.17-otp-27 bash -lc '
  mix local.hex --force >/dev/null
  mix local.rebar --force >/dev/null
  mix deps.get >/dev/null
  mix test 2>&1 | tail -30
' 2>&1 | tail -35

echo
echo "################ look for elixir 1.20 image ################"
docker search elixir 2>/dev/null | head -5
# try pull candidates
for img in elixir:1.20-otp-28 elixir:1.20 elixir:1.20.0 elixir:1.20-otp-27; do
  echo "try $img"
  if docker pull "$img" >/dev/null 2>&1; then
    echo "AVAILABLE: $img"
    docker run --rm "$img" elixir --version
    break
  else
    echo "missing $img"
  fi
done

echo
echo "################ CRAFTPLAN config hostname ################"
grep -n 'hostname\|url\|Repo' /tmp/large-dd/classic-craftplan/config/test.exs | head -20
cat /tmp/large-dd/classic-craftplan/config/test.exs | head -40
