defmodule TestCheckFormatter do
  @moduledoc false
  use GenServer

  ## Callbacks

  def init(_) do
    {:ok, :will_be_setup_in_each_module_started}
  end

  defp get_max_points_from_env() do
    case System.get_env("MAX_POINTS") do
      nil -> 15
      max_points -> String.to_integer(max_points)
    end
  end

  def handle_cast({:module_started, test_module}, _state) do
    # Max points will be set as a moduletag attribute in the test module
    # `@moduletag max_points: 15`
    max_points =
      case test_module.tests do
        [] -> get_max_points_from_env()
        [test | _] -> test.tags.max_points
      end

    {:noreply,
     %{
       max_points: max_points,
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

  def handle_cast({:module_finished, test_module}, state) do
    print_module_finished(state, test_module)
    {:noreply, state}
  end

  def handle_cast({:suite_finished, _}, state) do
    print_suite_finished()
    {:noreply, state}
  end

  def handle_cast(_, state) do
    {:noreply, state}
  end

  defp print_module_finished(state, test_module) do
    max_points = state.max_points

    total_success_tasks =
      (Enum.uniq(state.success_tasks) -- Enum.uniq(state.fail_tasks)) |> length()

    total_failed_tasks = Enum.uniq(state.fail_tasks) |> length()
    total_tasks = Enum.uniq(state.success_tasks ++ state.fail_tasks) |> length()

    percent_success = percent_of_0_to_1(total_tasks, total_success_tasks)
    points_earned = Float.round(percent_success * max_points, 2)

    update_process_dictionary(max_points, points_earned)

    failed_tests_str =
      Enum.with_index(state.fail_tests, 1)
      |> Enum.map(fn {{file, line, task}, index} ->
        "#{index}. #{file}:#{line} (task_id: #{task})"
      end)
      |> Enum.join("\n")

    if failed_tests_str != "" do
      failed_tests_str = IO.ANSI.red() <> "Failed tests:\n" <> failed_tests_str <> IO.ANSI.reset()
      IO.puts(failed_tests_str <> "\n")
    end

    IO.puts("""
    Report for test module #{test_module.name}:
      Max points for the current homework: #{max_points}
      Tasks: #{total_tasks}
      Tasks have at least one failed test: #{total_failed_tasks}
      Tasks that don't have failing tests: #{total_success_tasks}
      Percent successful tests: #{percent_success * 100}%

      Points assigned: #{points_earned}
    """)

    :ok
  end

  defp print_suite_finished() do
    points_earned = Process.get(:points_earned)
    max_points = Process.get(:max_points)

    IO.puts("""
    Report for all test modules:
      Max points: #{Enum.sum(max_points) * 1.0}
      Points earned: #{Enum.sum(points_earned)}
    """)
  end

  defp percent_of_0_to_1(total, part) do
    Float.round(part / total, 2)
  end

  defp update_process_dictionary(max_points, points_earned) do
    points = Process.get(:points_earned, [])
    Process.put(:points_earned, [points_earned | points])

    points = Process.get(:max_points, [])
    Process.put(:max_points, [max_points | points])
  end
end
