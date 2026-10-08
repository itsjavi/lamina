#include "TestPixels.h"
#include <stdlib.h>

void test_noise_rgba(uint8_t *bytes, size_t width, size_t height, size_t stride, uint32_t seed, uint8_t alpha) {
    uint32_t state = seed;
    for (size_t y = 0; y < height; ++y) {
        uint8_t *row = bytes + y * stride;
        for (size_t x = 0; x < width; ++x) {
            state = state * 1664525u + 1013904223u;
            row[x * 4] = (uint8_t)(((state >> 24) & 255) * alpha / 255);
            row[x * 4 + 1] = (uint8_t)(((state >> 16) & 255) * alpha / 255);
            row[x * 4 + 2] = (uint8_t)(((state >> 8) & 255) * alpha / 255);
            row[x * 4 + 3] = alpha;
        }
    }
}

void test_noise_gray(uint8_t *bytes, size_t width, size_t height, size_t stride, uint32_t seed) {
    uint32_t state = seed;
    for (size_t y = 0; y < height; ++y)
        for (size_t x = 0; x < width; ++x) {
            state = state * 1664525u + 1013904223u;
            bytes[y * stride + x] = (uint8_t)(state >> 24);
        }
}

void test_pattern_rgba(uint8_t *bytes, size_t width, size_t height, size_t stride, int seed, int alpha) {
    long w = (long)width, h = (long)height, span = w + h - 2 > 1 ? w + h - 2 : 1;
    for (long y = 0; y < h; ++y) {
        uint8_t *row = bytes + y * stride;
        for (long x = 0; x < w; ++x) {
            long a = 255;
            if (alpha) { a = (x + y) * 255 / span + 40; if (a > 255) a = 255; }
            row[x * 4] = (uint8_t)(((x * 255 / w + seed * 40) & 255) * a / 255);
            row[x * 4 + 1] = (uint8_t)(((y * 255 / h + seed * 25) & 255) * a / 255);
            row[x * 4 + 2] = (uint8_t)((((x / 16 + y / 16) % 2 == 0 ? 200 : 60) & 255) * a / 255);
            row[x * 4 + 3] = (uint8_t)a;
        }
    }
}

int test_largest_difference(const uint8_t *expected, const uint8_t *actual, const uint8_t *outline, size_t side) {
    int largest = 0;
    for (size_t y = 1; y + 1 < side; ++y)
        for (size_t x = 1; x + 1 < side; ++x) {
            int inside = 1;
            for (int dy = -1; dy <= 1 && inside; ++dy)
                for (int dx = -1; dx <= 1; ++dx)
                    if (outline[((y + dy) * side + x + dx) * 4 + 3] < 255) { inside = 0; break; }
            if (!inside) continue;
            size_t i = (y * side + x) * 4;
            for (int c = 0; c < 4; ++c) {
                int d = abs((int)expected[i + c] - (int)actual[i + c]);
                if (d > largest) largest = d;
            }
        }
    return largest;
}

int test_largest_difference_outside(const uint8_t *a, const uint8_t *b, size_t width, size_t height, size_t rowBytes,
                                    size_t samples, double minX, double minY, double maxX, double maxY) {
    int largest = 0;
    for (size_t y = 0; y < height; ++y)
        for (size_t x = 0; x < width; ++x) {
            if ((double)x >= minX && (double)x < maxX && (double)y >= minY && (double)y < maxY) continue;
            size_t i = y * rowBytes + x * samples;
            for (size_t c = 0; c < samples; ++c) {
                int d = abs((int)a[i + c] - (int)b[i + c]);
                if (d > largest) largest = d;
            }
        }
    return largest;
}

void test_difference_stats(const uint8_t *a, const uint8_t *b, size_t pixels, int threshold, double *total, size_t *over) {
    unsigned long long sum = 0;
    size_t count = 0;
    for (size_t p = 0; p < pixels; ++p) {
        int largest = 0;
        for (int c = 0; c < 3; ++c) {
            int d = abs((int)a[p * 4 + c] - (int)b[p * 4 + c]);
            sum += (unsigned long long)d;
            if (d > largest) largest = d;
        }
        if (largest > threshold) ++count;
    }
    *total = (double)sum;
    *over = count;
}
