from PIL import Image
from collections import Counter
pal = {(74,150,74):'G',(0,142,206):'B',(0,0,0):'K',(214,154,82):'O',(197,198,197):'W',(255,255,255):'W'}
for name in ["_gbc_l1_b.png","_cgb_level1.png"]:
    im = Image.open("gb/tests/screenshots/"+name).convert("RGB")
    print('==',name)
    for cy in range(0, 144, 16):
        row=''
        for cx in range(0, 160, 16):
            c = Counter(im.crop((cx,cy,cx+16,cy+16)).getdata())
            top = [col for col,_ in c.most_common(3)]
            s=''
            for col in top:
                s += pal.get(col,'?')
            row += s.ljust(4)
        print(row)
