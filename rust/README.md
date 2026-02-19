# Rust Image Benchmarks

## Implementations

| Slug | Library | Description |
|------|--------|-------------|
| image-invert | image crate | `imageops::colorops::invert()` built-in |
| image-manual | manual loop | `pixels_mut()` with `255 - channel` per pixel |

## Setup

```bash
cargo build --release
```

## Usage

```bash
# Default: ../images/lenna.png, 101 iterations
cargo run --release

# Custom image and iteration count
cargo run --release -- ../images/lenna.png 5
```

Output is a table matching the Python and C# benchmark format.
