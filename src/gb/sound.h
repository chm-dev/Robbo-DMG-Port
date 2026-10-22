#ifndef SOUND_H
#define SOUND_H

#include <gb/gb.h>
#include <stdint.h>

/*
 * Two kinds of sound live in this player:
 *
 *  1. Pattern effects from sound-port2 (SFX_* below): full 16-step POKEY
 *     patterns played on the original 80 ms grid.  This is the game's main
 *     sound set.
 *  2. Legacy SfxDef effects, kept only for events the new set removed
 *     (explosion, destruct, door open).  They use the earlier mapping.
 *
 * The player mixes three voices (pulse 1, pulse 2, noise) so unrelated
 * effects play together.  Sounds that need the same hardware channel still
 * replace each other.
 */

/* ------------------------------------------------------------------ */
/* Pattern effects (sound-port2)                                      */
/* ------------------------------------------------------------------ */

#define SFX_PATTERN_COUNT 15

#define SFX_SHOT         0x01  /* firing the laser (short bright tick)     */
#define SFX_HIT_WALL     0x02  /* laser hitting a wall (single hiss tick)  */
#define SFX_TELEPORT     0x03  /* teleport / level-entry warp (tone run)   */
#define SFX_BOLT         0x04  /* bolt collected                           */
#define SFX_EXTRA_LIFE   0x05  /* extra life awarded                       */
#define SFX_AMMO         0x07  /* ammo collected (plus 9 shots)            */
#define SFX_PUSH         0x08  /* pushing a block                          */
#define SFX_KEY          0x09  /* key collected                            */
#define SFX_LEVEL_START  0x0B  /* new level fanfare (noise + tone run)     */
#define SFX_LEVEL_END    0x0C  /* exit capsule reached / level complete    */
#define SFX_GAME_OVER    0x0D  /* last bolt collected (overrides SFX_BOLT) */
#define SFX_MAGNET       0x0E  /* magnet hazard death                      */

/* ------------------------------------------------------------------ */
/* Legacy SfxDef effects (retained from the previous sound set)        */
/* ------------------------------------------------------------------ */

/*
 * One playable sound: a window into one of the 15 original POKEY patterns,
 * plus a pitch multiplier and a step rate.  This lets the same hardware table
 * serve several game events (e.g. fire and ammo are two halves of note 7).
 */
typedef struct {
    uint8_t note;        /* POKEY pattern 0..17 (15..17 are synthesized) */
    uint8_t first;       /* first step inside the pattern (0..15) */
    uint8_t count;       /* number of steps to play */
    uint16_t pitch_q8;   /* 256 = original pitch, 128 = one octave down */
    uint8_t step_frames; /* frames per step (original = 5 at 60 Hz) */
    uint8_t force_tone;  /* 1 = render POKEY noise steps as a tone */
    uint16_t tone_hz;    /* frequency used when force_tone is set */
    uint8_t noise_steps; /* first N steps rendered as noise */
    uint8_t noise_step_frames; /* step rate for those noise steps (0 = same) */
    uint16_t noise_pitch_q8;   /* pitch for noise steps (0 = use pitch_q8) */
    uint8_t gap;         /* 1 = mute every other step (noise bursts) */
    uint8_t square;      /* 1 = force 50% duty pulse */
    uint8_t smooth;      /* 1 = update volume without retriggering */
    uint8_t env;         /* 1..7 = hardware volume envelope period, 0 = none */
    uint8_t attack_steps;/* fade-in length in steps (0 = no fade-in) */
    uint8_t attack_env;  /* amplify envelope period for the fade-in */
    uint8_t master;      /* 1..7 = attenuate this sound (3 = half), 0 = full */
} SfxDef;

/* Bit per active voice (0 = pulse 1, 1 = pulse 2, 2 = noise).  Exposed so the
 * emulator tests can assert that effects really overlap. */
extern uint8_t sfx_voice_mask;

/* Reset the APU and select a sane master volume. */
void sound_init(void) BANKED;

/* Play a sound-port2 pattern (SFX_*).  Muted patterns do nothing. */
void sfx_play_note(uint8_t note) BANKED;

/* Start a legacy SfxDef sound (retained effects only). */
void sfx_play_def(const SfxDef *def) BANKED;

/* Silence all effect channels immediately. */
void sfx_stop(void) BANKED;

/* Advance the player; call once per frame (60 Hz). */
void sfx_update(void) BANKED;

/* 1 while any voice is running. */
uint8_t sfx_is_playing(void) BANKED;

/* Pattern index / note of the most recently started voice, or 0xFF. */
uint8_t sfx_current(void) BANKED;

#endif
