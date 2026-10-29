/*
 * NES actor redraw regression (MesenCE-MCP, Streamable HTTP).
 *
 * Start Mesen with the MCP server before running this:
 *   MesenCE-MCP\MesenCE-MCP-Windows.exe --mcp --mcp-port=9100 --enableStdout roms\robbo-debug.nes
 *
 * Level 40 has eight bears moving through the chamber just above Robbo's
 * spawn, so the 16-wide NES view shows several of them at once.  A tick with
 * that many moving actors crosses the dense flush path (>= 16 dirty cells).
 * The dense path clears a whole map row's dirty mask up front, so it must
 * draw every run in that row: dropping the second run used to leave the old
 * bear/baddie tile on screen until something else happened to redraw the
 * cell ("sprites are not removed after they moved").
 *
 * This test watches the visible playfield and fails when a cell keeps a bear
 * tile while its map cell no longer holds a bear for more than
 * STALE_POLL_LIMIT consecutive samples.  A couple of samples are expected:
 * the map changes during the logic tick, the cell is queued on the next
 * frame and the GBDK VRAM transfer lands on the VBlank after that.
 *
 * Run: node gb/tests/nes_actor_ghost.mjs
 */
import fs from 'node:fs';
import path from 'node:path';

const MCP_URL = process.env.MESEN_MCP_URL || 'http://localhost:9100/mcp';
const ROM = path.resolve('roms/robbo-debug.nes');
const NOI = path.resolve('roms/robbo-debug-nes.noi');

/* 25 ms per sample; 8 samples ~= 10 frames, well past the 2-3 frame
 * draw pipeline but far below the old indefinite ghost. */
const SAMPLE_MS = 25;
const SAMPLE_COUNT = 600;
const STALE_POLL_LIMIT = 8;
/* Metatile BEAR_0..BEAR_3 (see gb/src/gen/tiles.c). */
const BEAR_TILE_FIRST = 134;
const BEAR_TILE_LAST = 149;
const CT_BEAR = 23;

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
            clientInfo: { name: 'robbo-nes-actor-ghost', version: '1.0' },
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

async function main() {
    const sym = symbolsFromNoi(NOI);
    const byte = async (name) => (await readBytes(sym['_' + name], 1))[0];

    async function press(buttons, holdMs = 200) {
        await callTool('mesen_input_override', { action: 'set', port: 0, buttons });
        await sleep(holdMs);
        await callTool('mesen_input_override', { action: 'set', port: 0, buttons: '' });
        await sleep(200);
    }

    async function waitIntro(timeoutMs = 30000) {
        const start = Date.now();
        while (Date.now() - start < timeoutMs) {
            if (!(await byte('intro_active')) && !(await byte('robbo_busy'))) return true;
            await sleep(100);
        }
        return false;
    }

    async function warpTo(target, timeoutMs = 90000) {
        const start = Date.now();
        while (Date.now() - start < timeoutMs) {
            if ((await byte('level_planet')) === target) return true;
            await press('Select', 150);
            await sleep(200);
        }
        return false;
    }

    await init();
    await callTool('mesen_load_rom', { filepath: ROM });
    await callTool('mesen_reset', { type: 'hard' });
    await sleep(1000);

    /* Debug ROM: the title starts level 1 on START, then Select warps. */
    await press('Start', 300);
    for (let i = 0; i < 100 && (await byte('level_planet')) === 0; i++) await sleep(100);
    check('started level 1', (await byte('level_planet')) === 1,
        `level=${await byte('level_planet')}`);
    await waitIntro();
    check('warp to level 40', await warpTo(40));
    await sleep(800);
    check('level 40 intro finished', await waitIntro(),
        `level=${await byte('level_planet')} camY=${await byte('cam_y')}`);

    /* Track how long each cell keeps a bear tile after the map dropped it. */
    const staleRun = new Map();
    let maxRun = 0;
    let maxRunCell = null;
    let bearTilesSeen = 0;

    for (let sample = 0; sample < SAMPLE_COUNT; sample++) {
        await sleep(SAMPLE_MS);
        const map = await readBytes(sym._map_type, 496);
        const ring = await readBytes(sym._map_row_level, 15);
        const nt = await readBytes(0, 2048, 'NesNametableRam');
        const camY = (await readBytes(sym._cam_y, 1))[0];
        const nextRun = new Map();

        for (let y = Math.max(0, camY - 1); y <= Math.min(30, camY + 13); y++) {
            const slot = y % 15;
            if (ring[slot] !== y) continue;
            for (let x = 0; x < 16; x++) {
                const tile = nt[(slot * 2) * 32 + x * 2];
                const isBearTile = tile >= BEAR_TILE_FIRST && tile <= BEAR_TILE_LAST;
                if (isBearTile) bearTilesSeen++;
                if (!isBearTile || map[y * 16 + x] === CT_BEAR) continue;
                const key = `${x},${y}`;
                const run = (staleRun.get(key) || 0) + 1;
                nextRun.set(key, run);
                if (run > maxRun) {
                    maxRun = run;
                    maxRunCell = `${key} tile=${tile} map=${map[y * 16 + x]} camY=${camY}`;
                }
            }
        }
        staleRun.clear();
        for (const [k, v] of nextRun) staleRun.set(k, v);
    }

    check('level 40 shows moving bears', bearTilesSeen > 0, `samples=${bearTilesSeen}`);
    check('no actor cell stays stale', maxRun <= STALE_POLL_LIMIT,
        `longest stale run=${maxRun} (limit ${STALE_POLL_LIMIT})` +
        (maxRunCell ? ` at ${maxRunCell}` : ''));

    console.log(failures ? `\n${failures} check(s) failed` : '\nNES actor redraw test passed');
    process.exit(failures ? 1 : 0);
}

main().catch(err => {
    console.error(err);
    process.exit(1);
});
