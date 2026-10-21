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
	.globl b_render_victory
	.globl _render_victory
	.globl b_render_pause
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
_pan_active:
	.ds 1
_pan_delay:
	.ds 1
_pan_saved_x:
	.ds 1
_pan_saved_y:
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
;C:\dev\AI\robbo-port2\gb\src\main.c:41: static void pan_cancel(uint8_t restore)
;	---------------------------------
; Function pan_cancel
; ---------------------------------
_pan_cancel:
	ld	c, a
;C:\dev\AI\robbo-port2\gb\src\main.c:43: if (pan_active && restore) {
	ld	a, (#_pan_active)
	or	a, a
	jr	Z, 00102$
	ld	a, c
	or	a, a
	jr	Z, 00102$
;C:\dev\AI\robbo-port2\gb\src\main.c:44: cam_x = pan_saved_x;
	ld	a, (#_pan_saved_x)
	ld	(#_cam_x),a
;C:\dev\AI\robbo-port2\gb\src\main.c:45: cam_y = pan_saved_y;
	ld	a, (#_pan_saved_y)
	ld	(#_cam_y),a
00102$:
;C:\dev\AI\robbo-port2\gb\src\main.c:47: pan_active = 0;
;C:\dev\AI\robbo-port2\gb\src\main.c:48: pan_delay = 0;
	xor	a, a
	ld	(#_pan_active), a
	ld	(#_pan_delay),a
;C:\dev\AI\robbo-port2\gb\src\main.c:49: }
	ret
;C:\dev\AI\robbo-port2\gb\src\main.c:51: static void pan_step(uint8_t dir)
;	---------------------------------
; Function pan_step
; ---------------------------------
_pan_step:
	ld	c, a
;C:\dev\AI\robbo-port2\gb\src\main.c:54: uint8_t max_y = (level_height > VIEW_ROWS) ? (level_height - VIEW_ROWS) : 0;
	ld	a, #0x08
	ld	hl, #_level_height
	sub	a, (hl)
	jr	NC, 00122$
	ld	a, (hl)
	add	a, #0xf8
	ld	b, a
	jr	00123$
00122$:
	ld	b, #0x00
00123$:
;C:\dev\AI\robbo-port2\gb\src\main.c:56: if (dir == 0) {
	ld	a, c
	or	a, a
	jr	NZ, 00118$
;C:\dev\AI\robbo-port2\gb\src\main.c:57: if (cam_x < max_x) cam_x++;
	ld	hl, #_cam_x
	ld	a, (hl)
	sub	a, #0x06
	ret	NC
	inc	(hl)
	ret
00118$:
;C:\dev\AI\robbo-port2\gb\src\main.c:58: } else if (dir == 1) {
	ld	a, c
	dec	a
	jr	NZ, 00115$
;C:\dev\AI\robbo-port2\gb\src\main.c:59: if (cam_y < max_y) cam_y++;
	ld	hl, #_cam_y
	ld	a, (hl)
	sub	a, b
	ret	NC
	inc	(hl)
	ret
00115$:
;C:\dev\AI\robbo-port2\gb\src\main.c:60: } else if (dir == 2) {
	ld	a, c
	sub	a, #0x02
	jr	NZ, 00112$
;C:\dev\AI\robbo-port2\gb\src\main.c:61: if (cam_x > 0) cam_x--;
	ld	hl, #_cam_x
	ld	a, (hl)
	or	a, a
	ret	Z
	dec	(hl)
	ret
00112$:
;C:\dev\AI\robbo-port2\gb\src\main.c:62: } else if (dir == 3) {
	ld	a, c
	sub	a, #0x03
	ret	NZ
;C:\dev\AI\robbo-port2\gb\src\main.c:63: if (cam_y > 0) cam_y--;
	ld	hl, #_cam_y
	ld	a, (hl)
	or	a, a
	ret	Z
	dec	(hl)
;C:\dev\AI\robbo-port2\gb\src\main.c:65: }
	ret
;C:\dev\AI\robbo-port2\gb\src\main.c:67: static void wait_vbl(void)
;	---------------------------------
; Function wait_vbl
; ---------------------------------
_wait_vbl:
;C:\dev\AI\robbo-port2\gb\src\main.c:69: VBL_DONE = 0;
	xor	a, a
	ldh	(__vbl_done + 0), a
;C:\dev\AI\robbo-port2\gb\src\main.c:70: while (!VBL_DONE) {}
00101$:
	ld	a, (#__vbl_done)
	or	a, a
	jr	Z, 00101$
;C:\dev\AI\robbo-port2\gb\src\main.c:71: }
	ret
;C:\dev\AI\robbo-port2\gb\src\main.c:73: void main(void)
;	---------------------------------
; Function main
; ---------------------------------
_main::
	add	sp, #-7
;C:\dev\AI\robbo-port2\gb\src\main.c:75: uint8_t pad, prev = 0;
	ldhl	sp,	#6
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\main.c:79: DISPLAY_OFF;
	call	_display_off
;C:\dev\AI\robbo-port2\gb\src\main.c:80: sound_init();
	ld	e, #b_sound_init
	ld	hl, #_sound_init
	call	___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\main.c:81: game_init();
	call	_game_init
;C:\dev\AI\robbo-port2\gb\src\main.c:82: DISPLAY_ON;
	ldh	a, (_LCDC_REG + 0)
	or	a, #0x80
	ldh	(_LCDC_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\main.c:84: sound_time = sys_time;
	ld	a, (#_sys_time)
	ldhl	sp,	#2
	ld	(hl), a
	ld	a, (#_sys_time + 1)
	ldhl	sp,	#3
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\main.c:86: while (1) {
00203$:
;C:\dev\AI\robbo-port2\gb\src\main.c:87: wait_vbl();
	call	_wait_vbl
;C:\dev\AI\robbo-port2\gb\src\main.c:88: debug_ticks++;
	ld	hl, #_debug_ticks
	inc	(hl)
	jr	NZ, 00564$
	inc	hl
	inc	(hl)
00564$:
;C:\dev\AI\robbo-port2\gb\src\main.c:94: uint16_t now = sys_time;
	ld	a, (_sys_time)
	ld	c, a
	ld	hl, #_sys_time + 1
	ld	b, (hl)
;C:\dev\AI\robbo-port2\gb\src\main.c:95: uint8_t elapsed = (uint8_t)(now - sound_time);
	ldhl	sp,	#5
	ld	(hl), c
	ldhl	sp,	#2
	ld	e, (hl)
	ldhl	sp,	#5
	ld	a, (hl)
	sub	a, e
;C:\dev\AI\robbo-port2\gb\src\main.c:96: sound_time = now;
	ldhl	sp,	#2
	ld	(hl), c
	inc	hl
	ld	(hl), b
;C:\dev\AI\robbo-port2\gb\src\main.c:97: if (elapsed > 4) elapsed = 4;
	cp	a, #0x05
	jr	C, 00215$
	ld	a, #0x04
;C:\dev\AI\robbo-port2\gb\src\main.c:98: while (elapsed--) sfx_update();
00215$:
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
;C:\dev\AI\robbo-port2\gb\src\main.c:101: if (game_complete) {
	ld	a, (#_game_complete)
	or	a, a
	jr	Z, 00110$
;C:\dev\AI\robbo-port2\gb\src\main.c:102: pad = joypad();
	call	_joypad
;C:\dev\AI\robbo-port2\gb\src\main.c:103: if ((pad & (J_START | J_SELECT)) && !(prev & (J_START | J_SELECT))) {
	ldhl	sp,#5
	ld	(hl), a
	ld	a, (hl)
	and	a, #0xc0
	jr	Z, 00107$
	ldhl	sp,	#6
	ld	a, (hl)
;C:\dev\AI\robbo-port2\gb\src\main.c:104: game_complete = 0;
	and	a,#0xc0
	jr	NZ, 00107$
	ld	(#_game_complete),a
;C:\dev\AI\robbo-port2\gb\src\main.c:105: level = 1;
	ld	hl, #_level
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\main.c:106: pan_cancel(0);
	xor	a, a
	call	_pan_cancel
;C:\dev\AI\robbo-port2\gb\src\main.c:107: paused = 0;
;C:\dev\AI\robbo-port2\gb\src\main.c:108: move_delay = 0;
	xor	a, a
	ld	(#_paused), a
	ld	(#_move_delay),a
;C:\dev\AI\robbo-port2\gb\src\main.c:109: tick_timer = 0;
	xor	a, a
	ld	(#_tick_timer),a
;C:\dev\AI\robbo-port2\gb\src\main.c:110: DISPLAY_OFF;
	call	_display_off
;C:\dev\AI\robbo-port2\gb\src\main.c:111: game_load_level(level);
	ld	a, (_level)
	call	_game_load_level
;C:\dev\AI\robbo-port2\gb\src\main.c:112: DISPLAY_ON;
	ldh	a, (_LCDC_REG + 0)
	or	a, #0x80
	ldh	(_LCDC_REG + 0), a
00107$:
;C:\dev\AI\robbo-port2\gb\src\main.c:114: prev = pad;
	ldhl	sp,	#5
	ld	a, (hl+)
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\main.c:115: continue;
	jp	00203$
00110$:
;C:\dev\AI\robbo-port2\gb\src\main.c:119: if (!pan_active) render_camera();
	ld	a, (#_pan_active)
	or	a, a
	jr	NZ, 00112$
	call	_render_camera
00112$:
;C:\dev\AI\robbo-port2\gb\src\main.c:120: render_apply_camera();
	call	_render_apply_camera
;C:\dev\AI\robbo-port2\gb\src\main.c:121: game_teleport_camera_ready();
	call	_game_teleport_camera_ready
;C:\dev\AI\robbo-port2\gb\src\main.c:122: render_sync_rows();
	call	_render_sync_rows
;C:\dev\AI\robbo-port2\gb\src\main.c:123: if (pause_draw) {
	ld	hl, #_pause_draw
	ld	a, (hl)
	or	a, a
	jr	Z, 00116$
;C:\dev\AI\robbo-port2\gb\src\main.c:124: pause_draw = 0;
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\main.c:125: render_pause();
	ld	e, #b_render_pause
	ld	hl, #_render_pause
	call	___sdcc_bcall_ehl
	jr	00117$
00116$:
;C:\dev\AI\robbo-port2\gb\src\main.c:126: } else if (hud_dirty) {
	ld	hl, #_hud_dirty
	ld	a, (hl)
	or	a, a
	jr	Z, 00117$
;C:\dev\AI\robbo-port2\gb\src\main.c:127: hud_dirty = 0;
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\main.c:128: render_hud();
	call	_render_hud
00117$:
;C:\dev\AI\robbo-port2\gb\src\main.c:130: render_flush_cells();
	call	_render_flush_cells
;C:\dev\AI\robbo-port2\gb\src\main.c:132: pad = joypad();
	call	_joypad
;C:\dev\AI\robbo-port2\gb\src\main.c:133: debug_pad = pad;
	ldhl	sp,#4
	ld	(hl), a
	ld	a, (hl)
	ld	hl, #_debug_pad
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\main.c:135: if ((pad & J_START) && !(prev & J_START)) {
	push	hl
	ldhl	sp,	#6
	bit	7, (hl)
	pop	hl
	jr	Z, 00122$
	push	hl
	ldhl	sp,	#8
	bit	7, (hl)
	pop	hl
	jr	NZ, 00122$
;C:\dev\AI\robbo-port2\gb\src\main.c:136: paused = !paused;
	ld	hl, #_paused
	ld	a, (hl)
	sub	a, #0x01
	ld	a, #0x00
	rla
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\main.c:137: pan_cancel(1);
	ld	a, #0x01
	call	_pan_cancel
;C:\dev\AI\robbo-port2\gb\src\main.c:138: if (paused) pause_draw = 1;
	ld	a, (#_paused)
	or	a, a
	jr	Z, 00119$
	ld	hl, #_pause_draw
	ld	(hl), #0x01
	jr	00122$
00119$:
;C:\dev\AI\robbo-port2\gb\src\main.c:139: else hud_dirty = 1;
	ld	hl, #_hud_dirty
	ld	(hl), #0x01
00122$:
;C:\dev\AI\robbo-port2\gb\src\main.c:142: if ((pad & J_SELECT) && !(prev & J_SELECT)) {
	ldhl	sp,	#4
	ld	a, (hl)
	and	a, #0x40
	ld	c, a
	ld	b, #0x00
	ld	a, b
	or	a, c
	jp	Z, 00145$
	push	hl
	inc	hl
	inc	hl
	bit	6, (hl)
	pop	hl
	jp	NZ, 00145$
;C:\dev\AI\robbo-port2\gb\src\main.c:143: if (pad & J_A) {
	push	hl
	ldhl	sp,	#6
	bit	4, (hl)
	pop	hl
	jr	Z, 00142$
;C:\dev\AI\robbo-port2\gb\src\main.c:144: level = 30;
	ld	hl, #_level
	ld	(hl), #0x1e
	jp	00143$
00142$:
;C:\dev\AI\robbo-port2\gb\src\main.c:145: } else if (pad & J_B) {
	push	hl
	ldhl	sp,	#6
	bit	5, (hl)
	pop	hl
	jr	Z, 00139$
;C:\dev\AI\robbo-port2\gb\src\main.c:146: level = 1;
	ld	hl, #_level
	ld	(hl), #0x01
	jp	00143$
00139$:
;C:\dev\AI\robbo-port2\gb\src\main.c:147: } else if (pad & J_RIGHT) {
	push	hl
	ldhl	sp,	#6
	bit	0, (hl)
	pop	hl
	jr	Z, 00136$
;C:\dev\AI\robbo-port2\gb\src\main.c:148: level = (level + 10 > LEVEL_COUNT) ? LEVEL_COUNT : (level + 10);
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
	jr	NC, 00207$
	ld	e, #0x38
	jr	00208$
00207$:
	ld	a, (_level)
	add	a, #0x0a
	ld	e, a
00208$:
	ld	hl, #_level
	ld	(hl), e
	jr	00143$
00136$:
;C:\dev\AI\robbo-port2\gb\src\main.c:149: } else if (pad & J_LEFT) {
	push	hl
	ldhl	sp,	#6
	bit	1, (hl)
	pop	hl
	jr	Z, 00133$
;C:\dev\AI\robbo-port2\gb\src\main.c:150: level = (level > 10) ? (level - 10) : 1;
	ld	a, #0x0a
	ld	hl, #_level
	sub	a, (hl)
	jr	NC, 00209$
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
	jr	00210$
00209$:
	ldhl	sp,	#5
	ld	a, #0x01
	ld	(hl+), a
	xor	a, a
	ld	(hl), a
00210$:
	ldhl	sp,	#5
	ld	a, (hl)
	ld	(#_level),a
	jr	00143$
00133$:
;C:\dev\AI\robbo-port2\gb\src\main.c:151: } else if (pad & J_UP) {
	push	hl
	ldhl	sp,	#6
	bit	2, (hl)
	pop	hl
	jr	Z, 00130$
;C:\dev\AI\robbo-port2\gb\src\main.c:152: level = (level > 1) ? (level - 1) : LEVEL_COUNT;
	ld	a, #0x01
	ld	hl, #_level
	sub	a, (hl)
	jr	NC, 00211$
	ld	a, (hl)
	ldhl	sp,	#6
	ld	(hl), a
	dec	(hl)
	ld	a, (hl-)
	ld	(hl+), a
	rlca
	sbc	a, a
	ld	(hl), a
	jr	00212$
00211$:
	ldhl	sp,	#5
	ld	a, #0x38
	ld	(hl+), a
	xor	a, a
	ld	(hl), a
00212$:
	ldhl	sp,	#5
	ld	a, (hl)
	ld	(#_level),a
	jr	00143$
00130$:
;C:\dev\AI\robbo-port2\gb\src\main.c:153: } else if (pad & J_DOWN) {
	push	hl
	ldhl	sp,	#6
	bit	3, (hl)
	pop	hl
	jr	Z, 00127$
;C:\dev\AI\robbo-port2\gb\src\main.c:154: level = 23;  /* bomb/question test level */
	ld	hl, #_level
	ld	(hl), #0x17
	jr	00143$
00127$:
;C:\dev\AI\robbo-port2\gb\src\main.c:156: level++;
	ld	hl, #_level
	inc	(hl)
;C:\dev\AI\robbo-port2\gb\src\main.c:157: if (level > LEVEL_COUNT) level = 1;
	ld	a, #0x38
	sub	a, (hl)
	jr	NC, 00143$
	ld	(hl), #0x01
00143$:
;C:\dev\AI\robbo-port2\gb\src\main.c:159: pan_cancel(0);
	xor	a, a
	call	_pan_cancel
;C:\dev\AI\robbo-port2\gb\src\main.c:160: DISPLAY_OFF;
	call	_display_off
;C:\dev\AI\robbo-port2\gb\src\main.c:161: game_load_level(level);
	ld	a, (_level)
	call	_game_load_level
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
	ldhl	sp,	#4
	ld	a, (hl+)
	inc	hl
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\main.c:167: continue;
	jp	00203$
00145$:
;C:\dev\AI\robbo-port2\gb\src\main.c:170: if (!paused && !(pad & J_SELECT)) {
	ld	a, (#_paused)
	or	a, a
	jp	NZ, 00193$
	ld	a, b
	or	a, c
	jp	NZ, 00193$
;C:\dev\AI\robbo-port2\gb\src\main.c:171: if (++tick_timer >= LOGIC_TICK_FRAMES) {
	ld	hl, #_tick_timer
	inc	(hl)
	ld	a, (hl)
	sub	a, #0x06
	jr	C, 00148$
;C:\dev\AI\robbo-port2\gb\src\main.c:172: tick_timer = 0;
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\main.c:173: game_tick();
	call	_game_tick
00148$:
;C:\dev\AI\robbo-port2\gb\src\main.c:176: if (pad & J_RIGHT) dir = 0;
	push	hl
	ldhl	sp,	#6
	bit	0, (hl)
	pop	hl
	jr	Z, 00159$
	ld	c, #0x00
	jr	00160$
00159$:
;C:\dev\AI\robbo-port2\gb\src\main.c:177: else if (pad & J_DOWN) dir = 1;
	push	hl
	ldhl	sp,	#6
	bit	3, (hl)
	pop	hl
	jr	Z, 00156$
	ld	c, #0x01
	jr	00160$
00156$:
;C:\dev\AI\robbo-port2\gb\src\main.c:178: else if (pad & J_LEFT) dir = 2;
	push	hl
	ldhl	sp,	#6
	bit	1, (hl)
	pop	hl
	jr	Z, 00153$
	ld	c, #0x02
	jr	00160$
00153$:
;C:\dev\AI\robbo-port2\gb\src\main.c:179: else if (pad & J_UP) dir = 3;
	push	hl
	ldhl	sp,	#6
	bit	2, (hl)
	pop	hl
;C:\dev\AI\robbo-port2\gb\src\main.c:180: else dir = 0xFF;
	ld	c, #0x03
	jr	NZ, 00160$
	ld	c, #0xff
00160$:
;C:\dev\AI\robbo-port2\gb\src\main.c:184: if ((pad & J_B) && !(prev & J_B) && !pan_active && !robbo_busy) {
	ldhl	sp,	#4
	ld	a, (hl)
	and	a, #0x20
	ld	b, a
	ld	e, #0x00
	ld	a, e
	or	a, b
	jr	Z, 00162$
	push	hl
	inc	hl
	inc	hl
	bit	5, (hl)
	pop	hl
	jr	NZ, 00162$
	ld	a, (#_pan_active)
	or	a, a
	jr	NZ, 00162$
	ld	a, (#_robbo_busy)
	or	a, a
	jr	NZ, 00162$
;C:\dev\AI\robbo-port2\gb\src\main.c:185: pan_active = 1;
	ld	hl, #_pan_active
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\main.c:186: pan_saved_x = cam_x;
	ld	a, (#_cam_x)
	ld	(#_pan_saved_x),a
;C:\dev\AI\robbo-port2\gb\src\main.c:187: pan_saved_y = cam_y;
	ld	a, (#_cam_y)
	ld	(#_pan_saved_y),a
;C:\dev\AI\robbo-port2\gb\src\main.c:188: pan_delay = 0;
;C:\dev\AI\robbo-port2\gb\src\main.c:189: move_delay = 0;
	xor	a, a
	ld	(#_pan_delay), a
	ld	(#_move_delay),a
00162$:
;C:\dev\AI\robbo-port2\gb\src\main.c:192: if (pan_active) {
	ld	a, (#_pan_active)
	or	a, a
	jr	Z, 00176$
;C:\dev\AI\robbo-port2\gb\src\main.c:193: if (!(pad & J_B)) {
	ld	a, e
	or	a, b
	jr	NZ, 00173$
;C:\dev\AI\robbo-port2\gb\src\main.c:194: cam_x = pan_saved_x;
	ld	a, (#_pan_saved_x)
	ld	(#_cam_x),a
;C:\dev\AI\robbo-port2\gb\src\main.c:195: cam_y = pan_saved_y;
	ld	a, (#_pan_saved_y)
	ld	(#_cam_y),a
;C:\dev\AI\robbo-port2\gb\src\main.c:196: pan_active = 0;
;C:\dev\AI\robbo-port2\gb\src\main.c:197: pan_delay = 0;
	xor	a, a
	ld	(#_pan_active), a
	ld	(#_pan_delay),a
	jr	00176$
00173$:
;C:\dev\AI\robbo-port2\gb\src\main.c:198: } else if (dir != 0xFF) {
	ld	a, c
	inc	a
	jr	Z, 00170$
;C:\dev\AI\robbo-port2\gb\src\main.c:199: if (pan_delay == 0) {
	ld	a, (#_pan_delay)
	or	a, a
	jr	NZ, 00167$
;C:\dev\AI\robbo-port2\gb\src\main.c:200: pan_step(dir);
	push	bc
	ld	a, c
	call	_pan_step
	pop	bc
;C:\dev\AI\robbo-port2\gb\src\main.c:201: pan_delay = PAN_REPEAT_FRAMES;
	ld	hl, #_pan_delay
	ld	(hl), #0x03
	jr	00176$
00167$:
;C:\dev\AI\robbo-port2\gb\src\main.c:203: pan_delay--;
	ld	hl, #_pan_delay
	dec	(hl)
	jr	00176$
00170$:
;C:\dev\AI\robbo-port2\gb\src\main.c:206: pan_delay = 0;
	xor	a, a
	ld	(#_pan_delay),a
00176$:
;C:\dev\AI\robbo-port2\gb\src\main.c:210: if (!pan_active && !robbo_busy && !robbo_no_move) {
	ld	a, (#_pan_active)
	or	a, a
	jr	NZ, 00193$
	ld	a, (#_robbo_busy)
	or	a, a
	jr	NZ, 00193$
	ld	hl, #_robbo_no_move
	ld	a, (hl)
	or	a, a
	jr	NZ, 00193$
;C:\dev\AI\robbo-port2\gb\src\main.c:198: } else if (dir != 0xFF) {
	ld	a, c
	inc	a
	ld	a, #0x01
	jr	Z, 00587$
	xor	a, a
00587$:
	ld	b, a
;C:\dev\AI\robbo-port2\gb\src\main.c:211: uint8_t fire_held = pad & J_A;
	push	hl
	ldhl	sp,	#6
	bit	4, (hl)
	pop	hl
	jr	Z, 00186$
;C:\dev\AI\robbo-port2\gb\src\main.c:213: if (fire_held) {
;C:\dev\AI\robbo-port2\gb\src\main.c:216: if (dir != 0xFF) {
	bit	0, b
	jr	NZ, 00178$
;C:\dev\AI\robbo-port2\gb\src\main.c:217: game_face(dir);
	ld	a, c
	call	_game_face
;C:\dev\AI\robbo-port2\gb\src\main.c:218: game_fire();
	call	_game_fire
00178$:
;C:\dev\AI\robbo-port2\gb\src\main.c:220: move_delay = 0;
	xor	a, a
	ld	(#_move_delay),a
	jr	00193$
00186$:
;C:\dev\AI\robbo-port2\gb\src\main.c:222: if (dir != 0xFF) {
	bit	0, b
	jr	NZ, 00183$
;C:\dev\AI\robbo-port2\gb\src\main.c:223: if (move_delay == 0) {
	ld	a, (#_move_delay)
	or	a, a
	jr	NZ, 00180$
;C:\dev\AI\robbo-port2\gb\src\main.c:224: game_try_move(dir);
	ld	a, c
	call	_game_try_move
;C:\dev\AI\robbo-port2\gb\src\main.c:225: game_check_enemies();
	call	_game_check_enemies
;C:\dev\AI\robbo-port2\gb\src\main.c:226: move_delay = MOVE_REPEAT_FRAMES;
	ld	hl, #_move_delay
	ld	(hl), #0x06
	jr	00193$
00180$:
;C:\dev\AI\robbo-port2\gb\src\main.c:228: move_delay--;
	ld	hl, #_move_delay
	dec	(hl)
	jr	00193$
00183$:
;C:\dev\AI\robbo-port2\gb\src\main.c:231: move_delay = 0;
	xor	a, a
	ld	(#_move_delay),a
00193$:
;C:\dev\AI\robbo-port2\gb\src\main.c:237: if (game_restart_requested) {
	ld	hl, #_game_restart_requested
	ld	a, (hl)
	or	a, a
	jr	Z, 00196$
;C:\dev\AI\robbo-port2\gb\src\main.c:238: game_restart_requested = 0;
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\main.c:239: pan_cancel(0);
	xor	a, a
	call	_pan_cancel
;C:\dev\AI\robbo-port2\gb\src\main.c:240: DISPLAY_OFF;
	call	_display_off
;C:\dev\AI\robbo-port2\gb\src\main.c:241: level = level_planet;
	ld	a, (#_level_planet)
	ld	hl, #_level
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\main.c:242: game_load_level(level);
	ld	a, (hl)
	call	_game_load_level
;C:\dev\AI\robbo-port2\gb\src\main.c:243: paused = 0;
;C:\dev\AI\robbo-port2\gb\src\main.c:244: move_delay = 0;
	xor	a, a
	ld	(#_paused), a
	ld	(#_move_delay),a
;C:\dev\AI\robbo-port2\gb\src\main.c:245: tick_timer = 0;
	xor	a, a
	ld	(#_tick_timer),a
;C:\dev\AI\robbo-port2\gb\src\main.c:246: DISPLAY_ON;
	ldh	a, (_LCDC_REG + 0)
	or	a, #0x80
	ldh	(_LCDC_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\main.c:247: prev = pad;
	ldhl	sp,	#4
	ld	a, (hl+)
	inc	hl
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\main.c:248: continue;
	jp	00203$
00196$:
;C:\dev\AI\robbo-port2\gb\src\main.c:251: if (game_level_advance_requested) {
	ld	hl, #_game_level_advance_requested
	ld	a, (hl)
	or	a, a
	jr	Z, 00201$
;C:\dev\AI\robbo-port2\gb\src\main.c:252: game_level_advance_requested = 0;
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\main.c:253: pan_cancel(0);
	xor	a, a
	call	_pan_cancel
;C:\dev\AI\robbo-port2\gb\src\main.c:254: if (level_planet >= LEVEL_COUNT) {
	ld	a, (#_level_planet)
	sub	a, #0x38
	jr	C, 00198$
;C:\dev\AI\robbo-port2\gb\src\main.c:255: game_complete = 1;
	ld	hl, #_game_complete
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\main.c:256: cam_x = 0;
;C:\dev\AI\robbo-port2\gb\src\main.c:257: cam_y = 0;
	xor	a, a
	ld	(#_cam_x), a
	ld	(#_cam_y),a
;C:\dev\AI\robbo-port2\gb\src\main.c:258: DISPLAY_OFF;
	call	_display_off
;C:\dev\AI\robbo-port2\gb\src\main.c:259: render_victory();
	ld	e, #b_render_victory
	ld	hl, #_render_victory
	call	___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\main.c:260: DISPLAY_ON;
	ldh	a, (_LCDC_REG + 0)
	or	a, #0x80
	ldh	(_LCDC_REG + 0), a
	jr	00199$
00198$:
;C:\dev\AI\robbo-port2\gb\src\main.c:262: level = level_planet + 1;
	ld	a, (_level_planet)
	inc	a
	ld	(#_level),a
;C:\dev\AI\robbo-port2\gb\src\main.c:263: DISPLAY_OFF;
	call	_display_off
;C:\dev\AI\robbo-port2\gb\src\main.c:264: game_load_level(level);
	ld	a, (_level)
	call	_game_load_level
;C:\dev\AI\robbo-port2\gb\src\main.c:265: DISPLAY_ON;
	ldh	a, (_LCDC_REG + 0)
	or	a, #0x80
	ldh	(_LCDC_REG + 0), a
00199$:
;C:\dev\AI\robbo-port2\gb\src\main.c:267: paused = 0;
;C:\dev\AI\robbo-port2\gb\src\main.c:268: move_delay = 0;
	xor	a, a
	ld	(#_paused), a
	ld	(#_move_delay),a
;C:\dev\AI\robbo-port2\gb\src\main.c:269: tick_timer = 0;
	xor	a, a
	ld	(#_tick_timer),a
;C:\dev\AI\robbo-port2\gb\src\main.c:270: prev = pad;
	ldhl	sp,	#4
	ld	a, (hl+)
	inc	hl
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\main.c:271: continue;
	jp	00203$
00201$:
;C:\dev\AI\robbo-port2\gb\src\main.c:274: prev = pad;
	ldhl	sp,	#4
	ld	a, (hl+)
	inc	hl
	ld	(hl), a
	jp	00203$
;C:\dev\AI\robbo-port2\gb\src\main.c:276: }
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
__xinit__pan_active:
	.db #0x00	; 0
__xinit__pan_delay:
	.db #0x00	; 0
__xinit__pan_saved_x:
	.db #0x00	; 0
__xinit__pan_saved_y:
	.db #0x00	; 0
	.area _CABS (ABS)
