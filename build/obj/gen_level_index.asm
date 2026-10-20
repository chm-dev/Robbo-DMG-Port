;--------------------------------------------------------
; File Created by SDCC : free open source ISO C Compiler
; Version 4.5.1 #15267 (MINGW64)
;--------------------------------------------------------
	.module level_index
	
;--------------------------------------------------------
; Public variables in this module
;--------------------------------------------------------
	.globl b_load_level_56
	.globl _load_level_56
	.globl b_load_level_55
	.globl _load_level_55
	.globl b_load_level_54
	.globl _load_level_54
	.globl b_load_level_53
	.globl _load_level_53
	.globl b_load_level_52
	.globl _load_level_52
	.globl b_load_level_51
	.globl _load_level_51
	.globl b_load_level_50
	.globl _load_level_50
	.globl b_load_level_49
	.globl _load_level_49
	.globl b_load_level_48
	.globl _load_level_48
	.globl b_load_level_47
	.globl _load_level_47
	.globl b_load_level_46
	.globl _load_level_46
	.globl b_load_level_45
	.globl _load_level_45
	.globl b_load_level_44
	.globl _load_level_44
	.globl b_load_level_43
	.globl _load_level_43
	.globl b_load_level_42
	.globl _load_level_42
	.globl b_load_level_41
	.globl _load_level_41
	.globl b_load_level_40
	.globl _load_level_40
	.globl b_load_level_39
	.globl _load_level_39
	.globl b_load_level_38
	.globl _load_level_38
	.globl b_load_level_37
	.globl _load_level_37
	.globl b_load_level_36
	.globl _load_level_36
	.globl b_load_level_35
	.globl _load_level_35
	.globl b_load_level_34
	.globl _load_level_34
	.globl b_load_level_33
	.globl _load_level_33
	.globl b_load_level_32
	.globl _load_level_32
	.globl b_load_level_31
	.globl _load_level_31
	.globl b_load_level_30
	.globl _load_level_30
	.globl b_load_level_29
	.globl _load_level_29
	.globl b_load_level_28
	.globl _load_level_28
	.globl b_load_level_27
	.globl _load_level_27
	.globl b_load_level_26
	.globl _load_level_26
	.globl b_load_level_25
	.globl _load_level_25
	.globl b_load_level_24
	.globl _load_level_24
	.globl b_load_level_23
	.globl _load_level_23
	.globl b_load_level_22
	.globl _load_level_22
	.globl b_load_level_21
	.globl _load_level_21
	.globl b_load_level_20
	.globl _load_level_20
	.globl b_load_level_19
	.globl _load_level_19
	.globl b_load_level_18
	.globl _load_level_18
	.globl b_load_level_17
	.globl _load_level_17
	.globl b_load_level_16
	.globl _load_level_16
	.globl b_load_level_15
	.globl _load_level_15
	.globl b_load_level_14
	.globl _load_level_14
	.globl b_load_level_13
	.globl _load_level_13
	.globl b_load_level_12
	.globl _load_level_12
	.globl b_load_level_11
	.globl _load_level_11
	.globl b_load_level_10
	.globl _load_level_10
	.globl b_load_level_09
	.globl _load_level_09
	.globl b_load_level_08
	.globl _load_level_08
	.globl b_load_level_07
	.globl _load_level_07
	.globl b_load_level_06
	.globl _load_level_06
	.globl b_load_level_05
	.globl _load_level_05
	.globl b_load_level_04
	.globl _load_level_04
	.globl b_load_level_03
	.globl _load_level_03
	.globl b_load_level_02
	.globl _load_level_02
	.globl b_load_level_01
	.globl _load_level_01
	.globl _load_level_data
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
	.area _CODE
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:4: void load_level_data(uint8_t level)
;	---------------------------------
; Function load_level_data
; ---------------------------------
_load_level_data::
	ld	c, a
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:6: switch (level) {
	ld	a, #0x38
	sub	a, c
	ret	C
	ld	b, #0x00
	ld	hl, #00168$
	add	hl, bc
	add	hl, bc
	ld	c, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, c
	jp	(hl)
00168$:
	.dw	00159$
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
	.dw	00112$
	.dw	00113$
	.dw	00114$
	.dw	00115$
	.dw	00116$
	.dw	00117$
	.dw	00118$
	.dw	00119$
	.dw	00120$
	.dw	00121$
	.dw	00122$
	.dw	00123$
	.dw	00124$
	.dw	00125$
	.dw	00126$
	.dw	00127$
	.dw	00128$
	.dw	00129$
	.dw	00130$
	.dw	00131$
	.dw	00132$
	.dw	00133$
	.dw	00134$
	.dw	00135$
	.dw	00136$
	.dw	00137$
	.dw	00138$
	.dw	00139$
	.dw	00140$
	.dw	00141$
	.dw	00142$
	.dw	00143$
	.dw	00144$
	.dw	00145$
	.dw	00146$
	.dw	00147$
	.dw	00148$
	.dw	00149$
	.dw	00150$
	.dw	00151$
	.dw	00152$
	.dw	00153$
	.dw	00154$
	.dw	00155$
	.dw	00156$
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:7: case 1: load_level_01(); break;
00101$:
	ld	e, #b_load_level_01
	ld	hl, #_load_level_01
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:8: case 2: load_level_02(); break;
00102$:
	ld	e, #b_load_level_02
	ld	hl, #_load_level_02
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:9: case 3: load_level_03(); break;
00103$:
	ld	e, #b_load_level_03
	ld	hl, #_load_level_03
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:10: case 4: load_level_04(); break;
00104$:
	ld	e, #b_load_level_04
	ld	hl, #_load_level_04
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:11: case 5: load_level_05(); break;
00105$:
	ld	e, #b_load_level_05
	ld	hl, #_load_level_05
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:12: case 6: load_level_06(); break;
00106$:
	ld	e, #b_load_level_06
	ld	hl, #_load_level_06
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:13: case 7: load_level_07(); break;
00107$:
	ld	e, #b_load_level_07
	ld	hl, #_load_level_07
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:14: case 8: load_level_08(); break;
00108$:
	ld	e, #b_load_level_08
	ld	hl, #_load_level_08
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:15: case 9: load_level_09(); break;
00109$:
	ld	e, #b_load_level_09
	ld	hl, #_load_level_09
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:16: case 10: load_level_10(); break;
00110$:
	ld	e, #b_load_level_10
	ld	hl, #_load_level_10
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:17: case 11: load_level_11(); break;
00111$:
	ld	e, #b_load_level_11
	ld	hl, #_load_level_11
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:18: case 12: load_level_12(); break;
00112$:
	ld	e, #b_load_level_12
	ld	hl, #_load_level_12
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:19: case 13: load_level_13(); break;
00113$:
	ld	e, #b_load_level_13
	ld	hl, #_load_level_13
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:20: case 14: load_level_14(); break;
00114$:
	ld	e, #b_load_level_14
	ld	hl, #_load_level_14
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:21: case 15: load_level_15(); break;
00115$:
	ld	e, #b_load_level_15
	ld	hl, #_load_level_15
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:22: case 16: load_level_16(); break;
00116$:
	ld	e, #b_load_level_16
	ld	hl, #_load_level_16
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:23: case 17: load_level_17(); break;
00117$:
	ld	e, #b_load_level_17
	ld	hl, #_load_level_17
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:24: case 18: load_level_18(); break;
00118$:
	ld	e, #b_load_level_18
	ld	hl, #_load_level_18
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:25: case 19: load_level_19(); break;
00119$:
	ld	e, #b_load_level_19
	ld	hl, #_load_level_19
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:26: case 20: load_level_20(); break;
00120$:
	ld	e, #b_load_level_20
	ld	hl, #_load_level_20
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:27: case 21: load_level_21(); break;
00121$:
	ld	e, #b_load_level_21
	ld	hl, #_load_level_21
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:28: case 22: load_level_22(); break;
00122$:
	ld	e, #b_load_level_22
	ld	hl, #_load_level_22
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:29: case 23: load_level_23(); break;
00123$:
	ld	e, #b_load_level_23
	ld	hl, #_load_level_23
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:30: case 24: load_level_24(); break;
00124$:
	ld	e, #b_load_level_24
	ld	hl, #_load_level_24
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:31: case 25: load_level_25(); break;
00125$:
	ld	e, #b_load_level_25
	ld	hl, #_load_level_25
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:32: case 26: load_level_26(); break;
00126$:
	ld	e, #b_load_level_26
	ld	hl, #_load_level_26
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:33: case 27: load_level_27(); break;
00127$:
	ld	e, #b_load_level_27
	ld	hl, #_load_level_27
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:34: case 28: load_level_28(); break;
00128$:
	ld	e, #b_load_level_28
	ld	hl, #_load_level_28
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:35: case 29: load_level_29(); break;
00129$:
	ld	e, #b_load_level_29
	ld	hl, #_load_level_29
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:36: case 30: load_level_30(); break;
00130$:
	ld	e, #b_load_level_30
	ld	hl, #_load_level_30
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:37: case 31: load_level_31(); break;
00131$:
	ld	e, #b_load_level_31
	ld	hl, #_load_level_31
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:38: case 32: load_level_32(); break;
00132$:
	ld	e, #b_load_level_32
	ld	hl, #_load_level_32
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:39: case 33: load_level_33(); break;
00133$:
	ld	e, #b_load_level_33
	ld	hl, #_load_level_33
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:40: case 34: load_level_34(); break;
00134$:
	ld	e, #b_load_level_34
	ld	hl, #_load_level_34
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:41: case 35: load_level_35(); break;
00135$:
	ld	e, #b_load_level_35
	ld	hl, #_load_level_35
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:42: case 36: load_level_36(); break;
00136$:
	ld	e, #b_load_level_36
	ld	hl, #_load_level_36
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:43: case 37: load_level_37(); break;
00137$:
	ld	e, #b_load_level_37
	ld	hl, #_load_level_37
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:44: case 38: load_level_38(); break;
00138$:
	ld	e, #b_load_level_38
	ld	hl, #_load_level_38
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:45: case 39: load_level_39(); break;
00139$:
	ld	e, #b_load_level_39
	ld	hl, #_load_level_39
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:46: case 40: load_level_40(); break;
00140$:
	ld	e, #b_load_level_40
	ld	hl, #_load_level_40
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:47: case 41: load_level_41(); break;
00141$:
	ld	e, #b_load_level_41
	ld	hl, #_load_level_41
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:48: case 42: load_level_42(); break;
00142$:
	ld	e, #b_load_level_42
	ld	hl, #_load_level_42
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:49: case 43: load_level_43(); break;
00143$:
	ld	e, #b_load_level_43
	ld	hl, #_load_level_43
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:50: case 44: load_level_44(); break;
00144$:
	ld	e, #b_load_level_44
	ld	hl, #_load_level_44
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:51: case 45: load_level_45(); break;
00145$:
	ld	e, #b_load_level_45
	ld	hl, #_load_level_45
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:52: case 46: load_level_46(); break;
00146$:
	ld	e, #b_load_level_46
	ld	hl, #_load_level_46
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:53: case 47: load_level_47(); break;
00147$:
	ld	e, #b_load_level_47
	ld	hl, #_load_level_47
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:54: case 48: load_level_48(); break;
00148$:
	ld	e, #b_load_level_48
	ld	hl, #_load_level_48
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:55: case 49: load_level_49(); break;
00149$:
	ld	e, #b_load_level_49
	ld	hl, #_load_level_49
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:56: case 50: load_level_50(); break;
00150$:
	ld	e, #b_load_level_50
	ld	hl, #_load_level_50
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:57: case 51: load_level_51(); break;
00151$:
	ld	e, #b_load_level_51
	ld	hl, #_load_level_51
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:58: case 52: load_level_52(); break;
00152$:
	ld	e, #b_load_level_52
	ld	hl, #_load_level_52
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:59: case 53: load_level_53(); break;
00153$:
	ld	e, #b_load_level_53
	ld	hl, #_load_level_53
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:60: case 54: load_level_54(); break;
00154$:
	ld	e, #b_load_level_54
	ld	hl, #_load_level_54
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:61: case 55: load_level_55(); break;
00155$:
	ld	e, #b_load_level_55
	ld	hl, #_load_level_55
	jp  ___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:62: case 56: load_level_56(); break;
00156$:
	ld	e, #b_load_level_56
	ld	hl, #_load_level_56
	call	___sdcc_bcall_ehl
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:64: }
00159$:
;C:\dev\AI\robbo-port2\gb\src\gen\level_index.c:65: }
	ret
	.area _CODE
	.area _INITIALIZER
	.area _CABS (ABS)
