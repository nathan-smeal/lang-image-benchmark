# lang-image-benchmark

Cross-language benchmark suite for common image processing operations.

## Languages

| Language | Directory | Implementations |
|----------|-----------|-----------------|
| Python | `python/` | NumPy, OpenCV, Pillow, Numba, pure Python |
| C# | `csharp/` | EmguCV |
| Rust | `rust/` | image crate (built-in invert, manual pixel loop) |
| C | `c/` | stb_image (manual byte loop) |
| C++ | `cpp/` | stb_image (std::transform, manual loop) |
| Haskell | `haskell/` | JuicyPixels (pixelMap, STVector) |
| Elixir | `elixir/` | Nx (tensor op, binary comprehension) |

## Tasks

- **invert** -- bitwise image inversion (255 - pixel)

## Prerequisites

- [Conda](https://docs.conda.io/en/latest/miniconda.html) (Miniconda or Anaconda)
- [.NET 8 SDK](https://dotnet.microsoft.com/en-us/download/dotnet/8.0)
- [Rust toolchain](https://rustup.rs/) (rustc + cargo)
- `gcc` (C compiler)
- `g++` (C++ compiler)
- [GHC](https://www.haskell.org/ghcup/) and cabal (Haskell)
- [Elixir](https://elixir-lang.org/install.html) and OTP

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

### C

Downloads stb headers automatically and compiles:

```bash
make -C c/
```

### C++

Downloads stb headers automatically and compiles:

```bash
make -C cpp/
```

### Haskell

Build with cabal:

```bash
cd haskell && cabal build && cd ..
```

### Elixir

Fetch dependencies:

```bash
cd elixir && mix deps.get && cd ..
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

### C Only

```bash
./c/c_bench images/lenna.png 101
```

### C++ Only

```bash
./cpp/cpp_bench images/lenna.png 101
```

### Haskell Only

```bash
cabal run --project-dir=haskell -- images/lenna.png 101
```

### Elixir Only

```bash
cd elixir && mix run -e 'Bench.main(["../images/lenna.png", "101"])'
```

## Output

All runners produce a table with the same columns (times in seconds):

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
image-invert             0.000081     0.000073     0.000018     0.000067     0.000127     0.008213
image-manual             0.000044     0.000046     0.000010     0.000022     0.000062     0.004420
```

All times are in seconds.

## Project Structure

```
├── run_all.sh                # Run all benchmarks
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
├── c/
│   ├── main.c                # CLI entrypoint
│   └── Makefile
├── cpp/
│   ├── main.cpp              # CLI entrypoint
│   └── Makefile
├── haskell/
│   ├── app/Main.hs           # CLI entrypoint
│   └── bench.cabal
├── elixir/
│   ├── lib/bench.ex          # CLI entrypoint (mix run)
│   └── mix.exs
└── output/                   # Generated result images (gitignored)
```
