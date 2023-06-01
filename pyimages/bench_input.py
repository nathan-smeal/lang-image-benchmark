from dataclasses import dataclass
from pathlib import Path


@dataclass
class BenchmarkInput:
    fp: Path
    iterations: int
    