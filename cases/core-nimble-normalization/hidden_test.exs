defmodule Benchmark.NimbleNormalizationTest do
  use ExUnit.Case, async: true

  def integer(value) when is_integer(value), do: {:ok, value}

  def integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {number, ""} -> {:ok, number}
      _ -> {:error, "expected a whole decimal number"}
    end
  end

  def integer(_), do: {:error, "expected a whole decimal number"}
  def normalize_key(value) when is_binary(value), do: {:ok, String.downcase(value)}
  def normalize_key(_), do: {:error, "expected a textual key"}

  defp integer_type, do: {:custom, __MODULE__, :integer, []}

  test "top-level maps receive defaults and transformed scalar values" do
    schema = [attempts: [type: integer_type()], queue: [type: :string, default: "urgent"]]

    assert {:ok, %{attempts: 12, queue: "urgent"}} =
             NimbleOptions.validate(%{attempts: "12"}, schema)

    assert {:ok, result} = NimbleOptions.validate([attempts: "12"], schema)
    assert Map.new(result) == %{attempts: 12, queue: "urgent"}
  end

  test "typed maps preserve conversion of keys and values together" do
    schema = [
      quotas: [type: {:map, {:custom, __MODULE__, :normalize_key, []}, integer_type()}]
    ]

    assert {:ok, [quotas: %{"east" => 7, "west" => 11}]} =
             NimbleOptions.validate([quotas: %{"EAST" => "7", "WEST" => "11"}], schema)
  end

  test "nested map defaults compose through an ordered list of map configurations" do
    worker_schema = [
      name: [type: :string, required: true],
      concurrency: [type: integer_type(), default: "3"],
      labels: [type: {:map, :string, integer_type()}, default: %{}]
    ]

    schema = [workers: [type: {:list, {:map, worker_schema}}]]

    input = [
      workers: [
        %{name: "archive", labels: %{"retention" => "30"}},
        %{name: "mail", concurrency: "8"}
      ]
    ]

    assert {:ok,
            [
              workers: [
                %{name: "archive", concurrency: 3, labels: %{"retention" => 30}},
                %{name: "mail", concurrency: 8, labels: %{}}
              ]
            ]} = NimbleOptions.validate(input, schema)
  end

  test "empty containers and idempotent normalized input keep their shape" do
    schema = [quotas: [type: {:map, :string, integer_type()}]]
    assert {:ok, [quotas: %{}]} = NimbleOptions.validate([quotas: %{}], schema)
    assert {:ok, [quotas: %{"east" => 4}]} =
             NimbleOptions.validate([quotas: %{"east" => 4}], schema)

    assert {:ok, %{}} = NimbleOptions.validate(%{}, [])
  end

  test "invalid transformed map values remain errors with the containing option" do
    schema = [quotas: [type: {:map, :string, integer_type()}]]

    assert {:error, %NimbleOptions.ValidationError{} = error} =
             NimbleOptions.validate([quotas: %{"east" => "4x"}], schema)

    assert Exception.message(error) =~ "quotas"
    assert Exception.message(error) =~ "whole decimal number"
  end

  test "unknown and missing nested options are not silently accepted" do
    schema = [service: [type: :map, keys: [name: [type: :string, required: true]]]]

    for invalid <- [%{service: %{}}, %{service: %{name: "mail", typo: true}}] do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               NimbleOptions.validate(invalid, schema)

      assert Exception.message(error) =~ "service"
    end
  end
end
