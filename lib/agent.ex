defmodule Agent do
  use Application.Behaviour

  def start(_type, _args) do
    Agent.Supervisor.start_link
  end

  @doc """
  Create a new agent. You can pass in an initial state.

      # store some configuration information
      agent = Agent.new(%[ name: myapp, use_count: 0 ])

      # retrieve the stored information
      IO.inspect agent.value  #=> %[ name: myapp, use_count: 0 ])
  """

  def new(value) do
    spawn_link(__MODULE__, :loop, [%{value: value, parent: self, children: [], waiting: false}])
#    Agent.Server.register(pid, state)
#    send(pid, {:start, self, state})
#    pid
  end

  def update(agent, fun) do
    send(agent, {:update, fun})
  end

  def wait(agent) do
    send(agent, {:wait})
    get_value()
  end

  def value(agent, extractor \\ &(&1)) do
    send(agent, {:get_value, extractor})
    get_value()
  end

  defp get_value do
    receive do
      {:value, value} -> value
    end
  end

  def loop(state=%{value: value, parent: parent, children: children, waiting: waiting}) do
    IO.puts "top of loop, state=#{inspect state}"
    receive do
      {:update, fun} ->
        {pid,_} = Process.spawn_monitor(__MODULE__, :do_async_update, [self, fun, value])
        loop(%{state| children: [pid|children]})

      {:set_value, new_value} ->
        IO.puts "Setting value to #{new_value}"
        loop(%{state | value: new_value})

      {:get_value, extractor} ->
        send(parent, {:value, extractor.(value)})
        loop(state)

      {:wait} when length(children) == 0 ->
        send(parent, {:value, value })
        loop(state)

      {:wait} ->
        IO.puts "other wait"
        loop(%{state | waiting: true})

      {:DOWN, _ref, :process, pid, :normal} ->
        children = List.delete(children, pid)
        if length(children) == 0 && waiting do
          send(parent, {:value, value})
          state = %{ state | waiting: false }
        end
        loop(%{ state | children: children })

      other ->
        IO.puts "other message: #{inspect other}"
    end
  end

  def do_async_update(agent, fun, value) do
    send(agent, {:set_value, fun.(value)})
  end

end
