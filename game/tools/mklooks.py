#!/usr/bin/env python3
"""Собирает config/looks_<код>.tres из описаний в looks_spec.py (внешности посёлков по странам)."""
import sys, importlib.util, os
HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("looks_spec", os.path.join(HERE, "looks_spec.py"))
S = importlib.util.module_from_spec(spec); spec.loader.exec_module(S)

ENUMS = {
    "head": ["BARE", "CAP", "SCARF", "HAT", "HOOD"] + getattr(S, "EXTRA_HEADS", []),
    "hair_style": ["SHORT", "BANGS", "PONYTAIL", "CURLY", "BALD", "BOB", "BUN", "SPIKY", "LONG", "BRAIDS", "PIGTAILS"],
    "beard": ["NONE", "STUBBLE", "MUSTACHE", "FULL"],
    "brows": ["THIN", "THICK", "STERN"],
    "nose": ["BUTTON", "LONG", "ROUND"],
    "outfit": ["COAT", "DRESS", "SWEATER", "JACKET"] + getattr(S, "EXTRA_OUTFITS", []),
    "bow": ["NONE", "BOW", "CLIP", "FLOWER"],
    "animal": ["NONE"] + getattr(S, "ANIMALS", []),
}
DEFAULT = dict(coat="3a4650", accent="8a6c39", skin="c9a58a", hair="3a2a22", head="BARE", height=1.0,
    hair_style="SHORT", beard="NONE", brows="THIN", nose="BUTTON", eye="5a4030", glasses=False,
    freckles=False, scar=False, age=1, female=False, outfit="COAT", bow="NONE", earrings=False, animal="NONE")
ORDER = ["coat", "accent", "skin", "hair", "head", "height", "hair_style", "beard", "brows", "nose", "eye",
    "glasses", "freckles", "scar", "age", "female", "outfit", "bow", "earrings", "animal"]


def col(h):
    h = h.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return "Color(%.4f, %.4f, %.4f, 1)" % (r, g, b)


def val(k, v):
    if k in ("coat", "accent", "skin", "hair", "eye"):
        return col(v)
    if k in ENUMS:
        return str(ENUMS[k].index(v))
    if isinstance(v, bool):
        return "true" if v else "false"
    return str(v)


def entry(i, who, d):
    full = dict(DEFAULT); full.update(d)
    # выше 1.07 фигура закрывает имена стоящих позади (самотест --crowd)
    full["height"] = min(float(full["height"]), 1.07)
    if "female" not in d:
        full["outfit"] = d.get("outfit", "COAT")
    lines = ['[sub_resource type="Resource" id="look_%s"]' % i, 'script = ExtResource("2_look")', 'who = "%s"' % who]
    for k in ORDER:
        lines.append("%s = %s" % (k, val(k, full[k])))
    return "\n".join(lines)


def build(code):
    village = S.VILLAGES[code]
    subs = [entry(i, who, d) for i, (who, d) in enumerate(village["people"])]
    subs.append(entry(99, village.get("you", "You"), village.get("player", S.PLAYER)))
    n = len(village["people"])
    out = ['[gd_resource type="Resource" script_class="LookBook" load_steps=%d format=3]' % (n + 4), "",
        '[ext_resource type="Script" path="res://scripts/village/look_book.gd" id="1_book"]',
        '[ext_resource type="Script" path="res://scripts/village/look_def.gd" id="2_look"]', ""]
    for s in subs:
        out += [s, ""]
    refs = ", ".join('SubResource("look_%d")' % i for i in range(n))
    out += ["[resource]", 'script = ExtResource("1_book")', 'looks = Array[ExtResource("2_look")]([%s])' % refs,
        'player = SubResource("look_99")', ""]
    return "\n".join(out)


if __name__ == "__main__":
    root = sys.argv[1]
    for code in (sys.argv[2:] or S.VILLAGES.keys()):
        path = os.path.join(root, "config", "looks.tres" if code == "ru" else "looks_%s.tres" % code)
        open(path, "w").write(build(code))
        print("записан", path)
