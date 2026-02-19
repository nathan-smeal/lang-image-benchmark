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

void invert_transform(unsigned char* pixels, int size) {
    std::transform(pixels, pixels + size, pixels,
                   [](unsigned char c) { return static_cast<unsigned char>(255 - c); });
}

void invert_manual(unsigned char* pixels, int size) {
    for (int i = 0; i < size; i++) {
        pixels[i] = 255 - pixels[i];
    }
}

struct Benchmark {
    const char* slug;
    void (*fn)(unsigned char*, int);
};

int main(int argc, char* argv[]) {
    const char* image_path = argc > 1 ? argv[1] : "../images/lenna.png";
    int iterations = argc > 2 ? std::atoi(argv[2]) : 101;

    int width, height, channels;
    unsigned char* original = stbi_load(image_path, &width, &height, &channels, 0);
    if (!original) {
        fprintf(stderr, "Failed to load image: %s\n", image_path);
        return 1;
    }

    int size = width * height * channels;

    /* Derive output directory from image path */
    std::string img_path_str(image_path);
    std::string output_dir;
    size_t last_slash = img_path_str.find_last_of('/');
    if (last_slash != std::string::npos) {
        output_dir = img_path_str.substr(0, last_slash) + "/../output";
    } else {
        output_dir = "../output";
    }

    /* Create output directory */
    std::string mkdir_cmd = "mkdir -p " + output_dir;
    if (system(mkdir_cmd.c_str()) != 0) {
        fprintf(stderr, "Failed to create output directory\n");
    }

    Benchmark benchmarks[] = {
        {"cpp-transform", invert_transform},
        {"cpp-manual",    invert_manual},
    };

    char header[256];
    snprintf(header, sizeof(header),
             "%-20s %12s %12s %12s %12s %12s %12s",
             "slug", "mean", "median", "std_dev", "min", "max", "total");
    printf("%s\n", header);
    int header_len = static_cast<int>(strlen(header));
    for (int i = 0; i < header_len; i++) putchar('-');
    putchar('\n');

    auto* working = new unsigned char[size];

    for (const auto& bench : benchmarks) {
        std::vector<double> times;
        times.reserve(iterations);

        for (int i = 0; i < iterations; i++) {
            std::memcpy(working, original, size);
            auto start = std::chrono::high_resolution_clock::now();
            bench.fn(working, size);
            auto end = std::chrono::high_resolution_clock::now();
            double elapsed = std::chrono::duration<double>(end - start).count();
            times.push_back(elapsed);
        }

        std::string out_path = output_dir + "/" + bench.slug + ".png";
        stbi_write_png(out_path.c_str(), width, height, channels, working, width * channels);

        Stats stats = compute_stats(times);
        printf("%-20s %12.6f %12.6f %12.6f %12.6f %12.6f %12.6f\n",
               bench.slug,
               stats.mean, stats.median, stats.std_dev,
               stats.min, stats.max, stats.total);
    }

    delete[] working;
    stbi_image_free(original);
    return 0;
}
