defmodule Agent do

  @moduledoc Regex.replace(~r/^#+\s*Copyright.*/sm,
                           File.read!(Path.join(__DIR__, "/../README.md")),
                           '')


  ####################################################################
  # API
  ####################################################################

  @doc """
  Create a new agent, specifying an initial state.

      # store some configuration information
      agent = Agent.new(%[ name: myapp, use_count: 0 ])

      # retrieve the stored information
      IO.inspect Agent.value(agent)  #=> %[ name: myapp, use_count: 0 ])
  """
  def new(value) do
    spawn_link(__MODULE__, :loop, [%{value: value, parent: self, children: [], waiting: false}])
  end

  @doc """
  Create an agent whose initial value is determined by a function. You
  can optionally pass in a value which be passed to this function.
  The value is calculated in the background, and so you'll need to call
  `wait` in order to retrieve it.

      task = Agent.task(fn param -> long_running_calc(param), 123)
      Agent.wait(task)  #=> result of long_running_calc(123)

  """
  def task(fun, value \\ :undefined) when is_function(fun) do
    agent = spawn_link(__MODULE__, :loop, [%{value: value, parent: self, children: [], waiting: false}])
    update(agent, fun)
    agent
  end

  @doc """
  Return the current value of the agent. If an `update` or `task` is
  pending or executing, then this value will be the old value. That is,
  `value` will not wait for them to finish. Use `wait` if you want to
  wait for the execution of pending updates to finish before returning
  the value.

  You can pass an optional function to `value`. If specified, this
  function will be run on the value, and its result returned. The function
  is run in the background process that stores the agent's state.
  Is the state is large, and you only want a small part of it, this might
  make your code more efficient, as a smaller message will be sent.

      agent = Agent.new(%{ name: "Dave", location: "Texas"})
      Agent.value(agent)  #=> %{ name: "Dave", location: "Texas" }
      Agent.value(agent, &Map.size/1)           #=> 2
      Agent.value(agent, fn val -> val[:name])  #=> "Dave"
  """
  def value(agent, extractor \\ &(&1)) do
    send_to_agent(agent, {:get_value, extractor})
    get_value()
  end

  @doc """
  Applies `fun` to the current value of the agent. This function is
  run in a separate process. When it returns, the value it returns will
  become the agent's new value. If `update` is called multiple times,
  they will be run sequentially in the order received.

  As updates are asynchronous, you'll need to call `wait` if you want
  the updated value.

      agent = Agent.new(%{ name: "Dave", location: "Texas"})
      Agent.update(agent fn val -> Map.put(val, :likes, "Elixir"))

      # the following statement may or may not return the
      # updated value
      Agent.value(agent) #=> %{ name: "Dave", location: "Texas"}

      # but calling `wait` will always get the latest
      Agent.wait(agent) #=> %{ name: "Dave", location: "Texas", likes: "Elixir"}

  """

  def update(agent, fun) do
    send_to_agent(agent, {:update, fun})
  end

  @doc """
  Wait for all background updates for the agent to complete, and
  then return the value.

      agent = Agent.new(%{ name: "Dave", location: "Texas"})
      Agent.update(agent fn val -> Map.put(val, :likes, "Elixir"))
      Agent.update(agent fn val -> Map.put(val, :name, "José"))
      Agent.wait(a) #=> %{ name: "José", location: "Texas", likes: "Elixir" }

  Note that `wait` waits for all pending updates. If an update is
  initiated while a `wait` is waiting for a previous update, then the
  `wait` will wait for both.
  """
  def wait(agent) do
    send_to_agent(agent, {:wait})
    get_value()
  end




  ####################################################################
  # Implementation
  ####################################################################

  defp get_value do
    receive do
      {:value, value} -> value
    end
  end

  defp send_to_agent(agent, msg) do
    if Process.alive?(agent) do
      send(agent, msg)
    else
      raise "Cannot sent #{inspect msg} to agent #{inspect agent}—it no longer exists"
    end
  end

  def loop(state=%{value: value, parent: parent, children: children, waiting: waiting}) do
    receive do
      {:update, fun} ->
        {pid,_} = Process.spawn_monitor(__MODULE__, :do_async_update, [self, fun, value])
        loop(%{state| children: [pid|children]})

      {:set_value, new_value} ->
        loop(%{state | value: new_value})

      {:get_value, extractor} ->
        send(parent, {:value, extractor.(value)})
        loop(state)

      {:wait} when length(children) == 0 ->
        send(parent, {:value, value })
        loop(state)

      {:wait} ->
        loop(%{state | waiting: true})

      {:DOWN, _ref, :process, pid, :normal} ->
        children = List.delete(children, pid)
        if length(children) == 0 && waiting do
          send(parent, {:value, value})
#          state = %{ state | waiting: false }
          state = Map.put(state, :waiting, false)
        end
        loop(Map.put(state, :children, children))

      {:DOWN, _ref, :process, pid, reason} ->
        exit(reason)

      other ->
        IO.puts "other message: #{inspect other}"
    end
  end

  def do_async_update(agent, fun, value)
  when is_function(fun, 1) do
    send(agent, {:set_value, fun.(value)})
  end

  def do_async_update(agent, fun, _value)
  when is_function(fun, 0) do
    send(agent, {:set_value, fun.()})
  end
end
