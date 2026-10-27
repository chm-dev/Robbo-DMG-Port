/*
 * NES door regression test (MesenCE-MCP, Streamable HTTP).
 *
 * Start Mesen with the MCP server before running this:
 *   MesenCE-MCP\MesenCE-MCP-Windows.exe --mcp --mcp-port=9100 --enableStdout roms\robbo-debug.nes
 *
 * Opening a key door used to freeze the NES build: sound.c copied the GBC
 * CH3 wave image straight to $FF30, which is wave RAM on the Game Boy but the
 * UxROM bank register on the NES.  The store selected an empty bank and the
 * CPU ran off into $FF-filled ROM, ending in the crt0 hang loop at $C322.
 * The NES APU backend now plays a triangle body plus the Atari door's boosted
 * 25% pulse on pulse 2 and never touches $FF30.
 *
 * The test injects a door next to Robbo with a key in hand, opens it, and
 * checks that:
 *   - the door cell becomes empty and one key is consumed,
 *   - the door SFX drives the NES 25% pulse layer,
 *   - the game keeps ticking (anim_frame advances, PC never sits in the
 *     $C322 hang loop),
 *   - Robbo can walk into the cell the door occupied.
 *
 * Run: node gb/tests/nes_door.mjs
 */
import fs from 'node:fs';
import path from 'node:path';

const MCP_URL = process.env.MESEN_MCP_URL || 'http://localhost:9100/mcp';
const ROM = path.resolve('roms/robbo-debug.nes');
const NOI = path.resolve('roms/robbo-debug-nes.noi');

const CT_EMPTY = 0;
const CT_DOOR = 12;
const CT_ROBBO = 26;
const HANG_LOOP = '$C322';

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
            clientInfo: { name: 'robbo-nes-door', version: '1.0' },
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

async function writeBytes(addr, bytes, type = 'NesMemory') {
    return callTool('mesen_write_memory', {
        address: `0x${addr.toString(16)}`,
        hexData: bytes.map(b => b.toString(16).padStart(2, '0')).join(''),
        memoryType: type,
    });
}

const sleep = ms => new Promise(r => setTimeout(r, ms));
let failures = 0;

function check(name, ok, detail = '') {
    console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? '  ' + detail : ''}`);
    if (!ok) failures++;
}

async function press(buttons, holdMs = 180) {
    await callTool('mesen_input_override', { action: 'set', port: 0, buttons });
    await sleep(holdMs);
    await callTool('mesen_input_override', { action: 'set', port: 0, buttons: '' });
    await sleep(150);
}

async function cpuState() {
    return callTool('mesen_get_state', { component: 'cpu', cpuType: 'Nes' });
}

async function inHangLoop() {
    return (await cpuState()).includes(`PC=${HANG_LOOP}`);
}

/* Read the door's pulse-2 state from Mesen's APU snapshot. */
async function doorPulseActive() {
    const lua = `local s=emu.getState()
emu.log(tostring(s['apu.square2.envelope.volume']) .. ' ' .. tostring(s['apu.square2.duty']))`;
    const text = await callTool('mesen_run_lua_script', { code: lua, waitMs: 100 });
    const line = text.split(/\r?\n/).map(l => l.trim()).find(l => /^\d+ \d+$/.test(l));
    if (!line) return false;
    const [vol, duty] = line.split(/\s+/).map(Number);
    return vol > 0 && duty === 1;
}

async function main() {
    if (!fs.existsSync(ROM)) throw new Error(`Missing ${ROM}`);
    if (!fs.existsSync(NOI)) throw new Error(`Missing ${NOI}`);
    const sym = symbolsFromNoi(NOI);
    const rd = async name => (await readBytes(sym[name], 1))[0];

    await init();
    await callTool('mesen_breakpoint', { action: 'remove_all' });
    await callTool('mesen_resume_execution', {}).catch(() => {});
    await callTool('mesen_load_rom', { filepath: ROM });
    await sleep(1000);
    await writeBytes(0x7FF0, new Array(16).fill(0));
    await callTool('mesen_reset', { type: 'hard' });
    await sleep(1500);

    await press('Start', 220);
    let started = false;
    for (let i = 0; i < 40; i++) {
        await sleep(200);
        if ((await rd('_intro_active')) === 0 && (await rd('_level_planet')) === 1) {
            started = true;
            break;
        }
    }
    check('level 1 started', started);
    if (!started) return finish();

    const rx = await rd('_robbo_x');
    const ry = await rd('_robbo_y');
    const mapAddr = sym._map_type;
    const dirs = [
        [1, 0, 'Right'], [0, 1, 'Down'], [-1, 0, 'Left'], [0, -1, 'Up'],
    ];
    let door = null;
    for (const [dx, dy, name] of dirs) {
        const nx = rx + dx, ny = ry + dy;
        if (nx < 0 || nx >= 16 || ny < 0 || ny >= 31) continue;
        if ((await readBytes(mapAddr + ny * 16 + nx, 1))[0] === CT_EMPTY) {
            door = { nx, ny, name };
            break;
        }
    }
    check('found an empty cell beside Robbo', door !== null);
    if (!door) return finish();

    const doorIdx = door.ny * 16 + door.nx;
    await writeBytes(mapAddr + doorIdx, [CT_DOOR]);
    await writeBytes(sym._map_extra + doorIdx, [0]);
    await writeBytes(sym._keys, [5]);
    await sleep(300);
    check('door injected', (await readBytes(mapAddr + doorIdx, 1))[0] === CT_DOOR);

    let opened = false;
    let doorSfx = false;
    for (let attempt = 0; attempt < 10 && !opened; attempt++) {
        /* Poll the APU while the direction is held: the door body only lasts
         * about 0.6 s, and the MCP round-trip is ~100 ms per sample. */
        await callTool('mesen_input_override', { action: 'set', port: 0, buttons: door.name });
        for (let i = 0; i < 12 && !doorSfx; i++) {
            doorSfx = await doorPulseActive();
            if (!doorSfx) await sleep(40);
        }
        await callTool('mesen_input_override', { action: 'set', port: 0, buttons: '' });
        await sleep(180);
        opened = (await rd('_keys')) < 5;
    }
    check('door opens with a key', opened, `keys=${await rd('_keys')}`);
    const doorCell = (await readBytes(mapAddr + doorIdx, 1))[0];
    check('door cell is empty (or Robbo already entered it)',
        doorCell === CT_EMPTY || doorCell === CT_ROBBO, `cell=${doorCell}`);

    /* The NES door SFX is the Atari 25% pulse body on pulse 2 (plus a triangle
     * fundamental) and a few noise accents.  No CH3 wave data is copied, so
     * $FF30 (the UxROM bank register) is never touched. */
    check('door SFX drives the NES 25% pulse layer', doorSfx);

    const frames = new Set();
    let hung = false;
    for (let i = 0; i < 6; i++) {
        await sleep(200);
        frames.add(await rd('_anim_frame'));
        if (await inHangLoop()) hung = true;
    }
    check('game keeps ticking after the door', frames.size > 1, `anim=${[...frames].join(',')}`);
    check('CPU is not in the crt0 hang loop', !hung);

    await press(door.name, 300);
    await sleep(500);
    const nx = await rd('_robbo_x');
    const ny = await rd('_robbo_y');
    check('Robbo walks into the opened cell', nx === door.nx && ny === door.ny,
        `robbo=${nx},${ny} expected=${door.nx},${door.ny}`);
    check('still not in the hang loop', !(await inHangLoop()), await cpuState());

    finish();
}

function finish() {
    if (failures) {
        console.log(`NES door test FAILED (${failures})`);
        process.exitCode = 1;
    } else {
        console.log('NES door test passed');
    }
}

main().catch(err => {
    console.error(err.message);
    process.exitCode = 1;
});
