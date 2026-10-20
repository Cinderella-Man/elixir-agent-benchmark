defmodule ForkMigration.Outcomes do
  def normalize(proof) do
    Map.new(~w(empty_patch reference_patch early_exit partial_repair), fn name ->
      grade = proof["controls"][name]
      results =
        Map.new(~w(hidden regression submission), &{&1, result(grade[&1])})
        |> Map.put("regression_coverage", coverage(grade["regression_coverage"]))

      {name, Map.merge(Map.take(grade, ~w(passed reason submitted_test_files)), results)}
    end)
  end

  defp result(value) when is_map(value),
    do: Map.take(value, ~w(passed completed test_results failure_phases failure_types))

  defp result(value), do: value

  defp coverage(value) when is_map(value) do
    Map.take(value, ~w(passed policy reason detected_tests))
    |> Map.put("test_probe", result(value["test_probe"]))
    |> Map.put("broken_test_probe", result(value["broken_test_probe"]))
  end

  defp coverage(value), do: value
end
