defmodule TestCheckFormatter do
  @moduledoc false
  use GenServer

  ## Callbacks

  def init(_opts) do
    {:ok,
     %{
       fail_tasks: [],
       success_tasks: [],
       fail_tests: []
     }}
  end

  def handle_cast({_, %{tags: %{test_type: :doctest}}}, state) do
    # Ignore doctests
    {:noreply, state}
  end

  def handle_cast({:test_finished, %ExUnit.Test{} = test}, state) do
    state =
      case test.state do
        {:failed, [{:error, _error, _failures}]} ->
          # Add a leading dot so the file:line string can be copy-pasted in the
          # terminal to directly execute it
          file = String.replace_leading(test.tags.file, File.cwd!() <> "/", "")
          line = test.tags.line
          task = test.tags.task

          %{
            state
            | fail_tasks: [task | state.fail_tasks],
              fail_tests: [{file, line, task} | state.fail_tests]
          }

        nil ->
          %{state | success_tasks: [test.tags.task | state.success_tasks]}

        {:excluded, _} ->
          IO.puts("Test excluded on line: #{test.tags.line}")

        _ ->
          state
      end

    {:noreply, state}
  end

  def handle_cast({:suite_finished, _times_us}, state) do
    print_suite(state)
    {:noreply, state}
  end

  def handle_cast(_, state) do
    {:noreply, state}
  end

  defp print_suite(state) do
    max_points = 15

    total_success_tasks =
      (Enum.uniq(state.success_tasks) -- Enum.uniq(state.fail_tasks)) |> length()

    total_failed_tasks = Enum.uniq(state.fail_tasks) |> length()
    total_tasks = Enum.uniq(state.success_tasks ++ state.fail_tasks) |> length()

    percent_success = percent_of_0_to_1(total_tasks, total_success_tasks)

    failed_tests_str =
      Enum.with_index(state.fail_tests, 1)
      |> Enum.map(fn {{file, line, task}, index} ->
        "#{index}. #{file}:#{line} (task_id: #{task})"
      end)
      |> Enum.join("\n")

    failed_tests_str = IO.ANSI.red() <> "Failed tests:\n" <> failed_tests_str <> IO.ANSI.reset()

    IO.puts(failed_tests_str <> "\n")

    IO.puts("""
    Report:
      Max points for the current homework: #{max_points}
      Tasks: #{total_tasks}
      Tasks have at least one failed test: #{total_failed_tasks}
      Tasks that don't have failing tests: #{total_success_tasks}
      Percent successful tests: #{percent_success * 100}%

      Points assigned: #{Float.round(percent_success * max_points, 2)}
    """)

    :ok
  end

  defp percent_of_0_to_1(total, part) do
    Float.round(part / total, 2)
  end
end
