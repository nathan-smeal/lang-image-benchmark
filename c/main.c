#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

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

static void invert_pixels(unsigned char *pixels, int size) {
    for (int i = 0; i < size; i++) {
        pixels[i] = 255 - pixels[i];
    }
}

int main(int argc, char *argv[]) {
    const char *image_path = argc > 1 ? argv[1] : "../images/lenna.png";
    int iterations = argc > 2 ? atoi(argv[2]) : 101;

    int width, height, channels;
    unsigned char *original = stbi_load(image_path, &width, &height, &channels, 0);
    if (!original) {
        fprintf(stderr, "Failed to load image: %s\n", image_path);
        return 1;
    }

    int size = width * height * channels;

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

    /* Create output directory */
    {
        char mkdir_cmd[2200];
        snprintf(mkdir_cmd, sizeof(mkdir_cmd), "mkdir -p %s", output_dir);
        if (system(mkdir_cmd) != 0) {
            fprintf(stderr, "Failed to create output directory\n");
        }
    }

    unsigned char *working = (unsigned char *)malloc(size);
    if (!working) {
        fprintf(stderr, "Failed to allocate memory\n");
        stbi_image_free(original);
        return 1;
    }

    double *times = (double *)malloc(iterations * sizeof(double));
    if (!times) {
        fprintf(stderr, "Failed to allocate memory\n");
        free(working);
        stbi_image_free(original);
        return 1;
    }

    /* Benchmark: c-invert */
    for (int i = 0; i < iterations; i++) {
        memcpy(working, original, size);
        double start = get_time_sec();
        invert_pixels(working, size);
        double elapsed = get_time_sec() - start;
        times[i] = elapsed;
    }

    /* Save output image */
    {
        char out_path[2200];
        snprintf(out_path, sizeof(out_path), "%s/c-invert.png", output_dir);
        stbi_write_png(out_path, width, height, channels, working, width * channels);
    }

    Stats stats = compute_stats(times, iterations);

    char header[256];
    snprintf(header, sizeof(header),
             "%-20s %12s %12s %12s %12s %12s %12s",
             "slug", "mean", "median", "std_dev", "min", "max", "total");
    printf("%s\n", header);
    int header_len = (int)strlen(header);
    for (int i = 0; i < header_len; i++) putchar('-');
    putchar('\n');

    printf("%-20s %12.6f %12.6f %12.6f %12.6f %12.6f %12.6f\n",
           "c-invert",
           stats.mean, stats.median, stats.std_dev,
           stats.min, stats.max, stats.total);

    free(times);
    free(working);
    stbi_image_free(original);
    return 0;
}
