#ifndef SOUND_H
#define SOUND_H

#include <gb/gb.h>
#include <stdint.h>

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

/*
 * The player runs three voices: pulse 1, pulse 2 and noise.  Tone effects
 * take a free pulse voice and can play together; noise effects (fire, impact,
 * explosion, destroy) share the noise channel.  A new sound only cuts off
 * another sound that needs the same channel.
 */

/* Bit per active voice (0 = pulse 1, 1 = pulse 2, 2 = noise).  Exposed so the
 * emulator tests can assert that effects really overlap. */
extern uint8_t sfx_voice_mask;

/* Reset the APU and select a sane master volume. */
void sound_init(void) BANKED;

/* Start a sound.  Takes a free voice; only sounds that need the same
 * channel cut each other off. */
void sfx_play_def(const SfxDef *def) BANKED;

/* Play a whole POKEY pattern at its original pitch/speed. */
void sfx_play_note(uint8_t note) BANKED;

/* Silence the effect channels immediately. */
void sfx_stop(void) BANKED;

/* Advance the player; call once per frame (60 Hz). */
void sfx_update(void) BANKED;

/* 1 while a pattern is still running. */
uint8_t sfx_is_playing(void) BANKED;

/* POKEY note index of the most recently started voice, or 0xFF. */
uint8_t sfx_current(void) BANKED;

#endif

