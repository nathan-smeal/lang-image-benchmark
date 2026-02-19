import os
import statistics
import time

import cv2
import numpy as np
from PIL import Image

from implementations.base import Implementation
from .types import BenchmarkConfig, BenchmarkResult


def run_single(impl: Implementation, config: BenchmarkConfig) -> BenchmarkResult:
    if impl.backend == "numpy":
        original = cv2.imread(config.image_path)
        if original is None:
            raise FileNotFoundError(f"Could not load image: {config.image_path}")
    else:
        original = Image.open(config.image_path)

    if impl.warmup:
        impl.fn(original.copy() if impl.backend == "numpy" else original.copy())

    times = []
    result_img = None
    for _ in range(config.iterations):
        img_copy = original.copy()
        start = time.perf_counter()
        result_img = impl.fn(img_copy)
        elapsed = time.perf_counter() - start
        times.append(elapsed)

    os.makedirs(config.output_dir, exist_ok=True)
    out_path = os.path.join(config.output_dir, f"{impl.slug}.png")
    if impl.backend == "numpy":
        cv2.imwrite(out_path, result_img)
    else:
        result_img.save(out_path)

    result = BenchmarkResult(
        task=impl.task,
        slug=impl.slug,
        description=impl.description,
        iterations=config.iterations,
        times=times,
        total=sum(times),
        mean=statistics.mean(times),
        median=statistics.median(times),
        std_dev=statistics.stdev(times) if len(times) > 1 else 0.0,
        min=min(times),
        max=max(times),
    )
    return result
