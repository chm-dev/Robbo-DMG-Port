from PIL import Image
from collections import Counter
import os
for name in ["gbc-l1_gbc.png","gbc-l1_gb.png"]:
    p = os.path.join("gb","tests","screenshots",name)
    if not os.path.exists(p):
        # try repo root
        p = name
    im = Image.open(p).convert("RGB")
    print(name, im.size)
    c = Counter(im.getdata())
    for col,n in c.most_common(10):
        print("   ", col, n)
