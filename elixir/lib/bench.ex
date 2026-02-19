defmodule Bench do
  def main(args) do
    {image_path, iterations} = parse_args(args)

    case StbImage.read_file(image_path) do
      {:ok, img} ->
        img_dir = Path.dirname(image_path)
        output_dir = Path.join([img_dir, "..", "output"])
        File.mkdir_p!(output_dir)

        {height, width, channels} = img.shape
        tensor = StbImage.to_nx(img)

        benchmarks = [
          {"nx-invert", &invert_nx/1},
          {"elixir-manual", fn t -> invert_manual(t, height, width, channels) end}
        ]

        header =
          :io_lib.format("~-20s ~12s ~12s ~12s ~12s ~12s ~12s", [
            "slug", "mean", "median", "std_dev", "min", "max", "total"
          ])
          |> IO.iodata_to_binary()

        IO.puts(header)
        IO.puts(String.duplicate("-", String.length(header)))

        Enum.each(benchmarks, fn {slug, fun} ->
          {stats, result_tensor} = run_bench(fun, tensor, iterations)

          # Save output image
          result_img = StbImage.from_nx(result_tensor)
          out_path = Path.join(output_dir, "#{slug}.png")
          StbImage.write_file!(result_img, out_path)

          :io.format("~-20s ~12.6f ~12.6f ~12.6f ~12.6f ~12.6f ~12.6f~n", [
            slug,
            stats.mean,
            stats.median,
            stats.std_dev,
            stats.min,
            stats.max,
            stats.total
          ])
        end)

      {:error, reason} ->
        IO.puts(:stderr, "Failed to load image: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp parse_args(args) do
    image_path = Enum.at(args, 0, "../images/lenna.png")
    iterations = Enum.at(args, 1, "101") |> String.to_integer()
    {image_path, iterations}
  end

  defp invert_nx(tensor) do
    Nx.subtract(255, tensor)
  end

  defp invert_manual(tensor, height, width, channels) do
    binary = Nx.to_binary(tensor)

    inverted =
      for <<byte <- binary>>, into: <<>> do
        <<255 - byte>>
      end

    Nx.from_binary(inverted, :u8)
    |> Nx.reshape({height, width, channels})
  end

  defp run_bench(fun, tensor, iterations) do
    results =
      Enum.map(1..iterations, fn _ ->
        start = System.monotonic_time(:nanosecond)
        result = fun.(tensor)
        elapsed = (System.monotonic_time(:nanosecond) - start) / 1_000_000_000
        {elapsed, result}
      end)

    times = Enum.map(results, &elem(&1, 0))
    last_result = results |> List.last() |> elem(1)

    {compute_stats(times), last_result}
  end

  defp compute_stats(times) do
    sorted = Enum.sort(times)
    n = length(sorted)
    total = Enum.sum(sorted)
    mean = total / n
    median = Enum.at(sorted, div(n, 2))
    min_val = List.first(sorted)
    max_val = List.last(sorted)

    std_dev =
      if n > 1 do
        variance =
          sorted
          |> Enum.map(fn t -> (t - mean) * (t - mean) end)
          |> Enum.sum()
          |> Kernel./(n - 1)

        :math.sqrt(variance)
      else
        0.0
      end

    %{
      mean: mean,
      median: median,
      std_dev: std_dev,
      min: min_val,
      max: max_val,
      total: total
    }
  end
end
