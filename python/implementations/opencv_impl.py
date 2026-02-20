import cv2
import numpy as np

from .base import Implementation


def invert_cv2_absdiff(img: np.ndarray) -> np.ndarray:
    return cv2.absdiff(img, 255)


def cv2_grayscale(img: np.ndarray) -> np.ndarray:
    return cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)


def cv2_blur(img: np.ndarray) -> np.ndarray:
    return cv2.GaussianBlur(img, (5, 5), 1.0)


def cv2_sobel(img: np.ndarray) -> np.ndarray:
    gx = cv2.Sobel(img, cv2.CV_64F, 1, 0, ksize=3)
    gy = cv2.Sobel(img, cv2.CV_64F, 0, 1, ksize=3)
    mag = np.sqrt(gx * gx + gy * gy)
    return np.clip(mag, 0, 255).astype(np.uint8)


def cv2_canny(img: np.ndarray) -> np.ndarray:
    return cv2.Canny(img, 100, 200)


def cv2_rotate90(img: np.ndarray) -> np.ndarray:
    return cv2.rotate(img, cv2.ROTATE_90_CLOCKWISE)


def cv2_rotate45(img: np.ndarray) -> np.ndarray:
    h, w = img.shape[:2]
    cx, cy = w / 2, h / 2
    cos45 = np.cos(np.radians(45))
    sin45 = np.sin(np.radians(45))
    nw = int(w * cos45 + h * sin45)
    nh = int(w * sin45 + h * cos45)
    M = cv2.getRotationMatrix2D((cx, cy), 45, 1.0)
    M[0, 2] += (nw - w) / 2
    M[1, 2] += (nh - h) / 2
    return cv2.warpAffine(img, M, (nw, nh), flags=cv2.INTER_LINEAR)


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
    Implementation(
        task="grayscale",
        slug="cv2-grayscale",
        description="cv2.cvtColor BGR2GRAY",
        fn=cv2_grayscale,
        backend="numpy",
    ),
    Implementation(
        task="blur",
        slug="cv2-blur",
        description="cv2.GaussianBlur 5x5 sigma=1.0",
        fn=cv2_blur,
        backend="numpy",
    ),
    Implementation(
        task="edge_detect_sobel",
        slug="cv2-sobel",
        description="cv2.Sobel 3x3 gradient magnitude",
        fn=cv2_sobel,
        backend="numpy",
        input_type="grayscale",
    ),
    Implementation(
        task="edge_detect_canny",
        slug="cv2-canny",
        description="cv2.Canny thresholds 100/200",
        fn=cv2_canny,
        backend="numpy",
        input_type="grayscale",
    ),
    Implementation(
        task="rotate_90",
        slug="cv2-rotate90",
        description="cv2.rotate ROTATE_90_CLOCKWISE",
        fn=cv2_rotate90,
        backend="numpy",
    ),
    Implementation(
        task="rotate_arbitrary",
        slug="cv2-rotate45",
        description="cv2.warpAffine 45 deg bilinear",
        fn=cv2_rotate45,
        backend="numpy",
    ),
]
