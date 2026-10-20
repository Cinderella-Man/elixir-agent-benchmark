alias Eab.{Cache, Candidates, Store}
ref = Store.read("curation/ash-pr-3031-current.json")
prefix = "curation/#{ref["id"]}/#{ref["version"]}"
proof_path = "candidates/#{ref["id"]}/#{ref["version"]}/qualification.json"
# Synchronize with a first round already running under the candidate lock.
first =
  Cache.locked({:candidate, ref["id"]}, fn ->
    Store.read(proof_path) || raise("Initial qualification has not passed")
  end)
unless first["controls"]["valid"], do: raise("Initial controls invalid")

Code.require_file("qualification-outcomes.exs", __DIR__)
normalize = &AshCuration.Outcomes.normalize/1

for round <- 1..3 do
  destination = "#{prefix}/qualification-round-#{round}.json"
  if Store.read(destination), do: raise("Round already recorded; inspect rather than overwrite")
  proof = if round == 1 do
    first
  else
    cache = "qualifications/#{Cache.key(first["controls"]["identity"])}.json"
    archived = Store.path("#{prefix}/qualification-cache-before-round-#{round}.json")
    File.mkdir_p!(Path.dirname(archived))
    File.rename!(Store.path(cache), archived)
    IO.puts("FRESH_ROUND #{round}: prior qualification cache retained outside lookup")
    Candidates.qualify(ref, &IO.puts/1)
    Store.read(proof_path)
  end
  Store.write(destination, proof)
  unless normalize.(proof) == normalize.(first), do: raise("Named control outcomes differ between rounds")
  IO.puts("FRESH_ROUND #{round}: valid, matching named outcomes")
end
Store.write("#{prefix}/matching-controls.json", normalize.(first))
IO.puts("THREE_FRESH_ROUNDS_VERIFIED")
