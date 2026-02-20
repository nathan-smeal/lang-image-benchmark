import numpy as np

from .base import Implementation


def invert_naive(img: np.ndarray) -> np.ndarray:
    res = img.copy()
    for i in range(img.shape[0]):
        for j in range(img.shape[1]):
            for k in range(img.shape[2]):
                res[i][j][k] = abs(res[i][j][k] - 255)
    return res


def grayscale_naive(img: np.ndarray) -> np.ndarray:
    h, w = img.shape[0], img.shape[1]
    out = np.empty((h, w), dtype=np.uint8)
    for i in range(h):
        for j in range(w):
            b = int(img[i, j, 0])
            g = int(img[i, j, 1])
            r = int(img[i, j, 2])
            out[i, j] = int(0.299 * r + 0.587 * g + 0.114 * b)
    return out


IMPLEMENTATIONS = [
    Implementation(
        task="invert",
        slug="naive-invert",
        description="Pure Python triple loop inversion",
        fn=invert_naive,
        backend="numpy",
    ),
    Implementation(
        task="grayscale",
        slug="naive-grayscale",
        description="Pure Python triple loop grayscale",
        fn=grayscale_naive,
        backend="numpy",
    ),
]
