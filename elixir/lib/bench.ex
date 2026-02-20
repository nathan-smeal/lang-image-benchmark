defmodule Bench do
  def main(args) do
    {image_path, iterations, task_filter} = parse_args(args)

    case StbImage.read_file(image_path) do
      {:ok, img} ->
        img_dir = Path.dirname(image_path)
        output_dir = Path.join([img_dir, "..", "output"])
        File.mkdir_p!(output_dir)

        {height, width, channels} = img.shape
        tensor = StbImage.to_nx(img)

        # Pre-compute grayscale for gray-input benchmarks (outside timing)
        gray_tensor =
          tensor
          |> Nx.as_type(:f32)
          |> then(fn t ->
            r = t[[.., .., 0]]
            g = t[[.., .., 1]]
            b = t[[.., .., 2]]

            Nx.add(Nx.add(Nx.multiply(r, 0.299), Nx.multiply(g, 0.587)), Nx.multiply(b, 0.114))
            |> Nx.round()
            |> Nx.clip(0, 255)
            |> Nx.as_type(:u8)
          end)

        benchmarks = [
          {"invert", "nx-invert", :rgb, &invert_nx/1},
          {"invert", "elixir-manual", :rgb,
           fn t -> invert_manual(t, height, width, channels) end},
          {"grayscale", "nx-grayscale", :rgb, &grayscale_nx/1},
          {"blur", "nx-blur", :rgb, &blur_nx/1},
          {"edge_detect_sobel", "nx-sobel", :gray, &sobel_nx/1},
          {"rotate_90", "nx-rotate90", :rgb, &rotate90_nx/1},
          {"lee_filter", "nx-lee", :gray, &lee_filter_nx/1}
        ]

        benchmarks =
          if task_filter do
            Enum.filter(benchmarks, fn {task, _, _, _} -> task == task_filter end)
          else
            benchmarks
          end

        header =
          :io_lib.format("~-20s ~-25s ~12s ~12s ~12s ~12s ~12s ~12s", [
            "task",
            "slug",
            "mean",
            "median",
            "std_dev",
            "min",
            "max",
            "total"
          ])
          |> IO.iodata_to_binary()

        IO.puts(header)
        IO.puts(String.duplicate("-", String.length(header)))

        Enum.each(benchmarks, fn {task, slug, input_type, fun} ->
          input = if input_type == :gray, do: gray_tensor, else: tensor
          {stats, result_tensor} = run_bench(fun, input, iterations)

          # Ensure 3D shape for StbImage
          result_for_save =
            case Nx.rank(result_tensor) do
              2 ->
                {h2, w2} = Nx.shape(result_tensor)
                Nx.reshape(result_tensor, {h2, w2, 1})

              _ ->
                result_tensor
            end

          result_img = StbImage.from_nx(result_for_save)
          out_path = Path.join(output_dir, "#{slug}.png")
          StbImage.write_file!(result_img, out_path)

          :io.format("~-20s ~-25s ~12.6f ~12.6f ~12.6f ~12.6f ~12.6f ~12.6f~n", [
            task,
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
    task_filter = Enum.at(args, 2, nil)
    {image_path, iterations, task_filter}
  end

  # --- Invert ---

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

  # --- Grayscale ---

  defp grayscale_nx(tensor) do
    f = Nx.as_type(tensor, :f32)
    r = f[[.., .., 0]]
    g = f[[.., .., 1]]
    b = f[[.., .., 2]]

    Nx.add(Nx.add(Nx.multiply(r, 0.299), Nx.multiply(g, 0.587)), Nx.multiply(b, 0.114))
    |> Nx.round()
    |> Nx.clip(0, 255)
    |> Nx.as_type(:u8)
  end

  # --- Blur (5x5 box blur via window_sum) ---

  defp blur_nx(tensor) do
    tensor
    |> Nx.as_type(:f32)
    |> Nx.window_sum({5, 5, 1}, padding: :same)
    |> Nx.divide(25.0)
    |> Nx.round()
    |> Nx.clip(0, 255)
    |> Nx.as_type(:u8)
  end

  # --- Sobel edge detection ---

  defp sobel_nx(tensor) do
    {h, w} = Nx.shape(tensor)
    input = tensor |> Nx.as_type(:f32) |> Nx.reshape({1, 1, h, w})

    gx_kernel =
      Nx.tensor([[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]], type: :f32) |> Nx.reshape({1, 1, 3, 3})

    gy_kernel =
      Nx.tensor([[-1, -2, -1], [0, 0, 0], [1, 2, 1]], type: :f32) |> Nx.reshape({1, 1, 3, 3})

    gx = Nx.conv(input, gx_kernel, padding: :same)
    gy = Nx.conv(input, gy_kernel, padding: :same)

    Nx.sqrt(Nx.add(Nx.multiply(gx, gx), Nx.multiply(gy, gy)))
    |> Nx.reshape({h, w})
    |> Nx.clip(0, 255)
    |> Nx.as_type(:u8)
  end

  # --- Rotate 90 clockwise ---

  defp rotate90_nx(tensor) do
    # CW 90: reverse rows, then transpose spatial axes
    tensor
    |> Nx.reverse(axes: [0])
    |> Nx.transpose(axes: [1, 0, 2])
  end

  # --- Lee filter (7x7 window) ---

  defp lee_filter_nx(tensor) do
    f = Nx.as_type(tensor, :f32)
    overall_var = Nx.variance(f) |> Nx.to_number()

    if overall_var == 0.0 do
      tensor
    else
      overall_var_t = Nx.tensor(overall_var, type: :f32)
      local_sum = Nx.window_sum(f, {7, 7}, padding: :same)
      local_sq_sum = Nx.window_sum(Nx.multiply(f, f), {7, 7}, padding: :same)
      local_mean = Nx.divide(local_sum, 49.0)
      local_sq_mean = Nx.divide(local_sq_sum, 49.0)
      local_var = Nx.subtract(local_sq_mean, Nx.multiply(local_mean, local_mean))

      weight = Nx.divide(local_var, Nx.add(local_var, overall_var_t))
      result = Nx.add(local_mean, Nx.multiply(weight, Nx.subtract(f, local_mean)))

      result |> Nx.clip(0, 255) |> Nx.as_type(:u8)
    end
  end

  # --- Benchmark runner ---

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
