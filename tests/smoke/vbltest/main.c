#include <gb/gb.h>
#include <stdint.h>
uint8_t counter;
void main(void) {
    while (1) {
        vsync();
        counter++;
    }
}
