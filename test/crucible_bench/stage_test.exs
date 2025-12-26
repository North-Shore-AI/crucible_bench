defmodule CrucibleBench.StageTest do
  use ExUnit.Case, async: true

  alias CrucibleBench.Stage

  describe "run/2" do
    test "successfully processes context with valid stats config and outputs" do
      context = %{
        experiment: %{
          reliability: %{
            stats: %CrucibleIR.Reliability.Stats{
              tests: [:ttest, :bootstrap],
              alpha: 0.05,
              confidence_level: 0.95
            }
          }
        },
        outputs: [0.85, 0.87, 0.84, 0.86, 0.88, 0.83, 0.89, 0.85]
      }

      assert {:ok, updated_context} = Stage.run(context)
      assert Map.has_key?(updated_context, :bench)
      assert is_map(updated_context.bench)
      assert Map.has_key?(updated_context.bench, :tests)
      assert Map.has_key?(updated_context.bench, :config)
      assert Map.has_key?(updated_context.bench, :summary)
    end

    test "includes bootstrap test results when requested" do
      context = %{
        experiment: %{
          reliability: %{
            stats: %CrucibleIR.Reliability.Stats{
              tests: [:bootstrap],
              bootstrap_iterations: 500,
              confidence_level: 0.95
            }
          }
        },
        outputs: [0.85, 0.87, 0.84, 0.86, 0.88]
      }

      assert {:ok, updated_context} = Stage.run(context)
      assert Map.has_key?(updated_context.bench.tests, :bootstrap)
      bootstrap_result = updated_context.bench.tests.bootstrap
      assert bootstrap_result.test_type == :bootstrap
      assert Map.has_key?(bootstrap_result, :confidence_interval)
    end

    test "processes context with metrics key instead of outputs" do
      context = %{
        experiment: %{
          reliability: %{
            stats: %CrucibleIR.Reliability.Stats{
              tests: [:bootstrap],
              alpha: 0.05
            }
          }
        },
        metrics: [0.91, 0.89, 0.90, 0.92, 0.88]
      }

      assert {:ok, updated_context} = Stage.run(context)
      assert Map.has_key?(updated_context, :bench)
      assert updated_context.bench.summary.n == 5
    end

    test "returns error when stats config is missing" do
      context = %{
        outputs: [0.85, 0.87, 0.84, 0.86, 0.88]
      }

      assert {:error, reason} = Stage.run(context)
      assert reason =~ "Missing experiment.reliability.stats"
    end

    test "returns error when data is missing" do
      context = %{
        experiment: %{
          reliability: %{
            stats: %CrucibleIR.Reliability.Stats{
              tests: [:ttest],
              alpha: 0.05
            }
          }
        }
      }

      assert {:error, reason} = Stage.run(context)
      assert reason =~ "No data found"
    end

    test "returns error when stats config is invalid type" do
      context = %{
        experiment: %{
          reliability: %{
            stats: %{invalid: "config"}
          }
        },
        outputs: [0.85, 0.87, 0.84]
      }

      assert {:error, reason} = Stage.run(context)
      assert reason =~ "Invalid stats config"
    end

    test "extracts numeric values from map data" do
      context = %{
        experiment: %{
          reliability: %{
            stats: %CrucibleIR.Reliability.Stats{
              tests: [:bootstrap],
              alpha: 0.05
            }
          }
        },
        outputs: [
          %{accuracy: 0.85, latency: 100},
          %{accuracy: 0.87, latency: 105},
          %{accuracy: 0.84, latency: 98}
        ]
      }

      assert {:ok, updated_context} = Stage.run(context)
      assert Map.has_key?(updated_context, :bench)
      # Should extract first numeric key (accuracy)
      assert updated_context.bench.summary.n == 3
    end

    test "accepts options to override config" do
      context = %{
        experiment: %{
          reliability: %{
            stats: %CrucibleIR.Reliability.Stats{
              tests: [:ttest],
              alpha: 0.05
            }
          }
        },
        outputs: [0.85, 0.87, 0.84, 0.86, 0.88]
      }

      opts = %{tests: [:bootstrap], bootstrap_iterations: 100}
      assert {:ok, updated_context} = Stage.run(context, opts)
      assert Map.has_key?(updated_context.bench.tests, :bootstrap)
      refute Map.has_key?(updated_context.bench.tests, :ttest)
    end

    test "includes summary statistics in results" do
      context = %{
        experiment: %{
          reliability: %{
            stats: %CrucibleIR.Reliability.Stats{
              tests: [:bootstrap],
              alpha: 0.05
            }
          }
        },
        outputs: [0.85, 0.87, 0.84, 0.86, 0.88]
      }

      assert {:ok, updated_context} = Stage.run(context)
      summary = updated_context.bench.summary

      assert summary.n == 5
      assert is_float(summary.mean)
      assert is_float(summary.sd)
      assert is_float(summary.median)
      assert summary.mean > 0.84 and summary.mean < 0.88
    end

    test "handles custom data_key option" do
      context = %{
        experiment: %{
          reliability: %{
            stats: %CrucibleIR.Reliability.Stats{
              tests: [:bootstrap],
              alpha: 0.05
            }
          }
        },
        custom_results: [0.91, 0.89, 0.90, 0.92, 0.88]
      }

      opts = %{data_key: :custom_results}
      assert {:ok, updated_context} = Stage.run(context, opts)
      assert updated_context.bench.summary.n == 5
    end
  end

  describe "describe/1" do
    test "returns basic metadata without verbose option" do
      result = Stage.describe()

      assert is_map(result)
      assert result.name == "CrucibleBench.Stage"
      assert result.type == :analysis
      assert result.purpose == "Statistical testing and analysis"
      assert is_list(result.inputs)
      assert is_list(result.outputs)
      assert result.config_source == "experiment.reliability.stats"
    end

    test "returns detailed metadata with verbose option" do
      result = Stage.describe(%{verbose: true})

      assert is_map(result)
      assert result.name == "CrucibleBench.Stage"
      assert Map.has_key?(result, :available_tests)
      assert Map.has_key?(result, :effect_sizes)
      assert Map.has_key?(result, :corrections)
      assert Map.has_key?(result, :requirements)

      assert is_list(result.available_tests)
      assert :ttest in result.available_tests
      assert :bootstrap in result.available_tests
    end

    test "includes correct test types in verbose mode" do
      result = Stage.describe(%{verbose: true})

      expected_tests = [:ttest, :bootstrap, :anova, :mannwhitney, :wilcoxon, :kruskal]
      assert Enum.all?(expected_tests, &(&1 in result.available_tests))
    end

    test "includes correct effect sizes in verbose mode" do
      result = Stage.describe(%{verbose: true})

      expected_effects = [:cohens_d, :eta_squared, :omega_squared]
      assert Enum.all?(expected_effects, &(&1 in result.effect_sizes))
    end

    test "includes correct correction methods in verbose mode" do
      result = Stage.describe(%{verbose: true})

      expected_corrections = [:bonferroni, :holm, :benjamini_hochberg]
      assert Enum.all?(expected_corrections, &(&1 in result.corrections))
    end
  end

  describe "CrucibleIR.Reliability.Stats integration" do
    test "accepts all config fields from Stats struct" do
      context = %{
        experiment: %{
          reliability: %{
            stats: %CrucibleIR.Reliability.Stats{
              tests: [:bootstrap],
              alpha: 0.01,
              confidence_level: 0.99,
              effect_size_type: :cohens_d,
              multiple_testing_correction: :bonferroni,
              bootstrap_iterations: 2000,
              options: %{custom: "value"}
            }
          }
        },
        outputs: [0.85, 0.87, 0.84, 0.86, 0.88]
      }

      assert {:ok, updated_context} = Stage.run(context)
      assert updated_context.bench.config.alpha == 0.01
      assert updated_context.bench.config.confidence_level == 0.99
    end

    test "uses default values when config fields are nil" do
      context = %{
        experiment: %{
          reliability: %{
            stats: %CrucibleIR.Reliability.Stats{
              tests: [:bootstrap]
            }
          }
        },
        outputs: [0.85, 0.87, 0.84, 0.86, 0.88]
      }

      assert {:ok, updated_context} = Stage.run(context)
      # Should use defaults
      assert updated_context.bench.config.alpha == 0.05
      assert updated_context.bench.config.confidence_level == 0.95
    end
  end

  describe "run/2 with two groups" do
    test "performs t-test when control and treatment provided" do
      context = %{
        experiment: %{
          reliability: %{
            stats: %CrucibleIR.Reliability.Stats{
              tests: [:ttest],
              alpha: 0.05
            }
          }
        },
        control: [0.72, 0.68, 0.75, 0.71, 0.69],
        treatment: [0.78, 0.73, 0.81, 0.76, 0.74]
      }

      assert {:ok, updated} = Stage.run(context)
      assert Map.has_key?(updated.bench.tests, :ttest)
      ttest = updated.bench.tests.ttest

      assert is_number(ttest.statistic)
      assert is_number(ttest.p_value)
      assert is_boolean(ttest.significant)
      assert is_map(ttest.effect_size)
    end

    test "performs Mann-Whitney when mannwhitney requested" do
      context = %{
        experiment: %{
          reliability: %{
            stats: %CrucibleIR.Reliability.Stats{
              tests: [:mannwhitney],
              alpha: 0.05
            }
          }
        },
        control: [0.72, 0.68, 0.75, 0.71, 0.69],
        treatment: [0.78, 0.73, 0.81, 0.76, 0.74]
      }

      assert {:ok, updated} = Stage.run(context)
      assert Map.has_key?(updated.bench.tests, :mannwhitney)
      mannwhitney = updated.bench.tests.mannwhitney

      assert is_number(mannwhitney.statistic)
      assert is_number(mannwhitney.p_value)
      assert is_boolean(mannwhitney.significant)
    end
  end

  describe "run/2 with multiple groups" do
    test "performs ANOVA when groups provided" do
      context = %{
        experiment: %{
          reliability: %{
            stats: %CrucibleIR.Reliability.Stats{
              tests: [:anova],
              alpha: 0.05
            }
          }
        },
        groups: [
          [0.89, 0.91, 0.88, 0.90, 0.92],
          [0.87, 0.89, 0.86, 0.88, 0.90],
          [0.84, 0.86, 0.83, 0.85, 0.87]
        ]
      }

      assert {:ok, updated} = Stage.run(context)
      assert Map.has_key?(updated.bench.tests, :anova)
      anova = updated.bench.tests.anova

      assert is_number(anova.statistic)
      assert is_number(anova.p_value)
      assert is_map(anova.effect_size)
      assert Map.has_key?(anova.effect_size, :eta_squared)
    end

    test "performs Kruskal-Wallis when kruskal requested" do
      context = %{
        experiment: %{
          reliability: %{
            stats: %CrucibleIR.Reliability.Stats{
              tests: [:kruskal],
              alpha: 0.05
            }
          }
        },
        groups: [
          [0.89, 0.91, 0.88, 0.90, 0.92],
          [0.87, 0.89, 0.86, 0.88, 0.90],
          [0.84, 0.86, 0.83, 0.85, 0.87]
        ]
      }

      assert {:ok, updated} = Stage.run(context)
      assert Map.has_key?(updated.bench.tests, :kruskal)
      kruskal = updated.bench.tests.kruskal

      assert is_number(kruskal.statistic)
      assert is_number(kruskal.p_value)
      assert is_boolean(kruskal.significant)
    end
  end

  describe "run/2 with paired groups" do
    test "performs paired t-test when before and after provided" do
      context = %{
        experiment: %{
          reliability: %{
            stats: %CrucibleIR.Reliability.Stats{
              tests: [:ttest],
              alpha: 0.05
            }
          }
        },
        before: [0.72, 0.68, 0.75, 0.71, 0.69],
        after: [0.78, 0.73, 0.81, 0.76, 0.74]
      }

      assert {:ok, updated} = Stage.run(context)
      # Should detect paired data and use paired t-test
      assert Map.has_key?(updated.bench.tests, :ttest)
      ttest = updated.bench.tests.ttest

      assert is_number(ttest.statistic)
      assert is_number(ttest.p_value)
      assert is_boolean(ttest.significant)
    end

    test "performs Wilcoxon signed-rank test when wilcoxon requested" do
      context = %{
        experiment: %{
          reliability: %{
            stats: %CrucibleIR.Reliability.Stats{
              tests: [:wilcoxon],
              alpha: 0.05
            }
          }
        },
        before: [0.72, 0.68, 0.75, 0.71, 0.69],
        after: [0.78, 0.73, 0.81, 0.76, 0.74]
      }

      assert {:ok, updated} = Stage.run(context)
      assert Map.has_key?(updated.bench.tests, :wilcoxon)
      wilcoxon = updated.bench.tests.wilcoxon

      assert is_number(wilcoxon.statistic)
      assert is_number(wilcoxon.p_value)
      assert is_boolean(wilcoxon.significant)
    end
  end

  describe "metrics merging" do
    test "merges statistical results into context.metrics" do
      context = %{
        experiment: %{
          reliability: %{
            stats: %CrucibleIR.Reliability.Stats{
              tests: [:bootstrap],
              alpha: 0.05
            }
          }
        },
        outputs: [0.85, 0.87, 0.84, 0.86, 0.88],
        metrics: %{existing: 123}
      }

      assert {:ok, updated} = Stage.run(context)

      # Existing metrics preserved
      assert updated.metrics.existing == 123

      # New bench metrics added
      assert is_number(updated.metrics.bench_n)
      assert is_number(updated.metrics.bench_mean)
      assert is_number(updated.metrics.bench_sd)
      assert is_number(updated.metrics.bench_median)
    end

    test "merges p-values from tests into metrics" do
      context = %{
        experiment: %{
          reliability: %{
            stats: %CrucibleIR.Reliability.Stats{
              tests: [:ttest],
              alpha: 0.05
            }
          }
        },
        control: [0.72, 0.68, 0.75, 0.71, 0.69],
        treatment: [0.78, 0.73, 0.81, 0.76, 0.74]
      }

      assert {:ok, updated} = Stage.run(context)
      assert is_number(updated.metrics.bench_ttest_p_value)
    end

    test "creates metrics map when none exists" do
      context = %{
        experiment: %{
          reliability: %{
            stats: %CrucibleIR.Reliability.Stats{
              tests: [:bootstrap],
              alpha: 0.05
            }
          }
        },
        outputs: [0.85, 0.87, 0.84, 0.86, 0.88]
      }

      assert {:ok, updated} = Stage.run(context)
      assert is_map(updated.metrics)
      assert is_number(updated.metrics.bench_n)
    end
  end

  describe "behaviour compliance" do
    test "run/2 accepts map context and returns ok/error tuple" do
      valid_context = %{
        experiment: %{
          reliability: %{
            stats: %CrucibleIR.Reliability.Stats{tests: [:bootstrap]}
          }
        },
        outputs: [1.0, 2.0, 3.0]
      }

      assert {:ok, _} = Stage.run(valid_context)
      assert {:ok, _} = Stage.run(valid_context, %{})
      assert {:error, _} = Stage.run(%{})
    end

    test "describe/1 returns map with required keys" do
      result = Stage.describe(%{})

      assert is_map(result)
      assert Map.has_key?(result, :name)
      assert Map.has_key?(result, :type)
      assert Map.has_key?(result, :purpose)
    end
  end
end
