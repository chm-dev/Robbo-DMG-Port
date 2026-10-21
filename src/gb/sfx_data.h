#ifndef SFX_DATA_H
#define SFX_DATA_H

#include <stdint.h>

/* Number of note patterns: 15 original POKEY notes (0..14) plus two
 * synthesized effects (15 = fire, 16 = explosion). */
#define SFX_NOTE_COUNT 18

/* Each pattern is 16 steps, played from index 0 (volume 16) to 15 (volume 1). */
#define SFX_STEPS 16

/* One POKEY register pair: AUDC (control) and AUDF (divider). */
typedef struct {
    uint8_t audc;
    uint8_t audf;
} SfxStep;

extern const SfxStep sfx_notes[SFX_NOTE_COUNT][SFX_STEPS];

#endif

