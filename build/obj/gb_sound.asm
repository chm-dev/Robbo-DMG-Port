;--------------------------------------------------------
; File Created by SDCC : free open source ISO C Compiler
; Version 4.5.1 #15267 (MINGW64)
;--------------------------------------------------------
	.module sound
	
;--------------------------------------------------------
; Public variables in this module
;--------------------------------------------------------
	.globl _sfx_voice_mask
	.globl b_sound_init
	.globl _sound_init
	.globl b_sfx_play_note
	.globl _sfx_play_note
	.globl b_sfx_play_def
	.globl _sfx_play_def
	.globl b_sfx_stop
	.globl _sfx_stop
	.globl b_sfx_update
	.globl _sfx_update
	.globl b_sfx_is_playing
	.globl _sfx_is_playing
	.globl b_sfx_current
	.globl _sfx_current
;--------------------------------------------------------
; special function registers
;--------------------------------------------------------
	.area _HRAM
;--------------------------------------------------------
; ram data
;--------------------------------------------------------
	.area _DATA
_voices:
	.ds 39
_start_order:
	.ds 1
_noise_owner:
	.ds 1
_sfx_voice_mask::
	.ds 1
;--------------------------------------------------------
; ram data
;--------------------------------------------------------
	.area _INITIALIZED
;--------------------------------------------------------
; absolute external ram data
;--------------------------------------------------------
	.area _DABS (ABS)
;--------------------------------------------------------
; global & static initialisations
;--------------------------------------------------------
	.area _HOME
	.area _GSINIT
	.area _GSFINAL
	.area _GSINIT
;--------------------------------------------------------
; Home
;--------------------------------------------------------
	.area _HOME
	.area _HOME
;--------------------------------------------------------
; code
;--------------------------------------------------------
	.area _CODE_9
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:96: static uint8_t pokey_volume(uint8_t audc)
;	---------------------------------
; Function pokey_volume
; ---------------------------------
_pokey_volume:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:98: return audc & 0x0F;
	and	a, #0x0f
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:99: }
	ret
_noise_rate_table:
	.byte #0x00, #0x00, #0x08, #0x00	; 524288
	.byte #0x00, #0x00, #0x04, #0x00	; 262144
	.byte #0x00, #0x00, #0x02, #0x00	; 131072
	.byte #0x55, #0x55, #0x01, #0x00	; 87381
	.byte #0x00, #0x00, #0x01, #0x00	; 65536
	.byte #0xcc, #0xcc, #0x00, #0x00	; 52428
	.byte #0xaa, #0xaa, #0x00, #0x00	; 43690
	.byte #0x49, #0x92, #0x00, #0x00	; 37449
	.byte #0x00, #0x00, #0x04, #0x00	; 262144
	.byte #0x00, #0x00, #0x02, #0x00	; 131072
	.byte #0x00, #0x00, #0x01, #0x00	; 65536
	.byte #0xaa, #0xaa, #0x00, #0x00	; 43690
	.byte #0x00, #0x80, #0x00, #0x00	; 32768
	.byte #0x66, #0x66, #0x00, #0x00	; 26214
	.byte #0x55, #0x55, #0x00, #0x00	; 21845
	.byte #0x24, #0x49, #0x00, #0x00	; 18724
	.byte #0x00, #0x00, #0x02, #0x00	; 131072
	.byte #0x00, #0x00, #0x01, #0x00	; 65536
	.byte #0x00, #0x80, #0x00, #0x00	; 32768
	.byte #0x55, #0x55, #0x00, #0x00	; 21845
	.byte #0x00, #0x40, #0x00, #0x00	; 16384
	.byte #0x33, #0x33, #0x00, #0x00	; 13107
	.byte #0xaa, #0x2a, #0x00, #0x00	; 10922
	.byte #0x92, #0x24, #0x00, #0x00	; 9362
	.byte #0x00, #0x00, #0x01, #0x00	; 65536
	.byte #0x00, #0x80, #0x00, #0x00	; 32768
	.byte #0x00, #0x40, #0x00, #0x00	; 16384
	.byte #0xaa, #0x2a, #0x00, #0x00	; 10922
	.byte #0x00, #0x20, #0x00, #0x00	; 8192
	.byte #0x99, #0x19, #0x00, #0x00	; 6553
	.byte #0x55, #0x15, #0x00, #0x00	; 5461
	.byte #0x49, #0x12, #0x00, #0x00	; 4681
	.byte #0x00, #0x80, #0x00, #0x00	; 32768
	.byte #0x00, #0x40, #0x00, #0x00	; 16384
	.byte #0x00, #0x20, #0x00, #0x00	; 8192
	.byte #0x55, #0x15, #0x00, #0x00	; 5461
	.byte #0x00, #0x10, #0x00, #0x00	; 4096
	.byte #0xcc, #0x0c, #0x00, #0x00	; 3276
	.byte #0xaa, #0x0a, #0x00, #0x00	; 2730
	.byte #0x24, #0x09, #0x00, #0x00	; 2340
	.byte #0x00, #0x40, #0x00, #0x00	; 16384
	.byte #0x00, #0x20, #0x00, #0x00	; 8192
	.byte #0x00, #0x10, #0x00, #0x00	; 4096
	.byte #0xaa, #0x0a, #0x00, #0x00	; 2730
	.byte #0x00, #0x08, #0x00, #0x00	; 2048
	.byte #0x66, #0x06, #0x00, #0x00	; 1638
	.byte #0x55, #0x05, #0x00, #0x00	; 1365
	.byte #0x92, #0x04, #0x00, #0x00	; 1170
	.byte #0x00, #0x20, #0x00, #0x00	; 8192
	.byte #0x00, #0x10, #0x00, #0x00	; 4096
	.byte #0x00, #0x08, #0x00, #0x00	; 2048
	.byte #0x55, #0x05, #0x00, #0x00	; 1365
	.byte #0x00, #0x04, #0x00, #0x00	; 1024
	.byte #0x33, #0x03, #0x00, #0x00	; 819
	.byte #0xaa, #0x02, #0x00, #0x00	; 682
	.byte #0x49, #0x02, #0x00, #0x00	; 585
	.byte #0x00, #0x10, #0x00, #0x00	; 4096
	.byte #0x00, #0x08, #0x00, #0x00	; 2048
	.byte #0x00, #0x04, #0x00, #0x00	; 1024
	.byte #0xaa, #0x02, #0x00, #0x00	; 682
	.byte #0x00, #0x02, #0x00, #0x00	; 512
	.byte #0x99, #0x01, #0x00, #0x00	; 409
	.byte #0x55, #0x01, #0x00, #0x00	; 341
	.byte #0x24, #0x01, #0x00, #0x00	; 292
	.byte #0x00, #0x08, #0x00, #0x00	; 2048
	.byte #0x00, #0x04, #0x00, #0x00	; 1024
	.byte #0x00, #0x02, #0x00, #0x00	; 512
	.byte #0x55, #0x01, #0x00, #0x00	; 341
	.byte #0x00, #0x01, #0x00, #0x00	; 256
	.byte #0xcc, #0x00, #0x00, #0x00	; 204
	.byte #0xaa, #0x00, #0x00, #0x00	; 170
	.byte #0x92, #0x00, #0x00, #0x00	; 146
	.byte #0x00, #0x04, #0x00, #0x00	; 1024
	.byte #0x00, #0x02, #0x00, #0x00	; 512
	.byte #0x00, #0x01, #0x00, #0x00	; 256
	.byte #0xaa, #0x00, #0x00, #0x00	; 170
	.byte #0x80, #0x00, #0x00, #0x00	; 128
	.byte #0x66, #0x00, #0x00, #0x00	; 102
	.byte #0x55, #0x00, #0x00, #0x00	; 85
	.byte #0x49, #0x00, #0x00, #0x00	; 73
	.byte #0x00, #0x02, #0x00, #0x00	; 512
	.byte #0x00, #0x01, #0x00, #0x00	; 256
	.byte #0x80, #0x00, #0x00, #0x00	; 128
	.byte #0x55, #0x00, #0x00, #0x00	; 85
	.byte #0x40, #0x00, #0x00, #0x00	; 64
	.byte #0x33, #0x00, #0x00, #0x00	; 51
	.byte #0x2a, #0x00, #0x00, #0x00	; 42
	.byte #0x24, #0x00, #0x00, #0x00	; 36
	.byte #0x00, #0x01, #0x00, #0x00	; 256
	.byte #0x80, #0x00, #0x00, #0x00	; 128
	.byte #0x40, #0x00, #0x00, #0x00	; 64
	.byte #0x2a, #0x00, #0x00, #0x00	; 42
	.byte #0x20, #0x00, #0x00, #0x00	; 32
	.byte #0x19, #0x00, #0x00, #0x00	; 25
	.byte #0x15, #0x00, #0x00, #0x00	; 21
	.byte #0x12, #0x00, #0x00, #0x00	; 18
	.byte #0x80, #0x00, #0x00, #0x00	; 128
	.byte #0x40, #0x00, #0x00, #0x00	; 64
	.byte #0x20, #0x00, #0x00, #0x00	; 32
	.byte #0x15, #0x00, #0x00, #0x00	; 21
	.byte #0x10, #0x00, #0x00, #0x00	; 16
	.byte #0x0c, #0x00, #0x00, #0x00	; 12
	.byte #0x0a, #0x00, #0x00, #0x00	; 10
	.byte #0x09, #0x00, #0x00, #0x00	; 9
	.byte #0x40, #0x00, #0x00, #0x00	; 64
	.byte #0x20, #0x00, #0x00, #0x00	; 32
	.byte #0x10, #0x00, #0x00, #0x00	; 16
	.byte #0x0a, #0x00, #0x00, #0x00	; 10
	.byte #0x08, #0x00, #0x00, #0x00	; 8
	.byte #0x06, #0x00, #0x00, #0x00	; 6
	.byte #0x05, #0x00, #0x00, #0x00	; 5
	.byte #0x04, #0x00, #0x00, #0x00	; 4
	.byte #0x20, #0x00, #0x00, #0x00	; 32
	.byte #0x10, #0x00, #0x00, #0x00	; 16
	.byte #0x08, #0x00, #0x00, #0x00	; 8
	.byte #0x05, #0x00, #0x00, #0x00	; 5
	.byte #0x04, #0x00, #0x00, #0x00	; 4
	.byte #0x03, #0x00, #0x00, #0x00	; 3
	.byte #0x02, #0x00, #0x00, #0x00	; 2
	.byte #0x02, #0x00, #0x00, #0x00	; 2
	.byte #0x10, #0x00, #0x00, #0x00	; 16
	.byte #0x08, #0x00, #0x00, #0x00	; 8
	.byte #0x04, #0x00, #0x00, #0x00	; 4
	.byte #0x02, #0x00, #0x00, #0x00	; 2
	.byte #0x02, #0x00, #0x00, #0x00	; 2
	.byte #0x01, #0x00, #0x00, #0x00	; 1
	.byte #0x01, #0x00, #0x00, #0x00	; 1
	.byte #0x01, #0x00, #0x00, #0x00	; 1
_noise_code_table:
	.db #0x00	; 0
	.db #0x01	; 1
	.db #0x02	; 2
	.db #0x03	; 3
	.db #0x04	; 4
	.db #0x05	; 5
	.db #0x06	; 6
	.db #0x07	; 7
	.db #0x10	; 16
	.db #0x11	; 17
	.db #0x12	; 18
	.db #0x13	; 19
	.db #0x14	; 20
	.db #0x15	; 21
	.db #0x16	; 22
	.db #0x17	; 23
	.db #0x20	; 32
	.db #0x21	; 33
	.db #0x22	; 34
	.db #0x23	; 35
	.db #0x24	; 36
	.db #0x25	; 37
	.db #0x26	; 38
	.db #0x27	; 39
	.db #0x30	; 48	'0'
	.db #0x31	; 49	'1'
	.db #0x32	; 50	'2'
	.db #0x33	; 51	'3'
	.db #0x34	; 52	'4'
	.db #0x35	; 53	'5'
	.db #0x36	; 54	'6'
	.db #0x37	; 55	'7'
	.db #0x40	; 64
	.db #0x41	; 65	'A'
	.db #0x42	; 66	'B'
	.db #0x43	; 67	'C'
	.db #0x44	; 68	'D'
	.db #0x45	; 69	'E'
	.db #0x46	; 70	'F'
	.db #0x47	; 71	'G'
	.db #0x50	; 80	'P'
	.db #0x51	; 81	'Q'
	.db #0x52	; 82	'R'
	.db #0x53	; 83	'S'
	.db #0x54	; 84	'T'
	.db #0x55	; 85	'U'
	.db #0x56	; 86	'V'
	.db #0x57	; 87	'W'
	.db #0x60	; 96
	.db #0x61	; 97	'a'
	.db #0x62	; 98	'b'
	.db #0x63	; 99	'c'
	.db #0x64	; 100	'd'
	.db #0x65	; 101	'e'
	.db #0x66	; 102	'f'
	.db #0x67	; 103	'g'
	.db #0x70	; 112	'p'
	.db #0x71	; 113	'q'
	.db #0x72	; 114	'r'
	.db #0x73	; 115	's'
	.db #0x74	; 116	't'
	.db #0x75	; 117	'u'
	.db #0x76	; 118	'v'
	.db #0x77	; 119	'w'
	.db #0x80	; 128
	.db #0x81	; 129
	.db #0x82	; 130
	.db #0x83	; 131
	.db #0x84	; 132
	.db #0x85	; 133
	.db #0x86	; 134
	.db #0x87	; 135
	.db #0x90	; 144
	.db #0x91	; 145
	.db #0x92	; 146
	.db #0x93	; 147
	.db #0x94	; 148
	.db #0x95	; 149
	.db #0x96	; 150
	.db #0x97	; 151
	.db #0xa0	; 160
	.db #0xa1	; 161
	.db #0xa2	; 162
	.db #0xa3	; 163
	.db #0xa4	; 164
	.db #0xa5	; 165
	.db #0xa6	; 166
	.db #0xa7	; 167
	.db #0xb0	; 176
	.db #0xb1	; 177
	.db #0xb2	; 178
	.db #0xb3	; 179
	.db #0xb4	; 180
	.db #0xb5	; 181
	.db #0xb6	; 182
	.db #0xb7	; 183
	.db #0xc0	; 192
	.db #0xc1	; 193
	.db #0xc2	; 194
	.db #0xc3	; 195
	.db #0xc4	; 196
	.db #0xc5	; 197
	.db #0xc6	; 198
	.db #0xc7	; 199
	.db #0xd0	; 208
	.db #0xd1	; 209
	.db #0xd2	; 210
	.db #0xd3	; 211
	.db #0xd4	; 212
	.db #0xd5	; 213
	.db #0xd6	; 214
	.db #0xd7	; 215
	.db #0xe0	; 224
	.db #0xe1	; 225
	.db #0xe2	; 226
	.db #0xe3	; 227
	.db #0xe4	; 228
	.db #0xe5	; 229
	.db #0xe6	; 230
	.db #0xe7	; 231
	.db #0xf0	; 240
	.db #0xf1	; 241
	.db #0xf2	; 242
	.db #0xf3	; 243
	.db #0xf4	; 244
	.db #0xf5	; 245
	.db #0xf6	; 246
	.db #0xf7	; 247
_pulse_duty:
	.dw _NR11_REG
	.dw _NR21_REG
_pulse_vol:
	.dw _NR12_REG
	.dw _NR22_REG
_pulse_period_lo:
	.dw _NR13_REG
	.dw _NR23_REG
_pulse_period_hi:
	.dw _NR14_REG
	.dw _NR24_REG
_pattern_muted:
	.db #0x01	; 1
	.db #0x00	; 0
	.db #0x00	; 0
	.db #0x00	; 0
	.db #0x00	; 0
	.db #0x00	; 0
	.db #0x01	; 1
	.db #0x00	; 0
	.db #0x00	; 0
	.db #0x00	; 0
	.db #0x01	; 1
	.db #0x00	; 0
	.db #0x00	; 0
	.db #0x00	; 0
	.db #0x00	; 0
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:101: static uint8_t pokey_distortion(uint8_t audc)
;	---------------------------------
; Function pokey_distortion
; ---------------------------------
_pokey_distortion:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:103: return (audc >> 5) & 0x03;
	swap	a
	rrca
	and	a, #0x3
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:104: }
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:107: static uint32_t pokey_rate(uint8_t audc, uint8_t audf)
;	---------------------------------
; Function pokey_rate
; ---------------------------------
_pokey_rate:
	add	sp, #-13
	ldhl	sp,	#12
	ld	(hl), a
	ld	a, e
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:109: uint32_t clock = (audc & 0x80) ? POKEY_CLOCK_179M : POKEY_CLOCK_64K;
	push	hl
	bit	7, (hl)
	pop	hl
	jr	Z, 00108$
	ld	bc, #0x4f4d
	ld	de, #0x001b
	jr	00109$
00108$:
	ld	bc, #0xf9b1
	ld	de, #0x0000
00109$:
	ldhl	sp,	#4
	ld	(hl), c
	inc	hl
	ld	(hl), b
	inc	hl
	ld	(hl), e
	inc	hl
	ld	(hl), d
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:110: uint32_t div = (uint32_t)audf + 1UL;
	ldhl	sp,	#0
	ld	(hl+), a
	xor	a, a
	ld	(hl+), a
	ld	(hl+), a
	ld	(hl), a
	pop	de
	push	de
	ld	a, e
	add	a, #0x01
	ld	e, a
	ld	a, d
	adc	a, #0x00
	push	af
	ldhl	sp,	#11
	ld	(hl-), a
	ld	(hl), e
	ldhl	sp,#4
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	pop	af
	ld	a, e
	adc	a, #0x00
	ld	e, a
	ld	a, d
	adc	a, #0x00
	ldhl	sp,	#11
	ld	(hl-), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:111: uint8_t dist = pokey_distortion(audc);
	ld	a, e
	ld	(hl+), a
	inc	hl
	ld	a, (hl)
	call	_pokey_distortion
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:113: switch (dist) {
	ldhl	sp,#3
	ld	(hl), a
	or	a, a
	jr	Z, 00101$
	ldhl	sp,	#3
	ld	a, (hl)
	dec	a
	jr	Z, 00102$
	ldhl	sp,	#3
	ld	a, (hl)
	sub	a, #0x02
	jr	Z, 00103$
	jp	00104$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:114: case 0:  /* 5-bit polynomial counter (period 31) */
00101$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:115: return clock / (div * 31UL);
	ldhl	sp,	#8
	ld	a, (hl+)
	ld	c, a
	ld	b, (hl)
	ld	l, c
	ld	h, b
	add	hl, hl
	add	hl, bc
	add	hl, hl
	add	hl, bc
	add	hl, hl
	add	hl, bc
	add	hl, hl
	add	hl, bc
	ld	bc, #0x0000
	push	bc
	push	hl
	ldhl	sp,	#8
	ld	a, (hl+)
	ld	c, a
	ld	a, (hl+)
	ld	b, a
	ld	e, (hl)
	ld	d, #0x00
	call	__divulong
	jp	00106$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:116: case 1:  /* 4-bit polynomial counter (period 15) */
00102$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:117: return clock / (div * 15UL);
	ldhl	sp,	#8
	ld	a, (hl+)
	inc	hl
	ld	(hl-), a
	ld	a, (hl+)
	inc	hl
	ld	(hl-), a
	ld	a, (hl+)
	ld	c, a
	ld	b, (hl)
	ld	l, c
	ld	h, b
	add	hl, hl
	add	hl, bc
	add	hl, hl
	add	hl, bc
	add	hl, hl
	add	hl, bc
	push	hl
	ld	a, l
	ldhl	sp,	#12
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#11
	ld	(hl-), a
	ld	a, (hl-)
	dec	hl
	ld	(hl), a
	ldhl	sp,	#11
	ld	a, (hl-)
	dec	hl
	ld	(hl+), a
	xor	a, a
	ld	(hl+), a
	ld	(hl), a
	ld	de, #0x0
	push	de
	ldhl	sp,	#10
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	push	de
	ldhl	sp,	#8
	ld	a, (hl+)
	ld	c, a
	ld	a, (hl+)
	ld	b, a
	ld	e, (hl)
	ld	d, #0x00
	call	__divulong
	ldhl	sp,	#8
	ld	(hl), c
	inc	hl
	ld	(hl), b
	inc	hl
	ld	(hl), e
	inc	hl
	ld	(hl), d
	ldhl	sp,	#8
	ld	c, (hl)
	inc	hl
	ld	b, (hl)
	inc	hl
	ld	e, (hl)
	inc	hl
	ld	d, (hl)
	jr	00106$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:118: case 2:  /* 5-bit + 4-bit poly = noise; AUDF sets the LFSR clock */
00103$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:119: return clock / div;
	ld	de, #0x0
	push	de
	ldhl	sp,	#10
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	push	de
	ldhl	sp,	#8
	ld	a, (hl+)
	ld	c, a
	ld	a, (hl+)
	ld	b, a
	ld	e, (hl)
	ld	d, #0x00
	call	__divulong
	jr	00106$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:120: default: /* 17-bit poly = square wave */
00104$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:121: return clock / (2UL * div);
	ldhl	sp,	#8
	ld	a, (hl+)
	ld	b, (hl)
	ld	de, #0x0
	add	a, a
	rl	b
	rl	e
	rl	d
	push	de
	ld	c, a
	push	bc
	ldhl	sp,	#8
	ld	a, (hl+)
	ld	c, a
	ld	a, (hl+)
	ld	b, a
	ld	e, (hl)
	ld	d, #0x00
	call	__divulong
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:122: }
00106$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:123: }
	add	sp, #13
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:126: static uint16_t pulse_period(uint32_t hz)
;	---------------------------------
; Function pulse_period
; ---------------------------------
_pulse_period:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:130: if (hz < 64UL) hz = 64UL;
	ld	a, c
	sub	a, #0x40
	ld	a, b
	sbc	a, #0x00
	ld	a, e
	sbc	a, #0x00
	ld	a, d
	sbc	a, #0x00
	jr	NC, 00102$
	ld	bc, #0x0040
	ld	de, #0x0000
00102$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:131: if (hz > 131072UL) hz = 131072UL;
	xor	a, a
	cp	a, c
	sbc	a, b
	ld	a, #0x02
	sbc	a, e
	ld	a, #0x00
	sbc	a, d
	jr	NC, 00104$
	ld	bc, #0x0000
	ld	de, #0x0002
00104$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:132: period = 2048UL - (131072UL / hz);
	push	de
	push	bc
	ld	bc, #0x0000
	ld	de, #0x0002
	call	__divulong
	xor	a, a
	sub	a, c
	ld	c, a
	ld	a, #0x08
	sbc	a, b
	ld	b, a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:133: if (period > 2047UL) period = 2047UL;
	ld	a, #0xff
	cp	a, c
	ld	a, #0x07
	sbc	a, b
	ret	NC
	ld	bc, #0x07ff
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:134: return (uint16_t)period;
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:135: }
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:139: static uint8_t noise_period(uint32_t hz)
;	---------------------------------
; Function noise_period
; ---------------------------------
_noise_period:
	add	sp, #-18
	ldhl	sp,	#13
	ld	a, c
	ld	(hl+), a
	ld	a, b
	ld	(hl+), a
	ld	a, e
	ld	(hl+), a
	ld	(hl), d
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:141: uint8_t best = 0;
	ldhl	sp,	#0
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:143: uint32_t best_diff = 0xFFFFFFFFUL;
	xor	a, a
	ld	(hl+), a
	ld	a,#0xff
	ld	(hl+),a
	ld	(hl+), a
	ld	a, #0xff
	ld	(hl+), a
	ld	(hl), #0xff
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:145: if (hz < 400UL) hz = 400UL;
	ldhl	sp,	#13
	ld	a, (hl+)
	sub	a, #0x90
	ld	a, (hl+)
	sbc	a, #0x01
	ld	a, (hl+)
	sbc	a, #0x00
	ld	a, (hl)
	sbc	a, #0x00
	jr	NC, 00102$
	ldhl	sp,	#13
	ld	a, #0x90
	ld	(hl+), a
	ld	a, #0x01
	ld	(hl+), a
	xor	a, a
	ld	(hl+), a
	ld	(hl), a
00102$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:146: if (hz > 200000UL) hz = 200000UL;
	ldhl	sp,	#13
	ld	a, #0x40
	sub	a, (hl)
	inc	hl
	ld	a, #0x0d
	sbc	a, (hl)
	inc	hl
	ld	a, #0x03
	sbc	a, (hl)
	inc	hl
	ld	a, #0x00
	sbc	a, (hl)
	jr	NC, 00118$
	ldhl	sp,	#13
	ld	a, #0x40
	ld	(hl+), a
	ld	a, #0x0d
	ld	(hl+), a
	ld	a, #0x03
	ld	(hl+), a
	xor	a, a
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:148: for (i = 0; i < 128; i++) {
00118$:
	ldhl	sp,	#17
	ld	(hl), #0x00
00108$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:149: uint32_t f = noise_rate_table[i];
	ldhl	sp,	#17
	ld	c, (hl)
	xor	a, a
	ld	l, c
	ld	h, a
	add	hl, hl
	add	hl, hl
	ld	de, #_noise_rate_table
	add	hl, de
	ld	e, l
	ld	d, h
	ld	a, (de)
	ldhl	sp,	#5
	ld	(hl+), a
	inc	de
	ld	a, (de)
	ld	(hl+), a
	inc	de
	ld	a, (de)
	ld	(hl+), a
	inc	de
	ld	a, (de)
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:150: uint32_t diff = (f > hz) ? (f - hz) : (hz - f);
	ldhl	sp,	#13
	ld	e, l
	ld	d, h
	ldhl	sp,	#5
	ld	a, (de)
	inc	de
	sub	a, (hl)
	inc	hl
	ld	a, (de)
	inc	de
	sbc	a, (hl)
	inc	hl
	ld	a, (de)
	inc	de
	sbc	a, (hl)
	inc	hl
	ld	a, (de)
	sbc	a, (hl)
	jr	NC, 00112$
	ldhl	sp,#5
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, e
	ldhl	sp,	#13
	sub	a, (hl)
	inc	hl
	ld	e, a
	ld	a, d
	sbc	a, (hl)
	push	af
	ldhl	sp,	#12
	ld	(hl-), a
	ld	a, e
	ld	(hl-), a
	dec	hl
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ldhl	sp,	#17
	pop	af
	ld	a, e
	sbc	a, (hl)
	inc	hl
	ld	e, a
	ld	a, d
	sbc	a, (hl)
	ldhl	sp,	#12
	ld	(hl-), a
	ld	(hl), e
	jr	00113$
00112$:
	ldhl	sp,#13
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, e
	ldhl	sp,	#5
	sub	a, (hl)
	inc	hl
	ld	e, a
	ld	a, d
	sbc	a, (hl)
	push	af
	ldhl	sp,	#12
	ld	(hl-), a
	ld	(hl), e
	ldhl	sp,#17
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ldhl	sp,	#9
	pop	af
	ld	a, e
	sbc	a, (hl)
	inc	hl
	ld	e, a
	ld	a, d
	sbc	a, (hl)
	ldhl	sp,	#12
	ld	(hl-), a
	ld	(hl), e
00113$:
	ldhl	sp,	#9
	ld	a, (hl+)
	ld	c, a
	ld	a, (hl+)
	ld	b, a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:151: if (diff < best_diff) {
	ldhl	sp,	#1
	ld	a, c
	sub	a, (hl)
	inc	hl
	ld	a, b
	sbc	a, (hl)
	inc	hl
	ld	a, e
	sbc	a, (hl)
	inc	hl
	ld	a, d
	sbc	a, (hl)
	jr	NC, 00109$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:152: best_diff = diff;
	ldhl	sp,	#1
	ld	a, c
	ld	(hl+), a
	ld	a, b
	ld	(hl+), a
	ld	a, e
	ld	(hl+), a
	ld	(hl), d
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:153: best = noise_code_table[i];
	ld	de, #_noise_code_table
	ldhl	sp,	#17
	ld	l, (hl)
	ld	h, #0x00
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#13
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#12
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, (de)
	ldhl	sp,	#0
	ld	(hl), a
00109$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:148: for (i = 0; i < 128; i++) {
	ldhl	sp,	#17
	inc	(hl)
	ld	a, (hl)
	sub	a, #0x80
	jp	C, 00108$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:156: return best;
	ldhl	sp,	#0
	ld	a, (hl)
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:157: }
	add	sp, #18
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:173: static uint8_t pattern_noise_nr43(uint32_t hz)
;	---------------------------------
; Function pattern_noise_nr43
; ---------------------------------
_pattern_noise_nr43:
	add	sp, #-25
	ldhl	sp,	#20
	ld	a, c
	ld	(hl+), a
	ld	a, b
	ld	(hl+), a
	ld	a, e
	ld	(hl+), a
	ld	(hl), d
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:175: uint8_t best = 0;
	ldhl	sp,	#4
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:176: uint32_t best_err = 0xFFFFFFFFUL;
	xor	a, a
	ld	(hl+), a
	ld	a,#0xff
	ld	(hl+),a
	ld	(hl+), a
	ld	a, #0xff
	ld	(hl+), a
	ld	(hl), #0xff
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:179: if (hz < 4UL) hz = 4UL;
	ldhl	sp,	#20
	ld	a, (hl+)
	sub	a, #0x04
	ld	a, (hl+)
	sbc	a, #0x00
	ld	a, (hl+)
	sbc	a, #0x00
	ld	a, (hl)
	sbc	a, #0x00
	jr	NC, 00102$
	ldhl	sp,	#20
	ld	a, #0x04
	ld	(hl+), a
	xor	a, a
	ld	(hl+), a
	ld	(hl+), a
	ld	(hl), a
00102$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:180: if (hz > 262144UL) hz = 262144UL;
	ldhl	sp,	#20
	xor	a, a
	sub	a, (hl)
	inc	hl
	ld	a, #0x00
	sbc	a, (hl)
	inc	hl
	ld	a, #0x04
	sbc	a, (hl)
	inc	hl
	ld	a, #0x00
	sbc	a, (hl)
	jr	NC, 00123$
	xor	a, a
	ldhl	sp,	#20
	ld	(hl+), a
	ld	(hl+), a
	ld	a, #0x04
	ld	(hl+), a
	xor	a, a
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:182: for (shift = 0; shift < 14; shift++) {
00123$:
	ldhl	sp,	#24
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:183: for (code = 0; code < 4; code++) {
00121$:
	ldhl	sp,	#24
	ld	a, (hl)
	swap	a
	and	a, #0xf0
	ldhl	sp,	#9
	ld	(hl), a
	ldhl	sp,	#24
	ld	a, (hl)
	push	af
	xor	a, a
	ldhl	sp,	#12
	ld	(hl+), a
	ld	(hl+), a
	ld	a, #0x08
	ld	(hl+), a
	xor	a, a
	ld	(hl), a
	pop	af
	inc	a
	jr	00176$
00175$:
	ldhl	sp,	#13
	srl	(hl)
	dec	hl
	rr	(hl)
	dec	hl
	rr	(hl)
	dec	hl
	rr	(hl)
00176$:
	dec	a
	jr	NZ, 00175$
	ldhl	sp,	#14
	ld	(hl), #0x00
00109$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:184: uint32_t f = 524288UL >> shift;
	ldhl	sp,	#10
	ld	a, (hl+)
	ld	c, a
	ld	a, (hl+)
	ld	b, a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:187: f >>= (code + 1);
	ld	a, (hl+)
	inc	hl
	ld	e, a
	ld	d, #0x00
	ld	a, (hl+)
	inc	a
	ld	(hl), a
	inc	a
	jr	00178$
00177$:
	srl	d
	rr	e
	rr	b
	rr	c
00178$:
	dec	a
	jr	NZ, 00177$
	inc	sp
	inc	sp
	push	bc
	ldhl	sp,	#2
	ld	a, e
	ld	(hl+), a
	ld	(hl), d
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:188: err = (f > hz) ? (f - hz) : (hz - f);
	ldhl	sp,	#20
	ld	e, l
	ld	d, h
	ldhl	sp,	#0
	ld	a, (de)
	inc	de
	sub	a, (hl)
	inc	hl
	ld	a, (de)
	inc	de
	sbc	a, (hl)
	inc	hl
	ld	a, (de)
	inc	de
	sbc	a, (hl)
	inc	hl
	ld	a, (de)
	sbc	a, (hl)
	jr	NC, 00115$
	pop	de
	push	de
	ld	a, e
	ldhl	sp,	#20
	sub	a, (hl)
	inc	hl
	ld	e, a
	ld	a, d
	sbc	a, (hl)
	push	af
	ldhl	sp,	#19
	ld	(hl-), a
	ld	(hl), e
	ldhl	sp,#4
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ldhl	sp,	#24
	pop	af
	ld	a, e
	sbc	a, (hl)
	inc	hl
	ld	e, a
	ld	a, d
	sbc	a, (hl)
	ldhl	sp,	#19
	ld	(hl-), a
	ld	(hl), e
	jr	00116$
00115$:
	ldhl	sp,#20
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, e
	ldhl	sp,	#0
	sub	a, (hl)
	inc	hl
	ld	e, a
	ld	a, d
	sbc	a, (hl)
	push	af
	ldhl	sp,	#19
	ld	(hl-), a
	ld	(hl), e
	ldhl	sp,#24
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ldhl	sp,	#4
	pop	af
	ld	a, e
	sbc	a, (hl)
	inc	hl
	ld	e, a
	ld	a, d
	sbc	a, (hl)
	ldhl	sp,	#19
	ld	(hl-), a
	ld	(hl), e
00116$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:189: if (err < best_err) {
	ldhl	sp,	#16
	ld	e, l
	ld	d, h
	ldhl	sp,	#5
	ld	a, (de)
	inc	de
	sub	a, (hl)
	inc	hl
	ld	a, (de)
	inc	de
	sbc	a, (hl)
	inc	hl
	ld	a, (de)
	inc	de
	sbc	a, (hl)
	inc	hl
	ld	a, (de)
	sbc	a, (hl)
	jr	NC, 00110$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:190: best_err = err;
	ldhl	sp,	#16
	ld	d, h
	ld	e, l
	ldhl	sp,	#5
	ld	a, (de)
	ld	(hl+),	a
	inc	de
	ld	a, (de)
	ld	(hl+),	a
	inc	de
	ld	a, (de)
	ld	(hl+),	a
	inc	de
	ld	a, (de)
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:191: best = (uint8_t)((shift << 4) | code);
	ldhl	sp,	#9
	ld	a, (hl)
	ldhl	sp,	#14
	or	a, (hl)
	ldhl	sp,	#4
	ld	(hl), a
00110$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:183: for (code = 0; code < 4; code++) {
	ldhl	sp,	#15
	ld	a, (hl-)
	ld	(hl+), a
	ld	a, (hl)
	sub	a, #0x04
	jp	C, 00109$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:182: for (shift = 0; shift < 14; shift++) {
	ldhl	sp,	#24
	inc	(hl)
	ld	a, (hl)
	sub	a, #0x0e
	jp	C, 00121$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:195: return best;
	ldhl	sp,	#4
	ld	a, (hl)
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:196: }
	add	sp, #25
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:199: static uint8_t pattern_step_kind(uint8_t note, uint8_t index)
;	---------------------------------
; Function pattern_step_kind
; ---------------------------------
_pattern_step_kind:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:201: uint8_t audc = sfx_notes[note][index].audc;
	ld	l, a
	ld	bc, #_sfx_notes+0
	ld	h, #0x00
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, bc
	sla	e
	ld	d, #0x00
	add	hl, de
	ld	c, (hl)
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:203: if (audc == 0 || (audc & 0x0F) == 0) return 0;
	ld	a, c
	or	a, a
	jr	Z, 00101$
	ld	a, c
	and	a, #0x0f
	jr	NZ, 00102$
00101$:
	xor	a, a
	ret
00102$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:204: return ((audc >> 5) <= 4) ? 1 : 2;
	ld	a, c
	swap	a
	rrca
	and	a, #0x07
	cp	a, #0x05
	jr	NC, 00106$
	ld	a, #0x01
	ret
00106$:
	ld	a, #0x02
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:205: }
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:207: static uint8_t pattern_has_sound(uint8_t note, uint8_t from)
;	---------------------------------
; Function pattern_has_sound
; ---------------------------------
_pattern_has_sound:
	ld	d, a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:211: for (i = from; i < SFX_STEPS; i++) {
00105$:
	ld	a, e
	sub	a, #0x10
	jr	NC, 00103$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:212: if (sfx_notes[note][i].audc != 0) return 1;
	ld	l, d
	xor	a, a
	ld	h, a
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	bc, #_sfx_notes
	add	hl, bc
	ld	a, e
	add	a, a
	add	a, l
	ld	c, a
	ld	a, #0x00
	adc	a, h
	ld	b, a
	ld	a, (bc)
	or	a, a
	jr	Z, 00106$
	ld	a, #0x01
	ret
00106$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:211: for (i = from; i < SFX_STEPS; i++) {
	inc	e
	jr	00105$
00103$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:214: return 0;
	xor	a, a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:215: }
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:217: static uint8_t pattern_last_live_step(uint8_t note)
;	---------------------------------
; Function pattern_last_live_step
; ---------------------------------
_pattern_last_live_step:
	ld	c, a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:221: while (i != 0) {
	ld	b, #0x10
00103$:
	ld	a, b
	or	a, a
	jr	Z, 00105$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:222: --i;
	dec	b
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:223: if (sfx_notes[note][i].audc != 0) return i;
	ld	l, c
	ld	h, #0x00
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	a, l
	add	a, #<(_sfx_notes)
	ld	e, a
	ld	a, h
	adc	a, #>(_sfx_notes)
	ld	d, a
	ld	a, b
	add	a, a
	add	a, e
	ld	e, a
	ld	a, #0x00
	adc	a, d
	ld	d, a
	ld	a, (de)
	or	a, a
	jr	Z, 00103$
	ld	a, b
	ret
00105$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:225: return 0;
	xor	a, a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:226: }
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:236: static void release_voice(uint8_t vi)
;	---------------------------------
; Function release_voice
; ---------------------------------
_release_voice:
	dec	sp
	dec	sp
	ld	c, a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:238: SfxVoice *v = &voices[vi];
	ld	b, #0x00
	ld	l, c
	ld	h, b
	add	hl, hl
	add	hl, bc
	add	hl, hl
	add	hl, hl
	add	hl, bc
	ld	de, #_voices
	add	hl, de
	ld	e, l
	ld	d, h
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:240: if (v->last_type == 2) {
	ld	hl, #0x0008
	add	hl, de
	inc	sp
	inc	sp
	ld	e, l
	ld	d, h
	push	de
	ld	a, (de)
	ld	b, a
	sub	a, #0x02
	jr	NZ, 00107$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:241: if (noise_owner == vi) {
	ld	a, (#_noise_owner)
	sub	a, c
	jr	NZ, 00108$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:242: NR42_REG = 0x00;
	xor	a, a
	ldh	(_NR42_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:243: NR44_REG = 0x80;
	ld	a, #0x80
	ldh	(_NR44_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:244: noise_owner = 0xFF;
	ld	hl, #_noise_owner
	ld	(hl), #0xff
	jr	00108$
00107$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:246: } else if (v->last_type == 1 && vi != VOICE_NOISE) {
	dec	b
	jr	NZ, 00108$
	ld	a, c
	sub	a, #0x02
	jr	Z, 00108$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:247: *pulse_vol[vi] = 0x00;
	xor	a, a
	ld	b, a
	sla	c
	rl	b
	ld	hl, #_pulse_vol
	add	hl, bc
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:248: *pulse_period_hi[vi] = 0x80;
	ld	hl, #_pulse_period_hi
	add	hl, bc
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	ld	(hl), #0x80
00108$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:250: v->last_type = 0;
	pop	hl
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:251: }
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:254: static uint8_t last_live_step(const SfxDef *def)
;	---------------------------------
; Function last_live_step
; ---------------------------------
_last_live_step:
	add	sp, #-3
	ldhl	sp,	#1
	ld	a, e
	ld	(hl+), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:256: uint8_t i = def->count;
	ld	a, d
	ld	(hl-), a
	ld	a, (hl+)
	ld	h, (hl)
	ld	l, a
	inc	hl
	inc	hl
	ld	c, (hl)
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:258: while (i != 0) {
	ldhl	sp,	#1
	ld	a, (hl+)
	ld	e, a
	ld	a, (hl-)
	dec	hl
	ld	d, a
	inc	de
	ld	a, (de)
	ld	(hl), a
00103$:
	ld	a, c
	or	a, a
	jr	Z, 00105$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:259: --i;
	dec	c
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:260: if (sfx_notes[def->note][def->first + i].audc != 0) return i;
	ldhl	sp,#1
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, (de)
	ld	l, a
	ld	h, #0x00
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	a, l
	add	a, #<(_sfx_notes)
	ld	e, a
	ld	a, h
	adc	a, #>(_sfx_notes)
	ld	d, a
	ldhl	sp,	#0
	ld	a, (hl)
	add	a, c
	add	a, a
	add	a, e
	ld	e, a
	ld	a, #0x00
	adc	a, d
	ld	d, a
	ld	a, (de)
	or	a, a
	jr	Z, 00103$
	ld	a, c
	jr	00106$
00105$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:262: return 0;
	xor	a, a
00106$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:263: }
	add	sp, #3
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:266: static uint16_t legacy_remaining10(const SfxDef *def, uint8_t from)
;	---------------------------------
; Function legacy_remaining10
; ---------------------------------
_legacy_remaining10:
	ld	l, a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:268: uint8_t last = last_live_step(def);
	push	hl
	push	de
	call	_last_live_step
	ld	b, a
	pop	de
	pop	hl
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:269: uint8_t rate = def->step_frames ? def->step_frames : 1;
	inc	de
	inc	de
	inc	de
	inc	de
	inc	de
	ld	a, (de)
	or	a, a
	jr	Z, 00105$
	ld	c, a
	jr	00106$
00105$:
	ld	c, #0x01
00106$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:271: if (last < from) return 0;
	ld	a, b
	sub	a, l
	jr	NC, 00102$
	ld	bc, #0x0000
	ret
00102$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:272: return (uint16_t)(last - from + 1) * rate * 10;
	ld	a, b
	ld	b, #0x00
	sub	a, l
	ld	e, a
	sbc	a, a
	sub	a, b
	ld	d, a
	inc	de
	ld	b, #0x00
	call	__mulint
	ld	l, c
	ld	h, b
	add	hl, hl
	add	hl, hl
	add	hl, bc
	add	hl, hl
	ld	c, l
	ld	b, h
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:273: }
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:275: static uint16_t pattern_remaining10(uint8_t note, uint8_t from)
;	---------------------------------
; Function pattern_remaining10
; ---------------------------------
_pattern_remaining10:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:277: uint8_t last = pattern_last_live_step(note);
	push	de
	call	_pattern_last_live_step
	pop	de
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:279: if (last < from) return 0;
	cp	a, e
	jr	NC, 00102$
	ld	bc, #0x0000
	ret
00102$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:280: return (uint16_t)(last - from + 1) * 48;
	ld	d, #0x00
	sub	a, e
	ld	c, a
	sbc	a, a
	sub	a, d
	ld	b, a
	inc	bc
	ld	l, c
	ld	h, b
	add	hl, hl
	add	hl, bc
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	c, l
	ld	b, h
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:281: }
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:283: static uint16_t voice_remaining10(uint8_t vi)
;	---------------------------------
; Function voice_remaining10
; ---------------------------------
_voice_remaining10:
	ld	c, a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:285: SfxVoice *v = &voices[vi];
	ld	b, #0x00
	ld	l, c
	ld	h, b
	add	hl, hl
	add	hl, bc
	add	hl, hl
	add	hl, hl
	add	hl, bc
	ld	de, #_voices
	add	hl, de
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:287: if (v->kind == VOICE_KIND_PATTERN) return pattern_remaining10(v->note, v->step);
	ld	c, l
	ld	b, h
	inc	bc
	inc	bc
	ld	a, (bc)
	ld	b, a
	ld	a, l
	add	a, #0x05
	ld	e, a
	ld	a, h
	adc	a, #0x00
	ld	d, a
	ld	a, (de)
	ld	c, a
	dec	b
	jr	NZ, 00102$
	inc	hl
	inc	hl
	inc	hl
	ld	a, (hl)
	ld	e, c
	jp	_pattern_remaining10
00102$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:288: return legacy_remaining10(v->def, v->step);
	ld	a, (hl+)
	ld	b, a
	ld	l, (hl)
	ld	a, c
	ld	e, b
	ld	d, l
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:289: }
	jp	_legacy_remaining10
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:292: static uint8_t alloc_noise_voice(uint16_t want)
;	---------------------------------
; Function alloc_noise_voice
; ---------------------------------
_alloc_noise_voice:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:294: if (voices[VOICE_NOISE].playing) {
	ld	bc, #_voices+30
	ld	a, (bc)
	or	a, a
	jr	Z, 00104$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:298: uint16_t have = voice_remaining10(VOICE_NOISE);
	push	de
	ld	a, #0x02
	call	_voice_remaining10
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:299: if (have > (uint16_t)(want * 4)) return 0xFF;
	pop	hl
	add	hl, hl
	add	hl, hl
	ld	a, l
	sub	a, c
	ld	a, h
	sbc	a, b
	jr	NC, 00104$
	ld	a, #0xff
	ret
00104$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:301: return VOICE_NOISE;
	ld	a, #0x02
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:302: }
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:304: static uint8_t alloc_pulse_voice(void)
;	---------------------------------
; Function alloc_pulse_voice
; ---------------------------------
_alloc_pulse_voice:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:306: if (!voices[VOICE_PULSE1].playing) return VOICE_PULSE1;
	ld	a, (#(_voices + 4) + 0)
	or	a,a
	ret	Z
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:307: if (!voices[VOICE_PULSE2].playing) return VOICE_PULSE2;
	ld	a, (#(_voices + 17) + 0)
	or	a, a
	jr	NZ, 00104$
	ld	a, #0x01
	ret
00104$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:310: uint16_t left0 = voice_remaining10(VOICE_PULSE1);
	xor	a, a
	call	_voice_remaining10
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:311: uint16_t left1 = voice_remaining10(VOICE_PULSE2);
	push	bc
	ld	a, #0x01
	call	_voice_remaining10
	ld	e, c
	ld	d, b
	pop	bc
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:313: if (left0 < left1) return VOICE_PULSE1;
	ld	a, c
	sub	a, e
	ld	a, b
	sbc	a, d
	jr	NC, 00106$
	xor	a, a
	ret
00106$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:314: if (left1 < left0) return VOICE_PULSE2;
	ld	a, e
	sub	a, c
	ld	a, d
	sbc	a, b
	jr	NC, 00108$
	ld	a, #0x01
	ret
00108$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:317: return ((int8_t)(voices[VOICE_PULSE1].started - voices[VOICE_PULSE2].started) <= 0)
	ld	a, (#(_voices + 12))
	ld	hl, #(_voices + 25)
	sub	a, (hl)
	ld	c, a
	ld	e, c
	xor	a, a
	ld	d, a
	sub	a, c
	bit	7, e
	jr	Z, 00148$
	bit	7, d
	jr	NZ, 00149$
	cp	a, a
	jr	00149$
00148$:
	bit	7, d
	jr	Z, 00149$
	scf
00149$:
	jr	C, 00111$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:318: ? VOICE_PULSE1 : VOICE_PULSE2;
	xor	a, a
	ret
00111$:
	ld	a, #0x01
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:319: }
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:322: static uint8_t alloc_pattern_voice(uint8_t note)
;	---------------------------------
; Function alloc_pattern_voice
; ---------------------------------
_alloc_pattern_voice:
	dec	sp
	dec	sp
	ldhl	sp,	#1
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:325: uint8_t has_noise = 0;
	ld	(hl-), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:326: uint8_t has_pulse = 0;
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:328: for (i = 0; i < SFX_STEPS; i++) {
	ld	de, #0x0
	ld	(hl), e
00113$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:329: uint8_t kind = pattern_step_kind(note, i);
	push	de
	ldhl	sp,	#3
	ld	a, (hl)
	call	_pattern_step_kind
	pop	de
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:330: if (kind == 1) has_noise = 1;
	cp	a, #0x01
	jr	NZ, 00104$
	ldhl	sp,	#0
	ld	(hl), #0x01
	jr	00114$
00104$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:331: else if (kind == 2) has_pulse = 1;
	sub	a, #0x02
	jr	NZ, 00114$
	ld	d, #0x01
00114$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:328: for (i = 0; i < SFX_STEPS; i++) {
	inc	e
	ld	a, e
	sub	a, #0x10
	jr	C, 00113$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:333: if (!has_noise && !has_pulse) return 0xFF;
	ldhl	sp,	#0
	ld	a, (hl)
	or	a, a
	jr	NZ, 00108$
	or	a, d
	jr	NZ, 00108$
	ld	a, #0xff
	jr	00115$
00108$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:334: if (has_noise && !has_pulse) return alloc_noise_voice(pattern_remaining10(note, 0));
	ldhl	sp,	#0
	ld	a, (hl)
	or	a, a
	jr	Z, 00111$
	ld	a, d
	or	a, a
	jr	NZ, 00111$
	inc	hl
	ld	e, #0x00
	ld	a, (hl)
	call	_pattern_remaining10
	ld	e, c
	ld	d, b
	inc	sp
	inc	sp
	jp	_alloc_noise_voice
	jr	00115$
00111$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:335: return alloc_pulse_voice();
	inc	sp
	inc	sp
	jp	_alloc_pulse_voice
00115$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:336: }
	inc	sp
	inc	sp
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:339: static uint8_t legacy_is_noise(const SfxDef *def)
;	---------------------------------
; Function legacy_is_noise
; ---------------------------------
_legacy_is_noise:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:341: return pokey_distortion(sfx_notes[def->note][def->first].audc) == 2;
	ld	a, (de)
	ld	h, #0x00
	ld	l, a
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	bc, #_sfx_notes
	add	hl, bc
	inc	de
	ld	a, (de)
	add	a, a
	add	a, l
	ld	l, a
	ld	a, #0x00
	adc	a, h
	ld	h, a
	ld	a, (hl)
	call	_pokey_distortion
	sub	a, #0x02
	ld	a, #0x01
	ret	Z
	xor	a, a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:342: }
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:344: static uint8_t alloc_legacy_voice(const SfxDef *def)
;	---------------------------------
; Function alloc_legacy_voice
; ---------------------------------
_alloc_legacy_voice:
	ld	c, e
	ld	b, d
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:346: if (legacy_is_noise(def)) return alloc_noise_voice(legacy_remaining10(def, 0));
	push	bc
	ld	e, c
	ld	d, b
	call	_legacy_is_noise
	pop	bc
	or	a, a
	jp	Z, _alloc_pulse_voice
	xor	a, a
	ld	e, c
	ld	d, b
	call	_legacy_remaining10
	ld	e, c
	ld	d, b
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:347: return alloc_pulse_voice();
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:348: }
	jp	_alloc_noise_voice
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:354: static void apply_legacy_step(uint8_t vi, uint8_t index)
;	---------------------------------
; Function apply_legacy_step
; ---------------------------------
_apply_legacy_step:
	add	sp, #-17
	ldhl	sp,	#15
	ld	(hl-), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:356: SfxVoice *v = &voices[vi];
	ld	a, e
	ld	(hl+), a
	ld	bc, #_voices+0
	ld	e, (hl)
	ld	d, #0x00
	ld	l, e
	ld	h, d
	add	hl, hl
	add	hl, de
	add	hl, hl
	add	hl, hl
	add	hl, de
	add	hl, bc
	ld	c, l
	ld	a, h
	ldhl	sp,	#11
	ld	(hl), c
	inc	hl
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:357: const SfxDef *def = v->def;
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, (de)
	ldhl	sp,	#9
	ld	(hl+), a
	inc	de
	ld	a, (de)
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:358: const SfxStep *s = &sfx_notes[def->note][def->first + index];
	ld	(hl-), a
	ld	a, (hl)
	ldhl	sp,	#2
	ld	(hl), a
	ldhl	sp,	#10
	ld	a, (hl)
	ldhl	sp,	#3
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, (de)
	ldhl	sp,	#16
	ld	(hl), a
	ld	a, (hl)
	ldhl	sp,	#7
	ld	(hl+), a
	xor	a, a
	ld	(hl-), a
	ld	a, (hl-)
	dec	hl
	ld	(hl+), a
	ld	(hl), #0x00
	ld	a, #0x05
00419$:
	ldhl	sp,	#5
	sla	(hl)
	inc	hl
	rl	(hl)
	dec	a
	jr	NZ, 00419$
	dec	hl
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #_sfx_notes
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#9
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#8
	ld	(hl+), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	l, e
	ld	h, d
	inc	hl
	push	hl
	ld	a, l
	ldhl	sp,	#7
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#6
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, (de)
	ldhl	sp,	#14
	add	a, (hl)
	inc	hl
	inc	hl
	ld	(hl), a
	sla	(hl)
	ld	e, (hl)
	ld	d, #0x00
	ldhl	sp,	#7
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	inc	sp
	inc	sp
	push	hl
	ldhl	sp,	#0
	ld	a, (hl)
	ldhl	sp,	#6
	ld	(hl), a
	ldhl	sp,	#1
	ld	a, (hl)
	ldhl	sp,	#7
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:359: uint8_t audc = s->audc;
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	a, (hl+)
	ld	d, a
	ld	a, (de)
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:360: uint8_t vol = pokey_volume(audc);
	ld	a, (hl)
	call	_pokey_volume
	ldhl	sp,	#16
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:361: uint8_t dist = pokey_distortion(audc);
	ldhl	sp,	#8
	ld	a, (hl)
	call	_pokey_distortion
	ldhl	sp,	#4
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:364: if (def->gap && (index & 1)) {
	ldhl	sp,#9
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #0x000d
	add	hl, de
	ld	c, l
	ld	b, h
	ld	a, (bc)
	or	a, a
	jr	Z, 00102$
	push	hl
	ldhl	sp,	#16
	bit	0, (hl)
	pop	hl
	jr	Z, 00102$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:366: release_voice(vi);
	ldhl	sp,	#15
	ld	a, (hl)
	call	_release_voice
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:367: return;
	jp	00172$
00102$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:370: if (vol == 0) {
	ldhl	sp,	#16
	ld	a, (hl)
	or	a, a
	jr	NZ, 00105$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:371: release_voice(vi);
	dec	hl
	ld	a, (hl)
	call	_release_voice
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:372: return;
	jp	00172$
00105$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:378: if (def->note < 15 && vol != 0) {
	ldhl	sp,#2
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, (de)
	sub	a, #0x0f
	jr	NC, 00109$
	ldhl	sp,	#16
	ld	a, (hl)
	or	a, a
	jr	Z, 00109$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:379: vol = (uint8_t)(vol << 1);
	sla	(hl)
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:380: if (vol > 15) vol = 15;
	ld	a, #0x0f
	sub	a, (hl)
	jr	NC, 00109$
	ld	(hl), #0x0f
00109$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:385: if (def->master >= 1 && def->master < 8) {
	ldhl	sp,#9
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #0x0013
	add	hl, de
	ld	c, l
	ld	b, h
	ld	a, (bc)
	ldhl	sp,	#13
	ld	(hl), a
	ld	a, (hl)
	sub	a, #0x01
	jr	C, 00116$
	ld	a, (hl)
	sub	a, #0x08
	jr	NC, 00116$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:386: vol = (uint8_t)(((uint16_t)vol * (def->master + 1)) / 8);
	ld	c, (hl)
	inc	c
	ldhl	sp,	#16
	ld	e, (hl)
	xor	a, a
	ld	b, #0x00
	ld	d, a
	call	__mulint
	srl	b
	rr	c
	srl	b
	rr	c
	srl	b
	rr	c
	ldhl	sp,	#16
	ld	(hl), c
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:387: if (vol == 0) vol = 1;
	ld	a, (hl)
	or	a, a
	jr	NZ, 00112$
	ld	(hl), #0x01
00112$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:388: if (vol > 15) vol = 15;
	ld	a, #0x0f
	ldhl	sp,	#16
	sub	a, (hl)
	jr	NC, 00116$
	ld	(hl), #0x0f
00116$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:391: hz = pokey_rate(audc, s->audf);
	ldhl	sp,	#6
	ld	a, (hl+)
	ld	h, (hl)
	ld	l, a
	inc	hl
	ld	e, (hl)
	ldhl	sp,	#8
	ld	a, (hl)
	call	_pokey_rate
	ldhl	sp,	#5
	ld	a, c
	ld	(hl+), a
	ld	a, b
	ld	(hl+), a
	ld	a, e
	ld	(hl+), a
	ld	(hl), d
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:393: if (def->force_tone && dist == 2) {
	ldhl	sp,#9
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #0x0006
	add	hl, de
	ld	c, l
	ld	b, h
	ld	a, (bc)
	or	a, a
	jr	Z, 00119$
	ldhl	sp,	#4
	ld	a, (hl)
	sub	a, #0x02
	jr	NZ, 00119$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:395: dist = 3;
	ldhl	sp,	#4
	ld	(hl), #0x03
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:396: hz = def->tone_hz;
	ldhl	sp,#9
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #0x0007
	add	hl, de
	ld	a, (hl+)
	ld	c, a
	ld	a, (hl)
	ldhl	sp,	#5
	ld	(hl), c
	inc	hl
	ld	(hl+), a
	xor	a, a
	ld	(hl+), a
	ld	(hl), a
00119$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:398: if (index < def->noise_steps) {
	ldhl	sp,#9
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #0x0009
	add	hl, de
	ld	c, l
	ld	b, h
	ld	a, (bc)
	ld	c, a
	ldhl	sp,	#14
	ld	a, (hl)
	sub	a, c
	jr	NC, 00122$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:401: dist = 2;
	ldhl	sp,	#4
	ld	(hl), #0x02
00122$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:404: if (dist == 2 && def->noise_pitch_q8 != 0) {
	ldhl	sp,	#4
	ld	a, (hl)
	sub	a, #0x02
	ld	a, #0x01
	jr	Z, 00424$
	xor	a, a
00424$:
	ldhl	sp,	#13
	ld	(hl), a
	ld	a, (hl)
	or	a, a
	jr	Z, 00126$
	ldhl	sp,#9
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #0x000b
	add	hl, de
	ld	a, (hl+)
	ld	c, a
	ld	b, (hl)
	ld	a, b
	or	a, c
	jr	Z, 00126$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:405: hz = (hz * def->noise_pitch_q8) / 256UL;
	xor	a, a
	ld	d, a
	ld	e, a
	push	de
	push	bc
	ldhl	sp,	#9
	ld	a, (hl+)
	ld	c, a
	ld	a, (hl+)
	ld	b, a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	call	__mullong
	ld	c, b
	ld	b, e
	ld	e, d
	ld	d, #0x00
	ldhl	sp,	#5
	ld	a, c
	ld	(hl+), a
	ld	a, b
	ld	(hl+), a
	ld	a, e
	ld	(hl+), a
	ld	(hl), d
	jr	00127$
00126$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:406: } else if (def->pitch_q8 != 256) {
	ldhl	sp,	#9
	ld	a, (hl+)
	ld	h, (hl)
	ld	l, a
	inc	hl
	inc	hl
	inc	hl
	ld	a, (hl+)
	ld	c, a
	ld	b, (hl)
	ld	e, c
	ld	d, b
	ld	a, e
	or	a, a
	jr	NZ, 00427$
	dec	d
	jr	Z, 00127$
00427$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:407: hz = (hz * def->pitch_q8) / 256UL;
	xor	a, a
	ld	d, a
	ld	e, a
	push	de
	push	bc
	ldhl	sp,	#9
	ld	a, (hl+)
	ld	c, a
	ld	a, (hl+)
	ld	b, a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	call	__mullong
	ld	c, b
	ld	b, e
	ld	e, d
	ld	d, #0x00
	ldhl	sp,	#5
	ld	a, c
	ld	(hl+), a
	ld	a, b
	ld	(hl+), a
	ld	a, e
	ld	(hl+), a
	ld	(hl), d
00127$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:412: uint8_t envbits = (uint8_t)(def->env & 0x07);
	ldhl	sp,#9
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #0x0010
	add	hl, de
	ld	c, l
	ld	b, h
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:416: if (v->last_type == 1) {
	ldhl	sp,#11
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #0x0008
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#3
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#2
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:410: if (vi == VOICE_NOISE || dist == 2) {
	ldhl	sp,	#15
	ld	a, (hl)
	sub	a, #0x02
	jr	Z, 00168$
	ldhl	sp,	#13
	ld	a, (hl)
	or	a, a
	jp	Z, 00169$
00168$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:411: uint8_t nr43 = noise_period(hz);
	push	bc
	ldhl	sp,	#7
	ld	a, (hl+)
	ld	c, a
	ld	a, (hl+)
	ld	b, a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	call	_noise_period
	ldhl	sp,	#13
	ld	(hl), a
	pop	bc
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:412: uint8_t envbits = (uint8_t)(def->env & 0x07);
	ld	a, (bc)
	and	a, #0x07
	ld	b, a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:416: if (v->last_type == 1) {
	ldhl	sp,#1
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, (de)
	dec	a
	jr	NZ, 00130$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:417: *pulse_vol[vi] = 0x00;
	ld	de, #_pulse_vol+0
	ldhl	sp,	#15
	ld	c, (hl)
	xor	a, a
	sla	c
	adc	a, a
	ldhl	sp,	#12
	ld	(hl), c
	inc	hl
	ld	(hl-), a
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	a, (hl+)
	ld	c, a
	ld	a, (hl)
	ld	l, c
	ld	h, a
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:418: *pulse_period_hi[vi] = 0x80;
	ld	de, #_pulse_period_hi+0
	ldhl	sp,	#12
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	a, (hl+)
	ld	c, a
	ld	a, (hl)
	ld	l, c
	ld	h, a
	ld	(hl), #0x80
00130$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:421: if (def->attack_steps != 0 && index < def->attack_steps) {
	ldhl	sp,#9
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #0x0011
	add	hl, de
	ld	e, l
	ld	d, h
	ld	a, (de)
	ld	e, a
	or	a, a
	jr	Z, 00145$
	ldhl	sp,	#14
	ld	a, (hl)
	sub	a, e
	jr	NC, 00145$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:424: if (v->last_type != 2) {
	ldhl	sp,#1
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, (de)
	sub	a, #0x02
	jr	Z, 00132$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:425: NR41_REG = 0x00;
	xor	a, a
	ldh	(_NR41_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:426: NR42_REG = (uint8_t)(0x08 | (def->attack_env & 0x07));
	ldhl	sp,#9
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #0x0012
	add	hl, de
	ld	c, l
	ld	b, h
	ld	a, (bc)
	and	a, #0x07
	or	a, #0x08
	ldh	(_NR42_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:427: NR43_REG = nr43;
	ldhl	sp,	#11
	ld	a, (hl)
	ldh	(_NR43_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:428: NR44_REG = 0x80;
	ld	a, #0x80
	ldh	(_NR44_REG + 0), a
	jr	00146$
00132$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:430: NR43_REG = nr43;
	ldhl	sp,	#11
	ld	a, (hl)
	ldh	(_NR43_REG + 0), a
	jr	00146$
00145$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:432: } else if (def->attack_steps != 0 && index == def->attack_steps) {
	ld	a, e
	or	a, a
	jr	Z, 00141$
	ldhl	sp,	#14
	ld	a, (hl)
	sub	a, e
	jr	NZ, 00141$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:435: NR42_REG = (uint8_t)(0xF0 | envbits);
	ld	a, b
	or	a, #0xf0
	ldh	(_NR42_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:436: NR43_REG = nr43;
	ldhl	sp,	#11
	ld	a, (hl)
	ldh	(_NR43_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:437: NR44_REG = 0x80;
	ld	a, #0x80
	ldh	(_NR44_REG + 0), a
	jr	00146$
00141$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:438: } else if (!def->smooth || v->last_type != 2) {
	ldhl	sp,#9
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #0x000f
	add	hl, de
	ld	e, l
	ld	d, h
	ld	a, (de)
	or	a, a
	jr	Z, 00136$
	ldhl	sp,#1
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, (de)
	sub	a, #0x02
	jr	Z, 00137$
00136$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:440: NR41_REG = 0x00;
	xor	a, a
	ldh	(_NR41_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:441: NR42_REG = (uint8_t)((vol << 4) | envbits);
	ldhl	sp,	#16
	ld	a, (hl)
	swap	a
	and	a, #0xf0
	or	a, b
	ldh	(_NR42_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:442: NR43_REG = nr43;
	ldhl	sp,	#11
	ld	a, (hl)
	ldh	(_NR43_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:443: NR44_REG = 0x80;
	ld	a, #0x80
	ldh	(_NR44_REG + 0), a
	jr	00146$
00137$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:446: if (envbits == 0) NR42_REG = (uint8_t)(vol << 4);
	ld	a, b
	or	a, a
	jr	NZ, 00135$
	ldhl	sp,	#16
	ld	a, (hl)
	swap	a
	and	a, #0xf0
	ldh	(_NR42_REG + 0), a
00135$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:447: NR43_REG = nr43;
	ldhl	sp,	#11
	ld	a, (hl)
	ldh	(_NR43_REG + 0), a
00146$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:449: noise_owner = vi;
	ldhl	sp,	#15
	ld	a, (hl)
	ld	(#_noise_owner),a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:450: v->last_type = 2;
	ldhl	sp,	#1
	ld	a, (hl+)
	ld	h, (hl)
	ld	l, a
	ld	(hl), #0x02
	jp	00172$
00169$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:457: if (v->last_type == 2 && noise_owner == vi) {
	ldhl	sp,#1
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, (de)
	sub	a, #0x02
	jr	NZ, 00149$
	ld	a, (#_noise_owner)
	ldhl	sp,	#15
	sub	a, (hl)
	jr	NZ, 00149$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:458: NR42_REG = 0x00;
	xor	a, a
	ldh	(_NR42_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:459: NR44_REG = 0x80;
	ld	a, #0x80
	ldh	(_NR44_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:460: noise_owner = 0xFF;
	ld	hl, #_noise_owner
	ld	(hl), #0xff
00149$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:463: if (def->square)    duty = 2; /* forced 50% square */
	ldhl	sp,#9
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #0x000e
	add	hl, de
	ld	e, l
	ld	d, h
	ld	a, (de)
	or	a, a
	jr	Z, 00158$
	ldhl	sp,	#3
	ld	(hl), #0x02
	jr	00159$
00158$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:464: else if (dist == 3) duty = 2; /* 50%  - clean square */
	ldhl	sp,	#4
	ld	a, (hl)
	sub	a, #0x03
	jr	NZ, 00155$
	ldhl	sp,	#3
	ld	(hl), #0x02
	jr	00159$
00155$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:465: else if (dist == 1) duty = 1; /* 25%  - 4-bit poly buzz */
	ldhl	sp,	#4
	ld	a, (hl)
	dec	a
	jr	NZ, 00152$
	ldhl	sp,	#3
	ld	(hl), #0x01
	jr	00159$
00152$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:466: else                duty = 0; /* 12.5% - 5-bit poly buzz */
	ldhl	sp,	#3
	ld	(hl), #0x00
00159$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:468: period = pulse_period(hz);
	push	bc
	ldhl	sp,	#7
	ld	a, (hl+)
	ld	c, a
	ld	a, (hl+)
	ld	b, a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	call	_pulse_period
	ldhl	sp,	#6
	ld	a, c
	ld	(hl+), a
	ld	(hl), b
	pop	bc
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:470: if (def->smooth && v->last_type == 1 &&
	ldhl	sp,#9
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #0x000f
	add	hl, de
	ld	e, l
	ld	d, h
	ld	a, (de)
	ldhl	sp,	#13
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:471: v->last_period == period && v->last_duty == duty) {
	ld	(hl-), a
	dec	hl
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #0x0009
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#8
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#7
	ld	(hl), a
	ldhl	sp,#11
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #0x000b
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#10
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#9
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:470: if (def->smooth && v->last_type == 1 &&
	ldhl	sp,	#13
	ld	a, (hl)
	or	a, a
	jr	Z, 00163$
	ldhl	sp,#1
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, (de)
	dec	a
	jr	NZ, 00163$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:471: v->last_period == period && v->last_duty == duty) {
	ldhl	sp,#6
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, (de)
	ldhl	sp,	#12
	ld	(hl+), a
	inc	de
	ld	a, (de)
	ld	(hl), a
	ldhl	sp,	#4
	ld	a, (hl)
	ldhl	sp,	#12
	sub	a, (hl)
	jr	NZ, 00163$
	ldhl	sp,	#5
	ld	a, (hl)
	ldhl	sp,	#13
	sub	a, (hl)
	jr	NZ, 00163$
	ldhl	sp,#8
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, (de)
	ldhl	sp,	#3
	sub	a, (hl)
	jr	NZ, 00163$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:472: if (def->env == 0) *pulse_vol[vi] = (uint8_t)(vol << 4);
	ld	a, (bc)
	or	a, a
	jp	NZ, 00164$
	ld	bc, #_pulse_vol+0
	ldhl	sp,	#15
	ld	e, (hl)
	ld	d, #0x00
	ld	l, e
	ld	h, d
	add	hl, hl
	add	hl, bc
	ld	a, (hl+)
	ld	c, a
	ld	b, (hl)
	ldhl	sp,	#16
	ld	a, (hl)
	swap	a
	and	a, #0xf0
	ld	(bc), a
	jp	00164$
00163$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:474: *pulse_duty[vi] = (uint8_t)(duty << 6);
	ldhl	sp,	#15
	ld	e, (hl)
	xor	a, a
	sla	e
	adc	a, a
	ldhl	sp,	#10
	ld	(hl), e
	inc	hl
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #_pulse_duty
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#14
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#13
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	a, (hl-)
	ld	d, a
	ld	a, (de)
	ld	(hl+), a
	inc	de
	ld	a, (de)
	ld	(hl), a
	ldhl	sp,	#3
	ld	a, (hl)
	rrca
	rrca
	and	a, #0xc0
	ldhl	sp,	#12
	ld	e, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, e
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:475: *pulse_vol[vi] = (uint8_t)((vol << 4) | (def->env & 0x07));
	ld	de, #_pulse_vol
	ldhl	sp,	#10
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#14
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#13
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	a, (hl-)
	ld	d, a
	ld	a, (de)
	ld	(hl+), a
	inc	de
	ld	a, (de)
	ld	(hl), a
	ldhl	sp,	#16
	ld	a, (hl)
	swap	a
	and	a, #0xf0
	ld	e, a
	ld	a, (bc)
	and	a, #0x07
	or	a, e
	ldhl	sp,	#12
	ld	e, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, e
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:476: *pulse_period_lo[vi] = (uint8_t)(period & 0xFF);
	ld	de, #_pulse_period_lo
	ldhl	sp,	#10
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	a, (hl+)
	ld	c, a
	ld	b, (hl)
	ldhl	sp,	#4
	ld	a, (hl)
	ld	(bc), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:477: *pulse_period_hi[vi] = (uint8_t)(0x80 | ((period >> 8) & 0x07));
	ld	bc, #_pulse_period_hi+0
	ldhl	sp,	#10
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, bc
	ld	a, (hl+)
	ld	c, a
	ld	b, (hl)
	ldhl	sp,	#5
	ld	a, (hl)
	and	a, #0x07
	set	7, a
	ld	(bc), a
00164$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:479: v->last_type = 1;
	ldhl	sp,	#1
	ld	a, (hl+)
	ld	h, (hl)
	ld	l, a
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:480: v->last_period = period;
	ldhl	sp,	#6
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ldhl	sp,	#4
	ld	a, (hl+)
	ld	(de), a
	inc	de
	ld	a, (hl)
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:481: v->last_duty = duty;
	ldhl	sp,	#8
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ldhl	sp,	#3
	ld	a, (hl)
	ld	(de), a
00172$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:483: }
	add	sp, #17
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:485: static void apply_pattern_step(uint8_t vi, uint8_t index)
;	---------------------------------
; Function apply_pattern_step
; ---------------------------------
_apply_pattern_step:
	add	sp, #-20
	ldhl	sp,	#19
	ld	(hl-), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:487: SfxVoice *v = &voices[vi];
	ld	a, e
	ld	(hl+), a
	ld	bc, #_voices+0
	ld	e, (hl)
	ld	d, #0x00
	ld	l, e
	ld	h, d
	add	hl, hl
	add	hl, de
	add	hl, hl
	add	hl, hl
	add	hl, de
	add	hl, bc
	ld	c, l
	ld	a, h
	ldhl	sp,	#8
	ld	(hl), c
	inc	hl
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:488: const SfxStep *s = &sfx_notes[v->note][index];
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #0x0003
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#18
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#17
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, (de)
	ld	(hl), a
	ld	a, (hl-)
	ld	(hl+), a
	ld	(hl), #0x00
	ld	a, #0x05
00239$:
	ldhl	sp,	#16
	sla	(hl)
	inc	hl
	rl	(hl)
	dec	a
	jr	NZ, 00239$
	dec	hl
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #_sfx_notes
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#16
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#15
	ld	(hl), a
	ldhl	sp,	#18
	ld	a, (hl-)
	add	a, a
	ld	(hl), a
	ld	e, (hl)
	ld	d, #0x00
	ldhl	sp,	#14
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#18
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#17
	ld	(hl-), a
	ld	a, (hl)
	ldhl	sp,	#12
	ld	(hl), a
	ldhl	sp,	#17
	ld	a, (hl)
	ldhl	sp,	#13
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:489: uint8_t audc = s->audc;
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	a, (hl+)
	inc	hl
	ld	d, a
	ld	a, (de)
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:496: if (audc == 0) {
	ld	a, (hl)
	or	a, a
	jr	NZ, 00102$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:497: release_voice(vi);
	ldhl	sp,	#19
	ld	a, (hl)
	call	_release_voice
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:498: return;
	jp	00130$
00102$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:501: vol = (uint8_t)((audc & 0x0F) << 1);
	ldhl	sp,	#15
	ld	a, (hl+)
	inc	hl
	ld	(hl), a
	ld	a, (hl)
	and	a, #0x0f
	ld	(hl), a
	sla	(hl)
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:502: if (vol > 15) vol = 15;
	ld	a, #0x0f
	sub	a, (hl)
	jr	NC, 00104$
	ld	(hl), #0x0f
00104$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:503: if (vol == 0) {
	ldhl	sp,	#17
	ld	a, (hl)
	or	a, a
	jr	NZ, 00106$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:504: release_voice(vi);
	inc	hl
	inc	hl
	ld	a, (hl)
	call	_release_voice
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:505: return;
	jp	00130$
00106$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:508: dist = (uint8_t)(audc >> 5);
	ldhl	sp,	#15
	ld	a, (hl+)
	swap	a
	rrca
	and	a, #0x07
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:509: clock = (audc & 0x10) ? POKEY_CLOCK_179M : POKEY_CLOCK_64K;
	push	hl
	dec	hl
	bit	4, (hl)
	pop	hl
	jr	Z, 00132$
	ldhl	sp,	#4
	ld	a, #0x4d
	ld	(hl+), a
	ld	a, #0x4f
	ld	(hl+), a
	ld	a, #0x1b
	ld	(hl+), a
	xor	a, a
	ld	(hl), a
	jr	00133$
00132$:
	ldhl	sp,	#4
	ld	a, #0xb1
	ld	(hl+), a
	ld	a, #0xf9
	ld	(hl+), a
	xor	a, a
	ld	(hl+), a
	ld	(hl), a
00133$:
	ldhl	sp,	#4
	ld	d, h
	ld	e, l
	ldhl	sp,	#0
	ld	a, (de)
	ld	(hl+),	a
	inc	de
	ld	a, (de)
	ld	(hl+),	a
	inc	de
	ld	a, (de)
	ld	(hl+),	a
	inc	de
	ld	a, (de)
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:510: div = (uint32_t)s->audf + 1UL;
	ldhl	sp,#12
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	l, e
	ld	h, d
	inc	hl
	push	hl
	ld	a, l
	ldhl	sp,	#16
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#15
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, (de)
	ld	(hl), a
	ld	a, (hl)
	ldhl	sp,	#12
	ld	(hl+), a
	xor	a, a
	ld	(hl+), a
	ld	(hl+), a
	ld	(hl-), a
	dec	hl
	dec	hl
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, e
	add	a, #0x01
	ld	e, a
	ld	a, d
	adc	a, #0x00
	push	af
	ldhl	sp,	#7
	ld	(hl-), a
	ld	(hl), e
	ldhl	sp,#16
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	pop	af
	ld	a, e
	adc	a, #0x00
	ld	e, a
	ld	a, d
	adc	a, #0x00
	ldhl	sp,	#7
	ld	(hl-), a
	ld	(hl), e
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:522: if (v->last_type == 1) {
	ldhl	sp,#8
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #0x0008
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#12
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#11
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:528: NR42_REG = (uint8_t)(vol << 4);
	ldhl	sp,	#17
	ld	a, (hl-)
	dec	hl
	swap	a
	and	a, #0xf0
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:522: if (v->last_type == 1) {
	ldhl	sp,#10
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, (de)
	ldhl	sp,	#17
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:512: if (dist <= 4) {
	ld	(hl-), a
	ld	a, #0x04
	sub	a, (hl)
	jp	C, 00128$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:515: hz = clock / div;
	ld	de, #0x0
	push	de
	ldhl	sp,	#6
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	push	de
	ldhl	sp,	#4
	ld	a, (hl+)
	ld	c, a
	ld	a, (hl+)
	ld	b, a
	ld	e, (hl)
	ld	d, #0x00
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:516: if (dist <= 3) hz = (hz * 16UL) / 31UL;
	call	__divulong
	ldhl	sp,	#6
	ld	a, c
	ld	(hl+), a
	ld	a, b
	ld	(hl+), a
	ld	a, e
	ld	(hl+), a
	ld	(hl), d
	ld	a, #0x03
	ldhl	sp,	#16
	sub	a, (hl)
	jr	C, 00108$
	ld	a, #0x04
00241$:
	ldhl	sp,	#6
	sla	(hl)
	inc	hl
	rl	(hl)
	inc	hl
	rl	(hl)
	inc	hl
	rl	(hl)
	dec	a
	jr	NZ,00241$
	ld	de, #0x0000
	push	de
	ld	e, #0x1f
	push	de
	ldhl	sp,	#10
	ld	a, (hl+)
	ld	c, a
	ld	a, (hl+)
	ld	b, a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	call	__divulong
	ldhl	sp,	#6
	ld	a, c
	ld	(hl+), a
	ld	a, b
	ld	(hl+), a
	ld	a, e
	ld	(hl+), a
	ld	(hl), d
00108$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:517: if (hz < 4UL) hz = 4UL;
	ldhl	sp,	#6
	ld	a, (hl+)
	sub	a, #0x04
	ld	a, (hl+)
	sbc	a, #0x00
	ld	a, (hl+)
	sbc	a, #0x00
	ld	a, (hl)
	sbc	a, #0x00
	jr	NC, 00110$
	ldhl	sp,	#6
	ld	a, #0x04
	ld	(hl+), a
	xor	a, a
	ld	(hl+), a
	ld	(hl+), a
	ld	(hl), a
00110$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:518: if (hz > 262144UL) hz = 262144UL;
	ldhl	sp,	#6
	xor	a, a
	sub	a, (hl)
	inc	hl
	ld	a, #0x00
	sbc	a, (hl)
	inc	hl
	ld	a, #0x04
	sbc	a, (hl)
	inc	hl
	ld	a, #0x00
	sbc	a, (hl)
	jr	NC, 00112$
	xor	a, a
	ldhl	sp,	#6
	ld	(hl+), a
	ld	(hl+), a
	ld	a, #0x04
	ld	(hl+), a
	xor	a, a
	ld	(hl), a
00112$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:522: if (v->last_type == 1) {
	ldhl	sp,	#17
	ld	a, (hl)
	dec	a
	jr	NZ, 00114$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:523: *pulse_vol[vi] = 0x00;
	ldhl	sp,	#19
	ld	a, (hl)
	ldhl	sp,	#16
	ld	(hl+), a
	xor	a, a
	ld	(hl-), a
	ld	a, (hl)
	ldhl	sp,	#13
	ld	(hl+), a
	xor	a, a
	ld	(hl-), a
	sla	(hl)
	inc	hl
	rl	(hl)
	ld	de, #_pulse_vol
	ld	a, (hl-)
	ld	l, (hl)
	ld	h, a
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#18
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#17
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, (de)
	ld	l, a
	inc	de
	ld	a, (de)
	ld	h, a
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:524: *pulse_period_hi[vi] = 0x80;
	ld	bc, #_pulse_period_hi+0
	ldhl	sp,	#13
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, bc
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	ld	(hl), #0x80
00114$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:527: NR41_REG = 0x00;
	xor	a, a
	ldh	(_NR41_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:528: NR42_REG = (uint8_t)(vol << 4);
	ldhl	sp,	#15
	ld	a, (hl)
	ldh	(_NR42_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:529: nr43 = pattern_noise_nr43(hz);
	ldhl	sp,	#6
	ld	a, (hl+)
	ld	c, a
	ld	a, (hl+)
	ld	b, a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	call	_pattern_noise_nr43
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:530: NR43_REG = nr43;
	ldh	(_NR43_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:531: NR44_REG = 0x80;
	ld	a, #0x80
	ldh	(_NR44_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:532: noise_owner = vi;
	ldhl	sp,	#19
	ld	a, (hl)
	ld	(#_noise_owner),a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:533: v->last_type = 2;
	ldhl	sp,	#10
	ld	a, (hl+)
	ld	h, (hl)
	ld	l, a
	ld	(hl), #0x02
	jp	00130$
00128$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:539: if (v->last_type == 2 && noise_owner == vi) {
	ldhl	sp,	#17
	ld	a, (hl)
	sub	a, #0x02
	jr	NZ, 00116$
	ld	a, (#_noise_owner)
	ldhl	sp,	#19
	sub	a, (hl)
	jr	NZ, 00116$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:540: NR42_REG = 0x00;
	xor	a, a
	ldh	(_NR42_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:541: NR44_REG = 0x80;
	ld	a, #0x80
	ldh	(_NR44_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:542: noise_owner = 0xFF;
	ld	hl, #_noise_owner
	ld	(hl), #0xff
00116$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:545: if (dist == 6) {
	ldhl	sp,	#16
	ld	a, (hl)
	sub	a, #0x06
	jr	NZ, 00119$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:546: hz = clock / (15UL * div);
	ldhl	sp,	#4
	ld	a, (hl+)
	ld	c, a
	ld	b, (hl)
	ld	l, c
	ld	h, b
	add	hl, hl
	add	hl, bc
	add	hl, hl
	add	hl, bc
	add	hl, hl
	add	hl, bc
	ld	c, l
	ld	b, h
	xor	a, a
	ld	d, a
	ld	e, a
	push	de
	push	bc
	ldhl	sp,	#4
	ld	a, (hl+)
	ld	c, a
	ld	a, (hl+)
	ld	b, a
	ld	e, (hl)
	ld	d, #0x00
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:547: duty = 1; /* 25% duty */
	call	__divulong
	ldhl	sp,	#4
	ld	a, c
	ld	(hl+), a
	ld	a, b
	ld	(hl+), a
	ld	a, e
	ld	(hl+), a
	ld	(hl), d
	ldhl	sp,	#12
	ld	(hl), #0x01
	jr	00120$
00119$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:549: hz = clock / (2UL * div);
	ldhl	sp,	#4
	ld	a, (hl+)
	ld	b, (hl)
	ld	de, #0x0
	add	a, a
	rl	b
	rl	e
	rl	d
	push	de
	ld	c, a
	push	bc
	ldhl	sp,	#4
	ld	a, (hl+)
	ld	c, a
	ld	a, (hl+)
	ld	b, a
	ld	e, (hl)
	ld	d, #0x00
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:550: duty = 2; /* 50% duty */
	call	__divulong
	ldhl	sp,	#4
	ld	a, c
	ld	(hl+), a
	ld	a, b
	ld	(hl+), a
	ld	a, e
	ld	(hl+), a
	ld	(hl), d
	ldhl	sp,	#12
	ld	(hl), #0x02
00120$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:552: if (hz < 31UL) hz = 31UL;
	ldhl	sp,	#4
	ld	a, (hl+)
	sub	a, #0x1f
	ld	a, (hl+)
	sbc	a, #0x00
	ld	a, (hl+)
	sbc	a, #0x00
	ld	a, (hl)
	sbc	a, #0x00
	jr	NC, 00122$
	ldhl	sp,	#4
	ld	a, #0x1f
	ld	(hl+), a
	xor	a, a
	ld	(hl+), a
	ld	(hl+), a
	ld	(hl), a
00122$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:553: if (hz > 65535UL) hz = 65535UL;
	ldhl	sp,	#4
	ld	a, #0xff
	sub	a, (hl)
	inc	hl
	ld	a, #0xff
	sbc	a, (hl)
	inc	hl
	ld	a, #0x00
	sbc	a, (hl)
	inc	hl
	ld	a, #0x00
	sbc	a, (hl)
	jr	NC, 00124$
	ldhl	sp,	#4
	ld	a,#0xff
	ld	(hl+),a
	ld	(hl+), a
	xor	a, a
	ld	(hl+), a
	ld	(hl), a
00124$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:554: period = 2048UL - (131072UL / hz);
	ldhl	sp,	#6
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	push	de
	ldhl	sp,	#6
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	push	de
	ld	bc, #0x0000
	ld	de, #0x0002
	call	__divulong
	ld	de, #0x0800
	ld	a, e
	sub	a, c
	ld	e, a
	ld	a, d
	sbc	a, b
	ldhl	sp,	#14
	ld	(hl-), a
	ld	(hl), e
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:555: if (period > 2047UL) period = 2047UL;
	ld	a, #0xff
	sub	a, (hl)
	inc	hl
	ld	a, #0x07
	sbc	a, (hl)
	jr	NC, 00126$
	ldhl	sp,	#13
	ld	a, #0xff
	ld	(hl+), a
	ld	(hl), #0x07
00126$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:557: *pulse_duty[vi] = (uint8_t)(duty << 6);
	ldhl	sp,	#19
	ld	c, (hl)
	xor	a, a
	sla	c
	adc	a, a
	ldhl	sp,	#16
	ld	(hl), c
	inc	hl
	ld	(hl), a
	ld	de, #_pulse_duty
	ld	a, (hl-)
	ld	l, (hl)
	ld	h, a
	add	hl, de
	ld	a, (hl+)
	ld	c, a
	ld	b, (hl)
	ldhl	sp,	#12
	ld	a, (hl)
	rrca
	rrca
	and	a, #0xc0
	ld	(bc), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:558: *pulse_vol[vi] = (uint8_t)(vol << 4);
	ld	de, #_pulse_vol
	ldhl	sp,	#16
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	a, (hl+)
	ld	c, a
	ld	b, (hl)
	ldhl	sp,	#15
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:559: *pulse_period_lo[vi] = (uint8_t)(period & 0xFF);
	ld	a, (hl+)
	ld	(bc), a
	ld	de, #_pulse_period_lo
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	a, (hl+)
	ld	c, a
	ld	b, (hl)
	ldhl	sp,	#13
	ld	a, (hl)
	ld	(bc), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:560: *pulse_period_hi[vi] = (uint8_t)(0x80 | ((period >> 8) & 0x07));
	ld	de, #_pulse_period_hi
	ldhl	sp,	#16
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#8
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#7
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, (de)
	ldhl	sp,	#15
	ld	(hl+), a
	inc	de
	ld	a, (de)
	ld	(hl-), a
	dec	hl
	ld	a, (hl)
	ldhl	sp,	#17
	ld	(hl), a
	ld	a, (hl)
	and	a, #0x07
	ld	(hl), a
	ld	a, (hl)
	ld	(hl), a
	set	7, (hl)
	dec	hl
	dec	hl
	ld	a, (hl+)
	ld	e, a
	ld	a, (hl+)
	ld	d, a
	ld	a, (hl)
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:561: v->last_type = 1;
	ldhl	sp,	#10
	ld	a, (hl+)
	ld	h, (hl)
	ld	l, a
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:562: v->last_period = period;
	ldhl	sp,#8
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #0x0009
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#18
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#17
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ldhl	sp,	#13
	ld	a, (hl+)
	ld	(de), a
	inc	de
	ld	a, (hl)
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:563: v->last_duty = duty;
	ldhl	sp,#8
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #0x000b
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#18
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#17
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ldhl	sp,	#12
	ld	a, (hl)
	ld	(de), a
00130$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:565: }
	add	sp, #20
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:567: static void stop_voice(uint8_t vi)
;	---------------------------------
; Function stop_voice
; ---------------------------------
_stop_voice:
	ld	c, a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:569: release_voice(vi);
	push	bc
	ld	a, c
	call	_release_voice
	pop	bc
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:570: voices[vi].playing = 0;
	ld	b, #0x00
	ld	l, c
	ld	h, b
	add	hl, hl
	add	hl, bc
	add	hl, hl
	add	hl, hl
	add	hl, bc
	ld	a, #<(_voices)
	add	a, l
	ld	e, a
	ld	a, #>(_voices)
	adc	a, h
	ld	d, a
	ld	hl, #0x0004
	add	hl, de
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:571: voices[vi].kind = 0;
	ld	l, e
	ld	h, d
	inc	hl
	inc	hl
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:572: voices[vi].def = 0;
	ld	l, e
	ld	h, d
	xor	a, a
	ld	(hl+), a
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:573: voices[vi].note = 0xFF;
	inc	de
	inc	de
	inc	de
	ld	a, #0xff
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:574: sfx_voice_mask &= (uint8_t)~(1u << vi);
	ld	a, #0x01
	inc	c
	jr	00104$
00103$:
	add	a, a
00104$:
	dec	c
	jr	NZ,00103$
	cpl
	ld	hl, #_sfx_voice_mask
	and	a, (hl)
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:575: }
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:577: static uint8_t only_silence_left(const SfxDef *def, uint8_t from)
;	---------------------------------
; Function only_silence_left
; ---------------------------------
_only_silence_left:
	add	sp, #-6
	ldhl	sp,	#3
	ld	(hl), e
	inc	hl
	ld	(hl), d
	inc	hl
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:581: for (i = from; i < def->count; i++) {
	ld	(hl-), a
	dec	hl
	ld	a, (hl+)
	ld	c, a
	ld	b, (hl)
	inc	bc
	ld	a, (bc)
	ldhl	sp,	#0
	ld	(hl), a
	ldhl	sp,#3
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #0x0002
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#3
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#2
	ld	(hl), a
00105$:
	ldhl	sp,#1
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, (de)
	ld	c, a
	ldhl	sp,	#5
	ld	a, (hl)
	sub	a, c
	jr	NC, 00103$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:582: if (sfx_notes[def->note][def->first + i].audc != 0) return 0;
	dec	hl
	dec	hl
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, (de)
	ld	l, a
	ld	h, #0x00
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	a, l
	add	a, #<(_sfx_notes)
	ld	c, a
	ld	a, h
	adc	a, #>(_sfx_notes)
	ld	b, a
	ldhl	sp,	#0
	ld	a, (hl)
	ldhl	sp,	#5
	add	a, (hl)
	add	a, a
	ld	l, a
	ld	h, #0x00
	add	hl, bc
	ld	a, (hl)
	or	a, a
	jr	Z, 00106$
	xor	a, a
	jr	00107$
00106$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:581: for (i = from; i < def->count; i++) {
	ldhl	sp,	#5
	inc	(hl)
	jr	00105$
00103$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:584: return 1;
	ld	a, #0x01
00107$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:585: }
	add	sp, #6
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:591: void sound_init(void) BANKED
;	---------------------------------
; Function sound_init
; ---------------------------------
	b_sound_init	= 9
_sound_init::
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:595: NR52_REG = 0x80;   /* APU on */
	ld	a, #0x80
	ldh	(_NR52_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:596: NR51_REG = 0x9B;   /* pulse 1 + pulse 2 + noise on both outputs */
	ld	a, #0x9b
	ldh	(_NR51_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:597: NR50_REG = 0xFF;   /* left/right master volume 15 (max) */
	ld	a, #0xff
	ldh	(_NR50_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:598: NR10_REG = 0x00;   /* no sweep */
	xor	a, a
	ldh	(_NR10_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:599: NR11_REG = 0x00;
	xor	a, a
	ldh	(_NR11_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:600: NR12_REG = 0x00;
	xor	a, a
	ldh	(_NR12_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:601: NR13_REG = 0x00;
	xor	a, a
	ldh	(_NR13_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:602: NR14_REG = 0x00;
	xor	a, a
	ldh	(_NR14_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:603: NR21_REG = 0x00;
	xor	a, a
	ldh	(_NR21_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:604: NR22_REG = 0x00;
	xor	a, a
	ldh	(_NR22_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:605: NR23_REG = 0x00;
	xor	a, a
	ldh	(_NR23_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:606: NR24_REG = 0x00;
	xor	a, a
	ldh	(_NR24_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:607: NR41_REG = 0x00;
	xor	a, a
	ldh	(_NR41_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:608: NR42_REG = 0x00;
	xor	a, a
	ldh	(_NR42_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:609: NR43_REG = 0x00;
	xor	a, a
	ldh	(_NR43_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:610: NR44_REG = 0x00;
	xor	a, a
	ldh	(_NR44_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:612: for (i = 0; i < VOICE_COUNT; i++) {
	ld	c, #0x00
00102$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:613: voices[i].def = 0;
	ld	b, #0x00
	ld	l, c
	ld	h, b
	add	hl, hl
	add	hl, bc
	add	hl, hl
	add	hl, hl
	add	hl, bc
	ld	a, l
	add	a, #<(_voices)
	ld	e, a
	ld	a, h
	adc	a, #>(_voices)
	ld	d, a
	ld	l, e
	ld	h, d
	xor	a, a
	ld	(hl+), a
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:614: voices[i].kind = 0;
	ld	l, e
	ld	h, d
	inc	hl
	inc	hl
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:615: voices[i].note = 0xFF;
	ld	l, e
	ld	h, d
	inc	hl
	inc	hl
	inc	hl
	ld	(hl), #0xff
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:616: voices[i].playing = 0;
	ld	hl, #0x0004
	add	hl, de
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:617: voices[i].step = 0;
	ld	hl, #0x0005
	add	hl, de
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:618: voices[i].sub = 0;
	ld	hl, #0x0006
	add	hl, de
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:619: voices[i].wait = 0;
	ld	hl, #0x0007
	add	hl, de
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:620: voices[i].last_type = 0;
	ld	hl, #0x0008
	add	hl, de
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:621: voices[i].started = 0;
	ld	hl, #0x000c
	add	hl, de
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:612: for (i = 0; i < VOICE_COUNT; i++) {
	inc	c
	ld	a, c
	sub	a, #0x03
	jr	C, 00102$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:623: start_order = 0;
	xor	a, a
	ld	(#_start_order),a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:624: noise_owner = 0xFF;
	ld	hl, #_noise_owner
	ld	(hl), #0xff
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:625: sfx_voice_mask = 0;
	xor	a, a
	ld	(#_sfx_voice_mask),a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:626: }
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:628: void sfx_play_note(uint8_t note) BANKED
;	---------------------------------
; Function sfx_play_note
; ---------------------------------
	b_sfx_play_note	= 9
_sfx_play_note::
	dec	sp
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:632: if (note >= SFX_PATTERN_COUNT) return;
	ldhl	sp,	#7
	ld	a, (hl)
	sub	a, #0x0f
	jp	NC, 00109$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:633: if (pattern_muted[note]) return;
	ld	de, #_pattern_muted
	ldhl	sp,	#7
	ld	l, (hl)
	ld	h, #0x00
	add	hl, de
	ld	c, l
	ld	b, h
	ld	a, (bc)
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:634: if (!pattern_has_sound(note, 0)) return;
	or	a, a
	jp	NZ, 00109$
	ld	e, a
	ldhl	sp,	#7
	ld	a, (hl)
	call	_pattern_has_sound
	or	a, a
	jr	Z, 00109$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:636: vi = alloc_pattern_voice(note);
	ldhl	sp,	#7
	ld	a, (hl)
	call	_alloc_pattern_voice
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:637: if (vi >= VOICE_COUNT) return;  /* skipped to protect a longer effect */
	ldhl	sp,#0
	ld	(hl), a
	sub	a, #0x03
	jr	NC, 00109$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:640: SfxVoice *v = &voices[vi];
	ldhl	sp,	#0
	ld	c, (hl)
	ld	b, #0x00
	ld	l, c
	ld	h, b
	add	hl, hl
	add	hl, bc
	add	hl, hl
	add	hl, hl
	add	hl, bc
	ld	de, #_voices
	add	hl, de
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:641: release_voice(vi);
	push	hl
	ldhl	sp,	#2
	ld	a, (hl)
	call	_release_voice
	pop	bc
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:642: v->kind = VOICE_KIND_PATTERN;
	ld	l, c
	ld	h, b
	inc	hl
	inc	hl
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:643: v->note = note;
	ld	e, c
	ld	d, b
	inc	de
	inc	de
	inc	de
	ldhl	sp,	#7
	ld	a, (hl)
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:644: v->def = 0;
	ld	l, c
	ld	h, b
	xor	a, a
	ld	(hl+), a
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:645: v->playing = 1;
	ld	hl, #0x0004
	add	hl, bc
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:646: v->step = 0;
	ld	hl, #0x0005
	add	hl, bc
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:647: v->sub = 0;
	ld	hl, #0x0006
	add	hl, bc
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:648: v->wait = 0;
	ld	hl, #0x0007
	add	hl, bc
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:649: v->started = ++start_order;
	ld	hl, #0x000c
	add	hl, bc
	ld	c, l
	ld	b, h
	ld	hl, #_start_order
	inc	(hl)
	ld	a, (hl)
	ld	(bc), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:651: sfx_voice_mask |= (uint8_t)(1u << vi);
	ldhl	sp,	#0
	ld	b, (hl)
	ld	a, #0x01
	inc	b
	jr	00140$
00139$:
	add	a, a
00140$:
	dec	b
	jr	NZ,00139$
	ld	hl, #_sfx_voice_mask
	or	a, (hl)
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:653: apply_pattern_step(vi, 0);
	ld	e, #0x00
	ldhl	sp,	#0
	ld	a, (hl)
	inc	sp
	jp	_apply_pattern_step
00109$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:654: }
	inc	sp
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:656: void sfx_play_def(const SfxDef *def) BANKED
;	---------------------------------
; Function sfx_play_def
; ---------------------------------
	b_sfx_play_def	= 9
_sfx_play_def::
	add	sp, #-3
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:660: if (!def || def->count == 0 || def->note >= SFX_NOTE_COUNT) return;
	ldhl	sp,	#10
	ld	a, (hl-)
	or	a, (hl)
	jp	Z, 00111$
	ld	a, (hl)
	ldhl	sp,	#0
	ld	(hl), a
	ldhl	sp,	#10
	ld	a, (hl)
	ldhl	sp,	#1
	ld	(hl), a
	pop	hl
	push	hl
	inc	hl
	inc	hl
	ld	e, (hl)
	ld	a, e
	or	a, a
	jp	Z, 00111$
	pop	bc
	push	bc
	ld	a, (bc)
	sub	a, #0x12
	jp	NC, 00111$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:661: if ((uint16_t)(def->first + def->count) > SFX_STEPS) return;
	pop	hl
	push	hl
	inc	hl
	ld	a, (hl)
	ld	h, #0x00
	ld	d, h
	ld	l, a
	add	hl, de
	ld	a, #0x10
	cp	a, l
	ld	a, #0x00
	sbc	a, h
	jp	C, 00111$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:662: if (def->pitch_q8 == 0) return;
	pop	hl
	push	hl
	inc	hl
	inc	hl
	inc	hl
	ld	a, (hl+)
	ld	l, (hl)
	or	a, l
	jp	Z, 00111$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:664: vi = alloc_legacy_voice(def);
	push	bc
	ldhl	sp,	#2
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	call	_alloc_legacy_voice
	ldhl	sp,	#4
	ld	(hl), a
	pop	bc
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:665: if (vi >= VOICE_COUNT) return;  /* skipped to protect a longer effect */
	ldhl	sp,	#2
	ld	a, (hl)
	sub	a, #0x03
	jr	NC, 00111$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:668: SfxVoice *v = &voices[vi];
	ldhl	sp,	#2
	ld	e, (hl)
	ld	d, #0x00
	ld	l, e
	ld	h, d
	add	hl, hl
	add	hl, de
	add	hl, hl
	add	hl, hl
	add	hl, de
	ld	de, #_voices
	add	hl, de
	ld	e, l
	ld	d, h
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:669: release_voice(vi);
	push	bc
	push	de
	ldhl	sp,	#6
	ld	a, (hl)
	call	_release_voice
	pop	de
	pop	bc
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:670: v->kind = VOICE_KIND_LEGACY;
	ld	l, e
	ld	h, d
	inc	hl
	inc	hl
	ld	(hl), #0x02
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:671: v->def = def;
	ldhl	sp,	#0
	ld	a, (hl+)
	ld	(de), a
	inc	de
	ld	a, (hl)
	ld	(de), a
	dec	de
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:672: v->note = def->note;
	ld	l, e
	ld	h, d
	inc	hl
	inc	hl
	inc	hl
	ld	a, (bc)
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:673: v->playing = 1;
	ld	hl, #0x0004
	add	hl, de
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:674: v->step = 0;
	ld	hl, #0x0005
	add	hl, de
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:675: v->sub = 0;
	ld	hl, #0x0006
	add	hl, de
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:676: v->wait = 0;
	ld	hl, #0x0007
	add	hl, de
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:677: v->started = ++start_order;
	ld	hl, #0x000c
	add	hl, de
	ld	c, l
	ld	b, h
	ld	hl, #_start_order
	inc	(hl)
	ld	a, (hl)
	ld	(bc), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:679: sfx_voice_mask |= (uint8_t)(1u << vi);
	ldhl	sp,	#2
	ld	b, (hl)
	ld	a, #0x01
	inc	b
	jr	00149$
00148$:
	add	a, a
00149$:
	dec	b
	jr	NZ,00148$
	ld	hl, #_sfx_voice_mask
	or	a, (hl)
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:682: apply_legacy_step(vi, 0);
	ld	e, #0x00
	ldhl	sp,	#2
	ld	a, (hl)
	call	_apply_legacy_step
00111$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:683: }
	add	sp, #3
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:685: void sfx_stop(void) BANKED
;	---------------------------------
; Function sfx_stop
; ---------------------------------
	b_sfx_stop	= 9
_sfx_stop::
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:689: for (i = 0; i < VOICE_COUNT; i++) {
	ld	c, #0x00
00102$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:690: voices[i].playing = 0;
	ld	b, #0x00
	ld	l, c
	ld	h, b
	add	hl, hl
	add	hl, bc
	add	hl, hl
	add	hl, hl
	add	hl, bc
	ld	a, l
	add	a, #<(_voices)
	ld	e, a
	ld	a, h
	adc	a, #>(_voices)
	ld	d, a
	ld	hl, #0x0004
	add	hl, de
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:691: voices[i].kind = 0;
	ld	l, e
	ld	h, d
	inc	hl
	inc	hl
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:692: voices[i].def = 0;
	ld	l, e
	ld	h, d
	xor	a, a
	ld	(hl+), a
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:693: voices[i].note = 0xFF;
	inc	de
	inc	de
	inc	de
	ld	a, #0xff
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:694: release_voice(i);
	push	bc
	ld	a, c
	call	_release_voice
	pop	bc
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:689: for (i = 0; i < VOICE_COUNT; i++) {
	inc	c
	ld	a, c
	sub	a, #0x03
	jr	C, 00102$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:696: sfx_voice_mask = 0;
	xor	a, a
	ld	(#_sfx_voice_mask),a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:697: }
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:699: void sfx_update(void) BANKED
;	---------------------------------
; Function sfx_update
; ---------------------------------
	b_sfx_update	= 9
_sfx_update::
	add	sp, #-10
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:703: for (i = 0; i < VOICE_COUNT; i++) {
	ldhl	sp,	#9
	ld	(hl), #0x00
00122$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:704: SfxVoice *v = &voices[i];
	ldhl	sp,	#9
	ld	c, (hl)
	ld	b, #0x00
	ld	l, c
	ld	h, b
	add	hl, hl
	add	hl, bc
	add	hl, hl
	add	hl, hl
	add	hl, bc
	ld	a, l
	add	a, #<(_voices)
	ld	c, a
	ld	a, h
	adc	a, #>(_voices)
	ldhl	sp,	#0
	ld	(hl), c
	inc	hl
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:707: if (!v->playing) continue;
	pop	de
	push	de
	ld	hl, #0x0004
	add	hl, de
	ld	c, l
	ld	b, h
	ld	a, (bc)
	ldhl	sp,	#8
	ld	(hl), a
	or	a, a
	jp	Z, 00120$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:709: if (v->kind == VOICE_KIND_PATTERN) {
	pop	de
	push	de
	ld	hl, #0x0002
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#9
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#8
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, (de)
	dec	a
	jp	NZ, 00109$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:711: v->sub = (uint8_t)(v->sub + 10);
	pop	de
	push	de
	ld	hl, #0x0006
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#8
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#7
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	a, (hl+)
	ld	d, a
	ld	a, (de)
	ld	(hl), a
	add	a, #0x0a
	ld	(hl), a
	ld	a, (hl-)
	dec	hl
	ld	e, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, e
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:712: if (v->sub < 48) continue;
	sub	a, #0x30
	jp	C, 00120$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:713: v->sub = (uint8_t)(v->sub - 48);
	ldhl	sp,#6
	ld	a, (hl+)
	ld	e, a
	ld	a, (hl+)
	ld	d, a
	ld	a, (de)
	add	a, #0xd0
	ld	(hl-), a
	dec	hl
	ld	a, (hl+)
	ld	e, a
	ld	a, (hl+)
	ld	d, a
	ld	a, (hl)
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:715: v->step++;
	pop	de
	push	de
	ld	hl, #0x0005
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#6
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#5
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	a, (hl-)
	ld	d, a
	ld	a, (de)
	inc	a
	ld	e, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, e
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:716: if (v->step >= SFX_STEPS || !pattern_has_sound(v->note, v->step)) {
	sub	a, #0x10
	jr	NC, 00105$
	ldhl	sp,#4
	ld	a, (hl+)
	ld	e, a
	ld	a, (hl+)
	ld	d, a
	ld	a, (de)
	ld	(hl), a
	pop	de
	push	de
	ld	hl, #0x0003
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#9
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#8
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	a, (hl-)
	dec	hl
	ld	d, a
	ld	a, (de)
	ld	e, (hl)
	call	_pattern_has_sound
	or	a, a
	jr	NZ, 00106$
00105$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:717: stop_voice(i);
	ldhl	sp,	#9
	ld	a, (hl)
	call	_stop_voice
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:718: continue;
	jp	00120$
00106$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:720: apply_pattern_step(i, v->step);
	ldhl	sp,#4
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, (de)
	ld	e, a
	ldhl	sp,	#9
	ld	a, (hl)
	call	_apply_pattern_step
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:721: continue;
	jp	00120$
00109$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:724: rate = v->def->step_frames;
	ldhl	sp,	#0
	ld	a, (hl)
	ldhl	sp,	#7
	ld	(hl), a
	ldhl	sp,	#1
	ld	a, (hl)
	ldhl	sp,	#8
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, (de)
	ldhl	sp,	#5
	ld	(hl+), a
	inc	de
	ld	a, (de)
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #0x0005
	add	hl, de
	ld	c, l
	ld	b, h
	ld	a, (bc)
	ld	b, a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:725: if (v->step < v->def->noise_steps && v->def->noise_step_frames != 0) {
	pop	de
	push	de
	ld	hl, #0x0005
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#4
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#3
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, (de)
	ld	c, a
	ldhl	sp,#5
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #0x0009
	add	hl, de
	ld	e, l
	ld	d, h
	ld	a, (de)
	ld	e, a
	ld	a, c
	sub	a, e
	jr	NC, 00111$
	ldhl	sp,#5
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #0x000a
	add	hl, de
	ld	e, l
	ld	d, h
	ld	a, (de)
	or	a, a
	jr	Z, 00111$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:726: rate = v->def->noise_step_frames;
	ld	b, a
00111$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:728: if (rate == 0) rate = 1;
	ld	a, b
	or	a, a
	jr	NZ, 00114$
	ld	b, #0x01
00114$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:730: if (++v->wait < rate) continue;
	pop	de
	push	de
	ld	hl, #0x0007
	add	hl, de
	ld	e, l
	ld	d, h
	ld	a, (de)
	inc	a
	ld	(de), a
	sub	a, b
	jr	C, 00120$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:731: v->wait = 0;
	xor	a, a
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:733: v->step++;
	ldhl	sp,#2
	ld	a, (hl+)
	ld	e, a
	ld	a, (hl+)
	ld	d, a
	ld	a, (de)
	inc	a
	ld	(hl-), a
	dec	hl
	ld	a, (hl+)
	ld	e, a
	ld	a, (hl+)
	ld	d, a
	ld	a, (hl)
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:734: if (v->step >= v->def->count ||
	ldhl	sp,#7
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, (de)
	ldhl	sp,	#5
	ld	(hl+), a
	inc	de
	ld	a, (de)
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #0x0002
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#9
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#8
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, (de)
	ld	(hl), a
	ldhl	sp,	#4
	ld	a, (hl)
	ldhl	sp,	#8
	sub	a, (hl)
	jr	NC, 00117$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:735: only_silence_left(v->def, v->step)) {
	ldhl	sp,#2
	ld	a, (hl+)
	ld	e, a
	ld	a, (hl+)
	inc	hl
	ld	d, a
	ld	a, (de)
	ld	e, (hl)
	inc	hl
	ld	d, (hl)
	call	_only_silence_left
	ldhl	sp,#8
	ld	(hl), a
	or	a, a
	jr	Z, 00118$
00117$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:736: stop_voice(i);
	ldhl	sp,	#9
	ld	a, (hl)
	call	_stop_voice
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:737: continue;
	jr	00120$
00118$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:739: apply_legacy_step(i, v->step);
	ldhl	sp,#2
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, (de)
	ldhl	sp,	#8
	ld	(hl), a
	ld	a, (hl+)
	ld	e, a
	ld	a, (hl)
	call	_apply_legacy_step
00120$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:703: for (i = 0; i < VOICE_COUNT; i++) {
	ldhl	sp,	#9
	inc	(hl)
	ld	a, (hl)
	sub	a, #0x03
	jp	C, 00122$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:741: }
	add	sp, #10
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:743: uint8_t sfx_is_playing(void) BANKED
;	---------------------------------
; Function sfx_is_playing
; ---------------------------------
	b_sfx_is_playing	= 9
_sfx_is_playing::
	dec	sp
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:747: for (i = 0; i < VOICE_COUNT; i++) {
	ld	bc, #_voices+0
	ldhl	sp,	#0
	ld	(hl), #0x00
00104$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:748: if (voices[i].playing) return 1;
	ldhl	sp,	#0
	ld	e, (hl)
	ld	d, #0x00
	ld	l, e
	ld	h, d
	add	hl, hl
	add	hl, de
	add	hl, hl
	add	hl, hl
	add	hl, de
	add	hl, bc
	ld	e, l
	ld	d, h
	ld	hl, #0x0004
	add	hl, de
	ld	a, (hl)
	or	a, a
	jr	Z, 00105$
	ld	a, #0x01
	jr	00106$
00105$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:747: for (i = 0; i < VOICE_COUNT; i++) {
	ldhl	sp,	#0
	inc	(hl)
	ld	a, (hl)
	sub	a, #0x03
	jr	C, 00104$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:750: return 0;
	xor	a, a
00106$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:751: }
	inc	sp
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:753: uint8_t sfx_current(void) BANKED
;	---------------------------------
; Function sfx_current
; ---------------------------------
	b_sfx_current	= 9
_sfx_current::
	add	sp, #-5
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:756: uint8_t best = 0xFF;
	ld	c, #0xff
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:757: int8_t best_age = 0;
	ldhl	sp,	#0
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:759: for (i = 0; i < VOICE_COUNT; i++) {
	ld	b, #0x00
00110$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:762: if (!voices[i].playing) continue;
	ld	e, b
	ld	d, #0x00
	ld	l, e
	ld	h, d
	add	hl, hl
	add	hl, de
	add	hl, hl
	add	hl, hl
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#3
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#2
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #_voices
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#5
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#4
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #0x0004
	add	hl, de
	ld	e, l
	ld	d, h
	ld	a, (de)
	or	a, a
	jr	Z, 00106$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:763: age = (int8_t)(voices[i].started - start_order);
	ldhl	sp,#3
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #0x000c
	add	hl, de
	ld	e, l
	ld	d, h
	ld	a, (de)
	ld	hl, #_start_order
	sub	a, (hl)
	ldhl	sp,	#4
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:764: if (best == 0xFF || age > best_age) {
	ld	a, c
	inc	a
	jr	Z, 00103$
	ld	e, (hl)
	ldhl	sp,	#0
	ld	a,(hl)
	ld	d,a
	ldhl	sp,	#4
	sub	a, (hl)
	bit	7, e
	jr	Z, 00159$
	bit	7, d
	jr	NZ, 00160$
	cp	a, a
	jr	00160$
00159$:
	bit	7, d
	jr	Z, 00160$
	scf
00160$:
	jr	NC, 00106$
00103$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:765: best = i;
	ld	c, b
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:766: best_age = age;
	ldhl	sp,	#4
	ld	a, (hl)
	ldhl	sp,	#0
	ld	(hl), a
00106$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:759: for (i = 0; i < VOICE_COUNT; i++) {
	inc	b
	ld	a, b
	sub	a, #0x03
	jr	C, 00110$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:769: if (best == 0xFF) return 0xFF;
	ld	a, c
	inc	a
	jr	NZ, 00109$
	ld	a, #0xff
	jr	00111$
00109$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:770: return (voices[best].kind == VOICE_KIND_PATTERN)
	ld	b, #0x00
	ld	l, c
	ld	h, b
	add	hl, hl
	add	hl, bc
	add	hl, hl
	add	hl, hl
	add	hl, bc
	ld	a, #<(_voices)
	add	a, l
	ld	c, a
	ld	a, #>(_voices)
	adc	a, h
	ld	b, a
	ld	l, c
	ld	h, b
	inc	hl
	inc	hl
	ld	a, (hl)
	dec	a
	jr	NZ, 00113$
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:771: ? voices[best].note : voices[best].def->note;
	inc	bc
	inc	bc
	inc	bc
	ld	a, (bc)
	jr	00114$
00113$:
	ld	l, c
	ld	h, b
	ld	a, (hl+)
	ld	c, a
	ld	b, (hl)
	ld	a, (bc)
00114$:
00111$:
;C:\dev\AI\robbo-port2\gb\src\gb\sound.c:772: }
	add	sp, #5
	ret
	.area _CODE_9
	.area _INITIALIZER
	.area _CABS (ABS)
