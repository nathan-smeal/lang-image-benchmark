# Haskell Image Benchmarks

## Implementations

| Slug | Library | Description |
|------|---------|-------------|
| juicypixels-invert | JuicyPixels | `pixelMap` with channel inversion (idiomatic) |
| haskell-manual | vector | Mutable `STVector` in-place byte inversion |

## Setup

Requires GHC and cabal:

```bash
cabal build
```

## Usage

```bash
# Default: ../images/lenna.png, 101 iterations
cabal run bench

# Custom image and iteration count
cabal run bench -- ../images/lenna.png 5
```

Output is a table matching the Python benchmark format.
