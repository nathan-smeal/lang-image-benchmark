import cv2
import numpy as np

from .base import Implementation


def invert_cv2_absdiff(img: np.ndarray) -> np.ndarray:
    return cv2.absdiff(img, 255)


IMPLEMENTATIONS = [
    Implementation(
        task="invert",
        slug="cv2-bitwise",
        description="cv2.bitwise_not",
        fn=cv2.bitwise_not,
        backend="numpy",
    ),
    Implementation(
        task="invert",
        slug="cv2-absdiff",
        description="cv2.absdiff(img, 255)",
        fn=invert_cv2_absdiff,
        backend="numpy",
    ),
]
