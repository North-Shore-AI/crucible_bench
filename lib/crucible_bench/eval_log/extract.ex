defmodule CrucibleBench.EvalLog.Extract do
  @moduledoc """
  Helpers for extracting metrics from EvalLog structures.
  """

  alias CrucibleBench.EvalLog

  @doc """
  Return log location.
  """
  def eval_log_location(%EvalLog{location: location}), do: location

  @doc """
  Return display name for the task.
  """
  def eval_log_task_display_name(%EvalLog{} = log) do
    case log.eval.task_display_name do
      nil -> remove_namespace(log.eval.task)
      name -> name
    end
  end

  @doc """
  Extract scores as a list of score-name keyed metric maps.
  """
  def eval_log_scores_dict(%EvalLog{results: nil}), do: nil

  def eval_log_scores_dict(%EvalLog{results: results}) do
    Enum.map(results.scores, fn score ->
      metrics =
        Enum.into(score.metrics, %{}, fn {name, metric} ->
          {name, metric.value}
        end)

      %{score.name => metrics}
    end)
  end

  @doc """
  Extract headline stderr if present.
  """
  def eval_log_headline_stderr(%EvalLog{results: nil}), do: nil

  def eval_log_headline_stderr(%EvalLog{results: results}) do
    case List.first(results.scores) do
      nil ->
        nil

      score ->
        case Map.get(score.metrics, "stderr") do
          nil -> nil
          metric -> metric.value
        end
    end
  end

  defp remove_namespace(task) when is_binary(task) do
    task
    |> String.split("/")
    |> List.last()
  end

  defp remove_namespace(task), do: to_string(task)
end
