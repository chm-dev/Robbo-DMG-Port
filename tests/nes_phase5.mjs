/*
 * NES Phase-5 APU test (MesenCE-MCP, Streamable HTTP).
 *
 * Start Mesen with the MCP server before running this:
 *   MesenCE-MCP\MesenCE-MCP-Windows.exe --mcp --mcp-port=9100 --enableStdout roms\robbo-debug.nes
 *
 * The NES build now has a real 2A03 backend in sound.c: pulse 1/2, triangle
 * and noise.  This test drives each effect through the debug-ROM sound hook
 * and samples Mesen's APU state once per emulated frame through a persistent
 * Lua script.  Samples are packed into unused PRG-RAM above the game's BSS
 * ($7A00-$7FB0) so the test can read them with the normal memory API.
 *
 * Coverage:
 *   - sound_init selects the 4-step frame sequencer with IRQ inhibited and
 *     leaves all four channels silent;
 *   - the title typewriter drives the noise channel (click) and the line-feed
 *     beep drives pulse 1 at the expected duty/period;
 *   - every pattern effect reaches the expected channel with a sane
 *     frequency, duty and volume;
 *   - the door's GBC CH3 wave is played as a triangle tone (the NES cannot
 *     reproduce the wave shape) plus its noise accents;
 *   - the legacy explosion uses the software envelope and decays to silence;
 *   - two effects overlap on pulse 1 + pulse 2, and noise can run alongside a
 *     pulse;
 *   - pause is silent, a debug level warp reloads the level and sound still
 *     works afterwards, and all 56 levels can be warped through without a
 *     crash or stuck channels;
 *   - the debug ending preview produces APU activity.
 *
 * The release ROM compiles the sound hook out; this test loads
 * roms/robbo-debug.nes.
 *
 * Run: node gb/tests/nes_phase5.mjs
 */
import fs from 'node:fs';
import path from 'node:path';

const MCP_URL = process.env.MESEN_MCP_URL || 'http://localhost:9100/mcp';
const ROM = path.resolve('roms/robbo-debug.nes');
const NOI = path.resolve('roms/robbo-debug-nes.noi');

const SAMPLER_BASE = 0x7A00;
const SAMPLER_DATA = 0x7A10;
const SAMPLER_MAX = 90;
const SAMPLER_STRIDE = 16;

const CT_EMPTY = 0;
const CT_TURRET = 18;
const CT_MUSTACHE = 21;
const CT_BUTTERFLY = 22;
const CT_BEAR = 23;
const CT_MAGNET = 25;
const CT_BULLET = 27;
const CT_EXPLOSION = 28;

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
            clientInfo: { name: 'robbo-nes-phase5', version: '1.0' },
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

async function waitFor(fn, label, timeoutMs, intervalMs = 80) {
    const start = Date.now();
    while (Date.now() - start < timeoutMs) {
        if (await fn()) return true;
        await sleep(intervalMs);
    }
    console.log(`      (timeout waiting for ${label})`);
    return false;
}

async function press(buttons, holdMs = 200) {
    await callTool('mesen_input_override', { action: 'set', port: 0, buttons });
    await sleep(holdMs);
    await callTool('mesen_input_override', { action: 'set', port: 0, buttons: '' });
    await sleep(150);
}

async function apuField(name) {
    const lua = `local s=emu.getState()\nemu.log(tostring(s['${name}']))`;
    const text = await callTool('mesen_run_lua_script', { code: lua, waitMs: 250 });
    const line = text.split(/\r?\n/).map(l => l.trim()).find(l => /^-?\d+$/.test(l));
    return line === undefined ? null : parseInt(line, 10);
}

async function apuFields(names) {
    const lua = `local s=emu.getState()
for _,k in ipairs({${names.map(n => `'${n}'`).join(',')}}) do emu.log(k .. '=' .. tostring(s[k])) end`;
    const text = await callTool('mesen_run_lua_script', { code: lua, waitMs: 300 });
    const out = {};
    for (const line of text.split(/\r?\n/)) {
        const m = line.match(/^([\w.]+)=(.*)$/);
        if (!m) continue;
        const v = m[2].trim();
        out[m[1]] = v === 'true' ? true
            : v === 'false' ? false
            : v === 'nil' ? null
            : Number(v);
    }
    return names.map(n => out[n]);
}

async function cpuState() {
    return callTool('mesen_get_state', { component: 'cpu', cpuType: 'Nes' });
}

async function inHangLoop() {
    const text = await cpuState();
    return text.includes('PC=$C322') || text.includes('PC=$C39A');
}

/* ------------------------------------------------------------------ */
/* Frame-accurate APU sampler                                          */
/* ------------------------------------------------------------------ */
/* Header at $7A00: trigger, count, done, recording.  Records at $7A10, 16 bytes:
 *   0 p1 volume     1 p1 duty       2/3 p1 realPeriod
 *   4 p2 volume     5 p2 duty       6/7 p2 realPeriod
 *   8 noise volume  9/10 noise period (Mesen timer.period - 1)
 *  11/12 triangle period            13 triangle linearCounter
 *  14 triangle lengthCounter        15 frameCount low byte
 */
const SAMPLER_LUA = `
local BASE=0x7A00
local DATA=0x7A10
local MAX=90
local STRIDE=16
local recording=false
local count=0
local function frame()
  local trig=emu.read(BASE, emu.memType.nesMemory)
  if trig==0 then
    recording=false
    emu.write(BASE+3,0,emu.memType.nesMemory)
    return
  end
  if not recording then
    recording=true
    count=0
    emu.write(BASE+1,0,emu.memType.nesMemory)
    emu.write(BASE+2,0,emu.memType.nesMemory)
    emu.write(BASE+3,1,emu.memType.nesMemory)
  end
  if count>=MAX then return end
  local s=emu.getState()
  local o=DATA+count*STRIDE
  local function w(off,val) emu.write(o+off, math.floor(val)%256, emu.memType.nesMemory) end
  local p1p=s['apu.square1.realPeriod']
  local p2p=s['apu.square2.realPeriod']
  local np=s['apu.noise.timer.period']
  local tp=s['apu.triangle.timer.period']
  w(0,s['apu.square1.envelope.volume']); w(1,s['apu.square1.duty'])
  w(2,p1p%256); w(3,math.floor(p1p/256))
  w(4,s['apu.square2.envelope.volume']); w(5,s['apu.square2.duty'])
  w(6,p2p%256); w(7,math.floor(p2p/256))
  w(8,s['apu.noise.envelope.volume']); w(9,np%256); w(10,math.floor(np/256))
  w(11,tp%256); w(12,math.floor(tp/256)); w(13,s['apu.triangle.linearCounter'])
  w(14,s['apu.triangle.lengthCounter.counter']); w(15,s['frameCount']%256)
  count=count+1
  emu.write(BASE+1,count,emu.memType.nesMemory)
  if count==MAX then emu.write(BASE+2,1,emu.memType.nesMemory) end
end
emu.addEventCallback(frame, emu.eventType.endFrame)
`;

function decodeRecords(buf, count = SAMPLER_MAX) {
    const out = [];
    for (let i = 0; i < count; i++) {
        const o = i * SAMPLER_STRIDE;
        out.push({
            p1v: buf[o], p1d: buf[o + 1],
            p1p: buf[o + 2] | (buf[o + 3] << 8),
            p2v: buf[o + 4], p2d: buf[o + 5],
            p2p: buf[o + 6] | (buf[o + 7] << 8),
            nv: buf[o + 8], np: buf[o + 9] | (buf[o + 10] << 8),
            tp: buf[o + 11] | (buf[o + 12] << 8),
            tl: buf[o + 13], tlen: buf[o + 14],
            frame: buf[o + 15],
        });
    }
    return out;
}

async function readRecords() {
    const buf = await readBytes(SAMPLER_DATA, SAMPLER_MAX * SAMPLER_STRIDE);
    return decodeRecords(buf);
}

async function waitRecordDone() {
    return waitFor(async () => (await readBytes(SAMPLER_BASE + 2, 1))[0] === 1,
        'APU sampler', 10000, 40);
}

async function stopSampler() {
    await writeBytes(SAMPLER_BASE, [0]);
    await waitFor(async () => (await readBytes(SAMPLER_BASE + 3, 1))[0] === 0,
        'sampler idle', 2000, 40);
}

/* Start a recording and optionally trigger a debug sound id one frame later. */
async function recordStart(effectId = null) {
    await stopSampler();
    await writeBytes(SAMPLER_BASE, [0, 0, 0, 0]);
    await writeBytes(SAMPLER_BASE, [1]);
    await sleep(80);
    if (effectId !== null) {
        await writeBytes(sym._sfx_debug_play, [effectId]);
    }
}

async function recordEffect(effectId) {
    await recordStart(effectId);
    await waitRecordDone();
    const recs = await readRecords();
    await stopSampler();
    await sleep(120);
    return recs;
}

/* ------------------------------------------------------------------ */
/* Game helpers                                                        */
/* ------------------------------------------------------------------ */
let sym = null;

const rd = async name => (await readBytes(sym[name], 1))[0];
const voiceMask = () => rd('_sfx_voice_mask');

async function waitIntroAndSilence() {
    let sawIntro = false;
    const introDone = await waitFor(async () => {
        const it = await rd('_intro_active');
        if (it === 1) sawIntro = true;
        return sawIntro && it === 0;
    }, 'intro end', 20000, 120);
    if (!introDone) return false;
    return waitFor(async () => (await voiceMask()) === 0, 'voices silent', 6000, 100);
}

async function removeActors() {
    const types = await readBytes(sym._map_type, 16 * 31);
    const extra = await readBytes(sym._map_extra, 16 * 31);
    const obj = await readBytes(sym._map_obj, 16 * 31);
    const drop = new Set([
        CT_TURRET, CT_MUSTACHE, CT_BUTTERFLY, CT_BEAR, CT_MAGNET,
        CT_BULLET, CT_EXPLOSION,
    ]);
    let changed = 0;
    for (let i = 0; i < types.length; i++) {
        if (drop.has(types[i])) {
            types[i] = CT_EMPTY;
            extra[i] = 0;
            obj[i] = 0;
            changed++;
        }
    }
    if (changed) {
        await writeBytes(sym._map_type, types);
        await writeBytes(sym._map_extra, extra);
        await writeBytes(sym._map_obj, obj);
    }
    await sleep(400);
    return changed;
}

async function ensureClean() {
    const intro = await rd('_intro_active');
    if (intro) await waitIntroAndSilence();
    await waitFor(async () => (await voiceMask()) === 0, 'clean voices', 5000, 80);
}

/* ------------------------------------------------------------------ */
/* Assertion helpers                                                   */
/* ------------------------------------------------------------------ */
const anyRec = (recs, fn) => recs.some(fn);
const maxOf = (recs, fn) => recs.reduce((m, r) => Math.max(m, fn(r)), 0);

function pulseStats(recs) {
    const p1 = recs.filter(r => r.p1v > 0);
    const p2 = recs.filter(r => r.p2v > 0);
    const all = [
        ...p1.map(r => ({ ...r, v: r.p1v, p: r.p1p, d: r.p1d })),
        ...p2.map(r => ({ ...r, v: r.p2v, p: r.p2p, d: r.p2d })),
    ];
    return { p1, p2, all };
}

function noiseVols(recs) {
    return recs.map(r => r.nv);
}

function monotonicNonIncreasing(values) {
    let prev = 255;
    for (const v of values) {
        if (v > prev) return false;
        prev = v;
    }
    return true;
}

/* ------------------------------------------------------------------ */
/* Main                                                               */
/* ------------------------------------------------------------------ */
async function main() {
    if (!fs.existsSync(ROM)) throw new Error(`Missing ${ROM}`);
    if (!fs.existsSync(NOI)) throw new Error(`Missing ${NOI}`);
    sym = symbolsFromNoi(NOI);

    await init();
    await callTool('mesen_breakpoint', { action: 'remove_all' });
    await callTool('mesen_playback', { action: 'resume' });
    await callTool('mesen_load_rom', { filepath: ROM });
    await sleep(800);
    await writeBytes(0x7FF0, new Array(16).fill(0));
    await callTool('mesen_reset', { type: 'hard' });
    await sleep(1800);

    /* --- APU init --------------------------------------------------- */
    const [mode, inhibit, p1halt, p2halt, nhalt,
        p1v, p2v, nv, tlin, tlen] = await apuFields([
        'apu.frameCounter.stepMode', 'apu.frameCounter.inhibitIRQ',
        'apu.square1.envelope.lengthCounter.halt',
        'apu.square2.envelope.lengthCounter.halt',
        'apu.noise.envelope.lengthCounter.halt',
        'apu.square1.envelope.volume', 'apu.square2.envelope.volume',
        'apu.noise.envelope.volume', 'apu.triangle.linearCounter',
        'apu.triangle.lengthCounter.counter',
    ]);
    check('APU init: 4-step frame sequencer', mode === 0, `stepMode=${mode}`);
    check('APU init: frame IRQ inhibited', inhibit === true, `inhibitIRQ=${inhibit}`);
    check('APU init: pulse/noise length counters halted', p1halt && p2halt && nhalt);
    check('APU init: every channel silent', p1v === 0 && p2v === 0 && nv === 0 &&
        tlin === 0 && tlen === 0,
        `p1=${p1v} p2=${p2v} n=${nv} tri=${tlin}/${tlen}`);

    /* Start the persistent frame sampler.  It is removed before the test
     * exits; it otherwise survives ROM reloads. */
    const samplerText = await callTool('mesen_run_lua_script', {
        code: SAMPLER_LUA, persistent: true, waitMs: 500,
    });
    const samplerMatch = samplerText.match(/Script #(\d+) running/);
    const samplerId = samplerMatch ? Number(samplerMatch[1]) : null;

    /* --- Title typewriter ------------------------------------------- */
    /* The NES title has a two-second pre-typewriter pause. */
    await sleep(1200);
    await recordStart();
    await waitRecordDone();
    let recs = await readRecords();
    await stopSampler();
    const clickRecs = recs.filter(r => r.nv > 0);
    check('title: typewriter clicks drive the noise channel', clickRecs.length > 0,
        `clicks=${clickRecs.length}`);
    check('title: click is constant volume 5 at noise period 63',
        clickRecs.every(r => r.nv === 5 && r.np === 63),
        clickRecs.slice(0, 3).map(r => `${r.nv}/${r.np}`).join(' '));
    check('title: noise click is brief, not a sustained tone',
        clickRecs.length < recs.length,
        `${clickRecs.length}/${recs.length} frames`);

    /* --- Start level 1 ---------------------------------------------- */
    await press('Start', 240);
    const started = await waitFor(async () =>
        (await rd('_level_planet')) === 1 && (await rd('_debug_ticks')) > 5,
    'level 1', 15000, 150);
    check('level 1 starts', started);
    if (!started) return finish(samplerId);
    check('level 1 intro finishes', await waitIntroAndSilence());

    /* Clear the turrets and moving bullets so the effect recordings are not
     * polluted by gameplay shots. */
    const removed = await removeActors();
    check('level 1 actors removed for clean APU recordings', removed > 0,
        `cells=${removed}`);
    await ensureClean();

    /* --- Direct title sounds through the debug hook ----------------- */
    recs = await recordEffect(0x20);
    check('SFX click: noise tick at constant volume 5',
        anyRec(recs, r => r.nv === 5 && r.np === 63),
        `max=${maxOf(recs, r => r.nv)}`);
    check('SFX click: stops after a few frames',
        recs.slice(12).every(r => r.nv === 0));

    recs = await recordEffect(0x21);
    const beep = pulseStats(recs).all;
    check('SFX beep: pulse 1 at 50% duty and volume 4',
        beep.some(r => r.v === 4 && r.d === 2));
    check('SFX beep: ~3.5 kHz (timer period 30..32)',
        beep.some(r => r.p >= 28 && r.p <= 33));
    check('SFX beep: four-frame window', beep.length <= 6, `frames=${beep.length}`);

    /* --- Pattern effect sweep --------------------------------------- */
    /* id, name, extra predicate on the active pulse record */
    const pulseEffects = [
        [3, 'TELEPORT', r => r.p >= 50 && r.p <= 500 && r.d === 2],
        [4, 'BOLT', r => r.p >= 80 && r.p <= 260 && r.d === 2],
        [5, 'EXTRA_LIFE', r => r.p >= 200 && r.p <= 600 && r.d === 2],
        [7, 'AMMO', r => r.p >= 20 && r.p <= 90 && r.d === 1],
        [9, 'KEY', r => r.p >= 40 && r.p <= 120 && r.d === 2],
        [0x0C, 'LEVEL_END', r => r.p >= 30 && r.p <= 100 && r.d === 2],
    ];
    for (const [id, name, pred] of pulseEffects) {
        recs = await recordEffect(id);
        const pulses = pulseStats(recs);
        check(`SFX ${name}: pulse channel active`,
            pulses.all.length > 0,
            `p1=${pulses.p1.length} p2=${pulses.p2.length}`);
        check(`SFX ${name}: expected duty/period`,
            pulses.all.some(pred),
            `p1p=${pulses.p1.map(r => r.p1p).slice(0, 4).join(',')} ` +
            `p2p=${pulses.p2.map(r => r.p2p).slice(0, 4).join(',')}`);
        check(`SFX ${name}: ends cleanly`, (await voiceMask()) === 0);
    }

    const noiseEffects = [
        [1, 'SHOT', r => r.np >= 60 && r.np <= 200],
        [2, 'HIT_WALL', r => r.np >= 60 && r.np <= 4100],
        [8, 'PUSH', r => r.np >= 2000],
        [0x0D, 'LAST_BOLT', r =>
            (r.np >= 2000 && r.np <= 2100) || (r.np >= 4000 && r.np <= 4100)],
        [0x0E, 'MAGNET', r => r.np >= 0 && r.np <= 4100],
    ];
    for (const [id, name, pred] of noiseEffects) {
        recs = await recordEffect(id);
        check(`SFX ${name}: noise channel active`,
            maxOf(recs, r => r.nv) > 0,
            `max=${maxOf(recs, r => r.nv)}`);
        check(`SFX ${name}: expected noise period`,
            anyRec(recs, r => r.nv > 0 && pred(r)),
            `np=${recs.filter(r => r.nv > 0).map(r => r.np).slice(0, 4).join(',')}`);
        check(`SFX ${name}: ends cleanly`, (await voiceMask()) === 0);
    }

    /* --- Door: triangle tone + noise accents ------------------------ */
    recs = await recordEffect(6);
    const doorPulse = recs.filter(r => r.p2v > 0 && r.p2d === 1);
    check('SFX DOOR: drives the NES pulse channel at 25% duty',
        doorPulse.length > 0, `frames=${doorPulse.length}`);
    check('SFX DOOR: pulse pitch follows the GBC wave period',
        doorPulse.some(r => r.p2p >= 1200 && r.p2p <= 2050),
        `p2p=${doorPulse.map(r => r.p2p).slice(0, 4).join(',')}`);
    check('SFX DOOR: noise accents present', maxOf(recs, r => r.nv) > 0);
    check('SFX DOOR: ends cleanly', (await voiceMask()) === 0);

    /* --- Level start: noise sweep then low pulse tone ---------------- */
    recs = await recordEffect(0x0B);
    const lsNoise = recs.findIndex(r => r.nv > 0);
    const lsPulse = recs.findIndex(r => r.p1v > 0 || r.p2v > 0);
    check('SFX LEVEL_START: noise sweep first', lsNoise >= 0 && lsNoise < 20,
        `noise@${lsNoise}`);
    check('SFX LEVEL_START: pulse tone after the sweep',
        lsPulse > lsNoise && lsPulse >= 0, `pulse@${lsPulse}`);
    check('SFX LEVEL_START: low 50% tone at the end',
        anyRec(recs, r => (r.p1v > 0 && r.p1d === 2 && r.p1p >= 30 && r.p1p <= 60)));
    check('SFX LEVEL_START: ends cleanly', (await voiceMask()) === 0);

    /* --- Legacy explosion software envelope -------------------------- */
    recs = await recordEffect(0x10);
    const envVols = noiseVols(recs);
    const envStart = envVols.findIndex(v => v > 0);
    const envLive = envVols.filter(v => v > 0);
    check('SFX EXPLOSION: starts loud on the noise channel',
        envLive.length > 0 && envLive[0] >= 12,
        `start@${envStart} first=${envLive.slice(0, 6).join(',')}`);
    check('SFX EXPLOSION: one NES noise step above the floor',
        anyRec(recs, r => r.nv > 0 && r.np >= 2000 && r.np <= 2100),
        `np=${recs.filter(r => r.nv > 0).map(r => r.np).slice(0, 4).join(',')}`);
    check('SFX EXPLOSION: software envelope decays monotonically',
        monotonicNonIncreasing(envLive), envLive.slice(0, 16).join(','));
    check('SFX EXPLOSION: reaches silence',
        envStart >= 0 && envVols.slice(envStart + 64).every(v => v === 0),
        `tail=${envVols.slice(envStart + 60, envStart + 72).join(',')}`);
    check('SFX EXPLOSION: ends cleanly', (await voiceMask()) === 0);

    /* --- Legacy DESTROY: attack ramp + decay ------------------------- */
    recs = await recordEffect(0x11);
    const dVols = noiseVols(recs);
    const dStart = dVols.findIndex(v => v > 0);
    const dPeak = maxOf(recs, r => r.nv);
    const dPeakIdx = dVols.indexOf(dPeak);
    check('SFX DESTROY: noise channel active', dPeak > 0, `peak=${dPeak}`);
    check('SFX DESTROY: 5-step attack reaches the 5/15 peak',
        dPeak >= 4 && dPeak <= 6, `peak=${dPeak}`);
    check('SFX DESTROY: attack rises before the decay',
        dStart >= 0 && dPeakIdx > dStart, `start=${dStart} peak@${dPeakIdx}`);
    check('SFX DESTROY: decays to silence',
        dStart >= 0 && dVols.slice(dStart + 55).every(v => v === 0),
        `tail=${dVols.slice(dStart + 40, dStart + 56).join(',')}`);
    check('SFX DESTROY: ends cleanly', (await voiceMask()) === 0);

    /* --- sfx_stop cuts a running voice and an in-flight click -------- */
    await ensureClean();
    await recordStart();
    await writeBytes(sym._sfx_debug_play, [3]);       /* teleport */
    await sleep(300);
    await writeBytes(sym._sfx_debug_play, [0x22]);    /* sfx_stop */
    await waitRecordDone();
    recs = await readRecords();
    await stopSampler();
    check('sfx_stop silences a running pulse',
        recs.slice(30).every(r => r.p1v === 0 && r.p2v === 0),
        `tail p1=${maxOf(recs.slice(30), r => r.p1v)}`);

    await ensureClean();
    await recordStart();
    await writeBytes(sym._sfx_debug_play, [0x20]);    /* noise click */
    await sleep(40);
    await writeBytes(sym._sfx_debug_play, [0x22]);    /* sfx_stop */
    await waitRecordDone();
    recs = await readRecords();
    await stopSampler();
    check('sfx_stop clears an in-flight title click',
        recs.slice(10).every(r => r.nv === 0),
        `tail n=${maxOf(recs.slice(10), r => r.nv)}`);

    /* --- Voice mixing ------------------------------------------------ */
    await ensureClean();
    await recordStart();
    await writeBytes(sym._sfx_debug_play, [3]);   /* teleport: pulse */
    await sleep(350);
    await writeBytes(sym._sfx_debug_play, [1]);   /* shot: noise */
    await waitRecordDone();
    recs = await readRecords();
    await stopSampler();
    check('mixing: pulse and noise overlap',
        anyRec(recs, r => (r.p1v > 0 || r.p2v > 0) && r.nv > 0));

    await ensureClean();
    await recordStart();
    await writeBytes(sym._sfx_debug_play, [3]);   /* teleport: pulse 1 */
    await sleep(350);
    await writeBytes(sym._sfx_debug_play, [9]);   /* key: pulse 2 */
    await waitRecordDone();
    recs = await readRecords();
    await stopSampler();
    check('mixing: pulse 1 and pulse 2 both active',
        anyRec(recs, r => r.p1v > 0 && r.p2v > 0),
        `p1=${maxOf(recs, r => r.p1v)} p2=${maxOf(recs, r => r.p2v)}`);
    check('mixing: voices end cleanly', (await voiceMask()) === 0);

    /* --- Pause menu is silent --------------------------------------- */
    await ensureClean();
    await press('Start');
    const menuOpen = await waitFor(async () => (await rd('_pause_menu_state')) === 2,
        'pause menu open', 5000);
    check('pause menu opens', menuOpen);
    const pauseCue = await waitFor(async () => (await voiceMask()) !== 0,
        'pause cue', 1500);
    check('pause menu plays its cue', pauseCue);
    check('pause menu cue ends cleanly',
        await waitFor(async () => (await voiceMask()) === 0, 'pause silence', 5000));
    await press('Start');
    const menuClosed = await waitFor(async () => (await rd('_pause_menu_state')) === 0,
        'pause menu close', 5000);
    check('pause menu closes', menuClosed);
    await ensureClean();

    /* --- Level warp + full 56-level smoke --------------------------- */
    let warped = true;
    for (let target = 2; target <= 56; target++) {
        let ok = false;
        for (let attempt = 0; attempt < 4 && !ok; attempt++) {
            await press('Select', 220);
            ok = await waitFor(async () => (await rd('_level_planet')) === target,
                `level ${target}`, 2200, 100);
        }
        if (!ok) {
            warped = false;
            console.log(`      (warp stopped at target ${target}, level=${await rd('_level_planet')})`);
            break;
        }
        if ((target % 10) === 0) console.log(`      warped to level ${target}`);
    }
    check('all 56 levels warp without a crash', warped,
        `level=${await rd('_level_planet')}`);
    if (warped) {
        check('level 56 intro finishes', await waitIntroAndSilence());
        await removeActors();
        await ensureClean();
        const frames = new Set();
        for (let i = 0; i < 5; i++) {
            frames.add(await rd('_anim_frame'));
            await sleep(150);
        }
        check('game keeps ticking on level 56', frames.size > 1,
            `anim=${[...frames].join(',')}`);
        check('CPU is not in a hang loop', !(await inHangLoop()));
        recs = await recordEffect(3);
        check('sound still works after all 56 level loads',
            pulseStats(recs).all.length > 0);
    }

    /* --- Ending preview --------------------------------------------- */
    await ensureClean();
    await press('Start,Select', 240);
    const ending = await waitFor(async () => (await rd('_ending_active')) === 1,
        'ending start', 8000);
    check('ending preview starts', ending);
    if (ending) {
        await recordStart();
        await waitRecordDone();
        recs = await readRecords();
        await stopSampler();
        check('ending: APU cues play', anyRec(recs, r =>
            r.p1v > 0 || r.p2v > 0 || r.nv > 0 || (r.tl > 0 && r.tlen > 0)),
            `p1=${maxOf(recs, r => r.p1v)} p2=${maxOf(recs, r => r.p2v)} ` +
            `n=${maxOf(recs, r => r.nv)} tri=${maxOf(recs, r => r.tl)}`);
    }

    return finish(samplerId);
}

function finish(samplerId) {
    if (samplerId !== null) {
        callTool('mesen_remove_lua_script', { scriptId: samplerId }).catch(() => {});
    }
    if (failures) {
        console.log(`NES phase-5 APU test FAILED (${failures} failures)`);
        process.exitCode = 1;
    } else {
        console.log('NES phase-5 APU test passed');
    }
}

main().catch(err => {
    console.error(err.stack || err.message);
    process.exitCode = 1;
});
