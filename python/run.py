import argparse
import sys
from pathlib import Path

from benchmarks.runner import run_single
from benchmarks.types import BenchmarkConfig
from benchmarks.output import to_json, to_csv, to_table
from implementations import ALL_IMPLEMENTATIONS, NAIVE_SLUGS


def main():
    parser = argparse.ArgumentParser(description="Image processing benchmark suite")
    parser.add_argument("--image", default=str(Path(__file__).resolve().parent.parent / "images" / "lenna.png"),
                        help="Path to input image")
    parser.add_argument("-n", "--iterations", type=int, default=101,
                        help="Number of iterations per benchmark")
    parser.add_argument("--include-native", action="store_true",
                        help="Include slow pure-Python implementations")
    parser.add_argument("--task", default=None,
                        help="Filter to a specific task (e.g. 'invert')")
    parser.add_argument("--impl", default=None,
                        help="Filter to a specific implementation slug")
    parser.add_argument("--format", choices=["table", "json", "csv"], default="table",
                        help="Output format")
    parser.add_argument("--output-dir", default=str(Path(__file__).resolve().parent.parent / "output"),
                        help="Directory for output images")
    args = parser.parse_args()

    impls = ALL_IMPLEMENTATIONS
    if not args.include_native:
        impls = [i for i in impls if i.slug not in NAIVE_SLUGS]
    if args.task:
        impls = [i for i in impls if i.task == args.task]
    if args.impl:
        impls = [i for i in impls if i.slug == args.impl]

    if not impls:
        print("No implementations match the given filters.", file=sys.stderr)
        sys.exit(1)

    config = BenchmarkConfig(
        image_path=args.image,
        iterations=args.iterations,
        output_dir=args.output_dir,
    )

    results = []
    for impl in impls:
        print(f"Running {impl.slug}...", file=sys.stderr)
        result = run_single(impl, config)
        results.append(result)

    if args.format == "json":
        print(to_json(results))
    elif args.format == "csv":
        print(to_csv(results))
    else:
        print(to_table(results))


if __name__ == "__main__":
    main()
