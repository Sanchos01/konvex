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


  defp declare_namespaces_definit(lst) do
    quote location: :keep do
      case Enum.all?(unquote(lst), &(:ets.info(&1) == :undefined)) do
        true ->   Tinca.declare_namespaces
        false ->  Logger.error "#{__MODULE__} : pass table declaration, gen server was initialized again."
                  Enum.each(unquote(lst), &(Tinca.cleanup(&1)))
      end
    end
  end

  defmacro __using__(opts) do
    tables_declaration =  case {opts[:from], opts[:to]} do
                            {nil, nil} -> quote do end
                            {nil, to} when (is_atom(to)) -> quote do use Tinca, [unquote(to)] end
                            {from, nil} when (is_atom(from)) -> quote do use Tinca, [unquote(from)] end
                            {from, to} when (is_atom(from) and is_atom(to)) -> quote do use Tinca, [unquote(from), unquote(to)] end
                          end
    tables_declaration_call = case {opts[:from], opts[:to]} do
                                {nil, nil} -> quote do end
                                {nil, to} when (is_atom(to)) -> declare_namespaces_definit([to])
                                {from, nil} when (is_atom(from)) -> declare_namespaces_definit([from])
                                {from, to} when (is_atom(from) and is_atom(to)) -> declare_namespaces_definit([from, to])
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
                        defp write_callback(_, _) do
                          raise "#{__MODULE__} : you must re-define write_callback, or give 'to' opt."
                        end
                      end
              to when is_atom(to) ->
                      quote location: :keep do
                        defp write_callback(new_state, old_state) do
                          new_keys  = HashUtils.keys(new_state)
                          to_delete = HashUtils.keys(old_state) -- new_keys
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
      unquote(tables_declaration)
      unquote(read)
      unquote(write)
      defp handle_callback(val), do: raise "#{__MODULE__} : you must re-define handle_callback."
      use ExActor.GenServer, export: __MODULE__
      definit do
        unquote(tables_declaration_call)
        {:ok, %{old_raw: %{}, old_processed: %{}}, 0}
      end
      definfo :timeout, state: %{old_raw: old_raw, old_processed: old_processed} do
        new_raw = read_callback
        HashUtils.to_list(new_raw)
        |> Enum.map(
            fn({key, val}) ->
              case HashUtils.get(old_state, key) do
                # this clause - not changed, get cached value
                # we mean handle_callback is clean function
                ^val -> {key, HashUtils.get(old_processed, key)}
                # here value changed or new
                # we must handle it
                _ -> {key, handle_callback(val)}
              end
            end)
        |> HashUtils.to_map
        |> finalize_definfo(old_processed, new_raw)
      end
      defp finalize_definfo(new_processed, old_processed, new_raw) do
        {
          :noreply,
          %{old_raw: new_raw, old_processed: write_callback(new_processed, old_processed)},
          unquote(timeout)
        }
      end
    end

    defoverridable  [
                      read_callback: 0,
                      write_callback: 2,
                      handle_callback: 1
                    ]
  
  end
end
