from dataclasses import dataclass
from typing import Callable, Literal


@dataclass(frozen=True)
class Implementation:
    task: str
    slug: str
    description: str
    fn: Callable
    backend: Literal["numpy", "pillow"]
    input_type: Literal["rgb", "grayscale"] = "rgb"
    warmup: bool = False
