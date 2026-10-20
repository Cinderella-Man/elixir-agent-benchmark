# Probe: description before shorthand query (spec says NOT permitted)
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
"Mark story 12345 as liked"
mutation {
  likeStory(storyID: 12345) { story { likeCount } }
}
"""
IO.puts("=== anonymous mutation with description ===")
r3 = Absinthe.Phase.Parse.run(q3)
IO.inspect(r3, limit: 80)

IO.puts("=== render anonymous mutation via inspect pretty ===")
case r3 do
  {:ok, %{input: doc}} -> IO.puts(inspect(doc, pretty: true))
  other -> IO.inspect(other)
end

IO.puts("=== render shorthand with description ===")
case Absinthe.Phase.Parse.run(q1) do
  {:ok, %{input: doc}} -> IO.puts(inspect(doc, pretty: true))
  other -> IO.inspect(other)
end
