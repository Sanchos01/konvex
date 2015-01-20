defmodule Konvex do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Define workers and child supervisors to be supervised
      # worker(Konvex.Worker, [arg1, arg2, arg3])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Konvex.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defmacro __using__(opts) do
    declaration = case {opts[:from], opts[:to]} do
                    {nil, nil} -> raise "#{__MODULE__} : you must declare 'from' or 'to' opt."
                    {nil, to} when (is_atom(to)) -> quote do [unquote(to)] end
                    {from, nil} when (is_atom(from)) -> quote do [unquote(from)] end
                    {from, to} when (is_atom(from) and is_atom(to)) -> quote do [unquote(from), unquote(to)] end
                  end
    read =  case opts[:from] do
              nil ->  quote location: :keep do
                        defp read_callback do
                          raise "#{__MODULE__} : you must re-define read_callback, or give 'from' opt."
                        end
                      end
              from when is_atom(from) ->
                      quote location: :keep do
                        defp read_callback do
                          Tinca.getall(unquote(from))
                        end
                      end
            end
    write = case opts[:to] do
              nil ->  quote location: :keep do
                        defp write_callback(_) do
                          raise "#{__MODULE__} : you must re-define write_callback, or give 'to' opt."
                        end
                      end
              to when is_atom(to) ->
                      quote location: :keep do
                        defp write_callback(new_state) do
                          new_keys  = HashUtils.keys(new_state)
                          to_delete = (Tinca.getall(unquote(to)) |> HashUtils.keys) -- new_keys
                          Enum.each(new_keys, 
                            fn(key) -> HashUtils.get(new_state, key) |> Tinca.put(key, unquote(to)) end)
                          Enum.each(to_delete, 
                            fn(key) -> Tinca.delete(key, unquote(to)) end)
                          new_state
                        end
                      end
            end
    timeout = case opts[:timeout] do
                nil -> :timer.seconds(1)
                int when is_integer(int) -> int
              end


    quote location: :keep do
      unquote(declaration)
      unquote(read)
      unquote(write)
      defp handle_callback(val), do: val # do nothing by default
      use ExActor.GenServer, export: __MODULE__
      definit do
        Tinca.declare_namespaces
        {:ok, %{old_raw: %{}, old_processed: %{}}, 0}
      end
      definfo :timeout, state: %{old_raw: old_raw, old_processed: old_processed} do
        new_raw = read_callback
        HashUtils.to_list(new_raw)
        |> Enum.map(
            fn({key, val}) ->
              case HashUtils.get(old_state, key) do
                # this clause - not changed, get cached value
                # we mean handle_callback is clean
                ^val -> {key, HashUtils.get(old_processed, key)}
                # here value changed or new
                _ -> {key, handle_callback(val)}
              end
            end)
        |> HashUtils.to_map
        |> finalize_definfo(new_raw)
      end
      defp finalize_definfo(new_processed, new_raw) do
        {:noreply}
      end
    end
  end
end
