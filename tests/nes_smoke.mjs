/*
 * NES Phase-1 smoke test (MesenCE-MCP, Streamable HTTP).
 *
 * Start Mesen with the MCP server before running this:
 *   MesenCE-MCP\MesenCE-MCP-Windows.exe --mcp --mcp-port=9100 --enableStdout roms\robbo.nes
 *
 * The test checks the build/layout contract that Phase 1 introduced:
 *   - NES 2.0 header, mapper 2 + battery + vertical mirroring,
 *     8 KiB PRG-NVRAM at $6000-$7FFF and 8 KiB CHR-RAM,
 *   - the PRG-RAM window at $6000 is writable,
 *   - BSS is cleared at boot,
 *   - START loads level 1 through the game bank.
 */
import fs from 'node:fs';
import path from 'node:path';

const MCP_URL = process.env.MESEN_MCP_URL || 'http://localhost:9100/mcp';
const ROM = path.resolve('roms/robbo.nes');
const NOI = path.resolve('roms/robbo-nes.noi');

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
            clientInfo: { name: 'robbo-nes-smoke', version: '1.0' },
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

async function main() {
    if (!fs.existsSync(ROM)) throw new Error(`Missing ${ROM}`);
    if (!fs.existsSync(NOI)) throw new Error(`Missing ${NOI}`);
    const romBytes = fs.readFileSync(ROM);
    const sym = symbolsFromNoi(NOI);

    await init();

    // Clear the persistent record, then hard-reset into a fresh boot.
    await callTool('mesen_load_rom', { filepath: ROM });
    await sleep(700);
    await clearSave();
    await callTool('mesen_reset', { type: 'hard' });
    await sleep(1200);

    // Header contract: NES 2.0 is required so FCEUX and MiSTer map the
    // $6000-$7FFF PRG-RAM window.  Both ignore the iNES 1.0 byte-8 size.
    check('header is NES 2.0', romBytes[7] === 0x08, `byte7=0x${romBytes[7].toString(16)}`);
    check('mapper 2 low nibble', (romBytes[6] >> 4) === 2, `byte6=0x${romBytes[6].toString(16)}`);
    check('battery + vertical mirroring', (romBytes[6] & 0x03) === 0x03, `byte6=0x${romBytes[6].toString(16)}`);
    check('8 KiB PRG-NVRAM', (romBytes[10] >> 4) === 7, `byte10=0x${romBytes[10].toString(16)}`);
    check('8 KiB CHR-RAM', (romBytes[11] & 0x0F) === 7, `byte11=0x${romBytes[11].toString(16)}`);

    const header = JSON.parse(await callTool('mesen_get_rom_header'));
    check('Mesen sees NES 2.0', header.format === 'NES 2.0', `format=${header.format}`);
    check('mapper 2 header', header.mapper === 2, `mapper=${header.mapper}`);
    check('battery save bit', header.battery === true);
    check('vertical mirroring (side-by-side nametables)', header.mirroring === 'Vertical', `mirroring=${header.mirroring}`);
    check('BSS cleared at boot', (await readBytes(sym._nes_compat_cpu, 1))[0] === 0);

    await callTool('mesen_write_memory', {
        address: '0x7F00', hexData: 'A5', memoryType: 'NesMemory',
    });
    check('PRG-RAM $6000 window writable', (await readBytes(0x7F00, 1))[0] === 0xA5);

    // START from the title must load level 1 through the banked game core.
    await callTool('mesen_input_override', { action: 'set', port: 0, buttons: 'Start' });
    await sleep(250);
    await callTool('mesen_input_override', { action: 'set', port: 0, buttons: '' });
    await sleep(2200);

    const cells = await readBytes(sym._map_type, 16);
    check('level map loaded', cells[0] === 2 && cells.some(v => v !== 0), cells.slice(0, 4).join(','));
    check('planet is 1', (await readBytes(sym._level_planet, 1))[0] === 1);

    await clearSave();
    if (failures) {
        console.log(`NES smoke FAILED (${failures})`);
        process.exitCode = 1;
    } else {
        console.log('NES smoke passed');
    }
}

main().catch(err => {
    console.error(err.message);
    process.exitCode = 1;
});
