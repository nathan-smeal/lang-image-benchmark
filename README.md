# lang-image-benchmark

Cross-language benchmark suite for common image processing operations.

## Languages

| Language | Directory | Implementations |
|----------|-----------|-----------------|
| Python | `python/` | NumPy, OpenCV, Pillow, Numba, pure Python |
| C# | `csharp/` | EmguCV |
| Rust | `rust/` | image crate (built-in invert, manual pixel loop) |

## Tasks

- **invert** -- bitwise image inversion (255 - pixel)

## Prerequisites

- [Conda](https://docs.conda.io/en/latest/miniconda.html) (Miniconda or Anaconda)
- [.NET 8 SDK](https://dotnet.microsoft.com/en-us/download/dotnet/8.0)
- [Rust toolchain](https://rustup.rs/) (rustc + cargo)

## Setup

### Python

Create the conda environment and install dependencies:

```bash
conda create -n image-bench python=3.10 -y
conda activate image-bench
pip install -e python/
```

### C#

Restore NuGet packages (also happens automatically on first `dotnet run`):

```bash
dotnet restore csharp/
```

### Rust

Build in release mode:

```bash
cargo build --release --manifest-path rust/Cargo.toml
```

## Quick Start

### Run All Benchmarks

```bash
./run_all.sh          # default 101 iterations
./run_all.sh 5        # custom iteration count
```

### Python Only

```bash
conda activate image-bench
python python/run.py --format table -n 101
```

### C# Only

```bash
dotnet run --project csharp/ -- images/lenna.png 101
```

### Rust Only

```bash
cargo run --release --manifest-path rust/Cargo.toml -- images/lenna.png 101
```

## Output

Both runners produce a table with the same columns (times in seconds):

```
slug                         mean       median      std_dev          min          max        total
--------------------------------------------------------------------------------------------------
numpy-invert             0.000006     0.000004     0.000007     0.000004     0.000074     0.000561
```

Python also supports `--format json` and `--format csv`. Result images are saved to `output/` for visual verification.

## Example Results

Test image: `images/lenna.png` (512x512 RGB), 101 iterations, Ubuntu 20.04 on WSL2.

### Python

```
slug                         mean       median      std_dev          min          max        total
--------------------------------------------------------------------------------------------------
numpy-invert             0.000006     0.000004     0.000007     0.000004     0.000074     0.000561
cv2-bitwise              0.000015     0.000013     0.000007     0.000011     0.000064     0.001467
cv2-absdiff              0.000016     0.000015     0.000005     0.000013     0.000058     0.001634
pillow-invert            0.000302     0.000309     0.000037     0.000233     0.000442     0.030453
numba-invert             0.000124     0.000136     0.000029     0.000065     0.000178     0.012496
```

### C#

```
slug                         mean       median      std_dev          min          max        total
--------------------------------------------------------------------------------------------------
emgucv-invert            0.000090     0.000076     0.000072     0.000027     0.000545     0.009070
```

### Rust

```
slug                         mean       median      std_dev          min          max        total
--------------------------------------------------------------------------------------------------
image-invert             0.000050     0.000048     0.000010     0.000040     0.000120     0.005050
image-manual             0.000200     0.000195     0.000020     0.000180     0.000300     0.020200
```

All times are in seconds.

## Project Structure

```
├── run_all.sh                # Run all benchmarks (Python + C# + Rust)
├── images/lenna.png          # Shared test image
├── python/
│   ├── run.py                # CLI entrypoint
│   ├── benchmarks/           # Runner, types, output formatters
│   └── implementations/      # One file per library
├── csharp/
│   ├── Program.cs            # CLI entrypoint
│   └── csharp_bench.csproj
├── rust/
│   ├── src/main.rs           # CLI entrypoint
│   └── Cargo.toml
└── output/                   # Generated result images (gitignored)
```
