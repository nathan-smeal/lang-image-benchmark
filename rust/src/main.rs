use image::imageops;
use image::{GrayImage, ImageReader, Luma, Rgb, RgbImage};
use imageproc::edges::canny;
use imageproc::filter::gaussian_blur_f32;
use imageproc::gradients::{horizontal_sobel, vertical_sobel};
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

// --- Invert ---

fn invert_builtin(img: &mut RgbImage) {
    imageops::colorops::invert(img);
}

fn invert_manual(img: &mut RgbImage) {
    for pixel in img.pixels_mut() {
        pixel.0[0] = 255 - pixel.0[0];
        pixel.0[1] = 255 - pixel.0[1];
        pixel.0[2] = 255 - pixel.0[2];
    }
}

// --- Grayscale ---

fn grayscale_image(img: &RgbImage) -> GrayImage {
    imageops::grayscale(img)
}

fn grayscale_manual(img: &RgbImage) -> GrayImage {
    let (w, h) = img.dimensions();
    let mut out = GrayImage::new(w, h);
    for y in 0..h {
        for x in 0..w {
            let p = img.get_pixel(x, y);
            let r = p.0[0] as f64;
            let g = p.0[1] as f64;
            let b = p.0[2] as f64;
            let gray = (0.299 * r + 0.587 * g + 0.114 * b) as u8;
            out.put_pixel(x, y, Luma([gray]));
        }
    }
    out
}

// --- Blur ---

fn blur_gaussian(img: &RgbImage) -> RgbImage {
    gaussian_blur_f32(img, 1.0)
}

// --- Sobel edge detection ---

fn sobel_gradient(img: &GrayImage) -> GrayImage {
    let gx = horizontal_sobel(img);
    let gy = vertical_sobel(img);
    let (w, h) = img.dimensions();
    let mut out = GrayImage::new(w, h);
    for y in 0..h {
        for x in 0..w {
            let gx_val = gx.get_pixel(x, y).0[0] as f64;
            let gy_val = gy.get_pixel(x, y).0[0] as f64;
            let mag = (gx_val * gx_val + gy_val * gy_val).sqrt();
            out.put_pixel(x, y, Luma([mag.min(255.0) as u8]));
        }
    }
    out
}

// --- Canny edge detection ---

fn canny_detect(img: &GrayImage) -> GrayImage {
    canny(img, 100.0, 200.0)
}

// --- Rotate 90 ---

fn rotate90_image(img: &RgbImage) -> RgbImage {
    imageops::rotate90(img)
}

// --- Rotate 45 (arbitrary, bilinear interpolation, expanded canvas) ---

fn rotate45_bilinear(img: &RgbImage) -> RgbImage {
    let (w, h) = img.dimensions();
    let (wf, hf) = (w as f64, h as f64);
    let angle = std::f64::consts::FRAC_PI_4;
    let cos_a = angle.cos();
    let sin_a = angle.sin();

    let nw = (wf * cos_a + hf * sin_a).ceil() as u32;
    let nh = (wf * sin_a + hf * cos_a).ceil() as u32;

    let cx = wf / 2.0;
    let cy = hf / 2.0;
    let ncx = nw as f64 / 2.0;
    let ncy = nh as f64 / 2.0;

    let mut out = RgbImage::new(nw, nh);

    for oy in 0..nh {
        for ox in 0..nw {
            let dx = ox as f64 - ncx;
            let dy = oy as f64 - ncy;
            let sx = dx * cos_a + dy * sin_a + cx;
            let sy = -dx * sin_a + dy * cos_a + cy;

            if sx >= 0.0 && sx < wf - 1.0 && sy >= 0.0 && sy < hf - 1.0 {
                let x0 = sx.floor() as u32;
                let y0 = sy.floor() as u32;
                let x1 = x0 + 1;
                let y1 = y0 + 1;
                let fx = sx - sx.floor();
                let fy = sy - sy.floor();

                let p00 = img.get_pixel(x0, y0);
                let p10 = img.get_pixel(x1, y0);
                let p01 = img.get_pixel(x0, y1);
                let p11 = img.get_pixel(x1, y1);

                let mut rgb = [0u8; 3];
                for c in 0..3 {
                    let v = (1.0 - fx) * (1.0 - fy) * p00.0[c] as f64
                        + fx * (1.0 - fy) * p10.0[c] as f64
                        + (1.0 - fx) * fy * p01.0[c] as f64
                        + fx * fy * p11.0[c] as f64;
                    rgb[c] = v.round().clamp(0.0, 255.0) as u8;
                }
                out.put_pixel(ox, oy, Rgb(rgb));
            }
        }
    }
    out
}

// --- Lee filter ---

fn lee_filter_manual(img: &GrayImage) -> GrayImage {
    let (w, h) = img.dimensions();
    let half: u32 = 3;

    let mut sum_all = 0.0f64;
    let mut sum_sq_all = 0.0f64;
    let total_pixels = (w * h) as f64;
    for y in 0..h {
        for x in 0..w {
            let v = img.get_pixel(x, y).0[0] as f64;
            sum_all += v;
            sum_sq_all += v * v;
        }
    }
    let overall_mean = sum_all / total_pixels;
    let overall_var = sum_sq_all / total_pixels - overall_mean * overall_mean;

    let mut out = GrayImage::new(w, h);

    if overall_var == 0.0 {
        return img.clone();
    }

    for y in 0..h {
        for x in 0..w {
            let mut local_sum = 0.0f64;
            let mut local_sq = 0.0f64;
            let mut count = 0.0f64;

            let y_start = y.saturating_sub(half);
            let y_end = (y + half + 1).min(h);
            let x_start = x.saturating_sub(half);
            let x_end = (x + half + 1).min(w);

            for wy in y_start..y_end {
                for wx in x_start..x_end {
                    let v = img.get_pixel(wx, wy).0[0] as f64;
                    local_sum += v;
                    local_sq += v * v;
                    count += 1.0;
                }
            }

            let local_mean = local_sum / count;
            let local_var = local_sq / count - local_mean * local_mean;
            let weight = local_var / (local_var + overall_var);
            let val = local_mean + weight * (img.get_pixel(x, y).0[0] as f64 - local_mean);
            out.put_pixel(x, y, Luma([val.round().clamp(0.0, 255.0) as u8]));
        }
    }
    out
}

// --- Benchmark infrastructure ---

enum BenchFn {
    RgbMut(fn(&mut RgbImage)),
    RgbToRgb(fn(&RgbImage) -> RgbImage),
    RgbToGray(fn(&RgbImage) -> GrayImage),
    GrayToGray(fn(&GrayImage) -> GrayImage),
}

struct BenchmarkDef {
    task: &'static str,
    slug: &'static str,
    bench_fn: BenchFn,
}

fn bench_run(
    def: &BenchmarkDef,
    rgb: &RgbImage,
    gray: &GrayImage,
    iterations: usize,
    output_dir: &Path,
) -> Stats {
    let mut times = Vec::with_capacity(iterations);

    match &def.bench_fn {
        BenchFn::RgbMut(f) => {
            let mut result = rgb.clone();
            for _ in 0..iterations {
                let mut img = rgb.clone();
                let start = Instant::now();
                f(&mut img);
                times.push(start.elapsed().as_secs_f64());
                result = img;
            }
            result
                .save(output_dir.join(format!("{}.png", def.slug)))
                .expect("failed to save output image");
        }
        BenchFn::RgbToRgb(f) => {
            let mut result = rgb.clone();
            for _ in 0..iterations {
                let start = Instant::now();
                result = f(rgb);
                times.push(start.elapsed().as_secs_f64());
            }
            result
                .save(output_dir.join(format!("{}.png", def.slug)))
                .expect("failed to save output image");
        }
        BenchFn::RgbToGray(f) => {
            let mut result = f(rgb);
            for _ in 0..iterations {
                let start = Instant::now();
                result = f(rgb);
                times.push(start.elapsed().as_secs_f64());
            }
            result
                .save(output_dir.join(format!("{}.png", def.slug)))
                .expect("failed to save output image");
        }
        BenchFn::GrayToGray(f) => {
            let mut result = f(gray);
            for _ in 0..iterations {
                let start = Instant::now();
                result = f(gray);
                times.push(start.elapsed().as_secs_f64());
            }
            result
                .save(output_dir.join(format!("{}.png", def.slug)))
                .expect("failed to save output image");
        }
    }

    compute_stats(&mut times)
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let image_path = args.get(1).map_or("../images/lenna.png", |s| s.as_str());
    let iterations: usize = args
        .get(2)
        .and_then(|s| s.parse().ok())
        .unwrap_or(101);
    let task_filter: Option<&str> = args.get(3).map(|s| s.as_str());

    let img = ImageReader::open(image_path)
        .unwrap_or_else(|_| panic!("failed to open image: {}", image_path))
        .decode()
        .unwrap_or_else(|_| panic!("failed to decode image: {}", image_path))
        .into_rgb8();

    let gray = imageops::grayscale(&img);

    let output_dir = Path::new(image_path)
        .parent()
        .unwrap_or(Path::new("."))
        .join("../output");
    fs::create_dir_all(&output_dir).expect("failed to create output directory");

    let benchmarks = vec![
        BenchmarkDef {
            task: "invert",
            slug: "image-invert",
            bench_fn: BenchFn::RgbMut(invert_builtin),
        },
        BenchmarkDef {
            task: "invert",
            slug: "rust-manual-invert",
            bench_fn: BenchFn::RgbMut(invert_manual),
        },
        BenchmarkDef {
            task: "grayscale",
            slug: "image-grayscale",
            bench_fn: BenchFn::RgbToGray(grayscale_image),
        },
        BenchmarkDef {
            task: "grayscale",
            slug: "rust-manual-grayscale",
            bench_fn: BenchFn::RgbToGray(grayscale_manual),
        },
        BenchmarkDef {
            task: "blur",
            slug: "imageproc-blur",
            bench_fn: BenchFn::RgbToRgb(blur_gaussian),
        },
        BenchmarkDef {
            task: "edge_detect_sobel",
            slug: "imageproc-sobel",
            bench_fn: BenchFn::GrayToGray(sobel_gradient),
        },
        BenchmarkDef {
            task: "edge_detect_canny",
            slug: "imageproc-canny",
            bench_fn: BenchFn::GrayToGray(canny_detect),
        },
        BenchmarkDef {
            task: "rotate_90",
            slug: "image-rotate90",
            bench_fn: BenchFn::RgbToRgb(rotate90_image),
        },
        BenchmarkDef {
            task: "rotate_arbitrary",
            slug: "rust-rotate45",
            bench_fn: BenchFn::RgbToRgb(rotate45_bilinear),
        },
        BenchmarkDef {
            task: "lee_filter",
            slug: "rust-manual-lee",
            bench_fn: BenchFn::GrayToGray(lee_filter_manual),
        },
    ];

    let filtered: Vec<&BenchmarkDef> = if let Some(task) = task_filter {
        benchmarks.iter().filter(|b| b.task == task).collect()
    } else {
        benchmarks.iter().collect()
    };

    let header = format!(
        "{:<20} {:<25} {:>12} {:>12} {:>12} {:>12} {:>12} {:>12}",
        "task", "slug", "mean", "median", "std_dev", "min", "max", "total"
    );
    println!("{}", header);
    println!("{}", "-".repeat(header.len()));

    for def in &filtered {
        let stats = bench_run(def, &img, &gray, iterations, &output_dir);
        println!(
            "{:<20} {:<25} {:>12.6} {:>12.6} {:>12.6} {:>12.6} {:>12.6} {:>12.6}",
            def.task,
            def.slug,
            stats.mean,
            stats.median,
            stats.std_dev,
            stats.min,
            stats.max,
            stats.total
        );
    }
}
