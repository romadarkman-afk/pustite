# folk_cut.py SHEET OUTDIR PREFIX — лист персонажей на пурпурном фоне → отдельные png по росту H
import sys, os, numpy as np
from PIL import Image
from scipy import ndimage
src, out, pre = sys.argv[1], sys.argv[2], sys.argv[3]
H = 260
im = np.asarray(Image.open(src).convert("RGB")).astype(np.float32)
c = np.concatenate([im[:30, :30].reshape(-1, 3), im[:30, -30:].reshape(-1, 3), im[-30:, :30].reshape(-1, 3), im[-30:, -30:].reshape(-1, 3)])
bg = np.median(c, axis=0); print("bg", bg)
m = (np.minimum(im[..., 0], im[..., 2]) - im[..., 1]) / max(1.0, min(bg[0], bg[2]) - bg[1])
a = 1.0 - np.clip((m - 0.12) / 0.5, 0, 1)
lab, n = ndimage.label(ndimage.binary_closing(a > 0.35, iterations=3))
sizes = ndimage.sum(np.ones_like(a), lab, range(1, n + 1))
big = [i + 1 for i in np.argsort(-sizes) if sizes[i] > sizes.max() * 0.15]
objs = ndimage.find_objects(lab)
boxes = []
for i in big:
    sl = objs[i - 1]
    boxes.append((sl[0].start, sl[0].stop, sl[1].start, sl[1].stop, i))
# по рядам, слева направо
boxes.sort(key=lambda b: (round(b[0] / (im.shape[0] / 3)), b[2]))
aa = np.clip(a, 1e-3, 1)[..., None]
rgb = np.clip((im - (1 - aa) * bg) / aa, 0, 255)
tall = max(b[1] - b[0] for b in boxes)
for k, (y0, y1, x0, x1, li) in enumerate(boxes):
    mask = ndimage.binary_dilation(lab == li, iterations=4)
    al = a * mask
    p = 4
    y0, x0 = max(0, y0 - p), max(0, x0 - p); y1, x1 = min(a.shape[0], y1 + p), min(a.shape[1], x1 + p)
    img = np.dstack([rgb, al[..., None] * 255])[y0:y1, x0:x1].astype(np.uint8)
    pi = Image.fromarray(img, "RGBA")
    sc = H / tall      # общий масштаб: девочка остаётся ниже взрослых
    pi = pi.resize((round(pi.width * sc), round(pi.height * sc)), Image.LANCZOS)
    pi.save(os.path.join(out, "%s%d.png" % (pre, k + 1)))
    print(k + 1, (x0, y0, x1, y1), pi.size)
