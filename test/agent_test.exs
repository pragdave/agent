defmodule AgentTest do
  use ExUnit.Case

  test "basic agent creation/value" do
    agent = Agent.new(123)
    assert Agent.value(agent) == 123
  end

  test "wait with no pending updates" do
    agent = Agent.new(124)
    assert Agent.wait(agent) == 124
  end

  test "wait with pending update waits" do
    agent = Agent.new(125)
    Agent.update(agent, fn x -> :timer.sleep(100); x + 100 end)
    assert Agent.value(agent) == 125
    assert Agent.wait(agent)  == 225
    assert Agent.value(agent) == 225
  end

  test "update is asynchronous" do
    agent = Agent.new(126)
    Agent.update(agent, fn x -> :timer.sleep(100); x + 100 end)
    now = :erlang.now
    assert Agent.wait(agent) == 226
    assert_in_delta :timer.now_diff(:erlang.now, now), 100000, 4000
  end

  test "multiple updates are queued" do
    agent = Agent.new(127)
    Agent.update(agent, fn x -> :timer.sleep(100); x + 100 end)
    Agent.update(agent, fn x -> :timer.sleep(100); x * 10  end)
    assert Agent.wait(agent) == 2270
  end

  test "task is run" do
    task = Agent.task(fn -> :timer.sleep(100); "hello" end)
    assert Agent.wait(task) == "hello"
  end

  test "task with parameters is run" do
    task = Agent.task(fn name -> :timer.sleep(100); "hello#{name}" end, " world")
    assert Agent.wait(task) == "hello world"
  end

  test "an agent that exits will cause it's parent to exit" do
    agent = Agent.new(99)
    assert catch_exit(Agent.value(agent, fn x -> exit(x) end)) == 1
  end

  test "an agent that raises an error will cause it's parent to exit" do
    agent = Agent.new(99)
    assert catch_exit(Agent.value(agent, fn x -> x/0 end)) == 123
  end

end
