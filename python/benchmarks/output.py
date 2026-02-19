import csv
import io
import json
from typing import List

from .types import BenchmarkResult


def to_json(results: List[BenchmarkResult]) -> str:
    rows = []
    for r in results:
        rows.append({
            "task": r.task,
            "slug": r.slug,
            "description": r.description,
            "iterations": r.iterations,
            "mean": r.mean,
            "median": r.median,
            "std_dev": r.std_dev,
            "min": r.min,
            "max": r.max,
            "total": r.total,
            "times": r.times,
        })
    return json.dumps(rows, indent=2)


def to_csv(results: List[BenchmarkResult]) -> str:
    buf = io.StringIO()
    writer = csv.writer(buf)
    writer.writerow(["task", "slug", "description", "iterations",
                     "mean", "median", "std_dev", "min", "max", "total"])
    for r in results:
        writer.writerow([r.task, r.slug, r.description, r.iterations,
                         r.mean, r.median, r.std_dev, r.min, r.max, r.total])
    return buf.getvalue()


def to_table(results: List[BenchmarkResult]) -> str:
    header = f"{'slug':<20} {'mean':>12} {'median':>12} {'std_dev':>12} {'min':>12} {'max':>12} {'total':>12}"
    sep = "-" * len(header)
    lines = [header, sep]
    for r in results:
        lines.append(
            f"{r.slug:<20} {r.mean:>12.6f} {r.median:>12.6f} {r.std_dev:>12.6f} {r.min:>12.6f} {r.max:>12.6f} {r.total:>12.6f}"
        )
    return "\n".join(lines)
