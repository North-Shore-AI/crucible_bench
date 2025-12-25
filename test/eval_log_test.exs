defmodule CrucibleBench.EvalLogTest do
  use ExUnit.Case, async: true

  alias CrucibleBench.EvalLog
  alias CrucibleBench.EvalLog.Extract

  test "builds eval log from EvalEx.Result" do
    metrics = [
      %{accuracy: 1.0, loss: 0.2},
      %{accuracy: 0.0, loss: 0.4},
      %{accuracy: 1.0, loss: 0.3},
      %{accuracy: 0.0, loss: 0.1}
    ]

    result = EvalEx.Result.new("inspect_evals/gsm8k", :testset, metrics, 4, 100)

    log =
      EvalLog.from_eval_result(result,
        scorer_name: "llm_judge",
        task_display_name: nil,
        location: "/tmp/eval.json"
      )

    assert log.status == "success"
    assert log.location == "/tmp/eval.json"
    assert log.eval.task == "inspect_evals/gsm8k"
    assert log.eval.dataset.name == "testset"

    [score] = log.results.scores
    assert score.name == "llm_judge"

    assert score.metrics["accuracy"].value == 0.5
    assert score.metrics["loss"].value == 0.25
    assert_in_delta score.metrics["stderr"].value, 0.288675, 1.0e-6

    assert Extract.eval_log_task_display_name(log) == "gsm8k"
  end

  test "extracts score dict and headline stderr" do
    metrics = [
      %{accuracy: 1.0},
      %{accuracy: 0.0}
    ]

    result = EvalEx.Result.new("task", :dataset, metrics, 2, 50)
    log = EvalLog.from_eval_result(result, scorer_name: "default")

    [score_dict] = Extract.eval_log_scores_dict(log)
    assert score_dict["default"]["accuracy"] == 0.5
    assert score_dict["default"]["stderr"] == 0.5

    assert Extract.eval_log_headline_stderr(log) == 0.5
  end
end
