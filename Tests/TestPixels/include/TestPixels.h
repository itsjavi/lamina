#ifndef TestPixels_h
#define TestPixels_h
#include <stdint.h>
#include <stddef.h>
// Fixture and comparison loops for the rendering tests, in C and always optimized: as unoptimized Swift, these per-pixel
// loops over megapixel images were most of the test suite's time. Each matches the Swift it replaced exactly.

// Deterministic noise (a linear congruential generator from `seed`): premultiplied RGBA scaled by `alpha`, `stride`
// bytes per row.
void test_noise_rgba(uint8_t *bytes, size_t width, size_t height, size_t stride, uint32_t seed, uint8_t alpha);
// The same generator as 8-bit gray, one byte per pixel.
void test_noise_gray(uint8_t *bytes, size_t width, size_t height, size_t stride, uint32_t seed);
// Gradients and a 16-pixel checker in premultiplied RGBA; with `alpha`, opacity ramps from the top-left corner.
void test_pattern_rgba(uint8_t *bytes, size_t width, size_t height, size_t stride, int seed, int alpha);
// The largest channel difference between two `side` × `side` RGBA images, over pixels whose 3 × 3 neighborhood is
// fully opaque in `outline`.
int test_largest_difference(const uint8_t *expected, const uint8_t *actual, const uint8_t *outline, size_t side);
// The largest channel difference between two images of `samples` bytes per pixel and `rowBytes` per row, over pixels
// outside the box from (`minX`, `minY`) up to, not including, (`maxX`, `maxY`), as CGRect.contains takes it.
int test_largest_difference_outside(const uint8_t *a, const uint8_t *b, size_t width, size_t height, size_t rowBytes,
                                    size_t samples, double minX, double minY, double maxX, double maxY);
// Over `pixels` RGBA pixels: the sum of red, green and blue differences, and how many pixels differ by more than
// `threshold` in some channel.
void test_difference_stats(const uint8_t *a, const uint8_t *b, size_t pixels, int threshold, double *total, size_t *over);
#endif
