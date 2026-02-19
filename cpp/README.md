# C++ Image Benchmarks

## Implementations

| Slug | Library | Description |
|------|---------|-------------|
| cpp-transform | stb_image | `std::transform` with lambda `255 - c` |
| cpp-manual | manual loop | Raw pointer loop with `255 - pixel` |

## Setup

```bash
make
```

This downloads the stb header-only libraries automatically and compiles `cpp_bench`.

## Usage

```bash
# Default: ../images/lenna.png, 101 iterations
./cpp_bench

# Custom image and iteration count
./cpp_bench ../images/lenna.png 5
```

Output is a table matching the Python benchmark format.
