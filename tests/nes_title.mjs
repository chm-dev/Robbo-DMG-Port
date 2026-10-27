/*
 * NES title-screen regression test (MesenCE-MCP, Streamable HTTP).
 *
 * Start Mesen with the MCP server before running this:
 *   MesenCE-MCP\MesenCE-MCP-Windows.exe --mcp --mcp-port=9100 --enableStdout roms\robbo.nes
 *
 * Checks:
 *   - the Atari layout: 28x5 logo block at tile rows 3..7, copyright row 9,
 *     rule rows 18/27 and the 8-line instruction window at rows 19..26,
 *   - the authentic logo tiles are generated into CHR-RAM and the palette
 *     phases keep the backdrop black,
 *   - the 2-second pre-typewriter pause and the typewriter start,
 *   - START without a save loads level 1,
 *   - with a save, START opens the start-level menu, Down selects DELETE,
 *     A confirms, B cancels, Left changes the level and A starts it.
 */
import fs from 'node:fs';
import path from 'node:path';

const MCP_URL = process.env.MESEN_MCP_URL || 'http://localhost:9100/mcp';
const ROM = path.resolve('roms/robbo.nes');
const NOI = path.resolve('roms/robbo-nes.noi');
const EMPTY_TILE = 0x8d;   /* NES_BLANK_TILE = 141 */
const RULE_TILE = 0x8c;    /* NES_RULE_TILE = 140 */
const LOGO_X = 2;          /* logo tile column */
const LOGO_Y = 3;          /* logo tile row */

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
            clientInfo: { name: 'robbo-nes-title', version: '1.0' },
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

function readBytes(addr, length, type = 'NesMemory') {
    return callTool('mesen_read_memory', {
        address: `0x${addr.toString(16)}`,
        length,
        memoryType: type,
    }).then(text => text.trim().split(/\s+/).filter(Boolean).map(h => parseInt(h, 16)));
}

const sleep = ms => new Promise(r => setTimeout(r, ms));
let failures = 0;

function check(name, ok, detail = '') {
    console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? '  ' + detail : ''}`);
    if (!ok) failures++;
}

async function clearSave() {
    await callTool('mesen_write_memory', {
        address: '0x7FF0',
        hexData: '00000000000000000000000000000000',
        memoryType: 'NesMemory',
    });
}

async function writeSave(level) {
    const checkByte = (level ^ 1 ^ 0x3C) & 0xFF;
    const hex = ['52', '42', '42', '4F', '01',
        level.toString(16).padStart(2, '0'),
        checkByte.toString(16).padStart(2, '0'), 'A5'].join('');
    await callTool('mesen_write_memory', {
        address: '0x7FF0', hexData: hex, memoryType: 'NesMemory',
    });
}

async function press(buttons, ms = 120) {
    await callTool('mesen_input_override', { action: 'set', port: 0, buttons });
    await sleep(ms);
    await callTool('mesen_input_override', { action: 'set', port: 0, buttons: '' });
    await sleep(260);
}

async function nametable() {
    return readBytes(0, 2048, 'NesNametableRam');
}

function row(nt, y) {
    return nt.slice(y * 32, y * 32 + 32);
}

function eq(a, b) {
    return a.length === b.length && a.every((v, i) => v === b[i]);
}

async function waitFor(addr, predicate, timeoutMs = 12000) {
    const start = Date.now();
    while (Date.now() - start < timeoutMs) {
        const v = (await readBytes(addr, 1))[0];
        if (predicate(v)) return v;
        await sleep(120);
    }
    return null;
}

async function main() {
    if (!fs.existsSync(ROM)) throw new Error(`Missing ${ROM}`);
    if (!fs.existsSync(NOI)) throw new Error(`Missing ${NOI}`);
    const sym = symbolsFromNoi(NOI);

    await init();
    await callTool('mesen_load_rom', { filepath: ROM });
    await sleep(900);
    await clearSave();
    await callTool('mesen_reset', { type: 'soft' });
    await sleep(1700);

    // --- static Atari layout -------------------------------------------
    let nt = await nametable();
    let layoutOk = true;
    for (let tr = 0; tr < 5; tr++) {
        for (let tc = 0; tc < 28; tc++) {
            if (row(nt, 3 + tr)[2 + tc] !== tr * 28 + tc) layoutOk = false;
        }
    }
    check('supported logo block is 28x5 tiles at rows 3..7', layoutOk);
    check('copyright row is drawn', row(nt, 9)[8] === 0xd8, `tile=${row(nt, 9)[8].toString(16)}`);
    check('credits row is drawn', row(nt, 11)[6] !== EMPTY_TILE);
    check('top rule row 18 spans the screen', eq(row(nt, 18), Array(32).fill(RULE_TILE)));
    check('bottom rule row 27 spans the screen', eq(row(nt, 27), Array(32).fill(RULE_TILE)));
    check('instruction window starts blank during the 2s delay',
        [19, 20, 21, 22, 23, 24, 25, 26].every(y => row(nt, y).every(t => t === EMPTY_TILE)));

    const chr = await readBytes(0, 140 * 16, 'NesChrRam');
    let nonblank = 0;
    for (let t = 0; t < 140; t++) {
        if (chr.slice(t * 16, t * 16 + 16).some(b => b !== 0)) nonblank++;
    }
    check('logo CHR tiles are generated', nonblank > 80, `${nonblank}/140 nonblank`);

    // Every source block is a 4x4 pixel square of one palette entry.  This
    // is what makes the NES logo read like the Atari mosaic instead of the
    // horizontal stripes produced by native-planar CHR data.
    // `chr` is PPU (native NES) planar data: bytes 0..7 are plane 0,
    // bytes 8..15 are plane 1.
    function chrPixel(tile, px, py) {
        const b = tile * 16;
        const bit = 7 - px;
        return ((chr[b + py] >> bit) & 1) | (((chr[b + 8 + py] >> bit) & 1) << 1);
    }
    let mixedBlocks = 0;
    let blockCount = 0;
    const blockValues = new Set();
    for (let gy = 0; gy < 40; gy += 5) {
        for (let gx = 0; gx < 56; gx++) {
            let value = null;
            let solid = true;
            for (let y = 0; y < 4; y++) {
                for (let x = 0; x < 4; x++) {
                    const sx = LOGO_X * 8 + gx * 4 + x;
                    const sy = LOGO_Y * 8 + gy + y;
                    const pv = chrPixel(row(nt, sy >> 3)[sx >> 3], sx & 7, sy & 7);
                    if (value === null) value = pv;
                    else if (pv !== value) solid = false;
                }
            }
            if (!solid) mixedBlocks++;
            blockCount++;
            blockValues.add(value);
        }
    }
    check('logo blocks are solid 4x4 colour squares', mixedBlocks === 0,
        `${mixedBlocks}/${blockCount} mixed`);
    check('logo uses all three Atari foreground colours',
        [1, 2, 3].every(v => blockValues.has(v)),
        `values=${[...blockValues].sort().join(',')}`);

    const pal = await readBytes(0, 32, 'NesPaletteRam');
    check('title backdrop is black', pal[0] === 0x0f, `bg0=${pal.slice(0, 4).map(v => v.toString(16)).join(' ')}`);
    check('logo palette has three foreground colours',
        pal[1] !== pal[2] && pal[2] !== pal[3] && pal[1] !== pal[3]);

    // --- typewriter -----------------------------------------------------
    await sleep(2500);
    nt = await nametable();
    const windowText = [19, 20, 21, 22, 23, 24, 25, 26]
        .map(y => row(nt, y)).flat().filter(t => t !== EMPTY_TILE && t !== RULE_TILE);
    check('typewriter has started after the delay', windowText.length > 0,
        `nonblank=${windowText.length}`);

    // --- no save: START begins level 1 ---------------------------------
    await press('Start', 150);
    const level1 = await waitFor(sym._level_planet, v => v === 1);
    check('START without a save loads level 1', level1 === 1, `planet=${level1}`);

    // --- save menu ------------------------------------------------------
    await callTool('mesen_load_rom', { filepath: ROM });
    await sleep(900);
    await writeSave(5);
    await callTool('mesen_reset', { type: 'soft' });
    await sleep(2200);
    await press('Start', 150);
    await sleep(700);
    nt = await nametable();
    check('save menu heading row is drawn', row(nt, 19).some(t => t !== EMPTY_TILE && t !== RULE_TILE));
    check('level digits occupy rows 20/21', row(nt, 20)[15] !== EMPTY_TILE && row(nt, 21)[15] !== EMPTY_TILE);
    check('level arrow is on the heading row', row(nt, 19)[7] === 0xc8, `tile=${row(nt, 19)[7].toString(16)}`);

    await press('Down', 120);
    await sleep(350);
    nt = await nametable();
    check('Down selects DELETE SAVE GAME', row(nt, 23)[6] === 0xc8, `tile=${row(nt, 23)[6].toString(16)}`);

    await press('A', 120);
    await sleep(350);
    nt = await nametable();
    check('A opens delete confirmation', row(nt, 19).some(t => t !== EMPTY_TILE && t !== RULE_TILE));
    check('delete confirmation asks A/B', row(nt, 21).some(t => t !== EMPTY_TILE));

    await press('B', 120);
    await sleep(350);
    nt = await nametable();
    check('B cancels back to the menu', row(nt, 19).some(t => t !== EMPTY_TILE && t !== RULE_TILE));

    // B leaves the cursor on the level; Left lowers 5 -> 4 and A starts it.
    await press('Left', 120);
    await sleep(350);
    await press('A', 120);
    const level4 = await waitFor(sym._level_planet, v => v === 4);
    check('menu level selection starts the chosen planet', level4 === 4, `planet=${level4}`);

    console.log(failures ? `NES title test FAILED (${failures})` : 'NES title test passed');
    process.exit(failures ? 1 : 0);
}

main().catch(err => {
    console.error(err);
    process.exit(1);
});
