import re, pathlib
root = pathlib.Path('.')
tiles_c = (root/'gb/src/gen/tiles.c').read_text()
bank_c = (root/'gb/src/gen/tiles_bank.c').read_text()

def body(text, name):
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
    m = re.search(re.escape(name) + r'\[[^\]]*\]\s*=\s*\{(.*?)\};', text, re.S)
    return m.group(1)

mt = [int(x) for x in re.findall(r'\b(\d+)\b', body(tiles_c, 'metatile_tiles'))]
ts = [int(x,16) for x in re.findall(r'0x([0-9A-Fa-f]{2})', body(bank_c, 'tileset_data'))]
print('metatile_tiles', len(mt), 'tileset_data', len(ts))

names = {'MT_EMPTY':0,'MT_GROUND':2,'MT_STONE':3,'MT_PUSHABLE':4,'MT_SPACESHIP_0':6,
         'MT_TELEPORT_0':17,'MT_TELEPORT_1':18,'MT_BOXES?':4}

def tile_px(t):
    off = t*16
    rows=[]
    for y in range(8):
        lo = ts[off+y*2]; hi = ts[off+y*2+1]
        line=''
        for x in range(7,-1,-1):
            line += str((((hi>>x)&1)<<1) | ((lo>>x)&1))
        rows.append(line)
    return rows

for nm, idx in names.items():
    tiles = mt[idx*4:idx*4+4]
    hist={}
    for t in tiles:
        if t >= 245: continue
        for row in tile_px(t):
            for ch in row:
                hist[ch]=hist.get(ch,0)+1
    print('\n===', nm, 'tiles', tiles, 'hist', hist)
    for ty in range(2):
        for y in range(8):
            line=''
            for tx in range(2):
                t = tiles[ty*2+tx]
                line += tile_px(t)[y] if t < 245 else '........'
            print('   ', line.replace('0','.'))
