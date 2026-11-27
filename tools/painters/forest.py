"""4. 빛이 많은 숲 (실루엣 화풍, #140).

해가 막 진 숲. 청록 그림자 속에 나무줄기가 겹겹이 서 있고, 멀수록 푸른 안개에 녹는다. 위에서 금빛 빛줄기가
비스듬히 내리고 금빛 알갱이가 떠 있다. 유럽 동화풍(#136): 너도밤나무·전나무 줄기, 고사리, 이끼 낀 뿌리,
블루벨, 버섯 무리.

게임 자리와 맞춘 것(바꾸면 장소 씬 부품도 같이):
- 4-2 갈림길 두 번(placeholder_art.FOREST_FORKS): 이끼 바위, 덤불 벽, 빛줄기 아래 굴 같은 입구 셋(props 층).
- 4-3 빈터(x 6120~6266): 큰 빛과 알갱이. 4-4 숲 끝 안개.
"""

from __future__ import annotations

import math
import random

import placeholder_art as pa
from placeholder_art import Layer, rgba, H

HAZE = (96, 150, 150)      # 숲 속 푸른 안개(먼 층이 녹는 색)
GOLD = (255, 214, 150)     # 빛줄기·해빛


def fog(c: tuple[int, int, int], t: float, a: int = 255):
    return rgba(*(round(c[i] + (HAZE[i] - c[i]) * t) for i in range(3)), a)


def trunk(L: Layer, rng: random.Random, x: float, base: float, w: float, top: float, body, lit=None, roots: bool = True) -> None:
    """나무줄기: 위로 조금 가늘어지고 살짝 굽는다. 뿌리가 땅으로 퍼진다. lit = 오른쪽(빛 쪽) 가장자리."""
    bend = rng.uniform(-0.04, 0.04) * (base - top)
    pts_l = [(x - w * 0.5 + bend * (1 - t) ** 2 * 0 + bend * t * t, base - (base - top) * t) for t in (0, 0.5, 1.0)]
    L.poly([(x - w * 0.5, base), (x + w * 0.5, base), (x + w * 0.36 + bend, top), (x - w * 0.36 + bend, top)], body)
    if lit is not None:
        L.poly([(x + w * 0.32, base), (x + w * 0.5, base), (x + w * 0.36 + bend, top), (x + w * 0.24 + bend, top)], lit)
    if roots:
        for d in (-1, 1):
            for k in range(2):
                ln = w * rng.uniform(0.6, 1.3)
                L.poly([(x + d * w * 0.2, base - w * 0.5), (x + d * (w * 0.5 + ln), base + 4),
                        (x + d * w * 0.3, base + 4)], body)
    del pts_l


def fir(L: Layer, x: float, base: float, h: float, body) -> None:
    """전나무 실루엣: 층층이 처진 가지."""
    tiers = 7
    for k in range(tiers):
        t0 = k / tiers
        y = base - h * (0.12 + t0 * 0.88)
        hw = h * 0.2 * (1 - t0) + 4
        L.poly([(x - hw, y + h * 0.1), (x, y - h * 0.06), (x + hw, y + h * 0.1), (x + hw * 0.6, y + h * 0.12), (x - hw * 0.6, y + h * 0.12)], body)
    L.rect(x - h * 0.015, base - h * 0.14, x + h * 0.015, base, body)


def canopy(L: Layer, rng: random.Random, x0: float, x1: float, y: float, r: tuple[float, float], body, n_per_100: float = 1.2,
           lit=None) -> None:
    """위를 덮는 잎: 화면 위 가장자리는 잎으로 꽉 차고, 아래 가장자리는 작은 잎이 들쭉날쭉하게 늘어진다.
    lit가 있으면 군데군데 빛 받은 잎."""
    L.rect(x0, -20, x1, y - r[0] * 0.2, body)
    n = int((x1 - x0) / 100 * n_per_100)
    for _ in range(n):  # 큰 잎 덩어리의 아래 가장자리
        cx, rr = rng.uniform(x0, x1), rng.uniform(*r)
        cy = y + rng.uniform(-0.3, 0.3) * rr
        L.ellipse((cx - rr, cy - rr * 0.45, cx + rr, cy + rr * 0.35), body)
        for _ in range(int(rr / 6)):  # 가장자리에 붙은 작은 잎
            a = rng.uniform(0.1, math.pi - 0.1)
            lx = cx + math.cos(a) * rr * rng.uniform(0.7, 1.05)
            ly = cy + math.sin(a) * rr * 0.35 * rng.uniform(0.8, 1.3)
            lr = rng.uniform(6, 16)
            L.ellipse((lx - lr, ly - lr * 0.6, lx + lr, ly + lr * 0.6), body)
            if lit is not None and rng.random() < 0.12:
                L.ellipse((lx - lr * 0.5, ly - lr * 0.5, lx + lr * 0.4, ly), lit)
        if rng.random() < 0.35:  # 늘어진 덩굴: 가는 줄에 작은 잎
            hx = cx + rng.uniform(-rr, rr) * 0.6
            hl = rr * rng.uniform(0.5, 1.2)
            top_y = cy + rr * 0.3
            pts = pa.sag(hx, top_y, hx + rng.uniform(-14, 14), top_y + hl, 6, 8)
            L.line(pts, body, 2)
            for px, py in pts[1::2]:
                lr = rng.uniform(4, 8)
                L.ellipse((px - lr, py - lr * 0.6, px + lr, py + lr * 0.6), body)


def fern(L: Layer, rng: random.Random, x: float, base: float, size: float, body, lean: float = 0.0) -> None:
    """고사리: 활처럼 휜 잎줄기 몇 개, 줄기마다 작은 잎."""
    for _ in range(rng.randint(4, 7)):
        a = math.radians(rng.uniform(-150, -30) + lean)
        ln = size * rng.uniform(0.6, 1.0)
        pts = []
        for i in range(9):
            t = i / 8
            px = x + math.cos(a) * ln * t
            py = base + math.sin(a) * ln * t + ln * 0.5 * t * t
            pts.append((px, py))
        L.line(pts, body, max(1.5, size * 0.025))
        for i in range(1, 8):
            px, py = pts[i]
            lf = size * 0.12 * (1 - i / 9)
            for d in (-1, 1):
                L.line([(px, py), (px + d * lf * 0.4, py - lf)], body, max(1.2, size * 0.02))


def mushrooms(L: Layer, rng: random.Random, x: float, base: float, s: float, cap, stem) -> None:
    for _ in range(rng.randint(2, 5)):
        mx = x + rng.uniform(-24, 24) * s
        h = rng.uniform(10, 22) * s
        r = rng.uniform(6, 12) * s
        L.rect(mx - r * 0.25, base - h, mx + r * 0.25, base, stem)
        L.ellipse((mx - r, base - h - r * 0.7, mx + r, base - h + r * 0.4), cap)


def flowers(L: Layer, rng: random.Random, x0: float, x1: float, y0: float, y1: float, n: int, color) -> None:
    for _ in range(n):
        fx, fy = rng.uniform(x0, x1), rng.uniform(y0, y1)
        r = rng.uniform(1.6, 3.2)
        L.ellipse((fx - r, fy - r, fx + r, fy + r), color)


def motes(L: Layer, rng: random.Random, x0: float, x1: float, y0: float, y1: float, n: int, color) -> None:
    glow = []
    for _ in range(n):
        px, py, r = rng.uniform(x0, x1), rng.uniform(y0, y1), rng.uniform(1.6, 4.2)
        glow.append(("ellipse", (px - r * 3, py - r * 3, px + r * 3, py + r * 3), rgba(255, 220, 140, 70)))
        L.ellipse((px - r, py - r, px + r, py + r), color)
    L.haze(glow, 4)


def shaft(x: float, top_w: float, bottom_w: float, lean: float, y1: float, color) -> tuple:
    return ("poly", [(x - top_w / 2, -20), (x + top_w / 2, -20), (x + lean + bottom_w / 2, y1), (x + lean - bottom_w / 2, y1)], color)


def paint(width: float, markers: dict[str, float]) -> dict[str, Layer]:
    rng = random.Random("forest")
    mk = markers.get
    layers: dict[str, Layer] = {}

    # 하늘: 나무 사이로 보이는 해 진 하늘. 위는 짙은 청록, 아래(지평선)는 꺼져 가는 금빛.
    w = pa.layer_width(width, "sky")
    sky = pa.vertical_gradient(w, [
        (0.0, (20, 44, 60)), (0.35, (52, 98, 108)), (0.58, (136, 166, 146)),
        (0.7, (222, 196, 140)), (0.8, (200, 150, 110)), (1.0, (80, 104, 100)),
    ])
    pa.add_glow(sky, w * 0.7, 660, 900, (255, 200, 140), 0.45)
    layers["sky"] = L = Layer(w, sky)
    pa.stars(L, random.Random("forest_stars"), 50, 260, rgba(230, 240, 236, 150))

    # 지평선: 아주 먼 숲 능선(전나무 꼭대기들). 거의 안개 색.
    w = pa.layer_width(width, "horizon")
    layers["horizon"] = L = Layer(w)
    body = fog((40, 70, 80), 0.62)
    pts = pa.ridge(rng, w, 600, 50, waves=3)
    L.poly(pts, body)
    x = 0.0
    while x < w:
        fir(L, x, pa._ridge_y(pts, x) + 20, rng.uniform(110, 190), body)
        x += rng.uniform(26, 60)
    L.haze([("poly", [(-20, 640), (w + 20, 640), (w + 20, 760), (-20, 760)], rgba(*HAZE, 170))], 30)

    # 먼 숲: 가는 줄기가 빽빽하고 위는 잎으로 덮였다. 푸른 안개에 녹는다.
    w = pa.layer_width(width, "far")
    layers["far"] = L = Layer(w)
    body = fog((34, 62, 70), 0.5)
    L.rect(-20, 700, w + 20, H, body)
    x = 0.0
    while x < w:
        tw = rng.uniform(10, 22)
        trunk(L, rng, x, 712, tw, -20, body, None, roots=False)
        x += rng.uniform(40, 110)
    canopy(L, rng, -100, w + 100, 40, (80, 170), fog((24, 50, 52), 0.45), 1.6)
    for _ in range(int(w / 500)):
        fx = rng.uniform(0, w)
        fir(L, fx, 712, rng.uniform(380, 520), body)
    L.haze([("poly", [(-20, 600), (w + 20, 600), (w + 20, 760), (-20, 760)], rgba(*HAZE, 120))], 34)

    # 구릉 층: 중간 거리 줄기, 비스듬한 빛줄기.
    w = pa.layer_width(width, "hills")
    layers["hills"] = L = Layer(w)
    body = fog((30, 56, 62), 0.34)
    L.rect(-20, 728, w + 20, H, body)
    x = rng.uniform(0, 80)
    while x < w:
        tw = rng.uniform(22, 40)
        trunk(L, rng, x, 736, tw, -20, body, fog((120, 140, 110), 0.3) if rng.random() < 0.5 else None)
        x += rng.uniform(110, 260)
    canopy(L, rng, -100, w + 100, 30, (110, 220), fog((20, 44, 42), 0.3), 1.3, fog((70, 100, 70), 0.3))
    shafts = [shaft(rng.uniform(0, w), 40, 180, 160, 740, rgba(*GOLD, 34)) for _ in range(int(w / 700))]
    L.haze(shafts, 16)
    L.haze([("poly", [(-20, 680), (w + 20, 680), (w + 20, 790), (-20, 790)], rgba(*HAZE, 100))], 26)

    # 가운데: 굵은 너도밤나무 줄기와 뿌리, 위를 덮는 잎, 블루벨 깔린 숲 바닥.
    w = pa.layer_width(width, "mid")
    layers["mid"] = L = Layer(w)
    body = fog((26, 50, 52), 0.16)
    floor = pa.ridge(rng, w, 752, 8, step=40)
    L.poly(floor, fog((40, 64, 54), 0.14))
    x = rng.uniform(0, 120)
    while x < w:
        tw = rng.uniform(44, 80)
        trunk(L, rng, x, pa._ridge_y(floor, x) + 6, tw, -20, body, fog((150, 150, 110), 0.18))
        x += rng.uniform(220, 520)
    canopy(L, rng, -100, w + 100, 10, (140, 260), rgba(12, 34, 34), 1.1, rgba(58, 94, 60))
    deco = random.Random("forest_mid_deco")
    flowers(L, deco, 0, w, 752, 790, int(w / 4), fog((120, 120, 220), 0.12, 230))  # 블루벨
    for _ in range(int(w / 400)):
        fern(L, deco, deco.uniform(0, w), pa._ridge_y(floor, 0) + 30, deco.uniform(50, 80), fog((40, 84, 60), 0.12))
    L.haze([shaft(deco.uniform(0, w), 50, 240, 200, 790, rgba(*GOLD, 40)) for _ in range(int(w / 900))], 18)

    # 가까운 덤불: 고사리, 버섯, 쓰러진 통나무. 하윤 뒤 길가.
    w = pa.layer_width(width, "near")
    layers["near"] = L = Layer(w)
    deco = random.Random("forest_near")
    under = fog((30, 66, 52), 0.04)
    band = pa.ridge(deco, w, 772, 10, step=30)
    L.poly(band, under)
    x = deco.uniform(0, 200)
    while x < w:
        fern(L, deco, x, pa._ridge_y(band, x) + 24, deco.uniform(70, 120), rgba(46, 96, 64))
        x += deco.uniform(60, 180)
    for _ in range(int(w / 700)):
        lx = deco.uniform(0, w)
        ly = pa._ridge_y(band, lx) + 18
        ln = deco.uniform(200, 380)
        L.poly([(lx, ly - 34), (lx + ln, ly - 26), (lx + ln, ly + 4), (lx, ly + 4)], rgba(54, 52, 42))  # 쓰러진 통나무
        L.ellipse((lx + ln - 18, ly - 28, lx + ln + 14, ly + 4), rgba(120, 100, 70))
        L.poly([(lx, ly - 34), (lx + ln, ly - 26), (lx + ln, ly - 20), (lx, ly - 26)], rgba(70, 120, 60))  # 이끼
        mushrooms(L, deco, lx + ln * 0.4, ly - 30, 0.9, rgba(214, 120, 70), rgba(226, 214, 190))
    flowers(L, deco, 0, w, 776, 800, int(w / 6), rgba(132, 134, 230, 230))
    flowers(L, deco, 0, w, 776, 800, int(w / 40), rgba(240, 236, 210, 230))

    # 땅: 이끼 덮인 흙길, 뿌리가 길을 가로지른다.
    w = pa.layer_width(width, "ground")
    layers["ground"] = L = Layer(w)
    L.rect(-20, 770, w + 20, H, rgba(40, 58, 44))
    path_top = [(float(x), 792 + rng.uniform(-3, 3)) for x in range(-20, w + 40, 60)]
    path_bot = [(float(x), 860 + rng.uniform(-8, 8)) for x in range(w + 40, -40, -60)]
    L.poly(path_top + path_bot, rgba(84, 82, 60))
    gd = random.Random("forest_ground")
    for _ in range(int(w / 260)):  # 길을 건너는 뿌리
        rx = gd.uniform(0, w)
        L.line(pa.sag(rx, 790, rx + gd.uniform(-160, 160), 866, gd.uniform(-10, 10), 10), rgba(56, 50, 38), gd.uniform(5, 9))
    L.rect(-20, 960, w + 20, H, rgba(32, 48, 38))
    for _ in range(int(w / 3)):  # 길 앞 이끼·낙엽: 작고 납작한 점
        x, y = gd.uniform(0, w), gd.uniform(868, H)
        r = gd.uniform(3, 9) * (0.6 + (y - 868) / 300)
        c = gd.choice([rgba(52, 82, 52), rgba(62, 96, 58), rgba(110, 92, 56), rgba(130, 96, 52), rgba(44, 70, 48)])
        L.ellipse((x - r, y - r * 0.35, x + r, y + r * 0.35), c)
    pa.strokes(L, gd, 0, w, 770, 796, int(w / 7), rgba(40, 74, 54), rgba(96, 128, 76), (10, 36))
    pa.strokes(L, gd, 0, w, 870, H, int(w / 14), rgba(34, 62, 42), rgba(70, 104, 62), (8, 22), lean=(-6, 6))
    pa.pebbles(L, gd, 0, w, 800, 852, int(w / 30), rgba(94, 88, 66), rgba(124, 114, 84))
    flowers(L, gd, 0, w, 880, H, int(w / 30), rgba(130, 130, 224, 220))

    # 하윤 뒤 물건: 굵은 나무, 갈림길(바위·덤불 벽·입구), 빈터, 숲 끝 안개.
    w = pa.layer_width(width, "props")
    layers["props"] = L = Layer(w)
    tr = random.Random("forest_props")
    x = 100.0
    while x < w:  # 하윤 바로 뒤 굵은 나무
        if all(abs(x - mk(k, -9999)) > 500 for k in ("4-2", "4-3")) and not (3000 < x < 5900):
            tw = tr.uniform(70, 110)
            trunk(L, tr, x, 792, tw, -20, rgba(34, 56, 52), rgba(150, 140, 100))
            for k in range(tr.randint(1, 3)):  # 줄기 아래쪽 이끼(뿌리에서 위로 번진다)
                ky = tr.uniform(560, 760)
                for j in range(10):
                    mx, my = x + tr.uniform(-tw * 0.45, tw * 0.1), ky + tr.uniform(-30, 30)
                    mr = tr.uniform(4, 10)
                    L.ellipse((mx - mr, my - mr * 0.6, mx + mr, my + mr * 0.6), rgba(52, 86, 56))
            L.ellipse((x + tw * 0.05, 420, x + tw * 0.3, 452), rgba(24, 40, 38))  # 옹이
            mushrooms(L, tr, x + tw * 0.6, 792, 1.1, rgba(232, 214, 180), rgba(230, 222, 200))
        x += tr.uniform(500, 1100)
    gold = rgba(*GOLD, 70)
    x0 = mk("4-2", 3171)
    for rock_dx, shaft_dxs in pa.FOREST_FORKS:
        x = x0 + rock_dx
        # 이끼 바위
        L.ellipse((x - 180, 620, x + 180, 820), rgba(84, 94, 90))
        L.ellipse((x - 120, 636, x + 160, 760), rgba(110, 118, 108))
        L.ellipse((x - 150, 612, x + 140, 700), rgba(82, 128, 70))
        L.ellipse((x - 90, 606, x + 60, 650), rgba(120, 160, 84))
        # 덤불 벽: 잎 덩어리를 겹쳐 쌓고, 위쪽은 빛을 받는다.
        hx0, hx1 = x + shaft_dxs[0] - 220, x + shaft_dxs[-1] + 260
        hr = random.Random(f"hedge{rock_dx}")
        for _ in range(int((hx1 - hx0) / 22)):
            cx, cy, r = hr.uniform(hx0, hx1), hr.uniform(400, 760), hr.uniform(60, 120)
            L.ellipse((cx - r, cy - r * 0.8, cx + r, cy + r * 0.8), rgba(22, 46, 40))
        for _ in range(int((hx1 - hx0) / 8)):  # 윗가장자리 잎: 들쭉날쭉
            cx = hr.uniform(hx0 + 20, hx1 - 20)
            cy, r = hr.uniform(330, 420), hr.uniform(14, 34)
            L.ellipse((cx - r, cy - r * 0.7, cx + r, cy + r * 0.7), hr.choice([rgba(22, 46, 40), rgba(34, 66, 50)]))
        for _ in range(int((hx1 - hx0) / 30)):
            cx, cy, r = hr.uniform(hx0, hx1), hr.uniform(330, 720), hr.uniform(30, 70)
            L.ellipse((cx - r, cy - r * 0.7, cx + r, cy + r * 0.7), rgba(38, 74, 56))
        for _ in range(int((hx1 - hx0) / 18)):  # 잎끝(빛 받은 잎)
            cx, cy, r = hr.uniform(hx0, hx1), hr.uniform(320, 640), hr.uniform(8, 18)
            L.ellipse((cx - r, cy - r * 0.6, cx + r, cy + r * 0.6), rgba(84, 120, 70))
        L.rect(hx0 + 40, 620, hx1 - 40, 800, rgba(22, 44, 40))
        for dx in shaft_dxs:
            ex = x + dx
            L.ellipse((ex - 92, 470, ex + 92, 640), rgba(64, 90, 62))  # 입구 테두리(빛 받은 잎)
            L.rect(ex - 92, 556, ex + 92, 800, rgba(64, 90, 62))
            L.ellipse((ex - 74, 488, ex + 74, 620), rgba(10, 20, 18))  # 굴 안쪽 어둠
            L.rect(ex - 74, 554, ex + 74, 800, rgba(10, 20, 18))
            L.ellipse((ex - 46, 600, ex + 46, 800), rgba(4, 10, 10))  # 굴 안쪽 깊이
            for k in range(26):  # 입구 둘레 잎(테두리가 반듯한 문처럼 보이지 않게)
                a = math.pi * (k / 25)
                lx = ex + math.cos(a) * 84 + hr.uniform(-6, 6)
                ly = 556 - math.sin(a) * 76 + hr.uniform(-6, 6)
                lr = hr.uniform(10, 20)
                L.ellipse((lx - lr, ly - lr * 0.7, lx + lr, ly + lr * 0.7), hr.choice([rgba(40, 74, 54), rgba(64, 98, 62), rgba(30, 58, 46)]))
            for k in range(8):
                ly = 560 + k * 30
                for d in (-1, 1):
                    lr = hr.uniform(9, 16)
                    lx = ex + d * (80 + hr.uniform(-6, 6))
                    L.ellipse((lx - lr, ly - lr * 0.7, lx + lr, ly + lr * 0.7), hr.choice([rgba(40, 74, 54), rgba(30, 58, 46)]))
        L.haze([("poly", [(x + dx - 160, -10), (x + dx - 60, -10), (x + dx + 70, 792), (x + dx - 70, 792)], gold)
                for dx in shaft_dxs], 18)
        motes(L, hr, hx0, hx1, 300, 780, 40, rgba(255, 230, 160, 230))
    # 4-3 빈터: 열린 하늘에서 큰 빛이 쏟아진다. 둘레는 풀과 꽃.
    x = mk("4-3", 6266)
    L.ellipse((x - 560, 768, x + 560, 834), rgba(110, 116, 74))
    L.ellipse((x - 380, 774, x + 380, 820), rgba(150, 146, 90))
    pa.strokes(L, tr, x - 560, x + 560, 772, 800, 260, rgba(110, 128, 70), rgba(200, 190, 120), (10, 34))
    flowers(L, tr, x - 520, x + 520, 776, 812, 160, rgba(250, 240, 200, 230))
    L.haze([("poly", [(x - 420, -10), (x + 220, -10), (x + 480, 792), (x - 300, 792)], rgba(255, 226, 150, 90))], 30)
    L.haze([("poly", [(x - 200, -10), (x + 20, -10), (x + 200, 792), (x - 80, 792)], rgba(255, 240, 200, 60))], 14)
    motes(L, tr, x - 640, x + 640, 240, 790, 90, rgba(255, 232, 160, 235))
    # 4-4 숲 끝 안개
    x = mk("4-4", 8546)
    L.haze(pa.mist(tr, x - 900, w + 200, 760, 180, rgba(190, 214, 208, 120), 20), 30)

    # 앞: 가늘고 흐린 줄기, 고사리, 늘어진 가지(하윤을 가리지 않게 듬성듬성).
    w = pa.layer_width(width, "front")
    layers["front"] = L = Layer(w)
    fr = random.Random("forest_front")
    x = fr.uniform(300, 700)
    while x < w:
        # 맨 앞 줄기는 없앤다(어두운 기둥이 화면을 갈랐다). 위에서 늘어진 가지만.
        x += fr.uniform(1400, 2600)
    x = fr.uniform(100, 400)
    while x < w:
        fern(L, fr, x, H + 40, fr.uniform(220, 320), rgba(22, 44, 34))
        x += fr.uniform(600, 1300)
    x = fr.uniform(400, 900)
    while x < w:
        for k in range(fr.randint(2, 4)):
            sx = x + k * 50
            L.line(pa.sag(sx, -10, sx + fr.uniform(-80, 80), fr.uniform(160, 300), 20, 8), rgba(22, 44, 36), 5)
            for j in range(6):  # 가지 끝 잎
                ly = fr.uniform(40, 280)
                lx = sx + fr.uniform(-20, 20)
                L.ellipse((lx - 14, ly - 6, lx + 14, ly + 6), rgba(26, 52, 40))
        x += fr.uniform(1100, 2000)
    return pa.finish(layers, "forest", GOLD, (40, 84, 96))
