#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

struct Stats {
    double mean;
    double median;
    double std_dev;
    double min;
    double max;
    double total;
};

Stats compute_stats(std::vector<double>& times) {
    std::sort(times.begin(), times.end());
    int n = static_cast<int>(times.size());

    Stats s{};
    s.total = 0.0;
    for (double t : times) s.total += t;
    s.mean = s.total / n;
    s.median = times[n / 2];
    s.min = times[0];
    s.max = times[n - 1];

    if (n > 1) {
        double sum_sq = 0.0;
        for (double t : times) {
            double diff = t - s.mean;
            sum_sq += diff * diff;
        }
        s.std_dev = std::sqrt(sum_sq / (n - 1));
    } else {
        s.std_dev = 0.0;
    }

    return s;
}

static inline int iclamp(int v, int lo, int hi) {
    return v < lo ? lo : (v > hi ? hi : v);
}

/* --- Invert --- */

void invert_transform(const unsigned char* in, unsigned char* out, int w, int h, int ch) {
    int size = w * h * ch;
    std::transform(in, in + size, out,
                   [](unsigned char c) { return static_cast<unsigned char>(255 - c); });
}

void invert_manual(const unsigned char* in, unsigned char* out, int w, int h, int ch) {
    int size = w * h * ch;
    for (int i = 0; i < size; i++) {
        out[i] = 255 - in[i];
    }
}

/* --- Grayscale --- */

void grayscale(const unsigned char* in, unsigned char* out, int w, int h, int ch) {
    for (int i = 0; i < w * h; i++) {
        int r = in[i * ch + 0];
        int g = in[i * ch + 1];
        int b = in[i * ch + 2];
        out[i] = static_cast<unsigned char>(0.299 * r + 0.587 * g + 0.114 * b);
    }
}

/* --- Gaussian Blur 5x5, sigma=1.0 --- */

static const double gauss5[25] = {
    0.00297, 0.01331, 0.02194, 0.01331, 0.00297,
    0.01331, 0.05963, 0.09832, 0.05963, 0.01331,
    0.02194, 0.09832, 0.16210, 0.09832, 0.02194,
    0.01331, 0.05963, 0.09832, 0.05963, 0.01331,
    0.00297, 0.01331, 0.02194, 0.01331, 0.00297
};

void gaussian_blur(const unsigned char* in, unsigned char* out, int w, int h, int ch) {
    for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
            for (int c = 0; c < ch; c++) {
                double sum = 0.0;
                for (int ky = -2; ky <= 2; ky++) {
                    for (int kx = -2; kx <= 2; kx++) {
                        int sy = iclamp(y + ky, 0, h - 1);
                        int sx = iclamp(x + kx, 0, w - 1);
                        sum += in[(sy * w + sx) * ch + c] * gauss5[(ky + 2) * 5 + (kx + 2)];
                    }
                }
                out[(y * w + x) * ch + c] =
                    static_cast<unsigned char>(iclamp(static_cast<int>(round(sum)), 0, 255));
            }
        }
    }
}

/* --- Sobel edge detection --- */

void sobel_edge(const unsigned char* in, unsigned char* out, int w, int h, int /*ch*/) {
    static const int gx[3][3] = {{-1, 0, 1}, {-2, 0, 2}, {-1, 0, 1}};
    static const int gy[3][3] = {{-1, -2, -1}, {0, 0, 0}, {1, 2, 1}};

    for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
            double sx = 0, sy = 0;
            for (int ky = -1; ky <= 1; ky++) {
                for (int kx = -1; kx <= 1; kx++) {
                    int py = iclamp(y + ky, 0, h - 1);
                    int px = iclamp(x + kx, 0, w - 1);
                    double v = in[py * w + px];
                    sx += v * gx[ky + 1][kx + 1];
                    sy += v * gy[ky + 1][kx + 1];
                }
            }
            double mag = std::sqrt(sx * sx + sy * sy);
            out[y * w + x] = static_cast<unsigned char>(mag > 255 ? 255 : static_cast<int>(mag));
        }
    }
}

/* --- Rotate 90 clockwise --- */

void rotate90_cw(const unsigned char* in, unsigned char* out, int w, int h, int ch) {
    int out_w = h;
    for (int iy = 0; iy < h; iy++) {
        for (int ix = 0; ix < w; ix++) {
            int out_x = h - 1 - iy;
            int out_y = ix;
            for (int c = 0; c < ch; c++) {
                out[(out_y * out_w + out_x) * ch + c] = in[(iy * w + ix) * ch + c];
            }
        }
    }
}

/* --- Rotate 45 degrees with bilinear interpolation, expanded canvas --- */

void rotate45_bilinear(const unsigned char* in, unsigned char* out, int w, int h, int ch) {
    double angle = M_PI / 4.0;
    double cos_a = cos(angle), sin_a = sin(angle);
    int nw = static_cast<int>(ceil(w * cos_a + h * sin_a));
    int nh = static_cast<int>(ceil(w * sin_a + h * cos_a));
    double cx = w / 2.0, cy = h / 2.0;
    double ncx = nw / 2.0, ncy = nh / 2.0;

    std::memset(out, 0, nw * nh * ch);

    for (int oy = 0; oy < nh; oy++) {
        for (int ox = 0; ox < nw; ox++) {
            double dx = ox - ncx, dy = oy - ncy;
            double sx = dx * cos_a + dy * sin_a + cx;
            double sy = -dx * sin_a + dy * cos_a + cy;

            if (sx >= 0 && sx < w - 1 && sy >= 0 && sy < h - 1) {
                int x0 = static_cast<int>(floor(sx));
                int y0 = static_cast<int>(floor(sy));
                double fx = sx - x0, fy = sy - y0;

                for (int c = 0; c < ch; c++) {
                    double v = (1 - fx) * (1 - fy) * in[(y0 * w + x0) * ch + c]
                             + fx * (1 - fy) * in[(y0 * w + x0 + 1) * ch + c]
                             + (1 - fx) * fy * in[((y0 + 1) * w + x0) * ch + c]
                             + fx * fy * in[((y0 + 1) * w + x0 + 1) * ch + c];
                    out[(oy * nw + ox) * ch + c] =
                        static_cast<unsigned char>(iclamp(static_cast<int>(round(v)), 0, 255));
                }
            }
        }
    }
}

/* --- Lee filter (7x7 window) --- */

void lee_filter(const unsigned char* in, unsigned char* out, int w, int h, int /*ch*/) {
    int half = 3;
    double total_pixels = static_cast<double>(w * h);
    double sum_all = 0, sum_sq_all = 0;

    for (int i = 0; i < w * h; i++) {
        double v = in[i];
        sum_all += v;
        sum_sq_all += v * v;
    }

    double overall_mean = sum_all / total_pixels;
    double overall_var = sum_sq_all / total_pixels - overall_mean * overall_mean;

    if (overall_var == 0) {
        std::memcpy(out, in, w * h);
        return;
    }

    for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
            double local_sum = 0, local_sq = 0;
            int count = 0;

            int y0 = y - half < 0 ? 0 : y - half;
            int y1 = y + half + 1 > h ? h : y + half + 1;
            int x0 = x - half < 0 ? 0 : x - half;
            int x1 = x + half + 1 > w ? w : x + half + 1;

            for (int wy = y0; wy < y1; wy++) {
                for (int wx = x0; wx < x1; wx++) {
                    double v = in[wy * w + wx];
                    local_sum += v;
                    local_sq += v * v;
                    count++;
                }
            }

            double local_mean = local_sum / count;
            double local_var = local_sq / count - local_mean * local_mean;
            double weight = local_var / (local_var + overall_var);
            double val = local_mean + weight * (in[y * w + x] - local_mean);
            out[y * w + x] =
                static_cast<unsigned char>(iclamp(static_cast<int>(round(val)), 0, 255));
        }
    }
}

/* --- Benchmark infrastructure --- */

typedef void (*BenchFn)(const unsigned char* in, unsigned char* out, int w, int h, int ch);

struct BenchmarkDef {
    const char* task;
    const char* slug;
    bool gray_input;
    int out_w, out_h, out_ch;
    BenchFn fn;
};

int main(int argc, char* argv[]) {
    const char* image_path = argc > 1 ? argv[1] : "../images/lenna.png";
    int iterations = argc > 2 ? std::atoi(argv[2]) : 101;
    const char* task_filter = argc > 3 ? argv[3] : nullptr;

    int width, height, channels;
    unsigned char* original = stbi_load(image_path, &width, &height, &channels, 0);
    if (!original) {
        fprintf(stderr, "Failed to load image: %s\n", image_path);
        return 1;
    }

    /* Pre-compute grayscale */
    auto* gray = new unsigned char[width * height];
    for (int i = 0; i < width * height; i++) {
        int r = original[i * channels + 0];
        int g = original[i * channels + 1];
        int b = original[i * channels + 2];
        gray[i] = static_cast<unsigned char>(0.299 * r + 0.587 * g + 0.114 * b);
    }

    /* Compute rotate45 output dimensions */
    double cos45 = cos(M_PI / 4.0), sin45 = sin(M_PI / 4.0);
    int w45 = static_cast<int>(ceil(width * cos45 + height * sin45));
    int h45 = static_cast<int>(ceil(width * sin45 + height * cos45));

    /* Derive output directory from image path */
    std::string img_path_str(image_path);
    std::string output_dir;
    size_t last_slash = img_path_str.find_last_of('/');
    if (last_slash != std::string::npos) {
        output_dir = img_path_str.substr(0, last_slash) + "/../output";
    } else {
        output_dir = "../output";
    }

    std::string mkdir_cmd = "mkdir -p " + output_dir;
    if (system(mkdir_cmd.c_str()) != 0) {
        fprintf(stderr, "Failed to create output directory\n");
    }

    std::vector<BenchmarkDef> benchmarks = {
        {"invert",           "cpp-transform",  false, width,  height, channels, invert_transform},
        {"invert",           "cpp-manual",     false, width,  height, channels, invert_manual},
        {"grayscale",        "cpp-grayscale",  false, width,  height, 1,        grayscale},
        {"blur",             "cpp-blur",       false, width,  height, channels, gaussian_blur},
        {"edge_detect_sobel","cpp-sobel",      true,  width,  height, 1,        sobel_edge},
        {"rotate_90",        "cpp-rotate90",   false, height, width,  channels, rotate90_cw},
        {"rotate_arbitrary", "cpp-rotate45",   false, w45,    h45,    channels, rotate45_bilinear},
        {"lee_filter",       "cpp-lee",        true,  width,  height, 1,        lee_filter},
    };

    /* Filter by task if requested */
    if (task_filter) {
        std::string tf(task_filter);
        std::vector<BenchmarkDef> filtered;
        for (const auto& b : benchmarks) {
            if (tf == b.task) filtered.push_back(b);
        }
        benchmarks = std::move(filtered);
    }

    char header[256];
    snprintf(header, sizeof(header),
             "%-20s %-25s %12s %12s %12s %12s %12s %12s",
             "task", "slug", "mean", "median", "std_dev", "min", "max", "total");
    printf("%s\n", header);
    int header_len = static_cast<int>(strlen(header));
    for (int i = 0; i < header_len; i++) putchar('-');
    putchar('\n');

    for (const auto& bench : benchmarks) {
        const unsigned char* input = bench.gray_input ? gray : original;
        int in_ch = bench.gray_input ? 1 : channels;
        int out_size = bench.out_w * bench.out_h * bench.out_ch;
        auto* output = new unsigned char[out_size]();

        std::vector<double> times;
        times.reserve(iterations);

        for (int i = 0; i < iterations; i++) {
            auto start = std::chrono::high_resolution_clock::now();
            bench.fn(input, output, width, height, in_ch);
            auto end = std::chrono::high_resolution_clock::now();
            double elapsed = std::chrono::duration<double>(end - start).count();
            times.push_back(elapsed);
        }

        std::string out_path = output_dir + "/" + bench.slug + ".png";
        stbi_write_png(out_path.c_str(), bench.out_w, bench.out_h, bench.out_ch,
                       output, bench.out_w * bench.out_ch);

        Stats stats = compute_stats(times);
        printf("%-20s %-25s %12.6f %12.6f %12.6f %12.6f %12.6f %12.6f\n",
               bench.task, bench.slug,
               stats.mean, stats.median, stats.std_dev,
               stats.min, stats.max, stats.total);

        delete[] output;
    }

    delete[] gray;
    stbi_image_free(original);
    return 0;
}
