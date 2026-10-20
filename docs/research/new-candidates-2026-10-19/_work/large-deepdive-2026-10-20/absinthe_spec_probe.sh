#!/usr/bin/env bash
set -uo pipefail

SRC=/tmp/large-dd/classic-absinthe
docker run --rm -v "$SRC":/app -w /app elixir:1.17-otp-27 bash -lc '
  mix local.hex --force >/dev/null
  mix local.rebar --force >/dev/null
  mix deps.get >/dev/null
  cat > /tmp/spec_probe.exs <<'"'"'EOF'"'"'
# Probe: description before shorthand query
q1 = """
"desc on shorthand"
{
  user { id }
}
"""
IO.puts("=== shorthand with description ===")
IO.inspect(Absinthe.Phase.Parse.run(q1), limit: :infinity)

# Probe: description before anonymous non-shorthand query
q2 = """
"desc on anonymous query"
query {
  user { id }
}
"""
IO.puts("=== anonymous query with description ===")
IO.inspect(Absinthe.Phase.Parse.run(q2), limit: :infinity)

# Probe: description before anonymous mutation (spec Example 4 style)
q3 = """
"""
"Mark story 12345 as liked"
mutation {
  likeStory(storyID: 12345) { story { likeCount } }
}
"""
IO.puts("=== anonymous mutation with description ===")
r3 = Absinthe.Phase.Parse.run(q3)
IO.inspect(r3, limit: 80)

# Render round-trip via inspect (Language.Render)
IO.puts("=== render anonymous mutation via inspect pretty ===")
case r3 do
  {:ok, %{input: doc}} ->
    IO.puts(inspect(doc, pretty: true))
  other -> IO.inspect(other)
end

# Render shorthand with description
IO.puts("=== render shorthand with description ===")
case Absinthe.Phase.Parse.run(q1) do
  {:ok, %{input: doc}} -> IO.puts(inspect(doc, pretty: true))
  other -> IO.inspect(other)
end
EOF
  mix run /tmp/spec_probe.exs 2>&1 | tail -80
' 2>&1 | tail -100
