/*
 * NES Phase-4 ending test (MesenCE-MCP, Streamable HTTP).
 *
 * Start Mesen with the MCP server before running this:
 *   MesenCE-MCP\MesenCE-MCP-Windows.exe --mcp --mcp-port=9100 --enableStdout roms\robbo-debug.nes
 *
 * The ending is the phase-4 screen that used to be a grayscale stopgap.  This
 * checks the final contract:
 *   - the real NES scene / ground / text palettes are installed (no more
 *     grey ramp) and every slot keeps the shared backdrop black,
 *   - the 20x18 GBC scene is centred on the 32x30 NES screen, the surround is
 *     cleared to the sky tile, the star/ground tiles land on the right cells,
 *     and the attribute map is scene/ground/text per 16x16 cell,
 *   - Robbo's sprites carry the centred +48 px offset, stay on the ground row
 *     and use the sprite priority bit,
 *   - both text pages fade in through the NES palette (entry 1 ink, entry 2
 *     hatch), draw their hatched border + inverted heading band, and use the
 *     text slot,
 *   - the closing wipe is a tile-row curtain (band tile 109, black behind it)
 *     instead of the GB window slide,
 *   - returning to the title and starting level 1 still works.
 *
 * Uses the debug ROM's START+SELECT ending preview.
 *
 * Run: node gb/tests/nes_phase4.mjs
 */
import fs from 'node:fs';
import path from 'node:path';

const MCP_URL = process.env.MESEN_MCP_URL || 'http://localhost:9100/mcp';
const ROM = path.resolve('roms/robbo-debug.nes');
const NOI = path.resolve('roms/robbo-debug-nes.noi');
const ENDING_HDR = path.resolve('gb/src/gen/ending_data.h');

let sessionId = null;
let nextId = 1;

function symbolsFromNoi(file) {
    const out = {};
    for (const line of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
        const m = line.match(/^DEF (\S+) (0x[0-9A-Fa-f]+)$/);
        if (m) out[m[1]] = parseInt(m[2], 16);
    }
    return out;
}

function endingConstants() {
    const text = fs.readFileSync(ENDING_HDR, 'utf8');
    const out = {};
    for (const m of text.matchAll(/#define (ENDING_\w+) (\d+)/g)) {
        out[m[1]] = parseInt(m[2], 10);
    }
    return out;
}

function parseSse(text) {
    const out = [];
    for (const block of text.split(/\r?\n\r?\n/)) {
        const data = block.split(/\r?\n/)
            .filter(line => line.startsWith('data:'))
            .map(line => line.slice(5).trimStart())
            .join('\n');
        if (data) out.push(JSON.parse(data));
    }
    return out;
}

async function post(body, useSession = true) {
    const headers = {
        'Content-Type': 'application/json',
        Accept: 'application/json, text/event-stream',
    };
    if (useSession && sessionId) headers['Mcp-Session-Id'] = sessionId;
    const res = await fetch(MCP_URL, { method: 'POST', headers, body: JSON.stringify(body) });
    const text = await res.text();
    const sid = res.headers.get('mcp-session-id');
    if (sid) sessionId = sid;
    if (!res.ok) throw new Error(`MCP HTTP ${res.status}: ${text}`);
    return parseSse(text);
}

async function init() {
    await post({
        jsonrpc: '2.0', id: nextId++, method: 'initialize',
        params: {
            protocolVersion: '2024-11-05',
            capabilities: {},
            clientInfo: { name: 'robbo-nes-phase4', version: '1.0' },
        },
    }, false);
    await post({ jsonrpc: '2.0', method: 'notifications/initialized', params: {} });
}

async function callTool(name, args = {}) {
    const messages = await post({
        jsonrpc: '2.0', id: nextId++, method: 'tools/call',
        params: { name, arguments: args },
    });
    const msg = messages.find(m => m && m.result);
    if (!msg) {
        const err = messages.find(m => m && m.error);
        throw new Error(`${name}: ${err ? err.error.message : 'no result'}`);
    }
    return msg.result.content?.filter(c => c.type === 'text').map(c => c.text).join('\n') ?? '';
}

async function readBytes(addr, length, type = 'NesMemory') {
    const text = await callTool('mesen_read_memory', {
        address: `0x${addr.toString(16)}`,
        length,
        memoryType: type,
    });
    return text.trim().split(/\s+/).filter(Boolean).map(h => parseInt(h, 16));
}

const sleep = ms => new Promise(r => setTimeout(r, ms));
let failures = 0;

function check(name, ok, detail = '') {
    console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? '  ' + detail : ''}`);
    if (!ok) failures++;
}

const arrEq = (a, b) => a.length === b.length && a.every((v, i) => v === b[i]);
const hex = a => a.map(v => v.toString(16).padStart(2, '0')).join(' ');

/* Optional visual capture: NES_SHOTS=1 node gb/tests/nes_phase4.mjs */
const SHOTS = process.env.NES_SHOTS === '1';

async function shot(name) {
    if (!SHOTS) return;
    const dir = path.resolve('gb/tests/screenshots');
    fs.mkdirSync(dir, { recursive: true });
    await callTool('mesen_take_screenshot', { outputFile: path.join(dir, name) });
}

async function press(buttons, holdMs = 200) {
    await callTool('mesen_input_override', { action: 'set', port: 0, buttons });
    await sleep(holdMs);
    await callTool('mesen_input_override', { action: 'set', port: 0, buttons: '' });
    await sleep(150);
}

/* 16x16 attribute slot for a tile coordinate in nametable 0. */
function attrSlot(nt, tx, ty) {
    const cellX = tx >> 1;
    const cellY = ty >> 1;
    const byte = nt[0x3C0 + (cellY >> 1) * 8 + (cellX >> 1)];
    const shift = ((cellY & 1) ? 4 : 0) + ((cellX & 1) ? 2 : 0);
    return (byte >> shift) & 3;
}

async function readPalette() {
    const pal = await readBytes(0, 32, 'NesPaletteRam');
    return {
        bg: [pal.slice(0, 4), pal.slice(4, 8), pal.slice(8, 12), pal.slice(12, 16)],
        sprite: [pal.slice(16, 20), pal.slice(20, 24), pal.slice(24, 28), pal.slice(28, 32)],
    };
}

async function readScreen() {
    return readBytes(0, 2048, 'NesNametableRam');
}

async function waitFor(fn, label, timeoutMs) {
    const start = Date.now();
    while (Date.now() - start < timeoutMs) {
        if (await fn()) return true;
        await sleep(120);
    }
    console.log(`      (timeout waiting for ${label})`);
    return false;
}

async function main() {
    if (!fs.existsSync(ROM)) throw new Error(`Missing ${ROM}`);
    if (!fs.existsSync(NOI)) throw new Error(`Missing ${NOI}`);
    const sym = symbolsFromNoi(NOI);
    const E = endingConstants();

    /* Centring: (32 - 20) / 2 = 6 tiles, (30 - 18) / 2 = 6 tiles. */
    const OX = (32 - E.ENDING_MSG_COLS) / 2;
    const OY = (30 - E.ENDING_MSG_ROWS) / 2;
    check('ending grid is 20x18 and centres on 6,6',
        E.ENDING_MSG_COLS === 20 && E.ENDING_MSG_ROWS === 18 && OX === 6 && OY === 6,
        `${E.ENDING_MSG_COLS}x${E.ENDING_MSG_ROWS} at ${OX},${OY}`);

    const BLANK = E.ENDING_BLANK_TILE;
    const BLACK = E.ENDING_BLACK_TILE;
    const PATTERN = E.ENDING_PATTERN_TILE;
    const WIPE = E.ENDING_WIPE_TILE;
    const FONT = E.ENDING_FONT;
    const FONT_INV = E.ENDING_FONT_INVERSE;
    const GLYPHS = E.ENDING_GLYPH_COUNT;

    await init();
    await callTool('mesen_load_rom', { filepath: ROM });
    await sleep(700);
    await callTool('mesen_write_memory', {
        address: '0x7FF0',
        hexData: '00000000000000000000000000000000',
        memoryType: 'NesMemory',
    });
    await callTool('mesen_reset', { type: 'hard' });
    await sleep(1200);

    /* Boot title -> level 1 so the ending is triggered from gameplay. */
    await press('Start', 240);
    check('level 1 starts', await waitFor(async () =>
        (await readBytes(sym._level_planet, 1))[0] === 1, 'level 1', 12000));
    await waitFor(async () => (await readBytes(sym._intro_active, 1))[0] === 0,
        'intro', 12000);
    await sleep(300);

    /* Debug START+SELECT ending preview. */
    await press('Start,Select', 240);
    check('ending starts', await waitFor(async () =>
        (await readBytes(sym._ending_active, 1))[0] === 1, 'ending', 8000));

    // --- Scene palettes ---------------------------------------------------
    /* Atari CONGR COLS+6: COLBK $32, COLPF0 $C8, COLPF1 $0C (light grey),
     * COLPF2 $74 (blue), quantised to 2C02 colours, with the COLPF0 role
     * recoloured from olive-green to brown (NES_END_SOIL). */
    const ATARI_SCENE = [0x0D, 0x17, 0x3D, 0x12];
    const scenePal = await readPalette();
    check('ending: scene palette = backdrop, COLPF0, COLPF1, COLPF2',
        arrEq(scenePal.bg[0], ATARI_SCENE), hex(scenePal.bg[0]));
    check('ending: text palette = backdrop, white, grey, black',
        arrEq(scenePal.bg[2], [0x0D, 0x30, 0x00, 0x0D]), hex(scenePal.bg[2]));
    check('ending: shared backdrop is black in every slot',
        scenePal.bg.every(p => p[0] === 0x0D) && scenePal.bg[3][0] === 0x0D);
    check('ending: sprite grey ramp', scenePal.sprite.every(p =>
        arrEq(p.slice(1), [0x00, 0x10, 0x30])), hex(scenePal.sprite[0]));
    check('ending: HUD split is parked (no stale scanline write)',
        (await readBytes(sym._nes_hud_enabled, 1))[0] === 0);

    // --- Scene geometry ---------------------------------------------------
    let nt = await readScreen();
    let surroundBad = 0;
    for (let y = 0; y < 30; y++) {
        for (let x = 0; x < 32; x++) {
            const inScene = x >= OX && x < OX + 20 && y >= OY && y < OY + 18;
            if (inScene) continue;
            if (nt[y * 32 + x] !== BLANK) surroundBad++;
        }
    }
    check('ending: screen surround cleared to the sky tile', surroundBad === 0,
        `bad=${surroundBad}`);

    /* Stars are single tiles at their scene coordinate. */
    const stars = [
        [0, 0], [16, 0], [10, 1], [18, 1], [10, 2], [15, 3], [17, 4], [3, 4],
        [11, 8], [15, 8], [3, 9], [7, 10], [5, 2], [8, 5], [0, 6], [1, 12],
        [16, 12],
    ];
    let starBad = 0;
    for (const [sx, sy] of stars) {
        if (nt[(OY + sy) * 32 + OX + sx] !== E.ENDING_STAR + 1) starBad++;
    }
    check('ending: all 17 stars centred on the scene grid', starBad === 0,
        `bad=${starBad}`);

    const groundRow = OY + E.ENDING_GROUND_ROW;
    let groundBad = 0;
    for (let x = 0; x < 20; x++) {
        const expect0 = E.ENDING_GROUND + (x & 1);
        if (nt[groundRow * 32 + OX + x] !== expect0) groundBad++;
        if (nt[(groundRow + 1) * 32 + OX + x] !== expect0 + 2) groundBad++;
    }
    check('ending: ground metatiles under the scene', groundBad === 0,
        `bad=${groundBad}`);

    // --- Scene attributes -------------------------------------------------
    /* The Atari ending uses one colour set for sky, ship and ground, so the
     * whole screen (scene included) shares the scene slot. */
    let attrBad = 0;
    for (let cy = 0; cy < 15; cy++) {
        for (let cx = 0; cx < 16; cx++) {
            if (attrSlot(nt, cx * 2, cy * 2) !== 0) attrBad++;
        }
    }
    check('ending: every 16x16 cell uses the scene slot', attrBad === 0,
        `bad=${attrBad}`);

    // --- Robbo sprites ----------------------------------------------------
    /* Robbo's 2x2 block stands on the ground surface: the sprite top row is
     * scene row ENDING_FEET_ROW, and NES OAM y is one line above it. */
    const FEET_Y = (OY + E.ENDING_FEET_ROW) * 8;
    const spritesOk = await waitFor(async () => {
        const oam = await readBytes(0, 256, 'NesSpriteRam');
        for (let i = 0; i < 40; i++) {
            const y = oam[i * 4];
            const tile = oam[i * 4 + 1];
            if (tile >= 128 && tile < 168 &&
                (y === FEET_Y - 1 || y === FEET_Y + 8 - 1)) return true;
        }
        return false;
    }, 'robbo sprites', 12000);
    check('ending: Robbo sprites stand on the ground surface', spritesOk);
    /* Wait for the ship to land so the visual capture shows the full scene. */
    await waitFor(async () => {
        const n = await readScreen();
        for (let y = OY; y < OY + E.ENDING_GROUND_ROW; y++) {
            for (let x = OX; x < OX + 20; x++) {
                if (n[y * 32 + x] === E.ENDING_SHIPL) return true;
            }
        }
        return false;
    }, 'ship', 12000);
    await shot('nes-ending-scene.png');

    const oam = await readBytes(0, 256, 'NesSpriteRam');
    let quad = null;
    for (let i = 0; i + 3 < 40; i += 4) {
        const t0 = oam[i * 4 + 1];
        if (t0 >= 128 && t0 < 168) {
            quad = [oam.slice(i * 4, i * 4 + 4), oam.slice((i + 1) * 4, (i + 1) * 4 + 4),
                oam.slice((i + 2) * 4, (i + 2) * 4 + 4), oam.slice((i + 3) * 4, (i + 3) * 4 + 4)];
            break;
        }
    }
    if (quad) {
        const [s0, s1, s2, s3] = quad;
        check('ending: Robbo is a 2x2 sprite block',
            s1[3] === s0[3] + 8 && s2[3] === s0[3] && s3[3] === s0[3] + 8 &&
            s2[0] === s0[0] + 8 && s3[0] === s0[0] + 8,
            `x=${s0[3]},${s1[3]} y=${s0[0]},${s2[0]}`);
        check('ending: sprite X carries the +48 px centring (or is walking)',
            s0[3] >= OX * 8 && s0[3] + 8 <= (OX + 20) * 8,
            `x=${s0[3]}`);
        check('ending: sprite block sits above the ground, not inside it',
            s0[0] === FEET_Y - 1,
            `y=${s0[0]} expect=${FEET_Y - 1} (ground top=${(OY + E.ENDING_GROUND_ROW) * 8})`);
        check('ending: Robbo sprites use the priority bit',
            quad.every(q => (q[2] & 0x20) !== 0), hex(quad.map(q => q[2])));
    } else {
        check('ending: Robbo sprite block found', false);
    }

    // --- Text page 0 ------------------------------------------------------
    /* The departure calls robbo_at(HIDDEN): NES must park the block at OAM
     * y >= 240, because GB-style (0,0) would draw it at the top-left corner. */
    let sawHidden = false;
    check('ending: text page 0 appears', await waitFor(async () => {
        const o = await readBytes(0, 256, 'NesSpriteRam');
        if (!sawHidden && o[0] >= 240 && o[4] >= 240 && o[8] >= 240 && o[12] >= 240) {
            sawHidden = true;
        }
        const n = await readScreen();
        return n[(OY + 1) * 32 + OX] === PATTERN;
    }, 'text page', 30000));
    check('ending: Robbo hides off-screen for the departure', sawHidden);

    check('ending: page fade completes', await waitFor(async () => {
        const p = await readPalette();
        return p.bg[2][1] === 0x30 && p.bg[2][2] === 0x10;
    }, 'fade', 6000), hex((await readPalette()).bg[2]));

    /* The reveal loop redraws 14 random cells per PAL frame; wait until the
     * whole heading band has been drawn (and re-check the attributes). */
    check('ending: page 0 fully revealed', await waitFor(async () => {
        const n = await readScreen();
        for (let x = E.ENDING_HEAD_X0_0; x < E.ENDING_HEAD_X1_0; x++) {
            const tile = n[(OY + E.ENDING_HEAD_ROW_0) * 32 + OX + x];
            if (tile < FONT_INV || tile >= FONT_INV + GLYPHS) return false;
        }
        return true;
    }, 'page 0 reveal', 12000));
    nt = await readScreen();

    let pageAttrBad = 0;
    for (let cy = OY / 2; cy < OY / 2 + 9; cy++) {
        for (let cx = OX / 2; cx < OX / 2 + 10; cx++) {
            if (attrSlot(nt, cx * 2, cy * 2) !== 2) pageAttrBad++;
        }
    }
    check('ending: text page cells use slot 2', pageAttrBad === 0,
        `bad=${pageAttrBad}`);

    let borderBad = 0;
    for (let x = 0; x < 20; x++) {
        if (nt[OY * 32 + OX + x] !== PATTERN) borderBad++;
        if (nt[(OY + 17) * 32 + OX + x] !== PATTERN) borderBad++;
    }
    check('ending: hatched border on the page edges', borderBad === 0,
        `bad=${borderBad}`);

    // Page 0 heading band: scene row 3, columns 5..14.
    let invBad = 0;
    for (let x = E.ENDING_HEAD_X0_0; x < E.ENDING_HEAD_X1_0; x++) {
        const tile = nt[(OY + E.ENDING_HEAD_ROW_0) * 32 + OX + x];
        if (tile < FONT_INV || tile >= FONT_INV + GLYPHS) invBad++;
    }
    check('ending: page 0 heading uses the inverse font', invBad === 0,
        `bad=${invBad}`);

    // Revealed glyphs live in the normal font range.
    let glyphs = 0;
    for (let y = 0; y < 18; y++) {
        for (let x = 0; x < 20; x++) {
            const tile = nt[(OY + y) * 32 + OX + x];
            if (tile >= FONT && tile < FONT + GLYPHS) glyphs++;
        }
    }
    check('ending: page 0 glyphs revealed', glyphs > 40, `glyphs=${glyphs}`);
    await shot('nes-ending-text0.png');

    // --- Page 1 -----------------------------------------------------------
    await press('Start', 200);
    check('ending: page 1 starts', await waitFor(async () =>
        (await readBytes(sym._ending_page, 1))[0] === 1, 'page 1', 8000));
    check('ending: page 1 fades back in', await waitFor(async () => {
        const p = await readPalette();
        return p.bg[2][1] === 0x30 && p.bg[2][2] === 0x10;
    }, 'page 1 fade', 12000));

    await sleep(1200);
    nt = await readScreen();
    let inv1Bad = 0;
    for (let x = E.ENDING_HEAD_X0_1; x < E.ENDING_HEAD_X1_1; x++) {
        const tile = nt[(OY + E.ENDING_HEAD_ROW_1) * 32 + OX + x];
        if (tile < FONT_INV || tile >= FONT_INV + GLYPHS) inv1Bad++;
    }
    check('ending: page 1 heading uses the inverse font', inv1Bad === 0,
        `bad=${inv1Bad}`);
    await shot('nes-ending-text1.png');

    // --- Closing wipe -----------------------------------------------------
    await press('Start', 200);
    const wipeSeen = await waitFor(async () => {
        const n = await readScreen();
        for (let y = OY; y < OY + 18; y++) {
            for (let x = OX; x < OX + 20; x++) {
                if (n[y * 32 + x] === WIPE) return true;
            }
        }
        return false;
    }, 'wipe band', 20000);
    check('ending: closing wipe paints the band tile', wipeSeen);
    await shot('nes-ending-wipe.png');

    /* Mid-wipe: the curtain is raised from the bottom, so the lowest page row
     * is black before the highest one. */
    let ordered = false;
    await waitFor(async () => {
        const n = await readScreen();
        const bottom = n[(OY + 17) * 32 + OX + 1];
        const top = n[(OY + 1) * 32 + OX + 1];
        if (bottom === BLACK && top !== BLACK) ordered = true;
        return ordered;
    }, 'curtain order', 8000);
    check('ending: curtain rises from the bottom row', ordered);

    check('ending: sequence finishes', await waitFor(async () =>
        (await readBytes(sym._ending_active, 1))[0] === 0, 'ending end', 20000));
    await sleep(600);

    // --- Back to the title / gameplay -------------------------------------
    check('ending: returns to the title', await waitFor(async () =>
        (await readBytes(sym._ending_active, 1))[0] === 0 &&
        (await readBytes(sym._level_planet, 1))[0] >= 1, 'title', 8000));
    await press('Start', 240);
    check('ending: title starts level 1 again', await waitFor(async () =>
        (await readBytes(sym._level_planet, 1))[0] === 1 &&
        (await readBytes(sym._nes_hud_enabled, 1))[0] === 1, 'level 1', 12000));
    await waitFor(async () => (await readBytes(sym._intro_active, 1))[0] === 0,
        'intro', 12000);
    await sleep(300);

    /* NES palette reads mirror $3F00 into entry 0 of every slot, so the
     * level's own COLB backdrop is what shows up there. */
    const playPal = await readPalette();
    check('ending: gameplay palettes are reinstalled after the ending',
        arrEq(playPal.bg[3].slice(1), [0x30, 0x00, 0x0D]) &&
        playPal.bg[3][0] === playPal.bg[0][0],
        hex(playPal.bg[3]));

    if (failures) {
        console.error(`NES phase 4: ${failures} failure(s)`);
        process.exit(1);
    }
    console.log('NES phase 4 passed');
}

main().catch(err => {
    console.error(err);
    process.exit(1);
});
