# Elixir Image Benchmarks

## Implementations

| Slug | Library | Description |
|------|---------|-------------|
| nx-invert | Nx | `Nx.subtract(255, tensor)` tensor operation |
| elixir-manual | binary comprehension | `for <<byte <- binary>>` byte-level inversion |

## Setup

Requires Elixir and OTP:

```bash
mix deps.get
```

## Usage

```bash
# Default: ../images/lenna.png, 101 iterations
mix run -e 'Bench.main([])'

# Custom image and iteration count
mix run -e 'Bench.main(["../images/lenna.png", "5"])'
```

Output is a table matching the Python benchmark format.
