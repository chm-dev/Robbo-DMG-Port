/*
 * Phase 0 smoke test data/code in bank 2.
 *
 * GBDK puts code in the cart bank named by #pragma bank.  Bank 0 must call the
 * function through the BANKED trampoline; data is reached through the banked
 * pointer helper the linker generates.
 */
#include <gb/gb.h>
#include <gbdk/platform.h>
#include <stdint.h>

#pragma bank 2

const uint8_t bank2_data[] = { 0x5A, 0x01, 0x02 };

uint8_t bank2_value(void) BANKED
{
    return 0xA7u;
}

uint8_t bank2_read(uint8_t index) BANKED
{
    return bank2_data[index];
}
