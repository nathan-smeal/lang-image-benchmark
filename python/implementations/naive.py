import numpy as np

from .base import Implementation


def invert_naive(img: np.ndarray) -> np.ndarray:
    res = img.copy()
    for i in range(img.shape[0]):
        for j in range(img.shape[1]):
            for k in range(img.shape[2]):
                res[i][j][k] = abs(res[i][j][k] - 255)
    return res


IMPLEMENTATIONS = [
    Implementation(
        task="invert",
        slug="naive-invert",
        description="Pure Python triple loop inversion",
        fn=invert_naive,
        backend="numpy",
    ),
]
