#include <stdint.h>
#include <stdio.h>

#define LOG2_MAGIC 37

size_t bit_log2(uint32_t bit) {
    return bit % LOG2_MAGIC;
}

void main(void) {
    for (int32_t i = 0; i < 32; i++) {
        printf("%zu\n", bit_log2(1 << i));
    }
}