# cutout.py: вырезка домов и предметов с пурпурного фона Nano Banana (использовался в v0.22.0).
# Перед запуском поправить SRC (папка с картинками), OUT и словарь F (имя -> часть имени файла Gemini).
# Нужны numpy, pillow, scipy.
# cutout.py — вырезать розовый фон Nano Banana, обрезать по содержимому, уменьшить.
import numpy as np, sys, os
from PIL import Image
from scipy import ndimage

SRC = "/mnt/user-data/uploads/Downloads/"
OUT = "/home/claude/v2/game/assets/village/"
os.makedirs(OUT, exist_ok=True)
F = {k: SRC + "Gemini_Generated_Image_%s.jpg" % v for k, v in {
    "house_day": "e2j7hre2j7hre2j7", "house_night": "ughhonughhonughh",
    "cellar_night": "9s0qom9s0qom9s0q", "garage_night": "7r2pe7r2pe7r2pe7", "shed_night": "2n9ole2n9ole2n9o",
    "church_day": "9jf8el9jf8el9jf8", "church_night": "1o5mg11o5mg11o5m",
    "shed_day": "s004cas004cas004", "garage_day": "agvj00agvj00agvj", "cellar_day": "r5upwor5upwor5up",
    "barn_day": "qhj579qhj579qhj5", "barn_night": "ivz55livz55livz5",
    "well": "m7jhhtm7jhhtm7jh", "lamp_day": "2j4n9e2j4n9e2j4n", "lamp_night": "kkvyrokkvyrokkvy",
    "woodpile": "at1t6pat1t6pat1t", "barrel": "p6u4sip6u4sip6u4", "talisman": "hfnhxdhfnhxdhfnh", "tree": "kx656zkx656zkx65"}.items()}
# ширина итоговой картинки, px (в игре рисуется примерно вдвое меньше логических единиц)
WIDTH = {"house": 300, "cellar": 300, "garage": 300, "shed": 260, "church": 280, "barn": 320,
         "well": 200, "lamp": 120, "woodpile": 220, "barrel": 140, "talisman": 72, "tree": 160}


def key(path):
    im = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    h, w, _ = im.shape
    corners = np.concatenate([im[:40, :40].reshape(-1, 3), im[:40, -40:].reshape(-1, 3), im[-40:, :40].reshape(-1, 3), im[-40:, -40:].reshape(-1, 3)])
    bg = np.median(corners, axis=0)
    # «розовость»: насколько min(R,B) выше G, относительно фона
    m = (np.minimum(im[..., 0], im[..., 2]) - im[..., 1]) / max(1.0, min(bg[0], bg[2]) - bg[1])
    a = 1.0 - np.clip((m - 0.12) / (0.62 - 0.12), 0.0, 1.0)
    # убрать мелкие острова (артефакты jpeg, следы водяного знака)
    lab, n = ndimage.label(a > 0.35)
    if n > 1:
        sizes = ndimage.sum(np.ones_like(a), lab, range(1, n + 1))
        keep = np.zeros(n + 1, bool)
        keep[1:] = sizes >= max(400, sizes.max() * 0.01)
        mask = keep[lab]
        mask = ndimage.binary_dilation(mask, iterations=6)
        a = a * mask
    # снять розовый ореол: c = (c - (1-a)*bg) / a
    aa = np.clip(a, 1e-3, 1.0)[..., None]
    rgb = np.clip((im - (1.0 - aa) * bg) / aa, 0, 255)
    # свечение из-под двери: полупрозрачные тёплые пиксели — в янтарь, без розового отлива
    warm = (a < 0.9) & (a > 0.02) & (rgb[..., 0] > 200) & (rgb[..., 0] > rgb[..., 1] + 30)
    amber = np.array([255.0, 176.0, 90.0])
    rgb[warm] = rgb[warm] * 0.35 + amber * 0.65
    # розовые пиксели у порога (красный яркий, синий выше зелёного) — тоже в янтарь
    pink = (a > 0.02) & (rgb[..., 0] > 170) & (rgb[..., 2] > rgb[..., 1] + 8) & (rgb[..., 0] > rgb[..., 1] + 60)
    rgb[pink] = rgb[pink] * 0.3 + amber * 0.7
    rgb[a < 0.02] = 0
    return rgb, a


def bbox(a):
    ys, xs = np.where(a > 0.08)
    return [xs.min(), ys.min(), xs.max() + 1, ys.max() + 1]


def save(name, rgb, a, box, width):
    x0, y0, x1, y1 = box
    pad = 6
    x0, y0 = max(0, x0 - pad), max(0, y0 - pad)
    x1, y1 = min(a.shape[1], x1 + pad), min(a.shape[0], y1 + pad)
    img = np.dstack([rgb, a[..., None] * 255])[y0:y1, x0:x1].astype(np.uint8)
    im = Image.fromarray(img, "RGBA")
    hgt = round(im.height * width / im.width)
    im = im.resize((width, hgt), Image.LANCZOS)
    im.save(OUT + name + ".png", optimize=True)
    return im.size


done = {}
for name in F:
    base = name.split("_")[0]
    if name in done:
        continue
    pair = [name]
    if name.endswith("_day") or name.endswith("_night"):
        pair = [base + "_day", base + "_night"]
    keyed = {p: key(F[p]) for p in pair}
    boxes = [bbox(keyed[p][1]) for p in pair]
    if len(pair) == 2:
        print(base, "сдвиг день/ночь:", [b1 - b0 for b0, b1 in zip(*boxes)])
    box = [min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes)]
    for p in pair:
        print(p, save(p, *keyed[p], box, WIDTH[base]))
        done[p] = True
