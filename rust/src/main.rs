use image::ImageReader;
use image::RgbImage;
use std::env;
use std::fs;
use std::path::Path;
use std::time::Instant;

struct Stats {
    mean: f64,
    median: f64,
    std_dev: f64,
    min: f64,
    max: f64,
    total: f64,
}

fn compute_stats(times: &mut Vec<f64>) -> Stats {
    times.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let n = times.len() as f64;
    let total: f64 = times.iter().sum();
    let mean = total / n;
    let median = times[times.len() / 2];
    let min = times[0];
    let max = times[times.len() - 1];
    let variance = if times.len() > 1 {
        times.iter().map(|t| (t - mean).powi(2)).sum::<f64>() / (n - 1.0)
    } else {
        0.0
    };
    let std_dev = variance.sqrt();
    Stats {
        mean,
        median,
        std_dev,
        min,
        max,
        total,
    }
}

fn invert_builtin(img: &mut RgbImage) {
    image::imageops::colorops::invert(img);
}

fn invert_manual(img: &mut RgbImage) {
    for pixel in img.pixels_mut() {
        pixel.0[0] = 255 - pixel.0[0];
        pixel.0[1] = 255 - pixel.0[1];
        pixel.0[2] = 255 - pixel.0[2];
    }
}

fn bench(
    name: &str,
    original: &RgbImage,
    iterations: usize,
    invert_fn: fn(&mut RgbImage),
    output_dir: &Path,
) -> Stats {
    let mut times = Vec::with_capacity(iterations);
    let mut result = original.clone();

    for _ in 0..iterations {
        let mut img = original.clone();
        let start = Instant::now();
        invert_fn(&mut img);
        let elapsed = start.elapsed().as_secs_f64();
        times.push(elapsed);
        result = img;
    }

    result
        .save(output_dir.join(format!("{}.png", name)))
        .expect("failed to save output image");

    compute_stats(&mut times)
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let image_path = args.get(1).map_or("../images/lenna.png", |s| s.as_str());
    let iterations: usize = args
        .get(2)
        .and_then(|s| s.parse().ok())
        .unwrap_or(101);

    let img = ImageReader::open(image_path)
        .unwrap_or_else(|_| panic!("failed to open image: {}", image_path))
        .decode()
        .unwrap_or_else(|_| panic!("failed to decode image: {}", image_path))
        .into_rgb8();

    let output_dir = Path::new(image_path)
        .parent()
        .unwrap_or(Path::new("."))
        .join("../output");
    fs::create_dir_all(&output_dir).expect("failed to create output directory");

    let benchmarks: Vec<(&str, fn(&mut RgbImage))> =
        vec![("image-invert", invert_builtin), ("image-manual", invert_manual)];

    let header = format!(
        "{:<20} {:>12} {:>12} {:>12} {:>12} {:>12} {:>12}",
        "slug", "mean", "median", "std_dev", "min", "max", "total"
    );
    println!("{}", header);
    println!("{}", "-".repeat(header.len()));

    for (name, func) in &benchmarks {
        let stats = bench(name, &img, iterations, *func, &output_dir);
        println!(
            "{:<20} {:>12.6} {:>12.6} {:>12.6} {:>12.6} {:>12.6} {:>12.6}",
            name, stats.mean, stats.median, stats.std_dev, stats.min, stats.max, stats.total
        );
    }
}
