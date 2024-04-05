from argparse import ArgumentParser
from opencv_implementation import invert_cv2absdiff
from naive_implementation import invert_naive
from numba_implementation import numba_invert
from pathlib import Path
from time import time
from typing import Callable, Union
import cv2
from PIL import ImageChops
from PIL import Image
import numpy as np
from benchmark_result import BenchmarkResult
from bench_input import BenchmarkInput


def run_task(
    inputs: BenchmarkInput,
    task_name: str,
    fn: Union[Callable[[np.ndarray], np.ndarray], Callable[[Image.Image], Image.Image]],
    impl_slug: str,
    impl_desc: str,
    numpy_based=True,
) -> BenchmarkResult:
    if numpy_based:
        img = cv2.imread(str(inputs.fp))
    else:
        img = Image.open(str(inputs.fp))
    mem_results = []
    time_results = []
    start = time()
    for i in range(inputs.iterations):
        img = fn(img)
    print(impl_slug)
    print(time() - start)
    if numpy_based:
        cv2.imwrite(impl_slug + ".png", img)
    else:
        img.save(impl_slug + ".png")
    return BenchmarkResult(
        task_name=task_name,
        impl_slug=impl_slug,
        impl_desc=impl_desc,
        times=time_results,
        mem_usage=mem_results,
        iterations=inputs.iterations,
    )


def main():
    parser = ArgumentParser()

    parser.add_argument(
        "-n",
        "--Native",
        action="store_true",
        help="Run really slow native python loops",
        default=False,
        required=False,
    )
    args = parser.parse_args()
    fp = Path(__file__).parent / "images" / "lenna.png"
    iterations = 101
    cv2.imwrite("inverted-numpy.png", np.invert(cv2.imread(str(fp))))
    cv2.imwrite("inverted-numba.png", numba_invert(cv2.imread(str(fp))))
    cv2.imwrite("inverted-cv2.png", cv2.bitwise_not(cv2.imread(str(fp))))
    inputs = BenchmarkInput(fp, iterations)
    invert_cv2_bit_res = run_task(
        inputs,
        "invert",
        np.invert,
        "numpy-invert",
        "Inverts the colors of an image with numpy invert",
    )
    invert_cv2_bit_res = run_task(
        inputs,
        "invert",
        cv2.bitwise_not,
        "cv2-bitwise",
        "Inverts the colors of an image with a bitwise not via opencv in python",
    )
    invert_cv2_bit_res = run_task(
        inputs,
        "invert",
        invert_cv2absdiff,
        "cv2-absdiff",
        "Inverts the colors of an image with a naive absdiff with max px value not via opencv in python",
    )
    invert_cv2_bit_res = run_task(
        inputs,
        "invert",
        ImageChops.invert,
        "pillow-invert",
        "Inverts the colors of an image with a naive absdiff with max px value not via opencv in python",
        False,
    )
    invert_cv2_bit_res = run_task(
        inputs,
        "invert",
        numba_invert,
        "numba-invert",
        "Inverts the colors of an image with a pure python loop and numba in python",
    )
    # this is a WIP, but don't run this with more than like 100;
    # naive may need a catch and reduce number of iterations to 1 and multiply by iterations for sanity
    if args.Native:
        invert_cv2_bit_res = run_task(
            inputs,
            "invert",
            invert_naive,
            "naive-invert",
            "Inverts the colors of an image with a pure python loop and nothing else... in python",
        )


if __name__ == "__main__":
    # gui()
    main()
# https://upload.wikimedia.org/wikipedia/en/thumb/7/7d/Lenna_%28test_image%29.png/220px-Lenna_%28test_image%29.png
