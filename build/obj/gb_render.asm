;--------------------------------------------------------
; File Created by SDCC : free open source ISO C Compiler
; Version 4.5.1 #15267 (MINGW64)
;--------------------------------------------------------
	.module render
	
;--------------------------------------------------------
; Public variables in this module
;--------------------------------------------------------
	.globl _set_win_tiles
	.globl _set_bkg_tile_xy
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
	.globl _render_pause
	.globl _render_flash_set
	.globl _render_victory
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
_dirty_cells:
	.ds 128
_dirty_count:
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
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:29: uint8_t render_metatile_for_cell(uint8_t type, uint8_t extra)
;	---------------------------------
; Function render_metatile_for_cell
; ---------------------------------
_render_metatile_for_cell::
	dec	sp
	dec	sp
	ldhl	sp,	#1
	ld	(hl-), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:31: if (IS_WALL(type)) return MT_WALL;
	ld	a, e
	ld	(hl+), a
	ld	a, (hl)
	sub	a, #0x01
	jr	C, 00102$
	ld	a, #0x08
	sub	a, (hl)
	jr	C, 00102$
	ld	a, #0x01
	jp	00129$
00102$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:33: switch (type) {
	ld	a, #0x1c
	ldhl	sp,	#1
	sub	a, (hl)
	jp	C, 00127$
	ld	c, (hl)
	ld	b, #0x00
	ld	hl, #00199$
	add	hl, bc
	add	hl, bc
	ld	c, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, c
	jp	(hl)
00199$:
	.dw	00104$
	.dw	00127$
	.dw	00127$
	.dw	00127$
	.dw	00127$
	.dw	00127$
	.dw	00127$
	.dw	00127$
	.dw	00127$
	.dw	00105$
	.dw	00106$
	.dw	00107$
	.dw	00108$
	.dw	00109$
	.dw	00110$
	.dw	00111$
	.dw	00112$
	.dw	00113$
	.dw	00115$
	.dw	00114$
	.dw	00116$
	.dw	00117$
	.dw	00118$
	.dw	00119$
	.dw	00120$
	.dw	00121$
	.dw	00122$
	.dw	00123$
	.dw	00124$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:34: case CT_EMPTY:      return MT_EMPTY;
00104$:
	xor	a, a
	jp	00129$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:35: case CT_GROUND:     return MT_GROUND;
00105$:
	ld	a, #0x02
	jp	00129$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:36: case CT_STONE:      return MT_STONE;
00106$:
	ld	a, #0x03
	jp	00129$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:37: case CT_PUSHABLE:   return MT_PUSHABLE;
00107$:
	ld	a, #0x04
	jp	00129$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:38: case CT_DOOR:       return MT_DOOR;
00108$:
	ld	a, #0x05
	jp	00129$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:39: case CT_SPACESHIP:  return ((extra & 1) || screws_left == 0) ? MT_SPACESHIP_1 : MT_SPACESHIP_0;
00109$:
	ldhl	sp,	#0
	ld	a, (hl)
	and	a, #0x01
	jr	NZ, 00134$
	ld	a, (#_screws_left)
	or	a, a
	jr	NZ, 00131$
00134$:
	ld	a, #0x07
	jp	00129$
00131$:
	ld	a, #0x06
	jp	00129$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:40: case CT_QUESTION:   return MT_QUESTION;
00110$:
	ld	a, #0x08
	jp	00129$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:41: case CT_BOMB:       return MT_BOMB;
00111$:
	ld	a, #0x09
	jp	00129$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:42: case CT_KEY:        return MT_KEY;
00112$:
	ld	a, #0x0a
	jp	00129$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:43: case CT_SCREW:      return MT_SCREW;
00113$:
	ld	a, #0x0b
	jr	00129$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:44: case CT_AMMO:       return MT_AMMO;
00114$:
	ld	a, #0x0c
	jr	00129$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:45: case CT_TURRET:     return turret_mt[extra & 3];
00115$:
	ld	bc, #_turret_mt+0
	ldhl	sp,	#0
	ld	a, (hl)
	and	a, #0x03
	ld	l, a
	ld	h, #0x00
	add	hl, bc
	ld	a, (hl)
	jr	00129$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:46: case CT_TELEPORT:   return MT_TELEPORT_0;
00116$:
	ld	a, #0x11
	jr	00129$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:49: case CT_MUSTACHE:   return MT_MUSTACHE_0;
00117$:
	ld	a, #0x1a
	jr	00129$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:50: case CT_BUTTERFLY:  return MT_BUTTERFLY_0;
00118$:
	ld	a, #0x1c
	jr	00129$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:51: case CT_BEAR:       return (extra & 4) ? MT_BEAR_2 : MT_BEAR_0;
00119$:
	push	hl
	ldhl	sp,	#2
	bit	2, (hl)
	pop	hl
	jr	Z, 00136$
	ld	a, #0x29
	jr	00129$
00136$:
	ld	a, #0x27
	jr	00129$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:52: case CT_LAVA:       return MT_LAVA_0;
00120$:
	ld	a, #0x1e
	jr	00129$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:53: case CT_MAGNET:     return (extra & 1) ? MT_MAGNET_1 : MT_MAGNET_0;
00121$:
	push	hl
	ldhl	sp,	#2
	bit	0, (hl)
	pop	hl
	jr	Z, 00138$
	ld	a, #0x21
	jr	00129$
00138$:
	ld	a, #0x20
	jr	00129$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:54: case CT_ROBBO:      return MT_ROBBO_0 + robbo_mt_base[extra & 3];
00122$:
	ld	bc, #_robbo_mt_base+0
	ldhl	sp,	#0
	ld	a, (hl)
	and	a, #0x03
	ld	l, a
	ld	h, #0x00
	add	hl, bc
	ld	a, (hl)
	add	a, #0x2b
	jr	00129$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:55: case CT_BULLET:     return bullet_mt[extra & 3];
00123$:
	ld	bc, #_bullet_mt+0
	ldhl	sp,	#0
	ld	a, (hl)
	and	a, #0x03
	ld	l, a
	ld	h, #0x00
	add	hl, bc
	ld	a, (hl)
	jr	00129$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:56: case CT_EXPLOSION: {
00124$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:57: uint8_t t = extra & 7;
	ldhl	sp,	#0
	ld	a, (hl)
	and	a, #0x07
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:59: if (t > 5) t = 5;
	cp	a, #0x06
	jr	C, 00126$
	ld	a, #0x05
00126$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:60: frame = (t >= 3) ? (uint8_t)(6 - t) : t;
	cp	a, #0x03
	jr	C, 00140$
	ld	c, a
	ld	a, #0x06
	sub	a, c
00140$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:61: return MT_EXPLOSION_0 + frame;
	add	a, #0x12
	jr	00129$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:63: default:            return MT_EMPTY;
00127$:
	xor	a, a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:64: }
00129$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:65: }
	inc	sp
	inc	sp
	ret
_turret_mt:
	.db #0x0d	; 13
	.db #0x0e	; 14
	.db #0x0f	; 15
	.db #0x10	; 16
_bullet_mt:
	.db #0x16	; 22
	.db #0x18	; 24
	.db #0x17	; 23
	.db #0x19	; 25
_robbo_mt_base:
	.db #0x00	; 0
	.db #0x02	; 2
	.db #0x04	; 4
	.db #0x06	; 6
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:67: static uint8_t empty_tile(void)
;	---------------------------------
; Function empty_tile
; ---------------------------------
_empty_tile:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:69: return metatile_tiles[MT_EMPTY * 4];
	ld	a, (#_metatile_tiles + 0)
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:70: }
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:72: static void draw_metatile(uint8_t mt, uint8_t tx, uint8_t ty)
;	---------------------------------
; Function draw_metatile
; ---------------------------------
_draw_metatile:
	dec	sp
	ld	d, a
	ldhl	sp,	#0
	ld	(hl), e
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:74: const uint8_t *t = &metatile_tiles[mt * 4];
	ld	bc, #_metatile_tiles+0
	ld	l, d
	ld	h, #0x00
	add	hl, hl
	add	hl, hl
	add	hl, bc
	ld	c, l
	ld	b, h
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:75: set_bkg_tile_xy(tx, ty, t[0]);
	ld	a, (bc)
	push	bc
	push	af
	inc	sp
	ldhl	sp,	#6
	ld	e, (hl)
	ldhl	sp,	#3
	ld	a, (hl)
	call	_set_bkg_tile_xy
	pop	bc
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:76: set_bkg_tile_xy(tx + 1, ty, t[1]);
	ld	l, c
	ld	h, b
	inc	hl
	ld	a, (hl)
	ldhl	sp,	#0
	ld	d, (hl)
	inc	d
	push	bc
	push	de
	push	af
	inc	sp
	ldhl	sp,	#8
	ld	e, (hl)
	ld	a, d
	call	_set_bkg_tile_xy
	pop	de
	pop	bc
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:77: set_bkg_tile_xy(tx, ty + 1, t[2]);
	ld	l, c
	ld	h, b
	inc	hl
	inc	hl
	ld	a, (hl)
	ldhl	sp,	#3
	ld	e, (hl)
	inc	e
	push	bc
	push	de
	push	af
	inc	sp
	ldhl	sp,	#5
	ld	a, (hl)
	call	_set_bkg_tile_xy
	pop	de
	pop	bc
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:78: set_bkg_tile_xy(tx + 1, ty + 1, t[3]);
	inc	bc
	inc	bc
	inc	bc
	ld	a, (bc)
	push	af
	inc	sp
	ld	a, d
	call	_set_bkg_tile_xy
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:79: }
	inc	sp
	pop	hl
	inc	sp
	jp	(hl)
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:81: static void draw_level_row(uint8_t level_y, uint8_t map_row)
;	---------------------------------
; Function draw_level_row
; ---------------------------------
_draw_level_row:
	add	sp, #-3
	ld	c, a
	ldhl	sp,	#2
	ld	(hl), e
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:85: for (x = 0; x < MAP_W; x++) {
	ld	a, (hl-)
	dec	hl
	add	a, a
	ld	(hl), a
	ld	b, #0x00
00105$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:87: if (level_y < level_height) {
	ld	a, c
	ld	hl, #_level_height
	sub	a, (hl)
	jr	NC, 00102$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:88: uint16_t idx = level_y * MAP_W + x;
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
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:89: mt = render_metatile_for_cell(map_type[idx], map_extra[idx]);
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
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:91: mt = MT_EMPTY;
	ld	d, #0x00
00103$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:93: draw_metatile(mt, x * 2, map_row * 2);
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
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:85: for (x = 0; x < MAP_W; x++) {
	inc	b
	ld	a, b
	sub	a, #0x10
	jr	C, 00105$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:95: map_row_level[map_row] = level_y;
	ld	de, #_map_row_level
	ldhl	sp,	#2
	ld	l, (hl)
	ld	h, #0x00
	add	hl, de
	ld	e, l
	ld	d, h
	ld	a, c
	ld	(de), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:96: }
	add	sp, #3
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:98: static void lcd_isr(void)
;	---------------------------------
; Function lcd_isr
; ---------------------------------
_lcd_isr:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:102: if (LY_REG == 16) {
	ldh	a, (_LY_REG + 0)
	sub	a, #0x10
	ret	NZ
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:103: LCDC_REG &= (uint8_t)~LCDCF_WINON;
	ldh	a, (_LCDC_REG + 0)
	and	a, #0xdf
	ldh	(_LCDC_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:105: }
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:107: void render_apply_camera(void)
;	---------------------------------
; Function render_apply_camera
; ---------------------------------
_render_apply_camera::
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:109: SCX_REG = (uint8_t)(cam_x * 16);
	ld	a, (_cam_x)
	swap	a
	and	a, #0xf0
	ldh	(_SCX_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:110: SCY_REG = (uint8_t)(((cam_y & (MAP_METAROWS - 1)) * 16) - 16);
	ld	a, (#_cam_y)
	swap a
	and	a, #0xf0
	add	a, #0xf0
	ldh	(_SCY_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:111: }
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:113: static void vbl_isr(void)
;	---------------------------------
; Function vbl_isr
; ---------------------------------
_vbl_isr:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:115: LCDC_REG |= LCDCF_WINON;
	ldh	a, (_LCDC_REG + 0)
	or	a, #0x20
	ldh	(_LCDC_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:116: render_apply_camera();
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:117: }
	jp	_render_apply_camera
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:119: void render_init(void)
;	---------------------------------
; Function render_init
; ---------------------------------
_render_init::
	add	sp, #-32
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:123: uint8_t empty = empty_tile();
	call	_empty_tile
	ld	c, a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:125: BGP_REG = 0xE4;
	ld	a, #0xe4
	ldh	(_BGP_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:126: SCX_REG = 0;
	xor	a, a
	ldh	(_SCX_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:127: SCY_REG = 0;
	xor	a, a
	ldh	(_SCY_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:131: LCDC_REG = LCDCF_WIN9C00 | LCDCF_BG8000 | LCDCF_BGON;
	ld	a, #0x51
	ldh	(_LCDC_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:134: SWITCH_ROM_MBC5(1);
	ld	a, #0x01
	ldh	(__current_bank + 0), a
	xor	a, a
	ld	(#_rROMB1),a
	ld	hl, #_rROMB0
	ld	(hl), #0x01
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:135: set_bkg_data(0, TILESET_COUNT, tileset_data);
	ld	de, #_tileset_data
	push	de
	ld	hl, #0xed00
	push	hl
	call	_set_bkg_data
	add	sp, #4
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:136: SWITCH_ROM_MBC5(0);
	xor	a, a
	ldh	(__current_bank + 0), a
	xor	a, a
	ld	(#_rROMB1), a
	ld	(#_rROMB0),a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:139: for (x = 0; x < 32; x++) buf[x] = empty;
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
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:140: for (y = 0; y < 32; y++) {
	ld	b, #0x00
00108$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:141: set_bkg_tiles(0, y, 32, 1, buf);
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
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:140: for (y = 0; y < 32; y++) {
	inc	b
	ld	a, b
	sub	a, #0x20
	jr	C, 00108$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:144: for (x = 0; x < 20; x++) buf[x] = empty;
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
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:145: for (y = 0; y < 2; y++) {
	ld	b, #0x00
00112$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:146: set_win_tiles(0, y, 20, 1, buf);
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
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:145: for (y = 0; y < 2; y++) {
	inc	b
	ld	a, b
	sub	a, #0x02
	jr	C, 00112$
;c:\dev\ai\robbo-port2\gbdk\include\gb\gb.h:1739: WX_REG=x, WY_REG=y;
	ld	a, #0x07
	ldh	(_WX_REG + 0), a
	xor	a, a
	ldh	(_WY_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:151: LCDC_REG |= LCDCF_ON | LCDCF_WINON;
	ldh	a, (_LCDC_REG + 0)
	or	a, #0xa0
	ldh	(_LCDC_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:153: LYC_REG = 16;
	ld	a, #0x10
	ldh	(_LYC_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:154: STAT_REG = STATF_LYC;
	ld	a, #0x40
	ldh	(_STAT_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:155: add_LCD(lcd_isr);
	ld	de, #_lcd_isr
	call	_add_LCD
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:156: add_VBL(vbl_isr);
	ld	de, #_vbl_isr
	call	_add_VBL
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:157: set_interrupts(VBL_IFLAG | LCD_IFLAG);
	ld	a, #0x03
	call	_set_interrupts
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:158: }
	add	sp, #32
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:160: void render_level(void)
;	---------------------------------
; Function render_level
; ---------------------------------
_render_level::
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:164: dirty_count = 0;
	xor	a, a
	ld	(#_dirty_count),a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:166: for (row = 0; row < MAP_METAROWS; row++) {
	ld	e, #0x00
00102$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:167: draw_level_row(row, row);
	push	de
	ld	a, e
	call	_draw_level_row
	pop	de
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:166: for (row = 0; row < MAP_METAROWS; row++) {
	inc	e
	ld	a, e
	sub	a, #0x10
	jr	C, 00102$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:170: render_hud();
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:171: }
	jp	_render_hud
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:173: void render_hud(void)
;	---------------------------------
; Function render_hud
; ---------------------------------
_render_hud::
	add	sp, #-54
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:178: uint8_t icons[5] = {
	ldhl	sp,	#45
	ld	a, #0x22
	ld	(hl+), a
	ld	a, #0x23
	ld	(hl+), a
	ld	a, #0x24
	ld	(hl+), a
	ld	a, #0x25
	ld	(hl+), a
	ld	(hl), #0x26
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:182: for (i = 0; i < 40; i++) win[i] = empty_tile();
	ld	c, #0x00
00112$:
	ld	e, c
	ld	d, #0x00
	ld	hl, #0
	add	hl, sp
	add	hl, de
	push	hl
	push	bc
	call	_empty_tile
	pop	bc
	pop	hl
	ld	(hl), a
	inc	c
	ld	a, c
	sub	a, #0x28
	jr	C, 00112$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:184: if (screws_left > 99) values[0] = 99; else values[0] = screws_left;
	ld	a, #0x63
	ld	hl, #_screws_left
	sub	a, (hl)
	jr	NC, 00103$
	ldhl	sp,	#40
	ld	(hl), #0x63
	jr	00104$
00103$:
	ld	a, (#_screws_left)
	ldhl	sp,	#40
	ld	(hl), a
00104$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:185: if (ammo > 99) values[1] = 99; else values[1] = ammo;
	ld	a, #0x63
	ld	hl, #_ammo
	sub	a, (hl)
	jr	NC, 00106$
	ldhl	sp,	#41
	ld	(hl), #0x63
	jr	00107$
00106$:
	ld	a, (#_ammo)
	ldhl	sp,	#41
	ld	(hl), a
00107$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:186: if (keys > 99) values[2] = 99; else values[2] = keys;
	ld	a, #0x63
	ld	hl, #_keys
	sub	a, (hl)
	jr	NC, 00109$
	ldhl	sp,	#42
	ld	(hl), #0x63
	jr	00110$
00109$:
	ld	a, (#_keys)
	ldhl	sp,	#42
	ld	(hl), a
00110$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:187: values[3] = 0;
	ldhl	sp,	#43
	ld	(hl), #0x00
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:188: values[4] = level_planet;
	ld	a, (#_level_planet)
	ldhl	sp,	#44
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:190: for (g = 0; g < 5; g++) {
	ldhl	sp,	#53
	ld	(hl), #0x00
00114$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:191: const uint8_t *icon = &metatile_tiles[icons[g] * 4];
	push	hl
	ld	hl, #47
	add	hl, sp
	ld	e, l
	ld	d, h
	pop	hl
	ldhl	sp,	#53
	ld	l, (hl)
	ld	h, #0x00
	add	hl, de
	ld	c, l
	ld	b, h
	ld	a, (bc)
	ld	h, #0x00
	ld	l, a
	add	hl, hl
	add	hl, hl
	ld	de, #_metatile_tiles
	add	hl, de
	ld	c, l
	ld	b, h
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:192: uint8_t tens = (values[g] / 10) % 10;
	push	hl
	ld	hl, #42
	add	hl, sp
	ld	e, l
	ld	d, h
	pop	hl
	ldhl	sp,	#53
	ld	l, (hl)
	ld	h, #0x00
	add	hl, de
	ld	e, l
	ld	d, h
	ld	a, (de)
	ldhl	sp,	#52
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
	ldhl	sp,	#50
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:193: uint8_t ones = values[g] % 10;
	ld	(hl+), a
	inc	hl
	push	bc
	ld	e, #0x0a
	ld	a, (hl)
	call	__moduchar
	ld	a, c
	pop	bc
	ldhl	sp,	#51
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:195: x = HUD_X + g * 4;
	ld	(hl+), a
	inc	hl
	ld	a, (hl)
	add	a, a
	add	a, a
	ld	e, a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:196: win[x] = icon[0];
	push	de
	ld	d, #0x00
	ld	hl, #2
	add	hl, sp
	add	hl, de
	pop	de
	ld	a, (bc)
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:197: win[x + 1] = icon[1];
	ldhl	sp,	#52
	ld	(hl),e
	inc	e
	ld	d, #0x00
	ld	hl, #0
	add	hl, sp
	add	hl, de
	ld	e, c
	ld	d, b
	inc	de
	ld	a, (de)
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:198: win[20 + x] = icon[2];
	ldhl	sp,	#52
	ld	a, (hl)
	add	a, #0x14
	ld	e, a
	ld	d, #0x00
	ld	hl, #0
	add	hl, sp
	add	hl, de
	ld	e, c
	ld	d, b
	inc	de
	inc	de
	ld	a, (de)
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:199: win[20 + x + 1] = icon[3];
	ldhl	sp,	#52
	ld	a, (hl)
	add	a, #0x15
	ld	e, a
	ld	d, #0x00
	ld	hl, #0
	add	hl, sp
	add	hl, de
	inc	bc
	inc	bc
	inc	bc
	ld	a, (bc)
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:201: win[x + 2] = digit_tiles[tens][0];
	ldhl	sp,	#52
	ld	e, (hl)
	inc	e
	inc	e
	ld	d, #0x00
	ld	hl, #0
	add	hl, sp
	add	hl, de
	ld	e, l
	ld	d, h
	ldhl	sp,	#50
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:202: win[20 + x + 2] = digit_tiles[tens][1];
	ld	a, (hl+)
	inc	hl
	ld	b, #0x00
	add	a, a
	rl	b
	add	a, #<(_digit_tiles)
	ld	c, a
	ld	a, b
	adc	a, #>(_digit_tiles)
	ld	b, a
	ld	a, (bc)
	ld	(de), a
	ld	a, (hl)
	add	a, #0x16
	ld	e, a
	ld	d, #0x00
	ld	hl, #0
	add	hl, sp
	add	hl, de
	inc	bc
	ld	a, (bc)
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:203: win[x + 3] = digit_tiles[ones][0];
	ldhl	sp,	#52
	ld	e, (hl)
	inc	e
	inc	e
	inc	e
	ld	d, #0x00
	ld	hl, #0
	add	hl, sp
	add	hl, de
	ld	e, l
	ld	d, h
	ldhl	sp,	#51
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:204: win[20 + x + 3] = digit_tiles[ones][1];
	ld	a, (hl+)
	ld	b, #0x00
	add	a, a
	rl	b
	add	a, #<(_digit_tiles)
	ld	c, a
	ld	a, b
	adc	a, #>(_digit_tiles)
	ld	b, a
	ld	a, (bc)
	ld	(de), a
	ld	a, (hl)
	add	a, #0x17
	ld	e, a
	ld	d, #0x00
	ld	hl, #0
	add	hl, sp
	add	hl, de
	push	hl
	ld	a, l
	ldhl	sp,	#53
	ld	(hl), a
	pop	hl
	ld	a, h
	ldhl	sp,	#52
	ld	(hl-), a
	inc	bc
	ld	a, (bc)
	ld	e, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, e
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:190: for (g = 0; g < 5; g++) {
	ldhl	sp,	#53
	inc	(hl)
	ld	a, (hl)
	sub	a, #0x05
	jp	C, 00114$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:207: set_win_tiles(0, 0, 20, 2, win);
	ld	hl, #0
	add	hl, sp
	push	hl
	ld	hl, #0x214
	push	hl
	xor	a, a
	rrca
	push	af
	call	_set_win_tiles
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:208: }
	add	sp, #60
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:210: void render_pause(void)
;	---------------------------------
; Function render_pause
; ---------------------------------
_render_pause::
	add	sp, #-40
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:214: const char *msg = "PAUSED";
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:217: for (i = 0; i < 20; i++) {
	ld	c, #0x00
00103$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:218: row0[i] = empty_tile();
	ld	e, c
	ld	d, #0x00
	ld	hl, #0
	add	hl, sp
	add	hl, de
	push	hl
	push	bc
	call	_empty_tile
	pop	bc
	pop	hl
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:219: row1[i] = empty_tile();
	ld	e, c
	ld	d, #0x00
	ld	hl, #20
	add	hl, sp
	add	hl, de
	push	hl
	push	bc
	call	_empty_tile
	pop	bc
	pop	hl
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:217: for (i = 0; i < 20; i++) {
	inc	c
	ld	a, c
	sub	a, #0x14
	jr	C, 00103$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:221: for (i = 0; msg[i]; i++) {
	ld	c, #0x00
00106$:
	ld	hl, #___str_0
	ld	b, #0x00
	add	hl, bc
	ld	b, (hl)
	ld	a, b
	or	a, a
	jr	Z, 00102$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:222: row0[7 + i] = font_tiles[(uint8_t)msg[i]];
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
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:221: for (i = 0; msg[i]; i++) {
	inc	c
	jr	00106$
00102$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:224: set_win_tiles(0, 0, 20, 1, row0);
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
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:225: set_win_tiles(0, 1, 20, 1, row1);
	ld	hl, #20
	add	hl, sp
	push	hl
	ld	hl, #0x114
	push	hl
	xor	a, a
	inc	a
	push	af
	call	_set_win_tiles
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:226: }
	add	sp, #46
	ret
___str_0:
	.ascii "PAUSED"
	.db 0x00
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:228: void render_flash_set(uint8_t on)
;	---------------------------------
; Function render_flash_set
; ---------------------------------
_render_flash_set::
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:230: BGP_REG = on ? 0xC4 : 0xE4;
	or	a, a
	ld	a, #0xc4
	jr	NZ, 00104$
	ld	a, #0xe4
00104$:
	ldh	(_BGP_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:231: }
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:233: static void draw_bg_text(const char *text, uint8_t x, uint8_t y)
;	---------------------------------
; Function draw_bg_text
; ---------------------------------
_draw_bg_text:
	ld	c, e
	ld	b, d
	ld	d, a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:235: while (*text) {
00103$:
	ld	a, (bc)
	or	a, a
	jr	Z, 00106$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:236: uint8_t tile = font_tiles[(uint8_t)*text];
	add	a, #<(_font_tiles)
	ld	l, a
	ld	a, #0x00
	adc	a, #>(_font_tiles)
	ld	h, a
	ld	a, (hl)
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:237: if (tile != 0xFF) {
	cp	a, #0xff
	jr	Z, 00102$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:238: set_bkg_tile_xy(x, y, tile);
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
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:240: x++;
	inc	d
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:241: text++;
	inc	bc
	jr	00103$
00106$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:243: }
	pop	hl
	inc	sp
	jp	(hl)
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:245: void render_victory(void)
;	---------------------------------
; Function render_victory
; ---------------------------------
_render_victory::
	add	sp, #-32
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:249: uint8_t empty = empty_tile();
	call	_empty_tile
	ld	e, a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:251: BGP_REG = 0xE4;
	ld	a, #0xe4
	ldh	(_BGP_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:252: SCX_REG = 0;
	xor	a, a
	ldh	(_SCX_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:253: SCY_REG = 0;
	xor	a, a
	ldh	(_SCY_REG + 0), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:255: for (x = 0; x < 32; x++) buf[x] = empty;
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
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:256: for (y = 0; y < 32; y++) {
	ld	d, #0x00
00106$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:257: set_bkg_tiles(0, y, 32, 1, buf);
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
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:256: for (y = 0; y < 32; y++) {
	inc	d
	ld	a, d
	sub	a, #0x20
	jr	C, 00106$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:259: for (x = 0; x < 20; x++) buf[x] = empty;
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
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:257: set_bkg_tiles(0, y, 32, 1, buf);
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:260: set_win_tiles(0, 0, 20, 1, buf);
	push	bc
	ld	hl, #0x114
	push	hl
	xor	a, a
	rrca
	push	af
	call	_set_win_tiles
	add	sp, #6
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:261: set_win_tiles(0, 1, 20, 1, buf);
	push	bc
	ld	hl, #0x114
	push	hl
	xor	a, a
	inc	a
	push	af
	call	_set_win_tiles
	add	sp, #6
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:263: draw_bg_text("CONGRATULATIONS", 2, 7);
	ld	a, #0x07
	push	af
	inc	sp
	ld	a, #0x02
	ld	de, #___str_1
	call	_draw_bg_text
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:264: draw_bg_text("YOU WIN", 6, 9);
	ld	a, #0x09
	push	af
	inc	sp
	ld	a, #0x06
	ld	de, #___str_2
	call	_draw_bg_text
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:265: draw_bg_text("PRESS START", 4, 11);
	ld	a, #0x0b
	push	af
	inc	sp
	ld	a, #0x04
	ld	de, #___str_3
	call	_draw_bg_text
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:266: }
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
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:268: void render_sync_rows(void)
;	---------------------------------
; Function render_sync_rows
; ---------------------------------
_render_sync_rows::
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:271: for (i = 0; i < VIEW_ROWS; i++) {
	ld	c, #0x00
00104$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:272: uint8_t level_y = cam_y + i;
	ld	a, (#_cam_y)
	add	a, c
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:273: uint8_t map_row = level_y & (MAP_METAROWS - 1);
	ld	b, a
	and	a, #0x0f
	ld	e, a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:274: if (map_row_level[map_row] != level_y) {
	ld	hl, #_map_row_level
	ld	d, #0x00
	add	hl, de
	ld	a, (hl)
	sub	a, b
	jr	Z, 00105$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:275: draw_level_row(level_y, map_row);
	push	bc
	ld	a, b
	call	_draw_level_row
	pop	bc
00105$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:271: for (i = 0; i < VIEW_ROWS; i++) {
	inc	c
	ld	a, c
	sub	a, #0x08
	jr	C, 00104$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:278: }
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:280: static void draw_cell_now(uint8_t x, uint8_t y)
;	---------------------------------
; Function draw_cell_now
; ---------------------------------
_draw_cell_now:
	add	sp, #-3
	ldhl	sp,	#2
	ld	(hl), a
	ld	c, e
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:282: uint8_t map_row = y & (MAP_METAROWS - 1);
	ld	a, c
	and	a, #0x0f
	ld	e, a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:285: if (map_row_level[map_row] != y) return;
	ld	hl, #_map_row_level
	ld	d, #0x00
	add	hl, de
	ld	a, (hl)
	sub	a, c
	jr	NZ, 00103$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:286: idx = (uint16_t)y * MAP_W + x;
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
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:288: x * 2, map_row * 2);
	ld	a, e
	add	a, a
	ldhl	sp,	#0
	ld	(hl+), a
	inc	hl
	ld	a, (hl-)
	add	a, a
	ld	(hl), a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:287: draw_metatile(render_metatile_for_cell(map_type[idx], map_extra[idx]),
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
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:289: }
	add	sp, #3
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:291: void render_cell(uint8_t x, uint8_t y)
;	---------------------------------
; Function render_cell
; ---------------------------------
_render_cell::
	dec	sp
	ld	c, a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:294: uint16_t idx = ((uint16_t)y << 8) | x;
	ld	b, e
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:296: for (i = 0; i < dirty_count; i++) {
	ldhl	sp,	#0
	ld	(hl), #0x00
00107$:
	ldhl	sp,	#0
	ld	a, (hl)
	ld	hl, #_dirty_count
	sub	a, (hl)
	jr	NC, 00103$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:297: if (dirty_cells[i] == idx) return;
	ldhl	sp,	#0
	ld	e, (hl)
	xor	a, a
	ld	l, e
	ld	h, a
	add	hl, hl
	ld	de, #_dirty_cells
	add	hl, de
	ld	a,	(hl+)
	ld	h, (hl)
	sub	a, c
	jr	NZ, 00108$
	ld	a, h
	sub	a, b
	jr	Z, 00109$
00108$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:296: for (i = 0; i < dirty_count; i++) {
	ldhl	sp,	#0
	inc	(hl)
	jr	00107$
00103$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:299: if (dirty_count < MAX_DIRTY) {
	ld	hl, #_dirty_count
	ld	a, (hl)
	sub	a, #0x40
	jr	NC, 00109$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:300: dirty_cells[dirty_count++] = idx;
	ld	e, (hl)
	inc	(hl)
	ld	l, e
	ld	h, #0x00
	add	hl, hl
	ld	de, #_dirty_cells
	add	hl, de
	ld	a, c
	ld	(hl+), a
	ld	(hl), b
00109$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:302: }
	inc	sp
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:304: void render_flush_cells(void)
;	---------------------------------
; Function render_flush_cells
; ---------------------------------
_render_flush_cells::
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:307: for (i = 0; i < dirty_count; i++) {
	ld	c, #0x00
00103$:
	ld	a, c
	ld	hl, #_dirty_count
	sub	a, (hl)
	jr	NC, 00101$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:308: draw_cell_now(dirty_cells[i] & 0xFF, dirty_cells[i] >> 8);
	ld	l, c
	xor	a, a
	ld	h, a
	add	hl, hl
	ld	de, #_dirty_cells
	add	hl, de
	ld	a, (hl+)
	ld	b, (hl)
	ld	e, b
	push	bc
	call	_draw_cell_now
	pop	bc
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:307: for (i = 0; i < dirty_count; i++) {
	inc	c
	jr	00103$
00101$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:310: dirty_count = 0;
	xor	a, a
	ld	(#_dirty_count),a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:311: }
	ret
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:313: void render_camera(void)
;	---------------------------------
; Function render_camera
; ---------------------------------
_render_camera::
	add	sp, #-7
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:316: uint8_t max_y = (level_height > VIEW_ROWS) ? (level_height - VIEW_ROWS) : 0;
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
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:318: if (cam_override) {
	ld	a, (#_cam_override)
	or	a, a
	jr	Z, 00114$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:320: if (cam_pan_timer < 2) {
	ld	hl, #_cam_pan_timer
	ld	a, (hl)
	sub	a, #0x02
	jr	NC, 00102$
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:321: cam_pan_timer++;
	inc	(hl)
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:322: return;
	jp	00129$
00102$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:324: cam_pan_timer = 0;
	xor	a, a
	ld	(#_cam_pan_timer),a
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:326: if (cam_x < cam_target_x) cam_x++;
	ld	a, (#_cam_x)
	ld	hl, #_cam_target_x
	sub	a, (hl)
	jr	NC, 00106$
	ld	hl, #_cam_x
	inc	(hl)
	jr	00107$
00106$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:327: else if (cam_x > cam_target_x) cam_x--;
	ld	a, (#_cam_target_x)
	ld	hl, #_cam_x
	sub	a, (hl)
	jr	NC, 00107$
	dec	(hl)
00107$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:328: if (cam_y < cam_target_y) cam_y++;
	ld	a, (#_cam_y)
	ld	hl, #_cam_target_y
	sub	a, (hl)
	jr	NC, 00111$
	ld	hl, #_cam_y
	inc	(hl)
	jp	00129$
00111$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:329: else if (cam_y > cam_target_y) cam_y--;
	ld	a, (#_cam_target_y)
	ld	hl, #_cam_y
	sub	a, (hl)
	jp	NC, 00129$
	dec	(hl)
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:330: return;
	jp	00129$
00114$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:333: if (robbo_x < cam_x + 2) {
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
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:334: cam_x = (robbo_x >= 2) ? (robbo_x - 2) : 0;
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
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:335: } else if (robbo_x > cam_x + 7) {
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
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:336: cam_x = robbo_x - 7;
	ld	a, (_robbo_x)
	add	a, #0xf9
	ld	(#_cam_x),a
00119$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:338: if (cam_x > max_x) cam_x = max_x;
	ld	a, #0x06
	ld	hl, #_cam_x
	sub	a, (hl)
	jr	NC, 00121$
	ld	(hl), #0x06
00121$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:340: if (robbo_y < cam_y + 2) {
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
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:341: cam_y = (robbo_y >= 2) ? (robbo_y - 2) : 0;
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
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:342: } else if (robbo_y > cam_y + 5) {
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
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:343: cam_y = robbo_y - 5;
	ld	a, (_robbo_y)
	add	a, #0xfb
	ld	(#_cam_y),a
00126$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:345: if (cam_y > max_y) cam_y = max_y;
	ldhl	sp,	#0
	ld	a, (hl)
	ld	hl, #_cam_y
	sub	a, (hl)
	jr	NC, 00129$
	ldhl	sp,	#0
	ld	a, (hl)
	ld	(#_cam_y),a
00129$:
;C:\dev\AI\robbo-port2\gb\src\gb\render.c:346: }
	add	sp, #7
	ret
	.area _CODE
	.area _INITIALIZER
	.area _CABS (ABS)
