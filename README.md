# Agent

A simple implementation of agents—chunks of state that
can be operated on in the background.

## Basic State Storage

An agent can store values, and those values can subsequently be retrieved:

    agent = Agent.new(%{ name: "Dave", location: "Texas"})

    Agent.value(agent)  #=> %{ name: "Dave", location: "Texas" }

You can supply a function that is applied to the returned value.
As well as being used to mutate the value, this capability also
allows you to retrieve just part of the stored state:

    Agent.value(agent, &Map.size/1)           #=> 2
    Agent.value(agent, fn val -> val[:name])  #=> "Dave"

## Updating Stored State

The `Agent.update` function mutates agent state. Pass it a function,
which it applies to the current state, yielding the new state.

    Agent.update(agent, fn val -> Map.put(val, :likes, "Elixir"))

Note that _update_ does not return anything meaningful. This is
because the updating function is run asynchronously—the `update` function
returns immediately, and calls to `value` will continue to return the
existing state until this asynchonous function completes.

    Agent.update(agent, fn val -> Map.put(val, :likes, "Elixir"))
    Agent.value(agent) #=> %{ name: "Dave", location: "Texas" }
    Agent.value(agent) #=> %{ name: "Dave", location: "Texas" }
    # some time passes...
    Agent.value(agent) #=> %{ name: "Dave", location: "Texas", likes: "Elixir" }

If you want to synchonize with this background processing, call
`Agent.wait`. The `wait` function waits for all pending updates to an agent
to complete before returning the updated value:

    Agent.update(agent, fn val -> Map.put(val, :likes, "Elixir"))
    Agent.update(agent, fn val -> Map.put(val, :name, "José"))
    Agent.wait(agent) #=> %{ name: "José", location: "Texas", likes: "Elixir" }

After the call to `wait`, subsequent calls to `value` will also return
the updated value.

## Agents as Tasks

If you want to use an agent simply to run a background task, use the
shortcut `Agent.task`. This takes a function and optionally an initial
value. The function will be run in the background (optionally passing it the
initial value). You can use `wait` to retrieve the resulting value when the
function terminates:

    sleeper = Agent.task(fn delay -> :timer.sleep(delay); :erlang.now end, 5000)
    now = :erlang.now
    IO.puts :timer.now_diff(Agent.wait(sleeper), now)  #=> 5000572

## Errors

Agents are run as linked subprocesses of the process that creates them.
Any error in the agent will cause the the original process to terminate.

## Copyright

_Copyright (c) 2014 Dave Thomas, The Pragmatic Programmers_

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

The software is provided "as is", without warranty of any kind, express or
implied, including but not limited to the warranties of merchantability,
fitness for a particular purpose and noninfringement. In no event shall the
authors or copyright holders be liable for any claim, damages or other
liability, whether in an action of contract, tort or otherwise, arising from,
out of or in connection with the software or the use or other dealings in
the software.
