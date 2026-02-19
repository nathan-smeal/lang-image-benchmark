# C# Image Benchmarks

## Implementation

| Slug | Library | Description |
|------|---------|-------------|
| emgucv-invert | EmguCV | `Image.Not()` bitwise inversion |

## Setup

```bash
dotnet restore
```

## Usage

```bash
# Default: ../images/lenna.png, 101 iterations
dotnet run

# Custom image and iteration count
dotnet run -- ../images/lenna.png 5
```

Output is a table matching the Python benchmark format.
