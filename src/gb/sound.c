/*
 * sound.c - POKEY -> Game Boy sound-effect player.
 *
 * The original Atari engine (see tools/gen_sfx.js) stores each effect as 16
 * (AUDC, AUDF) register pairs.  It writes one pair every 4th PAL frame
 * (80 ms), stepping from volume 16 down to volume 1.  AUDC selects the clock
 * (64 kHz / 1.79 MHz), the distortion (polynomial counter type) and the
 * volume; AUDF is the divider.
 *
 * Game Boy mapping:
 *   AUDC distortion 3 (17-bit poly, clean tone) -> pulse, 50% duty
 *   AUDC distortion 0 (5-bit poly, buzzy)       -> pulse, 12.5% duty
 *   AUDC distortion 1 (4-bit poly, buzzy)       -> pulse, 25% duty
 *   AUDC distortion 2 (5+4 poly, noise)         -> noise channel
 *   AUDC volume 0..15                           -> NRx2 volume 0..15
 *
 * Each SfxDef selects a window into a pattern, a fixed-point pitch
 * multiplier and a step rate.  The multipliers below were chosen from an
 * ear comparison with the real game (the high "ding" effects are perceived
 * roughly two octaves lower than the raw POKEY polynomial rate).
 *
 * POLYPHONY
 * ---------
 * The original Atari engine also plays one effect at a time, but the port
 * starts effects from many game events per frame (step + pickup + shot...).
 * Rather than restarting a single voice, the player runs three independent
 * voices:
 *
 *   voice 0 -> pulse channel 1 (tone effects)
 *   voice 1 -> pulse channel 2 (tone effects)
 *   voice 2 -> noise channel   (shot, impact, explosion, destroy)
 *
 * Every pulse effect takes a free pulse voice; if both are busy it steals the
 * one with the least amount of pattern left, so a footstep cannot cut off a
 * level jingle.  Noise effects share the one noise channel; a short noise
 * hit is dropped while a much longer explosion is still running.  Mixed
 * patterns (Level Start, Door Open) hold a pulse voice but borrow the noise
 * channel for their noisy opening steps, as the original did.
 */
#pragma bank 9

#include <gb/gb.h>
#include <stdint.h>

#include "sound.h"
#include "sfx_data.h"
#include "noise_table.h"

/* POKEY master clocks (PAL). */
#define POKEY_CLOCK_64K   63921UL
#define POKEY_CLOCK_179M  1789773UL

#define VOICE_PULSE1 0
#define VOICE_PULSE2 1
#define VOICE_NOISE  2
#define VOICE_COUNT  3

typedef struct {
    const SfxDef *def;
    uint8_t playing;
    uint8_t step;
    uint8_t wait;
    uint8_t last_type;      /* 0 none, 1 pulse, 2 noise */
    uint16_t last_period;
    uint8_t last_duty;
    uint8_t started;        /* start order, used for voice stealing */
} SfxVoice;

static SfxVoice voices[VOICE_COUNT];
static uint8_t start_order;
static uint8_t noise_owner;   /* voice currently driving the noise channel, 0xFF none */

uint8_t sfx_voice_mask;

/* Pulse channel register views, so one code path can drive either channel. */
static volatile uint8_t *const pulse_duty[2] = { &NR11_REG, &NR21_REG };
static volatile uint8_t *const pulse_vol[2] = { &NR12_REG, &NR22_REG };
static volatile uint8_t *const pulse_period_lo[2] = { &NR13_REG, &NR23_REG };
static volatile uint8_t *const pulse_period_hi[2] = { &NR14_REG, &NR24_REG };

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

/* Pick the closest Game Boy noise frequency.  This used to search 16x8
 * candidates with a 32-bit division in the loop, which cost several frames
 * per step on the SM83 and made noise effects run many times too long.  The
 * rate table is precomputed at build time, so the runtime work is a scan. */
static uint8_t noise_period(uint32_t hz)
{
    uint8_t best = 0;
    uint8_t i;
    uint32_t best_diff = 0xFFFFFFFFUL;

    if (hz < 400UL) hz = 400UL;
    if (hz > 200000UL) hz = 200000UL;

    for (i = 0; i < 128; i++) {
        uint32_t f = noise_rate_table[i];
        uint32_t diff = (f > hz) ? (f - hz) : (hz - f);
        if (diff < best_diff) {
            best_diff = diff;
            best = noise_code_table[i];
        }
    }
    return best;
}

/* Stop using the channel this voice currently owns.  Pulse channels belong to
 * exactly one voice; the noise channel can be borrowed by a pulse voice for
 * the noisy steps of a mixed effect (Level Start / Door Open), so it is only
 * released by the voice that last wrote it. */
static void release_voice(uint8_t vi)
{
    SfxVoice *v = &voices[vi];

    if (v->last_type == 2) {
        if (noise_owner == vi) {
            NR42_REG = 0x00;
            NR44_REG = 0x80;
            noise_owner = 0xFF;
        }
    } else if (v->last_type == 1 && vi != VOICE_NOISE) {
        *pulse_vol[vi] = 0x00;
        *pulse_period_hi[vi] = 0x80;
    }
    v->last_type = 0;
}

/* Last step in the pattern that is not a mute entry. */
static uint8_t last_live_step(const SfxDef *def)
{
    uint8_t i = def->count;

    while (i != 0) {
        --i;
        if (sfx_notes[def->note][def->first + i].audc != 0) return i;
    }
    return 0;
}

/* Rough number of player calls left, used to decide which voice to steal. */
static uint16_t def_remaining(const SfxDef *def, uint8_t from)
{
    uint8_t last = last_live_step(def);
    uint8_t rate = def->step_frames ? def->step_frames : 1;

    if (last < from) return 0;
    return (uint16_t)(last - from + 1) * rate;
}

/* True when the effect's first step is a real POKEY noise step, so it can use
 * the dedicated noise voice.  Mixed effects (Level Start, Door Open) start on
 * a pulse voice and borrow the noise channel for their noisy steps. */
static uint8_t voice_is_noise(const SfxDef *def)
{
    return pokey_distortion(sfx_notes[def->note][def->first].audc) == 2;
}

/* Pick a voice, or 0xFF when the new sound should be skipped. */
static uint8_t alloc_voice(const SfxDef *def)
{
    if (voice_is_noise(def)) {
        if (voices[VOICE_NOISE].playing) {
            /* Do not chop a long explosion for a short impact blip. */
            uint16_t have = def_remaining(voices[VOICE_NOISE].def, voices[VOICE_NOISE].step);
            uint16_t want = def_remaining(def, 0);
            if (have > (uint16_t)(want * 2)) return 0xFF;
        }
        return VOICE_NOISE;
    }

    if (!voices[VOICE_PULSE1].playing) return VOICE_PULSE1;
    if (!voices[VOICE_PULSE2].playing) return VOICE_PULSE2;

    {
        uint16_t left0 = def_remaining(voices[VOICE_PULSE1].def, voices[VOICE_PULSE1].step);
        uint16_t left1 = def_remaining(voices[VOICE_PULSE2].def, voices[VOICE_PULSE2].step);

        if (left0 < left1) return VOICE_PULSE1;
        if (left1 < left0) return VOICE_PULSE2;
    }

    return ((int8_t)(voices[VOICE_PULSE1].started - voices[VOICE_PULSE2].started) <= 0)
        ? VOICE_PULSE1 : VOICE_PULSE2;
}

static void apply_step(uint8_t vi, uint8_t index)
{
    SfxVoice *v = &voices[vi];
    const SfxDef *def = v->def;
    const SfxStep *s = &sfx_notes[def->note][def->first + index];
    uint8_t audc = s->audc;
    uint8_t vol = pokey_volume(audc);
    uint8_t dist = pokey_distortion(audc);
    uint32_t hz;

    if (def->gap && (index & 1)) {
        /* Muted step: keeps the timing grid but leaves a gap between bursts. */
        release_voice(vi);
        return;
    }

    if (vol == 0) {
        release_voice(vi);
        return;
    }

    /* POKEY table volumes are conservative; double them (clamped) so the
     * converted effects are audible on real DMG hardware.  Synthesized
     * notes (15..17) keep their authored volume. */
    if (def->note < 15 && vol != 0) {
        vol = (uint8_t)(vol << 1);
        if (vol > 15) vol = 15;
    }

    /* A per-sound master used to change NR50 globally; with several voices
     * that would duck the other effects, so scale this sound's volume instead.
     * The references use 3, which halves it (NR50 3/15 is 4/8 in the mixer). */
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

    if (vi == VOICE_NOISE || dist == 2) {
        uint8_t nr43 = noise_period(hz);
        uint8_t envbits = (uint8_t)(def->env & 0x07);

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
    } else {
        uint16_t period;
        uint8_t duty;

        /* Back on this voice's own pulse channel: release the shared noise
         * channel if this voice was the one using it. */
        if (v->last_type == 2 && noise_owner == vi) {
            NR42_REG = 0x00;
            NR44_REG = 0x80;
            noise_owner = 0xFF;
        }

        if (def->square)   duty = 2; /* forced 50% square */
        else if (dist == 3) duty = 2; /* 50%  - clean square */
        else if (dist == 1) duty = 1; /* 25%  - 4-bit poly buzz */
        else                duty = 0; /* 12.5% - 5-bit poly buzz */

        period = pulse_period(hz);

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
}

static uint8_t only_silence_left(const SfxDef *def, uint8_t from)
{
    uint8_t i;

    for (i = from; i < def->count; i++) {
        if (sfx_notes[def->note][def->first + i].audc != 0) return 0;
    }
    return 1;
}

static void stop_voice(uint8_t vi)
{
    release_voice(vi);
    voices[vi].playing = 0;
    voices[vi].def = 0;
    sfx_voice_mask &= (uint8_t)~(1u << vi);
}

void sound_init(void) BANKED
{
    uint8_t i;

    NR52_REG = 0x80;   /* APU on */
    NR51_REG = 0x9B;   /* pulse 1 + pulse 2 + noise on both outputs */
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
    NR41_REG = 0x00;
    NR42_REG = 0x00;
    NR43_REG = 0x00;
    NR44_REG = 0x00;

    for (i = 0; i < VOICE_COUNT; i++) {
        voices[i].def = 0;
        voices[i].playing = 0;
        voices[i].step = 0;
        voices[i].wait = 0;
        voices[i].last_type = 0;
        voices[i].started = 0;
    }
    start_order = 0;
    noise_owner = 0xFF;
    sfx_voice_mask = 0;
}

void sfx_play_note(uint8_t note) BANKED
{
    static const SfxDef plain = { 0, 0, SFX_STEPS, 256, 5, 0, 0, 0, 0, 0, 0 };
    static SfxDef def;

    if (note >= SFX_NOTE_COUNT) return;
    sfx_stop();  /* the debug note owns every voice */
    def = plain;
    def.note = note;
    sfx_play_def(&def);
}

void sfx_play_def(const SfxDef *def) BANKED
{
    uint8_t vi;

    if (!def || def->count == 0 || def->note >= SFX_NOTE_COUNT) return;
    if ((uint16_t)(def->first + def->count) > SFX_STEPS) return;
    if (def->pitch_q8 == 0) return;

    vi = alloc_voice(def);
    if (vi >= VOICE_COUNT) return;  /* skipped to protect a longer effect */

    {
        SfxVoice *v = &voices[vi];
        release_voice(vi);
        v->def = def;
        v->playing = 1;
        v->step = 0;
        v->wait = 0;
        v->started = ++start_order;
    }
    sfx_voice_mask |= (uint8_t)(1u << vi);

    /* The 6502 engine always starts at the highest-volume table entry. */
    apply_step(vi, 0);
}

void sfx_stop(void) BANKED
{
    uint8_t i;

    for (i = 0; i < VOICE_COUNT; i++) {
        voices[i].playing = 0;
        voices[i].def = 0;
        release_voice(i);
    }
    sfx_voice_mask = 0;
}

void sfx_update(void) BANKED
{
    uint8_t i;

    for (i = 0; i < VOICE_COUNT; i++) {
        SfxVoice *v = &voices[i];
        uint8_t rate;

        if (!v->playing) continue;

        rate = v->def->step_frames;
        if (v->step < v->def->noise_steps && v->def->noise_step_frames != 0) {
            rate = v->def->noise_step_frames;
        }
        if (rate == 0) rate = 1;

        if (++v->wait < rate) continue;
        v->wait = 0;

        v->step++;
        if (v->step >= v->def->count || only_silence_left(v->def, v->step)) {
            stop_voice(i);
            continue;
        }
        apply_step(i, v->step);
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
    return (best == 0xFF) ? 0xFF : voices[best].def->note;
}
