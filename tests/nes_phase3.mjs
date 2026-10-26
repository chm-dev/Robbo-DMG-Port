/*
 * NES Phase-3 colour test (MesenCE-MCP, Streamable HTTP).
 *
 * Start Mesen with the MCP server before running this:
 *   MesenCE-MCP\MesenCE-MCP-Windows.exe --mcp --mcp-port=9100 --enableStdout roms\robbo-debug.nes
 *
 * Checks the phase-3 colour contract:
 *   - the generated NES table is programmed into PPU palette RAM per level
 *     (normal / wall / objects / UI, with the shared backdrop = COLB),
 *   - every ring cell's 16x16 attribute matches the map (walls, cave fill,
 *     inverse objects, teleports borrowing the wall palette, normal-palette
 *     wall variants),
 *   - the intro's attribute pre-pass publishes the whole ring before the
 *     column paint, so no cell keeps the previous level's palette,
 *   - the HUD in nametable 1 uses the UI slot,
 *   - the 16x10 pause panel is cell-aligned, paints UI attributes and
 *     restores the map's attribute values when it closes,
 *   - the normal-palette wall variant (L6/L25/L26/L28/L37) draws slot 0.
 *
 * Run: node gb/tests/nes_phase3.mjs
 */
import fs from 'node:fs';
import path from 'node:path';

const MCP_URL = process.env.MESEN_MCP_URL || 'http://localhost:9100/mcp';
const ROM = path.resolve('roms/robbo-debug.nes');
const NOI = path.resolve('roms/robbo-debug-nes.noi');
const PAL_SRC = path.resolve('gb/src/gen/level_pal_nes.c');

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
            clientInfo: { name: 'robbo-nes-phase3', version: '1.0' },
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

function arrEq(a, b) {
    return a.length === b.length && a.every((v, i) => v === b[i]);
}

const hex = a => a.map(v => v.toString(16).padStart(2, '0')).join(' ');

/* Per-level NES palettes straight from the generated source, so the test
 * fails if the generator output and the ROM ever drift apart. */
function levelPalettes() {
    const text = fs.readFileSync(PAL_SRC, 'utf8');
    const rows = [];
    const re = /\{((?:0x[0-9A-Fa-f]{2},\s*){7}0x[0-9A-Fa-f]{2})\},\s*\/\*\s*(\d+)\s*\*\//g;
    let m;
    while ((m = re.exec(text))) {
        const values = m[1].split(',').map(v => parseInt(v.trim(), 16));
        rows[parseInt(m[2], 10) - 1] = values;
    }
    if (rows.filter(Boolean).length !== 56) {
        throw new Error(`expected 56 NES palettes in ${PAL_SRC}`);
    }
    return rows;
}

/* Gameplay attribute value for one map cell (mirrors render_cell_palette). */
function cellPalette(type, extra) {
    if (type >= 1 && type <= 8) {
        if (type - 1 === 5) return 0;          /* cave fill -> normal */
        if (extra & 0x80) return 0;            /* normal-palette wall */
        return 1;                              /* inverse wall */
    }
    if (type === 20) return 1;                 /* teleport borrows the wall */
    if (type === 10 || type === 12) return 2;  /* stone / door */
    return 0;
}

/* Pack the 15 ring rows into the 64 hardware attribute bytes. */
function expectedAttributes(map, extra, ring, height) {
    const bytes = new Array(64).fill(0);
    const seen = { teleport: 0, cave: 0, object: 0, wall: 0, normalWall: 0 };

    for (let ar = 0; ar < 8; ar++) {
        for (let b = 0; b < 8; b++) {
            let value = 0;
            for (let half = 0; half < 2; half++) {
                const slot = ar * 2 + half;
                if (slot >= 15) continue;      /* slot 15 is not in the ring */
                const levelY = ring[slot];
                for (let bit = 0; bit < 2; bit++) {
                    const x = b * 2 + bit;
                    let pal = 0;
                    if (levelY < height) {
                        const idx = levelY * 16 + x;
                        const type = map[idx];
                        const state = extra[idx];
                        pal = cellPalette(type, state);
                        if (type === 20) seen.teleport++;
                        if (type >= 1 && type <= 8 && type - 1 === 5) seen.cave++;
                        if (type === 10 || type === 12) seen.object++;
                        if (type >= 1 && type <= 8 && type - 1 !== 5) {
                            if (state & 0x80) seen.normalWall++;
                            else seen.wall++;
                        }
                    }
                    value |= pal << (bit * 2 + half * 4);
                }
            }
            bytes[ar * 8 + b] = value;
        }
    }
    return { bytes, seen };
}

async function readRing(sym) {
    const map = await readBytes(sym._map_type, 496);
    const extra = await readBytes(sym._map_extra, 496);
    const ring = await readBytes(sym._map_row_level, 15);
    const height = (await readBytes(sym._level_height, 1))[0];
    return { map, extra, ring, height };
}

async function waitIntro(sym, timeoutMs = 18000) {
    const start = Date.now();
    while (Date.now() - start < timeoutMs) {
        const intro = (await readBytes(sym._intro_active, 1))[0];
        const busy = (await readBytes(sym._robbo_busy, 1))[0];
        if (!intro && !busy) return true;
        await sleep(100);
    }
    return false;
}

/* game_load_level() sets level_planet early and installs the palette /
 * starts the intro later in the same (frame-spanning) load.  Wait until the
 * intro has actually begun before waiting for it to finish. */
async function waitLoad(sym, timeoutMs = 18000) {
    const start = Date.now();
    while (Date.now() - start < 3000) {
        if ((await readBytes(sym._intro_active, 1))[0] === 1) break;
        await sleep(50);
    }
    return waitIntro(sym, timeoutMs);
}

async function press(sym, buttons, holdMs = 160) {
    await callTool('mesen_input_override', { action: 'set', port: 0, buttons });
    await sleep(holdMs);
    await callTool('mesen_input_override', { action: 'set', port: 0, buttons: '' });
    await sleep(120);
}

async function warpTo(sym, target, timeoutMs = 15000) {
    const start = Date.now();
    while (Date.now() - start < timeoutMs) {
        const level = (await readBytes(sym._level_planet, 1))[0];
        if (level === target) return true;
        await press(sym, 'Select', 140);
        await sleep(150);
    }
    return false;
}

/* One debug-warp press (Select alone = next, Select+Right = +10,
 * Select+Up = previous), then wait for the load and intro to finish. */
async function warpPress(sym, buttons, target, timeoutMs = 15000) {
    await press(sym, buttons, 140);
    const start = Date.now();
    let level = 0;
    while (Date.now() - start < timeoutMs) {
        level = (await readBytes(sym._level_planet, 1))[0];
        if (level === target) break;
        await sleep(100);
    }
    return level === target;
}

async function checkPalettes(label, sym, row) {
    const pal = await readBytes(0, 32, 'NesPaletteRam');
    const bg0 = pal.slice(0, 4);
    const bg1 = pal.slice(4, 8);
    const bg2 = pal.slice(8, 12);
    const bg3 = pal.slice(12, 16);

    check(`${label}: normal palette`, arrEq(bg0, row.slice(0, 4)),
        `${hex(bg0)} expect ${hex(row.slice(0, 4))}`);
    check(`${label}: wall palette`, arrEq(bg1, row.slice(4, 8)),
        `${hex(bg1)} expect ${hex(row.slice(4, 8))}`);
    check(`${label}: inverse objects derived from the wall`, arrEq(bg2, [
        row[4], row[7], row[6], row[5],
    ]), `${hex(bg2)}`);
    check(`${label}: shared backdrop is COLB`, bg0[0] === row[0] && bg3[0] === row[0]);
    check(`${label}: UI slot 3`, arrEq(bg3.slice(1, 4), [0x30, 0x00, 0x0D]),
        hex(bg3));
    for (let i = 0; i < 4; i++) {
        if (!arrEq(pal.slice(16 + i * 4 + 1, 16 + i * 4 + 4), [0x00, 0x10, 0x30])) {
            check(`${label}: sprite palette ${i}`, false, hex(pal.slice(16 + i * 4, 20 + i * 4)));
            return;
        }
    }
    check(`${label}: sprite ramps`, true);
}

async function checkAttributes(label, sym, expectSeen = null) {
    const ringData = await readRing(sym);
    const nt = await readBytes(0, 2048, 'NesNametableRam');
    const actual = nt.slice(0x3C0, 0x400);
    const { bytes: expected, seen } = expectedAttributes(
        ringData.map, ringData.extra, ringData.ring, ringData.height);

    let bad = -1;
    for (let ar = 0; ar < 8 && bad < 0; ar++) {
        for (let b = 0; b < 8; b++) {
            const a = actual[ar * 8 + b];
            const e = expected[ar * 8 + b];
            const mask = ar === 7 ? 0x0F : 0xFF;   /* slot 15 is off-ring */
            if ((a & mask) !== (e & mask)) {
                bad = ar * 8 + b;
                break;
            }
        }
    }
    check(`${label}: ring attributes match the map`, bad < 0,
        bad < 0 ? `ring=${ringData.ring.join(',')}` :
            `attr[${bad}] actual=${actual[bad].toString(16)} expected=${expected[bad].toString(16)}`);

    if (expectSeen) {
        for (const [key, min] of Object.entries(expectSeen)) {
            check(`${label}: ${key} cells covered (${seen[key]})`, seen[key] >= min,
                `${seen[key]} >= ${min}`);
        }
    }
    return seen;
}

async function main() {
    if (!fs.existsSync(ROM)) throw new Error(`Missing ${ROM}`);
    if (!fs.existsSync(NOI)) throw new Error(`Missing ${NOI}`);
    const sym = symbolsFromNoi(NOI);
    const palettes = levelPalettes();

    // The teleport middle alternates the wall highlight (row[5]) and wall
    // detail (row[7]); the ring is the wall body (row[6]).  A shared entry
    // there means only the source's two sparkle pixels change, not the mirror.
    const blinkDup = palettes.map((p, i) => p[5] === p[7] ? i + 1 : 0).filter(Boolean);
    check('all 56 levels have a distinct teleport highlight/detail pair',
        blinkDup.length === 0, `levels=${blinkDup.join(',')}`);
    const bodyDup = palettes.map((p, i) => p[6] === p[7] ? i + 1 : 0).filter(Boolean);
    check('all 56 levels keep the wall body/detail distinct',
        bodyDup.length === 0, `levels=${bodyDup.join(',')}`);

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

    await press(sym, 'Start', 220);
    const level = (await readBytes(sym._level_planet, 1))[0];
    check('level 1 started', level === 1, `planet=${level}`);
    check('intro finishes', await waitLoad(sym));
    await sleep(300);

    // --- Level 1 palette / attributes -------------------------------------
    await checkPalettes('L1', sym, palettes[0]);
    const seen1 = await checkAttributes('L1', sym,
        { teleport: 1, object: 1, wall: 1 });

    // HUD attributes in nametable 1 use slot 3 (all four sub-areas = 3).
    let nt = await readBytes(0, 2048, 'NesNametableRam');
    check('HUD attribute row is all UI', nt.slice(0x7C0, 0x7C8).every(v => v === 0xFF),
        hex(nt.slice(0x7C0, 0x7C8)));
    check('HUD padding rows stay slot 0', nt.slice(0x7C8, 0x800).every(v => v === 0));

    // --- Pause menu: cell-aligned panel, UI attributes, exact restore -----
    await press(sym, 'Start');
    let menuState = 0;
    for (let i = 0; i < 40 && menuState !== 2; i++) {
        await sleep(100);
        menuState = (await readBytes(sym._pause_menu_state, 1))[0];
    }
    check('pause menu opens', menuState === 2, `state=${menuState}`);

    const bgx = (await readBytes(sym._pause_menu_bg_x, 1))[0];
    const bgy = (await readBytes(sym._pause_menu_bg_y, 1))[0];
    check('pause panel x is cell-aligned', (bgx & 1) === 0, `x=${bgx}`);
    check('pause panel y is cell-aligned', (bgy & 1) === 0, `y=${bgy}`);

    let menuBad = 0;
    nt = await readBytes(0, 2048, 'NesNametableRam');
    for (let i = 0; i < 5; i++) {
        const slot = ((bgy >> 1) + i) % 15;
        for (let cx = 4; cx < 12; cx++) {
            const byte = nt[0x3C0 + (slot >> 1) * 8 + (cx >> 1)];
            const shift = ((slot & 1) ? 4 : 0) + ((cx & 1) ? 2 : 0);
            if (((byte >> shift) & 3) !== 3) menuBad++;
        }
    }
    check('pause panel cells use the UI slot', menuBad === 0, `bad=${menuBad}`);

    await press(sym, 'B');
    let closed = 0;
    for (let i = 0; i < 40 && closed !== 1; i++) {
        await sleep(100);
        closed = (await readBytes(sym._pause_menu_state, 1))[0] === 0 ? 1 : 0;
    }
    check('pause menu closes', closed === 1);
    await sleep(300);
    await checkAttributes('L1 after pause', sym);

    // --- Warp: per-level palette changes ----------------------------------
    check('warp to level 2', await warpTo(sym, 2));
    check('L2 intro finishes', await waitLoad(sym));
    await sleep(300);
    await checkPalettes('L2', sym, palettes[1]);
    await checkAttributes('L2', sym);

    // --- Level 3: cave fill + more teleports/doors ------------------------
    check('warp to level 3', await warpTo(sym, 3));
    check('L3 intro finishes', await waitLoad(sym));
    await sleep(300);
    await checkPalettes('L3', sym, palettes[2]);
    await checkAttributes('L3', sym,
        { cave: 1, teleport: 1, object: 1 });

    // --- Level 6: mixed wall style ----------------------------------------
    check('warp to level 6', await warpTo(sym, 6));
    check('L6 intro finishes', await waitLoad(sym));
    await sleep(300);
    await checkPalettes('L6', sym, palettes[5]);
    await checkAttributes('L6', sym);

    // --- Level 25: normal-palette wall variant draws slot 0 ---------------
    // All 42 variant walls are in rows 6..9, inside the top-aligned start
    // view (Robbo spawns on row 2).  Select+Right = +10.
    check('warp to level 16', await warpPress(sym, 'Select,Right', 16));
    check('L16 intro finishes', await waitLoad(sym));
    check('warp to level 26', await warpPress(sym, 'Select,Right', 26));
    check('L26 intro finishes', await waitLoad(sym));
    check('warp to level 25', await warpPress(sym, 'Select,Up', 25));
    check('L25 intro finishes', await waitLoad(sym));
    await sleep(300);
    await checkPalettes('L25', sym, palettes[24]);
    await checkAttributes('L25', sym, { normalWall: 1 });

    if (failures) {
        console.error(`NES phase 3: ${failures} failure(s)`);
        process.exit(1);
    }
    console.log('NES phase 3 passed');
}

main().catch(err => {
    console.error(err);
    process.exit(1);
});
