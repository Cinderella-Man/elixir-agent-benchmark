defmodule Eab.ComparisonTest do
  use ExUnit.Case, async: true
  alias Eab.Comparison

  test "comparison rejects mixed policies and keeps incomplete/error outcomes distinct" do
    run = %{
      "id" => "first",
      "release_id" => "frozen",
      "settings" => %{"seed" => 101},
      "cases" => ~w(a b),
      "status" => "completed",
      "model" => %{"model" => "model-a"},
      "attempts" => %{
        "a" => %{"status" => "completed", "grade" => %{"passed" => true}},
        "b" => %{"status" => "completed", "grade" => %{"passed" => false}}
      }
    }

    other =
      run
      |> Map.put("id", "other")
      |> Map.put("status", "error")
      |> put_in(["attempts", "b"], %{"status" => "error"})

    comparison = Comparison.build([run, other])
    assert Enum.map(comparison["runs"], & &1["score"]["score_percent"]) == [50.0, nil]
    assert Enum.at(comparison["cases"], 1)["outcomes"] == ["Failed", "Evaluation error"]

    for changed <- [
          Map.put(other, "release_id", nil),
          Map.put(other, "release_id", "another"),
          Map.put(other, "cases", ~w(b a)),
          put_in(other, ["settings", "seed"], 42)
        ],
        do: assert_raise(RuntimeError, fn -> Comparison.build([run, changed]) end)
  end
end
