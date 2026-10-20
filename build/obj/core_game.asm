;--------------------------------------------------------
; File Created by SDCC : free open source ISO C Compiler
; Version 4.5.1 #15267 (MINGW64)
;--------------------------------------------------------
	.module game
	
;--------------------------------------------------------
; Public variables in this module
;--------------------------------------------------------
	.globl _render_cell
	.globl _render_apply_camera
	.globl _render_camera
	.globl _render_flash_set
	.globl _render_level
	.globl _render_init
	.globl _load_level_data
	.globl _game_level_advance_requested
	.globl _game_restart_requested
	.globl _anim_frame
	.globl _cam_pan_timer
	.globl _cam_target_y
	.globl _cam_target_x
	.globl _cam_override
	.globl _robbo_busy
	.globl _hud_dirty
	.globl _debug_ticks
	.globl _debug_pad
	.globl _cam_y
	.globl _cam_x
	.globl _keys
	.globl _ammo
	.globl _screws_left
	.globl _robbo_dir
	.globl _robbo_y
	.globl _robbo_x
	.globl _level_teleport_count
	.globl _level_planet
	.globl _level_screw
	.globl _level_height
	.globl _teleport_dest
	.globl _map_obj
	.globl _map_extra
	.globl _map_type
	.globl _game_init
	.globl _game_load_level
	.globl _game_teleport_camera_ready
	.globl _game_try_move
	.globl _game_check_enemies
	.globl _game_face
	.globl _game_fire
	.globl _game_tick
;--------------------------------------------------------
; special function registers
;--------------------------------------------------------
	.area _HRAM
;--------------------------------------------------------
; ram data
;--------------------------------------------------------
	.area _DATA
_map_type::
	.ds 496
_map_extra::
	.ds 496
_map_obj::
	.ds 496
_teleport_dest::
	.ds 128
_level_height::
	.ds 1
_level_screw::
	.ds 1
_level_planet::
	.ds 1
_level_teleport_count::
	.ds 1
_robbo_x::
	.ds 1
_robbo_y::
	.ds 1
_robbo_dir::
	.ds 1
_screws_left::
	.ds 1
_ammo::
	.ds 1
_keys::
	.ds 1
_cam_x::
	.ds 1
_cam_y::
	.ds 1
_debug_pad::
	.ds 1
_debug_ticks::
	.ds 2
_hud_dirty::
	.ds 1
_robbo_busy::
	.ds 1
_cam_override::
	.ds 1
_cam_target_x::
	.ds 1
_cam_target_y::
	.ds 1
_cam_pan_timer::
	.ds 1
_anim_frame::
	.ds 1
_sliding_boxes:
	.ds 64
_sliding_count:
	.ds 1
_bullet_cells:
	.ds 192
_turret_list:
	.ds 32
_enemy_list:
	.ds 80
_bomb_list:
	.ds 320
_explosion_list:
	.ds 992
_turret_count:
	.ds 1
_enemy_count:
	.ds 1
_bomb_count:
	.ds 1
_explosion_count:
	.ds 2
_bullet_count:
	.ds 1
;--------------------------------------------------------
; ram data
;--------------------------------------------------------
	.area _INITIALIZED
_fire_delay:
	.ds 1
_teleport_phase:
	.ds 1
_teleport_to:
	.ds 2
_robbo_dead:
	.ds 1
_death_timer:
	.ds 1
_screen_flash_ticks:
	.ds 1
_transition_active:
	.ds 1
_wipe_col:
	.ds 1
_game_restart_requested::
	.ds 1
_game_level_advance_requested::
	.ds 1
_rng_state:
	.ds 2
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
;C:\dev\AI\robbo-port2\gb\src\core\game.c:73: void game_init(void)
;	---------------------------------
; Function game_init
; ---------------------------------
_game_init::
;C:\dev\AI\robbo-port2\gb\src\core\game.c:75: render_init();
	call	_render_init
;C:\dev\AI\robbo-port2\gb\src\core\game.c:76: game_load_level(1);
	ld	a, #0x01
;C:\dev\AI\robbo-port2\gb\src\core\game.c:77: }
	jp	_game_load_level
;C:\dev\AI\robbo-port2\gb\src\core\game.c:79: void game_load_level(uint8_t level)
;	---------------------------------
; Function game_load_level
; ---------------------------------
_game_load_level::
;C:\dev\AI\robbo-port2\gb\src\core\game.c:84: if (level == 0) level = 1;
	or	a, a
	jr	NZ, 00102$
	ld	a, #0x01
00102$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:85: if (level > LEVEL_COUNT) level = LEVEL_COUNT;
	cp	a, #0x39
	jr	C, 00104$
	ld	a, #0x38
00104$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:87: load_level_data(level);
	call	_load_level_data
;C:\dev\AI\robbo-port2\gb\src\core\game.c:89: for (i = 0; i < MAP_CELLS; i++) {
	ld	bc, #0x0000
00110$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:90: map_obj[i] = 0;
	ld	hl, #_map_obj
	add	hl, bc
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\core\game.c:89: for (i = 0; i < MAP_CELLS; i++) {
	inc	bc
	ld	e, c
	ld	d, b
	ld	a, e
	sub	a, #0xf0
	ld	a, d
	sbc	a, #0x01
	jr	C, 00110$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:93: robbo_x = 2;
	ld	hl, #_robbo_x
	ld	(hl), #0x02
;C:\dev\AI\robbo-port2\gb\src\core\game.c:94: robbo_y = 2;
	ld	hl, #_robbo_y
	ld	(hl), #0x02
;C:\dev\AI\robbo-port2\gb\src\core\game.c:95: robbo_dir = 1;
	ld	hl, #_robbo_dir
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\core\game.c:96: for (y = 0; y < level_height; y++) {
	ld	c, #0x00
00115$:
	ld	a, c
	ld	hl, #_level_height
	sub	a, (hl)
	jr	NC, 00109$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:97: for (x = 0; x < MAP_W; x++) {
	ld	b, #0x00
00112$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:98: uint16_t idx = y * MAP_W + x;
	ld	l, c
	ld	h, #0x00
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	e, b
	ld	d, #0x00
	add	hl, de
	ld	e, l
	ld	d, h
;C:\dev\AI\robbo-port2\gb\src\core\game.c:99: if (map_type[idx] == CT_ROBBO) {
	ld	hl, #_map_type
	add	hl, de
	ld	a, (hl)
	sub	a, #0x1a
	jr	NZ, 00113$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:100: robbo_x = x;
	ld	hl, #_robbo_x
	ld	(hl), b
;C:\dev\AI\robbo-port2\gb\src\core\game.c:101: robbo_y = y;
	ld	hl, #_robbo_y
	ld	(hl), c
;C:\dev\AI\robbo-port2\gb\src\core\game.c:102: robbo_dir = map_extra[idx] & 3;
	ld	hl, #_map_extra
	add	hl, de
	ld	a, (hl)
	and	a, #0x03
	ld	(#_robbo_dir),a
00113$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:97: for (x = 0; x < MAP_W; x++) {
	inc	b
	ld	a, b
	sub	a, #0x10
	jr	C, 00112$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:96: for (y = 0; y < level_height; y++) {
	inc	c
	jr	00115$
00109$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:107: screws_left = level_screw;
	ld	a, (#_level_screw)
	ld	(#_screws_left),a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:108: ammo = 0;
;C:\dev\AI\robbo-port2\gb\src\core\game.c:109: keys = 0;
	xor	a, a
	ld	(#_ammo), a
	ld	(#_keys),a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:110: cam_x = 0;
;C:\dev\AI\robbo-port2\gb\src\core\game.c:111: cam_y = 0;
	xor	a, a
	ld	(#_cam_x), a
	ld	(#_cam_y),a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:112: sliding_count = 0;
;C:\dev\AI\robbo-port2\gb\src\core\game.c:113: bullet_count = 0;
	xor	a, a
	ld	(#_sliding_count), a
	ld	(#_bullet_count),a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:114: fire_delay = 0;
;C:\dev\AI\robbo-port2\gb\src\core\game.c:115: robbo_busy = 0;
	xor	a, a
	ld	(#_fire_delay), a
	ld	(#_robbo_busy),a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:116: teleport_phase = 0;
;C:\dev\AI\robbo-port2\gb\src\core\game.c:117: teleport_to = 0;
	xor	a, a
	ld	(#_teleport_phase), a
	ld	hl, #_teleport_to
	ld	(hl+), a
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:118: cam_override = 0;
;C:\dev\AI\robbo-port2\gb\src\core\game.c:119: cam_pan_timer = 0;
	xor	a, a
	ld	(#_cam_override), a
	ld	(#_cam_pan_timer),a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:120: robbo_dead = 0;
;C:\dev\AI\robbo-port2\gb\src\core\game.c:121: death_timer = 0;
	xor	a, a
	ld	(#_robbo_dead), a
	ld	(#_death_timer),a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:122: game_restart_requested = 0;
;C:\dev\AI\robbo-port2\gb\src\core\game.c:123: game_level_advance_requested = 0;
	xor	a, a
	ld	(#_game_restart_requested), a
	ld	(#_game_level_advance_requested),a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:124: screen_flash_ticks = 0;
;C:\dev\AI\robbo-port2\gb\src\core\game.c:125: transition_active = 0;
	xor	a, a
	ld	(#_screen_flash_ticks), a
	ld	(#_transition_active),a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:126: wipe_col = 0;
;C:\dev\AI\robbo-port2\gb\src\core\game.c:127: anim_frame = 0;
	xor	a, a
	ld	(#_wipe_col), a
	ld	(#_anim_frame),a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:128: render_flash_set(0);
	xor	a, a
	call	_render_flash_set
;C:\dev\AI\robbo-port2\gb\src\core\game.c:130: render_level();
	call	_render_level
;C:\dev\AI\robbo-port2\gb\src\core\game.c:131: hud_dirty = 0;
	xor	a, a
	ld	(#_hud_dirty),a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:132: render_camera();
	call	_render_camera
;C:\dev\AI\robbo-port2\gb\src\core\game.c:133: render_apply_camera();
;C:\dev\AI\robbo-port2\gb\src\core\game.c:134: }
	jp	_render_apply_camera
;C:\dev\AI\robbo-port2\gb\src\core\game.c:136: static uint8_t is_demolishable(uint8_t type)
;	---------------------------------
; Function is_demolishable
; ---------------------------------
_is_demolishable:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:141: switch (type) {
	cp	a, #0x09
	jr	Z, 00107$
	cp	a, #0x0e
	jr	Z, 00107$
	cp	a, #0x0f
	jr	Z, 00107$
	cp	a, #0x13
	jr	Z, 00107$
	cp	a, #0x15
	jr	Z, 00107$
	cp	a, #0x16
	jr	Z, 00107$
	sub	a, #0x17
	jr	NZ, 00108$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:148: case CT_MUSTACHE:
00107$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:149: return 1;
	ld	a, #0x01
	ret
;C:\dev\AI\robbo-port2\gb\src\core\game.c:150: default:
00108$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:151: return 0;
	xor	a, a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:152: }
;C:\dev\AI\robbo-port2\gb\src\core\game.c:153: }
	ret
;C:\dev\AI\robbo-port2\gb\src\core\game.c:155: static uint8_t is_explodable(uint8_t type)
;	---------------------------------
; Function is_explodable
; ---------------------------------
_is_explodable:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:157: switch (type) {
	cp	a, #0x09
	jr	C, 00117$
	cp	a, #0x1a
	jr	NC, 00117$
	add	a, #0xf7
	ld	c, a
	ld	b, #0x00
	ld	hl, #00135$
	add	hl, bc
	add	hl, bc
	ld	c, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, c
	jp	(hl)
00135$:
	.dw	00116$
	.dw	00116$
	.dw	00116$
	.dw	00116$
	.dw	00117$
	.dw	00116$
	.dw	00116$
	.dw	00116$
	.dw	00116$
	.dw	00116$
	.dw	00116$
	.dw	00116$
	.dw	00116$
	.dw	00116$
	.dw	00116$
	.dw	00116$
	.dw	00116$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:173: case CT_MAGNET:
00116$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:174: return 1;
	ld	a, #0x01
	ret
;C:\dev\AI\robbo-port2\gb\src\core\game.c:175: default:
00117$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:176: return 0;
	xor	a, a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:177: }
;C:\dev\AI\robbo-port2\gb\src\core\game.c:178: }
	ret
;C:\dev\AI\robbo-port2\gb\src\core\game.c:182: static uint8_t next_rand8(void)
;	---------------------------------
; Function next_rand8
; ---------------------------------
_next_rand8:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:184: rng_state ^= (uint16_t)(rng_state << 7);
	ld	a, (_rng_state)
	ld	hl, #_rng_state + 1
	ld	c, (hl)
	dec	hl
	add	a, a
	rl	c
	add	a, a
	rl	c
	add	a, a
	rl	c
	add	a, a
	rl	c
	add	a, a
	rl	c
	add	a, a
	rl	c
	add	a, a
	rl	c
	xor	a, (hl)
	ld	(hl+), a
	ld	a, c
	xor	a, (hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:185: rng_state ^= (uint16_t)(rng_state >> 9);
	ld	(hl-), a
	srl	a
	ld	c, a
	ld	a, (hl)
	xor	a, c
;C:\dev\AI\robbo-port2\gb\src\core\game.c:186: rng_state ^= (uint16_t)(rng_state << 8);
	ld	(hl+), a
	xor	a, (hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:187: return (uint8_t)(rng_state & 0xFF);
	ld	(hl-), a
	ld	a, (hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:188: }
	ret
;C:\dev\AI\robbo-port2\gb\src\core\game.c:190: static void add_sliding(uint16_t idx)
;	---------------------------------
; Function add_sliding
; ---------------------------------
_add_sliding:
	add	sp, #-7
	ldhl	sp,	#4
	ld	a, e
	ld	(hl+), a
	ld	(hl), d
;C:\dev\AI\robbo-port2\gb\src\core\game.c:193: if (sliding_count >= MAX_SLIDING) return;
	ld	a, (#_sliding_count)
	sub	a, #0x20
;C:\dev\AI\robbo-port2\gb\src\core\game.c:194: for (i = 0; i < sliding_count; i++) {
	jr	NC, 00109$
	ldhl	sp,	#6
	ld	(hl), #0x00
00107$:
	ldhl	sp,	#6
	ld	a, (hl)
	ld	hl, #_sliding_count
	sub	a, (hl)
	jr	NC, 00105$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:195: if (sliding_boxes[i] == idx) return;
	ldhl	sp,	#6
	ld	a, (hl)
	ld	d, #0x00
	add	a, a
	rl	d
	ld	e, a
	ld	hl, #_sliding_boxes
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
	ld	a, (hl-)
	ld	d, a
	ld	a, (de)
	ld	(hl+), a
	inc	de
	ld	a, (de)
	ld	(hl+), a
	ld	a, (hl-)
	dec	hl
	sub	a, (hl)
	jr	NZ, 00108$
	ldhl	sp,	#5
	ld	a, (hl-)
	dec	hl
	sub	a, (hl)
	jr	Z, 00109$
00108$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:194: for (i = 0; i < sliding_count; i++) {
	ldhl	sp,	#6
	inc	(hl)
	jr	00107$
00105$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:197: sliding_boxes[sliding_count++] = idx;
	ld	a, (_sliding_count)
	ld	c, a
	ld	hl, #_sliding_count
	inc	(hl)
	ldhl	sp,	#2
	ld	a, c
	ld	(hl+), a
	xor	a, a
	ld	(hl-), a
	ld	a, (hl-)
	dec	hl
	ld	(hl+), a
	xor	a, a
	ld	(hl-), a
	sla	(hl)
	inc	hl
	rl	(hl)
	pop	de
	push	de
	ld	hl, #_sliding_boxes
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
	ld	a, (hl+)
	ld	d, a
	ld	a, (hl+)
	ld	(de), a
	inc	de
	ld	a, (hl)
	ld	(de), a
00109$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:198: }
	add	sp, #7
	ret
;C:\dev\AI\robbo-port2\gb\src\core\game.c:200: static void remove_sliding(uint8_t i)
;	---------------------------------
; Function remove_sliding
; ---------------------------------
_remove_sliding:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:202: sliding_boxes[i] = sliding_boxes[--sliding_count];
	ld	l, a
	ld	de, #_sliding_boxes+0
	ld	h, #0x00
	add	hl, hl
	add	hl, de
	ld	c, l
	ld	b, h
	ld	hl, #_sliding_count
	dec	(hl)
	ld	a, (hl)
	ld	h, #0x00
	ld	l, a
	add	hl, hl
	add	hl, de
	ld	a,	(hl+)
	ld	h, (hl)
	ld	(bc), a
	inc	bc
	ld	a, h
	ld	(bc), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:203: }
	ret
;C:\dev\AI\robbo-port2\gb\src\core\game.c:205: static void refresh_spaceships(void)
;	---------------------------------
; Function refresh_spaceships
; ---------------------------------
_refresh_spaceships:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:208: for (y = 0; y < level_height; y++) {
	ld	e, #0x00
00108$:
	ld	a, e
	ld	hl, #_level_height
	sub	a, (hl)
	ret	NC
;C:\dev\AI\robbo-port2\gb\src\core\game.c:209: for (x = 0; x < MAP_W; x++) {
	ld	d, #0x00
00105$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:210: if (map_type[y * MAP_W + x] == CT_SPACESHIP) {
	ld	l, e
	xor	a, a
	ld	h, a
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	c, d
	ld	b, #0x00
	add	hl, bc
	ld	bc, #_map_type
	add	hl, bc
	ld	a, (hl)
	sub	a, #0x0d
	jr	NZ, 00106$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:211: render_cell(x, y);
	push	de
	ld	a, d
	call	_render_cell
	pop	de
00106$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:209: for (x = 0; x < MAP_W; x++) {
	inc	d
	ld	a, d
	sub	a, #0x10
	jr	C, 00105$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:208: for (y = 0; y < level_height; y++) {
	inc	e
;C:\dev\AI\robbo-port2\gb\src\core\game.c:215: }
	jr	00108$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:217: static void move_robbo_to(uint8_t nx, uint8_t ny, uint8_t dir)
;	---------------------------------
; Function move_robbo_to
; ---------------------------------
_move_robbo_to:
	dec	sp
	dec	sp
	ldhl	sp,	#1
	ld	(hl-), a
	ld	(hl), e
;C:\dev\AI\robbo-port2\gb\src\core\game.c:219: uint16_t old_idx = (uint16_t)robbo_y * MAP_W + robbo_x;
	ld	a, (_robbo_y)
	ld	l, a
	ld	h, #0x00
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	a, (_robbo_x)
	ld	c, a
	ld	b, #0x00
	add	hl, bc
	ld	e, l
	ld	d, h
;C:\dev\AI\robbo-port2\gb\src\core\game.c:220: uint16_t new_idx = (uint16_t)ny * MAP_W + nx;
	ldhl	sp,	#0
	ld	a, (hl+)
	ld	c, a
	xor	a, a
	ld	b, a
	sla	c
	rl	b
	sla	c
	rl	b
	sla	c
	rl	b
	sla	c
	rl	b
	ld	l, (hl)
	ld	h, #0x00
	add	hl, bc
	ld	c, l
	ld	b, h
;C:\dev\AI\robbo-port2\gb\src\core\game.c:222: map_type[old_idx] = CT_EMPTY;
	ld	hl, #_map_type
	add	hl, de
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\core\game.c:223: map_extra[old_idx] = 0;
	ld	hl, #_map_extra
	add	hl, de
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\core\game.c:224: map_type[new_idx] = CT_ROBBO;
	ld	hl, #_map_type
	add	hl, bc
	ld	(hl), #0x1a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:225: map_extra[new_idx] = dir;
	ld	hl, #_map_extra
	add	hl, bc
	ld	c, l
	ld	b, h
	ldhl	sp,	#4
	ld	a, (hl)
	ld	(bc), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:227: render_cell(robbo_x, robbo_y);
	ld	a, (_robbo_y)
	ld	e, a
	ld	a, (_robbo_x)
	call	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:228: robbo_x = nx;
	ldhl	sp,	#1
	ld	a, (hl)
	ld	(#_robbo_x),a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:229: robbo_y = ny;
	ldhl	sp,	#0
	ld	a, (hl)
	ld	(#_robbo_y),a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:230: robbo_dir = dir;
	ldhl	sp,	#4
	ld	a, (hl)
	ld	(#_robbo_dir),a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:231: render_cell(robbo_x, robbo_y);
	ld	a, (_robbo_y)
	ld	e, a
	ld	a, (_robbo_x)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:232: }
	call	_render_cell
	pop	hl
	pop	hl
	inc	sp
	jp	(hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:239: static uint16_t teleport_scan(uint16_t base, uint8_t *pdir)
;	---------------------------------
; Function teleport_scan
; ---------------------------------
_teleport_scan:
	add	sp, #-12
;C:\dev\AI\robbo-port2\gb\src\core\game.c:242: uint8_t dir = *pdir;
	ld	a, (bc)
	ldhl	sp,	#10
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:243: uint8_t bx = base % MAP_W;
	ld	a, e
	and	a, #0x0f
	ld	l, #0x00
	push	hl
	ldhl	sp,	#2
	ld	(hl), a
	pop	hl
;C:\dev\AI\robbo-port2\gb\src\core\game.c:244: uint8_t by = base / MAP_W;
	srl	d
	rr	e
	srl	d
	rr	e
	srl	d
	rr	e
	srl	d
	rr	e
	ldhl	sp,	#1
	ld	(hl), e
;C:\dev\AI\robbo-port2\gb\src\core\game.c:246: for (i = 0; i < 4; i++) {
	ldhl	sp,	#11
	ld	(hl), #0x00
00109$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:247: int16_t nx = (int16_t)bx + tp_dx[dir];
	ldhl	sp,	#0
	ld	a, (hl)
	ldhl	sp,	#7
	ld	(hl), a
	ld	de, #_tp_dx
	ldhl	sp,	#10
	ld	l, (hl)
	ld	h, #0x00
	add	hl, de
	ld	e, l
	ld	d, h
	ld	a, (de)
	ldhl	sp,	#8
	ld	(hl+), a
	rlca
	sbc	a, a
	ld	(hl-), a
	dec	hl
	ld	a, (hl+)
	ld	e, a
	ld	d, #0x00
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	e, l
	ld	a, h
	ldhl	sp,	#2
	ld	(hl), e
	inc	hl
;C:\dev\AI\robbo-port2\gb\src\core\game.c:248: int16_t ny = (int16_t)by + tp_dy[dir];
	ld	(hl-), a
	dec	hl
	ld	a, (hl)
	ldhl	sp,	#7
	ld	(hl), a
	ld	de, #_tp_dy
	ldhl	sp,	#10
	ld	l, (hl)
	ld	h, #0x00
	add	hl, de
	ld	e, l
	ld	d, h
	ld	a, (de)
	ldhl	sp,	#8
	ld	(hl+), a
	rlca
	sbc	a, a
	ld	(hl-), a
	dec	hl
	ld	a, (hl+)
	ld	e, a
	ld	d, #0x00
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	e, l
	ld	a, h
	ldhl	sp,	#4
	ld	(hl), e
	inc	hl
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:249: if (nx >= 0 && ny >= 0 && nx < MAP_W && ny < level_height) {
	ldhl	sp,	#2
	ld	a, (hl)
	ldhl	sp,	#6
	ld	(hl), a
	ldhl	sp,	#3
	ld	a, (hl)
	ldhl	sp,	#7
	ld	(hl), a
	bit	7, (hl)
	jr	NZ, 00104$
	ldhl	sp,	#4
	ld	a, (hl)
	ldhl	sp,	#8
	ld	(hl), a
	ldhl	sp,	#5
	ld	a, (hl)
	ldhl	sp,	#9
	ld	(hl), a
	bit	7, (hl)
	jr	NZ, 00104$
	ldhl	sp,	#6
	ld	a, (hl+)
	sub	a, #0x10
	ld	a, (hl)
	sbc	a, #0x00
	jr	NC, 00104$
	ld	a, (#_level_height)
	ldhl	sp,	#8
	ld	(hl+), a
	ld	(hl), #0x00
	ldhl	sp,	#4
	ld	e, l
	ld	d, h
	ldhl	sp,	#8
	ld	a, (de)
	inc	de
	sub	a, (hl)
	inc	hl
	ld	a, (de)
	sbc	a, (hl)
	ld	a, (de)
	ld	d, a
	bit	7, (hl)
	jr	Z, 00162$
	bit	7, d
	jr	NZ, 00163$
	cp	a, a
	jr	00163$
00162$:
	bit	7, d
	jr	Z, 00163$
	scf
00163$:
	jr	NC, 00104$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:250: uint16_t nidx = (uint16_t)ny * MAP_W + (uint8_t)nx;
	ldhl	sp,	#4
	ld	a, (hl+)
	ld	e, (hl)
	ld	l, a
	ld	h, e
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	e, l
	ld	d, h
	ldhl	sp,	#2
	ld	l, (hl)
	ld	h, #0x00
	add	hl, de
	ld	e, l
	ld	d, h
;C:\dev\AI\robbo-port2\gb\src\core\game.c:251: if (map_type[nidx] == CT_EMPTY) {
	ld	hl, #_map_type
	add	hl, de
	ld	a, (hl)
	or	a, a
	jr	NZ, 00104$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:252: *pdir = dir;
	ldhl	sp,	#10
	ld	a, (hl)
	ld	(bc), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:253: return nidx;
	ld	c, e
	ld	b, d
	jr	00111$
00104$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:256: dir ^= (uint8_t)(3 - (i & 1));
	ldhl	sp,	#11
	ld	a, (hl-)
	and	a, #0x01
	ld	e, a
	ld	a, #0x03
	sub	a, e
	ld	e, a
	ld	a, (hl)
	xor	a, e
;C:\dev\AI\robbo-port2\gb\src\core\game.c:246: for (i = 0; i < 4; i++) {
	ld	(hl+), a
	inc	(hl)
	ld	a, (hl)
	sub	a, #0x04
	jp	C, 00109$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:259: *pdir = dir;
	dec	hl
	ld	a, (hl)
	ld	(bc), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:260: return TELEPORT_NONE;
	ld	bc, #0xffff
00111$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:261: }
	add	sp, #12
	ret
_tp_dx:
	.db #0x01	;  1
	.db #0x00	;  0
	.db #0xff	; -1
	.db #0x00	;  0
_tp_dy:
	.db #0x00	;  0
	.db #0x01	;  1
	.db #0x00	;  0
	.db #0xff	; -1
;C:\dev\AI\robbo-port2\gb\src\core\game.c:263: static uint16_t teleport_find_next(uint16_t entry_idx, uint16_t dest_idx)
;	---------------------------------
; Function teleport_find_next
; ---------------------------------
_teleport_find_next:
	add	sp, #-3
	ldhl	sp,	#1
	ld	a, e
	ld	(hl+), a
	ld	(hl), d
	ld	e, c
	ld	d, b
;C:\dev\AI\robbo-port2\gb\src\core\game.c:265: uint8_t dir = robbo_dir;
	ld	a, (#_robbo_dir)
	ldhl	sp,	#0
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:269: candidate = teleport_scan(dest_idx, &dir);
	push	de
	ld	hl, #2
	add	hl, sp
	ld	c, l
	ld	b, h
	call	_teleport_scan
	pop	de
;C:\dev\AI\robbo-port2\gb\src\core\game.c:270: if (candidate != TELEPORT_NONE && map_type[dest_idx] == CT_TELEPORT) {
	ld	l, c
	ld	h, b
	ld	a, l
	and	a, h
	inc	a
	jr	Z, 00102$
	ld	hl, #_map_type
	add	hl, de
	ld	a, (hl)
	sub	a, #0x14
	jr	NZ, 00102$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:271: robbo_dir = dir;
	ldhl	sp,	#0
	ld	a, (hl)
	ld	(#_robbo_dir),a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:272: return candidate;
	jr	00104$
00102$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:276: candidate = teleport_scan(entry_idx, &dir);
	ld	hl, #0
	add	hl, sp
	ld	c, l
	ld	b, h
	ldhl	sp,	#1
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	call	_teleport_scan
;C:\dev\AI\robbo-port2\gb\src\core\game.c:277: robbo_dir = dir;
	ldhl	sp,	#0
	ld	a, (hl)
	ld	(#_robbo_dir),a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:278: return candidate;
00104$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:279: }
	add	sp, #3
	ret
;C:\dev\AI\robbo-port2\gb\src\core\game.c:281: static void game_teleport(uint16_t entry_idx)
;	---------------------------------
; Function game_teleport
; ---------------------------------
_game_teleport:
	add	sp, #-4
	ldhl	sp,	#2
	ld	a, e
	ld	(hl+), a
	ld	(hl), d
;C:\dev\AI\robbo-port2\gb\src\core\game.c:288: if (robbo_busy) return;
	ld	a, (#_robbo_busy)
	or	a, a
	jp	NZ, 00111$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:290: table_idx = map_extra[entry_idx];
	ld	de, #_map_extra
	ldhl	sp,	#2
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	c, l
	ld	b, h
	ld	a, (bc)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:291: if (table_idx >= level_teleport_count) return;
	ld	e, a
	ld	hl, #_level_teleport_count
	sub	a, (hl)
	jp	NC, 00111$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:292: dest_idx = teleport_dest[table_idx];
	ld	bc, #_teleport_dest+0
	xor	a, a
	ld	l, e
	ld	h, a
	add	hl, hl
	add	hl, bc
	ld	a, (hl+)
	ld	c, a
	ld	b, (hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:294: to = teleport_find_next(entry_idx, dest_idx);
	ldhl	sp,	#2
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:295: if (to == TELEPORT_NONE) return;
	call	_teleport_find_next
	pop	hl
	push	bc
	ldhl	sp,	#0
	ld	a, (hl+)
	and	a, (hl)
	inc	a
	jp	Z, 00111$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:297: old_idx = (uint16_t)robbo_y * MAP_W + robbo_x;
	ld	a, (_robbo_y)
	ld	h, #0x00
	ld	l, a
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	a, (_robbo_x)
	ld	e, a
	ld	d, #0x00
	add	hl, de
	ld	e, l
	ld	d, h
;C:\dev\AI\robbo-port2\gb\src\core\game.c:298: robbo_busy = 1;
	ld	hl, #_robbo_busy
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\core\game.c:299: teleport_phase = 1;
	ld	hl, #_teleport_phase
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\core\game.c:300: teleport_to = to;
	ld	hl, #_teleport_to
	ld	a, c
	ld	(hl+), a
	ld	(hl), b
;C:\dev\AI\robbo-port2\gb\src\core\game.c:302: map_type[old_idx] = CT_EXPLOSION;
	ld	hl, #_map_type
	add	hl, de
	ld	(hl), #0x1c
;C:\dev\AI\robbo-port2\gb\src\core\game.c:303: map_extra[old_idx] = 2;
	ld	hl, #_map_extra
	add	hl, de
	ld	(hl), #0x02
;C:\dev\AI\robbo-port2\gb\src\core\game.c:304: render_cell(robbo_x, robbo_y);
	ld	a, (_robbo_y)
	ld	e, a
	ld	a, (_robbo_x)
	call	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:308: uint8_t tx = to % MAP_W;
	ldhl	sp,	#0
	ld	a, (hl)
	and	a, #0x0f
	ld	c, a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:309: uint8_t ty = to / MAP_W;
	ld	a, (hl+)
	ld	d, a
	ld	b, (hl)
	srl	b
	rr	d
	srl	b
	rr	d
	srl	b
	rr	d
	srl	b
	rr	d
;C:\dev\AI\robbo-port2\gb\src\core\game.c:311: uint8_t max_y = (level_height > VIEW_ROWS) ? (level_height - VIEW_ROWS) : 0;
	ld	a, #0x08
	ld	hl, #_level_height
	sub	a, (hl)
	jr	NC, 00113$
	ld	a, (hl)
	add	a, #0xf8
	ld	e, a
	jr	00114$
00113$:
	ld	e, #0x00
00114$:
	ld	b, e
;C:\dev\AI\robbo-port2\gb\src\core\game.c:313: cam_target_x = (tx > 4) ? (uint8_t)(tx - 4) : 0;
	ld	a, #0x04
	sub	a, c
	jr	NC, 00115$
	ld	a, c
	add	a, #0xfc
	jr	00116$
00115$:
	xor	a, a
00116$:
	ld	(#_cam_target_x),a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:314: cam_target_y = (ty > 3) ? (uint8_t)(ty - 3) : 0;
	ld	a, #0x03
	sub	a, d
	jr	NC, 00117$
	ld	a, d
	add	a, #0xfd
	jr	00118$
00117$:
	xor	a, a
00118$:
	ld	(#_cam_target_y),a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:315: if (cam_target_x > max_x) cam_target_x = max_x;
	ld	a, #0x06
	ld	hl, #_cam_target_x
	sub	a, (hl)
	jr	NC, 00108$
	ld	(hl), #0x06
00108$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:316: if (cam_target_y > max_y) cam_target_y = max_y;
	ld	a, b
	ld	hl, #_cam_target_y
	sub	a, (hl)
	jr	NC, 00110$
	ld	(hl), b
00110$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:317: cam_override = 1;
	ld	hl, #_cam_override
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\core\game.c:318: cam_pan_timer = 0;
	xor	a, a
	ld	(#_cam_pan_timer),a
00111$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:320: }
	add	sp, #4
	ret
;C:\dev\AI\robbo-port2\gb\src\core\game.c:322: void game_teleport_camera_ready(void)
;	---------------------------------
; Function game_teleport_camera_ready
; ---------------------------------
_game_teleport_camera_ready::
;C:\dev\AI\robbo-port2\gb\src\core\game.c:324: if (teleport_phase != 1) return;
	ld	a, (#_teleport_phase)
	dec	a
	ret	NZ
;C:\dev\AI\robbo-port2\gb\src\core\game.c:325: if (cam_x != cam_target_x || cam_y != cam_target_y) return;
	ld	a, (#_cam_x)
	ld	hl, #_cam_target_x
	sub	a, (hl)
	ret	NZ
	ld	a, (#_cam_y)
	ld	hl, #_cam_target_y
	sub	a, (hl)
	ret	NZ
;C:\dev\AI\robbo-port2\gb\src\core\game.c:327: teleport_phase = 2;
	ld	hl, #_teleport_phase
	ld	(hl), #0x02
;C:\dev\AI\robbo-port2\gb\src\core\game.c:329: map_type[teleport_to] = CT_EXPLOSION;
	ld	a, #<(_map_type)
	ld	hl, #_teleport_to
	add	a, (hl)
	inc	hl
	ld	c, a
	ld	a, #>(_map_type)
	adc	a, (hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:330: map_extra[teleport_to] = (uint8_t)((12 << 3) | 2);
	dec	hl
	ld	b, a
	ld	a, #0x1c
	ld	(bc), a
	ld	a, #<(_map_extra)
	add	a, (hl)
	inc	hl
	ld	c, a
	ld	a, #>(_map_extra)
	adc	a, (hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:331: render_cell(teleport_to % MAP_W, teleport_to / MAP_W);
	dec	hl
	ld	b, a
	ld	a, #0x62
	ld	(bc), a
	ld	a, (hl+)
	ld	c, a
	ld	b, (hl)
	ld	e, c
	ld	d, b
	srl	d
	rr	e
	srl	d
	rr	e
	srl	d
	rr	e
	srl	d
	rr	e
	ld	a, c
	and	a, #0x0f
;C:\dev\AI\robbo-port2\gb\src\core\game.c:332: }
	jp	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:334: static void teleport_arrive(uint16_t idx)
;	---------------------------------
; Function teleport_arrive
; ---------------------------------
_teleport_arrive:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:336: teleport_phase = 0;
;C:\dev\AI\robbo-port2\gb\src\core\game.c:337: cam_override = 0;
	xor	a, a
	ld	(#_teleport_phase), a
	ld	(#_cam_override),a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:338: robbo_x = idx % MAP_W;
	ld	c, e
	ld	b, d
	ld	a, c
	and	a, #0x0f
	ld	(_robbo_x), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:339: robbo_y = idx / MAP_W;
	srl	b
	rr	c
	srl	b
	rr	c
	srl	b
	rr	c
	srl	b
	rr	c
	ld	hl, #_robbo_y
	ld	(hl), c
;C:\dev\AI\robbo-port2\gb\src\core\game.c:340: map_type[idx] = CT_ROBBO;
	ld	hl, #_map_type
	add	hl, de
	ld	(hl), #0x1a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:341: map_extra[idx] = robbo_dir;
	ld	hl, #_map_extra
	add	hl, de
	ld	a, (_robbo_dir)
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:342: robbo_busy = 0;
	xor	a, a
	ld	(#_robbo_busy),a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:343: render_cell(robbo_x, robbo_y);
	ld	a, (_robbo_y)
	ld	e, a
	ld	a, (_robbo_x)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:344: }
	jp	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:346: static void destroy_teleport(uint16_t idx)
;	---------------------------------
; Function destroy_teleport
; ---------------------------------
_destroy_teleport:
	add	sp, #-8
	ldhl	sp,	#4
	ld	a, e
	ld	(hl+), a
	ld	(hl), d
;C:\dev\AI\robbo-port2\gb\src\core\game.c:349: uint8_t table_idx = map_extra[idx];
	ld	de, #_map_extra
	ld	a, (hl-)
	ld	l, (hl)
	ld	h, a
	add	hl, de
	ld	c, l
	ld	b, h
	ld	a, (bc)
	ldhl	sp,	#7
;C:\dev\AI\robbo-port2\gb\src\core\game.c:352: if (table_idx >= level_teleport_count) {
	ld	(hl), a
	ld	hl, #_level_teleport_count
	sub	a, (hl)
	jr	C, 00102$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:353: spawn_explosion_timer(idx, 3);
	ld	a, #0x03
	ldhl	sp,	#4
	ld	e, (hl)
	inc	hl
	ld	d, (hl)
	call	_spawn_explosion_timer
;C:\dev\AI\robbo-port2\gb\src\core\game.c:354: return;
	jp	00110$
00102$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:357: new_dest = teleport_dest[table_idx];
	ldhl	sp,	#7
	ld	a, (hl-)
	ld	(hl+), a
	xor	a, a
	ld	(hl-), a
	ld	a, (hl)
	ldhl	sp,	#2
	ld	(hl+), a
	xor	a, a
	ld	(hl-), a
	sla	(hl)
	inc	hl
	rl	(hl)
	dec	hl
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #_teleport_dest
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
	ldhl	sp,	#0
	ld	(hl+), a
	inc	de
	ld	a, (de)
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:360: for (i = 0; i < MAP_CELLS; i++) {
	xor	a, a
	ldhl	sp,	#6
	ld	(hl+), a
	ld	(hl), a
00108$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:361: if (map_type[i] == CT_TELEPORT) {
	ld	de, #_map_type
	ldhl	sp,	#6
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	c, l
	ld	b, h
	ld	a, (bc)
	sub	a, #0x14
	jr	NZ, 00109$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:362: if (teleport_dest[map_extra[i]] == idx) {
	ld	de, #_map_extra
	ldhl	sp,	#6
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	c, l
	ld	b, h
	ld	a, (bc)
	ld	b, #0x00
	add	a, a
	rl	b
	add	a, #<(_teleport_dest)
	ld	c, a
	ld	a, b
	adc	a, #>(_teleport_dest)
	ld	b, a
	ld	e, c
	ld	d, b
	ld	a, (de)
	ldhl	sp,	#2
	ld	(hl+), a
	inc	de
	ld	a, (de)
	ld	(hl+), a
	ld	a, (hl-)
	dec	hl
	sub	a, (hl)
	jr	NZ, 00109$
	ldhl	sp,	#5
	ld	a, (hl-)
	dec	hl
	sub	a, (hl)
	jr	NZ, 00109$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:363: teleport_dest[map_extra[i]] = new_dest;
	ldhl	sp,	#0
	ld	a, (hl+)
	ld	(bc), a
	inc	bc
	ld	a, (hl)
	ld	(bc), a
00109$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:360: for (i = 0; i < MAP_CELLS; i++) {
	ldhl	sp,	#6
	inc	(hl)
	jr	NZ, 00154$
	inc	hl
	inc	(hl)
00154$:
	ldhl	sp,	#6
	ld	a, (hl+)
	ld	c, a
	ld	b, (hl)
	ld	a, c
	sub	a, #0xf0
	ld	a, b
	sbc	a, #0x01
	jr	C, 00108$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:368: spawn_explosion_timer(idx, 3);
	ld	a, #0x03
	ldhl	sp,	#4
	ld	e, (hl)
	inc	hl
	ld	d, (hl)
	call	_spawn_explosion_timer
00110$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:369: }
	add	sp, #8
	ret
;C:\dev\AI\robbo-port2\gb\src\core\game.c:371: uint8_t game_try_move(uint8_t dir)
;	---------------------------------
; Function game_try_move
; ---------------------------------
_game_try_move::
	add	sp, #-13
	ldhl	sp,	#10
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:373: uint8_t nx = robbo_x;
	ld	a, (#_robbo_x)
	ldhl	sp,	#11
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:374: uint8_t ny = robbo_y;
	ld	a, (#_robbo_y)
	ldhl	sp,	#12
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:379: if (robbo_busy) return 0;
	ld	a, (#_robbo_busy)
	or	a, a
	jr	Z, 00102$
	xor	a, a
	jp	00172$
00102$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:381: if (dir == 0) {
	ldhl	sp,	#10
	ld	a, (hl)
	or	a, a
	jr	NZ, 00114$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:382: nx++;
	inc	hl
	inc	(hl)
	jr	00115$
00114$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:383: } else if (dir == 1) {
	ldhl	sp,	#10
	ld	a, (hl)
	dec	a
	jr	NZ, 00111$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:384: ny++;
	ldhl	sp,	#12
	inc	(hl)
	jr	00115$
00111$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:385: } else if (dir == 2) {
	ldhl	sp,	#10
	ld	a, (hl)
	sub	a, #0x02
	jr	NZ, 00108$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:386: if (nx > 0) nx--;
	ldhl	sp,	#11
	ld	a, (hl)
	or	a, a
	jr	Z, 00115$
	dec	(hl)
	jr	00115$
00108$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:388: if (ny > 0) ny--;
	ldhl	sp,	#12
	ld	a, (hl)
	or	a, a
	jr	Z, 00115$
	dec	(hl)
00115$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:391: old_idx = (uint16_t)robbo_y * MAP_W + robbo_x;
	ld	a, (#_robbo_y)
	ldhl	sp,	#8
	ld	(hl+), a
	xor	a, a
	ld	(hl-), a
	ld	a, (hl)
	ldhl	sp,	#4
	ld	(hl+), a
	ld	(hl), #0x00
	ld	a, #0x04
00395$:
	ldhl	sp,	#4
	sla	(hl)
	inc	hl
	rl	(hl)
	dec	a
	jr	NZ, 00395$
	ld	a, (#_robbo_x)
	ldhl	sp,	#9
	ld	(hl), a
	ldhl	sp,	#6
	ld	(hl+), a
	xor	a, a
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ldhl	sp,	#4
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#10
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#9
;C:\dev\AI\robbo-port2\gb\src\core\game.c:392: robbo_dir = dir;
	ld	(hl+), a
	ld	a, (hl)
	ld	(#_robbo_dir),a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:393: map_extra[old_idx] = dir;  /* face the direction even when blocked */
	ld	de, #_map_extra
	ldhl	sp,	#8
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	c, l
	ld	b, h
	ldhl	sp,	#10
;C:\dev\AI\robbo-port2\gb\src\core\game.c:395: if (nx >= MAP_W || ny >= level_height) {
	ld	a, (hl+)
	ld	(bc), a
	ld	a, (hl)
	sub	a, #0x10
	jr	NC, 00116$
	inc	hl
	ld	a, (hl)
	ld	hl, #_level_height
	sub	a, (hl)
	jr	C, 00117$
00116$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:396: render_cell(robbo_x, robbo_y);
	ld	a, (_robbo_y)
	ld	e, a
	ld	a, (_robbo_x)
	call	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:397: return 0;
	xor	a, a
	jp	00172$
00117$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:400: new_idx = (uint16_t)ny * MAP_W + nx;
	ldhl	sp,	#12
	ld	a, (hl)
	ldhl	sp,	#8
	ld	(hl+), a
	xor	a, a
	ld	(hl-), a
	ld	a, (hl)
	ldhl	sp,	#4
	ld	(hl+), a
	ld	(hl), #0x00
	ld	a, #0x04
00396$:
	ldhl	sp,	#4
	sla	(hl)
	inc	hl
	rl	(hl)
	dec	a
	jr	NZ, 00396$
	ldhl	sp,	#11
	ld	a, (hl-)
	dec	hl
	ld	(hl), a
	ldhl	sp,	#6
	ld	(hl+), a
	xor	a, a
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ldhl	sp,	#4
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#10
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#9
	ld	(hl-), a
	ld	a, (hl)
	ldhl	sp,	#0
	ld	(hl), a
	ldhl	sp,	#9
	ld	a, (hl)
	ldhl	sp,	#1
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:401: target = map_type[new_idx];
	ld	de, #_map_type
	pop	hl
	push	hl
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
	ldhl	sp,	#9
;C:\dev\AI\robbo-port2\gb\src\core\game.c:403: if (target == CT_TELEPORT) {
	ld	(hl), a
	sub	a, #0x14
	jr	NZ, 00120$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:404: game_teleport(new_idx);
	pop	de
	push	de
	call	_game_teleport
;C:\dev\AI\robbo-port2\gb\src\core\game.c:405: return 0;
	xor	a, a
	jp	00172$
00120$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:408: if (target == CT_EMPTY) {
	ldhl	sp,	#9
	ld	a, (hl)
	or	a, a
	jr	NZ, 00122$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:409: move_robbo_to(nx, ny, dir);
	inc	hl
	ld	a, (hl+)
	inc	hl
	push	af
	inc	sp
	ld	a, (hl-)
	ld	e, a
	ld	a, (hl)
	call	_move_robbo_to
;C:\dev\AI\robbo-port2\gb\src\core\game.c:410: return 1;
	ld	a, #0x01
	jp	00172$
00122$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:413: if (target == CT_SCREW) {
	ldhl	sp,	#9
	ld	a, (hl)
	sub	a, #0x11
	jr	NZ, 00126$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:414: screws_left--;
	ld	hl, #_screws_left
	dec	(hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:415: map_type[new_idx] = CT_EMPTY;
	ldhl	sp,	#2
	ld	a, (hl+)
	ld	h, (hl)
	ld	l, a
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\core\game.c:416: map_extra[new_idx] = 0;
	ld	de, #_map_extra
	pop	hl
	push	hl
	add	hl, de
	ld	c, l
	ld	b, h
	xor	a, a
	ld	(bc), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:417: hud_dirty = 1;
	ld	hl, #_hud_dirty
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\core\game.c:418: if (screws_left == 0) {
	ld	a, (#_screws_left)
	or	a, a
	jr	NZ, 00124$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:419: screen_flash_ticks = 1;
	ld	hl, #_screen_flash_ticks
;C:\dev\AI\robbo-port2\gb\src\core\game.c:420: render_flash_set(1);
	ld	a,#0x01
	ld	(hl),a
	call	_render_flash_set
;C:\dev\AI\robbo-port2\gb\src\core\game.c:421: refresh_spaceships();
	call	_refresh_spaceships
00124$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:423: move_robbo_to(nx, ny, dir);
	ldhl	sp,	#10
	ld	a, (hl+)
	inc	hl
	push	af
	inc	sp
	ld	a, (hl-)
	ld	e, a
	ld	a, (hl)
	call	_move_robbo_to
;C:\dev\AI\robbo-port2\gb\src\core\game.c:424: return 1;
	ld	a, #0x01
	jp	00172$
00126$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:427: if (target == CT_AMMO) {
	ldhl	sp,	#9
	ld	a, (hl)
	sub	a, #0x13
	jr	NZ, 00130$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:428: ammo += 9;
	ld	a, (_ammo)
	add	a, #0x09
	ld	hl, #_ammo
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:429: if (ammo > 99) ammo = 99;
	ld	a, #0x63
	sub	a, (hl)
	jr	NC, 00128$
	ld	(hl), #0x63
00128$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:430: map_type[new_idx] = CT_EMPTY;
	ldhl	sp,	#2
	ld	a, (hl+)
	ld	h, (hl)
	ld	l, a
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\core\game.c:431: map_extra[new_idx] = 0;
	ld	de, #_map_extra
	pop	hl
	push	hl
	add	hl, de
	ld	c, l
	ld	b, h
	xor	a, a
	ld	(bc), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:432: hud_dirty = 1;
	ld	hl, #_hud_dirty
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\core\game.c:433: move_robbo_to(nx, ny, dir);
	ldhl	sp,	#10
	ld	a, (hl+)
	inc	hl
	push	af
	inc	sp
	ld	a, (hl-)
	ld	e, a
	ld	a, (hl)
	call	_move_robbo_to
;C:\dev\AI\robbo-port2\gb\src\core\game.c:434: return 1;
	ld	a, #0x01
	jp	00172$
00130$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:437: if (target == CT_KEY) {
	ldhl	sp,	#9
	ld	a, (hl)
	sub	a, #0x10
	jr	NZ, 00134$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:438: keys++;
	ld	hl, #_keys
	inc	(hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:439: if (keys > 99) keys = 99;
	ld	a, #0x63
	sub	a, (hl)
	jr	NC, 00132$
	ld	(hl), #0x63
00132$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:440: map_type[new_idx] = CT_EMPTY;
	ldhl	sp,	#2
	ld	a, (hl+)
	ld	h, (hl)
	ld	l, a
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\core\game.c:441: map_extra[new_idx] = 0;
	ld	de, #_map_extra
	pop	hl
	push	hl
	add	hl, de
	ld	c, l
	ld	b, h
	xor	a, a
	ld	(bc), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:442: hud_dirty = 1;
	ld	hl, #_hud_dirty
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\core\game.c:443: move_robbo_to(nx, ny, dir);
	ldhl	sp,	#10
	ld	a, (hl+)
	inc	hl
	push	af
	inc	sp
	ld	a, (hl-)
	ld	e, a
	ld	a, (hl)
	call	_move_robbo_to
;C:\dev\AI\robbo-port2\gb\src\core\game.c:444: return 1;
	ld	a, #0x01
	jp	00172$
00134$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:447: if (target == CT_DOOR) {
	ldhl	sp,	#9
	ld	a, (hl)
	sub	a, #0x0c
	jr	NZ, 00138$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:448: if (keys > 0) {
	ld	hl, #_keys
	ld	a, (hl)
	or	a, a
	jr	Z, 00136$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:449: keys--;
	dec	(hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:450: map_type[new_idx] = CT_EMPTY;
	ldhl	sp,	#2
	ld	a, (hl+)
	ld	h, (hl)
	ld	l, a
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\core\game.c:451: map_extra[new_idx] = 0;
	ld	de, #_map_extra
	pop	hl
	push	hl
	add	hl, de
	ld	c, l
	ld	b, h
	xor	a, a
	ld	(bc), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:452: hud_dirty = 1;
	ld	hl, #_hud_dirty
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\core\game.c:453: render_cell(nx, ny);
	ldhl	sp,	#12
	ld	a, (hl-)
	ld	e, a
	ld	a, (hl)
	call	_render_cell
00136$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:456: render_cell(robbo_x, robbo_y);
	ld	a, (_robbo_y)
	ld	e, a
	ld	a, (_robbo_x)
	call	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:457: return 0;
	xor	a, a
	jp	00172$
00138$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:460: if (target == CT_SPACESHIP) {
	ldhl	sp,	#9
	ld	a, (hl)
	sub	a, #0x0d
	jp	NZ, 00143$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:461: if (screws_left == 0 || (map_extra[new_idx] & 1)) {
	ld	a, (#_screws_left)
	or	a, a
	jr	Z, 00139$
	ld	de, #_map_extra
	pop	hl
	push	hl
	add	hl, de
	ld	c, l
	ld	b, h
	ld	a, (bc)
	rrca
	jr	NC, 00140$
00139$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:462: uint16_t robbo_idx = (uint16_t)robbo_y * MAP_W + robbo_x;
	ld	a, (#_robbo_y)
	ldhl	sp,	#11
	ld	(hl+), a
	xor	a, a
	ld	(hl-), a
	ld	a, (hl)
	ldhl	sp,	#6
	ld	(hl+), a
	ld	(hl), #0x00
	ld	a, #0x04
00410$:
	ldhl	sp,	#6
	sla	(hl)
	inc	hl
	rl	(hl)
	dec	a
	jr	NZ, 00410$
	ld	a, (#_robbo_x)
	ldhl	sp,	#12
	ld	(hl), a
	ldhl	sp,	#8
	ld	(hl+), a
	xor	a, a
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ldhl	sp,	#6
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#13
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#12
;C:\dev\AI\robbo-port2\gb\src\core\game.c:463: map_type[robbo_idx] = CT_EMPTY;
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #_map_type
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#10
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#9
	ld	(hl-), a
	ld	a, (hl+)
	ld	h, (hl)
	ld	l, a
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\core\game.c:464: map_extra[robbo_idx] = 0;
	ld	de, #_map_extra
	ldhl	sp,	#11
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	c, l
	ld	b, h
	xor	a, a
	ld	(bc), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:465: render_cell(robbo_x, robbo_y);
	ld	a, (_robbo_y)
	ld	e, a
	ld	a, (_robbo_x)
	call	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:466: robbo_busy = 1;
	ld	hl, #_robbo_busy
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\core\game.c:467: transition_active = 1;
	ld	hl, #_transition_active
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\core\game.c:468: wipe_col = MAP_W - 1;
	ld	hl, #_wipe_col
	ld	(hl), #0x0f
;C:\dev\AI\robbo-port2\gb\src\core\game.c:469: return 0;
	xor	a, a
	jp	00172$
00140$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:471: render_cell(robbo_x, robbo_y);
	ld	a, (_robbo_y)
	ld	e, a
	ld	a, (_robbo_x)
	call	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:472: return 0;
	xor	a, a
	jp	00172$
00143$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:475: if (target == CT_STONE || target == CT_PUSHABLE ||
	ldhl	sp,	#9
	ld	a, (hl)
	sub	a, #0x0a
	jr	Z, 00167$
	ldhl	sp,	#9
	ld	a, (hl)
	sub	a, #0x0b
	jr	Z, 00167$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:476: target == CT_BOMB || target == CT_QUESTION) {
	ldhl	sp,	#9
	ld	a, (hl)
	sub	a, #0x0f
	jr	Z, 00167$
	ldhl	sp,	#9
	ld	a, (hl)
	sub	a, #0x0e
	jp	NZ, 00168$
00167$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:477: uint8_t bx = nx;
	ldhl	sp,	#11
	ld	a, (hl)
	ldhl	sp,	#4
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:478: uint8_t by = ny;
	ldhl	sp,	#12
	ld	a, (hl)
	ldhl	sp,	#5
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:479: uint8_t moved_extra = map_extra[new_idx];
	ld	de, #_map_extra
	pop	hl
	push	hl
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
;C:\dev\AI\robbo-port2\gb\src\core\game.c:482: if (dir == 0) bx++;
	ld	(hl+), a
	inc	hl
	ld	a, (hl)
	or	a, a
	jr	NZ, 00155$
	inc	hl
	ld	a, (hl)
	inc	a
	ldhl	sp,	#4
	ld	(hl), a
	jr	00156$
00155$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:483: else if (dir == 1) by++;
	ldhl	sp,	#10
	ld	a, (hl)
	dec	a
	jr	NZ, 00152$
	ldhl	sp,	#12
	ld	a, (hl)
	inc	a
	ldhl	sp,	#5
	ld	(hl), a
	jr	00156$
00152$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:484: else if (dir == 2) { if (bx > 0) bx--; }
	ldhl	sp,	#10
	ld	a, (hl)
	sub	a, #0x02
	jr	NZ, 00149$
	ldhl	sp,	#11
	ld	a, (hl)
	or	a, a
	jr	Z, 00156$
	ld	a, (hl)
	dec	a
	ldhl	sp,	#4
	ld	(hl), a
	jr	00156$
00149$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:485: else { if (by > 0) by--; }
	ldhl	sp,	#12
	ld	a, (hl)
	or	a, a
	jr	Z, 00156$
	ld	a, (hl)
	dec	a
	ldhl	sp,	#5
	ld	(hl), a
00156$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:487: if (bx >= MAP_W || by >= level_height) {
	ldhl	sp,	#4
	ld	a, (hl)
	sub	a, #0x10
	jr	NC, 00157$
	inc	hl
	ld	a, (hl)
	ld	hl, #_level_height
	sub	a, (hl)
	jr	C, 00158$
00157$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:488: render_cell(robbo_x, robbo_y);
	ld	a, (_robbo_y)
	ld	e, a
	ld	a, (_robbo_x)
	call	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:489: return 0;
	xor	a, a
	jp	00172$
00158$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:492: beyond_idx = (uint16_t)by * MAP_W + bx;
	ldhl	sp,	#5
	ld	a, (hl-)
	ld	d, #0x00
	add	a, a
	rl	d
	add	a, a
	rl	d
	add	a, a
	rl	d
	add	a, a
	rl	d
	ld	l, (hl)
	ld	h, #0x00
	ld	e, a
	add	hl, de
	ld	c, l
	ld	b, h
;C:\dev\AI\robbo-port2\gb\src\core\game.c:493: if (map_type[beyond_idx] != CT_EMPTY) {
	ld	hl, #_map_type
	add	hl, bc
	ld	e, l
	ld	d, h
	ld	a, (de)
	or	a, a
	jr	Z, 00161$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:494: render_cell(robbo_x, robbo_y);
	ld	a, (_robbo_y)
	ld	e, a
	ld	a, (_robbo_x)
	call	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:495: return 0;
	xor	a, a
	jr	00172$
00161$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:498: map_type[beyond_idx] = target;
	ldhl	sp,	#9
	ld	a, (hl)
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:499: if (target == CT_PUSHABLE) {
	ld	a, (hl)
	sub	a, #0x0b
	ld	a, #0x01
	jr	Z, 00422$
	xor	a, a
00422$:
	ldhl	sp,	#9
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:500: map_extra[beyond_idx] = dir | 4;
	ld	hl, #_map_extra
	add	hl, bc
	ld	e, l
	ld	d, h
;C:\dev\AI\robbo-port2\gb\src\core\game.c:499: if (target == CT_PUSHABLE) {
	ldhl	sp,	#9
	ld	a, (hl)
	or	a, a
	jr	Z, 00163$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:500: map_extra[beyond_idx] = dir | 4;
	inc	hl
	ld	a, (hl)
	set	2, a
	ld	(de), a
	jr	00164$
00163$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:502: map_extra[beyond_idx] = moved_extra;
	ldhl	sp,	#8
	ld	a, (hl)
	ld	(de), a
00164$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:504: map_type[new_idx] = CT_EMPTY;
	ldhl	sp,	#2
	ld	a, (hl+)
	ld	h, (hl)
	ld	l, a
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\core\game.c:505: map_extra[new_idx] = 0;
	ldhl	sp,	#6
	ld	a, (hl+)
	ld	h, (hl)
	ld	l, a
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\core\game.c:507: render_cell(bx, by);
	push	bc
	ldhl	sp,	#7
	ld	a, (hl-)
	ld	e, a
	ld	a, (hl)
	call	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:508: render_cell(nx, ny);
	ldhl	sp,	#14
	ld	a, (hl-)
	ld	e, a
	ld	a, (hl)
	call	_render_cell
	pop	bc
;C:\dev\AI\robbo-port2\gb\src\core\game.c:509: if (target == CT_PUSHABLE) add_sliding(beyond_idx);
	ldhl	sp,	#9
	ld	a, (hl)
	or	a, a
	jr	Z, 00166$
	ld	e, c
	ld	d, b
	call	_add_sliding
00166$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:510: move_robbo_to(nx, ny, dir);
	ldhl	sp,	#10
	ld	a, (hl+)
	inc	hl
	push	af
	inc	sp
	ld	a, (hl-)
	ld	e, a
	ld	a, (hl)
	call	_move_robbo_to
;C:\dev\AI\robbo-port2\gb\src\core\game.c:511: return 1;
	ld	a, #0x01
	jr	00172$
00168$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:514: render_cell(robbo_x, robbo_y);
	ld	a, (_robbo_y)
	ld	e, a
	ld	a, (_robbo_x)
	call	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:515: return 0;
	xor	a, a
00172$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:516: }
	add	sp, #13
	ret
;C:\dev\AI\robbo-port2\gb\src\core\game.c:518: static void spawn_explosion_timer(uint16_t idx, uint8_t timer)
;	---------------------------------
; Function spawn_explosion_timer
; ---------------------------------
_spawn_explosion_timer:
	ld	c, a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:520: map_type[idx] = CT_EXPLOSION;
	ld	hl, #_map_type
	add	hl, de
	ld	(hl), #0x1c
;C:\dev\AI\robbo-port2\gb\src\core\game.c:521: map_extra[idx] = timer;
	ld	hl, #_map_extra
	add	hl, de
	ld	(hl), c
;C:\dev\AI\robbo-port2\gb\src\core\game.c:522: render_cell(idx % MAP_W, idx / MAP_W);
	ld	c, e
	ld	b, d
	srl	b
	rr	c
	srl	b
	rr	c
	srl	b
	rr	c
	srl	b
	rr	c
	ld	a, e
	and	a, #0x0f
	ld	e, c
;C:\dev\AI\robbo-port2\gb\src\core\game.c:523: }
	jp	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:525: static void spawn_explosion(uint16_t idx)
;	---------------------------------
; Function spawn_explosion
; ---------------------------------
_spawn_explosion:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:527: spawn_explosion_timer(idx, 3);
	ld	a, #0x03
;C:\dev\AI\robbo-port2\gb\src\core\game.c:528: }
	jp	_spawn_explosion_timer
;C:\dev\AI\robbo-port2\gb\src\core\game.c:530: static void spawn_payload_explosion_timer(uint16_t idx, uint8_t payload, uint8_t timer)
;	---------------------------------
; Function spawn_payload_explosion_timer
; ---------------------------------
_spawn_payload_explosion_timer:
	ld	c, a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:532: map_type[idx] = CT_EXPLOSION;
	ld	hl, #_map_type
	add	hl, de
	ld	(hl), #0x1c
;C:\dev\AI\robbo-port2\gb\src\core\game.c:533: map_extra[idx] = (uint8_t)(((payload + 1) << 3) | timer);
	ld	hl, #_map_extra
	add	hl, de
	ld	a, c
	inc	a
	add	a, a
	add	a, a
	add	a, a
	push	hl
	ldhl	sp,	#4
	or	a, (hl)
	pop	hl
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:534: render_cell(idx % MAP_W, idx / MAP_W);
	ld	c, e
	ld	b, d
	srl	b
	rr	c
	srl	b
	rr	c
	srl	b
	rr	c
	srl	b
	rr	c
	ld	a, e
	and	a, #0x0f
	ld	e, c
	call	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:535: }
	pop	hl
	inc	sp
	jp	(hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:537: static void spawn_payload_explosion(uint16_t idx, uint8_t payload)
;	---------------------------------
; Function spawn_payload_explosion
; ---------------------------------
_spawn_payload_explosion:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:539: spawn_payload_explosion_timer(idx, payload, 3);
	ld	h, #0x03
	push	hl
	inc	sp
	call	_spawn_payload_explosion_timer
;C:\dev\AI\robbo-port2\gb\src\core\game.c:540: }
	ret
;C:\dev\AI\robbo-port2\gb\src\core\game.c:543: static void spawn_question_payload(uint16_t idx, uint8_t payload)
;	---------------------------------
; Function spawn_question_payload
; ---------------------------------
_spawn_question_payload:
	add	sp, #-5
	ldhl	sp,	#3
	ld	(hl), e
	inc	hl
	ld	(hl), d
	dec	hl
	dec	hl
;C:\dev\AI\robbo-port2\gb\src\core\game.c:545: uint8_t x = idx % MAP_W;
	ld	(hl+), a
	ld	a, (hl+)
	ld	c, a
	ld	b, (hl)
	ld	a, c
	and	a, #0x0f
	ld	e, a
	ldhl	sp,	#0
;C:\dev\AI\robbo-port2\gb\src\core\game.c:546: uint8_t y = idx / MAP_W;
	ld	a, e
	ld	(hl+), a
	srl	b
	rr	c
	srl	b
	rr	c
	srl	b
	rr	c
	srl	b
	rr	c
;C:\dev\AI\robbo-port2\gb\src\core\game.c:548: uint8_t extra = 0;
;C:\dev\AI\robbo-port2\gb\src\core\game.c:550: switch (payload) {
	ld	a, c
	ld	(hl+), a
	ld	c, #0x00
	ld	a, #0x0a
	sub	a, (hl)
	jr	C, 00112$
	ld	e, (hl)
	ld	d, #0x00
	ld	hl, #00123$
	add	hl, de
	add	hl, de
	ld	e, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, e
	jp	(hl)
00123$:
	.dw	00101$
	.dw	00102$
	.dw	00103$
	.dw	00104$
	.dw	00105$
	.dw	00106$
	.dw	00107$
	.dw	00108$
	.dw	00109$
	.dw	00110$
	.dw	00111$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:551: case 0:  /* another Question: roll a fresh payload */
00101$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:552: type = CT_QUESTION;
	ld	b, #0x0e
;C:\dev\AI\robbo-port2\gb\src\core\game.c:553: extra = next_rand8() % 11;
	push	bc
	call	_next_rand8
	ld	e, #0x0b
	call	__moduchar
	pop	af
	ld	b, a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:554: break;
	jr	00113$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:555: case 1:  /* Spaceship from question */
00102$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:556: type = CT_SPACESHIP;
;C:\dev\AI\robbo-port2\gb\src\core\game.c:557: extra = 1;
	ld	bc, #0xd01
;C:\dev\AI\robbo-port2\gb\src\core\game.c:558: break;
	jr	00113$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:559: case 2:  type = CT_STONE; break;
00103$:
	ld	b, #0x0a
	jr	00113$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:560: case 3:  type = CT_GROUND; break;
00104$:
	ld	b, #0x09
	jr	00113$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:561: case 4:
00105$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:562: type = CT_SCREW;
	ld	b, #0x11
;C:\dev\AI\robbo-port2\gb\src\core\game.c:563: screws_left++;
	ld	hl, #_screws_left
	inc	(hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:564: hud_dirty = 1;
	ld	hl, #_hud_dirty
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\core\game.c:565: break;
	jr	00113$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:566: case 5:  type = CT_KEY; break;
00106$:
	ld	b, #0x10
	jr	00113$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:567: case 6:  type = CT_AMMO; break;
00107$:
	ld	b, #0x13
	jr	00113$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:568: case 7:  /* Turret: random direction, gun, rotatable */
00108$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:569: type = CT_TURRET;
	ld	b, #0x12
;C:\dev\AI\robbo-port2\gb\src\core\game.c:570: extra = (uint8_t)((next_rand8() & 3) | 0x80);
	push	bc
	call	_next_rand8
	pop	bc
	and	a, #0x03
	or	a, #0x80
	ld	c, a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:571: break;
	jr	00113$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:572: case 8:  type = CT_EMPTY; break;
00109$:
	ld	b, #0x00
	jr	00113$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:573: case 9:  type = CT_BOMB; break;
00110$:
	ld	b, #0x0f
	jr	00113$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:574: case 10: type = CT_BUTTERFLY; break;
00111$:
	ld	b, #0x16
	jr	00113$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:575: default: type = CT_EMPTY; break;
00112$:
	ld	b, #0x00
;C:\dev\AI\robbo-port2\gb\src\core\game.c:576: }
00113$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:578: map_type[idx] = type;
	ld	de, #_map_type
	ldhl	sp,	#3
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	e, l
	ld	d, h
	ld	a, b
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:579: map_extra[idx] = extra;
	ld	de, #_map_extra
	ldhl	sp,	#3
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	e, l
	ld	d, h
	ld	a, c
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:580: render_cell(x, y);
	ldhl	sp,	#1
	ld	a, (hl-)
	ld	e, a
	ld	a, (hl)
	call	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:581: }
	add	sp, #5
	ret
;C:\dev\AI\robbo-port2\gb\src\core\game.c:583: static void demolish_cell(uint16_t idx)
;	---------------------------------
; Function demolish_cell
; ---------------------------------
_demolish_cell:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:585: uint8_t type = map_type[idx];
	ld	hl, #_map_type
	add	hl, de
	ld	a, (hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:587: if (type == CT_BOMB) {
	cp	a, #0x0f
	jr	NZ, 00104$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:588: if (map_extra[idx] == 0) {
	ld	hl, #_map_extra
	add	hl, de
	ld	a, (hl)
	or	a, a
	ret	NZ
;C:\dev\AI\robbo-port2\gb\src\core\game.c:589: map_extra[idx] = 2;  /* two logic ticks of fuse */
	ld	(hl), #0x02
;C:\dev\AI\robbo-port2\gb\src\core\game.c:590: render_cell(idx % MAP_W, idx / MAP_W);
	ld	c, e
	ld	b, d
	srl	b
	rr	c
	srl	b
	rr	c
	srl	b
	rr	c
	srl	b
	rr	c
	ld	a, e
	and	a, #0x0f
	ld	e, c
;C:\dev\AI\robbo-port2\gb\src\core\game.c:592: return;
	jp	_render_cell
00104$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:595: if (type == CT_QUESTION) {
	cp	a, #0x0e
	jr	NZ, 00106$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:596: spawn_payload_explosion(idx, map_extra[idx]);
	ld	hl, #_map_extra
	add	hl, de
;C:\dev\AI\robbo-port2\gb\src\core\game.c:597: return;
	ld	a, (hl)
	jp	_spawn_payload_explosion
00106$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:600: if (is_demolishable(type)) {
	push	de
	call	_is_demolishable
	pop	de
	or	a, a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:601: spawn_explosion(idx);
	jp	NZ, _spawn_explosion
;C:\dev\AI\robbo-port2\gb\src\core\game.c:603: }
	ret
;C:\dev\AI\robbo-port2\gb\src\core\game.c:605: static void blast_cell(uint16_t idx, uint8_t timer)
;	---------------------------------
; Function blast_cell
; ---------------------------------
_blast_cell:
	add	sp, #-7
	ldhl	sp,	#5
	ld	(hl), e
	inc	hl
	ld	(hl), d
	ld	c, a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:607: uint8_t type = map_type[idx];
	ld	de, #_map_type+0
	ld	a, (hl-)
	ld	l, (hl)
	ld	h, a
	add	hl, de
	ld	e, l
	ld	d, h
	ld	a, (de)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:609: if (type == CT_TELEPORT) {
	cp	a, #0x14
	jr	NZ, 00102$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:610: destroy_teleport(idx);
	ldhl	sp,	#5
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	call	_destroy_teleport
;C:\dev\AI\robbo-port2\gb\src\core\game.c:611: return;
	jp	00114$
00102$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:614: if (type == CT_BOMB) {
	cp	a, #0x0f
	jr	NZ, 00106$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:615: if (map_extra[idx] == 0) {
	ld	de, #_map_extra
	ldhl	sp,	#5
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
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
	ld	a, (hl+)
	ld	d, a
	ld	a, (de)
	ld	(hl), a
	or	a, a
	jp	NZ, 00114$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:616: map_extra[idx] = 2;
	dec	hl
	ld	a, (hl-)
	ld	l, (hl)
	ld	h, a
	ld	(hl), #0x02
;C:\dev\AI\robbo-port2\gb\src\core\game.c:617: render_cell(idx % MAP_W, idx / MAP_W);
	ldhl	sp,	#5
	ld	a, (hl)
	ldhl	sp,	#0
	ld	(hl), a
	ldhl	sp,	#6
	ld	a, (hl)
	ldhl	sp,	#1
	ld	(hl-), a
	ld	a, (hl)
	ldhl	sp,	#3
	ld	(hl-), a
	dec	hl
	ld	a, (hl)
	ldhl	sp,	#4
	ld	(hl), a
	srl	(hl)
	dec	hl
	rr	(hl)
	inc	hl
	srl	(hl)
	dec	hl
	rr	(hl)
	inc	hl
	srl	(hl)
	dec	hl
	rr	(hl)
	inc	hl
	srl	(hl)
	dec	hl
	rr	(hl)
	ld	a, (hl-)
	ld	(hl-), a
	dec	hl
	ld	a, (hl)
	and	a, #0x0f
	ldhl	sp,	#3
	ld	(hl+), a
	xor	a, a
	ld	(hl-), a
	ld	a, (hl-)
	ld	e, (hl)
	call	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:619: return;
	jr	00114$
00106$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:622: if (type == CT_QUESTION) {
	cp	a, #0x0e
	jr	NZ, 00108$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:623: spawn_payload_explosion_timer(idx, map_extra[idx], timer);
	ld	de, #_map_extra+0
	ldhl	sp,	#5
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	e, l
	ld	d, h
	ld	a, (de)
	ld	h, c
	push	hl
	inc	sp
	ldhl	sp,	#6
	ld	e, (hl)
	inc	hl
	ld	d, (hl)
	call	_spawn_payload_explosion_timer
;C:\dev\AI\robbo-port2\gb\src\core\game.c:624: return;
	jr	00114$
00108$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:627: if (type == CT_EMPTY || type == CT_EXPLOSION) {
	or	a, a
	jr	Z, 00109$
	cp	a, #0x1c
	jr	NZ, 00110$
00109$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:628: spawn_explosion_timer(idx, timer);
	ld	a, c
	ldhl	sp,	#5
	ld	e, (hl)
	inc	hl
	ld	d, (hl)
	call	_spawn_explosion_timer
;C:\dev\AI\robbo-port2\gb\src\core\game.c:629: return;
	jr	00114$
00110$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:632: if (is_explodable(type)) {
	push	bc
	call	_is_explodable
	pop	bc
	or	a, a
	jr	Z, 00114$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:633: spawn_explosion_timer(idx, timer);
	ld	a, c
	ldhl	sp,	#5
	ld	e, (hl)
	inc	hl
	ld	d, (hl)
	call	_spawn_explosion_timer
00114$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:635: }
	add	sp, #7
	ret
;C:\dev\AI\robbo-port2\gb\src\core\game.c:638: static void bomb_explode(uint16_t idx)
;	---------------------------------
; Function bomb_explode
; ---------------------------------
_bomb_explode:
	add	sp, #-9
;C:\dev\AI\robbo-port2\gb\src\core\game.c:645: uint8_t x = idx % MAP_W;
	ld	c, e
	ld	b, d
	ld	a, c
	and	a, #0x0f
	ldhl	sp,	#7
	ld	(hl+), a
	xor	a, a
	ld	(hl-), a
	ld	a, (hl)
	ldhl	sp,	#0
;C:\dev\AI\robbo-port2\gb\src\core\game.c:646: uint8_t y = idx / MAP_W;
	ld	(hl+), a
	srl	b
	rr	c
	srl	b
	rr	c
	srl	b
	rr	c
	srl	b
	rr	c
	ld	(hl), c
;C:\dev\AI\robbo-port2\gb\src\core\game.c:649: spawn_explosion_timer(idx, 3);
	ld	a, #0x03
	call	_spawn_explosion_timer
;C:\dev\AI\robbo-port2\gb\src\core\game.c:651: for (dy = -1; dy <= 1; dy++) {
	ld	c, #0xff
;C:\dev\AI\robbo-port2\gb\src\core\game.c:652: for (dx = -1; dx <= 1; dx++) {
00122$:
	ld	a, c
	inc	a
	ld	e, a
	add	a, a
	add	a, e
	ldhl	sp,	#2
	ld	(hl), a
	ldhl	sp,	#8
	ld	(hl), #0xff
00112$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:661: timer = blast_timer[(dy + 1) * 3 + (dx + 1)];
	ldhl	sp,	#8
	ld	b, (hl)
	inc	b
;C:\dev\AI\robbo-port2\gb\src\core\game.c:656: if (dx == 0 && dy == 0) continue;
	ld	a, (hl)
	or	a, a
	jr	NZ, 00102$
	or	a, c
	jp	Z, 00109$
00102$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:657: nx = (int16_t)x + dx;
	ldhl	sp,	#0
	ld	e, (hl)
	ldhl	sp,	#8
	ld	a, (hl)
	add	a, e
	ldhl	sp,	#3
;C:\dev\AI\robbo-port2\gb\src\core\game.c:658: ny = (int16_t)y + dy;
	ld	(hl-), a
	dec	hl
	ld	l, (hl)
	ld	a, c
	ld	e, a
	rlca
	sbc	a, a
	ld	d, a
	ld	h, #0x00
	add	hl, de
	ld	e, l
	ld	a, h
	ldhl	sp,	#4
	ld	(hl), e
	inc	hl
;C:\dev\AI\robbo-port2\gb\src\core\game.c:659: if (nx < 0 || ny < 0 || nx >= MAP_W || ny >= level_height) continue;
	ld	(hl-), a
	dec	hl
	ld	a, (hl)
	ldhl	sp,	#6
	ld	(hl), a
	bit	7, (hl)
	jr	NZ, 00109$
	dec	hl
	dec	hl
	ld	a, (hl)
	ldhl	sp,	#7
	ld	(hl-), a
	dec	hl
	ld	a, (hl)
	ldhl	sp,	#8
	ld	(hl), a
	bit	7, (hl)
	jr	NZ, 00109$
	dec	hl
	dec	hl
	ld	a, (hl)
	sub	a, #0x10
	jr	NC, 00109$
	ld	a, (#_level_height)
	ldhl	sp,	#7
	ld	(hl+), a
	ld	(hl), #0x00
	ldhl	sp,	#4
	ld	e, l
	ld	d, h
	ldhl	sp,	#7
	ld	a, (de)
	inc	de
	sub	a, (hl)
	inc	hl
	ld	a, (de)
	sbc	a, (hl)
	ld	a, (de)
	ld	d, a
	bit	7, (hl)
	jr	Z, 00175$
	bit	7, d
	jr	NZ, 00176$
	cp	a, a
	jr	00176$
00175$:
	bit	7, d
	jr	Z, 00176$
	scf
00176$:
	jr	NC, 00109$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:660: nidx = (uint16_t)ny * MAP_W + (uint8_t)nx;
	ldhl	sp,	#4
	ld	a, (hl+)
	ld	e, (hl)
	ld	l, a
	ld	h, e
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	e, l
	ld	d, h
	ldhl	sp,	#3
	ld	l, (hl)
	ld	h, #0x00
	add	hl, de
	ld	e, l
	ld	d, h
;C:\dev\AI\robbo-port2\gb\src\core\game.c:661: timer = blast_timer[(dy + 1) * 3 + (dx + 1)];
	ldhl	sp,	#2
	ld	a, (hl)
	add	a, b
	add	a, #<(_bomb_explode_blast_timer_10000_385)
	ld	l, a
	ld	a, #0x00
	adc	a, #>(_bomb_explode_blast_timer_10000_385)
	ld	h, a
	ld	a, (hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:662: blast_cell(nidx, timer);
	push	bc
	call	_blast_cell
	pop	bc
00109$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:652: for (dx = -1; dx <= 1; dx++) {
	ldhl	sp,	#8
	ld	(hl), b
	ld	e, b
	ld	a,#0x01
	ld	d,a
	sub	a, b
	bit	7, e
	jr	Z, 00177$
	bit	7, d
	jr	NZ, 00178$
	cp	a, a
	jr	00178$
00177$:
	bit	7, d
	jr	Z, 00178$
	scf
00178$:
	jp	NC, 00112$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:651: for (dy = -1; dy <= 1; dy++) {
	inc	c
	ld	a, #0x01
	sub	a, c
	jp	NC, 00122$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:665: }
	add	sp, #9
	ret
_bomb_explode_blast_timer_10000_385:
	.db #0x05	; 5
	.db #0x04	; 4
	.db #0x05	; 5
	.db #0x04	; 4
	.db #0x03	; 3
	.db #0x02	; 2
	.db #0x05	; 5
	.db #0x04	; 4
	.db #0x05	; 5
;C:\dev\AI\robbo-port2\gb\src\core\game.c:667: static uint8_t bullet_make_extra(uint8_t dir, uint8_t type, uint8_t owner)
;	---------------------------------
; Function bullet_make_extra
; ---------------------------------
_bullet_make_extra:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:669: return (uint8_t)((dir & 3) | ((type & 3) << 2) | ((owner & 1) << 4));
	and	a, #0x03
	ld	c, a
	ld	a, e
	and	a, #0x03
	add	a, a
	add	a, a
	or	a, c
	ld	c, a
	ldhl	sp,	#2
	ld	a, (hl)
	swap a
	and	a, #0x10
	or	a, c
;C:\dev\AI\robbo-port2\gb\src\core\game.c:670: }
	pop	hl
	inc	sp
	jp	(hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:672: static uint8_t add_bullet(uint16_t idx, uint8_t dir, uint8_t type, uint8_t owner)
;	---------------------------------
; Function add_bullet
; ---------------------------------
_add_bullet:
	dec	sp
	dec	sp
	ld	c, e
	ld	b, d
	ld	d, a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:674: if (bullet_count >= MAX_BULLETS) return 0;
	ld	a, (#_bullet_count)
	sub	a, #0x60
	jr	C, 00102$
	xor	a, a
	jr	00103$
00102$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:675: map_type[idx] = CT_BULLET;
	ld	hl, #_map_type
	add	hl, bc
	ld	(hl), #0x1b
;C:\dev\AI\robbo-port2\gb\src\core\game.c:676: map_extra[idx] = bullet_make_extra(dir, type, owner);
	ld	hl, #_map_extra
	add	hl, bc
	inc	sp
	inc	sp
	push	hl
	push	bc
	ldhl	sp,	#7
	ld	a, (hl-)
	push	af
	inc	sp
	ld	e, (hl)
	ld	a, d
	call	_bullet_make_extra
	pop	bc
	pop	hl
	push	hl
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:677: render_cell(idx % MAP_W, idx / MAP_W);
	ld	e, c
	ld	d, b
	ld	l, e
	ld	h, d
	srl	h
	rr	l
	srl	h
	rr	l
	srl	h
	rr	l
	srl	h
	rr	l
	ld	a, e
	and	a, #0x0f
	push	bc
	ld	e, l
	call	_render_cell
	pop	bc
;C:\dev\AI\robbo-port2\gb\src\core\game.c:678: bullet_cells[bullet_count++] = idx;
	ld	a, (_bullet_count)
	ld	e, a
	ld	hl, #_bullet_count
	inc	(hl)
	xor	a, a
	ld	l, e
	ld	h, a
	add	hl, hl
	ld	de, #_bullet_cells
	add	hl, de
	ld	a, c
	ld	(hl+), a
	ld	(hl), b
;C:\dev\AI\robbo-port2\gb\src\core\game.c:679: return 1;
	ld	a, #0x01
00103$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:680: }
	inc	sp
	inc	sp
	pop	hl
	pop	bc
	jp	(hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:682: static void remove_bullet_at(uint8_t i)
;	---------------------------------
; Function remove_bullet_at
; ---------------------------------
_remove_bullet_at:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:684: bullet_cells[i] = bullet_cells[--bullet_count];
	ld	l, a
	ld	de, #_bullet_cells+0
	ld	h, #0x00
	add	hl, hl
	add	hl, de
	ld	c, l
	ld	b, h
	ld	hl, #_bullet_count
	dec	(hl)
	ld	a, (hl)
	ld	h, #0x00
	ld	l, a
	add	hl, hl
	add	hl, de
	ld	a,	(hl+)
	ld	h, (hl)
	ld	(bc), a
	inc	bc
	ld	a, h
	ld	(bc), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:685: }
	ret
;C:\dev\AI\robbo-port2\gb\src\core\game.c:687: static uint8_t player_bullet_active(void)
;	---------------------------------
; Function player_bullet_active
; ---------------------------------
_player_bullet_active:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:690: for (i = 0; i < bullet_count; i++) {
	ld	c, #0x00
00106$:
	ld	a, c
	ld	hl, #_bullet_count
	sub	a, (hl)
	jr	NC, 00104$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:691: uint16_t idx = bullet_cells[i];
	ld	l, c
	xor	a, a
	ld	h, a
	add	hl, hl
	ld	de, #_bullet_cells
	add	hl, de
	ld	a,	(hl+)
	ld	h, (hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:692: if (map_type[idx] == CT_BULLET && ((map_extra[idx] >> 4) & 1) == 0) {
	ld	l, a
	add	a,#<(_map_type)
	ld	e, a
	ld	a, #>(_map_type)
	adc	a, h
	ld	d, a
	ld	a, (de)
	sub	a, #0x1b
	jr	NZ, 00107$
	ld	de, #_map_extra
	add	hl, de
	ld	a, (hl)
	swap	a
	and	a, #0x01
	jr	NZ, 00107$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:693: return 1;
	ld	a, #0x01
	ret
00107$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:690: for (i = 0; i < bullet_count; i++) {
	inc	c
	jr	00106$
00104$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:696: return 0;
	xor	a, a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:697: }
	ret
;C:\dev\AI\robbo-port2\gb\src\core\game.c:699: static void kill_robbo(void)
;	---------------------------------
; Function kill_robbo
; ---------------------------------
_kill_robbo:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:703: if (robbo_dead) return;
	ld	a, (#_robbo_dead)
	or	a, a
	ret	NZ
;C:\dev\AI\robbo-port2\gb\src\core\game.c:705: robbo_dead = 1;
	ld	hl, #_robbo_dead
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\core\game.c:706: robbo_busy = 1;
	ld	hl, #_robbo_busy
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\core\game.c:707: death_timer = 6;
	ld	hl, #_death_timer
	ld	(hl), #0x06
;C:\dev\AI\robbo-port2\gb\src\core\game.c:709: idx = (uint16_t)robbo_y * MAP_W + robbo_x;
	ld	a, (_robbo_y)
	ld	h, #0x00
	ld	l, a
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	a, (_robbo_x)
	ld	c, a
	ld	b, #0x00
	add	hl, bc
	ld	c, l
	ld	b, h
;C:\dev\AI\robbo-port2\gb\src\core\game.c:710: map_type[idx] = CT_EXPLOSION;
	ld	hl, #_map_type
	add	hl, bc
	ld	(hl), #0x1c
;C:\dev\AI\robbo-port2\gb\src\core\game.c:711: map_extra[idx] = 2;
	ld	hl, #_map_extra
	add	hl, bc
	ld	(hl), #0x02
;C:\dev\AI\robbo-port2\gb\src\core\game.c:712: render_cell(robbo_x, robbo_y);
	ld	a, (_robbo_y)
	ld	e, a
	ld	a, (_robbo_x)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:713: }
	jp	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:715: static void turret_fire(uint16_t idx, uint8_t dir, uint8_t btype)
;	---------------------------------
; Function turret_fire
; ---------------------------------
_turret_fire:
	dec	sp
	ld	c, a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:717: uint8_t x = idx % MAP_W;
	ld	a, e
	and	a, #0x0f
	ld	b, a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:718: uint8_t y = idx / MAP_W;
	srl	d
	rr	e
	srl	d
	rr	e
	srl	d
	rr	e
	srl	d
	rr	e
;C:\dev\AI\robbo-port2\gb\src\core\game.c:719: uint8_t nx = x;
	ld	d, b
;C:\dev\AI\robbo-port2\gb\src\core\game.c:720: uint8_t ny = y;
	ldhl	sp,	#0
	ld	(hl), e
;C:\dev\AI\robbo-port2\gb\src\core\game.c:724: if (dir == 0) nx++;
	ld	a, c
	or	a, a
	jr	NZ, 00112$
	ld	d, b
	inc	d
	jr	00113$
00112$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:725: else if (dir == 1) ny++;
	ld	a, c
	dec	a
	jr	NZ, 00109$
	ld	a, e
	inc	a
	ldhl	sp,	#0
	ld	(hl), a
	jr	00113$
00109$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:726: else if (dir == 2) { if (nx > 0) nx--; }
	ld	a, c
	sub	a, #0x02
	jr	NZ, 00106$
	or	a, b
	jr	Z, 00113$
	ld	d, b
	dec	d
	jr	00113$
00106$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:727: else { if (ny > 0) ny--; }
	ld	a, e
	or	a, a
	jr	Z, 00113$
	ld	a, e
	dec	a
	ldhl	sp,	#0
	ld	(hl), a
00113$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:729: if (nx >= MAP_W || ny >= level_height) return;
	ld	a, d
	sub	a, #0x10
	jr	NC, 00125$
	ldhl	sp,	#0
	ld	a, (hl)
	ld	hl, #_level_height
	sub	a, (hl)
	jr	NC, 00125$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:730: nidx = (uint16_t)ny * MAP_W + nx;
	ldhl	sp,	#0
	ld	b, (hl)
	xor	a, a
	ld	l, b
	ld	h, a
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	e, d
	ld	d, #0x00
	add	hl, de
	ld	e, l
	ld	d, h
;C:\dev\AI\robbo-port2\gb\src\core\game.c:731: target = map_type[nidx];
	ld	hl, #_map_type
	add	hl, de
	ld	a, (hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:733: if (target == CT_EMPTY) {
	or	a, a
	jr	NZ, 00123$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:734: add_bullet(nidx, dir, btype, 1);
	ld	a, #0x01
	push	af
	inc	sp
	ldhl	sp,	#4
	ld	a, (hl)
	push	af
	inc	sp
	ld	a, c
	call	_add_bullet
	jr	00125$
00123$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:735: } else if (target == CT_ROBBO) {
	cp	a, #0x1a
	jr	NZ, 00120$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:736: kill_robbo();
	call	_kill_robbo
	jr	00125$
00120$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:737: } else if (is_demolishable(target)) {
	push	de
	call	_is_demolishable
	pop	de
	or	a, a
	jr	Z, 00125$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:738: demolish_cell(nidx);
	call	_demolish_cell
00125$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:740: }
	inc	sp
	pop	hl
	inc	sp
	jp	(hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:746: static void turret_tick(void)
;	---------------------------------
; Function turret_tick
; ---------------------------------
_turret_tick:
	add	sp, #-23
;C:\dev\AI\robbo-port2\gb\src\core\game.c:751: for (i = 0; i < turret_count; i++) {
	ldhl	sp,	#21
	ld	(hl), #0x00
00135$:
	ldhl	sp,	#21
	ld	a, (hl)
	ld	hl, #_turret_count
	sub	a, (hl)
	jp	NC, 00136$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:755: eidx = turret_list[i];
	ldhl	sp,	#21
	ld	a, (hl-)
	dec	hl
	ld	(hl+), a
	xor	a, a
	ld	(hl-), a
	ld	a, (hl-)
	dec	hl
	ld	(hl+), a
	xor	a, a
	ld	(hl-), a
	sla	(hl)
	inc	hl
	rl	(hl)
	dec	hl
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #_turret_list
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#21
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#20
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
;C:\dev\AI\robbo-port2\gb\src\core\game.c:756: if (map_type[eidx] != CT_TURRET) continue;
	ld	de, #_map_type
	ld	a, (hl-)
	ld	l, (hl)
	ld	h, a
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
	ld	d, (hl)
	ld	a, (de)
	sub	a, #0x12
	jp	NZ, 00132$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:757: state = map_obj[eidx];
	ld	de, #_map_obj
	ldhl	sp,	#19
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
	ldhl	sp,	#18
;C:\dev\AI\robbo-port2\gb\src\core\game.c:759: extra = map_extra[eidx];
	ld	(hl+), a
	ld	de, #_map_extra
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#10
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#9
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	a, (hl+)
	ld	d, a
	ld	a, (de)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:760: dir = extra & 3;
	ld	(hl+), a
	and	a, #0x03
;C:\dev\AI\robbo-port2\gb\src\core\game.c:761: mdir = (extra >> 2) & 3;
	ld	(hl-), a
	ld	a, (hl+)
	inc	hl
	rrca
	rrca
	and	a, #0x3
;C:\dev\AI\robbo-port2\gb\src\core\game.c:762: btype = (extra >> 4) & 3;
	ld	(hl-), a
	dec	hl
	ld	a, (hl)
	swap	a
	and	a, #0x3
	ldhl	sp,	#13
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:763: movable = extra & 0x40;
	ldhl	sp,	#10
	ld	a, (hl)
	and	a, #0x40
	ldhl	sp,	#22
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:764: rotatable = extra & 0x80;
	ldhl	sp,	#10
	ld	a, (hl)
	and	a, #0x80
	ldhl	sp,	#14
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:765: was_shot = state & TURRET_SHOT;
	ldhl	sp,	#18
	ld	a, (hl)
	and	a, #0x02
	ldhl	sp,	#15
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:766: state &= (uint8_t)~TURRET_SHOT;
	ldhl	sp,	#18
	ld	a, (hl-)
	dec	hl
	and	a, #0xfd
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:767: idx = eidx;
	ldhl	sp,	#19
	ld	a, (hl-)
	dec	hl
	ld	(hl), a
	ldhl	sp,	#20
	ld	a, (hl-)
	dec	hl
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:769: if (movable && !(state & TURRET_MOVED)) {
	ldhl	sp,	#22
	ld	a, (hl)
	or	a, a
	jp	Z, 00122$
	push	hl
	ldhl	sp,	#18
	bit	0, (hl)
	pop	hl
	jp	NZ, 00122$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:770: uint8_t nx = eidx % MAP_W;
	ldhl	sp,	#19
	ld	a, (hl)
	ldhl	sp,	#2
	ld	(hl), a
	ldhl	sp,	#20
	ld	a, (hl)
	ldhl	sp,	#3
	ld	(hl-), a
	ld	a, (hl-)
	dec	hl
	and	a, #0x0f
	ld	(hl+), a
	xor	a, a
	ld	(hl-), a
	ld	a, (hl)
	ldhl	sp,	#19
	ld	(hl), a
	ldhl	sp,	#22
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:771: uint8_t ny = eidx / MAP_W;
	ldhl	sp,#2
	ld	a, (hl+)
	ld	c, a
	ld	b, (hl)
	srl	b
	rr	c
	srl	b
	rr	c
	srl	b
	rr	c
	srl	b
	rr	c
	ldhl	sp,	#20
	ld	(hl),c
;C:\dev\AI\robbo-port2\gb\src\core\game.c:773: if (mdir == 0) nx++;
	ldhl	sp,	#12
	ld	a, (hl)
	or	a, a
	jr	NZ, 00114$
	ldhl	sp,	#22
	inc	(hl)
	jr	00115$
00114$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:774: else if (mdir == 1) ny++;
	ldhl	sp,	#12
	ld	a, (hl)
	dec	a
	jr	NZ, 00111$
	inc	c
	jr	00115$
00111$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:775: else if (mdir == 2) { if (nx > 0) nx--; }
	ldhl	sp,	#12
	ld	a, (hl)
	sub	a, #0x02
	jr	NZ, 00108$
	ldhl	sp,	#22
	ld	a, (hl)
	or	a, a
	jr	Z, 00115$
	dec	(hl)
	jr	00115$
00108$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:776: else { if (ny > 0) ny--; }
	ld	a, c
	or	a, a
	jr	Z, 00115$
	dec	c
00115$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:783: map_obj[nidx] = state | TURRET_MOVED;
	ldhl	sp,	#16
	ld	b, (hl)
	set	0, b
;C:\dev\AI\robbo-port2\gb\src\core\game.c:778: if (nx < MAP_W && ny < level_height &&
	ldhl	sp,	#22
	ld	a, (hl)
	sub	a, #0x10
	jr	NC, 00117$
	ld	a, c
	ld	hl, #_level_height
	sub	a, (hl)
	jr	NC, 00117$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:779: map_type[(uint16_t)ny * MAP_W + nx] == CT_EMPTY) {
	ld	l, c
	ld	h, #0x00
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	e, l
	ld	d, h
	ldhl	sp,	#22
	ld	l, (hl)
	ld	h, #0x00
	add	hl, de
	ld	e, l
	ld	d, h
	ld	hl, #_map_type
	add	hl, de
	ld	a, (hl)
	or	a, a
	jr	NZ, 00117$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:780: uint16_t nidx = (uint16_t)ny * MAP_W + nx;
	ldhl	sp,	#17
	ld	a, e
	ld	(hl+), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:781: map_type[nidx] = CT_TURRET;
	ld	a, d
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #_map_type
	add	hl, de
	ld	(hl), #0x12
;C:\dev\AI\robbo-port2\gb\src\core\game.c:782: map_extra[nidx] = extra;
	ldhl	sp,#17
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #_map_extra
	add	hl, de
	ld	e, l
	ld	d, h
	ldhl	sp,	#10
	ld	a, (hl)
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:783: map_obj[nidx] = state | TURRET_MOVED;
	ldhl	sp,#17
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #_map_obj
	add	hl, de
	ld	e, l
	ld	d, h
	ld	a, b
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:784: map_type[eidx] = CT_EMPTY;
	ldhl	sp,	#4
	ld	a, (hl+)
	ld	h, (hl)
	ld	l, a
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\core\game.c:785: map_extra[eidx] = 0;
	ldhl	sp,	#8
	ld	a, (hl+)
	ld	h, (hl)
	ld	l, a
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\core\game.c:786: map_obj[eidx] = 0;
	ldhl	sp,	#6
	ld	a, (hl+)
	ld	h, (hl)
	ld	l, a
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\core\game.c:787: render_cell(eidx % MAP_W, eidx / MAP_W);
	push	bc
	ldhl	sp,	#22
	ld	a, (hl-)
	ld	e, a
	ld	a, (hl)
	call	_render_cell
	pop	bc
;C:\dev\AI\robbo-port2\gb\src\core\game.c:788: render_cell(nx, ny);
	push	bc
	ld	e, c
	ldhl	sp,	#24
	ld	a, (hl)
	call	_render_cell
	pop	bc
;C:\dev\AI\robbo-port2\gb\src\core\game.c:789: idx = nidx;
	jr	00118$
00117$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:791: mdir = (mdir + 2) & 3;
	ldhl	sp,	#12
;C:\dev\AI\robbo-port2\gb\src\core\game.c:792: extra = (uint8_t)((extra & ~0x0C) | (mdir << 2));
	ld	a, (hl-)
	dec	hl
	add	a, #0x02
	and	a, #0x03
	ld	c, a
	ld	a, (hl)
	and	a, #0xf3
	sla	c
	sla	c
	or	a, c
;C:\dev\AI\robbo-port2\gb\src\core\game.c:793: map_extra[eidx] = extra;
	ld	(hl-), a
	dec	hl
	ld	a, (hl+)
	ld	e, a
	ld	a, (hl+)
	ld	d, a
	ld	a, (hl)
	ld	(de), a
00118$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:795: state |= TURRET_MOVED;
	ldhl	sp,	#22
	ld	(hl), b
	jr	00123$
00122$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:797: state &= (uint8_t)~TURRET_MOVED;
	ldhl	sp,	#16
	ld	a, (hl)
	and	a, #0xfe
	ldhl	sp,	#22
	ld	(hl), a
00123$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:800: if (rotatable && (next_rand8() & 15) == 0) {
	ldhl	sp,	#14
	ld	a, (hl)
	or	a, a
	jr	Z, 00129$
	call	_next_rand8
	and	a, #0x0f
	jr	NZ, 00129$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:801: int8_t delta = (int8_t)(next_rand8() % 3) - 1;
	call	_next_rand8
	ldhl	sp,#20
	ld	(hl), a
	ld	e, #0x03
	call	__moduchar
	ldhl	sp,#20
	ld	(hl), c
	ld	a, (hl-)
	dec	a
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:802: dir = (uint8_t)((dir + delta + 4) & 3);
	ldhl	sp,	#11
	ld	a, (hl)
	ldhl	sp,	#20
	ld	(hl), a
	ld	a, (hl-)
	add	a, (hl)
	inc	hl
	ld	(hl-), a
	inc	a
	inc	a
	inc	a
	inc	a
	and	a, #0x03
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:803: extra = (uint8_t)((extra & ~3) | dir);
	ldhl	sp,	#10
	ld	a, (hl)
	and	a, #0xfc
	ldhl	sp,	#20
	ld	(hl), a
	ld	a, (hl-)
	or	a, (hl)
	inc	hl
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:804: map_extra[idx] = extra;
	ld	de, #_map_extra
	ldhl	sp,	#17
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#17
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#16
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ldhl	sp,	#20
	ld	a, (hl)
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:805: render_cell(idx % MAP_W, idx / MAP_W);
	ldhl	sp,	#17
	ld	a, (hl+)
	ld	c, a
	ld	b, (hl)
	ld	e, c
	ld	d, b
	srl	d
	rr	e
	srl	d
	rr	e
	srl	d
	rr	e
	srl	d
	rr	e
	ld	a, c
	and	a, #0x0f
	call	_render_cell
	jr	00130$
00129$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:806: } else if ((next_rand8() % 12) == 0 && !was_shot) {
	call	_next_rand8
	ld	e, #0x0c
	call	__moduchar
	ld	a, c
	or	a, a
	jr	NZ, 00130$
	ldhl	sp,	#15
	ld	a, (hl)
	or	a, a
	jr	NZ, 00130$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:807: state |= TURRET_SHOT;
	ldhl	sp,	#22
	set	1, (hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:808: turret_fire(idx, dir, btype);
	ldhl	sp,	#13
	ld	a, (hl-)
	dec	hl
	push	af
	inc	sp
	ld	a, (hl)
	ldhl	sp,	#18
	ld	e, (hl)
	inc	hl
	ld	d, (hl)
	call	_turret_fire
00130$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:811: map_obj[idx] = state;
	ldhl	sp,#17
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #_map_obj
	add	hl, de
	ld	c, l
	ld	b, h
	ldhl	sp,	#22
	ld	a, (hl)
	ld	(bc), a
00132$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:751: for (i = 0; i < turret_count; i++) {
	ldhl	sp,	#21
	inc	(hl)
	jp	00135$
00136$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:813: }
	add	sp, #23
	ret
;C:\dev\AI\robbo-port2\gb\src\core\game.c:822: static void enemy_try_kill_at(uint8_t x, uint8_t y)
;	---------------------------------
; Function enemy_try_kill_at
; ---------------------------------
_enemy_try_kill_at:
	dec	sp
	ldhl	sp,	#0
	ld	(hl), a
	ld	c, e
;C:\dev\AI\robbo-port2\gb\src\core\game.c:826: if (robbo_dead) return;
	ld	a, (#_robbo_dead)
	or	a, a
	jr	NZ, 00107$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:827: if (map_type[(uint16_t)robbo_y * MAP_W + robbo_x] != CT_ROBBO) return;
	ld	a, (_robbo_y)
	ld	h, #0x00
	ld	l, a
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	a, (_robbo_x)
	ld	e, a
	ld	d, #0x00
	add	hl, de
	ld	e, l
	ld	d, h
	ld	hl, #_map_type
	add	hl, de
	ld	a, (hl)
	sub	a, #0x1a
	jr	NZ, 00107$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:829: dx = (robbo_x > x) ? (robbo_x - x) : (x - robbo_x);
	ldhl	sp,	#0
	ld	a, (hl)
	ld	hl, #_robbo_x
	sub	a, (hl)
	jr	NC, 00109$
	ld	a, (hl)
	ldhl	sp,	#0
	sub	a, (hl)
	jr	00110$
00109$:
	ldhl	sp,	#0
	ld	a, (hl)
	ld	hl, #_robbo_x
	sub	a, (hl)
00110$:
	ld	e, a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:830: dy = (robbo_y > y) ? (robbo_y - y) : (y - robbo_y);
	ld	a, c
	ld	hl, #_robbo_y
	sub	a, (hl)
	jr	NC, 00111$
	ld	a, (hl)
	sub	a, c
	jr	00112$
00111$:
	ld	a, c
	ld	hl, #_robbo_y
	sub	a, (hl)
00112$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:831: if (dx + dy == 1) {
	ld	d, #0x00
	ld	h, d
	ld	l, a
	add	hl, de
	ld	a, l
	dec	a
	or	a, h
	jr	NZ, 00107$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:832: kill_robbo();
	inc	sp
	jp	_kill_robbo
00107$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:834: }
	inc	sp
	ret
;C:\dev\AI\robbo-port2\gb\src\core\game.c:836: static void enemy_check_kills(void)
;	---------------------------------
; Function enemy_check_kills
; ---------------------------------
_enemy_check_kills:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:839: for (idx = 0; idx < MAP_CELLS; idx++) {
	ld	bc, #0x0000
00106$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:840: uint8_t type = map_type[idx];
	ld	hl, #_map_type
	add	hl, bc
	ld	a, (hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:841: if (type == CT_BEAR || type == CT_BUTTERFLY || type == CT_MUSTACHE) {
	cp	a, #0x17
	jr	Z, 00101$
	cp	a, #0x16
	jr	Z, 00101$
	sub	a, #0x15
	jr	NZ, 00107$
00101$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:842: enemy_try_kill_at(idx % MAP_W, idx / MAP_W);
	ld	l, c
	ld	h, b
	ld	e, l
	ld	d, h
	srl	d
	rr	e
	srl	d
	rr	e
	srl	d
	rr	e
	srl	d
	rr	e
	ld	a, l
	and	a, #0x0f
	push	bc
	call	_enemy_try_kill_at
	pop	bc
00107$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:839: for (idx = 0; idx < MAP_CELLS; idx++) {
	inc	bc
	ld	e, c
	ld	d, b
	ld	a, e
	sub	a, #0xf0
	ld	a, d
	sbc	a, #0x01
	jr	C, 00106$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:845: }
	ret
;C:\dev\AI\robbo-port2\gb\src\core\game.c:847: static uint8_t dirs_contains(const uint8_t *dirs, uint8_t count, uint8_t dir)
;	---------------------------------
; Function dirs_contains
; ---------------------------------
_dirs_contains:
	ld	c, a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:850: for (i = 0; i < count; i++) {
	ld	b, #0x00
00105$:
	ld	a, b
	sub	a, c
	jr	NC, 00103$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:851: if (dirs[i] == dir) return 1;
	ld	l, b
	ld	h, #0x00
	add	hl, de
	ld	a, (hl)
	ldhl	sp,	#2
	sub	a, (hl)
	jr	NZ, 00106$
	ld	a, #0x01
	jr	00107$
00106$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:850: for (i = 0; i < count; i++) {
	inc	b
	jr	00105$
00103$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:853: return 0;
	xor	a, a
00107$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:854: }
	pop	hl
	inc	sp
	jp	(hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:856: static uint16_t bear_step(uint16_t idx, uint8_t state)
;	---------------------------------
; Function bear_step
; ---------------------------------
_bear_step:
	add	sp, #-23
	ldhl	sp,	#20
	ld	(hl), e
	inc	hl
	ld	(hl), d
	ldhl	sp,	#0
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:858: uint8_t extra = map_extra[idx];
	ld	de, #_map_extra
	ldhl	sp,	#20
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
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
	ld	a, (hl+)
	ld	d, a
	ld	a, (de)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:859: uint8_t dir = extra & 3;
	ld	(hl), a
	and	a, #0x03
	ldhl	sp,	#19
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:860: uint8_t cw = (extra >> 2) & 1;
	ldhl	sp,	#3
	ld	a, (hl)
	rrca
	rrca
;C:\dev\AI\robbo-port2\gb\src\core\game.c:861: int8_t add = cw ? 1 : -1;
	and	a, #0x01
	ld	a, #0x01
	jr	NZ, 00120$
	ld	a, #0xff
00120$:
	ldhl	sp,	#4
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:862: uint8_t original = dir;
	ldhl	sp,	#19
	ld	a, (hl)
	ldhl	sp,	#5
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:865: if (state & BEAR_SKIP) {
	push	hl
	ldhl	sp,	#2
	bit	1, (hl)
	pop	hl
	jr	Z, 00131$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:866: state &= (uint8_t)~BEAR_SKIP;
	ldhl	sp,	#0
	ld	a, (hl)
	and	a, #0xfd
	ldhl	sp,	#22
;C:\dev\AI\robbo-port2\gb\src\core\game.c:867: map_obj[idx] = state;
	ld	(hl-), a
	ld	de, #_map_obj
	ld	a, (hl-)
	ld	l, (hl)
	ld	h, a
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#20
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#19
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ldhl	sp,	#22
;C:\dev\AI\robbo-port2\gb\src\core\game.c:868: return idx;
	ld	a, (hl-)
	dec	hl
	ld	(de), a
	ld	c, (hl)
	inc	hl
	ld	b, (hl)
	jp	00117$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:871: for (i = 2; i; ) {
00131$:
	ldhl	sp,	#0
	ld	a, (hl)
	and	a, #0x01
	ldhl	sp,	#6
	ld	(hl+), a
	ld	(hl), #0x00
	ldhl	sp,	#4
	ld	a, (hl)
	add	a, a
	ldhl	sp,	#8
	ld	(hl), a
	ldhl	sp,	#22
	ld	(hl), #0x02
00115$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:875: --i;
	ldhl	sp,	#22
	dec	(hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:876: test = dir;
	ldhl	sp,	#19
;C:\dev\AI\robbo-port2\gb\src\core\game.c:877: dir = (uint8_t)((dir + 4 - add) & 3);
	ld	a,(hl)
	ld	c,a
	add	a, #0x04
	ldhl	sp,	#4
	sub	a, (hl)
	and	a, #0x03
	ldhl	sp,	#9
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:879: nx = (int16_t)(idx % MAP_W) + tp_dx[test];
	ldhl	sp,	#20
	ld	a, (hl)
	ldhl	sp,	#16
	ld	(hl), a
	ldhl	sp,	#21
	ld	a, (hl)
	ldhl	sp,	#17
	ld	(hl-), a
	ld	a, (hl)
	and	a, #0x0f
	ldhl	sp,	#10
	ld	(hl+), a
	xor	a, a
	ld	(hl-), a
	ld	e, (hl)
	ld	hl, #_tp_dx
	ld	b, #0x00
	add	hl, bc
	ld	a, (hl)
	ld	l, a
	rlca
	sbc	a, a
	ld	h, a
	ld	d, #0x00
	add	hl, de
	ld	e, l
	ld	d, h
	ldhl	sp,	#18
	ld	a, e
	ld	(hl+), a
	ld	(hl), d
;C:\dev\AI\robbo-port2\gb\src\core\game.c:880: ny = (int16_t)(idx / MAP_W) + tp_dy[test];
	ldhl	sp,	#16
	ld	a, (hl)
	ldhl	sp,	#12
	ld	(hl), a
	ldhl	sp,	#17
	ld	a, (hl)
	ldhl	sp,	#13
	ld	(hl), a
	srl	(hl)
	dec	hl
	rr	(hl)
	inc	hl
	srl	(hl)
	dec	hl
	rr	(hl)
	inc	hl
	srl	(hl)
	dec	hl
	rr	(hl)
	inc	hl
	srl	(hl)
	dec	hl
	rr	(hl)
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	l, c
	ld	h, #0x00
	ld	bc, #_tp_dy
	add	hl, bc
	ld	a, (hl)
	ld	l, a
	rlca
	sbc	a, a
	ld	h, a
	add	hl, de
	ld	c, l
	ld	b, h
	ldhl	sp,	#14
	ld	a, c
	ld	(hl+), a
	ld	(hl), b
;C:\dev\AI\robbo-port2\gb\src\core\game.c:881: if (nx >= 0 && ny >= 0 && nx < MAP_W && ny < level_height) {
	ldhl	sp,	#18
	ld	a, (hl+)
	ld	c, a
	ld	b, (hl)
	bit	7, b
	jp	NZ, 00110$
	ldhl	sp,	#14
	ld	a, (hl+)
	inc	hl
	ld	(hl-), a
	ld	a, (hl+)
	inc	hl
	ld	(hl), a
	bit	7, (hl)
	jp	NZ, 00110$
	ld	a, c
	sub	a, #0x10
	ld	a, b
	sbc	a, #0x00
	jp	NC, 00110$
	ld	a, (_level_height)
	ld	c, a
	ld	b, #0x00
	ldhl	sp,	#14
	ld	a, (hl+)
	sub	a, c
	ld	a, (hl)
	sbc	a, b
	ld	d, (hl)
	ld	a, b
	bit	7,a
	jr	Z, 00206$
	bit	7, d
	jr	NZ, 00207$
	cp	a, a
	jr	00207$
00206$:
	bit	7, d
	jr	Z, 00207$
	scf
00207$:
	jp	NC, 00110$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:882: uint16_t nidx = (uint16_t)ny * MAP_W + (uint8_t)nx;
	ldhl	sp,	#14
	ld	a, (hl+)
	ld	c, (hl)
	ld	l, a
	ld	h, c
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	c, l
	ld	b, h
	ldhl	sp,	#18
	ld	a, (hl-)
	dec	hl
	ld	(hl), a
	ld	l, (hl)
	ld	h, #0x00
	add	hl, bc
	ld	c, l
	ld	a, h
	ldhl	sp,	#17
	ld	(hl), c
	inc	hl
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:883: if (map_type[nidx] == CT_EMPTY) {
	ld	bc, #_map_type+0
	ld	a, (hl-)
	ld	l, (hl)
	ld	h, a
	add	hl, bc
	ld	e, l
	ld	d, h
	ld	a, (de)
	ldhl	sp,	#19
	ld	(hl), a
	or	a, a
	jr	NZ, 00104$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:884: map_type[nidx] = CT_BEAR;
;C:\dev\AI\robbo-port2\gb\src\core\game.c:885: map_extra[nidx] = (uint8_t)((extra & ~3) | dir);
	dec	hl
	ld	a, #0x17
	ld	(de), a
	ld	de, #_map_extra
	ld	a, (hl-)
	ld	l, (hl)
	ld	h, a
	add	hl, de
	ld	e, l
	ld	d, h
	ldhl	sp,	#3
	ld	a, (hl)
	and	a, #0xfc
	ldhl	sp,	#9
	or	a, (hl)
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:886: map_obj[nidx] = (uint8_t)(state & ~(BEAR_LAST_SKIP | BEAR_SKIP));
	ld	de, #_map_obj
	ldhl	sp,	#17
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	e, l
	ld	d, h
	ldhl	sp,	#0
	ld	a, (hl)
	and	a, #0xfc
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:887: map_type[idx] = CT_EMPTY;
	ldhl	sp,	#20
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, bc
	ld	c, l
	ld	b, h
	xor	a, a
	ld	(bc), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:888: map_extra[idx] = 0;
	ldhl	sp,	#1
	ld	a, (hl+)
	ld	h, (hl)
	ld	l, a
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\core\game.c:889: map_obj[idx] = 0;
	ld	de, #_map_obj
	ldhl	sp,	#20
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#10
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#9
	ld	(hl-), a
	ld	a, (hl+)
	ld	h, (hl)
	ld	l, a
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\core\game.c:890: render_cell(idx % MAP_W, idx / MAP_W);
	ldhl	sp,	#12
	ld	a, (hl)
	ldhl	sp,	#22
	ld	(hl), a
	ldhl	sp,	#10
	ld	a, (hl)
	ldhl	sp,	#19
	ld	(hl), a
	ldhl	sp,	#22
	ld	e, (hl)
	ldhl	sp,	#19
	ld	a, (hl)
	call	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:891: render_cell((uint8_t)nx, (uint8_t)ny);
	ldhl	sp,	#14
	ld	a, (hl+)
	inc	hl
	ld	e, a
	ld	a, (hl)
	call	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:892: return nidx;
	ldhl	sp,	#17
	ld	c, (hl)
	inc	hl
	ld	b, (hl)
	jp	00117$
00104$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:894: if (map_type[nidx] == CT_BEAR && i == 0 && !(state & BEAR_LAST_SKIP)) {
	ldhl	sp,	#19
	ld	a, (hl)
	sub	a, #0x17
	jr	NZ, 00110$
	ldhl	sp,	#22
	ld	a, (hl)
	or	a, a
	jr	NZ, 00110$
	ldhl	sp,	#6
	or	a, (hl)
	jr	NZ, 00110$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:895: state |= BEAR_LAST_SKIP | BEAR_SKIP;
	ldhl	sp,	#0
	ld	a, (hl)
	or	a, #0x03
	ld	c, a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:896: extra = (uint8_t)((extra & ~3) | original);
	ldhl	sp,	#3
	ld	a, (hl+)
	inc	hl
	and	a, #0xfc
	or	a, (hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:897: map_extra[idx] = extra;
	ldhl	sp,	#1
	ld	e, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, e
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:898: map_obj[idx] = state;
	ld	de, #_map_obj
	ldhl	sp,	#20
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	e, l
	ld	d, h
	ld	a, c
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:899: return idx;
	ldhl	sp,	#20
	ld	c, (hl)
	inc	hl
	ld	b, (hl)
	jr	00117$
00110$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:902: dir = (uint8_t)((dir + 4 + add * 2) & 3);
	ldhl	sp,	#9
	ld	a, (hl-)
	add	a, #0x04
	add	a, (hl)
	and	a, #0x03
	ldhl	sp,	#19
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:871: for (i = 2; i; ) {
	ldhl	sp,	#22
	ld	a, (hl)
	or	a, a
	jp	NZ, 00115$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:905: map_extra[idx] = (uint8_t)((extra & ~3) | dir);
	ldhl	sp,	#3
	ld	a, (hl)
	and	a, #0xfc
	ldhl	sp,	#22
	ld	(hl), a
	ldhl	sp,	#19
	or	a, (hl)
	ldhl	sp,	#1
	ld	e, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, e
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:906: state &= (uint8_t)~BEAR_LAST_SKIP;
	ldhl	sp,	#0
	ld	a, (hl)
	and	a, #0xfe
	ldhl	sp,	#22
;C:\dev\AI\robbo-port2\gb\src\core\game.c:907: map_obj[idx] = state;
	ld	(hl-), a
	ld	de, #_map_obj
	ld	a, (hl-)
	ld	l, (hl)
	ld	h, a
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#20
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#19
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ldhl	sp,	#22
;C:\dev\AI\robbo-port2\gb\src\core\game.c:908: return idx;
	ld	a, (hl-)
	dec	hl
	ld	(de), a
	ld	c, (hl)
	inc	hl
	ld	b, (hl)
00117$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:909: }
	add	sp, #23
	ret
;C:\dev\AI\robbo-port2\gb\src\core\game.c:911: static uint16_t butterfly_step(uint16_t idx, uint8_t state)
;	---------------------------------
; Function butterfly_step
; ---------------------------------
_butterfly_step:
	add	sp, #-20
	ldhl	sp,	#18
	ld	(hl), e
	inc	hl
	ld	(hl), d
	ldhl	sp,	#4
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:913: uint8_t extra = map_extra[idx];
	ld	de, #_map_extra
	ldhl	sp,	#18
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
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
	ld	a, (hl+)
	ld	d, a
	ld	a, (de)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:914: uint8_t dir = extra & 3;
	ld	(hl), a
	and	a, #0x03
	ld	c, a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:916: uint8_t count = 0;
	ldhl	sp,	#17
;C:\dev\AI\robbo-port2\gb\src\core\game.c:918: uint8_t x = idx % MAP_W;
	xor	a, a
	ld	(hl+), a
	ld	a, (hl+)
	ld	e, a
	ld	b, (hl)
	and	a, #0x0f
	ld	d, #0x00
	ldhl	sp,	#8
;C:\dev\AI\robbo-port2\gb\src\core\game.c:919: uint8_t y = idx / MAP_W;
	ld	(hl+), a
	srl	b
	rr	e
	srl	b
	rr	e
	srl	b
	rr	e
	srl	b
	rr	e
	ld	(hl), e
;C:\dev\AI\robbo-port2\gb\src\core\game.c:922: if (robbo_x < x) dirs[count++] = 2;
	ld	a, (#_robbo_x)
	ldhl	sp,	#8
	sub	a, (hl)
	jr	NC, 00102$
	ldhl	sp,	#17
	ld	(hl), #0x01
	ldhl	sp,	#0
	ld	(hl), #0x02
00102$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:923: if (robbo_x > x) dirs[count++] = 0;
	ldhl	sp,	#8
	ld	a, (hl)
	ld	hl, #_robbo_x
	sub	a, (hl)
	jr	NC, 00104$
	ldhl	sp,	#17
	ld	e, (hl)
	inc	(hl)
	ld	d, #0x00
	ld	hl, #0
	add	hl, sp
	add	hl, de
	ld	(hl), #0x00
00104$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:924: if (robbo_y < y) dirs[count++] = 3;
	ld	a, (#_robbo_y)
	ldhl	sp,	#9
	sub	a, (hl)
	jr	NC, 00106$
	ldhl	sp,	#17
	ld	e, (hl)
	inc	(hl)
	ld	d, #0x00
	ld	hl, #0
	add	hl, sp
	add	hl, de
	ld	(hl), #0x03
00106$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:925: if (robbo_y > y) dirs[count++] = 1;
	ldhl	sp,	#9
	ld	a, (hl)
	ld	hl, #_robbo_y
	sub	a, (hl)
	jr	NC, 00108$
	ldhl	sp,	#17
	ld	e, (hl)
	inc	(hl)
	ld	d, #0x00
	ld	hl, #0
	add	hl, sp
	add	hl, de
	ld	(hl), #0x01
00108$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:927: if (count == 0) {
	ldhl	sp,	#17
	ld	a, (hl)
	or	a, a
	jr	NZ, 00110$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:928: map_obj[idx] = state;
	inc	hl
	ld	bc, #_map_obj+0
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, bc
	ld	c, l
	ld	b, h
	ldhl	sp,	#4
	ld	a, (hl)
	ld	(bc), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:929: return idx;
	ldhl	sp,	#18
	ld	c, (hl)
	inc	hl
	ld	b, (hl)
	jp	00129$
00110$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:932: last = (state & BFLY_VALID) ? dir : 0xFF;
	push	hl
	ldhl	sp,	#6
	bit	0, (hl)
	pop	hl
	jr	NZ, 00132$
	ld	c, #0xff
00132$:
	ldhl	sp,	#16
	ld	(hl), c
;C:\dev\AI\robbo-port2\gb\src\core\game.c:934: if (((next_rand8() & 1) == 0) && last != 0xFF && dirs_contains(dirs, count, last)) {
	call	_next_rand8
	rrca
	jr	C, 00118$
	ldhl	sp,	#16
	ld	a, (hl)
	inc	a
	jr	Z, 00118$
	ldhl	sp,	#0
	ld	e, l
	ld	d, h
	ldhl	sp,	#16
	ld	a, (hl+)
	push	af
	inc	sp
	ld	a, (hl)
	call	_dirs_contains
	or	a, a
	jr	Z, 00118$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:935: dir = last;
	ldhl	sp,	#16
	ld	c, (hl)
	jr	00119$
00118$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:936: } else if ((next_rand8() % 6) == 0) {
	call	_next_rand8
	ld	e, #0x06
	call	__moduchar
	ld	a, c
	or	a, a
	jr	NZ, 00115$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:937: dir = dirs[0];
	ldhl	sp,	#0
	ld	c, (hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:938: while (dirs_contains(dirs, count, dir)) {
00111$:
	push	bc
	ld	a, c
	push	af
	inc	sp
	ldhl	sp,	#20
	ld	a, (hl)
	ld	hl, #3
	add	hl, sp
	ld	e, l
	ld	d, h
	call	_dirs_contains
	pop	bc
	or	a, a
	jr	Z, 00119$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:939: dir = next_rand8() & 3;
	call	_next_rand8
	and	a, #0x03
	ld	c, a
	jr	00111$
00115$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:942: dir = dirs[next_rand8() % count];
	call	_next_rand8
	ldhl	sp,	#17
	ld	e, (hl)
	call	__moduchar
	ld	e, c
	ld	d, #0x00
	ld	hl, #0
	add	hl, sp
	add	hl, de
	ld	c, (hl)
00119$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:945: nx = (int16_t)x + tp_dx[dir];
	ldhl	sp,	#8
	ld	e, (hl)
	ld	hl, #_tp_dx
	ld	b, #0x00
	add	hl, bc
	ld	a, (hl)
	ld	l, a
	rlca
	sbc	a, a
	ld	h, a
	ld	d, #0x00
	add	hl, de
	ld	e, l
	ld	a, h
	ldhl	sp,	#10
	ld	(hl), e
	inc	hl
;C:\dev\AI\robbo-port2\gb\src\core\game.c:946: ny = (int16_t)y + tp_dy[dir];
	ld	(hl-), a
	dec	hl
	ld	e, (hl)
	ld	hl, #_tp_dy
	ld	b, #0x00
	add	hl, bc
	ld	a, (hl)
	ld	l, a
	rlca
	sbc	a, a
	ld	h, a
	ld	d, #0x00
	add	hl, de
	ld	b, l
	ld	a, h
	ldhl	sp,	#12
	ld	(hl), b
	inc	hl
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:947: if (nx >= 0 && ny >= 0 && nx < MAP_W && ny < level_height) {
	ldhl	sp,	#10
	ld	a, (hl)
	ldhl	sp,	#14
	ld	(hl), a
	ldhl	sp,	#11
	ld	a, (hl)
	ldhl	sp,	#15
	ld	(hl), a
	bit	7, (hl)
	jp	NZ, 00125$
	ldhl	sp,	#12
	ld	a, (hl)
	ldhl	sp,	#16
	ld	(hl), a
	ldhl	sp,	#13
	ld	a, (hl)
	ldhl	sp,	#17
	ld	(hl), a
	bit	7, (hl)
	jp	NZ, 00125$
	ldhl	sp,	#14
	ld	a, (hl+)
	sub	a, #0x10
	ld	a, (hl)
	sbc	a, #0x00
	jp	NC, 00125$
	ld	a, (#_level_height)
	ldhl	sp,	#16
	ld	(hl+), a
	ld	(hl), #0x00
	ldhl	sp,	#12
	ld	e, l
	ld	d, h
	ldhl	sp,	#16
	ld	a, (de)
	inc	de
	sub	a, (hl)
	inc	hl
	ld	a, (de)
	sbc	a, (hl)
	ld	a, (de)
	ld	d, a
	bit	7, (hl)
	jr	Z, 00256$
	bit	7, d
	jr	NZ, 00257$
	cp	a, a
	jr	00257$
00256$:
	bit	7, d
	jr	Z, 00257$
	scf
00257$:
	jp	NC, 00125$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:948: uint16_t nidx = (uint16_t)ny * MAP_W + (uint8_t)nx;
	ldhl	sp,	#12
	ld	a, (hl+)
	ld	d, (hl)
	ld	l, a
	ld	h, d
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	e, l
	ld	d, h
	ldhl	sp,	#10
	ld	b, (hl)
	ld	l, b
	ld	h, #0x00
	add	hl, de
	ld	e, l
	ld	d, h
	ldhl	sp,	#16
	ld	a, e
	ld	(hl+), a
	ld	(hl), d
;C:\dev\AI\robbo-port2\gb\src\core\game.c:949: if (map_type[nidx] == CT_EMPTY) {
	ld	de, #_map_type
	ld	a, (hl-)
	ld	l, (hl)
	ld	h, a
	add	hl, de
	ld	e, l
	ld	d, h
	ld	a, (de)
	or	a, a
	jr	NZ, 00125$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:950: map_type[nidx] = CT_BUTTERFLY;
	ld	a, #0x16
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:951: map_extra[nidx] = (uint8_t)((extra & ~3) | dir);
	ldhl	sp,#16
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #_map_extra
	add	hl, de
	ld	e, l
	ld	d, h
	ldhl	sp,	#7
	ld	a, (hl)
	and	a, #0xfc
	or	a, c
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:952: map_obj[nidx] = (uint8_t)(state | BFLY_VALID);
	ld	de, #_map_obj
	ldhl	sp,	#16
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	e, l
	ld	d, h
	ldhl	sp,	#4
	ld	a, (hl)
	set	0, a
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:953: map_type[idx] = CT_EMPTY;
	ld	de, #_map_type
	ldhl	sp,	#18
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	e, l
	ld	d, h
	xor	a, a
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:954: map_extra[idx] = 0;
	ldhl	sp,	#5
	ld	a, (hl+)
	ld	h, (hl)
	ld	l, a
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\core\game.c:955: map_obj[idx] = 0;
	ld	de, #_map_obj
	ldhl	sp,	#18
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	e, l
	ld	d, h
	xor	a, a
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:956: render_cell(x, y);
	push	bc
	ldhl	sp,	#11
	ld	a, (hl-)
	ld	e, a
	ld	a, (hl)
	call	_render_cell
	pop	bc
;C:\dev\AI\robbo-port2\gb\src\core\game.c:957: render_cell((uint8_t)nx, (uint8_t)ny);
	ldhl	sp,	#12
	ld	e, (hl)
	ld	a, b
	call	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:958: return nidx;
	ldhl	sp,	#16
	ld	c, (hl)
	inc	hl
	ld	b, (hl)
	jr	00129$
00125$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:962: state &= (uint8_t)~BFLY_VALID;
	ldhl	sp,	#4
	ld	a, (hl)
	and	a, #0xfe
	ld	c, a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:963: map_obj[idx] = state;
	ld	de, #_map_obj+0
	ldhl	sp,	#18
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	e, l
	ld	d, h
	ld	a, c
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:964: return idx;
	ldhl	sp,	#18
	ld	c, (hl)
	inc	hl
	ld	b, (hl)
00129$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:965: }
	add	sp, #20
	ret
;C:\dev\AI\robbo-port2\gb\src\core\game.c:967: static uint16_t mustache_step(uint16_t idx, uint8_t state)
;	---------------------------------
; Function mustache_step
; ---------------------------------
_mustache_step:
	add	sp, #-18
	ldhl	sp,	#16
	ld	(hl), e
	inc	hl
	ld	(hl), d
	ldhl	sp,	#14
;C:\dev\AI\robbo-port2\gb\src\core\game.c:969: uint8_t extra = map_extra[idx];
	ld	(hl+), a
	inc	hl
	ld	de, #_map_extra
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	c, l
	ld	b, h
	ld	a, (bc)
	ldhl	sp,	#0
;C:\dev\AI\robbo-port2\gb\src\core\game.c:970: uint8_t dir = extra & 3;
	ld	(hl+), a
	and	a, #0x03
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:971: uint8_t was_shot = state & MUST_JUST_SHOT;
	ldhl	sp,	#14
	ld	a, (hl)
	and	a, #0x02
	ldhl	sp,	#2
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:972: uint8_t x = idx % MAP_W;
	ldhl	sp,	#16
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, e
	and	a, #0x0f
	ldhl	sp,	#12
	ld	(hl+), a
	xor	a, a
	ld	(hl-), a
	ld	a, (hl)
	ldhl	sp,	#3
;C:\dev\AI\robbo-port2\gb\src\core\game.c:973: uint8_t y = idx / MAP_W;
	ld	(hl+), a
	srl	d
	rr	e
	srl	d
	rr	e
	srl	d
	rr	e
	srl	d
	rr	e
	ld	(hl), e
;C:\dev\AI\robbo-port2\gb\src\core\game.c:974: uint16_t cur = idx;
	ldhl	sp,	#16
	ld	a, (hl)
	ldhl	sp,	#5
	ld	(hl), a
	ldhl	sp,	#17
	ld	a, (hl)
	ldhl	sp,	#6
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:976: state &= (uint8_t)~MUST_JUST_SHOT;
	ldhl	sp,	#14
	ld	a, (hl+)
	and	a, #0xfd
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:978: enemy_try_kill_at(x, y);
	push	bc
	ldhl	sp,	#6
	ld	a, (hl-)
	ld	e, a
	ld	a, (hl)
	call	_enemy_try_kill_at
	pop	bc
;C:\dev\AI\robbo-port2\gb\src\core\game.c:979: if (robbo_dead) {
	ld	hl, #_robbo_dead
	ld	a, (hl)
	or	a, a
	jr	Z, 00102$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:980: map_obj[idx] = state;
	ld	bc, #_map_obj+0
	ldhl	sp,	#16
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, bc
	ld	c, l
	ld	b, h
	ldhl	sp,	#15
;C:\dev\AI\robbo-port2\gb\src\core\game.c:981: return idx;
	ld	a, (hl+)
	ld	(bc), a
	ld	c, (hl)
	inc	hl
	ld	b, (hl)
	jp	00117$
00102$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:984: if (state & MUST_INNER_SKIP) {
	push	hl
	ldhl	sp,	#17
	bit	0, (hl)
	pop	hl
	jr	Z, 00111$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:985: state &= (uint8_t)~MUST_INNER_SKIP;
	ldhl	sp,	#15
	res	0, (hl)
	jp	00112$
00111$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:987: int16_t nx = (int16_t)x + tp_dx[dir];
	ldhl	sp,	#3
	ld	a, (hl)
	ldhl	sp,	#12
	ld	(hl), a
	ld	de, #_tp_dx
	ldhl	sp,	#1
	ld	l, (hl)
	ld	h, #0x00
	add	hl, de
	ld	e, l
	ld	d, h
	ld	a, (de)
	ldhl	sp,	#13
	ld	(hl+), a
	rlca
	sbc	a, a
	ld	(hl-), a
	dec	hl
	ld	a, (hl+)
	ld	e, a
	ld	d, #0x00
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	e, l
	ld	a, h
	ldhl	sp,	#7
	ld	(hl), e
	inc	hl
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:988: int16_t ny = (int16_t)y + tp_dy[dir];
	ldhl	sp,	#4
	ld	a, (hl)
	ldhl	sp,	#12
	ld	(hl), a
	ld	de, #_tp_dy
	ldhl	sp,	#1
	ld	l, (hl)
	ld	h, #0x00
	add	hl, de
	ld	e, l
	ld	d, h
	ld	a, (de)
	ldhl	sp,	#13
	ld	(hl+), a
	rlca
	sbc	a, a
	ld	(hl-), a
	dec	hl
	ld	a, (hl+)
	ld	e, a
	ld	d, #0x00
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	e, l
	ld	a, h
	ldhl	sp,	#9
	ld	(hl), e
	inc	hl
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:989: if (nx >= 0 && ny >= 0 && nx < MAP_W && ny < level_height &&
	ldhl	sp,	#7
	ld	a, (hl)
	ldhl	sp,	#11
	ld	(hl), a
	ldhl	sp,	#8
	ld	a, (hl)
	ldhl	sp,	#12
	ld	(hl), a
	bit	7, (hl)
	jp	NZ, 00104$
	ldhl	sp,	#9
	ld	a, (hl)
	ldhl	sp,	#13
	ld	(hl), a
	ldhl	sp,	#10
	ld	a, (hl)
	ldhl	sp,	#14
	ld	(hl), a
	bit	7, (hl)
	jp	NZ, 00104$
	ldhl	sp,	#11
	ld	a, (hl+)
	sub	a, #0x10
	ld	a, (hl)
	sbc	a, #0x00
	jp	NC, 00104$
	ld	a, (#_level_height)
	ldhl	sp,	#13
	ld	(hl+), a
	ld	(hl), #0x00
	ldhl	sp,	#9
	ld	e, l
	ld	d, h
	ldhl	sp,	#13
	ld	a, (de)
	inc	de
	sub	a, (hl)
	inc	hl
	ld	a, (de)
	sbc	a, (hl)
	ld	a, (de)
	ld	d, a
	bit	7, (hl)
	jr	Z, 00190$
	bit	7, d
	jr	NZ, 00191$
	cp	a, a
	jr	00191$
00190$:
	bit	7, d
	jr	Z, 00191$
	scf
00191$:
	jp	NC, 00104$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:990: map_type[(uint16_t)ny * MAP_W + (uint8_t)nx] == CT_EMPTY) {
	ldhl	sp,	#9
	ld	a, (hl+)
	ld	e, (hl)
	ld	l, a
	ld	h, e
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	e, l
	ld	d, h
	ldhl	sp,	#7
	ld	a, (hl)
	ldhl	sp,	#14
	ld	(hl), a
	ld	l, (hl)
	ld	h, #0x00
	add	hl, de
	ld	e, l
	ld	d, h
	ld	hl, #_map_type
	add	hl, de
	ld	a, (hl)
	or	a, a
	jr	NZ, 00104$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:991: uint16_t nidx = (uint16_t)ny * MAP_W + (uint8_t)nx;
	ldhl	sp,	#12
	ld	a, e
	ld	(hl+), a
	ld	(hl), d
;C:\dev\AI\robbo-port2\gb\src\core\game.c:992: map_type[nidx] = CT_MUSTACHE;
	ld	de, #_map_type
	ld	a, (hl-)
	ld	l, (hl)
	ld	h, a
	add	hl, de
	ld	(hl), #0x15
;C:\dev\AI\robbo-port2\gb\src\core\game.c:993: map_extra[nidx] = extra;
	ld	de, #_map_extra
	ldhl	sp,	#12
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	e, l
	ld	d, h
	ldhl	sp,	#0
	ld	a, (hl)
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:994: map_obj[nidx] = state;
	ld	de, #_map_obj
	ldhl	sp,	#12
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	e, l
	ld	d, h
	ldhl	sp,	#15
;C:\dev\AI\robbo-port2\gb\src\core\game.c:995: map_type[idx] = CT_EMPTY;
	ld	a, (hl+)
	ld	(de), a
	ld	de, #_map_type
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	e, l
	ld	d, h
;C:\dev\AI\robbo-port2\gb\src\core\game.c:996: map_extra[idx] = 0;
	xor	a, a
	ld	(de), a
	ld	(bc), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:997: map_obj[idx] = 0;
	ld	de, #_map_obj
	ldhl	sp,	#16
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	c, l
	ld	b, h
	xor	a, a
	ld	(bc), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:998: render_cell(x, y);
	ldhl	sp,	#4
	ld	a, (hl-)
	ld	e, a
	ld	a, (hl)
	call	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:999: render_cell((uint8_t)nx, (uint8_t)ny);
	ldhl	sp,	#9
	ld	e, (hl)
	ldhl	sp,	#14
	ld	a, (hl)
	call	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1000: cur = nidx;
	ldhl	sp,	#12
	ld	a, (hl)
	ldhl	sp,	#5
	ld	(hl), a
	ldhl	sp,	#13
	ld	a, (hl)
	ldhl	sp,	#6
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1002: y = (uint8_t)ny;
	jr	00112$
00104$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1004: dir = (dir + 2) & 3;
	ldhl	sp,	#1
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1005: extra = (uint8_t)((extra & ~3) | dir);
	ld	a, (hl-)
	add	a, #0x02
	and	a, #0x03
	ld	e, a
	ld	a, (hl)
	and	a, #0xfc
	or	a, e
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1006: map_extra[idx] = extra;
	ld	(hl), a
	ld	(bc), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1007: state |= MUST_INNER_SKIP;
	ldhl	sp,	#15
	set	0, (hl)
00112$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1011: if ((extra & 4) && ((next_rand8() & 7) == 0) && !was_shot) {
	push	hl
	ldhl	sp,	#2
	bit	2, (hl)
	pop	hl
	jr	Z, 00114$
	call	_next_rand8
	and	a, #0x07
	jr	NZ, 00114$
	ldhl	sp,	#2
	ld	a, (hl)
	or	a, a
	jr	NZ, 00114$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1012: state |= MUST_JUST_SHOT;
	ldhl	sp,	#15
	set	1, (hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1013: turret_fire(cur, 1, 0);  /* mustaches shoot downward */
	xor	a, a
	push	af
	inc	sp
	ld	a, #0x01
	ldhl	sp,	#6
	ld	e, (hl)
	inc	hl
	ld	d, (hl)
	call	_turret_fire
00114$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1016: map_obj[cur] = state;
	ld	de, #_map_obj
	ldhl	sp,	#5
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	c, l
	ld	b, h
	ldhl	sp,	#15
	ld	a, (hl)
	ld	(bc), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1017: return cur;
	ldhl	sp,	#5
	ld	c, (hl)
	inc	hl
	ld	b, (hl)
00117$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1018: }
	add	sp, #18
	ret
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1020: static void collect_actors(void)
;	---------------------------------
; Function collect_actors
; ---------------------------------
_collect_actors:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1024: turret_count = 0;
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1025: enemy_count = 0;
	xor	a, a
	ld	(#_turret_count), a
	ld	(#_enemy_count),a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1026: bomb_count = 0;
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1027: explosion_count = 0;
	xor	a, a
	ld	(#_bomb_count), a
	ld	hl, #_explosion_count
	ld	(hl+), a
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1029: for (idx = 0; idx < MAP_CELLS; idx++) {
	ld	bc, #0x0000
00123$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1030: uint8_t type = map_type[idx];
	ld	hl, #_map_type
	add	hl, bc
	ld	e, (hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1032: if (type == CT_TURRET) {
	ld	a, e
	sub	a, #0x12
	jr	NZ, 00120$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1033: if (turret_count < MAX_TURRET_LIST) turret_list[turret_count++] = idx;
	ld	hl, #_turret_count
	ld	a, (hl)
	sub	a, #0x10
	jr	NC, 00124$
	ld	e, (hl)
	inc	(hl)
	xor	a, a
	ld	l, e
	ld	h, a
	add	hl, hl
	ld	de, #_turret_list
	add	hl, de
	ld	a, c
	ld	(hl+), a
	ld	(hl), b
	jr	00124$
00120$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1034: } else if (type == CT_BEAR || type == CT_BUTTERFLY || type == CT_MUSTACHE) {
	ld	a,e
	cp	a,#0x17
	jr	Z, 00114$
	cp	a,#0x16
	jr	Z, 00114$
	sub	a, #0x15
	jr	NZ, 00115$
00114$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1035: if (enemy_count < MAX_ENEMY_LIST) enemy_list[enemy_count++] = idx;
	ld	hl, #_enemy_count
	ld	a, (hl)
	sub	a, #0x28
	jr	NC, 00124$
	ld	e, (hl)
	inc	(hl)
	xor	a, a
	ld	l, e
	ld	h, a
	add	hl, hl
	ld	de, #_enemy_list
	add	hl, de
	ld	a, c
	ld	(hl+), a
	ld	(hl), b
	jr	00124$
00115$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1036: } else if (type == CT_BOMB) {
	ld	a, e
	sub	a, #0x0f
	jr	NZ, 00112$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1037: if (bomb_count < MAX_BOMB_LIST) bomb_list[bomb_count++] = idx;
	ld	hl, #_bomb_count
	ld	a, (hl)
	sub	a, #0xa0
	jr	NC, 00124$
	ld	e, (hl)
	inc	(hl)
	xor	a, a
	ld	l, e
	ld	h, a
	add	hl, hl
	ld	de, #_bomb_list
	add	hl, de
	ld	a, c
	ld	(hl+), a
	ld	(hl), b
	jr	00124$
00112$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1038: } else if (type == CT_EXPLOSION) {
	ld	a, e
	sub	a, #0x1c
	jr	NZ, 00124$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1039: if (explosion_count < MAX_EXPLOSION_LIST) explosion_list[explosion_count++] = idx;
	ld	a, (_explosion_count)
	ld	e, a
	ld	hl, #_explosion_count + 1
	ld	d, (hl)
	ld	a, e
	sub	a, #0xf0
	ld	a, d
	sbc	a, #0x01
	jr	NC, 00124$
	dec	hl
	ld	a, (hl+)
	ld	e, a
	ld	a, (hl-)
	ld	d, a
	inc	(hl)
	jr	NZ, 00208$
	inc	hl
	inc	(hl)
00208$:
	ld	l, e
	ld	h, d
	add	hl, hl
	ld	de, #_explosion_list
	add	hl, de
	ld	a, c
	ld	(hl+), a
	ld	(hl), b
00124$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1029: for (idx = 0; idx < MAP_CELLS; idx++) {
	inc	bc
	ld	e, c
	ld	d, b
	ld	a, e
	sub	a, #0xf0
	ld	a, d
	sbc	a, #0x01
	jp	C, 00123$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1042: }
	ret
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1044: static void enemy_tick(void)
;	---------------------------------
; Function enemy_tick
; ---------------------------------
_enemy_tick:
	add	sp, #-3
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1049: if (robbo_dead) return;
	ld	a, (#_robbo_dead)
	or	a, a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1051: for (i = 0; i < enemy_count; i++) {
	jp	NZ, 00119$
	ldhl	sp,	#2
	ld	(hl), #0x00
00118$:
	ldhl	sp,	#2
	ld	a, (hl)
	ld	hl, #_enemy_count
	sub	a, (hl)
	jp	NC, 00119$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1056: idx = enemy_list[i];
	ldhl	sp,	#2
	ld	c, (hl)
	xor	a, a
	ld	l, c
	ld	h, a
	add	hl, hl
	ld	de, #_enemy_list
	add	hl, de
	ld	a, (hl+)
	ld	c, a
	ld	b, (hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1057: type = map_type[idx];
	ld	hl, #_map_type
	add	hl, bc
	ld	e, (hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1058: if (type != CT_BEAR && type != CT_BUTTERFLY && type != CT_MUSTACHE) continue;
	ld	a, e
	sub	a, #0x17
	ld	a, #0x01
	jr	Z, 00179$
	xor	a, a
00179$:
	ld	d, a
	bit	0, d
	jr	NZ, 00104$
	ld	a,e
	cp	a,#0x16
	jr	Z, 00104$
	sub	a, #0x15
	jr	NZ, 00115$
00104$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1060: state = map_obj[idx];
	ld	hl, #_map_obj
	add	hl, bc
	ld	l, (hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1061: if (type == CT_BEAR) {
	ld	a, d
	or	a, a
	jr	Z, 00111$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1062: cur = bear_step(idx, state);
	ld	a, l
	ld	e, c
	ld	d, b
	call	_bear_step
	jr	00112$
00111$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1063: } else if (type == CT_BUTTERFLY) {
	ld	a, e
	sub	a, #0x16
	jr	NZ, 00108$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1064: cur = butterfly_step(idx, state);
	ld	a, l
	ld	e, c
	ld	d, b
	call	_butterfly_step
	jr	00112$
00108$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1066: cur = mustache_step(idx, state);
	ld	a, l
	ld	e, c
	ld	d, b
	call	_mustache_step
00112$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1069: if (cur < MAP_CELLS) {
	ld	a, c
	sub	a, #0xf0
	ld	a, b
	sbc	a, #0x01
	jr	NC, 00115$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1070: render_cell(cur % MAP_W, cur / MAP_W);
	ld	l, c
	ld	e, b
	srl	e
	rr	l
	srl	e
	rr	l
	srl	e
	rr	l
	srl	e
	rr	l
	ld	a, l
	ldhl	sp,	#0
	ld	(hl+), a
	ld	a, c
	and	a, #0x0f
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	a, (hl)
	call	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1071: enemy_try_kill_at(cur % MAP_W, cur / MAP_W);
	ldhl	sp,	#0
	ld	a, (hl+)
	ld	e, a
	ld	a, (hl)
	call	_enemy_try_kill_at
00115$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1051: for (i = 0; i < enemy_count; i++) {
	ldhl	sp,	#2
	inc	(hl)
	jp	00118$
00119$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1074: }
	add	sp, #3
	ret
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1076: void game_check_enemies(void)
;	---------------------------------
; Function game_check_enemies
; ---------------------------------
_game_check_enemies::
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1078: enemy_check_kills();
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1079: }
	jp	_enemy_check_kills
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1081: void game_face(uint8_t dir)
;	---------------------------------
; Function game_face
; ---------------------------------
_game_face::
	ld	c, a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1083: if (dir > 3 || robbo_busy) return;
	ld	a, #0x03
	sub	a, c
	ret	C
	ld	a, (#_robbo_busy)
	or	a, a
	ret	NZ
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1084: robbo_dir = dir;
	ld	hl, #_robbo_dir
	ld	(hl), c
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1085: map_extra[(uint16_t)robbo_y * MAP_W + robbo_x] = dir;
	ld	a, (_robbo_y)
	ld	h, #0x00
	ld	l, a
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	a, (_robbo_x)
	ld	d, #0x00
	ld	e, a
	add	hl, de
	ld	de, #_map_extra
	add	hl, de
	ld	(hl), c
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1086: render_cell(robbo_x, robbo_y);
	ld	a, (_robbo_y)
	ld	e, a
	ld	a, (_robbo_x)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1087: }
	jp	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1090: uint8_t game_fire(void)
;	---------------------------------
; Function game_fire
; ---------------------------------
_game_fire::
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1092: uint8_t nx = robbo_x;
	ld	a, (_robbo_x)
	ld	c, a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1093: uint8_t ny = robbo_y;
	ld	a, (_robbo_y)
	ld	b, a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1097: if (player_bullet_active()) return 0;
	push	bc
	call	_player_bullet_active
	pop	bc
	or	a, a
	jr	Z, 00102$
	xor	a, a
	ret
00102$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1098: if (ammo == 0) return 0;
	ld	a, (#_ammo)
	or	a,a
	ret	Z
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1099: if (fire_delay != 0) return 0;
	ld	a, (#_fire_delay)
	or	a, a
	jr	Z, 00106$
	xor	a, a
	ret
00106$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1100: if (robbo_busy) return 0;
	ld	a, (#_robbo_busy)
	or	a, a
	jr	Z, 00108$
	xor	a, a
	ret
00108$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1102: if (robbo_dir == 0) nx++;
	ld	a, (#_robbo_dir)
	or	a, a
	jr	NZ, 00120$
	inc	c
	jr	00121$
00120$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1103: else if (robbo_dir == 1) ny++;
	ld	a, (#_robbo_dir)
	dec	a
	jr	NZ, 00117$
	inc	b
	jr	00121$
00117$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1104: else if (robbo_dir == 2) { if (nx > 0) nx--; }
	ld	a, (#_robbo_dir)
	sub	a, #0x02
	jr	NZ, 00114$
	or	a, c
	jr	Z, 00121$
	dec	c
	jr	00121$
00114$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1105: else { if (ny > 0) ny--; }
	ld	a, b
	or	a, a
	jr	Z, 00121$
	dec	b
00121$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1107: if (nx >= MAP_W || ny >= level_height) return 0;
	ld	a, c
	sub	a, #0x10
	jr	NC, 00122$
	ld	a, b
	ld	hl, #_level_height
	sub	a, (hl)
	jr	C, 00123$
00122$:
	xor	a, a
	ret
00123$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1109: idx = (uint16_t)ny * MAP_W + nx;
	ld	l, b
	ld	h, #0x00
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	b, #0x00
	add	hl, bc
	ld	e, l
	ld	d, h
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1110: target = map_type[idx];
	ld	hl, #_map_type
	add	hl, de
	ld	c, (hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1112: if (target == CT_EMPTY) {
	ld	a, c
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1113: if (!add_bullet(idx, robbo_dir, 0, 0)) return 0;
	or	a,a
	jr	NZ, 00128$
	rrca
	push	af
	ld	a, (_robbo_dir)
	call	_add_bullet
	or	a,a
	ret	Z
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1114: ammo--;
	ld	hl, #_ammo
	dec	(hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1115: hud_dirty = 1;
	ld	hl, #_hud_dirty
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1116: fire_delay = 2;
	ld	hl, #_fire_delay
	ld	(hl), #0x02
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1117: return 1;
	ld	a, #0x01
	ret
00128$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1121: if (is_demolishable(target)) {
	push	bc
	push	de
	ld	a, c
	call	_is_demolishable
	pop	de
	pop	bc
	or	a, a
	jr	Z, 00133$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1122: if (target == CT_BOMB && map_extra[idx] != 0) return 0;
	ld	a, c
	sub	a, #0x0f
	jr	NZ, 00130$
	ld	hl, #_map_extra
	add	hl, de
	ld	a, (hl)
	or	a, a
	jr	Z, 00130$
	xor	a, a
	ret
00130$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1123: ammo--;
	ld	hl, #_ammo
	dec	(hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1124: hud_dirty = 1;
	ld	hl, #_hud_dirty
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1125: fire_delay = 2;
	ld	hl, #_fire_delay
	ld	(hl), #0x02
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1126: demolish_cell(idx);
	call	_demolish_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1127: return 1;
	ld	a, #0x01
	ret
00133$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1131: if (target == CT_STONE || target == CT_PUSHABLE) {
	ld	a,c
	cp	a,#0x0a
	jr	Z, 00134$
	sub	a, #0x0b
	jr	NZ, 00135$
00134$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1132: ammo--;
	ld	hl, #_ammo
	dec	(hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1133: hud_dirty = 1;
	ld	hl, #_hud_dirty
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1134: fire_delay = 2;
	ld	hl, #_fire_delay
	ld	(hl), #0x02
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1135: blast_cell(idx, 3);
	ld	a, #0x03
	call	_blast_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1136: return 1;
	ld	a, #0x01
	ret
00135$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1139: return 0;
	xor	a, a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1140: }
	ret
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1142: void game_tick(void)
;	---------------------------------
; Function game_tick
; ---------------------------------
_game_tick::
	add	sp, #-18
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1148: if (fire_delay != 0) fire_delay--;
	ld	hl, #_fire_delay
	ld	a, (hl)
	or	a, a
	jr	Z, 00102$
	dec	(hl)
00102$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1149: anim_frame = (anim_frame + 1) & 1;
	ld	a, (_anim_frame)
	inc	a
	and	a, #0x01
	ld	(#_anim_frame),a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1151: if (robbo_dead) {
	ld	a, (#_robbo_dead)
	or	a, a
	jr	Z, 00108$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1152: if (death_timer != 0) {
	ld	hl, #_death_timer
	ld	a, (hl)
	or	a, a
	jr	Z, 00108$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1153: death_timer--;
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1154: if (death_timer == 0) game_restart_requested = 1;
	dec	(hl)
	jr	NZ, 00108$
	ld	hl, #_game_restart_requested
	ld	(hl), #0x01
00108$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1158: if (screen_flash_ticks != 0) {
	ld	hl, #_screen_flash_ticks
	ld	a, (hl)
	or	a, a
	jr	Z, 00112$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1159: screen_flash_ticks--;
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1160: if (screen_flash_ticks == 0) render_flash_set(0);
	dec	(hl)
	jr	NZ, 00112$
	ld	a, (hl)
	call	_render_flash_set
00112$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1163: if (transition_active) {
	ld	a, (#_transition_active)
	or	a, a
	jr	Z, 00263$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1164: if (wipe_col >= 0) {
	ld	a, (#_wipe_col)
	bit	7, a
	jr	NZ, 00115$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1166: for (y = 0; y < level_height; y++) {
	ld	e, #0x00
00238$:
	ld	a, e
	ld	hl, #_level_height
	sub	a, (hl)
	jr	NC, 00113$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1167: uint16_t widx = (uint16_t)y * MAP_W + (uint8_t)wipe_col;
	ld	c, e
	ld	b, #0x00
	sla	c
	rl	b
	sla	c
	rl	b
	sla	c
	rl	b
	sla	c
	rl	b
	ldhl	sp,	#16
	ld	a, c
	ld	(hl+), a
	ld	(hl), b
	ld	a, (_wipe_col)
	ld	c, a
	ld	b, #0x00
	ld	a, (hl-)
	ld	l, (hl)
	ld	h, a
	add	hl, bc
	ld	c, l
	ld	b, h
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1168: map_type[widx] = CT_WALL_0;
	ld	hl, #_map_type
	add	hl, bc
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1169: map_extra[widx] = 0;
	ld	hl, #_map_extra
	add	hl, bc
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1170: render_cell((uint8_t)wipe_col, y);
	ld	a, (_wipe_col)
	push	de
	call	_render_cell
	pop	de
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1166: for (y = 0; y < level_height; y++) {
	inc	e
	jr	00238$
00113$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1172: wipe_col--;
	ld	hl, #_wipe_col
	dec	(hl)
	jp	00249$
00115$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1174: transition_active = 0;
	xor	a, a
	ld	(#_transition_active),a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1175: game_level_advance_requested = 1;
	ld	hl, #_game_level_advance_requested
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1177: return;
	jp	00249$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1181: for (i = 0; i < bullet_count; i++) {
00263$:
	ld	c, #0x00
00241$:
	ld	a, c
	ld	hl, #_bullet_count
	sub	a, (hl)
	jr	NC, 00121$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1182: uint16_t c = bullet_cells[i];
	ld	l, c
	xor	a, a
	ld	h, a
	add	hl, hl
	ld	de, #_bullet_cells
	add	hl, de
	ld	a,	(hl+)
	ld	h, (hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1183: if (map_type[c] == CT_BULLET) {
	ld	l, a
	add	a,#<(_map_type)
	ld	e, a
	ld	a, #>(_map_type)
	adc	a, h
	ld	d, a
	ld	a, (de)
	sub	a, #0x1b
	jr	NZ, 00242$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1184: map_extra[c] &= 0x7F;
	ld	de, #_map_extra
	add	hl, de
	res	7, (hl)
00242$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1181: for (i = 0; i < bullet_count; i++) {
	inc	c
	jr	00241$
00121$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1187: i = 0;
	ldhl	sp,	#17
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1190: while (i < bullet_count) {
00189$:
	ldhl	sp,	#17
	ld	a, (hl)
	ld	hl, #_bullet_count
	sub	a, (hl)
	jp	NC, 00191$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1191: uint16_t bidx = bullet_cells[i];
	ldhl	sp,	#17
	ld	c, (hl)
	xor	a, a
	sla	c
	adc	a, a
	ldhl	sp,	#1
	ld	(hl), c
	inc	hl
	ld	(hl), a
	ld	de, #_bullet_cells
	ld	a, (hl-)
	ld	l, (hl)
	ld	h, a
	add	hl, de
	ld	c, l
	ld	b, h
	ld	e, c
	ld	d, b
	ld	a, (de)
	ldhl	sp,	#3
	ld	(hl+), a
	inc	de
	ld	a, (de)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1197: if (map_type[bidx] != CT_BULLET) {
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #_map_type
	add	hl, de
	ld	c, l
	ld	b, h
	ld	a, (bc)
	sub	a, #0x1b
	jr	Z, 00123$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1198: remove_bullet_at(i);
	ldhl	sp,	#17
	ld	a, (hl)
	call	_remove_bullet_at
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1199: continue;
	jr	00189$
00123$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1202: if (map_extra[bidx] & 0x80) {
	ldhl	sp,#3
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #_map_extra
	add	hl, de
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
	bit	7, a
	jr	Z, 00125$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1203: i++;
	ldhl	sp,	#17
	inc	(hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1204: continue;
	jr	00189$
00125$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1206: map_extra[bidx] |= 0x80;
	set	7, a
	ldhl	sp,	#5
	ld	e, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, e
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1208: be = map_extra[bidx];
	ldhl	sp,	#7
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1209: bdir = be & 3;
	ld	(hl), a
	and	a, #0x03
	ldhl	sp,	#16
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1210: btype = (be >> 2) & 3;
	ldhl	sp,	#7
	ld	a, (hl+)
	rrca
	rrca
	and	a, #0x3
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1211: owner = (be >> 4) & 1;
	ld	(hl-), a
	ld	a, (hl+)
	inc	hl
	swap	a
	and	a, #0x01
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1212: bx = bidx % MAP_W;
	ldhl	sp,	#3
	ld	a, (hl)
	ldhl	sp,	#14
	ld	(hl), a
	ldhl	sp,	#4
	ld	a, (hl)
	ldhl	sp,	#15
	ld	(hl-), a
	ld	a, (hl-)
	dec	hl
	and	a, #0x0f
	ld	(hl+), a
	xor	a, a
	ld	(hl-), a
	ld	a, (hl-)
	dec	hl
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1213: by = bidx / MAP_W;
	ldhl	sp,	#15
	srl	(hl)
	dec	hl
	rr	(hl)
	inc	hl
	srl	(hl)
	dec	hl
	rr	(hl)
	inc	hl
	srl	(hl)
	dec	hl
	rr	(hl)
	inc	hl
	srl	(hl)
	dec	hl
	rr	(hl)
	ld	a, (hl)
	ldhl	sp,	#11
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1214: nbx = bx;
	ld	(hl-), a
	ld	a, (hl+)
	inc	hl
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1215: nby = by;
	ld	(hl-), a
	ld	a, (hl+)
	inc	hl
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1217: if (bdir == 0) nbx++;
	ldhl	sp,	#16
	ld	a, (hl)
	or	a, a
	jr	NZ, 00137$
	ldhl	sp,	#10
	ld	a, (hl+)
	inc	hl
	inc	a
	ld	(hl), a
	jr	00138$
00137$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1218: else if (bdir == 1) nby++;
	ldhl	sp,	#16
	ld	a, (hl)
	dec	a
	jr	NZ, 00134$
	ldhl	sp,	#11
	ld	a, (hl+)
	inc	hl
	inc	a
	ld	(hl), a
	jr	00138$
00134$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1219: else if (bdir == 2) { if (nbx > 0) nbx--; }
	ldhl	sp,	#16
	ld	a, (hl)
	sub	a, #0x02
	jr	NZ, 00131$
	ldhl	sp,	#10
	ld	a, (hl)
	or	a, a
	jr	Z, 00138$
	ld	a, (hl+)
	inc	hl
	dec	a
	ld	(hl), a
	jr	00138$
00131$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1220: else { if (nby > 0) nby--; }
	ldhl	sp,	#11
	ld	a, (hl)
	or	a, a
	jr	Z, 00138$
	ld	a, (hl+)
	inc	hl
	dec	a
	ld	(hl), a
00138$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1222: if (btype == 1) {
	ldhl	sp,	#8
	ld	a, (hl)
	dec	a
	jp	NZ, 00169$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1223: uint8_t lstate = (be >> 5) & 3;
	ldhl	sp,	#7
	ld	a, (hl)
	swap	a
	rrca
	and	a, #0x3
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1225: if (lstate == BULLET_LASER_WAIT) {
	cp	a, #0x01
	jr	NZ, 00140$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1226: i++;
	ldhl	sp,	#17
	inc	(hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1227: continue;
	jp	00189$
00140$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1230: if (lstate == BULLET_LASER_RETURN) {
	sub	a, #0x02
	jp	NZ, 00153$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1231: int16_t px = (int16_t)bx - tp_dx[bdir];
	ldhl	sp,	#10
	ld	c, (hl)
	ld	de, #_tp_dx
	ldhl	sp,	#16
	ld	l, (hl)
	ld	h, #0x00
	add	hl, de
	ld	e, l
	ld	d, h
	ld	a, (de)
	ld	e, a
	rlca
	sbc	a, a
	ld	d, a
	ld	a, c
	sub	a, e
	ld	c, a
	sbc	a, a
	sub	a, d
	ldhl	sp,	#14
	ld	(hl), c
	inc	hl
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1232: int16_t py = (int16_t)by - tp_dy[bdir];
	ldhl	sp,	#11
	ld	c, (hl)
	ld	de, #_tp_dy
	ldhl	sp,	#16
	ld	l, (hl)
	ld	h, #0x00
	add	hl, de
	ld	e, l
	ld	d, h
	ld	a, (de)
	ld	e, a
	rlca
	sbc	a, a
	ld	d, a
	ld	a, c
	sub	a, e
	ld	c, a
	sbc	a, a
	sub	a, d
	ldhl	sp,	#12
	ld	(hl), c
	inc	hl
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1235: map_type[bidx] = CT_EMPTY;
	ld	de, #_map_type
	ldhl	sp,	#3
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	c, l
	ld	b, h
	xor	a, a
	ld	(bc), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1236: map_extra[bidx] = 0;
	ldhl	sp,	#5
	ld	a, (hl+)
	ld	h, (hl)
	ld	l, a
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1237: render_cell(bx, by);
	ldhl	sp,	#11
	ld	a, (hl-)
	ld	e, a
	ld	a, (hl)
	call	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1239: if (px >= 0 && py >= 0 && px < MAP_W && py < level_height) {
	ldhl	sp,	#14
	ld	a, (hl)
	ldhl	sp,	#7
	ld	(hl), a
	ldhl	sp,	#15
	ld	a, (hl)
	ldhl	sp,	#8
	ld	(hl), a
	bit	7, (hl)
	jp	NZ, 00148$
	ldhl	sp,	#12
	ld	a, (hl-)
	dec	hl
	ld	(hl), a
	ldhl	sp,	#13
	ld	a, (hl-)
	dec	hl
	ld	(hl), a
	bit	7, (hl)
	jr	NZ, 00148$
	ldhl	sp,	#7
	ld	a, (hl+)
	sub	a, #0x10
	ld	a, (hl)
	sbc	a, #0x00
	jr	NC, 00148$
	ld	a, (_level_height)
	ld	c, a
	ld	b, #0x00
	ldhl	sp,	#12
	ld	a, (hl+)
	sub	a, c
	ld	a, (hl)
	sbc	a, b
	ld	d, (hl)
	ld	a, b
	bit	7,a
	jr	Z, 00755$
	bit	7, d
	jr	NZ, 00756$
	cp	a, a
	jr	00756$
00755$:
	bit	7, d
	jr	Z, 00756$
	scf
00756$:
	jr	NC, 00148$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1240: pidx = (uint16_t)py * MAP_W + (uint8_t)px;
	ldhl	sp,	#12
	ld	a, (hl+)
	ld	c, (hl)
	ld	l, a
	ld	h, c
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	c, l
	ld	b, h
	ldhl	sp,	#14
	ld	l, (hl)
	ld	h, #0x00
	add	hl, bc
	ld	c, l
	ld	b, h
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1241: if (map_type[pidx] == CT_BULLET) {
	ld	hl, #_map_type
	add	hl, bc
	ld	a, (hl)
	sub	a, #0x1b
	jr	NZ, 00148$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1242: uint8_t pe = map_extra[pidx];
	ld	hl, #_map_extra
	add	hl, bc
	ld	c, l
	ld	b, h
	ld	a, (bc)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1243: if (((pe >> 5) & 3) == BULLET_LASER_WAIT &&
	ld	d, a
	swap	a
	rrca
	and	a, #0x3
	dec	a
	jr	NZ, 00148$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1244: ((pe >> 4) & 1) == owner &&
	ld	a, d
	swap	a
	and	a, #0x01
	ld	e, a
	ldhl	sp,	#9
	ld	a, (hl)
	sub	a, e
	jr	NZ, 00148$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1245: ((pe >> 2) & 3) == 1) {
	ld	a, d
	rrca
	rrca
	and	a, #0x3
	dec	a
	jr	NZ, 00148$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1246: map_extra[pidx] = (uint8_t)((pe & 0x1F) | (BULLET_LASER_RETURN << 5) | 0x80);
	ld	a, d
	and	a, #0x1f
	or	a, #0xc0
	ld	(bc), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1247: remove_bullet_at(i);
	ldhl	sp,	#17
	ld	a, (hl)
	call	_remove_bullet_at
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1248: continue;
	jp	00189$
00148$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1253: spawn_explosion_timer(bidx, 3);
	ld	a, #0x03
	ldhl	sp,	#3
	ld	e, (hl)
	inc	hl
	ld	d, (hl)
	call	_spawn_explosion_timer
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1254: remove_bullet_at(i);
	ldhl	sp,	#17
	ld	a, (hl)
	call	_remove_bullet_at
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1255: continue;
	jp	00189$
00153$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1203: i++;
	ldhl	sp,	#17
	inc	(hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1260: map_extra[bidx] = (uint8_t)((be & 0x1F) | (BULLET_LASER_RETURN << 5) | 0x80);
	ldhl	sp,	#7
	ld	a, (hl)
	and	a, #0x1f
	ldhl	sp,	#15
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1259: if (nbx >= MAP_W || nby >= level_height) {
	ldhl	sp,	#12
	ld	a, (hl)
	sub	a, #0x10
	jr	NC, 00154$
	inc	hl
	ld	a, (hl)
	ld	hl, #_level_height
	sub	a, (hl)
	jr	C, 00155$
00154$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1260: map_extra[bidx] = (uint8_t)((be & 0x1F) | (BULLET_LASER_RETURN << 5) | 0x80);
	ldhl	sp,	#15
	ld	a, (hl)
	or	a, #0xc0
	ldhl	sp,	#5
	ld	e, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, e
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1261: i++;
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1262: continue;
	jp	00189$
00155$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1265: nidx = (uint16_t)nby * MAP_W + nbx;
	ldhl	sp,	#13
	ld	a, (hl-)
	ld	c, a
	ld	b, #0x00
	sla	c
	rl	b
	sla	c
	rl	b
	sla	c
	rl	b
	sla	c
	rl	b
	ld	a, (hl+)
	ld	e, a
	ld	d, #0x00
	ld	a, e
	add	a, c
	ld	c, a
	ld	a, d
	adc	a, b
	ld	b, a
	ld	a, c
	ld	(hl+), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1266: target = map_type[nidx];
	ld	a, b
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #_map_type
	add	hl, de
	ld	c, l
	ld	b, h
	ld	a, (bc)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1268: if (target == CT_EMPTY) {
	ld	c, a
	or	a, a
	jr	NZ, 00161$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1269: map_extra[bidx] = (uint8_t)((be & 0x1F) | (BULLET_LASER_WAIT << 5) | 0x80);
	ldhl	sp,	#15
	ld	a, (hl)
	or	a, #0xa0
	ldhl	sp,	#5
	ld	e, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, e
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1270: if (add_bullet(nidx, bdir, 1, owner)) {
	ldhl	sp,	#9
	ld	h, (hl)
	ld	l, #0x01
	push	hl
	ldhl	sp,	#18
	ld	a, (hl)
	ldhl	sp,	#15
	ld	e, (hl)
	inc	hl
	ld	d, (hl)
	call	_add_bullet
	ldhl	sp,#16
	ld	(hl), a
	or	a, a
	jr	Z, 00158$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1271: map_extra[nidx] |= 0x80;
	dec	hl
	dec	hl
	dec	hl
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #_map_extra
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#17
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#16
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	a, (hl-)
	dec	hl
	ld	d, a
	ld	a, (de)
	ld	(hl+), a
	set	7, a
	ld	e, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, e
	ld	(hl), a
	jp	00189$
00158$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1273: map_extra[bidx] = (uint8_t)((be & 0x1F) | (BULLET_LASER_RETURN << 5) | 0x80);
	ldhl	sp,	#15
	ld	a, (hl+)
	or	a, #0xc0
	ld	(hl), a
	ldhl	sp,	#5
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ldhl	sp,	#16
	ld	a, (hl)
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1275: i++;
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1276: continue;
	jp	00189$
00161$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1279: if (target == CT_ROBBO && owner) {
	ld	a, c
	sub	a, #0x1a
	jr	NZ, 00165$
	ldhl	sp,	#9
	ld	a, (hl)
	or	a, a
	jr	Z, 00165$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1280: kill_robbo();
	call	_kill_robbo
	jr	00166$
00165$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1281: } else if (is_demolishable(target)) {
	ld	a, c
	call	_is_demolishable
	or	a, a
	jr	Z, 00166$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1282: demolish_cell(nidx);
	ldhl	sp,	#13
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	call	_demolish_cell
00166$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1284: map_extra[bidx] = (uint8_t)((be & 0x1F) | (BULLET_LASER_RETURN << 5) | 0x80);
	ldhl	sp,	#15
	ld	a, (hl)
	or	a, #0xc0
	ldhl	sp,	#5
	ld	e, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, e
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1285: i++;
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1286: continue;
	jp	00189$
00169$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1289: if (nbx >= MAP_W || nby >= level_height) {
	ldhl	sp,	#12
	ld	a, (hl)
	sub	a, #0x10
	jr	NC, 00170$
	inc	hl
	ld	a, (hl)
	ld	hl, #_level_height
	sub	a, (hl)
	jr	C, 00171$
00170$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1290: spawn_explosion_timer(bidx, 3);
	ld	a, #0x03
	ldhl	sp,	#3
	ld	e, (hl)
	inc	hl
	ld	d, (hl)
	call	_spawn_explosion_timer
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1291: remove_bullet_at(i);
	ldhl	sp,	#17
	ld	a, (hl)
	call	_remove_bullet_at
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1292: continue;
	jp	00189$
00171$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1295: nidx = (uint16_t)nby * MAP_W + nbx;
	ldhl	sp,	#13
	ld	a, (hl-)
	ld	e, #0x00
	add	a, a
	rl	e
	add	a, a
	rl	e
	add	a, a
	rl	e
	add	a, a
	rl	e
	ld	c, (hl)
	inc	hl
	inc	hl
	ld	b, #0x00
	add	a, c
	ld	c, a
	ld	a, e
	adc	a, b
	ld	b, a
	ld	a, c
	ld	(hl+), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1296: target = map_type[nidx];
	ld	a, b
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #_map_type
	add	hl, de
	ld	c, l
	ld	b, h
	ld	a, (bc)
	ldhl	sp,	#16
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1298: if (target == CT_EMPTY) {
	ld	(hl), a
	or	a, a
	jr	NZ, 00187$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1299: map_type[nidx] = CT_BULLET;
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1300: map_extra[nidx] = be;
	dec	hl
	ld	a, #0x1b
	ld	(bc), a
	ld	de, #_map_extra
	ld	a, (hl-)
	ld	l, (hl)
	ld	h, a
	add	hl, de
	ld	c, l
	ld	b, h
	ldhl	sp,	#7
	ld	a, (hl)
	ld	(bc), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1301: map_type[bidx] = CT_EMPTY;
	ld	de, #_map_type
	ldhl	sp,	#3
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	c, l
	ld	b, h
	xor	a, a
	ld	(bc), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1302: map_extra[bidx] = 0;
	ldhl	sp,	#5
	ld	a, (hl+)
	ld	h, (hl)
	ld	l, a
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1303: render_cell(bx, by);
	ldhl	sp,	#11
	ld	a, (hl-)
	ld	e, a
	ld	a, (hl)
	call	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1304: render_cell(nbx, nby);
	ldhl	sp,	#13
	ld	a, (hl-)
	ld	e, a
	ld	a, (hl)
	call	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1305: bullet_cells[i] = nidx;
	ld	de, #_bullet_cells
	ldhl	sp,	#1
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	c, l
	ld	b, h
	ldhl	sp,	#14
	ld	a, (hl+)
	ld	(bc), a
	inc	bc
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1306: i++;
	ld	a, (hl+)
	inc	hl
	ld	(bc), a
	inc	(hl)
	jp	00189$
00187$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1307: } else if (target == CT_BULLET) {
	ldhl	sp,	#16
	ld	a, (hl)
	sub	a, #0x1b
	jr	NZ, 00184$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1310: spawn_explosion_timer(bidx, 3);
	ld	a, #0x03
	ldhl	sp,	#3
	ld	e, (hl)
	inc	hl
	ld	d, (hl)
	call	_spawn_explosion_timer
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1311: remove_bullet_at(i);
	ldhl	sp,	#17
	ld	a, (hl)
	call	_remove_bullet_at
	jp	00189$
00184$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1312: } else if (target == CT_ROBBO && owner) {
	ldhl	sp,	#16
	ld	a, (hl)
	sub	a, #0x1a
	jr	NZ, 00180$
	ldhl	sp,	#9
	ld	a, (hl)
	or	a, a
	jr	Z, 00180$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1313: kill_robbo();
	call	_kill_robbo
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1314: spawn_explosion_timer(bidx, 3);
	ld	a, #0x03
	ldhl	sp,	#3
	ld	e, (hl)
	inc	hl
	ld	d, (hl)
	call	_spawn_explosion_timer
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1315: remove_bullet_at(i);
	ldhl	sp,	#17
	ld	a, (hl)
	call	_remove_bullet_at
	jp	00189$
00180$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1317: if (btype == 2 && is_explodable(target)) {
	ldhl	sp,	#8
	ld	a, (hl)
	sub	a, #0x02
	jr	NZ, 00176$
	ldhl	sp,	#16
	ld	a, (hl)
	call	_is_explodable
	or	a, a
	jr	Z, 00176$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1318: blast_cell(nidx, 3);
	ld	a, #0x03
	ldhl	sp,	#14
	ld	e, (hl)
	inc	hl
	ld	d, (hl)
	call	_blast_cell
	jr	00177$
00176$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1319: } else if (is_demolishable(target)) {
	ldhl	sp,	#16
	ld	a, (hl)
	call	_is_demolishable
	or	a, a
	jr	Z, 00177$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1320: demolish_cell(nidx);
	ldhl	sp,	#14
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	call	_demolish_cell
00177$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1322: spawn_explosion_timer(bidx, 3);
	ld	a, #0x03
	ldhl	sp,	#3
	ld	e, (hl)
	inc	hl
	ld	d, (hl)
	call	_spawn_explosion_timer
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1323: remove_bullet_at(i);
	ldhl	sp,	#17
	ld	a, (hl)
	call	_remove_bullet_at
	jp	00189$
00191$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1327: collect_actors();
	call	_collect_actors
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1328: turret_tick();
	call	_turret_tick
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1329: enemy_tick();
	call	_enemy_tick
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1332: for (i = 0; i < bomb_count; i++) {
	ld	c, #0x00
00244$:
	ld	a, c
	ld	hl, #_bomb_count
	sub	a, (hl)
	jr	NC, 00322$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1333: eidx = bomb_list[i];
	ld	l, c
	xor	a, a
	ld	h, a
	add	hl, hl
	ld	de, #_bomb_list
	add	hl, de
	ld	a,	(hl+)
	ld	h, (hl)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1334: if (map_type[eidx] == CT_BOMB && map_extra[eidx] != 0) {
	ld	l, a
	add	a,#<(_map_type)
	ld	e, a
	ld	a, #>(_map_type)
	adc	a, h
	ld	d, a
	ld	a, (de)
	sub	a, #0x0f
	jr	NZ, 00245$
	ld	a, #<(_map_extra)
	add	a, l
	ld	e, a
	ld	a, #>(_map_extra)
	adc	a, h
	ld	d, a
	ld	a, (de)
	or	a, a
	jr	Z, 00245$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1335: map_extra[eidx]--;
	dec	a
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1336: if (map_extra[eidx] == 0) {
	or	a, a
	jr	NZ, 00193$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1337: bomb_explode(eidx);
	push	bc
	ld	e, l
	ld	d, h
	call	_bomb_explode
	pop	bc
	jr	00245$
00193$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1339: render_cell(eidx % MAP_W, eidx / MAP_W);
	ld	e, l
	ld	d, h
	srl	d
	rr	e
	srl	d
	rr	e
	srl	d
	rr	e
	srl	d
	rr	e
	ld	a, l
	and	a, #0x0f
	ld	b, #0x00
	push	bc
	call	_render_cell
	pop	bc
00245$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1332: for (i = 0; i < bomb_count; i++) {
	inc	c
	jr	00244$
00322$:
	ldhl	sp,	#15
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1346: for (ei = 0; ei < explosion_count; ei++) {
	ld	a, c
	ld	(hl+), a
	xor	a, a
	ld	(hl+), a
	ld	(hl), a
00247$:
	ldhl	sp,	#16
	ld	e, l
	ld	d, h
	ld	hl, #_explosion_count
	ld	a, (de)
	inc	de
	sub	a, (hl)
	inc	hl
	ld	a, (de)
	sbc	a, (hl)
	jp	NC, 00311$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1347: eidx = explosion_list[ei];
	ldhl	sp,	#16
	ld	a, (hl+)
	ld	c, a
	ld	b, (hl)
	sla	c
	rl	b
	ld	hl, #_explosion_list
	add	hl, bc
	ld	e, l
	ld	d, h
	ld	a, (de)
	ldhl	sp,	#8
	ld	(hl+), a
	inc	de
	ld	a, (de)
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1348: if (map_type[eidx] == CT_EXPLOSION) {
	ld	de, #_map_type
	ldhl	sp,	#8
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#12
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#11
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, (de)
	sub	a, #0x1c
	jp	NZ, 00248$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1349: uint8_t timer = map_extra[eidx] & 7;
	ld	de, #_map_extra
	ldhl	sp,	#8
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
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1350: uint8_t payload = map_extra[eidx] >> 3;
	ld	a, (hl+)
	ld	d, a
	ld	a, (de)
	ld	b, a
	and	a, #0x07
	ld	c, a
	ld	a, b
	swap	a
	rlca
	and	a, #0x1f
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1351: if (timer > 0) {
	ld	a, c
	or	a, a
	jr	Z, 00206$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1352: timer--;
	dec	c
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1353: map_extra[eidx] = (uint8_t)((payload << 3) | timer);
	ld	a, (hl)
	add	a, a
	add	a, a
	add	a, a
	or	a, c
	ld	(hl-), a
	dec	hl
	ld	a, (hl+)
	ld	e, a
	ld	a, (hl+)
	ld	d, a
	ld	a, (hl)
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1354: render_cell(eidx % MAP_W, eidx / MAP_W);
	ldhl	sp,	#8
	ld	a, (hl)
	ldhl	sp,	#13
	ld	(hl), a
	ldhl	sp,	#9
	ld	a, (hl)
	ldhl	sp,	#14
	ld	(hl-), a
	ld	a, (hl-)
	dec	hl
	ld	(hl), a
	ldhl	sp,	#14
	ld	a, (hl-)
	dec	hl
	ld	(hl), a
	srl	(hl)
	dec	hl
	rr	(hl)
	inc	hl
	srl	(hl)
	dec	hl
	rr	(hl)
	inc	hl
	srl	(hl)
	dec	hl
	rr	(hl)
	inc	hl
	srl	(hl)
	dec	hl
	rr	(hl)
	ld	a, (hl-)
	ld	(hl), a
	ldhl	sp,	#13
	ld	a, (hl-)
	dec	hl
	and	a, #0x0f
	ld	(hl+), a
	xor	a, a
	ld	(hl-), a
	ld	a, (hl-)
	ld	e, (hl)
	call	_render_cell
	jr	00248$
00206$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1355: } else if (payload == 12) {
	ldhl	sp,	#14
	ld	a, (hl)
	sub	a, #0x0c
	jr	NZ, 00203$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1356: teleport_arrive(eidx);
	ldhl	sp,	#8
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	call	_teleport_arrive
	jr	00248$
00203$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1357: } else if (payload != 0) {
	ldhl	sp,	#14
	ld	a, (hl)
	or	a, a
	jr	Z, 00200$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1358: spawn_question_payload(eidx, payload - 1);
	ld	a, (hl)
	dec	a
	ldhl	sp,	#8
	ld	e, (hl)
	inc	hl
	ld	d, (hl)
	call	_spawn_question_payload
	jr	00248$
00200$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1360: map_type[eidx] = CT_EMPTY;
	ldhl	sp,	#10
	ld	a, (hl+)
	ld	h, (hl)
	ld	l, a
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1361: map_extra[eidx] = 0;
	ldhl	sp,	#12
	ld	a, (hl+)
	ld	h, (hl)
	ld	l, a
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1362: render_cell(eidx % MAP_W, eidx / MAP_W);
	ldhl	sp,	#8
	ld	a, (hl+)
	ld	c, a
	ld	b, (hl)
	ld	e, c
	ld	d, b
	srl	d
	rr	e
	srl	d
	rr	e
	srl	d
	rr	e
	srl	d
	rr	e
	ld	a, c
	and	a, #0x0f
	call	_render_cell
00248$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1346: for (ei = 0; ei < explosion_count; ei++) {
	ldhl	sp,	#16
	inc	(hl)
	jp	NZ, 00247$
	inc	hl
	inc	(hl)
	jp	00247$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1367: while (i < sliding_count) {
00311$:
	ldhl	sp,	#15
	ld	a, (hl+)
	inc	hl
	ld	(hl), a
00234$:
	ldhl	sp,	#17
	ld	a, (hl)
	ld	hl, #_sliding_count
	sub	a, (hl)
	jp	NC, 00249$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1368: uint16_t idx = sliding_boxes[i];
	ldhl	sp,	#17
	ld	a, (hl)
	ld	d, #0x00
	add	a, a
	rl	d
	ld	e, a
	ld	hl, #_sliding_boxes
	add	hl, de
	inc	sp
	inc	sp
	ld	e, l
	ld	d, h
	push	de
	ld	a, (de)
	ldhl	sp,	#2
	ld	(hl+), a
	inc	de
	ld	a, (de)
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1372: if (map_type[idx] != CT_PUSHABLE) {
	ld	de, #_map_type
	ld	a, (hl-)
	ld	l, (hl)
	ld	h, a
	add	hl, de
	ld	c, l
	ld	b, h
	ld	a, (bc)
	sub	a, #0x0b
	jr	Z, 00212$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1373: remove_sliding(i);
	ldhl	sp,	#17
	ld	a, (hl)
	call	_remove_sliding
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1374: continue;
	jr	00234$
00212$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1377: x = idx % MAP_W;
	ldhl	sp,	#2
	ld	a, (hl+)
	ld	c, a
	ld	a, (hl+)
	ld	b, a
	ld	a, c
	and	a, #0x0f
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1378: y = idx / MAP_W;
	ld	(hl+), a
	srl	b
	rr	c
	srl	b
	rr	c
	srl	b
	rr	c
	srl	b
	rr	c
	ld	(hl), c
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1379: dir = map_extra[idx] & 3;
	ld	de, #_map_extra
	ldhl	sp,	#2
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
	ldhl	sp,	#16
	ld	(hl), a
	and	a, #0x03
	ldhl	sp,	#8
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1380: nx = x;
	ldhl	sp,	#4
	ld	a, (hl)
	ldhl	sp,	#9
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1381: ny = y;
	ldhl	sp,	#5
	ld	a, (hl)
	ldhl	sp,	#10
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1383: if (dir == 0) nx++;
	ld	(hl-), a
	dec	hl
	ld	a, (hl)
	or	a, a
	jr	NZ, 00224$
	ldhl	sp,	#4
	ld	a, (hl)
	inc	a
	ldhl	sp,	#9
	ld	(hl), a
	jr	00225$
00224$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1384: else if (dir == 1) ny++;
	ldhl	sp,	#8
	ld	a, (hl)
	dec	a
	jr	NZ, 00221$
	ldhl	sp,	#5
	ld	a, (hl)
	inc	a
	ldhl	sp,	#10
	ld	(hl), a
	jr	00225$
00221$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1385: else if (dir == 2) { if (nx > 0) nx--; }
	ldhl	sp,	#8
	ld	a, (hl)
	sub	a, #0x02
	jr	NZ, 00218$
	ldhl	sp,	#4
	ld	a, (hl)
	or	a, a
	jr	Z, 00225$
	ld	a, (hl)
	dec	a
	ldhl	sp,	#9
	ld	(hl), a
	jr	00225$
00218$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1386: else { if (ny > 0) ny--; }
	ldhl	sp,	#5
	ld	a, (hl)
	or	a, a
	jr	Z, 00225$
	ld	a, (hl)
	dec	a
	ldhl	sp,	#10
	ld	(hl), a
00225$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1388: if (nx >= MAP_W || ny >= level_height) {
	ldhl	sp,	#9
	ld	a, (hl)
	sub	a, #0x10
	jr	NC, 00226$
	inc	hl
	ld	a, (hl)
	ld	hl, #_level_height
	sub	a, (hl)
	jr	C, 00227$
00226$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1389: map_extra[idx] &= (uint8_t)~4;
	ldhl	sp,	#16
	ld	a, (hl)
	and	a, #0xfb
	ldhl	sp,	#6
	ld	e, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, e
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1390: render_cell(x, y);
	ldhl	sp,	#5
	ld	a, (hl-)
	ld	e, a
	ld	a, (hl)
	call	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1391: remove_sliding(i);
	ldhl	sp,	#17
	ld	a, (hl)
	call	_remove_sliding
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1392: continue;
	jp	00234$
00227$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1395: nidx = (uint16_t)ny * MAP_W + nx;
	ldhl	sp,	#10
	ld	a, (hl-)
	ld	c, #0x00
	add	a, a
	rl	c
	add	a, a
	rl	c
	add	a, a
	rl	c
	add	a, a
	rl	c
	ld	e, (hl)
	inc	hl
	inc	hl
	ld	b, #0x00
	add	a, e
	ld	e, a
	ld	a, c
	adc	a, b
	ld	d, a
	ld	a, e
	ld	(hl+), a
	ld	(hl), d
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1396: target = map_type[nidx];
	ld	de, #_map_type
	ld	a, (hl-)
	ld	l, (hl)
	ld	h, a
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#15
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#14
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	a, (hl+)
	ld	d, a
	ld	a, (de)
	ld	(hl), a
	ld	a, (hl+)
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1398: if (target == CT_EMPTY) {
	ld	(hl-), a
	ld	a, (hl)
	or	a, a
	jr	NZ, 00232$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1399: map_type[nidx] = CT_PUSHABLE;
	dec	hl
	ld	a, (hl-)
	ld	l, (hl)
	ld	h, a
	ld	(hl), #0x0b
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1400: map_extra[nidx] = dir | 4;
	ldhl	sp,#11
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #_map_extra
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#17
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#16
	ld	(hl), a
	ldhl	sp,	#8
	ld	a, (hl)
	set	2, a
	ldhl	sp,	#15
	ld	e, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, e
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1401: map_type[idx] = CT_EMPTY;
	ld	de, #_map_type
	ldhl	sp,	#2
	ld	a,	(hl+)
	ld	h, (hl)
	ld	l, a
	add	hl, de
	ld	c, l
	ld	b, h
	xor	a, a
	ld	(bc), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1402: map_extra[idx] = 0;
	ldhl	sp,	#6
	ld	a, (hl+)
	ld	h, (hl)
	ld	l, a
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1403: render_cell(x, y);
	ldhl	sp,	#5
	ld	a, (hl-)
	ld	e, a
	ld	a, (hl)
	call	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1404: render_cell(nx, ny);
	ldhl	sp,	#10
	ld	a, (hl-)
	ld	e, a
	ld	a, (hl)
	call	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1405: sliding_boxes[i] = nidx;
	pop	de
	push	de
	ldhl	sp,	#11
	ld	a, (hl+)
	ld	(de), a
	inc	de
	ld	a, (hl)
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1406: i++;
	ldhl	sp,	#17
	inc	(hl)
	jp	00234$
00232$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1410: if (is_demolishable(target)) {
	ldhl	sp,	#16
	ld	a, (hl)
	call	_is_demolishable
	or	a, a
	jr	Z, 00230$
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1411: demolish_cell(nidx);
	ldhl	sp,	#11
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	call	_demolish_cell
00230$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1413: map_extra[idx] &= (uint8_t)~4;
	ldhl	sp,#6
	ld	a, (hl+)
	ld	e, a
	ld	a, (hl-)
	ld	d, a
	ld	a, (de)
	res	2, a
	ld	e, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, e
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1414: render_cell(x, y);
	ldhl	sp,	#5
	ld	a, (hl-)
	ld	e, a
	ld	a, (hl)
	call	_render_cell
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1415: remove_sliding(i);
	ldhl	sp,	#17
	ld	a, (hl)
	call	_remove_sliding
	jp	00234$
00249$:
;C:\dev\AI\robbo-port2\gb\src\core\game.c:1418: }
	add	sp, #18
	ret
	.area _CODE
	.area _INITIALIZER
__xinit__fire_delay:
	.db #0x00	; 0
__xinit__teleport_phase:
	.db #0x00	; 0
__xinit__teleport_to:
	.dw #0x0000
__xinit__robbo_dead:
	.db #0x00	; 0
__xinit__death_timer:
	.db #0x00	; 0
__xinit__screen_flash_ticks:
	.db #0x00	; 0
__xinit__transition_active:
	.db #0x00	; 0
__xinit__wipe_col:
	.db #0x00	;  0
__xinit__game_restart_requested:
	.db #0x00	; 0
__xinit__game_level_advance_requested:
	.db #0x00	; 0
__xinit__rng_state:
	.dw #0xace1
	.area _CABS (ABS)
