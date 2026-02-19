from PIL import ImageChops

from .base import Implementation


IMPLEMENTATIONS = [
    Implementation(
        task="invert",
        slug="pillow-invert",
        description="PIL ImageChops.invert",
        fn=ImageChops.invert,
        backend="pillow",
    ),
]
