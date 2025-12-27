defmodule CrucibleBench.ConformanceTest do
  use ExUnit.Case

  alias CrucibleBench.Stage

  describe "stage conformance" do
    test "implements Crucible.Stage behaviour" do
      assert function_exported?(Stage, :run, 2)
      assert function_exported?(Stage, :describe, 1)
    end

    test "describe/1 returns valid canonical schema" do
      schema = Stage.describe(%{})

      # Name must be atom
      assert is_atom(schema.name)
      assert schema.name == :bench

      # Required core fields exist
      assert Map.has_key?(schema, :description)
      assert Map.has_key?(schema, :required)
      assert Map.has_key?(schema, :optional)
      assert Map.has_key?(schema, :types)

      # No overlap between required and optional
      overlap =
        MapSet.intersection(
          MapSet.new(schema.required),
          MapSet.new(schema.optional)
        )

      assert MapSet.size(overlap) == 0
    end

    test "schema has version marker" do
      schema = Stage.describe(%{})

      assert Map.has_key?(schema, :__schema_version__)
      assert is_binary(schema.__schema_version__)
      assert schema.__schema_version__ == "1.0.0"
    end

    test "all optional fields have types" do
      schema = Stage.describe(%{})

      for key <- schema.optional do
        assert Map.has_key?(schema.types, key),
               "Optional field #{key} missing from types"
      end
    end

    test "all required fields have types" do
      schema = Stage.describe(%{})

      for key <- schema.required do
        assert Map.has_key?(schema.types, key),
               "Required field #{key} missing from types"
      end
    end

    test "defaults only contain optional field keys" do
      schema = Stage.describe(%{})

      if Map.has_key?(schema, :defaults) do
        for {key, _value} <- schema.defaults do
          assert key in schema.optional,
                 "Default key #{key} is not in optional fields"
        end
      end
    end

    test "extensions contain bench metadata" do
      schema = Stage.describe(%{})

      assert Map.has_key?(schema, :__extensions__)
      assert Map.has_key?(schema.__extensions__, :bench)
      assert schema.__extensions__.bench.type == :analysis
      assert is_list(schema.__extensions__.bench.available_tests)
      assert is_list(schema.__extensions__.bench.effect_sizes)
      assert is_list(schema.__extensions__.bench.corrections)
    end

    test "extensions contain expected test types" do
      schema = Stage.describe(%{})

      expected_tests = [
        :ttest,
        :paired_ttest,
        :bootstrap,
        :wilcoxon,
        :mann_whitney,
        :anova,
        :kruskal_wallis
      ]

      for test <- expected_tests do
        assert test in schema.__extensions__.bench.available_tests,
               "Missing test type #{test} in available_tests"
      end
    end
  end
end
