import numpy as np

from .base import Implementation


IMPLEMENTATIONS = [
    Implementation(
        task="invert",
        slug="numpy-invert",
        description="numpy.invert (bitwise NOT)",
        fn=np.invert,
        backend="numpy",
    ),
]
