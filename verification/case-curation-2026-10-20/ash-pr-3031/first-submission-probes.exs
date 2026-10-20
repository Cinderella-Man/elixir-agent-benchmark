defmodule Ash.Test.NilTupleDefaultsProbe do
  use ExUnit.Case, async: false
  require Ash.Query
  import Ash.Expr

  defmodule NormalizedInteger do
    use Ash.Type
    def storage_type(_), do: :integer
    def cast_stored(value, _), do: {:ok, value}
    def dump_to_native(value, _), do: {:ok, value}
    def cast_input(value, _) when is_integer(value), do: {:ok, value + 1}
    def cast_input(_, _), do: :error
    def apply_constraints(value, _), do: {:ok, value * 2}
  end

  defmodule Item do
    use Ash.Resource, domain: Ash.Test.Domain, data_layer: Ash.DataLayer.Ets
    ets do
      private? true
    end
    actions do
      defaults [:read, create: :*]
    end
    attributes do
      uuid_primary_key :id
      attribute :number, NormalizedInteger, public?: true
      attribute :enabled, :boolean, public?: true
    end
    calculations do
      calculate :at_least, :boolean, expr(number >= ^arg(:value) and ^arg(:other)) do
        public? true
        argument :value, NormalizedInteger, allow_nil?: false
        argument :other, :boolean, allow_expr?: true, allow_nil?: false
      end
      calculate :label, :string, expr(^arg(:value)) do
        public? true
        argument :value, :string, default: "match"
      end
    end
  end

  test "normalized literals remain stable in typed comparisons beside expressions" do
    item = Item |> Ash.Changeset.for_create(:create, %{number: 2, enabled: true}) |> Ash.create!()
    assert item.number == 6
    args = %{value: 2, other: expr(enabled)}
    assert %{at_least: true} = Ash.load!(item, at_least: args)
    assert [_] = Item |> Ash.Query.filter(^%{at_least: %{input: args, eq: true}}) |> Ash.read!()
  end

  test "nil tuple arguments preserve default calculation arguments" do
    item = Item |> Ash.Changeset.for_create(:create, %{}) |> Ash.create!()
    for query <- [
      Ash.Query.filter(Item, ^[label: {nil, [eq: "match"]}]),
      Ash.Query.filter_input(Item, label: {nil, [eq: "match"]})
    ] do
      assert query.valid?, inspect(query.errors)
      assert [found] = Ash.read!(query)
      assert found.id == item.id
    end
  end
end
