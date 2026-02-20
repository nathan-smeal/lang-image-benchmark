import numba
import numpy as np

from .base import Implementation


@numba.njit
def numba_invert(img: np.ndarray) -> np.ndarray:
    res = img.copy()
    for i in range(img.shape[0]):
        for j in range(img.shape[1]):
            for k in range(img.shape[2]):
                res[i][j][k] = abs(res[i][j][k] - 255)
    return res


@numba.njit
def numba_grayscale(img: np.ndarray) -> np.ndarray:
    h, w = img.shape[0], img.shape[1]
    out = np.empty((h, w), dtype=np.uint8)
    for i in range(h):
        for j in range(w):
            b = img[i, j, 0]
            g = img[i, j, 1]
            r = img[i, j, 2]
            out[i, j] = np.uint8(0.299 * r + 0.587 * g + 0.114 * b)
    return out


IMPLEMENTATIONS = [
    Implementation(
        task="invert",
        slug="numba-invert",
        description="Numba JIT-compiled triple loop inversion",
        fn=numba_invert,
        backend="numpy",
        warmup=True,
    ),
    Implementation(
        task="grayscale",
        slug="numba-grayscale",
        description="Numba JIT-compiled grayscale loop",
        fn=numba_grayscale,
        backend="numpy",
        warmup=True,
    ),
]
