;--------------------------------------------------------
; File Created by SDCC : free open source ISO C Compiler
; Version 4.5.1 #15267 (MINGW64)
;--------------------------------------------------------
	.module main
	
;--------------------------------------------------------
; Public variables in this module
;--------------------------------------------------------
	.globl _main
	.globl b_sfx_update
	.globl _sfx_update
	.globl b_sound_init
	.globl _sound_init
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
;C:\dev\AI\robbo-port2\gb\src\main.c:34: static void wait_vbl(void)
;	---------------------------------
; Function wait_vbl
; ---------------------------------
_wait_vbl:
;C:\dev\AI\robbo-port2\gb\src\main.c:36: VBL_DONE = 0;
	xor	a, a
	ldh	(__vbl_done + 0), a
;C:\dev\AI\robbo-port2\gb\src\main.c:37: while (!VBL_DONE) {}
00101$:
	ld	a, (#__vbl_done)
	or	a, a
	jr	Z, 00101$
;C:\dev\AI\robbo-port2\gb\src\main.c:38: }
	ret
;C:\dev\AI\robbo-port2\gb\src\main.c:40: void main(void)
;	---------------------------------
; Function main
; ---------------------------------
_main::
	add	sp, #-7
;C:\dev\AI\robbo-port2\gb\src\main.c:42: uint8_t pad, prev = 0;
	ldhl	sp,	#6
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\main.c:46: DISPLAY_OFF;
	call	_display_off
;C:\dev\AI\robbo-port2\gb\src\main.c:47: sound_init();
	ld	e, #b_sound_init
	ld	hl, #_sound_init
	call	___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\main.c:48: game_init();
	call	_game_init
;C:\dev\AI\robbo-port2\gb\src\main.c:49: DISPLAY_ON;
	ldh	a, (_LCDC_REG + 0)
	or	a, #0x80
	ldh	(_LCDC_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\main.c:51: sound_time = sys_time;
	ld	a, (#_sys_time)
	ldhl	sp,	#2
	ld	(hl), a
	ld	a, (#_sys_time + 1)
	ldhl	sp,	#3
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\main.c:53: while (1) {
00184$:
;C:\dev\AI\robbo-port2\gb\src\main.c:54: wait_vbl();
	call	_wait_vbl
;C:\dev\AI\robbo-port2\gb\src\main.c:55: debug_ticks++;
	ld	hl, #_debug_ticks
	inc	(hl)
	jr	NZ, 00475$
	inc	hl
	inc	(hl)
00475$:
;C:\dev\AI\robbo-port2\gb\src\main.c:61: uint16_t now = sys_time;
	ld	a, (_sys_time)
	ld	c, a
	ld	hl, #_sys_time + 1
	ld	b, (hl)
;C:\dev\AI\robbo-port2\gb\src\main.c:62: uint8_t elapsed = (uint8_t)(now - sound_time);
	ldhl	sp,	#5
	ld	(hl), c
	ldhl	sp,	#2
	ld	e, (hl)
	ldhl	sp,	#5
	ld	a, (hl)
	sub	a, e
;C:\dev\AI\robbo-port2\gb\src\main.c:63: sound_time = now;
	ldhl	sp,	#2
	ld	(hl), c
	inc	hl
	ld	(hl), b
;C:\dev\AI\robbo-port2\gb\src\main.c:64: if (elapsed > 4) elapsed = 4;
	cp	a, #0x05
	jr	C, 00196$
	ld	a, #0x04
;C:\dev\AI\robbo-port2\gb\src\main.c:65: while (elapsed--) sfx_update();
00196$:
	ld	c, a
00103$:
	ldhl	sp,	#5
	ld	(hl), c
	dec	c
	ld	a, (hl)
	or	a, a
	jr	Z, 00105$
	push	bc
	ld	e, #b_sfx_update
	ld	hl, #_sfx_update
	call	___sdcc_bcall_ehl
	pop	bc
	jr	00103$
00105$:
;C:\dev\AI\robbo-port2\gb\src\main.c:68: if (game_complete) {
	ld	a, (#_game_complete)
	or	a, a
	jr	Z, 00110$
;C:\dev\AI\robbo-port2\gb\src\main.c:69: pad = joypad();
	call	_joypad
;C:\dev\AI\robbo-port2\gb\src\main.c:70: if ((pad & (J_START | J_SELECT)) && !(prev & (J_START | J_SELECT))) {
	ldhl	sp,#5
	ld	(hl), a
	ld	a, (hl)
	and	a, #0xc0
	jr	Z, 00107$
	ldhl	sp,	#6
	ld	a, (hl)
;C:\dev\AI\robbo-port2\gb\src\main.c:71: game_complete = 0;
	and	a,#0xc0
	jr	NZ, 00107$
	ld	(#_game_complete),a
;C:\dev\AI\robbo-port2\gb\src\main.c:72: level = 1;
	ld	hl, #_level
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\main.c:73: paused = 0;
;C:\dev\AI\robbo-port2\gb\src\main.c:74: move_delay = 0;
	xor	a, a
	ld	(#_paused), a
	ld	(#_move_delay),a
;C:\dev\AI\robbo-port2\gb\src\main.c:75: tick_timer = 0;
	xor	a, a
	ld	(#_tick_timer),a
;C:\dev\AI\robbo-port2\gb\src\main.c:76: DISPLAY_OFF;
	call	_display_off
;C:\dev\AI\robbo-port2\gb\src\main.c:77: game_load_level(level);
	ld	a, (_level)
	call	_game_load_level
;C:\dev\AI\robbo-port2\gb\src\main.c:78: DISPLAY_ON;
	ldh	a, (_LCDC_REG + 0)
	or	a, #0x80
	ldh	(_LCDC_REG + 0), a
00107$:
;C:\dev\AI\robbo-port2\gb\src\main.c:80: prev = pad;
	ldhl	sp,	#5
	ld	a, (hl+)
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\main.c:81: continue;
	jr	00184$
00110$:
;C:\dev\AI\robbo-port2\gb\src\main.c:85: render_camera();
	call	_render_camera
;C:\dev\AI\robbo-port2\gb\src\main.c:86: render_apply_camera();
	call	_render_apply_camera
;C:\dev\AI\robbo-port2\gb\src\main.c:87: game_teleport_camera_ready();
	call	_game_teleport_camera_ready
;C:\dev\AI\robbo-port2\gb\src\main.c:88: render_sync_rows();
	call	_render_sync_rows
;C:\dev\AI\robbo-port2\gb\src\main.c:89: if (pause_draw) {
	ld	hl, #_pause_draw
	ld	a, (hl)
	or	a, a
	jr	Z, 00114$
;C:\dev\AI\robbo-port2\gb\src\main.c:90: pause_draw = 0;
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\main.c:91: render_pause();
	call	_render_pause
	jr	00115$
00114$:
;C:\dev\AI\robbo-port2\gb\src\main.c:92: } else if (hud_dirty) {
	ld	hl, #_hud_dirty
	ld	a, (hl)
	or	a, a
	jr	Z, 00115$
;C:\dev\AI\robbo-port2\gb\src\main.c:93: hud_dirty = 0;
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\main.c:94: render_hud();
	call	_render_hud
00115$:
;C:\dev\AI\robbo-port2\gb\src\main.c:96: render_flush_cells();
	call	_render_flush_cells
;C:\dev\AI\robbo-port2\gb\src\main.c:98: pad = joypad();
	call	_joypad
;C:\dev\AI\robbo-port2\gb\src\main.c:99: debug_pad = pad;
	ldhl	sp,#4
	ld	(hl), a
	ld	a, (hl)
	ld	hl, #_debug_pad
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\main.c:101: if ((pad & J_START) && !(prev & J_START)) {
	push	hl
	ldhl	sp,	#6
	bit	7, (hl)
	pop	hl
	jr	Z, 00120$
	push	hl
	ldhl	sp,	#8
	bit	7, (hl)
	pop	hl
	jr	NZ, 00120$
;C:\dev\AI\robbo-port2\gb\src\main.c:102: paused = !paused;
	ld	hl, #_paused
	ld	a, (hl)
	sub	a, #0x01
	ld	a, #0x00
	rla
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\main.c:103: if (paused) pause_draw = 1;
	ld	a, (hl)
	or	a, a
	jr	Z, 00117$
	ld	hl, #_pause_draw
	ld	(hl), #0x01
	jr	00120$
00117$:
;C:\dev\AI\robbo-port2\gb\src\main.c:104: else hud_dirty = 1;
	ld	hl, #_hud_dirty
	ld	(hl), #0x01
00120$:
;C:\dev\AI\robbo-port2\gb\src\main.c:107: if ((pad & J_SELECT) && !(prev & J_SELECT)) {
	ldhl	sp,	#4
	ld	a, (hl)
	and	a, #0x40
	ld	e, a
	ld	d, #0x00
	ld	a, d
	or	a, e
	jp	Z, 00143$
	push	hl
	inc	hl
	inc	hl
	bit	6, (hl)
	pop	hl
	jp	NZ, 00143$
;C:\dev\AI\robbo-port2\gb\src\main.c:108: if (pad & J_A) {
	push	hl
	ldhl	sp,	#6
	bit	4, (hl)
	pop	hl
	jr	Z, 00140$
;C:\dev\AI\robbo-port2\gb\src\main.c:109: level = 30;
	ld	hl, #_level
	ld	(hl), #0x1e
	jp	00141$
00140$:
;C:\dev\AI\robbo-port2\gb\src\main.c:110: } else if (pad & J_B) {
	push	hl
	ldhl	sp,	#6
	bit	5, (hl)
	pop	hl
	jr	Z, 00137$
;C:\dev\AI\robbo-port2\gb\src\main.c:111: level = 1;
	ld	hl, #_level
	ld	(hl), #0x01
	jp	00141$
00137$:
;C:\dev\AI\robbo-port2\gb\src\main.c:112: } else if (pad & J_RIGHT) {
	push	hl
	ldhl	sp,	#6
	bit	0, (hl)
	pop	hl
	jr	Z, 00134$
;C:\dev\AI\robbo-port2\gb\src\main.c:113: level = (level + 10 > LEVEL_COUNT) ? LEVEL_COUNT : (level + 10);
	ld	a, (#_level)
	ldhl	sp,	#0
	ld	(hl+), a
	ld	(hl), #0x00
	pop	de
	push	de
	ld	hl, #0x000a
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#7
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#6
	ld	(hl-), a
	ld	a, #0x38
	sub	a, (hl)
	inc	hl
	ld	a, #0x00
	sbc	a, (hl)
	jr	NC, 00188$
	ld	e, #0x38
	jr	00189$
00188$:
	ld	a, (_level)
	add	a, #0x0a
	ld	e, a
00189$:
	ld	hl, #_level
	ld	(hl), e
	jr	00141$
00134$:
;C:\dev\AI\robbo-port2\gb\src\main.c:114: } else if (pad & J_LEFT) {
	push	hl
	ldhl	sp,	#6
	bit	1, (hl)
	pop	hl
	jr	Z, 00131$
;C:\dev\AI\robbo-port2\gb\src\main.c:115: level = (level > 10) ? (level - 10) : 1;
	ld	a, #0x0a
	ld	hl, #_level
	sub	a, (hl)
	jr	NC, 00190$
	ld	a, (hl)
	ldhl	sp,	#6
	ld	(hl), a
	ld	a, (hl)
	add	a, #0xf6
	ld	(hl), a
	ld	a, (hl-)
	ld	(hl+), a
	rlca
	sbc	a, a
	ld	(hl), a
	jr	00191$
00190$:
	ldhl	sp,	#5
	ld	a, #0x01
	ld	(hl+), a
	xor	a, a
	ld	(hl), a
00191$:
	ldhl	sp,	#5
	ld	a, (hl)
	ld	(#_level),a
	jr	00141$
00131$:
;C:\dev\AI\robbo-port2\gb\src\main.c:116: } else if (pad & J_UP) {
	push	hl
	ldhl	sp,	#6
	bit	2, (hl)
	pop	hl
	jr	Z, 00128$
;C:\dev\AI\robbo-port2\gb\src\main.c:117: level = (level > 1) ? (level - 1) : LEVEL_COUNT;
	ld	a, #0x01
	ld	hl, #_level
	sub	a, (hl)
	jr	NC, 00192$
	ld	a, (hl)
	ldhl	sp,	#6
	ld	(hl), a
	dec	(hl)
	ld	a, (hl-)
	ld	(hl+), a
	rlca
	sbc	a, a
	ld	(hl), a
	jr	00193$
00192$:
	ldhl	sp,	#5
	ld	a, #0x38
	ld	(hl+), a
	xor	a, a
	ld	(hl), a
00193$:
	ldhl	sp,	#5
	ld	a, (hl)
	ld	(#_level),a
	jr	00141$
00128$:
;C:\dev\AI\robbo-port2\gb\src\main.c:118: } else if (pad & J_DOWN) {
	push	hl
	ldhl	sp,	#6
	bit	3, (hl)
	pop	hl
	jr	Z, 00125$
;C:\dev\AI\robbo-port2\gb\src\main.c:119: level = 23;  /* bomb/question test level */
	ld	hl, #_level
	ld	(hl), #0x17
	jr	00141$
00125$:
;C:\dev\AI\robbo-port2\gb\src\main.c:121: level++;
	ld	hl, #_level
	inc	(hl)
;C:\dev\AI\robbo-port2\gb\src\main.c:122: if (level > LEVEL_COUNT) level = 1;
	ld	a, #0x38
	sub	a, (hl)
	jr	NC, 00141$
	ld	(hl), #0x01
00141$:
;C:\dev\AI\robbo-port2\gb\src\main.c:124: DISPLAY_OFF;
	call	_display_off
;C:\dev\AI\robbo-port2\gb\src\main.c:125: game_load_level(level);
	ld	a, (_level)
	call	_game_load_level
;C:\dev\AI\robbo-port2\gb\src\main.c:126: paused = 0;
;C:\dev\AI\robbo-port2\gb\src\main.c:127: move_delay = 0;
	xor	a, a
	ld	(#_paused), a
	ld	(#_move_delay),a
;C:\dev\AI\robbo-port2\gb\src\main.c:128: tick_timer = 0;
	xor	a, a
	ld	(#_tick_timer),a
;C:\dev\AI\robbo-port2\gb\src\main.c:129: DISPLAY_ON;
	ldh	a, (_LCDC_REG + 0)
	or	a, #0x80
	ldh	(_LCDC_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\main.c:130: prev = pad;
	ldhl	sp,	#4
	ld	a, (hl+)
	inc	hl
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\main.c:131: continue;
	jp	00184$
00143$:
;C:\dev\AI\robbo-port2\gb\src\main.c:134: if (!paused && !(pad & J_SELECT)) {
	ld	a, (#_paused)
	or	a, a
	jp	NZ, 00174$
	ld	a, d
	or	a, e
	jp	NZ, 00174$
;C:\dev\AI\robbo-port2\gb\src\main.c:135: if (++tick_timer >= LOGIC_TICK_FRAMES) {
	ld	hl, #_tick_timer
	inc	(hl)
	ld	a, (hl)
	sub	a, #0x06
	jr	C, 00146$
;C:\dev\AI\robbo-port2\gb\src\main.c:136: tick_timer = 0;
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\main.c:137: game_tick();
	call	_game_tick
00146$:
;C:\dev\AI\robbo-port2\gb\src\main.c:140: if (!robbo_busy && !robbo_no_move) {
	ld	a, (#_robbo_busy)
	or	a, a
	jr	NZ, 00174$
	ld	a, (#_robbo_no_move)
	or	a, a
	jr	NZ, 00174$
;C:\dev\AI\robbo-port2\gb\src\main.c:141: uint8_t fire_held = pad & (J_A | J_B);
	ldhl	sp,	#4
	ld	a, (hl)
	and	a, #0x30
	ld	c, a
;C:\dev\AI\robbo-port2\gb\src\main.c:143: if (pad & J_RIGHT) dir = 0;
	push	hl
	bit	0, (hl)
	pop	hl
	jr	Z, 00157$
	ld	b, #0x00
	jr	00158$
00157$:
;C:\dev\AI\robbo-port2\gb\src\main.c:144: else if (pad & J_DOWN) dir = 1;
	push	hl
	ldhl	sp,	#6
	bit	3, (hl)
	pop	hl
	jr	Z, 00154$
	ld	b, #0x01
	jr	00158$
00154$:
;C:\dev\AI\robbo-port2\gb\src\main.c:145: else if (pad & J_LEFT) dir = 2;
	push	hl
	ldhl	sp,	#6
	bit	1, (hl)
	pop	hl
	jr	Z, 00151$
	ld	b, #0x02
	jr	00158$
00151$:
;C:\dev\AI\robbo-port2\gb\src\main.c:146: else if (pad & J_UP) dir = 3;
	push	hl
	ldhl	sp,	#6
	bit	2, (hl)
	pop	hl
	jr	Z, 00148$
	ld	b, #0x03
	jr	00158$
00148$:
;C:\dev\AI\robbo-port2\gb\src\main.c:147: else dir = 0xFF;
	ld	b, #0xff
00158$:
;C:\dev\AI\robbo-port2\gb\src\main.c:152: if (dir != 0xFF) {
	ld	a, b
	inc	a
	ld	a, #0x01
	jr	Z, 00495$
	xor	a, a
00495$:
	ld	e, a
;C:\dev\AI\robbo-port2\gb\src\main.c:149: if (fire_held) {
	ld	a, c
	or	a, a
	jr	Z, 00168$
;C:\dev\AI\robbo-port2\gb\src\main.c:152: if (dir != 0xFF) {
	bit	0, e
	jr	NZ, 00160$
;C:\dev\AI\robbo-port2\gb\src\main.c:153: game_face(dir);
	ld	a, b
	call	_game_face
;C:\dev\AI\robbo-port2\gb\src\main.c:154: game_fire();
	call	_game_fire
00160$:
;C:\dev\AI\robbo-port2\gb\src\main.c:156: move_delay = 0;
	xor	a, a
	ld	(#_move_delay),a
	jr	00174$
00168$:
;C:\dev\AI\robbo-port2\gb\src\main.c:158: if (dir != 0xFF) {
	bit	0, e
	jr	NZ, 00165$
;C:\dev\AI\robbo-port2\gb\src\main.c:159: if (move_delay == 0) {
	ld	a, (#_move_delay)
	or	a, a
	jr	NZ, 00162$
;C:\dev\AI\robbo-port2\gb\src\main.c:160: game_try_move(dir);
	ld	a, b
	call	_game_try_move
;C:\dev\AI\robbo-port2\gb\src\main.c:161: game_check_enemies();
	call	_game_check_enemies
;C:\dev\AI\robbo-port2\gb\src\main.c:162: move_delay = MOVE_REPEAT_FRAMES;
	ld	hl, #_move_delay
	ld	(hl), #0x06
	jr	00174$
00162$:
;C:\dev\AI\robbo-port2\gb\src\main.c:164: move_delay--;
	ld	hl, #_move_delay
	dec	(hl)
	jr	00174$
00165$:
;C:\dev\AI\robbo-port2\gb\src\main.c:167: move_delay = 0;
	xor	a, a
	ld	(#_move_delay),a
00174$:
;C:\dev\AI\robbo-port2\gb\src\main.c:173: if (game_restart_requested) {
	ld	hl, #_game_restart_requested
	ld	a, (hl)
	or	a, a
	jr	Z, 00177$
;C:\dev\AI\robbo-port2\gb\src\main.c:174: game_restart_requested = 0;
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\main.c:175: DISPLAY_OFF;
	call	_display_off
;C:\dev\AI\robbo-port2\gb\src\main.c:176: level = level_planet;
	ld	a, (#_level_planet)
	ld	hl, #_level
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\main.c:177: game_load_level(level);
	ld	a, (hl)
	call	_game_load_level
;C:\dev\AI\robbo-port2\gb\src\main.c:178: paused = 0;
;C:\dev\AI\robbo-port2\gb\src\main.c:179: move_delay = 0;
	xor	a, a
	ld	(#_paused), a
	ld	(#_move_delay),a
;C:\dev\AI\robbo-port2\gb\src\main.c:180: tick_timer = 0;
	xor	a, a
	ld	(#_tick_timer),a
;C:\dev\AI\robbo-port2\gb\src\main.c:181: DISPLAY_ON;
	ldh	a, (_LCDC_REG + 0)
	or	a, #0x80
	ldh	(_LCDC_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\main.c:182: prev = pad;
	ldhl	sp,	#4
	ld	a, (hl+)
	inc	hl
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\main.c:183: continue;
	jp	00184$
00177$:
;C:\dev\AI\robbo-port2\gb\src\main.c:186: if (game_level_advance_requested) {
	ld	hl, #_game_level_advance_requested
	ld	a, (hl)
	or	a, a
	jr	Z, 00182$
;C:\dev\AI\robbo-port2\gb\src\main.c:187: game_level_advance_requested = 0;
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\main.c:188: if (level_planet >= LEVEL_COUNT) {
	ld	a, (#_level_planet)
	sub	a, #0x38
	jr	C, 00179$
;C:\dev\AI\robbo-port2\gb\src\main.c:189: game_complete = 1;
	ld	hl, #_game_complete
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\main.c:190: cam_x = 0;
;C:\dev\AI\robbo-port2\gb\src\main.c:191: cam_y = 0;
	xor	a, a
	ld	(#_cam_x), a
	ld	(#_cam_y),a
;C:\dev\AI\robbo-port2\gb\src\main.c:192: DISPLAY_OFF;
	call	_display_off
;C:\dev\AI\robbo-port2\gb\src\main.c:193: render_victory();
	call	_render_victory
;C:\dev\AI\robbo-port2\gb\src\main.c:194: DISPLAY_ON;
	ldh	a, (_LCDC_REG + 0)
	or	a, #0x80
	ldh	(_LCDC_REG + 0), a
	jr	00180$
00179$:
;C:\dev\AI\robbo-port2\gb\src\main.c:196: level = level_planet + 1;
	ld	a, (_level_planet)
	inc	a
	ld	(#_level),a
;C:\dev\AI\robbo-port2\gb\src\main.c:197: DISPLAY_OFF;
	call	_display_off
;C:\dev\AI\robbo-port2\gb\src\main.c:198: game_load_level(level);
	ld	a, (_level)
	call	_game_load_level
;C:\dev\AI\robbo-port2\gb\src\main.c:199: DISPLAY_ON;
	ldh	a, (_LCDC_REG + 0)
	or	a, #0x80
	ldh	(_LCDC_REG + 0), a
00180$:
;C:\dev\AI\robbo-port2\gb\src\main.c:201: paused = 0;
;C:\dev\AI\robbo-port2\gb\src\main.c:202: move_delay = 0;
	xor	a, a
	ld	(#_paused), a
	ld	(#_move_delay),a
;C:\dev\AI\robbo-port2\gb\src\main.c:203: tick_timer = 0;
	xor	a, a
	ld	(#_tick_timer),a
;C:\dev\AI\robbo-port2\gb\src\main.c:204: prev = pad;
	ldhl	sp,	#4
	ld	a, (hl+)
	inc	hl
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\main.c:205: continue;
	jp	00184$
00182$:
;C:\dev\AI\robbo-port2\gb\src\main.c:208: prev = pad;
	ldhl	sp,	#4
	ld	a, (hl+)
	inc	hl
	ld	(hl), a
	jp	00184$
;C:\dev\AI\robbo-port2\gb\src\main.c:210: }
	add	sp, #7
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
