defmodule CrucibleBench.EvalLog do
  @moduledoc """
  Inspect-AI compatible evaluation log schema and adapters.
  """

  alias EvalEx.Metrics

  defmodule EvalMetric do
    @moduledoc "Metric entry for an evaluation score."

    @type t :: %__MODULE__{
            name: String.t(),
            value: number(),
            params: map(),
            metadata: map() | nil
          }

    defstruct [:name, :value, params: %{}, metadata: nil]
  end

  defmodule EvalScore do
    @moduledoc "Score summary for an evaluation."

    @type t :: %__MODULE__{
            name: String.t(),
            scorer: String.t(),
            reducer: String.t() | nil,
            scored_samples: non_neg_integer() | nil,
            unscored_samples: non_neg_integer() | nil,
            params: map(),
            metrics: map(),
            metadata: map() | nil
          }

    defstruct [
      :name,
      :scorer,
      :reducer,
      :scored_samples,
      :unscored_samples,
      params: %{},
      metrics: %{},
      metadata: nil
    ]
  end

  defmodule EvalResults do
    @moduledoc "Scoring results from evaluation."

    @type t :: %__MODULE__{
            total_samples: non_neg_integer(),
            completed_samples: non_neg_integer(),
            scores: [EvalScore.t()],
            metadata: map() | nil
          }

    defstruct total_samples: 0, completed_samples: 0, scores: [], metadata: nil
  end

  defmodule EvalDataset do
    @moduledoc "Dataset metadata for an eval."

    @type t :: %__MODULE__{
            name: String.t() | nil,
            location: String.t() | nil,
            samples: non_neg_integer() | nil,
            sample_ids: [String.t() | integer()] | nil,
            shuffled: boolean() | nil
          }

    defstruct [:name, :location, :samples, :sample_ids, :shuffled]
  end

  defmodule EvalSpec do
    @moduledoc "Identity and configuration for an eval run."

    @type t :: %__MODULE__{
            task: String.t(),
            task_display_name: String.t() | nil,
            dataset: EvalDataset.t() | nil,
            model: String.t() | nil,
            metadata: map() | nil
          }

    defstruct [:task, :task_display_name, :dataset, :model, metadata: nil]
  end

  defmodule EvalStats do
    @moduledoc "Timing and usage statistics."

    @type t :: %__MODULE__{
            started_at: String.t(),
            completed_at: String.t(),
            model_usage: map()
          }

    defstruct started_at: "", completed_at: "", model_usage: %{}
  end

  @type t :: %__MODULE__{
          version: non_neg_integer(),
          status: String.t(),
          eval: EvalSpec.t(),
          results: EvalResults.t() | nil,
          stats: EvalStats.t(),
          location: String.t()
        }

  defstruct version: 1,
            status: "success",
            eval: nil,
            results: nil,
            stats: nil,
            location: ""

  @doc """
  Build an EvalLog from an EvalEx.Result.
  """
  @spec from_eval_result(EvalEx.Result.t(), keyword()) :: t()
  def from_eval_result(%EvalEx.Result{} = result, opts \\ []) do
    scorer_name = Keyword.get(opts, :scorer_name, "default")
    task = Keyword.get(opts, :task, result.name)
    task_display_name = Keyword.get(opts, :task_display_name, result.name)
    dataset_name = Keyword.get(opts, :dataset_name, to_string(result.dataset))
    status = Keyword.get(opts, :status, "success")
    location = Keyword.get(opts, :location, "")

    scores = [
      %EvalScore{
        name: scorer_name,
        scorer: scorer_name,
        metrics: build_metrics(result, opts)
      }
    ]

    %__MODULE__{
      status: status,
      location: location,
      eval: %EvalSpec{
        task: task,
        task_display_name: task_display_name,
        dataset: %EvalDataset{name: dataset_name, samples: result.samples}
      },
      results: %EvalResults{
        total_samples: result.samples,
        completed_samples: result.samples,
        scores: scores
      },
      stats: %EvalStats{}
    }
  end

  defp build_metrics(%EvalEx.Result{} = result, opts) do
    value_lists = values_by_metric(result.metrics)
    metrics = build_base_metrics(result.aggregated_metrics, value_lists)
    stderr_metrics = Keyword.get(opts, :stderr_metrics, ["accuracy"])
    add_stderr_metrics(metrics, stderr_metrics, value_lists)
  end

  defp build_base_metrics(aggregated_metrics, value_lists) do
    Enum.reduce(aggregated_metrics, %{}, fn {name, stats}, acc ->
      metric_name = to_string(name)
      mean = metric_mean(stats, value_lists[metric_name])
      Map.put(acc, metric_name, %EvalMetric{name: metric_name, value: mean})
    end)
  end

  defp add_stderr_metrics(metrics, stderr_metrics, value_lists) do
    Enum.reduce(stderr_metrics, metrics, fn metric_name, acc ->
      maybe_add_stderr(acc, metric_name, value_lists[metric_name])
    end)
  end

  defp maybe_add_stderr(acc, metric_name, values) when is_list(values) and length(values) > 1 do
    stderr_name = if metric_name == "accuracy", do: "stderr", else: "#{metric_name}_stderr"
    Map.put(acc, stderr_name, %EvalMetric{name: stderr_name, value: Metrics.stderr(values)})
  end

  defp maybe_add_stderr(acc, _metric_name, _values), do: acc

  defp metric_mean(%{mean: mean}, _values) when is_number(mean), do: mean

  defp metric_mean(_stats, values) when is_list(values) and values != [] do
    Metrics.accuracy(values)
  end

  defp metric_mean(_stats, _values), do: 0.0

  defp values_by_metric(metrics) when is_list(metrics) do
    Enum.reduce(metrics, %{}, &merge_sample_metrics/2)
  end

  defp merge_sample_metrics(sample_metrics, acc) do
    Enum.reduce(sample_metrics, acc, &add_metric_value/2)
  end

  defp add_metric_value({name, value}, acc) when is_number(value) do
    Map.update(acc, to_string(name), [value], &[value | &1])
  end

  defp add_metric_value(_entry, acc), do: acc
end
