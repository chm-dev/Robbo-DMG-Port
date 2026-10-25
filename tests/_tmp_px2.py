from PIL import Image
from collections import Counter
for name in ["_gbc_l1_b.png","_cgb_level1.png"]:
    im = Image.open("gb/tests/screenshots/"+name).convert("RGB")
    print(name, im.size)
    c = Counter(im.getdata())
    for col,n in c.most_common(8):
        print("   ", col, n)
