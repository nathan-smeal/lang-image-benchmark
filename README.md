# lang-image-benchmark

Cross-language benchmark suite for common image processing operations.

## Languages

| Language | Directory | Implementations |
|----------|-----------|-----------------|
| Python | `python/` | NumPy, OpenCV, Pillow, Numba, pure Python |
| C# | `csharp/` | EmguCV |

## Tasks

- **invert** -- bitwise image inversion (255 - pixel)

## Quick Start

### Python

```bash
cd python
pip install -e .
python run.py --format json -n 5
```

### C#

```bash
dotnet run --project csharp/ -- images/lenna.png 5
```

## Output

Both runners produce JSON with the same schema:

```json
[
  {
    "task": "invert",
    "slug": "numpy-invert",
    "description": "numpy.invert (bitwise NOT)",
    "iterations": 5,
    "mean": 0.000123,
    "median": 0.000120,
    "std_dev": 0.000005,
    "min": 0.000118,
    "max": 0.000132,
    "total": 0.000615,
    "times": [0.000132, 0.000120, 0.000118, 0.000125, 0.000120]
  }
]
```

Result images are saved to `output/` for visual verification.

## Project Structure

```
├── images/lenna.png          # Shared test image
├── python/
│   ├── run.py                # CLI entrypoint
│   ├── benchmarks/           # Runner, types, output formatters
│   └── implementations/      # One file per library
├── csharp/
│   ├── Program.cs            # CLI entrypoint with JSON output
│   └── csharp_bench.csproj
└── output/                   # Generated result images (gitignored)
```
