# Python Image Benchmarks

## Tasks

- **invert** -- bitwise image inversion

## Implementations

| Slug | Library | Description |
|------|---------|-------------|
| numpy-invert | NumPy | `numpy.invert` (bitwise NOT) |
| cv2-bitwise | OpenCV | `cv2.bitwise_not` |
| cv2-absdiff | OpenCV | `cv2.absdiff(img, 255)` |
| pillow-invert | Pillow | `ImageChops.invert` |
| numba-invert | Numba | JIT-compiled triple loop |
| naive-invert | Pure Python | Triple loop (very slow, opt-in) |

## Setup

```bash
pip install -e .
```

## Usage

```bash
# Default: table output, 101 iterations
python run.py

# JSON output, 5 iterations
python run.py --format json -n 5

# Include the slow pure-Python implementation
python run.py --include-native -n 1

# Run only a specific implementation
python run.py --impl numba-invert -n 50
```
