"""Shared icon family for the Mouchoir WoW addons: one rounded-square tile
(dark field, bevelled gold border, soft accent glow) + one flat emblem each.
Writes <name>.png (512x512) and sheet.png into the folder given as argument
(default: next to this script). Pass --size 2048 for a large master."""
import math, os, sys
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
N = int(sys.argv[sys.argv.index('--size') + 1]) if '--size' in sys.argv else 512
S = 4
W = N * S

GOLD, GOLD_L, GOLD_D = (236, 190, 90), (255, 228, 150), (118, 80, 30)
STEEL, STEEL_D = (214, 222, 234), (60, 66, 80)
FIELD = (22, 20, 28)
CORNER = 0.20


def P(x, y):
    return (W * x, W * y)


def poly(d, pts, fill):
    d.polygon([P(*p) for p in pts], fill=fill)


def disc(d, cx, cy, r, fill):
    d.ellipse([W * (cx - r), W * (cy - r), W * (cx + r), W * (cy + r)], fill=fill)


def tile(glow):
    im = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    m = W * 0.015
    layers = [(0.0, (78, 52, 22)), (0.006, GOLD), (0.022, GOLD_L), (0.034, (156, 108, 44)),
              (0.050, (58, 38, 18)), (0.060, FIELD)]
    for inset, col in layers:
        o = m + W * inset
        d.rounded_rectangle([o, o, W - o, W - o], radius=W * (CORNER - inset * 1.1), fill=col)
    o = m + W * 0.060
    g = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ImageDraw.Draw(g).ellipse([W * 0.2, W * 0.2, W * 0.8, W * 0.8], fill=glow + (150,))
    g = g.filter(ImageFilter.GaussianBlur(W * 0.08))
    mask = Image.new("L", (W, W), 0)
    ImageDraw.Draw(mask).rounded_rectangle([o, o, W - o, W - o], radius=W * (CORNER - 0.066), fill=255)
    g.putalpha(Image.composite(g.split()[3], Image.new("L", (W, W), 0), mask))
    return Image.alpha_composite(im, g)


# ---------- emblems (all drawn in 0..1 tile coordinates) ----------
def swords(d, layer):
    for sign in (1, -1):
        ang = math.radians(45) * sign
        ux, uy = math.sin(ang), -math.cos(ang)
        qx, qy = -uy, ux
        L = 0.60

        def pt(o, a, b):
            return (o[0] + ux * a + qx * b, o[1] + uy * a + qy * b)

        base = (0.5 - ux * L * 0.34, 0.5 - uy * L * 0.34 + 0.035)
        hw = 0.028
        mid, tip = pt(base, L * 0.90, 0), pt(base, L, 0)
        poly(d, [pt(base, 0, hw), pt(mid, 0, hw * .75), tip, pt(mid, 0, -hw * .75), pt(base, 0, -hw)], STEEL_D)
        poly(d, [pt(base, 0, hw), pt(mid, 0, hw * .75), tip, base], STEEL)
        poly(d, [pt(base, 0, .017), pt(base, -.10, .017), pt(base, -.10, -.017), pt(base, 0, -.017)], (96, 62, 30))
        g, gw = pt(base, 0.010, 0), 0.095
        poly(d, [pt(g, .017, gw), pt(g, -.017, gw), pt(g, -.017, -gw), pt(g, .017, -gw)], GOLD_D)
        poly(d, [pt(g, .012, gw - .006), pt(g, -.012, gw - .006), pt(g, -.012, -gw + .006),
                 pt(g, .012, -gw + .006)], GOLD)
        pm = pt(base, -0.122, 0)
        disc(d, *pm, 0.032, GOLD_D)
        disc(d, *pm, 0.026, GOLD)


def hourglass(d, layer):
    cx, top, bot = 0.5, 0.24, 0.76

    def cap(y):
        poly(d, [(cx - .20, y - .022), (cx + .20, y - .022), (cx + .20, y + .022), (cx - .20, y + .022)], GOLD_D)
        poly(d, [(cx - .19, y - .016), (cx + .19, y - .016), (cx + .19, y + .014), (cx - .19, y + .014)], GOLD)

    poly(d, [(cx - .17, top + .02), (cx + .17, top + .02), (cx + .012, .5), (cx + .17, bot - .02),
             (cx - .17, bot - .02), (cx - .012, .5)], GOLD_D)
    poly(d, [(cx - .155, top + .03), (cx + .155, top + .03), (cx + .005, .5), (cx + .155, bot - .03),
             (cx - .155, bot - .03), (cx - .005, .5)], (30, 52, 90))
    poly(d, [(cx - .155, bot - .03), (cx + .155, bot - .03), (cx, .60)], GOLD)
    poly(d, [(cx - .09, top + .03), (cx + .09, top + .03), (cx + .02, .40), (cx - .02, .40)], (60, 100, 160))
    cap(top)
    cap(bot)
    bx, by, r = 0.70, 0.70, 0.135
    disc(d, bx, by, r + .012, (14, 40, 30))
    disc(d, bx, by, r, (46, 168, 104))
    pts = [(bx - .062, by + .005), (bx - .018, by + .048), (bx + .066, by - .050)]
    d.line([P(*p) for p in pts], fill=(255, 255, 255), width=int(W * .028), joint="curve")


def pin(d, layer):
    cx, cy, r = 0.5, 0.42, 0.20
    poly(d, [(cx - r * .86, cy + r * .5), (cx + r * .86, cy + r * .5), (cx, 0.80)], GOLD_D)
    disc(d, cx, cy, r + .014, GOLD_D)
    poly(d, [(cx - r * .78, cy + r * .52), (cx + r * .78, cy + r * .52), (cx, .775)], (190, 134, 40))
    disc(d, cx, cy, r, GOLD)
    disc(d, cx - .02, cy - .03, r * .55, GOLD_L)
    disc(d, cx, cy, r * .96, GOLD)
    s = 0.14
    poly(d, [(cx, cy - s * 1.15), (cx + s * .30, cy - s * .30), (cx + s * 1.15, cy), (cx + s * .30, cy + s * .30),
             (cx, cy + s * 1.15), (cx - s * .30, cy + s * .30), (cx - s * 1.15, cy), (cx - s * .30, cy - s * .30)],
         FIELD)


def roles(d, layer):
    cx, cy, r = 0.5, 0.5, 0.29
    disc(d, cx, cy, r + .018, GOLD_D)
    disc(d, cx, cy, r + .008, GOLD)
    box = [W * (cx - r), W * (cy - r), W * (cx + r), W * (cy + r)]
    base = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    bd = ImageDraw.Draw(base)
    bd.pieslice(box, 150, 270, fill=(206, 74, 58))     # damage, upper left
    bd.pieslice(box, 270, 390, fill=(62, 120, 190))    # tank, upper right
    bd.pieslice(box, 30, 150, fill=(60, 168, 100))     # healer, bottom
    m = Image.new("L", (W, W), 0)
    ImageDraw.Draw(m).ellipse(box, fill=255)
    layer.paste(base, (0, 0), m)
    L = (236, 238, 242)
    sx, sy = cx - .115, cy - .09                       # sword
    d.line([P(sx - .05, sy + .05), P(sx + .05, sy - .05)], fill=L, width=int(W * .022))
    d.line([P(sx - .045, sy - .005), P(sx - .005, sy + .035)], fill=L, width=int(W * .018))
    hx, hy = cx + .115, cy - .09                       # shield
    poly(d, [(hx - .05, hy - .055), (hx + .05, hy - .055), (hx + .05, hy + .01), (hx, hy + .065),
             (hx - .05, hy + .01)], L)
    kx, ky = cx, cy + .14                              # cross
    poly(d, [(kx - .018, ky - .055), (kx + .018, ky - .055), (kx + .018, ky + .055), (kx - .018, ky + .055)], L)
    poly(d, [(kx - .055, ky - .018), (kx + .055, ky - .018), (kx + .055, ky + .018), (kx - .055, ky + .018)], L)


def tent(d, layer):
    cx = 0.5
    PUR, PUR_D, PUR_L, NIGHT = (112, 56, 150), (74, 34, 106), (150, 90, 190), (30, 22, 44)
    # stars and crescent moon
    disc(d, .72, .22, .062, GOLD)
    disc(d, .745, .205, .054, FIELD)
    for sx, sy, sr in ((.24, .24, .014), (.30, .16, .010), (.82, .40, .010)):
        poly(d, [(sx, sy - sr * 2), (sx + sr * .5, sy - sr * .5), (sx + sr * 2, sy), (sx + sr * .5, sy + sr * .5),
                 (sx, sy + sr * 2), (sx - sr * .5, sy + sr * .5), (sx - sr * 2, sy), (sx - sr * .5, sy - sr * .5)], GOLD)
    # central big top: seven alternating gores meeting at the apex
    apex, eave, half = (cx, .26), .56, .31
    n = 7
    for i in range(n):
        x0 = cx - half + i * (2 * half / n)
        x1 = x0 + 2 * half / n
        poly(d, [apex, (x0, eave), (x1, eave)], PUR if i % 2 == 0 else GOLD)
    # soft shading on the right half for volume
    shade = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ImageDraw.Draw(shade).polygon([P(*apex), P(cx + .02, eave), P(cx + half, eave)], fill=(0, 0, 0, 70))
    layer.alpha_composite(shade)
    # scalloped valance in two colours
    for i in range(n):
        x0 = cx - half + i * (2 * half / n)
        d.pieslice([W * x0, W * (eave - .04), W * (x0 + 2 * half / n), W * (eave + .06)], 0, 180,
                   fill=GOLD if i % 2 == 0 else PUR_L)
    # side wings, walls and a curtained doorway
    for sgn in (1, -1):
        poly(d, [(cx + sgn * half, eave + .005), (cx + sgn * (half + .075), .66), (cx + sgn * half, .64)], PUR_D)
    poly(d, [(cx - half, .60), (cx + half, .60), (cx + half, .76), (cx - half, .76)], PUR)
    poly(d, [(cx - .075, .64), (cx + .075, .64), (cx + .105, .76), (cx - .105, .76)], NIGHT)
    poly(d, [(cx - .075, .64), (cx - .01, .64), (cx - .04, .76), (cx - .105, .76)], GOLD_D)
    poly(d, [(cx + .075, .64), (cx + .01, .64), (cx + .04, .76), (cx + .105, .76)], GOLD_D)
    for lx in (cx - half + .03, cx + half - .03):
        disc(d, lx, .66, .016, GOLD_L)
    # pole, pennants and a gem
    d.line([P(cx, .26), P(cx, .13)], fill=GOLD, width=int(W * .012))
    poly(d, [(cx, .13), (cx + .095, .16), (cx, .19)], (150, 60, 190))
    poly(d, [(cx, .13), (cx - .06, .145), (cx, .16)], GOLD)
    disc(d, cx, .13, .014, GOLD_L)


def heart(d, layer):
    ex0, ex1, ey0, ey1 = .20, .80, .40, .76
    DK, MD, LT = (150, 142, 130), (200, 194, 182), (238, 232, 220)
    # back of the envelope with its open flap behind the heart
    poly(d, [(ex0, ey0), (ex1, ey0), (ex1, ey1), (ex0, ey1)], MD)
    poly(d, [(ex0, ey0), (ex1, ey0), (.5, .22)], LT)
    d.line([P(ex0, ey0), P(.5, .22), P(ex1, ey0)], fill=DK, width=int(W * .008), joint="curve")
    d.line([P(ex0, ey0), P(ex1, ey0)], fill=DK, width=int(W * .008))
    # heart rising out of the envelope
    cx, cy, r = .5, .42, .105
    col, hi = (214, 52, 62), (250, 130, 130)
    disc(d, cx - r * .85, cy - .01, r, col)
    disc(d, cx + r * .85, cy - .01, r, col)
    poly(d, [(cx - r * 1.78, cy + .03), (cx + r * 1.78, cy + .03), (cx, cy + .25)], col)
    disc(d, cx - r * 1.15, cy - .045, .026, hi)
    # front pocket in front of the heart: two side folds and a bottom fold
    poly(d, [(ex0, ey0 + .05), (.5, .60), (ex0, ey1)], LT)
    poly(d, [(ex1, ey0 + .05), (.5, .60), (ex1, ey1)], LT)
    poly(d, [(ex0, ey1), (.5, .58), (ex1, ey1)], (222, 216, 204))
    for p0, p1 in (((ex0, ey0 + .05), (.5, .60)), ((ex1, ey0 + .05), (.5, .60)),
                   ((ex0, ey1), (.5, .58)), ((ex1, ey1), (.5, .58))):
        d.line([P(*p0), P(*p1)], fill=DK, width=int(W * .008))
    d.line([P(ex0, ey0 + .05), P(ex0, ey1), P(ex1, ey1), P(ex1, ey0 + .05)], fill=DK, width=int(W * .008), joint="curve")


FAMILY = [
    ("TargetInCombat", swords, (190, 40, 30)),
    ("TimelessQuestion", hourglass, (40, 90, 170)),
    ("MogWhere", pin, (200, 140, 40)),
    ("PartyRoleIcons", roles, (90, 110, 150)),
    ("DarkmoonFaireBuff", tent, (120, 50, 160)),
    ("HardcoreCongrats", heart, (190, 50, 70)),
]


def build(emblem, glow):
    im = tile(glow)
    layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    emblem(ImageDraw.Draw(layer), layer)
    shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 120), (0, int(W * .008)), layer.split()[3])
    shadow = shadow.filter(ImageFilter.GaussianBlur(W * .006))
    im = Image.alpha_composite(im, shadow)
    im = Image.alpha_composite(im, layer)
    return im.resize((N, N), Image.LANCZOS)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--") and not a.isdigit()]
    HERE = args[0] if args else HERE
    os.makedirs(HERE, exist_ok=True)
    out = []
    for name, em, glow in FAMILY:
        img = build(em, glow)
        img.save(os.path.join(HERE, name + ".png"))
        out.append(img)
    sheet = Image.new("RGBA", (len(out) * 270, 270), (16, 16, 18, 255))
    for i, im in enumerate(out):
        sheet.alpha_composite(im.resize((256, 256), Image.LANCZOS), (i * 270 + 7, 7))
    sheet.save(os.path.join(HERE, "sheet.png"))
