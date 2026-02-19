# C Image Benchmarks

## Implementations

| Slug | Library | Description |
|------|---------|-------------|
| c-invert | stb_image | Manual byte loop `255 - pixels[i]` |

## Setup

```bash
make
```

This downloads the stb header-only libraries automatically and compiles `c_bench`.

## Usage

```bash
# Default: ../images/lenna.png, 101 iterations
./c_bench

# Custom image and iteration count
./c_bench ../images/lenna.png 5
```

Output is a table matching the Python benchmark format.
