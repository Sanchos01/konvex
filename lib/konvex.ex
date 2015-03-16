defmodule Konvex do
  use Application
  
  #
  # TEST
  #
  #defmodule TabDeclaration do 
  #  use Tinca, [:layer1, :layer2, :layer3]
  #end

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    

    #
    # TEST
    #
    #TabDeclaration.Tinca.declare_namespaces

    children = [
      # Define workers and child supervisors to be supervised
      # worker(Konvex.Worker, [arg1, arg2, arg3])
      
      #
      # TEST
      #
      #worker(Konvex.W1, []),
      #worker(Konvex.W2, []),
      #worker(Konvex.W3, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Konvex.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defmacro __using__(opts) do
    tables_declaration =  case {opts[:from], opts[:to]} do
                            {nil, nil} -> quote do end
                            {nil, to} when (is_atom(to)) -> quote do use Tinca, [unquote(to)] end
                            {from, nil} when (is_atom(from)) -> quote do use Tinca, [unquote(from)] end
                            {from, to} when (is_atom(from) and is_atom(to)) -> quote do use Tinca, [unquote(from), unquote(to)] end
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
                          __MODULE__.Tinca.getall(unquote(from))
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
                          new_keys  = Map.keys(new_state)
                          to_delete = Map.keys(old_state) -- new_keys
                          Enum.each(new_keys, 
                            fn(key) -> Map.get(new_state, key) |> __MODULE__.Tinca.put(key, unquote(to)) end)
                          Enum.each(to_delete, 
                            fn(key) -> __MODULE__.Tinca.delete(key, unquote(to)) end)
                          new_state
                        end
                      end
            end
    timeout = case opts[:timeout] do
                nil -> :timer.seconds(1)
                int when is_integer(int) -> int
              end


    quote location: :keep do
      require Logger
      require Exutils
      unquote(tables_declaration)
      unquote(read)
      unquote(write)
      defp handle_callback(_,_,_,_), do: raise "#{__MODULE__} : you must re-define handle_callback."
      defp post_read_callback(some), do: some
      defp post_handle_callback(some), do: some
      defp time_callback(_), do: nil
      use ExActor.GenServer, export: __MODULE__
      definit do
        {:ok, %{old_raw: %{}, old_processed: %{}}, 0}
      end
      definfo :timeout, state: %{old_raw: old_raw, old_processed: old_processed} do
        :erlang.garbage_collect
        {time, res} = :timer.tc(fn() -> 
          new_raw = read_callback |> post_read_callback
          Enum.map(new_raw, 
              fn({key, val}) ->
                case {Map.get(old_raw, key), Map.has_key?(old_processed, key)} do
                  # this clause - not changed, get cached value
                  # we mean handle_callback is clean function
                  {^val, true} -> {key, Map.get(old_processed, key)}
                  # here value changed or new
                  # we must handle it
                  {old_raw_val, _} -> {key, handle_callback(key, val, old_raw_val, Map.get(old_processed, key))}
                end
              end)
          |> HashUtils.to_map
          |> post_handle_callback
          |> finalize_definfo(old_processed, new_raw)
        end)
        time_callback(time)
        res
      end
      defp finalize_definfo(new_processed, old_processed, new_raw) do
        {
          :noreply,
          %{old_raw: new_raw, old_processed: write_callback(new_processed, old_processed)},
          unquote(timeout)
        }
      end
      defoverridable  [
                        read_callback: 0,
                        post_read_callback: 1,
                        post_handle_callback: 1,
                        write_callback: 2,
                        handle_callback: 4,
                        time_callback: 1
                      ]
    end
    #IO.puts Macro.expand(r)
    #IO.puts Macro.to_string(r)
    #r
  end
end
