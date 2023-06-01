


from dataclasses import dataclass
from typing import List


@dataclass
class BenchmarkResult:
    task_name: str
    impl_slug: str
    impl_desc: str
    iterations: int
    times: List[float]
    mem_usage: List[float]