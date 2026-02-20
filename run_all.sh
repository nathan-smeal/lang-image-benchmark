#!/usr/bin/env bash

# Add toolchain paths if installed
[ -d "$HOME/.ghcup/bin" ] && export PATH="$HOME/.ghcup/bin:$PATH"
[ -d "$HOME/.local/lib" ] && export LIBRARY_PATH="$HOME/.local/lib:${LIBRARY_PATH:-}"
[ -f "$HOME/.asdf/asdf.sh" ] && source "$HOME/.asdf/asdf.sh"

ITERATIONS="${1:-101}"
TASK="${2:-}"

RESULTS_FILE=$(mktemp)
trap "rm -f $RESULTS_FILE" EXIT

echo "=========================================" >&2
echo "  Language Image Benchmark Suite" >&2
echo "  Iterations: $ITERATIONS" >&2
[ -n "$TASK" ] && echo "  Task filter: $TASK" >&2
echo "=========================================" >&2
echo >&2

# Helper: extract data lines (skip header + separator) and append to results
collect_output() {
    local output="$1"
    if [ -n "$output" ]; then
        echo "$output" | tail -n +3 >> "$RESULTS_FILE"
    fi
}

# --- Python ---
echo "  Running Python..." >&2
if eval "$(conda shell.bash hook)" 2>/dev/null && conda activate image-bench 2>/dev/null; then
    PYTHON_ARGS="-n $ITERATIONS --format table"
    [ -n "$TASK" ] && PYTHON_ARGS="$PYTHON_ARGS --task $TASK"
    output=$(python python/run.py $PYTHON_ARGS 2>/dev/null)
    collect_output "$output"
    conda deactivate
else
    echo "    SKIPPED: conda environment 'image-bench' not available" >&2
fi

# --- C# ---
echo "  Running C#..." >&2
if command -v dotnet &>/dev/null; then
    CSHARP_ARGS="images/lenna.png $ITERATIONS"
    [ -n "$TASK" ] && CSHARP_ARGS="$CSHARP_ARGS $TASK"
    output=$(dotnet run --project csharp/ -- $CSHARP_ARGS 2>/dev/null)
    collect_output "$output"
else
    echo "    SKIPPED: dotnet not found" >&2
fi

# --- Rust ---
echo "  Running Rust..." >&2
if command -v cargo &>/dev/null; then
    RUST_ARGS="images/lenna.png $ITERATIONS"
    [ -n "$TASK" ] && RUST_ARGS="$RUST_ARGS $TASK"
    output=$(cargo run --release --manifest-path rust/Cargo.toml -- $RUST_ARGS 2>/dev/null)
    collect_output "$output"
else
    echo "    SKIPPED: cargo not found" >&2
fi

# --- C ---
echo "  Running C..." >&2
if [ -x ./c/c_bench ]; then
    C_ARGS="images/lenna.png $ITERATIONS"
    [ -n "$TASK" ] && C_ARGS="$C_ARGS $TASK"
    output=$(./c/c_bench $C_ARGS 2>/dev/null)
    collect_output "$output"
else
    echo "    SKIPPED: ./c/c_bench not built (run 'make -C c/')" >&2
fi

# --- C++ ---
echo "  Running C++..." >&2
if [ -x ./cpp/cpp_bench ]; then
    CPP_ARGS="images/lenna.png $ITERATIONS"
    [ -n "$TASK" ] && CPP_ARGS="$CPP_ARGS $TASK"
    output=$(./cpp/cpp_bench $CPP_ARGS 2>/dev/null)
    collect_output "$output"
else
    echo "    SKIPPED: ./cpp/cpp_bench not built (run 'make -C cpp/')" >&2
fi

# --- Haskell ---
echo "  Running Haskell..." >&2
if command -v cabal &>/dev/null; then
    HASKELL_ARGS="../images/lenna.png $ITERATIONS"
    [ -n "$TASK" ] && HASKELL_ARGS="$HASKELL_ARGS $TASK"
    output=$(cd haskell && cabal run bench -- $HASKELL_ARGS 2>/dev/null)
    collect_output "$output"
else
    echo "    SKIPPED: cabal not found" >&2
fi

# --- Elixir ---
echo "  Running Elixir..." >&2
if command -v mix &>/dev/null; then
    ELIXIR_ARGS="\"../images/lenna.png\", \"$ITERATIONS\""
    [ -n "$TASK" ] && ELIXIR_ARGS="$ELIXIR_ARGS, \"$TASK\""
    output=$(cd elixir && mix run --no-deps-check -e "Bench.main([$ELIXIR_ARGS])" 2>/dev/null)
    collect_output "$output"
else
    echo "    SKIPPED: mix not found" >&2
fi

echo >&2

# --- Print combined results grouped by task ---
if [ ! -s "$RESULTS_FILE" ]; then
    echo "No results collected." >&2
    exit 1
fi

header=$(printf "%-20s %-25s %12s %12s %12s %12s %12s %12s" \
    "task" "slug" "mean" "median" "std_dev" "min" "max" "total")
echo "$header"
printf '%0.s-' $(seq 1 ${#header}); echo

# Sort by task then by median (column 4, numeric), group with blank lines between tasks
sort -k1,1 -k4,4n "$RESULTS_FILE" | awk '{
    if (prev != "" && prev != $1) print ""
    prev = $1
    print
}'
