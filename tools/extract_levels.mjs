#!/usr/bin/env node
/*
 * Extract the 56 Robbo levels from robboJS/game.html.
 *
 * The source format creates cell *types* from the ASCII map and then copies
 * fields from [additional] records onto those cells.  Several records refer to
 * cells of a different type; those records only add inert fields.  This script
 * reproduces the JS loader (parseMaps + Controller.loadLevel) in portable JS so
 * the C port gets the same initial runtime state, including:
 *
 *   - teleport group/index link resolution (last duplicate index wins)
 *   - map-generated bear CW/CCW records appended after parsed extras
 *   - self-linking teleports with no additional record
 *   - Screw counting only while game.levelLoaded is false
 *
 * Outputs:
 *   gb/tests/fixtures/levels.json          raw + canonical final state
 *   gb/tests/fixtures/levels.summary.json  counts and hashes
 *
 * Run: node gb/tools/extract_levels.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..');
const htmlPath = path.join(repoRoot, 'robboJS', 'game.html');
const outDir = path.join(repoRoot, 'gb', 'tests', 'fixtures');

const ASCII_TYPES = {
  'R': 'Robbo',
  '.': 'Empty', ' ': 'Empty',
  'O': 'Walls', 'I': 'Walls', 'o': 'Walls', '-': 'Walls',
  'Q': 'Walls', 'q': 'Walls', 'P': 'Walls', 'p': 'Walls',
  'S': 'Walls', 's': 'Walls', 'y': 'Walls', 'Y': 'Walls',
  'z': 'Walls', 'Z': 'Walls', 'J': 'Walls', 'j': 'Walls', 'i': 'Walls',
  'H': 'Ground', '#': 'Stone', '~': 'PushableStone', 'D': 'Door',
  '!': 'Spaceship', '?': 'Question', 'b': 'Bomb', '%': 'Key',
  'T': 'Screw', 'x': 'Screw', '}': 'Turrel', "'": 'Ammo',
  '&': 'Teleport', '^': 'Mustache', 'V': 'Butterfly',
  '@': 'Bear', '*': 'Bear', 'M': 'Magnet', '=': 'Lava',
  'e': 'Explosion', '|': 'Bullet',
};

const WALL_GLYPHS = 'OIo-QqPpSsyYzZJji';
const ACTION_TYPES = new Set([
  'Robbo', 'Turrel', 'Teleport', 'Mustache', 'Bear', 'Butterfly',
  'Magnet', 'Lava', 'Spaceship', 'Bullet', 'Explosion',
]);

function parseMaps(html) {
  const match = html.match(/<div[^>]*id="maps"[^>]*>([\s\S]*?)<\/div>/i);
  if (!match) throw new Error('Could not find the #maps block in game.html');

  const text = match[1].replace(/&amp;/g, '&').replace(/\r/g, '');
  const lines = text.split('\n').map(line => line.trim());

  const maps = [];
  let level = null;
  let current = null;
  let data = [];

  const finishSection = () => {
    if (!level || current === null) return;
    if (current === 'data') {
      // The JS loader stores [data] under the key "map".
      level.map = data.join('\n');
    } else if (current === 'additional') {
      // The JS loader stores [additional] under the key "data".
      level.data = convertData(data);
      level.additionalRaw = data.slice();
    } else {
      level[current] = data.slice();
    }
  };

  for (const line of lines) {
    const section = line.match(/^\[([a-z_]*)\]$/);
    if (section) {
      finishSection();
      current = section[1];
      if (current === 'level') {
        if (level) maps.push(level);
        level = { sections: {} };
      }
      data = [];
    } else {
      data.push(line);
    }
  }
  finishSection();
  if (level) maps.push(level);

  return { maps, totalLines: lines.length };
}

/** Port of convertData() in game.html. */
function convertData(data) {
  return data.slice(1).map(str => {
    const tokens = str.split('.');
    const out = {
      x: tokens[0] | 0,
      y: tokens[1] | 0,
      data: tokens.slice(3),
    };

    if (tokens[2] === '&') {
      const ids = [];
      data.slice(1).map(el => {
        el = el.split('.');
        return el[2] === '&' && (el[3]) === tokens[3] ? el : undefined;
      }).filter(el => el !== undefined)
        .forEach(el => { ids[el[4]] = el; });

      const next = ids[((tokens[4] | 0) + 1) % ids.length];
      if (!next) {
        throw new Error(`Teleport ${str} has no next member in group ${tokens[3]} (ids.length=${ids.length})`);
      }
      out.data = {
        teleportX: next[0] | 0,
        teleportY: next[1] | 0,
      };
    } else if (tokens[2] === '}') {
      out.data = {
        direction: tokens[3] | 0,
        moveDirection: tokens[4] | 0,
        bulletType: ['gun', 'laser', 'antimatter'][tokens[5] | 0],
        movable: tokens[6] | 0,
        rotatable: tokens[7] | 0,
      };
    } else if (tokens[2] === '^') {
      out.data = {
        direction: tokens[3] | 0,
        fire: (tokens[5] | 0) ? true : false,
      };
    } else if (tokens[2] === '@' || tokens[2] === '*') {
      out.data = {
        direction: tokens[3] | 0,
        clockwise: tokens[2] === '@',
      };
    } else if (tokens[2] === 'M') {
      out.data = { direction: tokens[3] | 0 };
    } else if (tokens[2] === '=') {
      out.data = { direction: tokens[3] | 0 };
    }
    return out;
  });
}

/** Small deterministic RNG used for initial question payloads. */
function makeRng(seed = 0xace1) {
  let state = seed;
  return () => {
    state ^= (state << 7) & 0xffff;
    state ^= state >> 9;
    state ^= (state << 8) & 0xffff;
    return (state & 0xffff) / 0x10000;
  };
}

function makeGame() {
  return {
    screw: 0,
    levelLoaded: false,
    robbo: null,
    actionObjects: [],
    cells: [],
    randomCalls: 0,
  };
}

function makeCell(type, x, y, game, extra = {}) {
  const cell = { type, x, y };
  Object.assign(cell, extra);

  // Defaults that live on the JS prototype (not own properties).
  switch (type) {
    case 'Robbo':
      cell.direction = 1;
      cell.stepAnimation = 0;
      cell.keys = 0;
      cell.ammo = 0;
      cell.inited = true;
      cell.noMove = false;
      game.robbo = cell;
      game.actionObjects.push(cell);
      break;
    case 'Screw':
      if (!game.levelLoaded) game.screw++;
      break;
    case 'Question':
      cell.randomObject = (game.rng() * 11) | 0;
      game.randomCalls++;
      break;
    case 'Bear':
      game.actionObjects.push(cell);
      cell.direction = 0;
      cell.stepAnimation = 1 % 4;
      cell.animationFrame = 0;
      cell.clockwise = false;
      cell.lastSkipped = false;
      cell.skipStep = 0;
      break;
    case 'Mustache':
      game.actionObjects.push(cell);
      cell.direction = 0;
      cell.stepAnimation = 1 % 4;
      cell.animationFrame = 0;
      cell.fire = false;
      cell.justShootted = false;
      cell.innerSkip = false;
      cell.bulletType = 'gun';
      break;
    case 'Turrel':
      game.actionObjects.push(cell);
      cell.direction = 0;
      cell.moveDirection = 0;
      cell.bulletType = 'gun';
      cell.movable = 0;
      cell.rotatable = 0;
      cell.justMoved = false;
      cell.justShootted = false;
      break;
    case 'Teleport':
      game.actionObjects.push(cell);
      cell.teleportX = x;
      cell.teleportY = y;
      break;
    case 'Magnet':
      game.actionObjects.push(cell);
      cell.direction = 0;
      break;
    case 'Lava':
      game.actionObjects.push(cell);
      cell.direction = 0;
      break;
    case 'Spaceship':
      game.actionObjects.push(cell);
      cell.fromQuestion = false;
      break;
    case 'Butterfly':
      game.actionObjects.push(cell);
      cell.direction = 0;
      break;
    case 'Bullet':
      game.actionObjects.push(cell);
      cell.bulletType = 'gun';
      break;
    case 'Explosion':
      game.actionObjects.push(cell);
      break;
    default:
      break;
  }

  // afterInit() runs after data is applied in ObjectFactory, so walls handle
  // ascii/img there; this is only the ascii -> img direction for map cells.
  if (type === 'Walls') {
    cell.img = WALL_GLYPHS.indexOf(cell.ascii);
  }
  return cell;
}

function getCell(game, x, y) {
  const row = game.cells[y];
  return (row && row[x]) || { type: 'Out', x, y };
}

function loadLevel(level, rng) {
  const rows = level.map.split('\n');
  const height = rows.length;
  const width = Math.max(...rows.map(row => row.length));
  const game = makeGame();
  game.rng = rng;
  game.cells = Array.from({ length: height }, () => new Array(width).fill(null));

  for (let y = 0; y < height; y++) {
    const row = rows[y];
    for (let x = 0; x < row.length; x++) {
      const ch = row[x];
      const type = ASCII_TYPES[ch];
      if (!type) throw new Error(`Unknown map character ${JSON.stringify(ch)} at ${x},${y}`);
      const cell = makeCell(type, x, y, game, { ascii: ch });
      game.cells[y][x] = cell;
      if (ch === '@') level.data.push({ x, y, data: { clockwise: true } });
      else if (ch === '*') level.data.push({ x, y, data: { clockwise: false } });
    }
  }

  // Apply parsed extras first, then the map-generated bear records appended
  // above.  This is the order R.apply sees in Controller.loadLevel.
  for (const record of level.data) {
    const cell = getCell(game, record.x, record.y);
    Object.assign(cell, record.data);
  }

  game.levelLoaded = true;

  return { game, width, height };
}

const MEANINGFUL_FIELDS = {
  Walls: ['img', 'ascii'],
  Turrel: ['direction', 'moveDirection', 'bulletType', 'movable', 'rotatable'],
  Teleport: ['teleportX', 'teleportY'],
  Mustache: ['direction', 'fire'],
  Bear: ['direction', 'clockwise'],
  Magnet: ['direction'],
  Lava: ['direction'],
  Robbo: ['direction', 'keys', 'ammo'],
  Question: ['randomObject'],
  Spaceship: ['fromQuestion'],
};

function canonicalFields(cell) {
  const out = [];
  const fields = MEANINGFUL_FIELDS[cell.type] || [];
  for (const field of fields) {
    let value = cell[field];
    if (field === 'movable' || field === 'rotatable' || field === 'fire' ||
        field === 'clockwise' || field === 'fromQuestion') {
      value = value ? 1 : 0;
    }
    if (value === undefined) value = 0;
    out.push(value);
  }
  return out;
}

function canonicalLevel(level, loaded) {
  const { game, width, height } = loaded;
  return {
    level: level.number,
    width,
    height,
    colour: level.colour,
    screw: game.screw,
    robbo: [game.robbo.x, game.robbo.y, game.robbo.direction],
    actions: game.actionObjects.map(obj => [obj.type, obj.x, obj.y, ...canonicalFields(obj)]),
    cells: game.cells.map(row => row.map(cell => [cell.type, ...canonicalFields(cell)])),
  };
}

function fnv1a32(text) {
  let hash = 0x811c9dc5 >>> 0;
  for (let i = 0; i < text.length; i++) {
    hash ^= text.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash.toString(16).padStart(8, '0');
}

/** The exact serialization used by the browser oracle. */
function canonicalString(canonical) {
  return JSON.stringify([
    canonical.level,
    canonical.screw,
    canonical.robbo,
    canonical.actions,
    canonical.cells,
  ]);
}

function hashCanonical(value) {
  return fnv1a32(JSON.stringify(value));
}

/* ------------------------------------------------------------------ */
/* Main                                                                */
/* ------------------------------------------------------------------ */

const html = fs.readFileSync(htmlPath, 'utf8');
const { maps } = parseMaps(html);

// Preamble sections (name, last_level, default_level_colour, notes).
const preamble = {};
for (const key of ['name', 'last_level', 'default_level_colour', 'notes']) {
  const found = maps.find(m => m[key]);
  if (found) preamble[key] = found[key];
}

const levels = [];
const usedRng = makeRng();

// Question.randomCfg evaluates R.rand(0,3) once at script load.  Consume the
// same first RNG value here so initial question payloads line up with the JS
// oracle when Math.random is seeded identically.
const questionTurretDirection = (usedRng() * 4) | 0;
const problems = [];

for (let i = 0; i < maps.length; i++) {
  const raw = maps[i];
  const number = Number(raw.level?.[0] ?? i + 1);
  const rowText = raw.map ?? '';
  const rows = rowText.split('\n').filter(Boolean);
  const widths = [...new Set(rows.map(r => r.length))];
  const sizeText = raw.size?.[0] ?? '';

  const level = {
    number,
    colour: raw.colour?.[0] ?? '',
    size: sizeText,
    author: raw.author?.[0] ?? '',
    notes: raw.level_notes?.join('\n') ?? '',
    map: rowText,
    data: raw.data ? raw.data.map(r => ({ x: r.x, y: r.y, data: { ...r.data } })) : [],
    additionalRaw: raw.additionalRaw ?? [],
  };

  // Basic source checks.
  if (widths.length !== 1) problems.push(`L${number}: inconsistent row widths ${widths.join(',')}`);
  if (widths[0] !== 16) problems.push(`L${number}: width ${widths[0]} != 16`);
  if (rows.length !== 31 && rows.length !== 30) problems.push(`L${number}: height ${rows.length}`);
  if (sizeText && sizeText !== `16.${rows.length}`) {
    problems.push(`L${number}: [size] ${sizeText} != 16.${rows.length}`);
  }

  const robboCount = (rowText.match(/R/g) || []).length;
  const exitCount = (rowText.match(/!/g) || []).length;
  if (robboCount !== 1) problems.push(`L${number}: ${robboCount} Robbo cells`);
  if (exitCount !== 1) problems.push(`L${number}: ${exitCount} exit cells`);

  const loaded = loadLevel(level, usedRng);
  const canonical = canonicalLevel(level, loaded);
  levels.push({ ...level, canonical });
}

const summary = {
  generatedAt: new Date().toISOString(),
  source: 'robboJS/game.html',
  lastLevelField: preamble.last_level?.[0] ?? null,
  levelCount: levels.length,
  problems,
  levels: levels.map(l => ({
    level: l.number,
    width: l.canonical.width,
    height: l.canonical.height,
    screws: l.canonical.screw,
    actionObjects: l.canonical.actions.length,
    cellsHash: hashCanonical(l.canonical.cells),
    stateHash: fnv1a32(canonicalString(l.canonical)),
    additionalRecords: l.data.length,
    rawAdditionalRecords: l.additionalRaw.length,
  })),
  totals: {
    mapBytes: levels.reduce((sum, l) => sum + l.canonical.width * l.canonical.height, 0),
    additionalRecords: levels.reduce((sum, l) => sum + l.additionalRaw.length, 0),
    questions: levels.reduce((sum, l) => sum + (l.map.match(/\?/g) || []).length, 0),
    robbo: levels.reduce((sum, l) => sum + (l.map.match(/R/g) || []).length, 0),
    exits: levels.reduce((sum, l) => sum + (l.map.match(/!/g) || []).length, 0),
  },
};

fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, 'levels.json'), JSON.stringify({ preamble, levels }, null, 2));
fs.writeFileSync(path.join(outDir, 'levels.summary.json'), JSON.stringify(summary, null, 2));

console.log(`Extracted ${levels.length} levels -> ${path.relative(repoRoot, outDir)}`);
console.log(`Map bytes: ${summary.totals.mapBytes}`);
console.log(`Additional records: ${summary.totals.additionalRecords}`);
console.log(`Questions: ${summary.totals.questions}, Robbo: ${summary.totals.robbo}, exits: ${summary.totals.exits}`);
if (problems.length) {
  console.log(`\n${problems.length} problem(s):`);
  for (const p of problems) console.log('  - ' + p);
} else {
  console.log('No structural problems found.');
}
