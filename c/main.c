#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

typedef struct {
    double mean;
    double median;
    double std_dev;
    double min;
    double max;
    double total;
} Stats;

static int cmp_double(const void *a, const void *b) {
    double da = *(const double *)a;
    double db = *(const double *)b;
    if (da < db) return -1;
    if (da > db) return 1;
    return 0;
}

static Stats compute_stats(double *times, int n) {
    Stats s;
    qsort(times, n, sizeof(double), cmp_double);

    s.total = 0.0;
    for (int i = 0; i < n; i++) s.total += times[i];
    s.mean = s.total / n;
    s.median = times[n / 2];
    s.min = times[0];
    s.max = times[n - 1];

    if (n > 1) {
        double sum_sq = 0.0;
        for (int i = 0; i < n; i++) {
            double diff = times[i] - s.mean;
            sum_sq += diff * diff;
        }
        s.std_dev = sqrt(sum_sq / (n - 1));
    } else {
        s.std_dev = 0.0;
    }

    return s;
}

static double get_time_sec(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec * 1e-9;
}

static int iclamp(int v, int lo, int hi) {
    return v < lo ? lo : (v > hi ? hi : v);
}

/* --- Invert --- */

static void invert_pixels(const unsigned char *in, unsigned char *out, int w, int h, int ch) {
    int size = w * h * ch;
    for (int i = 0; i < size; i++) {
        out[i] = 255 - in[i];
    }
}

/* --- Grayscale --- */

static void grayscale_convert(const unsigned char *in, unsigned char *out, int w, int h, int ch) {
    for (int i = 0; i < w * h; i++) {
        int r = in[i * ch + 0];
        int g = in[i * ch + 1];
        int b = in[i * ch + 2];
        out[i] = (unsigned char)(0.299 * r + 0.587 * g + 0.114 * b);
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

static void gaussian_blur(const unsigned char *in, unsigned char *out, int w, int h, int ch) {
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
                out[(y * w + x) * ch + c] = (unsigned char)iclamp((int)round(sum), 0, 255);
            }
        }
    }
}

/* --- Sobel edge detection --- */

static void sobel_edge(const unsigned char *in, unsigned char *out, int w, int h, int ch) {
    static const int gx[3][3] = {{-1, 0, 1}, {-2, 0, 2}, {-1, 0, 1}};
    static const int gy[3][3] = {{-1, -2, -1}, {0, 0, 0}, {1, 2, 1}};
    (void)ch;

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
            double mag = sqrt(sx * sx + sy * sy);
            out[y * w + x] = (unsigned char)(mag > 255 ? 255 : (int)mag);
        }
    }
}

/* --- Rotate 90 clockwise --- */

static void rotate90_cw(const unsigned char *in, unsigned char *out, int w, int h, int ch) {
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

static void rotate45_bilinear(const unsigned char *in, unsigned char *out, int w, int h, int ch) {
    double angle = M_PI / 4.0;
    double cos_a = cos(angle), sin_a = sin(angle);
    int nw = (int)ceil(w * cos_a + h * sin_a);
    int nh = (int)ceil(w * sin_a + h * cos_a);
    double cx = w / 2.0, cy = h / 2.0;
    double ncx = nw / 2.0, ncy = nh / 2.0;

    memset(out, 0, nw * nh * ch);

    for (int oy = 0; oy < nh; oy++) {
        for (int ox = 0; ox < nw; ox++) {
            double dx = ox - ncx, dy = oy - ncy;
            double sx = dx * cos_a + dy * sin_a + cx;
            double sy = -dx * sin_a + dy * cos_a + cy;

            if (sx >= 0 && sx < w - 1 && sy >= 0 && sy < h - 1) {
                int x0 = (int)floor(sx);
                int y0 = (int)floor(sy);
                double fx = sx - x0, fy = sy - y0;

                for (int c = 0; c < ch; c++) {
                    double v = (1 - fx) * (1 - fy) * in[(y0 * w + x0) * ch + c]
                             + fx * (1 - fy) * in[(y0 * w + x0 + 1) * ch + c]
                             + (1 - fx) * fy * in[((y0 + 1) * w + x0) * ch + c]
                             + fx * fy * in[((y0 + 1) * w + x0 + 1) * ch + c];
                    out[(oy * nw + ox) * ch + c] =
                        (unsigned char)iclamp((int)round(v), 0, 255);
                }
            }
        }
    }
}

/* --- Lee filter (7x7 window) --- */

static void lee_filter(const unsigned char *in, unsigned char *out, int w, int h, int ch) {
    int half = 3;
    double total_pixels = (double)(w * h);
    double sum_all = 0, sum_sq_all = 0;
    (void)ch;

    for (int i = 0; i < w * h; i++) {
        double v = in[i];
        sum_all += v;
        sum_sq_all += v * v;
    }

    double overall_mean = sum_all / total_pixels;
    double overall_var = sum_sq_all / total_pixels - overall_mean * overall_mean;

    if (overall_var == 0) {
        memcpy(out, in, w * h);
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
            out[y * w + x] = (unsigned char)iclamp((int)round(val), 0, 255);
        }
    }
}

/* --- Benchmark infrastructure --- */

typedef void (*BenchFn)(const unsigned char *in, unsigned char *out, int w, int h, int ch);

typedef struct {
    const char *task;
    const char *slug;
    int gray_input;
    int out_w, out_h, out_ch;
    BenchFn fn;
} BenchmarkDef;

int main(int argc, char *argv[]) {
    const char *image_path = argc > 1 ? argv[1] : "../images/lenna.png";
    int iterations = argc > 2 ? atoi(argv[2]) : 101;
    const char *task_filter = argc > 3 ? argv[3] : NULL;

    int width, height, channels;
    unsigned char *original = stbi_load(image_path, &width, &height, &channels, 0);
    if (!original) {
        fprintf(stderr, "Failed to load image: %s\n", image_path);
        return 1;
    }

    /* Pre-compute grayscale */
    unsigned char *gray = (unsigned char *)malloc(width * height);
    if (!gray) {
        fprintf(stderr, "Failed to allocate memory\n");
        stbi_image_free(original);
        return 1;
    }
    for (int i = 0; i < width * height; i++) {
        int r = original[i * channels + 0];
        int g = original[i * channels + 1];
        int b = original[i * channels + 2];
        gray[i] = (unsigned char)(0.299 * r + 0.587 * g + 0.114 * b);
    }

    /* Compute rotate45 output dimensions */
    double cos45 = cos(M_PI / 4.0), sin45 = sin(M_PI / 4.0);
    int w45 = (int)ceil(width * cos45 + height * sin45);
    int h45 = (int)ceil(width * sin45 + height * cos45);

    /* Derive output directory from image path */
    char output_dir[2048];
    {
        char img_dir[1024];
        strncpy(img_dir, image_path, sizeof(img_dir) - 1);
        img_dir[sizeof(img_dir) - 1] = '\0';
        char *last_slash = strrchr(img_dir, '/');
        if (last_slash) {
            *last_slash = '\0';
            snprintf(output_dir, sizeof(output_dir), "%s/../output", img_dir);
        } else {
            snprintf(output_dir, sizeof(output_dir), "../output");
        }
    }

    {
        char mkdir_cmd[2200];
        snprintf(mkdir_cmd, sizeof(mkdir_cmd), "mkdir -p %s", output_dir);
        if (system(mkdir_cmd) != 0) {
            fprintf(stderr, "Failed to create output directory\n");
        }
    }

    BenchmarkDef benchmarks[] = {
        {"invert",           "c-invert",     0, width,  height, channels, invert_pixels},
        {"grayscale",        "c-grayscale",  0, width,  height, 1,        grayscale_convert},
        {"blur",             "c-blur",       0, width,  height, channels, gaussian_blur},
        {"edge_detect_sobel","c-sobel",      1, width,  height, 1,        sobel_edge},
        {"rotate_90",        "c-rotate90",   0, height, width,  channels, rotate90_cw},
        {"rotate_arbitrary", "c-rotate45",   0, w45,    h45,    channels, rotate45_bilinear},
        {"lee_filter",       "c-lee",        1, width,  height, 1,        lee_filter},
    };
    int num_benchmarks = sizeof(benchmarks) / sizeof(benchmarks[0]);

    double *times = (double *)malloc(iterations * sizeof(double));
    if (!times) {
        fprintf(stderr, "Failed to allocate memory\n");
        free(gray);
        stbi_image_free(original);
        return 1;
    }

    char header[256];
    snprintf(header, sizeof(header),
             "%-20s %-25s %12s %12s %12s %12s %12s %12s",
             "task", "slug", "mean", "median", "std_dev", "min", "max", "total");
    printf("%s\n", header);
    int header_len = (int)strlen(header);
    for (int i = 0; i < header_len; i++) putchar('-');
    putchar('\n');

    for (int b = 0; b < num_benchmarks; b++) {
        BenchmarkDef *bench = &benchmarks[b];

        if (task_filter && strcmp(task_filter, bench->task) != 0)
            continue;

        const unsigned char *input = bench->gray_input ? gray : original;
        int in_ch = bench->gray_input ? 1 : channels;
        int out_size = bench->out_w * bench->out_h * bench->out_ch;
        unsigned char *output = (unsigned char *)calloc(out_size, 1);
        if (!output) {
            fprintf(stderr, "Failed to allocate output buffer\n");
            continue;
        }

        for (int i = 0; i < iterations; i++) {
            double start = get_time_sec();
            bench->fn(input, output, width, height, in_ch);
            double elapsed = get_time_sec() - start;
            times[i] = elapsed;
        }

        char out_path[2200];
        snprintf(out_path, sizeof(out_path), "%s/%s.png", output_dir, bench->slug);
        stbi_write_png(out_path, bench->out_w, bench->out_h, bench->out_ch,
                       output, bench->out_w * bench->out_ch);

        Stats stats = compute_stats(times, iterations);
        printf("%-20s %-25s %12.6f %12.6f %12.6f %12.6f %12.6f %12.6f\n",
               bench->task, bench->slug,
               stats.mean, stats.median, stats.std_dev,
               stats.min, stats.max, stats.total);

        free(output);
    }

    free(times);
    free(gray);
    stbi_image_free(original);
    return 0;
}
