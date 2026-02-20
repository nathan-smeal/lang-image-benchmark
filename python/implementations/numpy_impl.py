import numpy as np
from scipy.ndimage import uniform_filter

from .base import Implementation


def numpy_grayscale(img: np.ndarray) -> np.ndarray:
    weights = np.array([0.114, 0.587, 0.299], dtype=np.float64)
    return np.dot(img.astype(np.float64), weights).astype(np.uint8)


def numpy_rotate90(img: np.ndarray) -> np.ndarray:
    return np.rot90(img, k=-1)


def numpy_lee_filter(img: np.ndarray, window_size: int = 7) -> np.ndarray:
    img_f = img.astype(np.float64)
    mean = uniform_filter(img_f, size=window_size)
    mean_sq = uniform_filter(img_f * img_f, size=window_size)
    variance = mean_sq - mean * mean
    overall_variance = np.var(img_f)
    if overall_variance == 0:
        return img
    weight = variance / (variance + overall_variance)
    result = mean + weight * (img_f - mean)
    return np.clip(result, 0, 255).astype(np.uint8)


IMPLEMENTATIONS = [
    Implementation(
        task="invert",
        slug="numpy-invert",
        description="numpy.invert (bitwise NOT)",
        fn=np.invert,
        backend="numpy",
    ),
    Implementation(
        task="grayscale",
        slug="numpy-grayscale",
        description="numpy dot product grayscale",
        fn=numpy_grayscale,
        backend="numpy",
    ),
    Implementation(
        task="rotate_90",
        slug="numpy-rotate90",
        description="numpy.rot90 clockwise",
        fn=numpy_rotate90,
        backend="numpy",
    ),
    Implementation(
        task="lee_filter",
        slug="numpy-lee",
        description="numpy Lee filter with scipy uniform_filter",
        fn=numpy_lee_filter,
        backend="numpy",
        input_type="grayscale",
    ),
]
