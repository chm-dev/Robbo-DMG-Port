;--------------------------------------------------------
; File Created by SDCC : free open source ISO C Compiler
; Version 4.5.1 #15267 (MINGW64)
;--------------------------------------------------------
	.module main
	
;--------------------------------------------------------
; Public variables in this module
;--------------------------------------------------------
	.globl _main
	.globl _render_flush_cells
	.globl _render_sync_rows
	.globl _render_apply_camera
	.globl _render_camera
	.globl _render_victory
	.globl _render_pause
	.globl _render_hud
	.globl _game_teleport_camera_ready
	.globl _game_check_enemies
	.globl _game_face
	.globl _game_fire
	.globl _game_try_move
	.globl _game_tick
	.globl _game_load_level
	.globl _game_init
	.globl _display_off
	.globl _joypad
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
_level:
	.ds 1
_paused:
	.ds 1
_move_delay:
	.ds 1
_tick_timer:
	.ds 1
_pause_draw:
	.ds 1
_game_complete:
	.ds 1
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
	.area _CODE
;C:\dev\AI\robbo-port2\gb\src\main.c:33: static void wait_vbl(void)
;	---------------------------------
; Function wait_vbl
; ---------------------------------
_wait_vbl:
;C:\dev\AI\robbo-port2\gb\src\main.c:35: VBL_DONE = 0;
	xor	a, a
	ldh	(__vbl_done + 0), a
;C:\dev\AI\robbo-port2\gb\src\main.c:36: while (!VBL_DONE) {}
00101$:
	ld	a, (#__vbl_done)
	or	a, a
	jr	Z, 00101$
;C:\dev\AI\robbo-port2\gb\src\main.c:37: }
	ret
;C:\dev\AI\robbo-port2\gb\src\main.c:39: void main(void)
;	---------------------------------
; Function main
; ---------------------------------
_main::
	dec	sp
	dec	sp
;C:\dev\AI\robbo-port2\gb\src\main.c:41: uint8_t pad, prev = 0;
	ldhl	sp,	#0
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\main.c:44: DISPLAY_OFF;
	call	_display_off
;C:\dev\AI\robbo-port2\gb\src\main.c:45: game_init();
	call	_game_init
;C:\dev\AI\robbo-port2\gb\src\main.c:46: DISPLAY_ON;
	ldh	a, (_LCDC_REG + 0)
	or	a, #0x80
	ldh	(_LCDC_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\main.c:48: while (1) {
00178$:
;C:\dev\AI\robbo-port2\gb\src\main.c:49: wait_vbl();
	call	_wait_vbl
;C:\dev\AI\robbo-port2\gb\src\main.c:50: debug_ticks++;
	ld	hl, #_debug_ticks
	inc	(hl)
	jr	NZ, 00440$
	inc	hl
	inc	(hl)
00440$:
;C:\dev\AI\robbo-port2\gb\src\main.c:52: if (game_complete) {
	ld	a, (#_game_complete)
	or	a, a
	jr	Z, 00105$
;C:\dev\AI\robbo-port2\gb\src\main.c:53: pad = joypad();
	call	_joypad
;C:\dev\AI\robbo-port2\gb\src\main.c:54: if ((pad & (J_START | J_SELECT)) && !(prev & (J_START | J_SELECT))) {
	ldhl	sp,#1
	ld	(hl), a
	ld	a, (hl)
	and	a, #0xc0
	jr	Z, 00102$
	ldhl	sp,	#0
	ld	a, (hl)
;C:\dev\AI\robbo-port2\gb\src\main.c:55: game_complete = 0;
	and	a,#0xc0
	jr	NZ, 00102$
	ld	(#_game_complete),a
;C:\dev\AI\robbo-port2\gb\src\main.c:56: level = 1;
	ld	hl, #_level
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\main.c:57: paused = 0;
;C:\dev\AI\robbo-port2\gb\src\main.c:58: move_delay = 0;
	xor	a, a
	ld	(#_paused), a
	ld	(#_move_delay),a
;C:\dev\AI\robbo-port2\gb\src\main.c:59: tick_timer = 0;
	xor	a, a
	ld	(#_tick_timer),a
;C:\dev\AI\robbo-port2\gb\src\main.c:60: DISPLAY_OFF;
	call	_display_off
;C:\dev\AI\robbo-port2\gb\src\main.c:61: game_load_level(level);
	ld	a, (_level)
	call	_game_load_level
;C:\dev\AI\robbo-port2\gb\src\main.c:62: DISPLAY_ON;
	ldh	a, (_LCDC_REG + 0)
	or	a, #0x80
	ldh	(_LCDC_REG + 0), a
00102$:
;C:\dev\AI\robbo-port2\gb\src\main.c:64: prev = pad;
	ldhl	sp,	#1
	ld	a, (hl-)
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\main.c:65: continue;
	jr	00178$
00105$:
;C:\dev\AI\robbo-port2\gb\src\main.c:69: render_camera();
	call	_render_camera
;C:\dev\AI\robbo-port2\gb\src\main.c:70: render_apply_camera();
	call	_render_apply_camera
;C:\dev\AI\robbo-port2\gb\src\main.c:71: game_teleport_camera_ready();
	call	_game_teleport_camera_ready
;C:\dev\AI\robbo-port2\gb\src\main.c:72: render_sync_rows();
	call	_render_sync_rows
;C:\dev\AI\robbo-port2\gb\src\main.c:73: if (pause_draw) {
	ld	hl, #_pause_draw
	ld	a, (hl)
	or	a, a
	jr	Z, 00109$
;C:\dev\AI\robbo-port2\gb\src\main.c:74: pause_draw = 0;
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\main.c:75: render_pause();
	call	_render_pause
	jr	00110$
00109$:
;C:\dev\AI\robbo-port2\gb\src\main.c:76: } else if (hud_dirty) {
	ld	hl, #_hud_dirty
	ld	a, (hl)
	or	a, a
	jr	Z, 00110$
;C:\dev\AI\robbo-port2\gb\src\main.c:77: hud_dirty = 0;
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\main.c:78: render_hud();
	call	_render_hud
00110$:
;C:\dev\AI\robbo-port2\gb\src\main.c:80: render_flush_cells();
	call	_render_flush_cells
;C:\dev\AI\robbo-port2\gb\src\main.c:82: pad = joypad();
	call	_joypad
	ld	c, a
;C:\dev\AI\robbo-port2\gb\src\main.c:83: debug_pad = pad;
	ld	hl, #_debug_pad
	ld	(hl), c
;C:\dev\AI\robbo-port2\gb\src\main.c:85: if ((pad & J_START) && !(prev & J_START)) {
	bit	7, c
	jr	Z, 00115$
	push	hl
	ldhl	sp,	#2
	bit	7, (hl)
	pop	hl
	jr	NZ, 00115$
;C:\dev\AI\robbo-port2\gb\src\main.c:86: paused = !paused;
	ld	hl, #_paused
	ld	a, (hl)
	sub	a, #0x01
	ld	a, #0x00
	rla
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\main.c:87: if (paused) pause_draw = 1;
	ld	a, (hl)
	or	a, a
	jr	Z, 00112$
	ld	hl, #_pause_draw
	ld	(hl), #0x01
	jr	00115$
00112$:
;C:\dev\AI\robbo-port2\gb\src\main.c:88: else hud_dirty = 1;
	ld	hl, #_hud_dirty
	ld	(hl), #0x01
00115$:
;C:\dev\AI\robbo-port2\gb\src\main.c:91: if ((pad & J_SELECT) && !(prev & J_SELECT)) {
	ld	a, c
	and	a, #0x40
	ld	b, a
	ld	e, #0x00
	ld	a, e
	or	a, b
	jp	Z, 00138$
	push	hl
	ldhl	sp,	#2
	bit	6, (hl)
	pop	hl
	jp	NZ, 00138$
;C:\dev\AI\robbo-port2\gb\src\main.c:92: if (pad & J_A) {
	bit	4, c
	jr	Z, 00135$
;C:\dev\AI\robbo-port2\gb\src\main.c:93: level = 30;
	ld	hl, #_level
	ld	(hl), #0x1e
	jr	00136$
00135$:
;C:\dev\AI\robbo-port2\gb\src\main.c:94: } else if (pad & J_B) {
	bit	5, c
	jr	Z, 00132$
;C:\dev\AI\robbo-port2\gb\src\main.c:95: level = 1;
	ld	hl, #_level
	ld	(hl), #0x01
	jr	00136$
00132$:
;C:\dev\AI\robbo-port2\gb\src\main.c:96: } else if (pad & J_RIGHT) {
	bit	0, c
	jr	Z, 00129$
;C:\dev\AI\robbo-port2\gb\src\main.c:97: level = (level + 10 > LEVEL_COUNT) ? LEVEL_COUNT : (level + 10);
	ld	a, (_level)
	ld	h, #0x00
	ld	l, a
	ld	de, #0x000a
	add	hl, de
	ld	a, #0x38
	cp	a, l
	ld	a, #0x00
	sbc	a, h
	jr	NC, 00182$
	ld	e, #0x38
	jr	00183$
00182$:
	ld	a, (_level)
	add	a, #0x0a
	ld	e, a
00183$:
	ld	hl, #_level
	ld	(hl), e
	jr	00136$
00129$:
;C:\dev\AI\robbo-port2\gb\src\main.c:98: } else if (pad & J_LEFT) {
	bit	1, c
	jr	Z, 00126$
;C:\dev\AI\robbo-port2\gb\src\main.c:99: level = (level > 10) ? (level - 10) : 1;
	ld	a, #0x0a
	ld	hl, #_level
	sub	a, (hl)
	jr	NC, 00184$
	ld	a, (hl)
	add	a, #0xf6
	ld	b, a
	jr	00185$
00184$:
	ld	b, #0x01
00185$:
	ld	hl, #_level
	ld	(hl), b
	jr	00136$
00126$:
;C:\dev\AI\robbo-port2\gb\src\main.c:100: } else if (pad & J_UP) {
	bit	2, c
	jr	Z, 00123$
;C:\dev\AI\robbo-port2\gb\src\main.c:101: level = (level > 1) ? (level - 1) : LEVEL_COUNT;
	ld	a, #0x01
	ld	hl, #_level
	sub	a, (hl)
	jr	NC, 00186$
	ld	a, (hl)
	dec	a
	ld	b, a
	jr	00187$
00186$:
	ld	b, #0x38
00187$:
	ld	hl, #_level
	ld	(hl), b
	jr	00136$
00123$:
;C:\dev\AI\robbo-port2\gb\src\main.c:102: } else if (pad & J_DOWN) {
	bit	3, c
	jr	Z, 00120$
;C:\dev\AI\robbo-port2\gb\src\main.c:103: level = 23;  /* bomb/question test level */
	ld	hl, #_level
	ld	(hl), #0x17
	jr	00136$
00120$:
;C:\dev\AI\robbo-port2\gb\src\main.c:105: level++;
	ld	hl, #_level
	inc	(hl)
;C:\dev\AI\robbo-port2\gb\src\main.c:106: if (level > LEVEL_COUNT) level = 1;
	ld	a, #0x38
	sub	a, (hl)
	jr	NC, 00136$
	ld	(hl), #0x01
00136$:
;C:\dev\AI\robbo-port2\gb\src\main.c:108: DISPLAY_OFF;
	call	_display_off
;C:\dev\AI\robbo-port2\gb\src\main.c:109: game_load_level(level);
	push	bc
	ld	a, (_level)
	call	_game_load_level
	pop	bc
;C:\dev\AI\robbo-port2\gb\src\main.c:110: paused = 0;
;C:\dev\AI\robbo-port2\gb\src\main.c:111: move_delay = 0;
	xor	a, a
	ld	(#_paused), a
	ld	(#_move_delay),a
;C:\dev\AI\robbo-port2\gb\src\main.c:112: tick_timer = 0;
	xor	a, a
	ld	(#_tick_timer),a
;C:\dev\AI\robbo-port2\gb\src\main.c:113: DISPLAY_ON;
	ldh	a, (_LCDC_REG + 0)
	or	a, #0x80
	ldh	(_LCDC_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\main.c:114: prev = pad;
	ldhl	sp,	#0
	ld	(hl), c
;C:\dev\AI\robbo-port2\gb\src\main.c:115: continue;
	jp	00178$
00138$:
;C:\dev\AI\robbo-port2\gb\src\main.c:118: if (!paused && !(pad & J_SELECT)) {
	ld	a, (#_paused)
	or	a, a
	jp	NZ, 00168$
	ld	a, e
	or	a, b
	jp	NZ, 00168$
;C:\dev\AI\robbo-port2\gb\src\main.c:119: if (++tick_timer >= LOGIC_TICK_FRAMES) {
	ld	hl, #_tick_timer
	inc	(hl)
	ld	a, (hl)
	sub	a, #0x06
	jr	C, 00141$
;C:\dev\AI\robbo-port2\gb\src\main.c:120: tick_timer = 0;
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\main.c:121: game_tick();
	push	bc
	call	_game_tick
	pop	bc
00141$:
;C:\dev\AI\robbo-port2\gb\src\main.c:124: if (!robbo_busy) {
	ld	a, (#_robbo_busy)
	or	a, a
	jr	NZ, 00168$
;C:\dev\AI\robbo-port2\gb\src\main.c:125: uint8_t fire_held = pad & (J_A | J_B);
	ld	a, c
	and	a, #0x30
	ld	b, a
;C:\dev\AI\robbo-port2\gb\src\main.c:127: if (pad & J_RIGHT) dir = 0;
	bit	0, c
	jr	Z, 00152$
	ld	e, #0x00
	jr	00153$
00152$:
;C:\dev\AI\robbo-port2\gb\src\main.c:128: else if (pad & J_DOWN) dir = 1;
	bit	3, c
	jr	Z, 00149$
	ld	e, #0x01
	jr	00153$
00149$:
;C:\dev\AI\robbo-port2\gb\src\main.c:129: else if (pad & J_LEFT) dir = 2;
	bit	1, c
	jr	Z, 00146$
	ld	e, #0x02
	jr	00153$
00146$:
;C:\dev\AI\robbo-port2\gb\src\main.c:130: else if (pad & J_UP) dir = 3;
	bit	2, c
;C:\dev\AI\robbo-port2\gb\src\main.c:131: else dir = 0xFF;
	ld	e, #0x03
	jr	NZ, 00153$
	ld	e, #0xff
00153$:
;C:\dev\AI\robbo-port2\gb\src\main.c:136: if (dir != 0xFF) {
	ld	a, e
	inc	a
	ld	a, #0x01
	jr	Z, 00460$
	xor	a, a
00460$:
	ld	d, a
;C:\dev\AI\robbo-port2\gb\src\main.c:133: if (fire_held) {
	ld	a, b
	or	a, a
	jr	Z, 00163$
;C:\dev\AI\robbo-port2\gb\src\main.c:136: if (dir != 0xFF) {
	bit	0, d
	jr	NZ, 00155$
;C:\dev\AI\robbo-port2\gb\src\main.c:137: game_face(dir);
	push	bc
	ld	a, e
	call	_game_face
;C:\dev\AI\robbo-port2\gb\src\main.c:138: game_fire();
	call	_game_fire
	pop	bc
00155$:
;C:\dev\AI\robbo-port2\gb\src\main.c:140: move_delay = 0;
	xor	a, a
	ld	(#_move_delay),a
	jr	00168$
00163$:
;C:\dev\AI\robbo-port2\gb\src\main.c:142: if (dir != 0xFF) {
	bit	0, d
	jr	NZ, 00160$
;C:\dev\AI\robbo-port2\gb\src\main.c:143: if (move_delay == 0) {
	ld	a, (#_move_delay)
	or	a, a
	jr	NZ, 00157$
;C:\dev\AI\robbo-port2\gb\src\main.c:144: game_try_move(dir);
	push	bc
	ld	a, e
	call	_game_try_move
;C:\dev\AI\robbo-port2\gb\src\main.c:145: game_check_enemies();
	call	_game_check_enemies
	pop	bc
;C:\dev\AI\robbo-port2\gb\src\main.c:146: move_delay = MOVE_REPEAT_FRAMES;
	ld	hl, #_move_delay
	ld	(hl), #0x06
	jr	00168$
00157$:
;C:\dev\AI\robbo-port2\gb\src\main.c:148: move_delay--;
	ld	hl, #_move_delay
	dec	(hl)
	jr	00168$
00160$:
;C:\dev\AI\robbo-port2\gb\src\main.c:151: move_delay = 0;
	xor	a, a
	ld	(#_move_delay),a
00168$:
;C:\dev\AI\robbo-port2\gb\src\main.c:157: if (game_restart_requested) {
	ld	hl, #_game_restart_requested
	ld	a, (hl)
	or	a, a
	jr	Z, 00171$
;C:\dev\AI\robbo-port2\gb\src\main.c:158: game_restart_requested = 0;
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\main.c:159: DISPLAY_OFF;
	call	_display_off
;C:\dev\AI\robbo-port2\gb\src\main.c:160: level = level_planet;
	ld	a, (#_level_planet)
	ld	hl, #_level
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\main.c:161: game_load_level(level);
	push	bc
	ld	a, (hl)
	call	_game_load_level
	pop	bc
;C:\dev\AI\robbo-port2\gb\src\main.c:162: paused = 0;
;C:\dev\AI\robbo-port2\gb\src\main.c:163: move_delay = 0;
	xor	a, a
	ld	(#_paused), a
	ld	(#_move_delay),a
;C:\dev\AI\robbo-port2\gb\src\main.c:164: tick_timer = 0;
	xor	a, a
	ld	(#_tick_timer),a
;C:\dev\AI\robbo-port2\gb\src\main.c:165: DISPLAY_ON;
	ldh	a, (_LCDC_REG + 0)
	or	a, #0x80
	ldh	(_LCDC_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\main.c:166: prev = pad;
	ldhl	sp,	#0
	ld	(hl), c
;C:\dev\AI\robbo-port2\gb\src\main.c:167: continue;
	jp	00178$
00171$:
;C:\dev\AI\robbo-port2\gb\src\main.c:170: if (game_level_advance_requested) {
	ld	hl, #_game_level_advance_requested
	ld	a, (hl)
	or	a, a
	jr	Z, 00176$
;C:\dev\AI\robbo-port2\gb\src\main.c:171: game_level_advance_requested = 0;
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\main.c:172: if (level_planet >= LEVEL_COUNT) {
	ld	a, (#_level_planet)
	sub	a, #0x38
	jr	C, 00173$
;C:\dev\AI\robbo-port2\gb\src\main.c:173: game_complete = 1;
	ld	hl, #_game_complete
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\main.c:174: cam_x = 0;
;C:\dev\AI\robbo-port2\gb\src\main.c:175: cam_y = 0;
	xor	a, a
	ld	(#_cam_x), a
	ld	(#_cam_y),a
;C:\dev\AI\robbo-port2\gb\src\main.c:176: DISPLAY_OFF;
	call	_display_off
;C:\dev\AI\robbo-port2\gb\src\main.c:177: render_victory();
	push	bc
	call	_render_victory
	pop	bc
;C:\dev\AI\robbo-port2\gb\src\main.c:178: DISPLAY_ON;
	ldh	a, (_LCDC_REG + 0)
	or	a, #0x80
	ldh	(_LCDC_REG + 0), a
	jr	00174$
00173$:
;C:\dev\AI\robbo-port2\gb\src\main.c:180: level = level_planet + 1;
	ld	a, (_level_planet)
	inc	a
	ld	(#_level),a
;C:\dev\AI\robbo-port2\gb\src\main.c:181: DISPLAY_OFF;
	call	_display_off
;C:\dev\AI\robbo-port2\gb\src\main.c:182: game_load_level(level);
	push	bc
	ld	a, (_level)
	call	_game_load_level
	pop	bc
;C:\dev\AI\robbo-port2\gb\src\main.c:183: DISPLAY_ON;
	ldh	a, (_LCDC_REG + 0)
	or	a, #0x80
	ldh	(_LCDC_REG + 0), a
00174$:
;C:\dev\AI\robbo-port2\gb\src\main.c:185: paused = 0;
;C:\dev\AI\robbo-port2\gb\src\main.c:186: move_delay = 0;
	xor	a, a
	ld	(#_paused), a
	ld	(#_move_delay),a
;C:\dev\AI\robbo-port2\gb\src\main.c:187: tick_timer = 0;
	xor	a, a
	ld	(#_tick_timer),a
;C:\dev\AI\robbo-port2\gb\src\main.c:188: prev = pad;
	ldhl	sp,	#0
	ld	(hl), c
;C:\dev\AI\robbo-port2\gb\src\main.c:189: continue;
	jp	00178$
00176$:
;C:\dev\AI\robbo-port2\gb\src\main.c:192: prev = pad;
	ldhl	sp,	#0
	ld	(hl), c
	jp	00178$
;C:\dev\AI\robbo-port2\gb\src\main.c:194: }
	inc	sp
	inc	sp
	ret
	.area _CODE
	.area _INITIALIZER
__xinit__level:
	.db #0x01	; 1
__xinit__paused:
	.db #0x00	; 0
__xinit__move_delay:
	.db #0x00	; 0
__xinit__tick_timer:
	.db #0x00	; 0
__xinit__pause_draw:
	.db #0x00	; 0
__xinit__game_complete:
	.db #0x00	; 0
	.area _CABS (ABS)
