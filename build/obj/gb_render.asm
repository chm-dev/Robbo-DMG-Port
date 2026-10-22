;--------------------------------------------------------
; File Created by SDCC : free open source ISO C Compiler
; Version 4.5.1 #15267 (MINGW64)
;--------------------------------------------------------
	.module render
	
;--------------------------------------------------------
; Public variables in this module
;--------------------------------------------------------
	.globl _set_win_tiles
	.globl _set_bkg_tiles
	.globl _set_bkg_data
	.globl _set_interrupts
	.globl _add_LCD
	.globl _add_VBL
	.globl _render_metatile_for_cell
	.globl _render_apply_camera
	.globl _render_init
	.globl _render_level
	.globl _render_hud
	.globl _render_flash_set
	.globl _render_sync_rows
	.globl _render_cell
	.globl _render_flush_cells
	.globl _render_camera
;--------------------------------------------------------
; special function registers
;--------------------------------------------------------
	.area _HRAM
;--------------------------------------------------------
; ram data
;--------------------------------------------------------
	.area _DATA
_map_row_level:
	.ds 16
_dirty_bits:
	.ds 62
_dirty_any:
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
	.area _CODE
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:25: uint8_t render_metatile_for_cell(uint8_t type, uint8_t extra)
;	---------------------------------
; Function render_metatile_for_cell
; ---------------------------------
_render_metatile_for_cell::
	dec	sp
	dec	sp
	ldhl	sp,	#1
	ld	(hl-), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:27: if (IS_WALL(type)) return MT_WALL;
	ld	a, e
	ld	(hl+), a
	ld	a, (hl)
	sub	a, #0x01
	jr	C, 00102$
	ld	a, #0x08
	sub	a, (hl)
	jr	C, 00102$
	ld	a, #0x01
	jp	00132$
00102$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:29: switch (type) {
	ld	a, #0x1c
	ldhl	sp,	#1
	sub	a, (hl)
	jp	C, 00130$
	ld	c, (hl)
	ld	b, #0x00
	ld	hl, #00205$
	add	hl, bc
	add	hl, bc
	ld	c, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, c
	jp	(hl)
00205$:
	.dw	00104$
	.dw	00130$
	.dw	00130$
	.dw	00130$
	.dw	00130$
	.dw	00130$
	.dw	00130$
	.dw	00130$
	.dw	00130$
	.dw	00105$
	.dw	00106$
	.dw	00107$
	.dw	00108$
	.dw	00109$
	.dw	00113$
	.dw	00114$
	.dw	00115$
	.dw	00116$
	.dw	00118$
	.dw	00117$
	.dw	00119$
	.dw	00120$
	.dw	00121$
	.dw	00122$
	.dw	00123$
	.dw	00124$
	.dw	00125$
	.dw	00126$
	.dw	00127$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:30: case CT_EMPTY:      return MT_EMPTY;
00104$:
	xor	a, a
	jp	00132$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:31: case CT_GROUND:     return MT_GROUND;
00105$:
	ld	a, #0x02
	jp	00132$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:32: case CT_STONE:      return MT_STONE;
00106$:
	ld	a, #0x03
	jp	00132$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:33: case CT_PUSHABLE:   return MT_PUSHABLE;
00107$:
	ld	a, #0x04
	jp	00132$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:34: case CT_DOOR:       return MT_DOOR;
00108$:
	ld	a, #0x05
	jp	00132$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:35: case CT_SPACESHIP:
00109$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:36: if (screws_left == 0 || (extra & 1)) {
	ld	hl, #_screws_left
	ld	a, (hl)
	or	a, a
	jr	Z, 00110$
	push	hl
	ldhl	sp,	#2
	bit	0, (hl)
	pop	hl
	jr	Z, 00111$
00110$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:37: return (anim_slow & 1) ? MT_SPACESHIP_1 : MT_SPACESHIP_0;
	ld	a, (_anim_slow)
	rrca
	jr	NC, 00134$
	ld	a, #0x07
	jp	00132$
00134$:
	ld	a, #0x06
	jp	00132$
00111$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:39: return MT_SPACESHIP_0;
	ld	a, #0x06
	jp	00132$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:40: case CT_QUESTION:   return MT_QUESTION;
00113$:
	ld	a, #0x08
	jp	00132$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:41: case CT_BOMB:       return MT_BOMB;
00114$:
	ld	a, #0x09
	jp	00132$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:42: case CT_KEY:        return MT_KEY;
00115$:
	ld	a, #0x0a
	jp	00132$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:43: case CT_SCREW:      return MT_SCREW;
00116$:
	ld	a, #0x0b
	jp	00132$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:44: case CT_AMMO:       return MT_AMMO;
00117$:
	ld	a, #0x0c
	jp	00132$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:45: case CT_TURRET:     return turret_mt[extra & 3];
00118$:
	ld	bc, #_turret_mt+0
	ldhl	sp,	#0
	ld	a, (hl)
	and	a, #0x03
	ld	l, a
	ld	h, #0x00
	add	hl, bc
	ld	a, (hl)
	jp	00132$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:46: case CT_TELEPORT:   return MT_TELEPORT_0 + (anim_slow & 1);
00119$:
	ld	a, (_anim_slow)
	and	a, #0x01
	add	a, #0x11
	jr	00132$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:47: case CT_MUSTACHE:   return MT_MUSTACHE_0 + (anim_frame & 1);
00120$:
	ld	a, (_anim_frame)
	and	a, #0x01
	add	a, #0x1b
	jr	00132$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:48: case CT_BUTTERFLY:  return MT_BUTTERFLY_0 + (anim_frame & 1);
00121$:
	ld	a, (_anim_frame)
	and	a, #0x01
	add	a, #0x1d
	jr	00132$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:49: case CT_BEAR:       return ((extra & 4) ? MT_BEAR_2 : MT_BEAR_0) + (anim_frame & 1);
00122$:
	push	hl
	ldhl	sp,	#2
	bit	2, (hl)
	pop	hl
	ld	c, #0x2a
	jr	NZ, 00137$
	ld	c, #0x28
00137$:
	ld	a, (_anim_frame)
	and	a, #0x01
	add	a, c
	jr	00132$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:50: case CT_LAVA:       return MT_LAVA_0;
00123$:
	ld	a, #0x1f
	jr	00132$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:51: case CT_MAGNET:     return (extra & 2) ? MT_MAGNET_1 : MT_MAGNET_0;
00124$:
	push	hl
	ldhl	sp,	#2
	bit	1, (hl)
	pop	hl
	jr	Z, 00138$
	ld	a, #0x22
	jr	00132$
00138$:
	ld	a, #0x21
	jr	00132$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:52: case CT_ROBBO:      return MT_ROBBO_0 + robbo_mt_base[extra & 3] +
00125$:
	ld	bc, #_robbo_mt_base+0
	ldhl	sp,	#0
	ld	a, (hl)
	and	a, #0x03
	ld	l, a
	ld	h, #0x00
	add	hl, bc
	ld	a, (hl)
	add	a, #0x2c
	ld	c, a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:53: (robbo_step_anim & 1);
	ld	a, (_robbo_step_anim)
	and	a, #0x01
	add	a, c
	jr	00132$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:54: case CT_BULLET: {
00126$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:55: uint8_t dir = extra & 3;
	ldhl	sp,	#0
	ld	a, (hl)
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:56: return MT_BULLET_0 + (uint8_t)((dir & 1) * 2) + (anim_slow & 1);
	and	a, #0x1
	add	a, a
	add	a, #0x17
	ld	c, a
	ld	a, (_anim_slow)
	and	a, #0x01
	add	a, c
	jr	00132$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:58: case CT_EXPLOSION: {
00127$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:59: uint8_t t = extra & 7;
	ldhl	sp,	#0
	ld	a, (hl)
	and	a, #0x07
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:61: if (t > 5) t = 5;
	cp	a, #0x06
	jr	C, 00129$
	ld	a, #0x05
00129$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:62: frame = (t >= 3) ? (uint8_t)(6 - t) : t;
	cp	a, #0x03
	jr	C, 00140$
	ld	c, a
	ld	a, #0x06
	sub	a, c
00140$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:63: return MT_EXPLOSION_0 + frame;
	add	a, #0x13
	jr	00132$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:65: default:            return MT_EMPTY;
00130$:
	xor	a, a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:66: }
00132$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:67: }
	inc	sp
	inc	sp
	ret
_turret_mt:
	.db #0x0d	; 13
	.db #0x0e	; 14
	.db #0x0f	; 15
	.db #0x10	; 16
_robbo_mt_base:
	.db #0x00	; 0
	.db #0x02	; 2
	.db #0x04	; 4
	.db #0x06	; 6
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:69: static uint8_t empty_tile(void)
;	---------------------------------
; Function empty_tile
; ---------------------------------
_empty_tile:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:71: return metatile_tiles[MT_EMPTY * 4];
	ld	a, (#_metatile_tiles + 0)
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:72: }
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:74: static void draw_metatile(uint8_t mt, uint8_t tx, uint8_t ty)
;	---------------------------------
; Function draw_metatile
; ---------------------------------
_draw_metatile:
	ld	c, a
	ld	b, e
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:79: const uint8_t *t = &metatile_tiles[mt << 2];
	ld	de, #_metatile_tiles+0
	ld	l, c
	ld	h, #0x00
	add	hl, hl
	add	hl, hl
	add	hl, de
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:80: set_bkg_tiles(tx, ty, 2, 2, t);
	push	hl
	ld	hl, #0x202
	push	hl
	ldhl	sp,	#6
	ld	a, (hl)
	push	af
	inc	sp
	push	bc
	inc	sp
	call	_set_bkg_tiles
	add	sp, #6
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:81: }
	pop	hl
	inc	sp
	jp	(hl)
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:83: static void draw_level_row(uint8_t level_y, uint8_t map_row)
;	---------------------------------
; Function draw_level_row
; ---------------------------------
_draw_level_row:
	add	sp, #-3
	ld	c, a
	ldhl	sp,	#2
	ld	(hl), e
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:87: for (x = 0; x < MAP_W; x++) {
	ld	a, (hl-)
	dec	hl
	add	a, a
	ld	(hl), a
	ld	b, #0x00
00105$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:89: if (level_y < level_height) {
	ld	a, c
	ld	hl, #_level_height
	sub	a, (hl)
	jr	NC, 00102$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:90: uint16_t idx = level_y * MAP_W + x;
	ld	l, c
	xor	a, a
	ld	h, a
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	e, b
	ld	d, #0x00
	add	hl, de
	ld	e, l
	ld	d, h
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:91: mt = render_metatile_for_cell(map_type[idx], map_extra[idx]);
	ld	hl, #_map_extra
	add	hl, de
	ld	a, (hl)
	ldhl	sp,	#1
	ld	(hl), a
	ld	hl, #_map_type
	add	hl, de
	ld	a, (hl)
	push	bc
	ldhl	sp,	#3
	ld	e, (hl)
	call	_render_metatile_for_cell
	ld	d, a
	pop	bc
	jr	00103$
00102$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:93: mt = MT_EMPTY;
	ld	d, #0x00
00103$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:95: draw_metatile(mt, x * 2, map_row * 2);
	ld	a, b
	add	a, a
	push	bc
	ldhl	sp,	#2
	ld	h, (hl)
	push	hl
	inc	sp
	ld	e, a
	ld	a, d
	call	_draw_metatile
	pop	bc
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:87: for (x = 0; x < MAP_W; x++) {
	inc	b
	ld	a, b
	sub	a, #0x10
	jr	C, 00105$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:97: map_row_level[map_row] = level_y;
	ld	de, #_map_row_level
	ldhl	sp,	#2
	ld	l, (hl)
	ld	h, #0x00
	add	hl, de
	ld	e, l
	ld	d, h
	ld	a, c
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:98: }
	add	sp, #3
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:100: static void lcd_isr(void)
;	---------------------------------
; Function lcd_isr
; ---------------------------------
_lcd_isr:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:104: if (LY_REG == 16) {
	ldh	a, (_LY_REG + 0)
	sub	a, #0x10
	ret	NZ
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:105: LCDC_REG &= (uint8_t)~LCDCF_WINON;
	ldh	a, (_LCDC_REG + 0)
	and	a, #0xdf
	ldh	(_LCDC_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:107: }
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:109: void render_apply_camera(void)
;	---------------------------------
; Function render_apply_camera
; ---------------------------------
_render_apply_camera::
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:111: SCX_REG = (uint8_t)(cam_x * 16);
	ld	a, (_cam_x)
	swap	a
	and	a, #0xf0
	ldh	(_SCX_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:112: SCY_REG = (uint8_t)(((cam_y & (MAP_METAROWS - 1)) * 16) - 16);
	ld	a, (#_cam_y)
	swap a
	and	a, #0xf0
	add	a, #0xf0
	ldh	(_SCY_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:113: }
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:115: static void vbl_isr(void)
;	---------------------------------
; Function vbl_isr
; ---------------------------------
_vbl_isr:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:117: LCDC_REG |= LCDCF_WINON;
	ldh	a, (_LCDC_REG + 0)
	or	a, #0x20
	ldh	(_LCDC_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:118: render_apply_camera();
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:119: }
	jp	_render_apply_camera
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:121: void render_init(void)
;	---------------------------------
; Function render_init
; ---------------------------------
_render_init::
	add	sp, #-32
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:125: uint8_t empty = empty_tile();
	call	_empty_tile
	ld	c, a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:127: BGP_REG = 0xE4;
	ld	a, #0xe4
	ldh	(_BGP_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:128: SCX_REG = 0;
	xor	a, a
	ldh	(_SCX_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:129: SCY_REG = 0;
	xor	a, a
	ldh	(_SCY_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:133: LCDC_REG = LCDCF_WIN9C00 | LCDCF_BG8000 | LCDCF_BGON;
	ld	a, #0x51
	ldh	(_LCDC_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:136: SWITCH_ROM_MBC5(1);
	ld	a, #0x01
	ldh	(__current_bank + 0), a
	xor	a, a
	ld	(#_rROMB1),a
	ld	hl, #_rROMB0
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:137: set_bkg_data(0, TILESET_COUNT, tileset_data);
	ld	de, #_tileset_data
	push	de
	ld	hl, #0xed00
	push	hl
	call	_set_bkg_data
	add	sp, #4
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:138: SWITCH_ROM_MBC5(0);
	xor	a, a
	ldh	(__current_bank + 0), a
	xor	a, a
	ld	(#_rROMB1), a
	ld	(#_rROMB0),a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:141: for (x = 0; x < 32; x++) buf[x] = empty;
	ldhl	sp,	#0
	ld	e, l
	ld	d, h
	ld	b, #0x00
00106$:
	ld	l, b
	ld	h, #0x00
	add	hl, de
	ld	(hl), c
	inc	b
	ld	a, b
	sub	a, #0x20
	jr	C, 00106$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:142: for (y = 0; y < 32; y++) {
	ld	b, #0x00
00108$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:143: set_bkg_tiles(0, y, 32, 1, buf);
	ld	l, e
	ld	h, d
	push	de
	push	hl
	ld	hl, #0x120
	push	hl
	push	bc
	inc	sp
	xor	a, a
	push	af
	inc	sp
	call	_set_bkg_tiles
	add	sp, #6
	pop	de
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:142: for (y = 0; y < 32; y++) {
	inc	b
	ld	a, b
	sub	a, #0x20
	jr	C, 00108$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:146: for (x = 0; x < 20; x++) buf[x] = empty;
	ld	b, #0x00
00110$:
	ld	l, b
	ld	h, #0x00
	add	hl, de
	ld	(hl), c
	inc	b
	ld	a, b
	sub	a, #0x14
	jr	C, 00110$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:147: for (y = 0; y < 2; y++) {
	ld	b, #0x00
00112$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:148: set_win_tiles(0, y, 20, 1, buf);
	ld	l, e
	ld	h, d
	push	de
	push	hl
	ld	hl, #0x114
	push	hl
	push	bc
	inc	sp
	xor	a, a
	push	af
	inc	sp
	call	_set_win_tiles
	add	sp, #6
	pop	de
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:147: for (y = 0; y < 2; y++) {
	inc	b
	ld	a, b
	sub	a, #0x02
	jr	C, 00112$
;c:\dev\ai\robbo-port2\gbdk\include\gb\gb.h:1739: WX_REG=x, WY_REG=y;
	ld	a, #0x06
	ldh	(_WX_REG + 0), a
	xor	a, a
	ldh	(_WY_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:153: LCDC_REG |= LCDCF_ON | LCDCF_WINON;
	ldh	a, (_LCDC_REG + 0)
	or	a, #0xa0
	ldh	(_LCDC_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:155: LYC_REG = 16;
	ld	a, #0x10
	ldh	(_LYC_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:156: STAT_REG = STATF_LYC;
	ld	a, #0x40
	ldh	(_STAT_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:157: add_LCD(lcd_isr);
	ld	de, #_lcd_isr
	call	_add_LCD
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:158: add_VBL(vbl_isr);
	ld	de, #_vbl_isr
	call	_add_VBL
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:159: set_interrupts(VBL_IFLAG | LCD_IFLAG);
	ld	a, #0x03
	call	_set_interrupts
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:160: }
	add	sp, #32
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:162: void render_level(void)
;	---------------------------------
; Function render_level
; ---------------------------------
_render_level::
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:166: for (row = 0; row < DIRTY_WORDS; row++) dirty_bits[row] = 0;
	ld	bc, #_dirty_bits+0
	ld	e, #0x00
00103$:
	ld	l, e
	ld	h, #0x00
	add	hl, bc
	ld	(hl), #0x00
	inc	e
	ld	a, e
	sub	a, #0x3e
	jr	C, 00103$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:167: dirty_any = 0;
	xor	a, a
	ld	(#_dirty_any),a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:169: for (row = 0; row < MAP_METAROWS; row++) {
	ld	e, #0x00
00105$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:170: draw_level_row(row, row);
	push	de
	ld	a, e
	call	_draw_level_row
	pop	de
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:169: for (row = 0; row < MAP_METAROWS; row++) {
	inc	e
	ld	a, e
	sub	a, #0x10
	jr	C, 00105$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:173: render_hud();
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:174: }
	jp	_render_hud
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:176: void render_hud(void)
;	---------------------------------
; Function render_hud
; ---------------------------------
_render_hud::
	add	sp, #-56
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:181: uint8_t icons[4] = {
	ldhl	sp,	#46
	ld	a, #0x23
	ld	(hl+), a
	ld	a, #0x24
	ld	(hl+), a
	ld	a, #0x25
	ld	(hl+), a
	ld	(hl), #0x27
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:185: for (i = 0; i < 40; i++) win[i] = hud_bg_tile;
	ldhl	sp,	#2
	ld	c, l
	ld	b, h
	ld	e, #0x00
00112$:
	ld	l, e
	ld	h, #0x00
	add	hl, bc
	ld	a, (_hud_bg_tile)
	ld	(hl), a
	inc	e
	ld	a, e
	sub	a, #0x28
	jr	C, 00112$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:187: if (screws_left > 99) values[0] = 99; else values[0] = screws_left;
	ld	a, #0x63
	ld	hl, #_screws_left
	sub	a, (hl)
	jr	NC, 00103$
	ldhl	sp,	#42
	ld	(hl), #0x63
	jr	00104$
00103$:
	ld	a, (#_screws_left)
	ldhl	sp,	#42
	ld	(hl), a
00104$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:188: if (ammo > 99) values[1] = 99; else values[1] = ammo;
	ld	a, #0x63
	ld	hl, #_ammo
	sub	a, (hl)
	jr	NC, 00106$
	ldhl	sp,	#43
	ld	(hl), #0x63
	jr	00107$
00106$:
	ld	a, (#_ammo)
	ldhl	sp,	#43
	ld	(hl), a
00107$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:189: if (keys > 99) values[2] = 99; else values[2] = keys;
	ld	a, #0x63
	ld	hl, #_keys
	sub	a, (hl)
	jr	NC, 00109$
	ldhl	sp,	#44
	ld	(hl), #0x63
	jr	00110$
00109$:
	ld	a, (#_keys)
	ldhl	sp,	#44
	ld	(hl), a
00110$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:190: values[3] = level_planet;
	ld	a, (#_level_planet)
	ldhl	sp,	#45
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:192: for (g = 0; g < 4; g++) {
	ldhl	sp,	#55
	ld	(hl), #0x00
00114$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:193: const uint8_t *icon = &metatile_tiles[icons[g] * 4];
	push	hl
	ld	hl, #48
	add	hl, sp
	ld	e, l
	ld	d, h
	pop	hl
	ldhl	sp,	#55
	ld	l, (hl)
	ld	h, #0x00
	add	hl, de
	ld	e, l
	ld	d, h
	ld	a, (de)
	ld	h, #0x00
	ld	l, a
	add	hl, hl
	add	hl, hl
	ld	a, l
	add	a, #<(_metatile_tiles)
	ld	e, a
	ld	a, h
	adc	a, #>(_metatile_tiles)
	ldhl	sp,	#50
	ld	(hl), e
	inc	hl
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:194: uint8_t tens = (values[g] / 10) % 10;
	push	hl
	ld	hl, #44
	add	hl, sp
	ld	e, l
	ld	d, h
	pop	hl
	ldhl	sp,	#55
	ld	l, (hl)
	ld	h, #0x00
	add	hl, de
	ld	e, l
	ld	d, h
	ld	a, (de)
	ldhl	sp,	#54
	ld	(hl), a
	push	bc
	ld	e, #0x0a
	ld	a, (hl)
	call	__divuchar
	ld	a, c
	ld	e, #0x0a
	call	__moduchar
	ld	a, c
	pop	bc
	ldhl	sp,	#52
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:195: uint8_t ones = values[g] % 10;
	ld	(hl+), a
	inc	hl
	push	bc
	ld	e, #0x0a
	ld	a, (hl)
	call	__moduchar
	ld	a, c
	pop	bc
	ldhl	sp,	#53
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:200: x = hud_x[g];
	ld	(hl+), a
	inc	hl
	ld	de, #_render_hud_hud_x_30000_201
	ld	l, (hl)
	ld	h, #0x00
	add	hl, de
	ld	e, l
	ld	d, h
	ld	a, (de)
	ldhl	sp,	#54
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:201: win[x] = icon[0];
	ld	l, (hl)
	ld	h, #0x00
	add	hl, bc
	inc	sp
	inc	sp
	push	hl
	ldhl	sp,#50
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	a, (de)
	pop	hl
	push	hl
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:202: win[x + 1] = icon[1];
	ldhl	sp,	#54
	ld	a, (hl)
	inc	a
	ld	l, a
	rlca
	sbc	a, a
	ld	h, a
	add	hl, bc
	ld	e, l
	ld	d, h
	ldhl	sp,	#50
	ld	a, (hl+)
	ld	h, (hl)
	ld	l, a
	inc	hl
	ld	a, (hl)
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:203: win[20 + x] = icon[2];
	ldhl	sp,	#54
	ld	a, (hl)
	add	a, #0x14
	ld	l, a
	rlca
	sbc	a, a
	ld	h, a
	add	hl, bc
	ld	e, l
	ld	d, h
	ldhl	sp,	#50
	ld	a, (hl+)
	ld	h, (hl)
	ld	l, a
	inc	hl
	inc	hl
	ld	a, (hl)
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:204: win[20 + x + 1] = icon[3];
	ldhl	sp,	#54
	ld	a, (hl)
	add	a, #0x15
	ld	l, a
	rlca
	sbc	a, a
	ld	h, a
	add	hl, bc
	ld	e, l
	ld	d, h
	ldhl	sp,	#50
	ld	a, (hl+)
	ld	h, (hl)
	ld	l, a
	inc	hl
	inc	hl
	inc	hl
	ld	a, (hl)
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:206: win[x + 2] = digit_tiles[tens][0];
	ldhl	sp,	#54
	ld	a, (hl)
	inc	a
	inc	a
	ld	e, a
	rlca
	sbc	a, a
	ld	d, a
	ld	l, e
	ld	h, d
	add	hl, bc
	push	hl
	ld	a, l
	ldhl	sp,	#52
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#51
	ld	(hl+), a
	ld	a, (hl)
	ld	d, #0x00
	add	a, a
	rl	d
	ld	e, a
	ld	hl, #_digit_tiles
	add	hl, de
	inc	sp
	inc	sp
	ld	e, l
	ld	d, h
	push	de
	ld	a, (de)
	ldhl	sp,	#50
	ld	e, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, e
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:207: win[20 + x + 2] = digit_tiles[tens][1];
	ldhl	sp,	#54
	ld	a, (hl)
	add	a, #0x16
	ld	l, a
	rlca
	sbc	a, a
	ld	h, a
	add	hl, bc
	ld	e, l
	ld	d, h
	pop	hl
	push	hl
	inc	hl
	ld	a, (hl)
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:208: win[x + 3] = digit_tiles[ones][0];
	ldhl	sp,	#54
	ld	a, (hl)
	inc	a
	inc	a
	inc	a
	ld	e, a
	rlca
	sbc	a, a
	ld	d, a
	ld	l, e
	ld	h, d
	add	hl, bc
	push	hl
	ld	a, l
	ldhl	sp,	#53
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#52
	ld	(hl+), a
	ld	a, (hl)
	ld	d, #0x00
	add	a, a
	rl	d
	ld	e, a
	ld	hl, #_digit_tiles
	add	hl, de
	inc	sp
	inc	sp
	ld	e, l
	ld	d, h
	push	de
	ld	a, (de)
	ldhl	sp,	#51
	ld	e, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, e
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:209: win[20 + x + 3] = digit_tiles[ones][1];
	ldhl	sp,	#54
	ld	a, (hl)
	add	a, #0x17
	ld	l, a
	rlca
	sbc	a, a
	ld	h, a
	add	hl, bc
	ld	e, l
	ld	d, h
	pop	hl
	push	hl
	inc	hl
	ld	a, (hl)
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:192: for (g = 0; g < 4; g++) {
	ldhl	sp,	#55
	inc	(hl)
	ld	a, (hl)
	sub	a, #0x04
	jp	C, 00114$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:212: set_win_tiles(0, 0, 20, 2, win);
	push	bc
	ld	hl, #0x214
	push	hl
	xor	a, a
	rrca
	push	af
	call	_set_win_tiles
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:213: }
	add	sp, #62
	ret
_render_hud_hud_x_30000_201:
	.db #0x00	; 0
	.db #0x05	; 5
	.db #0x0b	; 11
	.db #0x10	; 16
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:215: void render_flash_set(uint8_t on)
;	---------------------------------
; Function render_flash_set
; ---------------------------------
_render_flash_set::
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:219: BGP_REG = on ? 0xE0 : 0xE4;
	or	a, a
	ld	a, #0xe0
	jr	NZ, 00104$
	ld	a, #0xe4
00104$:
	ldh	(_BGP_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:220: }
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:222: void render_sync_rows(void)
;	---------------------------------
; Function render_sync_rows
; ---------------------------------
_render_sync_rows::
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:225: for (i = 0; i < VIEW_ROWS; i++) {
	ld	c, #0x00
00104$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:226: uint8_t level_y = cam_y + i;
	ld	a, (#_cam_y)
	add	a, c
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:227: uint8_t map_row = level_y & (MAP_METAROWS - 1);
	ld	b, a
	and	a, #0x0f
	ld	e, a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:228: if (map_row_level[map_row] != level_y) {
	ld	hl, #_map_row_level
	ld	d, #0x00
	add	hl, de
	ld	a, (hl)
	sub	a, b
	jr	Z, 00105$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:229: draw_level_row(level_y, map_row);
	push	bc
	ld	a, b
	call	_draw_level_row
	pop	bc
00105$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:225: for (i = 0; i < VIEW_ROWS; i++) {
	inc	c
	ld	a, c
	sub	a, #0x08
	jr	C, 00104$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:232: }
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:234: static void draw_cell_now(uint8_t x, uint8_t y)
;	---------------------------------
; Function draw_cell_now
; ---------------------------------
_draw_cell_now:
	add	sp, #-3
	ldhl	sp,	#2
	ld	(hl), a
	ld	c, e
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:236: uint8_t map_row = y & (MAP_METAROWS - 1);
	ld	a, c
	and	a, #0x0f
	ld	e, a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:239: if (map_row_level[map_row] != y) return;
	ld	hl, #_map_row_level
	ld	d, #0x00
	add	hl, de
	ld	a, (hl)
	sub	a, c
	jr	NZ, 00103$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:240: idx = (uint16_t)y * MAP_W + x;
	ld	l, c
	ld	h, #0x00
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	c, l
	ld	b, h
	ldhl	sp,	#2
	ld	l, (hl)
	ld	h, #0x00
	add	hl, bc
	ld	c, l
	ld	b, h
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:242: x * 2, map_row * 2);
	ld	a, e
	add	a, a
	ldhl	sp,	#0
	ld	(hl+), a
	inc	hl
	ld	a, (hl-)
	add	a, a
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:241: draw_metatile(render_metatile_for_cell(map_type[idx], map_extra[idx]),
	ld	hl, #_map_extra
	add	hl, bc
	ld	e, (hl)
	ld	hl, #_map_type
	add	hl, bc
	ld	a, (hl)
	call	_render_metatile_for_cell
	ldhl	sp,	#0
	ld	h, (hl)
	push	hl
	inc	sp
	ldhl	sp,	#2
	ld	e, (hl)
	call	_draw_metatile
00103$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:243: }
	add	sp, #3
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:245: void render_cell(uint8_t x, uint8_t y)
;	---------------------------------
; Function render_cell
; ---------------------------------
_render_cell::
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:247: uint16_t idx = ((uint16_t)y << 4) | x;
	ld	l, e
	ld	h, #0x00
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	or	a, l
	ld	e, a
	ld	d, h
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:249: dirty_bits[idx >> 3] |= (uint8_t)(1u << (idx & 7));
	ld	bc, #_dirty_bits+0
	ld	l, e
	ld	h, d
	srl	h
	rr	l
	srl	h
	rr	l
	srl	h
	rr	l
	add	hl, bc
	ld	c, (hl)
	ld	a, e
	and	a, #0x07
	ld	b, a
	ld	a, #0x01
	inc	b
	jr	00104$
00103$:
	add	a, a
00104$:
	dec	b
	jr	NZ,00103$
	or	a, c
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:250: dirty_any = 1;
	ld	hl, #_dirty_any
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:251: }
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:253: void render_flush_cells(void)
;	---------------------------------
; Function render_flush_cells
; ---------------------------------
_render_flush_cells::
	add	sp, #-3
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:258: if (!dirty_any) return;
	ld	a, (#_dirty_any)
	or	a, a
	jr	Z, 00113$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:259: dirty_any = 0;
	xor	a, a
	ld	(#_dirty_any),a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:260: for (i = 0; i < DIRTY_WORDS; i++) {
	ld	c, #0x00
00112$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:261: uint8_t b = dirty_bits[i];
	ld	hl, #_dirty_bits
	ld	b, #0x00
	add	hl, bc
	ld	a, (hl)
	ld	d, a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:262: if (!b) continue;
	or	a, a
	jr	Z, 00109$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:263: dirty_bits[i] = 0;
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:264: for (p = 0; p < 8; p++) {
	ldhl	sp,	#2
	ld	(hl), #0x00
00111$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:265: if (!(b & (uint8_t)(1u << p))) continue;
	ldhl	sp,	#2
	ld	b, (hl)
	ld	a, #0x01
	inc	b
	jr	00153$
00152$:
	add	a, a
00153$:
	dec	b
	jr	NZ,00152$
	and	a, d
	jr	Z, 00107$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:266: idx = (uint16_t)((i << 3) | p);
	dec	hl
	dec	hl
	ld	b, c
	xor	a, a
	sla	b
	adc	a, a
	sla	b
	adc	a, a
	sla	b
	adc	a, a
	ld	(hl), b
	inc	hl
	ld	(hl+), a
	ld	a, (hl-)
	dec	hl
	ld	e, a
	ld	a, (hl+)
	or	a, e
	ld	b, (hl)
	dec	hl
	ld	(hl+), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:267: draw_cell_now((uint8_t)(idx & 0x0F), (uint8_t)(idx >> 4));
	ld	a, b
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	a, (hl-)
	ld	b, a
	srl	b
	rr	e
	srl	b
	rr	e
	srl	b
	rr	e
	srl	b
	rr	e
	ld	a, (hl)
	and	a, #0x0f
	push	bc
	push	de
	call	_draw_cell_now
	pop	de
	pop	bc
00107$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:264: for (p = 0; p < 8; p++) {
	ldhl	sp,	#2
	inc	(hl)
	ld	a, (hl)
	sub	a, #0x08
	jr	C, 00111$
00109$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:260: for (i = 0; i < DIRTY_WORDS; i++) {
	inc	c
	ld	a, c
	sub	a, #0x3e
	jr	C, 00112$
00113$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:270: }
	add	sp, #3
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:272: void render_camera(void)
;	---------------------------------
; Function render_camera
; ---------------------------------
_render_camera::
	add	sp, #-7
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:275: uint8_t max_y = (level_height > VIEW_ROWS) ? (level_height - VIEW_ROWS) : 0;
	ld	a, #0x08
	ld	hl, #_level_height
	sub	a, (hl)
	jr	NC, 00131$
	ld	a, (hl)
	add	a, #0xf8
	ld	c, a
	jr	00132$
00131$:
	ld	c, #0x00
00132$:
	ldhl	sp,	#0
	ld	(hl), c
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:277: if (cam_override) {
	ld	a, (#_cam_override)
	or	a, a
	jr	Z, 00114$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:279: if (cam_pan_timer < 2) {
	ld	hl, #_cam_pan_timer
	ld	a, (hl)
	sub	a, #0x02
	jr	NC, 00102$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:280: cam_pan_timer++;
	inc	(hl)
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:281: return;
	jp	00129$
00102$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:283: cam_pan_timer = 0;
	xor	a, a
	ld	(#_cam_pan_timer),a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:285: if (cam_x < cam_target_x) cam_x++;
	ld	a, (#_cam_x)
	ld	hl, #_cam_target_x
	sub	a, (hl)
	jr	NC, 00106$
	ld	hl, #_cam_x
	inc	(hl)
	jr	00107$
00106$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:286: else if (cam_x > cam_target_x) cam_x--;
	ld	a, (#_cam_target_x)
	ld	hl, #_cam_x
	sub	a, (hl)
	jr	NC, 00107$
	dec	(hl)
00107$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:287: if (cam_y < cam_target_y) cam_y++;
	ld	a, (#_cam_y)
	ld	hl, #_cam_target_y
	sub	a, (hl)
	jr	NC, 00111$
	ld	hl, #_cam_y
	inc	(hl)
	jp	00129$
00111$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:288: else if (cam_y > cam_target_y) cam_y--;
	ld	a, (#_cam_target_y)
	ld	hl, #_cam_y
	sub	a, (hl)
	jp	NC, 00129$
	dec	(hl)
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:289: return;
	jp	00129$
00114$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:292: if (robbo_x < cam_x + 2) {
	ld	a, (#_cam_x)
	ldhl	sp,	#1
	ld	(hl+), a
	xor	a, a
	ld	(hl-), a
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #0x0002
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#5
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#4
	ld	(hl), a
	ld	a, (#_robbo_x)
	ldhl	sp,	#5
	ld	(hl+), a
	ld	(hl), #0x00
	ldhl	sp,	#5
	ld	e, l
	ld	d, h
	ldhl	sp,	#3
	ld	a, (de)
	inc	de
	sub	a, (hl)
	inc	hl
	ld	a, (de)
	sbc	a, (hl)
	jr	NC, 00118$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:293: cam_x = (robbo_x >= 2) ? (robbo_x - 2) : 0;
	ld	a, (#_robbo_x)
	cp	a,#0x02
	jr	C, 00133$
	ldhl	sp,	#6
	ld	(hl), a
	dec	(hl)
	dec	(hl)
	ld	a, (hl-)
	ld	(hl+), a
	rlca
	sbc	a, a
	ld	(hl), a
	jr	00134$
00133$:
	xor	a, a
	ldhl	sp,	#5
	ld	(hl+), a
	ld	(hl), a
00134$:
	ldhl	sp,	#5
	ld	a, (hl)
	ld	(#_cam_x),a
	jr	00119$
00118$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:294: } else if (robbo_x > cam_x + 7) {
	ldhl	sp,#1
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #0x0007
	add	hl, de
	ld	c, l
	ld	b, h
	ldhl	sp,	#5
	ld	a, c
	sub	a, (hl)
	inc	hl
	ld	a, b
	sbc	a, (hl)
	jr	NC, 00119$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:295: cam_x = robbo_x - 7;
	ld	a, (_robbo_x)
	add	a, #0xf9
	ld	(#_cam_x),a
00119$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:297: if (cam_x > max_x) cam_x = max_x;
	ld	a, #0x06
	ld	hl, #_cam_x
	sub	a, (hl)
	jr	NC, 00121$
	ld	(hl), #0x06
00121$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:299: if (robbo_y < cam_y + 2) {
	ld	a, (#_cam_y)
	ldhl	sp,	#3
	ld	(hl+), a
	xor	a, a
	ld	(hl-), a
	ld	c, (hl)
	ld	b, #0x00
	inc	bc
	inc	bc
	ld	a, (#_robbo_y)
	ldhl	sp,	#5
	ld	(hl+), a
	xor	a, a
	ld	(hl-), a
	ld	a, (hl+)
	sub	a, c
	ld	a, (hl)
	sbc	a, b
	jr	NC, 00125$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:300: cam_y = (robbo_y >= 2) ? (robbo_y - 2) : 0;
	ld	a, (#_robbo_y)
	cp	a,#0x02
	jr	C, 00135$
	dec	a
	dec	a
	ld	e, a
	jr	00136$
00135$:
	ld	e, #0x00
00136$:
	ld	hl, #_cam_y
	ld	(hl), e
	jr	00126$
00125$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:301: } else if (robbo_y > cam_y + 5) {
	ldhl	sp,#3
	ld	a, (hl+)
	ld	e, a
	ld	d, (hl)
	ld	hl, #0x0005
	add	hl, de
	ld	c, l
	ld	b, h
	ldhl	sp,	#5
	ld	a, c
	sub	a, (hl)
	inc	hl
	ld	a, b
	sbc	a, (hl)
	jr	NC, 00126$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:302: cam_y = robbo_y - 5;
	ld	a, (_robbo_y)
	add	a, #0xfb
	ld	(#_cam_y),a
00126$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:304: if (cam_y > max_y) cam_y = max_y;
	ldhl	sp,	#0
	ld	a, (hl)
	ld	hl, #_cam_y
	sub	a, (hl)
	jr	NC, 00129$
	ldhl	sp,	#0
	ld	a, (hl)
	ld	(#_cam_y),a
00129$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:305: }
	add	sp, #7
	ret
	.area _CODE
	.area _INITIALIZER
	.area _CABS (ABS)
