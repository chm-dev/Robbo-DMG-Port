;--------------------------------------------------------
; File Created by SDCC : free open source ISO C Compiler
; Version 4.5.1 #15267 (MINGW64)
;--------------------------------------------------------
	.module screens
	
;--------------------------------------------------------
; Public variables in this module
;--------------------------------------------------------
	.globl _set_win_tiles
	.globl _set_bkg_tile_xy
	.globl _set_bkg_tiles
	.globl b_render_pause
	.globl _render_pause
	.globl b_render_victory
	.globl _render_victory
;--------------------------------------------------------
; special function registers
;--------------------------------------------------------
	.area _HRAM
;--------------------------------------------------------
; ram data
;--------------------------------------------------------
	.area _DATA
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
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:10: static uint8_t screen_empty_tile(void)
;	---------------------------------
; Function screen_empty_tile
; ---------------------------------
_screen_empty_tile:
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:12: return metatile_tiles[MT_EMPTY * 4];
	ld	a, (#_metatile_tiles + 0)
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:13: }
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:15: void render_pause(void) BANKED
;	---------------------------------
; Function render_pause
; ---------------------------------
	b_render_pause	= 9
_render_pause::
	add	sp, #-40
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:19: const char *msg = "PAUSED";
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:21: uint8_t empty = screen_empty_tile();
	call	_screen_empty_tile
	ld	c, a
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:23: for (i = 0; i < 20; i++) {
	ld	b, #0x00
00103$:
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:24: row0[i] = empty;
	ld	e, b
	ld	d, #0x00
	ld	hl, #0
	add	hl, sp
	add	hl, de
	ld	(hl), c
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:25: row1[i] = empty;
	ld	e, b
	ld	d, #0x00
	ld	hl, #20
	add	hl, sp
	add	hl, de
	ld	(hl), c
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:23: for (i = 0; i < 20; i++) {
	inc	b
	ld	a, b
	sub	a, #0x14
	jr	C, 00103$
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:27: for (i = 0; msg[i]; i++) {
	ld	c, #0x00
00106$:
	ld	hl, #___str_0
	ld	b, #0x00
	add	hl, bc
	ld	b, (hl)
	ld	a, b
	or	a, a
	jr	Z, 00102$
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:28: row0[7 + i] = font_tiles[(uint8_t)msg[i]];
	ld	a, c
	add	a, #0x07
	ld	e, a
	rlca
	sbc	a, a
	ld	d, a
	ld	hl, #0
	add	hl, sp
	add	hl, de
	ld	a, b
	add	a, #<(_font_tiles)
	ld	e, a
	ld	a, #0x00
	adc	a, #>(_font_tiles)
	ld	d, a
	ld	a, (de)
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:27: for (i = 0; msg[i]; i++) {
	inc	c
	jr	00106$
00102$:
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:30: set_win_tiles(0, 0, 20, 1, row0);
	ld	hl, #0
	add	hl, sp
	push	hl
	ld	hl, #0x114
	push	hl
	xor	a, a
	rrca
	push	af
	call	_set_win_tiles
	add	sp, #6
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:31: set_win_tiles(0, 1, 20, 1, row1);
	ld	hl, #20
	add	hl, sp
	push	hl
	ld	hl, #0x114
	push	hl
	xor	a, a
	inc	a
	push	af
	call	_set_win_tiles
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:32: }
	add	sp, #46
	ret
___str_0:
	.ascii "PAUSED"
	.db 0x00
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:34: static void draw_bg_text(const char *text, uint8_t x, uint8_t y)
;	---------------------------------
; Function draw_bg_text
; ---------------------------------
_draw_bg_text:
	ld	c, e
	ld	b, d
	ld	d, a
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:36: while (*text) {
00103$:
	ld	a, (bc)
	or	a, a
	jr	Z, 00106$
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:37: uint8_t tile = font_tiles[(uint8_t)*text];
	add	a, #<(_font_tiles)
	ld	l, a
	ld	a, #0x00
	adc	a, #>(_font_tiles)
	ld	h, a
	ld	a, (hl)
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:38: if (tile != 0xFF) {
	cp	a, #0xff
	jr	Z, 00102$
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:39: set_bkg_tile_xy(x, y, tile);
	push	bc
	push	de
	push	af
	inc	sp
	ldhl	sp,	#7
	ld	e, (hl)
	ld	a, d
	call	_set_bkg_tile_xy
	pop	de
	pop	bc
00102$:
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:41: x++;
	inc	d
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:42: text++;
	inc	bc
	jr	00103$
00106$:
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:44: }
	pop	hl
	inc	sp
	jp	(hl)
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:46: void render_victory(void) BANKED
;	---------------------------------
; Function render_victory
; ---------------------------------
	b_render_victory	= 9
_render_victory::
	add	sp, #-32
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:50: uint8_t empty = screen_empty_tile();
	call	_screen_empty_tile
	ld	e, a
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:52: BGP_REG = 0xE4;
	ld	a, #0xe4
	ldh	(_BGP_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:53: SCX_REG = 0;
	xor	a, a
	ldh	(_SCX_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:54: SCY_REG = 0;
	xor	a, a
	ldh	(_SCY_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:56: for (x = 0; x < 32; x++) buf[x] = empty;
	ldhl	sp,	#0
	ld	c, l
	ld	b, h
	ld	d, #0x00
00104$:
	ld	l, d
	ld	h, #0x00
	add	hl, bc
	ld	(hl), e
	inc	d
	ld	a, d
	sub	a, #0x20
	jr	C, 00104$
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:57: for (y = 0; y < 32; y++) {
	ld	d, #0x00
00106$:
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:58: set_bkg_tiles(0, y, 32, 1, buf);
	ld	l, c
	ld	h, b
	push	de
	push	hl
	ld	hl, #0x120
	push	hl
	push	de
	inc	sp
	xor	a, a
	push	af
	inc	sp
	call	_set_bkg_tiles
	add	sp, #6
	pop	de
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:57: for (y = 0; y < 32; y++) {
	inc	d
	ld	a, d
	sub	a, #0x20
	jr	C, 00106$
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:60: for (x = 0; x < 20; x++) buf[x] = empty;
	ld	d, #0x00
00108$:
	ld	l, d
	ld	h, #0x00
	add	hl, bc
	ld	(hl), e
	inc	d
	ld	a, d
	sub	a, #0x14
	jr	C, 00108$
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:58: set_bkg_tiles(0, y, 32, 1, buf);
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:61: set_win_tiles(0, 0, 20, 1, buf);
	push	bc
	ld	hl, #0x114
	push	hl
	xor	a, a
	rrca
	push	af
	call	_set_win_tiles
	add	sp, #6
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:62: set_win_tiles(0, 1, 20, 1, buf);
	push	bc
	ld	hl, #0x114
	push	hl
	xor	a, a
	inc	a
	push	af
	call	_set_win_tiles
	add	sp, #6
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:64: draw_bg_text("CONGRATULATIONS", 2, 7);
	ld	a, #0x07
	push	af
	inc	sp
	ld	a, #0x02
	ld	de, #___str_1
	call	_draw_bg_text
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:65: draw_bg_text("YOU WIN", 6, 9);
	ld	a, #0x09
	push	af
	inc	sp
	ld	a, #0x06
	ld	de, #___str_2
	call	_draw_bg_text
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:66: draw_bg_text("PRESS START", 4, 11);
	ld	a, #0x0b
	push	af
	inc	sp
	ld	a, #0x04
	ld	de, #___str_3
	call	_draw_bg_text
;C:\dev\AI\robbo-port2\gb\src\gb\screens.c:67: }
	add	sp, #32
	ret
___str_1:
	.ascii "CONGRATULATIONS"
	.db 0x00
___str_2:
	.ascii "YOU WIN"
	.db 0x00
___str_3:
	.ascii "PRESS START"
	.db 0x00
	.area _CODE_9
	.area _INITIALIZER
	.area _CABS (ABS)
