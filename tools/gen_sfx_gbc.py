#!/usr/bin/env python3
"""Generate the GBC-derived step tables used by the DMG sound player.

The GBC port (robbo-gbc) converts the original Atari POKEY effects to native
GBC APU steps.  This script reuses that conversion for the two effects the DMG
port renders with the GBC data:

  * door open (POKEY note 6): CH3 poly4 waves + CH4 noise accents
  * level start (POKEY note 11): noise sweep + square tone
  * last bolt / capsule open (POKEY note 13): gated-noise fade

Input is the existing generated POKEY table in gb/src/gb/sfx_data.c.  It is
already in playback order (volume 16 -> 1), so unlike the GBC converter we must
NOT reverse it again.

Output: gb/src/gb/sfx_gbc_data.c/.h (bank 9).  Do not edit those by hand.
"""
import math
import os
import re

PAL_CLOCK = 1773447
DIVIDER = 28
SQUARE = 0x00
WAVE = 0x40
NOISE = 0x80

# POKEY's polynomial output sequence, clocked at the master clock.
POLY4 = (1, 1, 1, 1, 0, 0, 0, 1, 0, 0, 1, 1, 0, 1, 0)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "gb", "src", "gb", "sfx_data.c")
OUT_DIR = os.path.join(ROOT, "gb", "src", "gb")


def parse_notes(path):
    text = open(path, encoding="utf-8").read()
    blocks = re.findall(r"\{ /\* note (\d+)[^*]*\*/(.*?)\n  \},", text, re.S)
    notes = {}
    for number, body in blocks:
        steps = [
            (int(audc, 16), int(audf, 16))
            for audc, audf in re.findall(
                r"\{ 0x([0-9A-Fa-f]{2}), 0x([0-9A-Fa-f]{2}) \}", body
            )
        ]
        if len(steps) == 16:
            notes[int(number)] = steps
    return notes


def gb_period(hz, wave=False):
    clock = 65536 if wave else 131072
    ideal = 2048 - clock / hz
    candidates = {
        max(0, min(2047, int(x))) for x in (math.floor(ideal), math.ceil(ideal))
    }
    return min(
        candidates,
        key=lambda x: abs(math.log2((clock / (2048 - x)) / hz)),
    )


def gb_square_freq(audf):
    return gb_period(PAL_CLOCK / (2 * DIVIDER * (audf + 1)))


def noise_rate(poly):
    divisor = (8, 16, 32, 48, 64, 80, 96, 112)[poly & 7]
    return 4194304 / (divisor << (poly >> 4))


def gb_noise_poly(audf, gated=False):
    rate = PAL_CLOCK / (DIVIDER * (audf + 1))
    if gated:
        # 15 of poly5's 31 states permit a new output bit; approximate the
        # resulting held noise's bandwidth rather than treating it as $8.
        rate *= 15 / 31
    return min(
        (shift << 4 | ratio for shift in range(14) for ratio in range(8)),
        key=lambda p: abs(math.log2(noise_rate(p) / rate)),
    )


def poly4_pattern(audf):
    stride = DIVIDER * (audf + 1)
    length = 15 // math.gcd(stride, 15)
    return tuple(POLY4[(i * stride) % 15] for i in range(length))


def wave_bytes(bits, volume):
    """Area-average one polynomial period into 32 four-bit wave samples."""
    n = len(bits)
    samples = []
    for i in range(32):
        start, end = i * n / 32, (i + 1) * n / 32
        area = sum(
            bits[j % n] * max(0, min(end, j + 1) - max(start, j))
            for j in range(math.floor(start), math.ceil(end))
        )
        samples.append(max(0, min(15, round(volume * area * 32 / n))))
    return tuple((samples[i] << 4) | samples[i + 1] for i in range(0, 32, 2))


def step_bytes(word, waves):
    """Convert one (AUDC, AUDF) pair to the GBC step byte layout."""
    audf, audc = word >> 8, word & 255
    volume, distortion = audc & 15, audc & 0xF0
    if not volume:
        return (0, 0, 0, 0)
    if distortion == 0xA0:
        period = gb_square_freq(audf)
        return (SQUARE | volume, period & 255, period >> 8, 0)
    if distortion == 0xC0:
        bits = poly4_pattern(audf)
        if len(set(bits)) == 1:
            # The divider repeatedly samples one poly4 bit: DC, not audio.
            return (0, 0, 0, 0)
        hz = PAL_CLOCK / (DIVIDER * (audf + 1) * len(bits))
        period = gb_period(hz, wave=True)
        wave = wave_bytes(bits, volume)
        if wave not in waves:
            waves.append(wave)
        return (WAVE | volume, period & 255, period >> 8, waves.index(wave))
    if distortion in (0x00, 0x80):
        return (NOISE | volume, gb_noise_poly(audf, distortion == 0), 0, 0)
    raise ValueError(f"unsupported Robbo AUDC ${audc:02X}")


def convert_note(notes, number, waves):
    if number not in notes:
        raise ValueError(f"note {number} not found in {SRC}")
    # sfx_data.c is already in play order: do not reverse.
    return [
        step_bytes((audf << 8) | audc, waves)
        for audc, audf in notes[number]
    ]


def format_steps(name, steps):
    rows = []
    for step in steps:
        rows.append("    {" + ", ".join(f"0x{byte:02X}" for byte in step) + "},")
    return (
        f"const unsigned char {name}[SFX_GBC_STEPS][4] = {{\n"
        + "\n".join(rows)
        + "\n};\n"
    )


def format_waves(name, waves):
    rows = []
    for wave in waves:
        rows.append("    {" + ", ".join(f"0x{byte:02X}" for byte in wave) + "},")
    return (
        f"const unsigned char {name}[SFX_GBC_WAVE_COUNT][16] = {{\n"
        + "\n".join(rows)
        + "\n};\n"
    )


def main():
    notes = parse_notes(SRC)
    waves = []
    door = convert_note(notes, 6, waves)
    level_start = convert_note(notes, 11, waves)
    last_bolt = convert_note(notes, 13, waves)

    header = """/* Generated by tools/gen_sfx_gbc.py - do not edit by hand.
 *
 * Source: the POKEY note table in gb/src/gb/sfx_data.c, converted with the
 * same algorithm as robbo-gbc/tools/convert_sound.py.  The step layout is:
 *   {kind | original volume, period/NR43, period high, wave id}
 * Silence is volume zero.  Kind is 0 (square), 0x40 (wave) or 0x80 (noise).
 */
#ifndef SFX_GBC_DATA_H
#define SFX_GBC_DATA_H

#define SFX_GBC_STEPS 16
#define SFX_GBC_WAVE_COUNT %d

extern const unsigned char sfx_door_steps[SFX_GBC_STEPS][4];
extern const unsigned char sfx_door_waves[SFX_GBC_WAVE_COUNT][16];
extern const unsigned char sfx_level_start_steps[SFX_GBC_STEPS][4];
extern const unsigned char sfx_last_bolt_steps[SFX_GBC_STEPS][4];

#endif
""" % len(waves)

    source = """/* Generated by tools/gen_sfx_gbc.py - do not edit by hand. */
#pragma bank 9

#include "sfx_gbc_data.h"

"""
    source += format_steps("sfx_door_steps", door)
    source += "\n"
    source += format_waves("sfx_door_waves", waves)
    source += "\n"
    source += format_steps("sfx_level_start_steps", level_start)
    source += "\n"
    source += format_steps("sfx_last_bolt_steps", last_bolt)

    os.makedirs(OUT_DIR, exist_ok=True)
    with open(os.path.join(OUT_DIR, "sfx_gbc_data.h"), "w", encoding="utf-8") as f:
        f.write(header)
    with open(os.path.join(OUT_DIR, "sfx_gbc_data.c"), "w", encoding="utf-8") as f:
        f.write(source)

    print(
        "generated door (11 audible steps, %d waves), level start "
        "(12 audible steps), and last bolt (16 noise steps) in %s"
        % (len(waves), OUT_DIR)
    )


if __name__ == "__main__":
    main()
