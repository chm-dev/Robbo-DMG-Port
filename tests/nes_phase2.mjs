/*
 * NES Phase-2 renderer test (MesenCE-MCP, Streamable HTTP).
 *
 * Start Mesen with the MCP server before running this:
 *   MesenCE-MCP\MesenCE-MCP-Windows.exe --mcp --mcp-port=9100 --enableStdout roms\robbo-debug.nes
 *
 * Checks the phase-2 contract:
 *   - the full 16-cell map width is on screen and the camera never pans X,
 *   - the 32-column HUD is stationary in nametable 1 (4 rows, status in the
 *     middle two so overscan cannot clip it),
 *   - the scanline split publishes the HUD at the top and the vertically
 *     wrapping playfield ring in nametable 0 below it,
 *   - the 15-metarow ring follows the camera and is repainted one row at a
 *     time as the view scrolls.
 */
import fs from 'node:fs';
import path from 'node:path';

const MCP_URL = process.env.MESEN_MCP_URL || 'http://localhost:9100/mcp';
const ROM = path.resolve('roms/robbo-debug.nes');
const NOI = path.resolve('roms/robbo-debug-nes.noi');

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
            clientInfo: { name: 'robbo-nes-phase2', version: '1.0' },
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

async function writeByte(addr, value) {
    await callTool('mesen_write_memory', {
        address: `0x${addr.toString(16)}`,
        hexData: value.toString(16).padStart(2, '0'),
        memoryType: 'NesMemory',
    });
}

const sleep = ms => new Promise(r => setTimeout(r, ms));
let failures = 0;

function check(name, ok, detail = '') {
    console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? '  ' + detail : ''}`);
    if (!ok) failures++;
}

function ntRow(nametables, base, row) {
    return nametables.slice(base + row * 32, base + row * 32 + 32);
}

function arrEq(a, b) {
    return a.length === b.length && a.every((v, i) => v === b[i]);
}

async function waitFor(sym, name, predicate, timeoutMs = 12000) {
    const start = Date.now();
    while (Date.now() - start < timeoutMs) {
        const v = (await readBytes(sym[name], 1))[0];
        if (predicate(v)) return v;
        await sleep(100);
    }
    return (await readBytes(sym[name], 1))[0];
}

async function main() {
    if (!fs.existsSync(ROM)) throw new Error(`Missing ${ROM}`);
    if (!fs.existsSync(NOI)) throw new Error(`Missing ${NOI}`);
    const sym = symbolsFromNoi(NOI);

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

    await callTool('mesen_input_override', { action: 'set', port: 0, buttons: 'Start' });
    await sleep(220);
    await callTool('mesen_input_override', { action: 'set', port: 0, buttons: '' });

    const level = await waitFor(sym, '_level_planet', v => v === 1, 12000);
    // Let the level load start the intro, then wait for the ENTCV paint/WFAC
    // morph to finish before reading the ring or the HUD.
    await sleep(1200);
    await waitFor(sym, '_intro_active', v => v === 0, 15000);
    await sleep(500);
    check('level 1 started', level === 1, `planet=${level}`);

    let nt = await readBytes(0, 2048, 'NesNametableRam');
    let camY = (await readBytes(sym._cam_y, 1))[0];
    let camScy = (await readBytes(sym._cam_scy, 1))[0];
    check('camera starts at the top row', camY === 0, `cam_y=${camY}`);
    check('camera X is fixed', (await readBytes(sym._cam_scx, 1))[0] === 0);

    // --- HUD in nametable 1 ------------------------------------------------
    const hudR0 = ntRow(nt, 0x400, 0);
    const hudR1 = ntRow(nt, 0x400, 1);
    const hudR2 = ntRow(nt, 0x400, 2);
    const hudR3 = ntRow(nt, 0x400, 3);
    check('HUD padding row 0 is the empty/HUD background', hudR0.every(v => v === 0));
    check('HUD status row 1 has the left screw group', hudR1[0] !== 0 && hudR1[1] !== 0 && hudR1[2] !== 0 && hudR1[3] !== 0,
        hudR1.slice(0, 4).join(','));
    check('HUD status row 2 has the left screw group', hudR2[0] !== 0 && hudR2[1] !== 0 && hudR2[2] !== 0 && hudR2[3] !== 0,
        hudR2.slice(0, 4).join(','));
    check('HUD uses the full 32-column width', hudR1[28] !== 0 && hudR1[29] !== 0 && hudR1[30] !== 0 && hudR1[31] !== 0,
        hudR1.slice(28, 32).join(','));
    check('HUD padding row 3 is the empty/HUD background', hudR3.every(v => v === 0));

    // --- Split scroll entries ---------------------------------------------
    const hb = (await readBytes(sym.__hblank_writes_index, 1))[0];
    const isrCtrl = await readBytes(sym.__lcd_isr_PPUCTRL, 10);
    const isrY = await readBytes(sym.__lcd_isr_scroll_y, 10);
    const isrDelay = await readBytes(sym.__lcd_isr_delay_num_scanlines, 10);
    check('VBL entry selects nametable 1 (HUD)', (isrCtrl[hb] & 1) === 1, `ppuctrl=${isrCtrl[hb].toString(16)}`);
    check('LCD entry selects nametable 0 (playfield)', (isrCtrl[hb + 1] & 1) === 0, `ppuctrl=${isrCtrl[hb + 1].toString(16)}`);
    check('split delay is 32 scanlines', isrDelay[hb + 1] === 32, `delay=${isrDelay[hb + 1]}`);
    check('top scroll is zero', isrY[hb] === 0, `y=${isrY[hb]}`);
    check('playfield scroll equals the ring position', isrY[hb + 1] === camScy,
        `y=${isrY[hb + 1]} expect=${camScy}`);

    // --- Playfield ring at the top ----------------------------------------
    const nt0r0 = ntRow(nt, 0, 0);
    check('playfield fills the full 32-tile width', nt0r0[0] >= 0xF5 && nt0r0[0] <= 0xF8 &&
        nt0r0[30] >= 0xF5 && nt0r0[30] <= 0xF8,
        `left=${nt0r0[0]} right=${nt0r0[30]}`);
    let ring = await readBytes(sym._map_row_level, 15);
    check('ring holds rows 0..14 at the top', arrEq(ring, Array.from({ length: 15 }, (_, i) => i)),
        ring.join(','));

    const hudBefore = [hudR1, hudR2];

    // --- Scroll down by poking Robbo into the lower part of the map -------
    await writeByte(sym._robbo_y, 20);
    await sleep(2600);
    camY = (await readBytes(sym._cam_y, 1))[0];
    camScy = (await readBytes(sym._cam_scy, 1))[0];
    check('camera centered on Robbo row 20', camY === 14, `cam_y=${camY}`);
    check('ring scroll wraps at 15 metarows', camScy === 224, `cam_scy=${camScy}`);
    ring = await readBytes(sym._map_row_level, 15);
    check('ring repainted to rows 14..28', arrEq(ring,
        [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 14]), ring.join(','));

    const isrCtrl2 = await readBytes(sym.__lcd_isr_PPUCTRL, 10);
    const isrY2 = await readBytes(sym.__lcd_isr_scroll_y, 10);
    check('split stays on the HUD/playfield nametables while scrolled',
        (isrCtrl2[hb] & 1) === 1 && (isrCtrl2[hb + 1] & 1) === 0);
    check('split scroll follows the ring', isrY2[hb + 1] === camScy, `y=${isrY2[hb + 1]}`);

    nt = await readBytes(0, 2048, 'NesNametableRam');
    check('HUD is stationary while the playfield scrolls',
        arrEq(ntRow(nt, 0x400, 1), hudBefore[0]) && arrEq(ntRow(nt, 0x400, 2), hudBefore[1]));
    check('scrolled playfield shows the ring row in its reserved slot',
        ntRow(nt, 0, 28)[0] >= 0xF5 && ntRow(nt, 0, 28)[0] <= 0xF8,
        `tile=${ntRow(nt, 0, 28)[0]}`);

    // --- Scroll back up ---------------------------------------------------
    await writeByte(sym._robbo_y, 10);
    await sleep(2600);
    camY = (await readBytes(sym._cam_y, 1))[0];
    camScy = (await readBytes(sym._cam_scy, 1))[0];
    check('camera follows Robbo back up', camY === 4, `cam_y=${camY}`);
    check('ring scroll wraps to slot 4', camScy === 64, `cam_scy=${camScy}`);
    ring = await readBytes(sym._map_row_level, 15);
    check('ring repainted to rows 4..18', arrEq(ring,
        [15, 16, 17, 18, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]), ring.join(','));

    // --- HUD values still update -----------------------------------------
    await writeByte(sym._screws_left, 5);
    await writeByte(sym._hud_dirty, 1);
    await sleep(300);
    nt = await readBytes(0, 2048, 'NesNametableRam');
    const hudR1b = ntRow(nt, 0x400, 1);
    check('HUD redraws on a counter change', hudR1b[3] !== hudBefore[0][3] ||
        ntRow(nt, 0x400, 2)[3] !== hudBefore[1][3],
        `${hudR1b[3]}/${ntRow(nt, 0x400, 2)[3]}`);

    await callTool('mesen_write_memory', {
        address: '0x7FF0',
        hexData: '00000000000000000000000000000000',
        memoryType: 'NesMemory',
    });

    if (failures) {
        console.log(`NES phase 2 FAILED (${failures})`);
        process.exitCode = 1;
    } else {
        console.log('NES phase 2 passed');
    }
}

main().catch(err => {
    console.error(err.message);
    process.exitCode = 1;
});
