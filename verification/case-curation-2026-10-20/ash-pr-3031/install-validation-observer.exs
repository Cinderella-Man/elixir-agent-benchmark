s = Eab.Runs.snapshot()
unless is_nil(s.active) and not s.cleaning and is_nil(s.cleanup_error), do: raise("Controller busy")
unless Eab.Inventory.all() == ["ash-pr-3031"], do: raise("Candidate is not isolated")
source = Path.join(__DIR__, "validation-measurement.ex")
installed_source = Eab.Inventory.path("lib/eab/measurement.ex")
beam_path = :code.which(Eab.Measurement) |> List.to_string()
unless File.regular?(beam_path), do: raise("Cannot locate installed observer module")
File.cp!(source, installed_source)
[{Eab.Measurement, binary}] = Code.compile_file(installed_source)
File.write!(beam_path, binary)
unless Eab.Measurement.start() == :disabled and
    Eab.Measurement.finish(:disabled) == %{"disabled" => "functional_validation_machine_policy"},
  do: raise("Observer is not disabled")
IO.puts("VALIDATION_OBSERVER_DISABLED")
