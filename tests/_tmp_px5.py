from PIL import Image
from collections import Counter
names = {(74,150,74):'BG(COLB)',(0,142,206):'COL3',(0,0,0):'COLPF0',(214,154,82):'COLPF1',(197,198,197):'COLPF2',(255,255,255):'white'}
cells = {'wall':(0,1),'teleport':(6,2),'stone':(2,4),'box2':(7,4),'capsule':(9,2),'floor':(4,3),'robbo':(1,2)}
for name in ["_gbc_l1_b.png","_cgb_l1_new.png"]:
    im = Image.open("gb/tests/screenshots/"+name).convert("RGB")
    print('==',name)
    for label,(cx,cy) in cells.items():
        c = Counter(im.crop((cx*16,cy*16,cx*16+16,cy*16+16)).getdata())
        parts = [f"{names.get(k,k)}={v}" for k,v in c.most_common(4)]
        print(f"  {label:9s}", ", ".join(parts))
