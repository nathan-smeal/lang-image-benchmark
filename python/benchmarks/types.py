from dataclasses import dataclass, field
from typing import List


@dataclass
class BenchmarkConfig:
    image_path: str
    iterations: int
    output_dir: str


@dataclass
class BenchmarkResult:
    task: str
    slug: str
    description: str
    iterations: int
    times: List[float] = field(default_factory=list)
    mean: float = 0.0
    median: float = 0.0
    std_dev: float = 0.0
    min: float = 0.0
    max: float = 0.0
    total: float = 0.0
