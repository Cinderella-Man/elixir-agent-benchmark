#!/usr/bin/env bash
set -uo pipefail
docker run --rm \
  -v /tmp/large-dd/classic-absinthe:/app \
  -v /mnt/c/Users/44773/Documents/elixir-swe-bench/docs/research/new-candidates-2026-10-19/_work/large-deepdive-2026-10-20/spec_probe.exs:/tmp/spec_probe.exs:ro \
  -w /app elixir:1.17-otp-27 bash -lc '
    mix local.hex --force
    mix local.rebar --force
    mix deps.get
    mix run /tmp/spec_probe.exs
  '
