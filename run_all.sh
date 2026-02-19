#!/usr/bin/env bash

# Add toolchain paths if installed
[ -d "$HOME/.ghcup/bin" ] && export PATH="$HOME/.ghcup/bin:$PATH"
[ -d "$HOME/.local/lib" ] && export LIBRARY_PATH="$HOME/.local/lib:${LIBRARY_PATH:-}"
[ -f "$HOME/.asdf/asdf.sh" ] && source "$HOME/.asdf/asdf.sh"

ITERATIONS="${1:-101}"

echo "========================================="
echo "  Language Image Benchmark Suite"
echo "  Iterations: $ITERATIONS"
echo "========================================="
echo

# --- Python Benchmarks ---
echo "========================================="
echo "  Python Benchmarks"
echo "========================================="
if eval "$(conda shell.bash hook)" 2>/dev/null && conda activate image-bench 2>/dev/null; then
    python python/run.py -n "$ITERATIONS" --format table
    conda deactivate
else
    echo "  SKIPPED: conda environment 'image-bench' not available"
fi
echo

# --- C# Benchmarks ---
echo "========================================="
echo "  C# Benchmarks"
echo "========================================="
if command -v dotnet &>/dev/null; then
    dotnet run --project csharp/ -- images/lenna.png "$ITERATIONS"
else
    echo "  SKIPPED: dotnet not found"
fi
echo

# --- Rust Benchmarks ---
echo "========================================="
echo "  Rust Benchmarks"
echo "========================================="
if command -v cargo &>/dev/null; then
    cargo run --release --manifest-path rust/Cargo.toml -- images/lenna.png "$ITERATIONS"
else
    echo "  SKIPPED: cargo not found"
fi
echo

# --- C Benchmarks ---
echo "========================================="
echo "  C Benchmarks"
echo "========================================="
if [ -x ./c/c_bench ]; then
    ./c/c_bench images/lenna.png "$ITERATIONS"
else
    echo "  SKIPPED: ./c/c_bench not built (run 'make -C c/')"
fi
echo

# --- C++ Benchmarks ---
echo "========================================="
echo "  C++ Benchmarks"
echo "========================================="
if [ -x ./cpp/cpp_bench ]; then
    ./cpp/cpp_bench images/lenna.png "$ITERATIONS"
else
    echo "  SKIPPED: ./cpp/cpp_bench not built (run 'make -C cpp/')"
fi
echo

# --- Haskell Benchmarks ---
echo "========================================="
echo "  Haskell Benchmarks"
echo "========================================="
if command -v cabal &>/dev/null; then
    (cd haskell && cabal run bench -- ../images/lenna.png "$ITERATIONS")
else
    echo "  SKIPPED: cabal not found"
fi
echo

# --- Elixir Benchmarks ---
echo "========================================="
echo "  Elixir Benchmarks"
echo "========================================="
if command -v mix &>/dev/null; then
    (cd elixir && mix run --no-deps-check -e "Bench.main([\"../images/lenna.png\", \"$ITERATIONS\"])")
else
    echo "  SKIPPED: mix not found"
fi
