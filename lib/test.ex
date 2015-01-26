defmodule Konvex.W1 do
	use Konvex, [from: :layer1, to: :layer2, timeout: 3000]
	defp handle_callback(_,v,_,_) do
		IO.puts "#{__MODULE__} got new val #{inspect v}, double it!"
		2 * v
	end
end

defmodule Konvex.W2 do
	use Konvex, [from: :layer2, to: :layer3, timeout: 3000]
	defp handle_callback(_,v,_,_) do
		IO.puts "#{__MODULE__} got new val #{inspect v}, double it!"
		2 * v
	end
end

defmodule Konvex.W3 do
	use Konvex, [from: :layer3, timeout: 3000]
	defp handle_callback(_,v,_,_) do
		IO.puts "#{__MODULE__} got new val #{inspect v}, double it!"
		2 * v
	end
	defp write_callback(new, old) do
		IO.puts "#{__MODULE__} finally got #{inspect new}, was #{inspect old}"
		new
	end
end