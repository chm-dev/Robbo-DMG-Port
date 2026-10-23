/*
 * sound.c - Robbo sound-effect mixer (Game Boy).
 *
 * Three playback paths share four voices:
 *
 *  - PATTERN voices play the sound-port2 effects on the original 80 ms step
 *    grid (4.8 DMG frames per step), using the POKEY -> DMG mapping.  The
 *    level-start fanfare overlays the GBC-derived note 11 table, and the last
 *    bolt uses the GBC note 13 table, so their noise uses the exact NR43 rates
 *    and original POKEY volumes.
 *
 *  - LEGACY voices play the few SfxDef effects kept from the previous set
 *    (explosion, destruct) because the new set removed them.
 *
 *  - The WAVE voice plays the GBC door conversion on CH3: poly4 wave images
 *    plus a few CH4 noise accents.
 *
 * POLYPHONY
 * ---------
 *   voice 0 -> pulse channel 1 (tone effects)
 *   voice 1 -> pulse channel 2 (tone effects)
 *   voice 2 -> noise channel   (shot, impact, ammo, magnet, ...)
 *   voice 3 -> CH3 wave channel (door); borrows CH4 for noise accents
 *
 * A pattern that contains both noise and tone steps takes a pulse voice: it
 * borrows the shared noise channel for its noise steps and returns to its own
 * pulse channel for the tone tail (Level Start does this).  Noise-only
 * patterns use the noise voice.  When both pulse voices are busy the player
 * steals the one with the least time left; a short noise hit is dropped while
 * a much longer noise effect (explosion) is still running.
 */
#pragma bank 9

#include <gb/gb.h>
#include <stdint.h>

#include "sound.h"
#include "sfx_data.h"
#include "sfx_gbc_data.h"
#include "noise_table.h"

/* POKEY master clocks (PAL). */
#define POKEY_CLOCK_64K   63921UL
#define POKEY_CLOCK_179M  1789773UL

/* Voice 3 is the otherwise-unused CH3 wave channel.  It plays the GBC door
 * conversion and borrows CH4 for that effect's short noise accents. */
#define VOICE_PULSE1 0
#define VOICE_PULSE2 1
#define VOICE_NOISE  2
#define VOICE_WAVE   3
#define VOICE_COUNT  4

#define VOICE_KIND_PATTERN 1
#define VOICE_KIND_LEGACY  2
#define VOICE_KIND_WAVE    3

typedef struct {
    const SfxDef *def;      /* legacy sounds */
    uint8_t kind;           /* 0 idle, VOICE_KIND_* */
    uint8_t note;           /* pattern index (pattern sounds) */
    uint8_t playing;
    uint8_t step;
    uint8_t sub;            /* pattern: 0.1-frame accumulator (step at 48) */
    uint8_t wait;           /* legacy: frames until the next step */
    uint8_t last_type;      /* 0 none, 1 pulse, 2 noise, 3 CH3 wave */
    uint16_t last_period;
    uint8_t last_duty;
    uint8_t started;        /* start order, used for voice stealing */
} SfxVoice;

static SfxVoice voices[VOICE_COUNT];
static uint8_t start_order;
static uint8_t noise_owner;   /* voice driving the noise channel, 0xFF none */
static uint8_t wave_id;       /* CH3 wave image currently loaded, 0xFF none */

uint8_t sfx_voice_mask;

/* Pulse channel register views, so one code path can drive either channel. */
static volatile uint8_t *const pulse_duty[2] = { &NR11_REG, &NR21_REG };
static volatile uint8_t *const pulse_vol[2] = { &NR12_REG, &NR22_REG };
static volatile uint8_t *const pulse_period_lo[2] = { &NR13_REG, &NR23_REG };
static volatile uint8_t *const pulse_period_hi[2] = { &NR14_REG, &NR24_REG };

/* Patterns removed from the sound-port2 game set ($00, $06, $0A). */
static const uint8_t pattern_muted[SFX_PATTERN_COUNT] = {
    1, /* $00 EXPLOSION  : removed from the set */
    0, /* $01 SHOT */
    0, /* $02 HIT WALL */
    0, /* $03 TELEPORT */
    0, /* $04 BOLT */
    0, /* $05 EXTRA LIFE */
    0, /* $06 DOOR OPEN  : played by the CH3 wave path */
    0, /* $07 AMMO */
    0, /* $08 PUSH */
    0, /* $09 KEY */
    1, /* $0A DESTRUCT  : removed from the set */
    0, /* $0B LEVEL START */
    0, /* $0C LEVEL END */
    0, /* $0D LAST BOLT : played by the GBC note 13 table */
    0, /* $0E MAGNET */
};

/* ------------------------------------------------------------------ */
/* Legacy mapping (previous sound set)                                */
/* ------------------------------------------------------------------ */

static uint8_t pokey_volume(uint8_t audc)
{
    return audc & 0x0F;
}

static uint8_t pokey_distortion(uint8_t audc)
{
    return (audc >> 5) & 0x03;
}

/* POKEY tone or noise-clock frequency for one AUDC/AUDF pair. */
static uint32_t pokey_rate(uint8_t audc, uint8_t audf)
{
    uint32_t clock = (audc & 0x80) ? POKEY_CLOCK_179M : POKEY_CLOCK_64K;
    uint32_t div = (uint32_t)audf + 1UL;
    uint8_t dist = pokey_distortion(audc);

    switch (dist) {
    case 0:  /* 5-bit polynomial counter (period 31) */
        return clock / (div * 31UL);
    case 1:  /* 4-bit polynomial counter (period 15) */
        return clock / (div * 15UL);
    case 2:  /* 5-bit + 4-bit poly = noise; AUDF sets the LFSR clock */
        return clock / div;
    default: /* 17-bit poly = square wave */
        return clock / (2UL * div);
    }
}

/* Game Boy pulse period register value for a frequency in Hz. */
static uint16_t pulse_period(uint32_t hz)
{
    uint32_t period;

    if (hz < 64UL) hz = 64UL;
    if (hz > 131072UL) hz = 131072UL;
    period = 2048UL - (131072UL / hz);
    if (period > 2047UL) period = 2047UL;
    return (uint16_t)period;
}

/* Pick the closest Game Boy noise frequency.  The rate table is 16 descending
 * groups of 8 entries, so only the entries inside [hz/4, hz*4] can win: any
 * entry outside is at least 3x farther than the nearest neighbour inside.
 * Skipping them keeps the scan exact (same order, same tie-break) but avoids
 * the 32-bit subtractions for 100+ entries. */
static uint8_t noise_period(uint32_t hz)
{
    uint8_t g, c, best = 0;
    uint32_t best_diff = 0xFFFFFFFFUL;
    uint32_t lo, hi;

    if (hz < 400UL) hz = 400UL;
    if (hz > 200000UL) hz = 200000UL;
    lo = hz >> 2;
    hi = hz << 2;

    for (g = 0; g < 16; g++) {
        for (c = 0; c < 8; c++) {
            uint8_t i = (uint8_t)((g << 3) | c);
            uint32_t f = noise_rate_table[i];
            uint32_t diff;

            if (f > hi) continue;
            if (f < lo) break;          /* rest of this group is smaller */
            diff = (f > hz) ? (f - hz) : (hz - f);
            if (diff < best_diff) {
                best_diff = diff;
                best = noise_code_table[i];
            }
        }
    }
    return best;
}

/* ------------------------------------------------------------------ */
/* Pattern mapping (sound-port2)                                      */
/* ------------------------------------------------------------------ */

/*
 * Pattern AUDC layout: bits 7-5 distortion, bit 4 clock, bits 3-0 volume.
 *   dist 5 / 7 -> pulse, 50% duty, f = clock / (2 * (AUDF + 1))
 *   dist 6     -> pulse, 25% duty, f = clock / (15 * (AUDF + 1))
 *   dist 4     -> noise, f = clock / (AUDF + 1)
 *   dist 0..3  -> noise, f = clock / (AUDF + 1) * 16 / 31
 *
 * The `shift << 4` layout below is deliberate: it reproduces the encoder the
 * sound-port2 ear tests approved.  Do not "fix" it to << 3.
 */
static uint8_t pattern_noise_nr43(uint32_t hz)
{
    /* NR43 f = 524288 / (2^shift * 2^(code+1)), so every (shift,code) pair is
     * really one total divide exponent t in 1..17 with f = 2^(19 - t).  The
     * original 56-iteration double loop visits those frequencies in t order
     * and keeps the first strict improvement, so this 17-step scan picks the
     * identical entry and tie.  The shift<<4 byte layout is preserved. */
    uint8_t t, best_t = 1, shift, code;
    uint32_t best_err = 0xFFFFFFFFUL;

    if (hz < 4UL) hz = 4UL;
    if (hz > 262144UL) hz = 262144UL;

    for (t = 1; t <= 17; t++) {
        uint32_t f = 0x80000UL >> t;
        uint32_t err = (f > hz) ? (f - hz) : (hz - f);
        if (err < best_err) {
            best_err = err;
            best_t = t;
        }
    }

    /* Byte-identical to the original first-improvement pair: (0, t-1) for
     * t <= 4, otherwise (t-4, 3). */
    if (best_t <= 4u) {
        shift = 0;
        code = (uint8_t)(best_t - 1u);
    } else {
        shift = (uint8_t)(best_t - 4u);
        code = 3;
    }
    return (uint8_t)((shift << 4) | code);
}

/* 0 silent, 1 noise step, 2 tone step. */
static uint8_t pattern_step_kind(uint8_t note, uint8_t index)
{
    uint8_t audc = sfx_notes[note][index].audc;

    if (audc == 0 || (audc & 0x0F) == 0) return 0;
    return ((audc >> 5) <= 4) ? 1 : 2;
}

static uint8_t pattern_has_sound(uint8_t note, uint8_t from)
{
    uint8_t i;

    for (i = from; i < SFX_STEPS; i++) {
        if (sfx_notes[note][i].audc != 0) return 1;
    }
    return 0;
}

static uint8_t pattern_last_live_step(uint8_t note)
{
    uint8_t i = SFX_STEPS;

    while (i != 0) {
        --i;
        if (sfx_notes[note][i].audc != 0) return i;
    }
    return 0;
}

/* ------------------------------------------------------------------ */
/* Voice bookkeeping                                                  */
/* ------------------------------------------------------------------ */

/* Stop using the channel this voice currently owns.  Pulse channels belong to
 * exactly one voice; the noise channel can be borrowed by a pulse voice for
 * the noisy steps of a mixed pattern, so it is only released by the voice
 * that last wrote it. */
static void release_voice(uint8_t vi)
{
    SfxVoice *v = &voices[vi];

    if (v->last_type == 2) {
        if (noise_owner == vi) {
            NR42_REG = 0x00;
            NR44_REG = 0x80;
            noise_owner = 0xFF;
        }
    } else if (v->last_type == 1 && vi < VOICE_NOISE) {
        *pulse_vol[vi] = 0x00;
        *pulse_period_hi[vi] = 0x80;
    } else if (v->last_type == 3) {
        /* Keep CH3's DAC biased; zero output level is silent. */
        NR32_REG = 0x00;
        wave_id = 0xFF;
    }
    v->last_type = 0;
}

/* Last step in a legacy window that is not a mute entry. */
static uint8_t last_live_step(const SfxDef *def)
{
    uint8_t i = def->count;

    while (i != 0) {
        --i;
        if (sfx_notes[def->note][def->first + i].audc != 0) return i;
    }
    return 0;
}

/* Rough time left, in tenths of a frame, used to decide voice stealing. */
static uint16_t legacy_remaining10(const SfxDef *def, uint8_t from)
{
    uint8_t last = last_live_step(def);
    uint8_t rate = def->step_frames ? def->step_frames : 1;

    if (last < from) return 0;
    return (uint16_t)(last - from + 1) * rate * 10;
}

static uint16_t pattern_remaining10(uint8_t note, uint8_t from)
{
    uint8_t last = pattern_last_live_step(note);

    if (last < from) return 0;
    return (uint16_t)(last - from + 1) * 48;
}

static uint16_t voice_remaining10(uint8_t vi)
{
    SfxVoice *v = &voices[vi];

    if (v->kind == VOICE_KIND_PATTERN) return pattern_remaining10(v->note, v->step);
    if (v->kind == VOICE_KIND_WAVE) {
        return (uint16_t)(SFX_GBC_STEPS - v->step) * 48;
    }
    return legacy_remaining10(v->def, v->step);
}

/* Pick a voice, or 0xFF when the new sound should be skipped. */
static uint8_t alloc_noise_voice(uint16_t want)
{
    if (voices[VOICE_NOISE].playing) {
        /* Keep a long effect (explosion, destruct) from being chopped by a
         * short blip, but let short effects replace each other: a bullet
         * impact must not disappear behind its own firing sound. */
        uint16_t have = voice_remaining10(VOICE_NOISE);
        if (have > (uint16_t)(want * 4)) return 0xFF;
    }
    return VOICE_NOISE;
}

static uint8_t alloc_pulse_voice(void)
{
    if (!voices[VOICE_PULSE1].playing) return VOICE_PULSE1;
    if (!voices[VOICE_PULSE2].playing) return VOICE_PULSE2;

    {
        uint16_t left0 = voice_remaining10(VOICE_PULSE1);
        uint16_t left1 = voice_remaining10(VOICE_PULSE2);

        if (left0 < left1) return VOICE_PULSE1;
        if (left1 < left0) return VOICE_PULSE2;
    }

    return ((int8_t)(voices[VOICE_PULSE1].started - voices[VOICE_PULSE2].started) <= 0)
        ? VOICE_PULSE1 : VOICE_PULSE2;
}

/* Pattern with only noise steps -> noise voice; anything with tone -> pulse. */
static uint8_t alloc_pattern_voice(uint8_t note)
{
    uint8_t i;
    uint8_t has_noise = 0;
    uint8_t has_pulse = 0;

    for (i = 0; i < SFX_STEPS; i++) {
        uint8_t kind = pattern_step_kind(note, i);
        if (kind == 1) has_noise = 1;
        else if (kind == 2) has_pulse = 1;
    }
    if (!has_noise && !has_pulse) return 0xFF;
    if (has_noise && !has_pulse) return alloc_noise_voice(pattern_remaining10(note, 0));
    return alloc_pulse_voice();
}

/* Legacy effects are either tone or noise; check the first step. */
static uint8_t legacy_is_noise(const SfxDef *def)
{
    return pokey_distortion(sfx_notes[def->note][def->first].audc) == 2;
}

static uint8_t alloc_legacy_voice(const SfxDef *def)
{
    if (legacy_is_noise(def)) return alloc_noise_voice(legacy_remaining10(def, 0));
    return alloc_pulse_voice();
}

/* ------------------------------------------------------------------ */
/* Step rendering                                                     */
/* ------------------------------------------------------------------ */

/* Cache of converted legacy step values.  pokey_rate() does two 32-bit
 * divisions and noise_period() a 128-entry 32-bit scan; a bomb chain
 * re-triggers the explosion definition dozens of times, always with the same
 * per-step (audc, audf) pairs.  Keyed by (def, step index) because every
 * input to the conversion is derived from those. */
typedef struct {
    const SfxDef *def;
    uint8_t index;
    uint8_t vol;
    uint8_t dist;
    uint8_t nr43;
    uint16_t period;
    uint8_t duty;
} SfxStepMemo;

#define SFX_STEP_MEMO 48    /* explosion 16 + destroy 17, with headroom */
static SfxStepMemo step_memo[SFX_STEP_MEMO];
static uint8_t step_memo_next;

static void apply_legacy_noise(uint8_t vi, uint8_t index, uint8_t vol,
                               uint8_t dist, uint8_t nr43)
{
    SfxVoice *v = &voices[vi];
    const SfxDef *def = v->def;
    uint8_t envbits = (uint8_t)(def->env & 0x07);

    (void)dist;
    /* A tone voice may borrow the noise channel for the noisy steps of a
     * mixed pattern; release its pulse channel first. */
    if (v->last_type == 1) {
        *pulse_vol[vi] = 0x00;
        *pulse_period_hi[vi] = 0x80;
    }

    if (def->attack_steps != 0 && index < def->attack_steps) {
        /* Fade-in phase: start at volume 0 and let the amplifying
         * hardware envelope raise it. */
        if (v->last_type != 2) {
            NR41_REG = 0x00;
            NR42_REG = (uint8_t)(0x08 | (def->attack_env & 0x07));
            NR43_REG = nr43;
            NR44_REG = 0x80;
        } else {
            NR43_REG = nr43;
        }
    } else if (def->attack_steps != 0 && index == def->attack_steps) {
        /* Peak reached: retrigger at full volume with a decaying
         * envelope for the fade-out. */
        NR42_REG = (uint8_t)(0xF0 | envbits);
        NR43_REG = nr43;
        NR44_REG = 0x80;
    } else if (!def->smooth || v->last_type != 2) {
        /* Start the noise channel. */
        NR41_REG = 0x00;
        NR42_REG = (uint8_t)((vol << 4) | envbits);
        NR43_REG = nr43;
        NR44_REG = 0x80;
    } else {
        /* Smooth pitch/rate update without restarting the LFSR. */
        if (envbits == 0) NR42_REG = (uint8_t)(vol << 4);
        NR43_REG = nr43;
    }
    noise_owner = vi;
    v->last_type = 2;
}

static void apply_legacy_pulse(uint8_t vi, uint8_t vol, uint8_t dist,
                               uint16_t period, uint8_t duty)
{
    SfxVoice *v = &voices[vi];
    const SfxDef *def = v->def;

    /* Back on this voice's own pulse channel: release the shared noise
     * channel if this voice was the one using it. */
    if (v->last_type == 2 && noise_owner == vi) {
        NR42_REG = 0x00;
        NR44_REG = 0x80;
        noise_owner = 0xFF;
    }

    if (def->square)    duty = 2; /* forced 50% square */
    else if (dist == 3) duty = 2; /* 50%  - clean square */
    else if (dist == 1) duty = 1; /* 25%  - 4-bit poly buzz */
    else                duty = 0; /* 12.5% - 5-bit poly buzz */

    if (def->smooth && v->last_type == 1 &&
        v->last_period == period && v->last_duty == duty) {
        if (def->env == 0) *pulse_vol[vi] = (uint8_t)(vol << 4);
    } else {
        *pulse_duty[vi] = (uint8_t)(duty << 6);
        *pulse_vol[vi] = (uint8_t)((vol << 4) | (def->env & 0x07));
        *pulse_period_lo[vi] = (uint8_t)(period & 0xFF);
        *pulse_period_hi[vi] = (uint8_t)(0x80 | ((period >> 8) & 0x07));
    }
    v->last_type = 1;
    v->last_period = period;
    v->last_duty = duty;
}

static uint8_t memo_find(const SfxDef *def, uint8_t index)
{
    uint8_t i;

    for (i = 0; i < SFX_STEP_MEMO; i++) {
        if (step_memo[i].def == def && step_memo[i].index == index) return i;
    }
    return 0xFF;
}

/* Convert one legacy step into the memo.  Pure: no APU writes.  Shared by
 * playback and by sfx_prewarm_def(), which fills the memo during level load
 * so the first explosion does not stall gameplay. */
static uint8_t memo_convert(const SfxDef *def, uint8_t index)
{
    const SfxStep *s = &sfx_notes[def->note][def->first + index];
    uint8_t audc = s->audc;
    uint8_t vol = pokey_volume(audc);
    uint8_t dist = pokey_distortion(audc);
    uint8_t slot = step_memo_next;
    SfxStepMemo *m = &step_memo[slot];
    uint32_t hz;

    /* POKEY table volumes are conservative; double them (clamped) so the
     * converted effects are audible on real DMG hardware.  Synthesized
     * notes (15..17) keep their authored volume. */
    if (def->note < 15) {
        vol = (uint8_t)(vol << 1);
        if (vol > 15) vol = 15;
    }

    /* A per-sound master used to change NR50 globally; with several voices
     * that would duck the other effects, so scale this sound's volume instead. */
    if (def->master >= 1 && def->master < 8) {
        vol = (uint8_t)(((uint16_t)vol * (def->master + 1)) / 8);
        if (vol == 0) vol = 1;
        if (vol > 15) vol = 15;
    }

    hz = pokey_rate(audc, s->audf);

    if (def->force_tone && dist == 2) {
        /* Some effects are noise on POKEY but a bright tone in the GB mix. */
        dist = 3;
        hz = def->tone_hz;
    }
    if (index < def->noise_steps) {
        /* Rising sweeps that the original renders with a poly counter sound
         * much closer to the game with the GB noise channel. */
        dist = 2;
    }

    if (dist == 2 && def->noise_pitch_q8 != 0) {
        hz = (hz * def->noise_pitch_q8) / 256UL;
    } else if (def->pitch_q8 != 256) {
        hz = (hz * def->pitch_q8) / 256UL;
    }

    m->def = def;
    m->index = index;
    m->vol = vol;
    m->period = 0;
    m->nr43 = 0;
    m->duty = 0;
    /* The voice a legacy def runs on is fixed by its first step, so the memo
     * can record the noise/pulse choice for every step. */
    if (legacy_is_noise(def) || dist == 2) {
        m->dist = 2;
        m->nr43 = noise_period(hz);
    } else {
        m->dist = dist;
        m->period = pulse_period(hz);
    }
    step_memo_next = (uint8_t)((step_memo_next + 1) % SFX_STEP_MEMO);
    return slot;
}

static void apply_legacy_step(uint8_t vi, uint8_t index)
{
    SfxVoice *v = &voices[vi];
    const SfxDef *def = v->def;
    const SfxStep *s = &sfx_notes[def->note][def->first + index];
    uint8_t audc = s->audc;
    uint8_t vol = pokey_volume(audc);
    uint8_t slot;

    if (def->gap && (index & 1)) {
        /* Muted step: keeps the timing grid but leaves a gap between bursts. */
        release_voice(vi);
        return;
    }

    if (vol == 0) {
        release_voice(vi);
        return;
    }

    slot = memo_find(def, index);
    if (slot == 0xFF) slot = memo_convert(def, index);

    if (step_memo[slot].dist == 2) {
        apply_legacy_noise(vi, index, step_memo[slot].vol,
                           step_memo[slot].dist, step_memo[slot].nr43);
    } else {
        apply_legacy_pulse(vi, step_memo[slot].vol, step_memo[slot].dist,
                           step_memo[slot].period, step_memo[slot].duty);
    }
}

/* GBC-converted note 11.  The table carries the exact NR43 values, the
 * 2048-period pair and the original POKEY volumes (no DMG doubling). */
static void apply_level_start_step(uint8_t vi, uint8_t index)
{
    SfxVoice *v = &voices[vi];
    const uint8_t *p = sfx_level_start_steps[index];
    uint8_t flags = p[0];
    uint8_t vol = flags & 0x0F;

    if (vol == 0) {
        release_voice(vi);
        return;
    }

    if (flags & 0x80) {
        /* Noise sweep.  A pulse voice may be borrowing CH4; release its pulse
         * channel first, exactly like the POKEY pattern path. */
        if (v->last_type == 1) {
            *pulse_vol[vi] = 0x00;
            *pulse_period_hi[vi] = 0x80;
        }
        NR41_REG = 0x00;
        NR42_REG = (uint8_t)(vol << 4);
        NR43_REG = p[1];
        NR44_REG = 0x80;
        noise_owner = vi;
        v->last_type = 2;
    } else {
        uint16_t period = (uint16_t)p[1] | ((uint16_t)(p[2] & 0x07) << 8);

        if (v->last_type == 2 && noise_owner == vi) {
            NR42_REG = 0x00;
            NR44_REG = 0x80;
            noise_owner = 0xFF;
        }
        *pulse_duty[vi] = 0xC0;   /* 50% square, matching POKEY $A */
        *pulse_vol[vi] = (uint8_t)(vol << 4);
        *pulse_period_lo[vi] = (uint8_t)(period & 0xFF);
        *pulse_period_hi[vi] = (uint8_t)(0x80 | ((period >> 8) & 0x07));
        v->last_type = 1;
        v->last_period = period;
        v->last_duty = 2;
    }
}

/* GBC-converted note 13: the last-bolt / capsule-open gated-noise fade.
 * alloc_pattern_voice() assigns this all-noise pattern to VOICE_NOISE, so the
 * step only has to drive CH4 with the precomputed NR43 and original volume. */
static void apply_last_bolt_step(uint8_t vi, uint8_t index)
{
    SfxVoice *v = &voices[vi];
    const uint8_t *p = sfx_last_bolt_steps[index];
    uint8_t vol = p[0] & 0x0F;

    if (vol == 0) {
        release_voice(vi);
        return;
    }

    NR41_REG = 0x00;
    NR42_REG = (uint8_t)(vol << 4);
    NR43_REG = p[1];
    NR44_REG = 0x80;
    noise_owner = vi;
    v->last_type = 2;
}

static void apply_pattern_step(uint8_t vi, uint8_t index)
{
    SfxVoice *v = &voices[vi];
    const SfxStep *s = &sfx_notes[v->note][index];
    uint8_t audc = s->audc;
    uint8_t vol;
    uint8_t dist;
    uint32_t clock;
    uint32_t div;
    uint32_t hz;

    /* The level-start fanfare now uses the GBC conversion for its noise
     * sweep and square tone.  The POKEY table is still used for its audible
     * step shape and end detection. */
    if (v->note == SFX_LEVEL_START) {
        apply_level_start_step(vi, index);
        return;
    }

    /* Last bolt / capsule open: GBC gated-noise fade. */
    if (v->note == SFX_LAST_BOLT) {
        apply_last_bolt_step(vi, index);
        return;
    }

    if (audc == 0) {
        release_voice(vi);
        return;
    }

    vol = (uint8_t)((audc & 0x0F) << 1);
    if (vol > 15) vol = 15;
    if (vol == 0) {
        release_voice(vi);
        return;
    }

    dist = (uint8_t)(audc >> 5);
    clock = (audc & 0x10) ? POKEY_CLOCK_179M : POKEY_CLOCK_64K;
    div = (uint32_t)s->audf + 1UL;

    if (dist <= 4) {
        uint8_t nr43;

        hz = clock / div;
        if (dist <= 3) hz = (hz * 16UL) / 31UL;
        if (hz < 4UL) hz = 4UL;
        if (hz > 262144UL) hz = 262144UL;

        /* A tone voice may borrow the noise channel; release its pulse
         * channel first. */
        if (v->last_type == 1) {
            *pulse_vol[vi] = 0x00;
            *pulse_period_hi[vi] = 0x80;
        }

        NR41_REG = 0x00;
        NR42_REG = (uint8_t)(vol << 4);
        nr43 = pattern_noise_nr43(hz);
        NR43_REG = nr43;
        NR44_REG = 0x80;
        noise_owner = vi;
        v->last_type = 2;
    } else {
        uint16_t period;
        uint8_t duty;

        /* Back on this voice's pulse channel. */
        if (v->last_type == 2 && noise_owner == vi) {
            NR42_REG = 0x00;
            NR44_REG = 0x80;
            noise_owner = 0xFF;
        }

        if (dist == 6) {
            hz = clock / (15UL * div);
            duty = 1; /* 25% duty */
        } else {
            hz = clock / (2UL * div);
            duty = 2; /* 50% duty */
        }
        if (hz < 31UL) hz = 31UL;
        if (hz > 65535UL) hz = 65535UL;
        period = 2048UL - (131072UL / hz);
        if (period > 2047UL) period = 2047UL;

        *pulse_duty[vi] = (uint8_t)(duty << 6);
        *pulse_vol[vi] = (uint8_t)(vol << 4);
        *pulse_period_lo[vi] = (uint8_t)(period & 0xFF);
        *pulse_period_hi[vi] = (uint8_t)(0x80 | ((period >> 8) & 0x07));
        v->last_type = 1;
        v->last_period = period;
        v->last_duty = duty;
    }
}

/* GBC door (POKEY note 6): CH3 poly4 wave body with three noise accents.
 * CH3 is dedicated to this voice; CH4 is borrowed only when no other voice
 * owns it, so a running explosion/shot is not chopped by the quiet door
 * accents. */
static void apply_door_step(uint8_t vi, uint8_t index)
{
    SfxVoice *v = &voices[vi];
    const uint8_t *p = sfx_door_steps[index];
    uint8_t flags = p[0];
    uint8_t vol = flags & 0x0F;
    uint8_t i;

    if (vol == 0) {
        release_voice(vi);
        return;
    }

    if (flags & 0x80) {
        if (v->last_type == 3) {
            NR32_REG = 0x00;
            wave_id = 0xFF;
        }
        if (noise_owner != 0xFF && noise_owner != vi) {
            /* A louder effect owns CH4; keep the wave body but drop this
             * quiet accent. */
            v->last_type = 0;
            return;
        }
        NR41_REG = 0x00;
        NR42_REG = (uint8_t)(vol << 4);
        NR43_REG = p[1];
        NR44_REG = 0x80;
        noise_owner = vi;
        v->last_type = 2;
        return;
    }

    /* Wave body. */
    if (v->last_type == 2 && noise_owner == vi) {
        NR42_REG = 0x00;
        NR44_REG = 0x80;
        noise_owner = 0xFF;
    }
    NR30_REG = 0x00;
    for (i = 0; i != 16; ++i) {
        ((volatile uint8_t *)0xFF30)[i] = sfx_door_waves[p[3]][i];
    }
    NR30_REG = 0x80;
    NR32_REG = 0x20;   /* 100%; the original volume is baked into the wave */
    NR33_REG = p[1];
    NR34_REG = (uint8_t)(0x80 | (p[2] & 0x07));
    wave_id = p[3];
    v->last_type = 3;
}

static void stop_voice(uint8_t vi)
{
    release_voice(vi);
    voices[vi].playing = 0;
    voices[vi].kind = 0;
    voices[vi].def = 0;
    voices[vi].note = 0xFF;
    sfx_voice_mask &= (uint8_t)~(1u << vi);
}

static uint8_t only_silence_left(const SfxDef *def, uint8_t from)
{
    uint8_t i;

    for (i = from; i < def->count; i++) {
        if (sfx_notes[def->note][def->first + i].audc != 0) return 0;
    }
    return 1;
}

/* ------------------------------------------------------------------ */
/* Public API                                                         */
/* ------------------------------------------------------------------ */

void sound_init(void) BANKED
{
    uint8_t i;

    NR52_REG = 0x80;   /* APU on */
    NR51_REG = 0xDF;   /* existing routing + CH3 on both outputs */
    NR50_REG = 0xFF;   /* left/right master volume 15 (max) */
    NR10_REG = 0x00;   /* no sweep */
    NR11_REG = 0x00;
    NR12_REG = 0x00;
    NR13_REG = 0x00;
    NR14_REG = 0x00;
    NR21_REG = 0x00;
    NR22_REG = 0x00;
    NR23_REG = 0x00;
    NR24_REG = 0x00;
    NR30_REG = 0x80;   /* CH3 DAC on, output level 0 while idle */
    NR31_REG = 0x00;
    NR32_REG = 0x00;
    NR33_REG = 0x00;
    NR34_REG = 0x00;
    NR41_REG = 0x00;
    NR42_REG = 0x00;
    NR43_REG = 0x00;
    NR44_REG = 0x00;

    for (i = 0; i < VOICE_COUNT; i++) {
        voices[i].def = 0;
        voices[i].kind = 0;
        voices[i].note = 0xFF;
        voices[i].playing = 0;
        voices[i].step = 0;
        voices[i].sub = 0;
        voices[i].wait = 0;
        voices[i].last_type = 0;
        voices[i].started = 0;
    }
    start_order = 0;
    noise_owner = 0xFF;
    wave_id = 0xFF;
    sfx_voice_mask = 0;
}

void sfx_play_note(uint8_t note) BANKED
{
    uint8_t vi;

    /* GBC start_level() stops all voices before the level fanfare, so a
     * previous level-end or death tail cannot mask it. */
    if (note == SFX_LEVEL_START) sfx_stop();

    /* Door open is the GBC CH3 wave effect, not the POKEY pattern path. */
    if (note == SFX_DOOR) {
        SfxVoice *v = &voices[VOICE_WAVE];

        release_voice(VOICE_WAVE);
        v->kind = VOICE_KIND_WAVE;
        v->def = 0;
        v->note = note;
        v->playing = 1;
        v->step = 0;
        v->sub = 0;
        v->wait = 0;
        v->started = ++start_order;
        sfx_voice_mask |= (uint8_t)(1u << VOICE_WAVE);
        apply_door_step(VOICE_WAVE, 0);
        return;
    }

    if (note >= SFX_PATTERN_COUNT) return;
    if (pattern_muted[note]) return;
    if (!pattern_has_sound(note, 0)) return;

    vi = alloc_pattern_voice(note);
    if (vi >= VOICE_COUNT) return;  /* skipped to protect a longer effect */

    {
        SfxVoice *v = &voices[vi];
        release_voice(vi);
        v->kind = VOICE_KIND_PATTERN;
        v->note = note;
        v->def = 0;
        v->playing = 1;
        v->step = 0;
        v->sub = 0;
        v->wait = 0;
        v->started = ++start_order;
    }
    sfx_voice_mask |= (uint8_t)(1u << vi);

    apply_pattern_step(vi, 0);
}

void sfx_play_def(const SfxDef *def) BANKED
{
    uint8_t vi, i;

    if (!def || def->count == 0 || def->note >= SFX_NOTE_COUNT) return;
    if ((uint16_t)(def->first + def->count) > SFX_STEPS) return;
    if (def->pitch_q8 == 0) return;

    /* Same effect already sounding (a bomb chain retriggering the explosion):
     * let the running voice finish instead of paying the voice-allocation and
     * frequency-mapping cost again and chopping it back to the first step. */
    for (i = 0; i < VOICE_COUNT; i++) {
        if (voices[i].playing && voices[i].kind == VOICE_KIND_LEGACY &&
            voices[i].def == def) {
            return;
        }
    }

    vi = alloc_legacy_voice(def);
    if (vi >= VOICE_COUNT) return;  /* skipped to protect a longer effect */

    {
        SfxVoice *v = &voices[vi];
        release_voice(vi);
        v->kind = VOICE_KIND_LEGACY;
        v->def = def;
        v->note = def->note;
        v->playing = 1;
        v->step = 0;
        v->sub = 0;
        v->wait = 0;
        v->started = ++start_order;
    }
    sfx_voice_mask |= (uint8_t)(1u << vi);

    /* The 6502 engine always starts at the highest-volume table entry. */
    apply_legacy_step(vi, 0);
}

/* Restart a legacy effect instead of treating it as a duplicate.  Explosions
 * use this for both bomb blasts and the death wipe, so each new blast is
 * audible even while an earlier one is still running.  Other legacy effects
 * keep sfx_play_def()'s duplicate guard. */
void sfx_restart_def(const SfxDef *def) BANKED
{
    uint8_t i;

    for (i = 0; i < VOICE_COUNT; i++) {
        if (voices[i].playing && voices[i].kind == VOICE_KIND_LEGACY &&
            voices[i].def == def) {
            release_voice(i);
            voices[i].playing = 0;
            voices[i].kind = 0;
            voices[i].def = 0;
            voices[i].note = 0xFF;
            sfx_voice_mask &= (uint8_t)~(1u << i);
        }
    }

    sfx_play_def(def);
}

void sfx_stop(void) BANKED
{
    uint8_t i;

    for (i = 0; i < VOICE_COUNT; i++) {
        voices[i].playing = 0;
        voices[i].kind = 0;
        voices[i].def = 0;
        voices[i].note = 0xFF;
        release_voice(i);
    }
    wave_id = 0xFF;
    sfx_voice_mask = 0;
}

void sfx_prewarm_def(const SfxDef *def) BANKED
{
    uint8_t i;

    if (!def || def->count == 0 || def->note >= SFX_NOTE_COUNT) return;
    if ((uint16_t)(def->first + def->count) > SFX_STEPS) return;

    for (i = 0; i < def->count; i++) {
        uint8_t audc = sfx_notes[def->note][def->first + i].audc;

        if (def->gap && (i & 1)) continue;   /* silenced when played */
        if (pokey_volume(audc) == 0) continue;
        if (memo_find(def, i) == 0xFF) memo_convert(def, i);
    }
}

void sfx_update(void) BANKED
{
    uint8_t i;

    for (i = 0; i < VOICE_COUNT; i++) {
        SfxVoice *v = &voices[i];
        uint8_t rate;

        if (!v->playing) continue;

        if (v->kind == VOICE_KIND_PATTERN) {
            /* sound-port2 grid: one step per 80 ms (4.8 DMG frames). */
            v->sub = (uint8_t)(v->sub + 10);
            if (v->sub < 48) continue;
            v->sub = (uint8_t)(v->sub - 48);

            v->step++;
            if (v->step >= SFX_STEPS || !pattern_has_sound(v->note, v->step)) {
                stop_voice(i);
                continue;
            }
            apply_pattern_step(i, v->step);
            continue;
        }

        if (v->kind == VOICE_KIND_WAVE) {
            /* Same 80 ms grid as the pattern effects. */
            v->sub = (uint8_t)(v->sub + 10);
            if (v->sub < 48) continue;
            v->sub = (uint8_t)(v->sub - 48);

            v->step++;
            if (v->step >= SFX_GBC_STEPS) {
                stop_voice(i);
                continue;
            }
            apply_door_step(i, v->step);
            continue;
        }

        rate = v->def->step_frames;
        if (v->step < v->def->noise_steps && v->def->noise_step_frames != 0) {
            rate = v->def->noise_step_frames;
        }
        if (rate == 0) rate = 1;

        if (++v->wait < rate) continue;
        v->wait = 0;

        v->step++;
        if (v->step >= v->def->count ||
            only_silence_left(v->def, v->step)) {
            stop_voice(i);
            continue;
        }
        apply_legacy_step(i, v->step);
    }
}

uint8_t sfx_is_playing(void) BANKED
{
    uint8_t i;

    for (i = 0; i < VOICE_COUNT; i++) {
        if (voices[i].playing) return 1;
    }
    return 0;
}

uint8_t sfx_current(void) BANKED
{
    uint8_t i;
    uint8_t best = 0xFF;
    int8_t best_age = 0;

    for (i = 0; i < VOICE_COUNT; i++) {
        int8_t age;

        if (!voices[i].playing) continue;
        age = (int8_t)(voices[i].started - start_order);
        if (best == 0xFF || age > best_age) {
            best = i;
            best_age = age;
        }
    }
    if (best == 0xFF) return 0xFF;
    if (voices[best].kind == VOICE_KIND_LEGACY) return voices[best].def->note;
    return voices[best].note;
}
