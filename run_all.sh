#!/usr/bin/env bash
set -e

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
eval "$(conda shell.bash hook)"
conda activate image-bench
python python/run.py -n "$ITERATIONS" --format table
conda deactivate
echo

# --- C# Benchmarks ---
echo "========================================="
echo "  C# Benchmarks"
echo "========================================="
dotnet run --project csharp/ -- images/lenna.png "$ITERATIONS"
