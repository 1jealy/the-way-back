"""7. 나루터 (실루엣 화풍, #140).

시간을 알 수 없는 곳. 흰빛과 옅은 금빛이 화면을 채운다. 흰 백합 꽃밭(집 식탁의 그 꽃, #136),
작은 나무 나루터, 나룻배 한 척, 강 건너는 빛 속에 거의 지워졌다. 그림자는 거의 없고 아래로 갈수록
어두워지지 않는다(다른 장소와 반대로 밝아진다).

게임과 맞춘 것(바꾸지 말 것):
- 나루터 데크: dock_x = 7-3 - 260 (960)부터 오른쪽, 땅 y 792. 그 왼쪽이 꽃밭과 길.
- 나룻배: bx = 7-3 + 260 (1480) 가운데, 물 위 y 758~808(할아버지 Grandpa_7-3 x 1380 옆).
- 말뚝·밧줄: dock_x + 40~56.
"""

from __future__ import annotations

import math
import random

import placeholder_art as pa
from placeholder_art import H, Layer, rgba

LIGHT = (255, 250, 236)     # 화면을 채우는 빛
HAZE = (250, 244, 226)


def _pale(c, t, a=255):
    """색 c를 빛(HAZE)에 t만큼 녹인다. 멀수록, 시간 밖일수록 하얗다."""
    return rgba(*(round(c[i] + (HAZE[i] - c[i]) * t) for i in range(3)), a)


def _finish(layers, place_id, light, shade, tweak=None):
    saved = dict(pa.PAINT)
    try:
        for k, v in (tweak or {}).items():
            pa.PAINT[k] = v
        return pa.finish(layers, place_id, light, shade)
    finally:
        pa.PAINT.clear()
        pa.PAINT.update(saved)


# 나루터는 아래로 어두워지지 않는다: 세로 그늘(아래 어둠)을 아주 약하게, 질감은 고운 종이처럼.
BRIGHT_TWEAK = {
    "sky":     (0.0, 0.012, 0.008, 0.00, 0.00, 0.0, 0.0),
    "horizon": (2.4, 0.015, 0.006, 0.04, 0.02, 0.25, 0.02),
    "far":     (1.6, 0.020, 0.008, 0.05, 0.03, 0.35, 0.03),
    "hills":   (1.0, 0.025, 0.010, 0.06, 0.04, 0.45, 0.04),
    "mid":     (0.6, 0.030, 0.010, 0.06, 0.04, 0.45, 0.05),
    "near":    (0.0, 0.035, 0.012, 0.06, 0.05, 0.55, 0.06),
    "ground":  (0.0, 0.035, 0.012, 0.04, 0.06, 0.45, 0.08),
    "props":   (0.0, 0.035, 0.012, 0.05, 0.08, 0.7, 0.12),
    "front":   (3.2, 0.020, 0.008, 0.00, 0.04, 0.25, 0.04),
}


def lily(L: Layer, x: float, y: float, r: float, rng: random.Random, petal=rgba(252, 250, 244),
         back=rgba(226, 224, 214), heart=rgba(236, 214, 120), tilt: float = 0.0) -> None:
    """흰 백합 한 송이(옆에서 본 나팔꼴): 뒤 꽃잎 셋은 그늘색, 앞 꽃잎 셋은 흰색, 끝이 바깥으로 젖혀진다.
    가운데 수술 몇 가닥(끝이 금빛)."""
    def petal_poly(a: float, ln: float, wd: float):
        ca, sa = math.cos(a), math.sin(a)
        px, py = -sa, ca
        tip = (x + ca * ln, y + sa * ln * 0.8)
        mid = (x + ca * ln * 0.55, y + sa * ln * 0.55 * 0.8)
        curl = (tip[0] + ca * ln * 0.12 + px * wd * 0.6, tip[1] + sa * ln * 0.12 + py * wd * 0.6)
        return [(x + px * wd * 0.2, y + py * wd * 0.2), (mid[0] + px * wd, mid[1] + py * wd), tip, curl,
                (mid[0] - px * wd * 0.8, mid[1] - py * wd * 0.8), (x - px * wd * 0.2, y - py * wd * 0.2)]
    base = -math.pi / 2 + tilt  # 위쪽
    for k in range(3):
        a = base + (k - 1) * 0.95 + math.pi / 6 + rng.uniform(-0.1, 0.1)
        L.poly(petal_poly(a, r, r * 0.24), back)
    for k in range(3):
        a = base + (k - 1) * 0.95 + rng.uniform(-0.1, 0.1)
        L.poly(petal_poly(a, r * 1.05, r * 0.26), petal)
    for k in range(5):  # 수술
        a = base + (k - 2) * 0.22
        ex, ey = x + math.cos(a) * r * 0.75, y + math.sin(a) * r * 0.6
        L.line([(x, y), (ex, ey)], rgba(214, 214, 170), max(1.0, r * 0.04))
        L.ellipse((ex - r * 0.06, ey - r * 0.05, ex + r * 0.06, ey + r * 0.05), heart)


def lily_plant(L: Layer, rng: random.Random, x: float, base: float, h: float, stem=rgba(128, 150, 96),
               leaf=rgba(150, 172, 112), flowers: int = 2, petal=rgba(252, 250, 244), back=rgba(226, 224, 214)) -> None:
    """백합 한 포기: 곧은 줄기, 가는 잎 몇 장, 꼭대기에 꽃 한두 송이(옆을 본다)."""
    top = (x + rng.uniform(-8, 8), base - h)
    L.line([(x, base), (top[0], top[1] + h * 0.1)], stem, max(1.2, h * 0.025))
    for k in range(4):
        t = 0.25 + k * 0.15
        lx, ly = x + (top[0] - x) * t, base - h * t
        d = -1 if k % 2 else 1
        L.line([(lx, ly), (lx + d * h * 0.16, ly - h * 0.12), (lx + d * h * 0.26, ly - h * 0.06)], leaf, max(1.0, h * 0.03))
    for f in range(flowers):
        fx = top[0] + (f - 0.5) * h * 0.18
        fy = top[1] + f * h * 0.06
        lily(L, fx, fy, h * rng.uniform(0.16, 0.2), rng, petal=petal, back=back,
             tilt=rng.choice((-1.0, 1.0)) * rng.uniform(0.9, 1.3))


def glitter(L: Layer, rng: random.Random, cx: float, y0: float, y1: float, spread: float, n: int, color) -> None:
    """빛 아래 물비늘: 빛 쪽으로 모이는 짧은 가로 빛 조각."""
    for _ in range(n):
        y = rng.uniform(y0, y1)
        t = (y - y0) / max(y1 - y0, 1)
        x = cx + rng.gauss(0, spread * (0.3 + t))
        ln = rng.uniform(8, 40) * (0.5 + t)
        L.line([(x - ln / 2, y), (x + ln / 2, y)], color, rng.uniform(1.2, 2.6))


def paint(width: float, markers: dict[str, float]) -> dict[str, Layer]:
    rng = random.Random("ferry")
    deco = random.Random("ferry_deco")
    mk = markers.get
    layers: dict[str, Layer] = {}
    dock_x = mk("7-3", 1220) - 260
    bx = mk("7-3", 1220) + 260

    # ---------------------------------------------------------------- 하늘: 빛이 가득 찬 흰 금빛
    w = pa.layer_width(width, "sky")
    sky = pa.vertical_gradient(w, [
        (0.0, (226, 228, 232)), (0.35, (242, 240, 232)), (0.58, (252, 246, 228)), (0.72, (255, 240, 206)), (1.0, (250, 236, 206)),
    ])
    sx, sy = w * 0.78, 560
    pa.add_glow(sky, sx, sy, 1500, (255, 248, 226), 0.75)
    pa.add_glow(sky, sx, sy, 520, (255, 236, 190), 0.55)
    pa.add_glow(sky, sx, sy, 160, (255, 252, 240), 0.9)
    pa.paint_clouds(sky, rng, 5, w, 140, 380, (sx, sy), lit=(255, 252, 244), shade=(232, 226, 222),
                    glow=(255, 232, 196), size=(320, 600))
    layers["sky"] = L = Layer(w, sky)
    rays = []
    for k in range(11):  # 빛살: 넓고 옅게
        a = math.radians(150 + k * 22 + deco.uniform(-5, 5))
        a2 = a + math.radians(deco.uniform(4, 8))
        ln = deco.uniform(1200, 2000)
        rays.append(("poly", [(sx, sy), (sx + math.cos(a) * ln, sy + math.sin(a) * ln),
                              (sx + math.cos(a2) * ln, sy + math.sin(a2) * ln)], rgba(255, 246, 220, 40)))
    L.haze(rays, 24)

    # ---------------------------------------------------------------- 지평선: 빛에 지워져 가는 강 건너
    w = pa.layer_width(width, "horizon")
    layers["horizon"] = L = Layer(w)
    pts = pa.ridge(rng, w, 610, 30, waves=3)
    L.poly(pts, _pale((196, 198, 196), 0.6, 200))
    x = 80.0
    while x < w:
        pa._poplar(L, x, pa._ridge_y(pts, x) + 6, deco.uniform(50, 90), _pale((186, 190, 184), 0.6, 200), _pale((255, 250, 236), 0.2, 160))
        x += deco.uniform(160, 520)
    L.haze([("poly", [(-20, 590), (w + 20, 590), (w + 20, 680), (-20, 680)], rgba(*HAZE, 200))], 34)

    # ---------------------------------------------------------------- 먼 물가: 빛에 잠긴 낮은 섬과 둥근 나무
    w = pa.layer_width(width, "far")
    layers["far"] = L = Layer(w)
    body = _pale((150, 160, 142), 0.55, 230)
    rim = rgba(255, 248, 226, 220)
    pts = pa.ridge(rng, w, 652, 10, waves=2)
    L.poly(pts, body)
    x = deco.uniform(40, 200)
    while x < w:
        if deco.random() < 0.7:
            pa._blob_tree(L, deco, x, pa._ridge_y(pts, x) + 4, deco.uniform(18, 34), body, rim)
        else:
            pa._poplar(L, x, pa._ridge_y(pts, x) + 4, deco.uniform(70, 110), body, rim)
        x += deco.uniform(60, 260)
    L.haze([("poly", [(-20, 630), (w + 20, 630), (w + 20, 700), (-20, 700)], rgba(*HAZE, 150))], 26)

    # ---------------------------------------------------------------- 강: 빛 길과 물안개
    w = pa.layer_width(width, "mid")
    layers["mid"] = L = Layer(w)
    L.rect(-20, 650, w + 20, H, rgba(222, 226, 228))
    L.haze([("poly", [(-20, 760), (w + 20, 760), (w + 20, H + 10), (-20, H + 10)], rgba(196, 204, 212, 160))], 40)
    refl = []
    for _ in range(8):  # 물에 비친 구름(흐리게)
        cx, cy = deco.uniform(0, w), deco.uniform(700, 780)
        cw = deco.uniform(200, 420)
        refl.append(("ellipse", (cx - cw / 2, cy - 12, cx + cw / 2, cy + 12), rgba(255, 250, 240, 120)))
    L.haze(refl, 10)
    L.haze([("poly", [(-20, 650), (w + 20, 650), (w + 20, 700), (-20, 700)], rgba(255, 246, 222, 230))], 14)
    pa.water_streaks(L, rng, 0, w, 662, H, int(w / 18), rgba(210, 216, 222, 150))
    glitter(L, deco, pa.layer_x(2900, "mid"), 660, 800, 260, 420, rgba(255, 238, 190, 210))
    L.haze(pa.mist(rng, 0, w, 668, 90, rgba(255, 253, 246, 170), int(w / 180)), 28)

    # ---------------------------------------------------------------- 가까운 물: 물비늘, 떠 있는 꽃잎
    w = pa.layer_width(width, "near")
    layers["near"] = L = Layer(w)
    pa.water_streaks(L, rng, 0, w, 770, H, int(w / 16), rgba(214, 220, 226, 140))
    glitter(L, deco, pa.layer_x(2900, "near"), 770, H, 420, 300, rgba(255, 240, 196, 190))
    for _ in range(26):  # 물에 뜬 흰 꽃잎
        x, y = deco.uniform(pa.layer_x(dock_x, "near"), w), deco.uniform(800, H)
        r = deco.uniform(4, 8)
        L.ellipse((x - r, y - r * 0.4, x + r, y + r * 0.4), rgba(255, 252, 244, 220))

    # ---------------------------------------------------------------- 땅: 백합 꽃밭과 길, 나루터 데크
    w = pa.layer_width(width, "ground")
    layers["ground"] = L = Layer(w)
    meadow, meadow_lit = rgba(206, 210, 176), rgba(234, 232, 200)
    shore = [(-20, 744), (dock_x + 10, 752), (dock_x + 40, 800), (dock_x - 30, 880), (dock_x - 160, 980), (dock_x - 260, H + 10), (-20, H + 10)]
    L.poly(shore, meadow)  # 꽃밭 바닥(오른쪽은 물가로 비스듬히 내려간다)
    L.poly([(dock_x + 40, 800), (dock_x + 60, 812), (dock_x - 10, 892), (dock_x - 140, 992), (dock_x - 240, H + 10), (dock_x - 260, H + 10),
            (dock_x - 160, 980), (dock_x - 30, 880)], rgba(184, 176, 150))  # 물가 흙
    L.haze([("poly", [(-20, 744), (dock_x, 750), (dock_x, 770), (-20, 764)], rgba(*meadow_lit[:3], 200))], 6)
    for _ in range(int(dock_x / 3)):  # 풀 결
        x, y = deco.uniform(0, dock_x), deco.uniform(748, H)
        if x > dock_x - 260 + (H - y) * 0.9:
            continue
        hh = deco.uniform(8, 22) * (0.6 + (y - 748) / 300)
        L.line([(x, y), (x + deco.uniform(-6, 2), y - hh)], pa.lerp_color(rgba(160, 176, 128), rgba(238, 236, 206), deco.random()), 1.6)
    path_top = [(float(x), 792 + deco.uniform(-2, 2)) for x in range(-20, int(dock_x) + 40, 40)]
    path_bot = [(float(x), 858 + deco.uniform(-4, 4)) for x in range(int(dock_x) + 40, -60, -40)]
    L.poly(path_top + path_bot, rgba(232, 222, 196))  # 흰 흙길
    for _ in range(60):
        x = deco.uniform(0, dock_x)
        L.line([(x, 800 + deco.uniform(0, 50)), (x + deco.uniform(20, 60), 800 + deco.uniform(0, 50))], rgba(214, 202, 176, 150), 2)
    for _ in range(int(dock_x / 9)):  # 길 뒤 꽃밭(작게, 멀리)
        lily_plant(L, deco, deco.uniform(0, dock_x - 20), deco.uniform(758, 790), deco.uniform(34, 56), flowers=1)
    for _ in range(int(dock_x / 16)):  # 길 앞 꽃밭(크게)
        yb = deco.uniform(890, H + 10)
        lily_plant(L, deco, deco.uniform(0, dock_x - 280 + (H - yb) * 0.8), yb, deco.uniform(70, 120), flowers=deco.randint(1, 2))
    L.poly([(dock_x + 60, 812), (w + 20, 812), (w + 20, H + 10), (dock_x - 240, H + 10), (dock_x - 140, 992), (dock_x - 10, 892)],
           rgba(220, 226, 230))  # 데크 아래·물가 앞 물
    L.haze([("poly", [(dock_x, 830), (w + 20, 830), (w + 20, 880), (dock_x, 880)], rgba(150, 150, 160, 110))], 10)  # 데크 그늘
    pa.water_streaks(L, rng, dock_x, w, 860, H, 60, rgba(255, 242, 210, 170))
    for x in range(int(dock_x) + 40, int(w), 300):  # 기둥과 물에 비친 그림자
        L.rect(x - 10, 830, x + 10, 960, rgba(176, 146, 108))
        L.rect(x - 10, 960, x + 10, 1010, rgba(196, 176, 150, 120))
    L.rect(dock_x, 792, w + 20, 830, rgba(176, 140, 98))  # 나루터 데크
    L.rect(dock_x, 792, w + 20, 797, rgba(236, 214, 170))
    L.rect(dock_x, 826, w + 20, 834, rgba(170, 140, 102))
    for x in range(int(dock_x), int(w), 44):
        L.line([(x, 796), (x, 828)], rgba(178, 148, 108), 2)
        L.ellipse((x + 6, 800, x + 10, 804), rgba(150, 124, 96))
        L.ellipse((x + 6, 818, x + 10, 822), rgba(150, 124, 96))

    # ---------------------------------------------------------------- 하윤 뒤: 버드나무, 나룻배, 말뚝, 등불
    w = pa.layer_width(width, "props")
    layers["props"] = L = Layer(w)
    # 꽃밭 뒤 늙은 버드나무(왼쪽 끝): 줄기와 늘어진 가지가 빛에 비친다
    wx = 150.0
    trunk, trunk_lit = rgba(132, 118, 96), rgba(196, 180, 150)
    L.poly([(wx - 34, 792), (wx + 38, 792), (wx + 22, 640), (wx + 30, 560), (wx + 6, 500), (wx - 14, 560), (wx - 20, 650)], trunk)
    L.poly([(wx + 14, 792), (wx + 38, 792), (wx + 22, 640), (wx + 30, 560), (wx + 18, 540), (wx + 14, 650)], trunk_lit)
    for (ex, ey, wd) in ((wx + 150, 400, 12), (wx - 120, 420, 11), (wx + 40, 360, 10), (wx + 230, 470, 8)):
        L.line([(wx + 6, 540), ((wx + 6 + ex) / 2, (540 + ey) / 2 - 30), (ex, ey)], trunk, wd)
    crown = []
    for _ in range(14):  # 잎 덩어리(뒤)
        cx, cy = wx + deco.uniform(-200, 280), deco.uniform(330, 470)
        r = deco.uniform(50, 90)
        crown.append(("ellipse", (cx - r, cy - r * 0.6, cx + r, cy + r * 0.6), rgba(170, 190, 130, 170)))
    L.under(crown, 10)
    for _ in range(140):  # 늘어진 버들가지: 끝이 바람 쪽으로 살짝 휜다
        tx = wx + deco.uniform(-230, 300)
        ty = deco.uniform(320, 470)
        ln = deco.uniform(150, 330)
        sway = deco.uniform(-30, -4)
        L.line([(tx, ty), (tx + sway * 0.2, ty + ln * 0.5), (tx + sway, ty + ln)],
               pa.lerp_color(rgba(140, 170, 104, 200), rgba(222, 236, 176, 230), deco.random()), deco.uniform(1.6, 3.0))
    # 나룻배: 나무 판, 갈빗대, 밝은 뱃전, 앞에 작은 등
    hull = [(bx - 290, 760), (bx + 300, 756), (bx + 240, 790), (bx + 200, 808), (bx - 210, 810), (bx - 250, 792)]
    L.poly(hull, rgba(150, 112, 78))
    for k in range(4):  # 판자 줄
        yy = 768 + k * 10
        L.line([(bx - 270 + k * 12, yy), (bx + 270 - k * 18, yy - 2)], rgba(128, 94, 66), 2)
    L.line([(bx - 286, 760), (bx + 296, 756)], rgba(222, 192, 146), 6)  # 뱃전
    for rx in range(int(bx - 200), int(bx + 220), 70):  # 갈빗대
        L.line([(rx, 760), (rx + 4, 790)], rgba(120, 88, 62), 4)
    L.rect(bx - 90, 768, bx + 90, 776, rgba(124, 94, 66))  # 가로 의자
    L.line([(bx + 40, 772), (bx + 260, 738)], rgba(170, 138, 100), 6)  # 쉬고 있는 노
    L.ellipse((bx + 250, 732, bx + 276, 744), rgba(170, 138, 100))
    L.line([(bx + 290, 756), (bx + 300, 690)], rgba(120, 92, 66), 4)  # 뱃머리 등대
    L.ellipse((bx + 290, 674, bx + 310, 694), rgba(255, 226, 160))
    L.haze([("ellipse", (bx + 240, 630, bx + 360, 740), rgba(255, 224, 160, 110))], 14)
    L.haze([("poly", [(bx - 280, 812), (bx + 280, 808), (bx + 240, 830), (bx - 240, 832)], rgba(110, 96, 86, 60))], 8)  # 물에 진 배 그림자
    L.rect(dock_x + 40, 700, dock_x + 56, 792, rgba(156, 124, 90))  # 말뚝
    L.rect(dock_x + 40, 700, dock_x + 56, 706, rgba(210, 180, 140))
    L.line([(dock_x + 50, 712), (bx - 150, 752), (bx - 270, 768)], rgba(190, 170, 136), 3)  # 밧줄(살짝 처진다)
    for x in range(int(dock_x + 300), int(w), 400):  # 데크 난간 기둥과 등불
        L.rect(x - 8, 700, x + 8, 792, rgba(176, 144, 106))
        L.rect(x - 14, 688, x + 14, 704, rgba(150, 120, 88))
        L.ellipse((x - 8, 672, x + 8, 690), rgba(255, 230, 170))
        L.haze([("ellipse", (x - 60, 620, x + 60, 740), rgba(255, 228, 170, 90))], 14)
    for _ in range(14):  # 데크 옆 물가 백합
        lily_plant(L, deco, deco.uniform(dock_x - 40, dock_x + 30), deco.uniform(790, 800), deco.uniform(60, 90), flowers=1)

    # ---------------------------------------------------------------- 앞: 가까운 백합(흐리게), 떠다니는 꽃잎, 물안개
    w = pa.layer_width(width, "front")
    layers["front"] = L = Layer(w)
    fend = pa.layer_x(dock_x, "front")
    x = 120.0
    while x < fend:
        for _ in range(deco.randint(3, 6)):
            lily_plant(L, deco, x + deco.gauss(0, 60), H + 20, deco.uniform(190, 260), stem=rgba(150, 170, 120),
                       leaf=rgba(170, 190, 136), flowers=deco.randint(1, 2))
        x += deco.uniform(500, 1000)
    for _ in range(40):
        px, py = deco.uniform(0, w), deco.uniform(80, H - 100)
        r = deco.uniform(3, 7)
        L.ellipse((px - r, py - r * 0.5, px + r, py + r * 0.5), rgba(255, 252, 240, 160))
    L.haze(pa.mist(rng, 0, w, H - 40, 140, rgba(255, 255, 252, 130), int(w / 260)), 30)

    return _finish(layers, "ferry", (255, 246, 224), (236, 232, 226), tweak=BRIGHT_TWEAK)
