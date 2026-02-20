from PIL import Image, ImageChops, ImageFilter

from .base import Implementation


def pillow_grayscale(img: Image.Image) -> Image.Image:
    return img.convert("L")


def pillow_blur(img: Image.Image) -> Image.Image:
    return img.filter(ImageFilter.GaussianBlur(radius=2))


def pillow_rotate90(img: Image.Image) -> Image.Image:
    return img.transpose(Image.Transpose.ROTATE_270)


def pillow_rotate45(img: Image.Image) -> Image.Image:
    return img.rotate(-45, resample=Image.Resampling.BILINEAR, expand=True)


IMPLEMENTATIONS = [
    Implementation(
        task="invert",
        slug="pillow-invert",
        description="PIL ImageChops.invert",
        fn=ImageChops.invert,
        backend="pillow",
    ),
    Implementation(
        task="grayscale",
        slug="pillow-grayscale",
        description="PIL Image.convert('L')",
        fn=pillow_grayscale,
        backend="pillow",
    ),
    Implementation(
        task="blur",
        slug="pillow-blur",
        description="PIL GaussianBlur",
        fn=pillow_blur,
        backend="pillow",
    ),
    Implementation(
        task="rotate_90",
        slug="pillow-rotate90",
        description="PIL transpose ROTATE_270",
        fn=pillow_rotate90,
        backend="pillow",
    ),
    Implementation(
        task="rotate_arbitrary",
        slug="pillow-rotate45",
        description="PIL rotate -45 bilinear expand",
        fn=pillow_rotate45,
        backend="pillow",
    ),
]
