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
 *  - The WAVE voice plays the GBC door conversion on CH3 (GB) or the Atari
 *    25% pulse body on pulse 2 (NES): poly4 wave images / pulse plus a few
 *    CH4 noise accents.
 *
 * POLYPHONY
 * ---------
 *   voice 0 -> pulse channel 1 (tone effects)
 *   voice 1 -> pulse channel 2 (tone effects)
 *   voice 2 -> noise channel   (shot, impact, ammo, magnet, ...)
 *   voice 3 -> CH3 wave channel on Game Boy; on NES it controls the door's
 *              Atari-style 25% pulse layer on pulse 2 plus shared-noise
 *              accents
 *
 * A pattern that contains both noise and tone steps takes a pulse voice: it
 * borrows the shared noise channel for its noise steps and returns to its own
 * pulse channel for the tone tail (Level Start does this).  Noise-only
 * patterns use the noise voice.  When both pulse voices are busy the player
 * steals the one with the least time left; a short noise hit is dropped while
 * a much longer noise effect (explosion) is still running.
 */
#pragma bank 9

#include <gbdk/platform.h>
#include "platform_compat.h"
#include <stdint.h>

#include "sound.h"
#include "sfx_data.h"
#include "sfx_gbc_data.h"
#include "noise_table.h"

/* Legacy explosion effect retained from the previous sound set.  It lives in
 * the sound bank so every banked caller (gameplay, ending) can read it while
 * sfx_play_def()/sfx_prewarm_def() have the sound bank selected. */
const SfxDef sfx_explosion = { 16, 0, 16, 16, 4, 0, 0, 0, 0, 0, 0, 0, 1, 4 };

#ifdef NINTENDO_NES
/* Same reason as sfx_explosion: game.c is bank 14 on NES, and the player runs
 * in bank 9.  Keep the DESTROY definition next to the player so the pointer
 * stays valid after the bank switch. */
const SfxDef sfx_destroy = { 17, 0, 16, 406, 3, 0, 0, 0, 0, 0, 0, 0, 1, 5, 5, 3, 2 };
#endif

/* POKEY master clocks (PAL). */
#define POKEY_CLOCK_64K   63921UL
#define POKEY_CLOCK_179M  1789773UL

/* Voice 3 is the otherwise-unused CH3 wave channel on GB.  On NES it is the
 * door controller: it reserves pulse 2 for the Atari-style 25% pulse layer and
 * borrows the shared noise channel for the short accents. */
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
#ifdef NINTENDO_NES
    /* Software envelope used by the two legacy noise/pulse effects.  The
     * NES has a hardware envelope too, but it always starts at volume 15;
     * decaying the constant-volume value keeps each effect's authored
     * amplitude and matches the GB envelope timing. */
    uint8_t env_vol;
    uint8_t env_left;
    uint8_t env_rate;       /* frames per volume step, 0 = no envelope */
#endif
} SfxVoice;

#ifdef DEBUG_STATE
/* Exposed in the debug ROM so the sound harness can inspect every voice.
 * The release build keeps the array private. */
SfxVoice voices[VOICE_COUNT];
#else
static SfxVoice voices[VOICE_COUNT];
#endif
static uint8_t start_order;
static uint8_t noise_owner;   /* voice driving the noise channel, 0xFF none */
static uint8_t wave_id;       /* CH3 wave image currently loaded, 0xFF none */
#ifdef NINTENDO_NES
static uint8_t door_pulse = 0xFF;  /* pulse channel reserved for the door */
#endif

uint8_t sfx_voice_mask;
uint8_t sfx_beep_frames;       /* title line-feed beep: frames left, 0 idle */
#ifdef NINTENDO_NES
static uint8_t sfx_click_frames;  /* title typewriter noise tick, 0 idle */
#endif

#ifndef NINTENDO_NES
/* Pulse channel register views, so one code path can drive either channel. */
static volatile uint8_t *const pulse_duty[2] = { &NR11_REG, &NR21_REG };
static volatile uint8_t *const pulse_vol[2] = { &NR12_REG, &NR22_REG };
static volatile uint8_t *const pulse_period_lo[2] = { &NR13_REG, &NR23_REG };
static volatile uint8_t *const pulse_period_hi[2] = { &NR14_REG, &NR24_REG };
#else
/* ------------------------------------------------------------------ */
/* NES APU backend                                                     */
/* ------------------------------------------------------------------ */
/* The shared player still computes Game Boy register-style values (duty,
 * 4-bit volume, 11-bit pulse period, NR43 noise divider).  These helpers
 * translate them to the four 2A03 channels:
 *
 *   voice 0 -> $4000 pulse 1
 *   voice 1 -> $4004 pulse 2 (also carries the door's 25% pulse layer)
 *   voice 2 -> $400C noise
 *   voice 3 -> door controller (triangle body + pulse 2 layer)
 */
#define APU_REG(r)      (*(volatile uint8_t *)(0x4000u + (r)))

/* GB pulse/wave period -> NES timer.  GB pulse f = 131072/(2048-p); the NES
 * pulse and triangle timers divide by 16 and 32 respectively, so both use
 * t = (2048-p)*1789773/2097152 - 1.  27/32 is a close 16-bit-safe scale
 * (1.1% low), and every effect stays well inside the audible range. */
static uint16_t apu_timer(uint16_t gb_period)
{
    uint16_t x = (uint16_t)(2048u - (gb_period & 0x07FFu));
    uint16_t t = (uint16_t)((x * 27u) >> 5);

    return t ? (uint16_t)(t - 1u) : 0u;
}

/* Nearest NES noise period index for a GB NR43 divider.  GB noise is
 * f = 2^(19-t) with t = shift + code + 1; the NES table spans 447 kHz down to
 * 440 Hz, so the lowest GB rates all clamp to index 15. */
static const uint8_t apu_noise_map[24] = {
    0, 1, 2, 3, 4, 5, 7, 10, 12, 14, 15, 15,
    15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15
};

static uint8_t apu_noise_period(uint8_t nr43)
{
    /* t is always 1..23: shift 0..15 + code 0..7 + 1. */
    uint8_t t = (uint8_t)((nr43 >> 4) + (nr43 & 0x07u) + 1u);
    uint8_t reg = apu_noise_map[t];

    if (nr43 & 0x08u) reg |= 0x80;  /* GB 7-bit noise -> NES short mode */
    return reg;
}

/* One NES noise period step higher.  At the bottom of the range (p=15 -> 14)
 * this is a clean octave; the explosions use it to sit an octave above the
 * NES noise floor. */
static uint8_t apu_noise_period_up(uint8_t nr43)
{
    uint8_t reg = apu_noise_period(nr43);
    uint8_t p = (uint8_t)(reg & 0x0Fu);

    if (p) p--;
    return (uint8_t)((reg & 0x80u) | p);
}

static void apu_pulse_off(uint8_t vi)
{
    /* Halt the length counter and hold a constant volume of zero. */
    APU_REG(vi ? 0x04 : 0x00) = 0x30;
    voices[vi].env_rate = 0;
}

static void apu_noise_off(void)
{
    APU_REG(0x0C) = 0x30;
}

static void apu_triangle_off(void)
{
    /* Control clear + reload 0: the linear counter is reloaded with zero and
     * mutes the triangle on the next quarter frame. */
    APU_REG(0x08) = 0x00;
}

static void apu_triangle_start(uint16_t period)
{
    uint16_t t = apu_timer(period);

    /* Control clear + reload 127: the counter is reloaded every quarter frame
     * and never reaches zero.  $400B reloads the length counter, which the
     * 80 ms step grid refreshes before it can expire. */
    APU_REG(0x08) = 0x7F;
    APU_REG(0x0A) = (uint8_t)(t & 0xFFu);
    APU_REG(0x0B) = (uint8_t)(0xF8u | ((t >> 8) & 0x07u));
}

static void apu_pulse_volume(uint8_t vi, uint8_t vol)
{
    APU_REG(vi ? 0x04 : 0x00) =
        (uint8_t)((voices[vi].last_duty << 6) | 0x30u | (vol & 0x0Fu));
}

static void apu_pulse_start_timer(uint8_t vi, uint8_t duty, uint8_t vol,
                                  uint16_t t, uint8_t env)
{
    /* A timer below 8 can be muted by the pulse sweep target logic even with
     * the sweep unit disabled; no effect needs a frequency above 12 kHz. */
    if (t < 8u) t = 8u;

    APU_REG(vi ? 0x04 : 0x00) =
        (uint8_t)((duty << 6) | 0x30u | (vol & 0x0Fu));
    APU_REG(vi ? 0x05 : 0x01) = 0x00;               /* sweep off */
    APU_REG(vi ? 0x06 : 0x02) = (uint8_t)(t & 0xFFu);
    APU_REG(vi ? 0x07 : 0x03) = (uint8_t)(0xF8u | ((t >> 8) & 0x07u));

    voices[vi].env_vol = vol;
    voices[vi].env_rate = env;
    voices[vi].env_left = env;
}

static void apu_pulse_start(uint8_t vi, uint8_t duty, uint8_t vol,
                            uint16_t period, uint8_t env)
{
    apu_pulse_start_timer(vi, duty, vol, apu_timer(period), env);
}

/* GB CH3 wave period -> NES pulse timer.  The GB wave channel runs one octave
 * below the pulse channel for the same period, so the timer is doubled to
 * keep the GBC door's pitch when the wave is played as a 25% pulse. */
static uint16_t apu_wave_pulse_timer(uint16_t period)
{
    uint16_t t = apu_timer(period);

    t = (uint16_t)((t << 1) | 1u);
    if (t > 2047u) t = 2047u;
    return t;
}

static void apu_noise_volume(uint8_t vol)
{
    APU_REG(0x0C) = (uint8_t)(0x30u | (vol & 0x0Fu));
}

static void apu_noise_rate_reg(uint8_t reg)
{
    APU_REG(0x0E) = reg;
}

static void apu_noise_start_reg(uint8_t vi, uint8_t vol, uint8_t reg,
                                uint8_t env)
{
    APU_REG(0x0C) = (uint8_t)(0x30u | (vol & 0x0Fu));
    APU_REG(0x0E) = reg;
    APU_REG(0x0F) = 0x00;   /* halt is set, so the length value is unused */

    voices[vi].env_vol = vol;
    voices[vi].env_rate = env;
    voices[vi].env_left = env;
}

static void apu_noise_start(uint8_t vi, uint8_t vol, uint8_t nr43,
                            uint8_t env)
{
    apu_noise_start_reg(vi, vol, apu_noise_period(nr43), env);
}
#endif

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

#ifdef NINTENDO_NES
    /* Voice 3 owns the door's pulse-2 layer for the whole effect, even when
     * the last door step was a noise accent and changed last_type. */
    if (vi == VOICE_WAVE && door_pulse != 0xFF) {
        apu_pulse_off(door_pulse);
        door_pulse = 0xFF;
        apu_triangle_off();
        wave_id = 0xFF;
    }

    if (v->last_type == 2) {
        if (noise_owner == vi) {
            apu_noise_off();
            noise_owner = 0xFF;
        }
    } else if (v->last_type == 1 && vi < VOICE_NOISE) {
        apu_pulse_off(vi);
    } else if (v->last_type == 3) {
        if (door_pulse != 0xFF) {
            apu_pulse_off(door_pulse);
            door_pulse = 0xFF;
        }
        apu_triangle_off();
        wave_id = 0xFF;
    }
    v->env_rate = 0;
#else
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
#endif
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
#ifdef NINTENDO_NES
    /* The door owns pulse 2 for its 25% pulse layer; keep new effects on
     * pulse 1 while it plays. */
    if (door_pulse != 0xFF) return VOICE_PULSE1;
#endif
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

#ifdef NINTENDO_NES
    uint8_t noise_reg;

    (void)dist;
    /* A tone voice may borrow the noise channel for the noisy steps of a
     * mixed pattern; release its pulse channel first. */
    if (v->last_type == 1) apu_pulse_off(vi);

    /* The main explosion sits one NES noise step above the 440 Hz floor. */
    noise_reg = (def == &sfx_explosion)
        ? apu_noise_period_up(nr43) : apu_noise_period(nr43);

    if (def->attack_steps != 0) {
        /* NES has no rising hardware envelope.  DESTROY's 5-step attack is
         * reproduced as a short constant-volume ramp, then the peak step
         * starts the normal software decay. */
        uint8_t peak = (def->master >= 1 && def->master < 8)
            ? (uint8_t)(((uint16_t)(def->master + 1u) * 15u) / 8u)
            : 15u;

        if (index < def->attack_steps) {
            uint8_t attack_vol = (uint8_t)
                (((uint16_t)peak * (index + 1u)) / (def->attack_steps + 1u));
            apu_noise_start_reg(vi, attack_vol, noise_reg, 0);
            noise_owner = vi;
            v->last_type = 2;
            return;
        }
        if (index == def->attack_steps) {
            apu_noise_start_reg(vi, peak, noise_reg, def->env);
            noise_owner = vi;
            v->last_type = 2;
            return;
        }
    }

    if (!def->smooth || v->last_type != 2) {
        apu_noise_start_reg(vi, vol, noise_reg, def->env);
    } else {
        if (def->env == 0) apu_noise_volume(vol);
        apu_noise_rate_reg(noise_reg);
    }
    noise_owner = vi;
    v->last_type = 2;
#else
    uint8_t envbits = (uint8_t)(def->env & 0x07);
    uint8_t peak;

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
        /* Peak reached: retrigger with a decaying envelope for the fade-out.
         * The fade-in starts from volume 0, so this is the first audible
         * level; apply SfxDef.master here too, otherwise the peak would
         * always be full scale and the per-sound volume control would have
         * no effect. */
        peak = (def->master >= 1 && def->master < 8)
            ? (uint8_t)(((uint16_t)(def->master + 1u) * 15u) / 8u)
            : 15u;
        NR42_REG = (uint8_t)((peak << 4) | envbits);
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
#endif
}

static void apply_legacy_pulse(uint8_t vi, uint8_t vol, uint8_t dist,
                               uint16_t period, uint8_t duty)
{
    SfxVoice *v = &voices[vi];
    const SfxDef *def = v->def;

#ifdef NINTENDO_NES
    /* Back on this voice's own pulse channel: release the shared noise
     * channel if this voice was the one using it. */
    if (v->last_type == 2 && noise_owner == vi) {
        apu_noise_off();
        noise_owner = 0xFF;
    }

    if (def->square)    duty = 2; /* forced 50% square */
    else if (dist == 3) duty = 2; /* 50%  - clean square */
    else if (dist == 1) duty = 1; /* 25%  - 4-bit poly buzz */
    else                duty = 0; /* 12.5% - 5-bit poly buzz */

    if (def->smooth && v->last_type == 1 &&
        v->last_period == period && v->last_duty == duty) {
        if (def->env == 0) apu_pulse_volume(vi, vol);
    } else {
        apu_pulse_start(vi, duty, vol, period, def->env);
    }
#else
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
#endif
    v->last_type = 1;
    v->last_period = period;
    v->last_duty = duty;
}

static uint8_t memo_find(const SfxDef *def, uint8_t index)
{
    const SfxStep *want = &sfx_notes[def->note][def->first + index];
    uint8_t want_noise = (def->noise_steps != 0 && index < def->noise_steps);
    uint8_t i;

    for (i = 0; i < SFX_STEP_MEMO; i++) {
        const SfxStep *have;

        if (step_memo[i].def != def) continue;
        if (step_memo[i].index == index) return i;
        /* Identical AUDC/AUDF steps convert to identical hardware values.
         * The only index-dependent input is the noise_steps override, so a
         * value match is safe on the same side of that boundary.  DESTROY is
         * 16 identical steps; sharing one memo entry keeps level-load
         * prewarming from converting the same pair 16 times. */
        if (def->noise_steps != 0 &&
            ((step_memo[i].index < def->noise_steps) != want_noise)) {
            continue;
        }
        have = &sfx_notes[def->note][def->first + step_memo[i].index];
        if (have->audc == want->audc && have->audf == want->audf) return i;
    }
    return 0xFF;
}

/* Convert one legacy step into the memo.  Pure: no APU writes.  Shared by
 * playback and by sfx_prewarm_def(), which fills the memo during level load
 * so the first explosion or destroyed tile does not stall gameplay. */
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

#ifdef NINTENDO_NES
    if (flags & 0x80) {
        if (v->last_type == 1) apu_pulse_off(vi);
        apu_noise_start(vi, vol, p[1], 0);
        noise_owner = vi;
        v->last_type = 2;
    } else {
        uint16_t period = (uint16_t)p[1] | ((uint16_t)(p[2] & 0x07) << 8);

        if (v->last_type == 2 && noise_owner == vi) {
            apu_noise_off();
            noise_owner = 0xFF;
        }
        apu_pulse_start(vi, 2, vol, period, 0);  /* 50% square */
        v->last_type = 1;
        v->last_period = period;
        v->last_duty = 2;
    }
#else
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
#endif
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

#ifdef NINTENDO_NES
    {
        /* Atari note 13 ("last bolt"/capsule open) is a 5-bit poly noise
         * burst alternating AUDF 8 (higher) and 24 (lower).  The GBC table
         * encodes those as NR43 0x45/0x57.  NES long noise sounds white, so
         * use short mode for the 93-bit metallic character and keep the two
         * rates distinct: the high step moves to p=14, the low step stays at
         * the 440 Hz floor (p=15). */
        uint8_t t = (uint8_t)((p[1] >> 4) + (p[1] & 0x07u) + 1u);
        uint8_t reg = (t <= 10u)
            ? apu_noise_period_up(p[1]) : apu_noise_period(p[1]);

        reg |= 0x80u;   /* NES short mode: metallic 93-bit LFSR */
        apu_noise_start_reg(vi, vol, reg, 0);
    }
#else
    NR41_REG = 0x00;
    NR42_REG = (uint8_t)(vol << 4);
    NR43_REG = p[1];
    NR44_REG = 0x80;
#endif
    noise_owner = vi;
    v->last_type = 2;
}

/* Cache of converted pattern steps.  apply_pattern_step() used to pay the
 * 32-bit POKEY -> DMG divisions on every step; laser turret levels retrigger
 * SFX_HIT_WALL constantly, so memoize the conversion exactly like the legacy
 * apply_legacy_step() path.  Keyed by (note, step) because every input to the
 * conversion derives from those two.  vol/dist are derived cheaply from AUDC
 * and kept local, so only the expensive nr43/period/duty go in the memo. */
typedef struct {
    uint8_t note;
    uint8_t index;
    uint8_t nr43;      /* valid when dist <= 4 */
    uint16_t period;   /* valid when dist > 4 */
    uint8_t duty;
} PatternMemo;

#define PATTERN_MEMO 24
static PatternMemo pattern_memo[PATTERN_MEMO];
static uint8_t pattern_memo_next;

static PatternMemo *pattern_memo_find(uint8_t note, uint8_t index)
{
    uint8_t i;
    for (i = 0; i < PATTERN_MEMO; i++) {
        if (pattern_memo[i].note == note && pattern_memo[i].index == index) {
            return &pattern_memo[i];
        }
    }
    return 0;
}

static PatternMemo *pattern_memo_slot(void)
{
    PatternMemo *m = &pattern_memo[pattern_memo_next];
    pattern_memo_next = (uint8_t)((pattern_memo_next + 1) % PATTERN_MEMO);
    return m;
}

/* Convert one POKEY step into DMG hardware values.  Pure: no APU writes. */
static void pattern_convert(uint8_t audc, uint8_t audf, uint8_t dist,
                            PatternMemo *m)
{
    uint32_t clock = (audc & 0x10) ? POKEY_CLOCK_179M : POKEY_CLOCK_64K;
    uint32_t div = (uint32_t)audf + 1UL;
    uint32_t hz;

    if (dist <= 4) {
        hz = clock / div;
        if (dist <= 3) hz = (hz * 16UL) / 31UL;
        if (hz < 4UL) hz = 4UL;
        if (hz > 262144UL) hz = 262144UL;
        m->nr43 = pattern_noise_nr43(hz);
        m->period = 0;
        m->duty = 0;
    } else {
        uint16_t period;
        uint8_t duty;

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
        m->nr43 = 0;
        m->period = period;
        m->duty = duty;
    }
}

static void apply_pattern_step(uint8_t vi, uint8_t index)
{
    SfxVoice *v = &voices[vi];
    uint8_t note = v->note;
    const SfxStep *s = &sfx_notes[note][index];
    uint8_t audc = s->audc;
    uint8_t vol;
    uint8_t dist;
    PatternMemo *m;

    /* The level-start fanfare now uses the GBC conversion for its noise
     * sweep and square tone.  The POKEY table is still used for its audible
     * step shape and end detection. */
    if (note == SFX_LEVEL_START) {
        apply_level_start_step(vi, index);
        return;
    }

    /* Last bolt / capsule open: GBC gated-noise fade. */
    if (note == SFX_LAST_BOLT) {
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

    m = pattern_memo_find(note, index);
    if (!m) {
        m = pattern_memo_slot();
        m->note = note;
        m->index = index;
        pattern_convert(audc, s->audf, dist, m);
    }

    if (dist <= 4) {
#ifdef NINTENDO_NES
        /* A tone voice may borrow the noise channel; release its pulse
         * channel first. */
        if (v->last_type == 1) apu_pulse_off(vi);
        apu_noise_start(vi, vol, m->nr43, 0);
        noise_owner = vi;
        v->last_type = 2;
#else
        /* A tone voice may borrow the noise channel; release its pulse
         * channel first. */
        if (v->last_type == 1) {
            *pulse_vol[vi] = 0x00;
            *pulse_period_hi[vi] = 0x80;
        }

        NR41_REG = 0x00;
        NR42_REG = (uint8_t)(vol << 4);
        NR43_REG = m->nr43;
        NR44_REG = 0x80;
        noise_owner = vi;
        v->last_type = 2;
#endif
    } else {
#ifdef NINTENDO_NES
        /* Back on this voice's pulse channel. */
        if (v->last_type == 2 && noise_owner == vi) {
            apu_noise_off();
            noise_owner = 0xFF;
        }

        apu_pulse_start(vi, m->duty, vol, m->period, 0);
        v->last_type = 1;
        v->last_period = m->period;
        v->last_duty = m->duty;
#else
        /* Back on this voice's pulse channel. */
        if (v->last_type == 2 && noise_owner == vi) {
            NR42_REG = 0x00;
            NR44_REG = 0x80;
            noise_owner = 0xFF;
        }

        *pulse_duty[vi] = (uint8_t)(m->duty << 6);
        *pulse_vol[vi] = (uint8_t)(vol << 4);
        *pulse_period_lo[vi] = (uint8_t)(m->period & 0xFF);
        *pulse_period_hi[vi] = (uint8_t)(0x80 | ((m->period >> 8) & 0x07));
        v->last_type = 1;
        v->last_period = m->period;
        v->last_duty = m->duty;
#endif
    }
}

/* GBC door (POKEY note 6): CH3 poly4 wave body with three noise accents on
 * GB.  The NES path plays the original Atari 25% pulse body on pulse 2 at the
 * same pitch, with the same noise accents.  The noise channel is borrowed only
 * when no other voice owns it, so a running explosion/shot is not chopped by
 * the quiet door accents. */
static void apply_door_step(uint8_t vi, uint8_t index)
{
    SfxVoice *v = &voices[vi];
    const uint8_t *p = sfx_door_steps[index];
    uint8_t flags = p[0];
    uint8_t vol = flags & 0x0F;

    if (vol == 0) {
        release_voice(vi);
        return;
    }

#ifdef NINTENDO_NES
    if (flags & 0x80) {
        if (v->last_type == 3) {
            if (door_pulse != 0xFF) apu_pulse_off(door_pulse);
            apu_triangle_off();
            wave_id = 0xFF;
        }
        if (noise_owner != 0xFF && noise_owner != vi) {
            /* A louder effect owns the noise channel; keep the pulse body
             * but drop this quiet accent. */
            v->last_type = 0;
            return;
        }
        apu_noise_start(vi, vol, p[1], 0);
        noise_owner = vi;
        v->last_type = 2;
        return;
    }

    /* Wave body.  The Atari door is a 25% pulse (AUDC $C1-$C8), not a sine.
     * Play the GBC wave's pitch as a full triangle fundamental plus a boosted
     * 25% pulse layer for the harmonics; at 60-90 Hz either layer alone is
     * easily lost on TV speakers.  Pulse 2 is reserved for the door while it
     * plays. */
    if (v->last_type == 2 && noise_owner == vi) {
        apu_noise_off();
        noise_owner = 0xFF;
    }
    {
        uint16_t period = (uint16_t)p[1] |
                          ((uint16_t)(p[2] & 0x07) << 8);
        uint8_t boost = (uint8_t)(vol + 7u);

        if (boost > 15u) boost = 15u;
        apu_triangle_start(period);
        if (door_pulse == 0xFF) door_pulse = VOICE_PULSE2;
        apu_pulse_start_timer(door_pulse, 1, boost,
                              apu_wave_pulse_timer(period), 0);
    }
    wave_id = p[3];
    v->last_type = 3;
#else
    uint8_t i;

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
        /* Must go through the platform shim: $FF30 is the UxROM bank
         * register on NES, not wave RAM. */
        PLATFORM_WAVE_RAM(i) = sfx_door_waves[p[3]][i];
    }
    NR30_REG = 0x80;
    NR32_REG = 0x20;   /* 100%; the original volume is baked into the wave */
    NR33_REG = p[1];
    NR34_REG = (uint8_t)(0x80 | (p[2] & 0x07));
    wave_id = p[3];
    v->last_type = 3;
#endif
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

#ifdef NINTENDO_NES
    /* $4015 enables pulse 1/2, triangle and noise (DMC stays off).  $4017
     * selects the 4-step sequencer with the frame IRQ inhibited; the APU
     * envelopes are clocked at 240 Hz in that mode. */
    APU_REG(0x15) = 0x0F;
    APU_REG(0x17) = 0x40;
    APU_REG(0x01) = 0x00;   /* pulse 1 sweep off */
    APU_REG(0x05) = 0x00;   /* pulse 2 sweep off */
    apu_pulse_off(0);
    apu_pulse_off(1);
    apu_noise_off();
    apu_triangle_off();
#else
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
#endif

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
#ifdef NINTENDO_NES
        voices[i].env_vol = 0;
        voices[i].env_left = 0;
        voices[i].env_rate = 0;
#endif
    }
    start_order = 0;
    noise_owner = 0xFF;
    wave_id = 0xFF;
    sfx_voice_mask = 0;
#ifdef NINTENDO_NES
    sfx_click_frames = 0;
    door_pulse = 0xFF;
#endif
}

void sfx_play_note(uint8_t note) BANKED
{
    uint8_t vi;

    /* GBC start_level() stops all voices before the level fanfare, so a
     * previous level-end or death tail cannot mask it. */
    if (note == SFX_LEVEL_START) sfx_stop();

    /* Door open: the GBC CH3 wave effect on GB; on NES the original Atari
     * 25% pulse, using pulse 2 so the door stays independent of the pattern
     * pulse voices. */
    if (note == SFX_DOOR) {
        SfxVoice *v = &voices[VOICE_WAVE];

        release_voice(VOICE_WAVE);
#ifdef NINTENDO_NES
        stop_voice(VOICE_PULSE2);
        door_pulse = VOICE_PULSE2;
#endif
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
    if (sfx_beep_frames) {
        sfx_beep_frames = 0;
#ifdef NINTENDO_NES
        apu_pulse_off(0);
#else
        NR12_REG = 0x00;
        NR14_REG = 0x80;
#endif
    }
#ifdef NINTENDO_NES
    if (sfx_click_frames) {
        sfx_click_frames = 0;
        apu_noise_off();
    }
#endif
}

void sfx_click(void) BANKED
{
    /* GBC title typewriter click: one short 15-bit noise tick.  No voice is
     * running on the title screen (sfx_stop clears them on entry), so the
     * noise channel can be driven directly without confusing the mixer. */
#ifdef NINTENDO_NES
    /* Constant volume 5 with a short software timeout; the NES hardware
     * envelope would start at full scale and be far louder than the DMG
     * click. */
    APU_REG(0x0C) = 0x35;
    APU_REG(0x0E) = apu_noise_period(0x30);
    APU_REG(0x0F) = 0x00;
    sfx_click_frames = 3;
#else
    NR41_REG = 0x00;
    NR42_REG = 0x51;
    NR43_REG = 0x30;
    NR44_REG = 0x80;
#endif
    noise_owner = 0xFF;
}

void sfx_beep(void) BANKED
{
    /* Line-feed beep: pulse 1 at ~3520 Hz (one octave above A6), 50% duty.
     * Volume 4 with envelope period 1 decays in about four real frames.
     * sfx_update() also tracks a four-frame logical window so sfx_stop() can
     * silence a beep if the player starts the game mid-line.  The title is
     * the only caller and has no other pulse voice. */
#ifdef NINTENDO_NES
    /* Same pitch: NR13/NR14 period $7DB -> 3496 Hz through the 27/32 scale. */
    apu_pulse_start(0, 2, 4, 2011, 0);
#else
    NR10_REG = 0x00;
    NR11_REG = 0x80;
    NR12_REG = 0x41;
    NR13_REG = 0xDB;
    NR14_REG = 0x87;
#endif
    sfx_beep_frames = 4;
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

#ifdef NINTENDO_NES
    if (sfx_click_frames) {
        if (--sfx_click_frames == 0) apu_noise_off();
    }
#endif

    if (sfx_beep_frames) {
        if (--sfx_beep_frames == 0) {
#ifdef NINTENDO_NES
            apu_pulse_off(0);
#else
            NR12_REG = 0x00;
            NR14_REG = 0x80;
#endif
        }
    }

    for (i = 0; i < VOICE_COUNT; i++) {
        SfxVoice *v = &voices[i];
        uint8_t rate;

        if (!v->playing) continue;

#ifdef NINTENDO_NES
        /* Software envelope for the two legacy effects.  It runs every frame,
         * including frames where the step grid does not advance. */
        if (v->env_rate && v->env_vol) {
            if (--v->env_left == 0) {
                v->env_left = v->env_rate;
                v->env_vol--;
                if (v->last_type == 1) apu_pulse_volume(i, v->env_vol);
                else if (v->last_type == 2) apu_noise_volume(v->env_vol);
            }
        }
#endif

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
