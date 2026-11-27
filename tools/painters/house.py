"""1. 산 아래 할아버지 집 (#140, 실루엣 화풍 + 그림 마무리).

늦가을 오후. 꿀빛 벽, 따뜻한 나무 바닥. 빛은 왼쪽 큰 창에서 비스듬히 들어온다.
방(1-1) → 현관·식탁(1-2) → 거실(1-3) → 서재·계단(1-4·1-5) → 현관문 → 마당(1-6, 사과나무·돌담·나무 대문).
창은 벽에 뚫린 구멍이라 뒤 층(하늘·산·단풍 숲)이 시차로 비친다 — 걸으면 창밖 풍경이 천천히 흐른다.
게임 부품 자리(장면 표시, 서랍 3220, 액자 3430, 사과나무 5070, 영정 1245·1435 y≈380)는 예전 그림과 같다.
"""
from __future__ import annotations

import math
import random

import placeholder_art as pa
from placeholder_art import H, Layer, rgba

# 주의: Layer.shapes에 반투명 색을 그리면 그 자리 알파가 그 값으로 바뀐다(아래 그림이 비친다).
# 불투명한 것 위에 옅게 덧칠할 때는 _over(Layer.haze로 합성)를 쓴다.


def _over(L: Layer, shapes, radius: float = 0.6) -> None:
    """반투명 덧칠: 같은 색끼리 묶어 haze(합성)로 얹는다."""
    groups: dict = {}
    for sh in shapes:
        groups.setdefault(sh[2], []).append(sh)
    for g in groups.values():
        L.haze(g, radius)

LIGHT = (255, 222, 170)   # 늦가을 오후 햇빛
SHADE = (104, 96, 140)    # 그늘에 섞는 하늘빛
YARD_X = 4750.0           # 여기까지 집 안, 그다음 마당
WALL_TOP, WALL_BOTTOM = 150.0, 792.0


def _wall_with_holes(L: Layer, x0: float, x1: float, y0: float, y1: float, holes, color) -> None:
    """네모난 벽을 구멍(창)만 남기고 칠한다. holes = [(hx0, hy0, hx1, hy1)]."""
    xs = sorted({x0, x1, *[h[0] for h in holes], *[h[2] for h in holes]})
    xs = [x for x in xs if x0 <= x <= x1]
    for a, b in zip(xs, xs[1:]):
        cover = sorted((h[1], h[3]) for h in holes if h[0] <= a and h[2] >= b)
        y = y0
        for hy0, hy1 in cover:
            if hy0 > y:
                L.rect(a, y, b, hy0, color)
            y = max(y, hy1)
        if y < y1:
            L.rect(a, y, b, y1, color)


def _window(L: Layer, x0, y0, x1, y1, frame, light_c, cross=True, curtain=None) -> None:
    """창틀(구멍은 이미 뚫려 있다): 바깥 테, 가운데 살, 유리의 옅은 반사, 창턱, 커튼."""
    t = 12
    L.rect(x0 - t, y0 - t, x1 + t, y0, frame)
    L.rect(x0 - t, y1, x1 + t, y1 + t, frame)
    L.rect(x0 - t, y0, x0, y1, frame)
    L.rect(x1, y0, x1 + t, y1, frame)
    if cross:
        mx, my = (x0 + x1) / 2, y0 + (y1 - y0) * 0.42
        L.rect(mx - 4, y0, mx + 4, y1, frame)
        L.rect(x0, my - 4, x1, my + 4, frame)
    # 유리 반사: 비스듬한 옅은 띠
    L.poly([(x0 + (x1 - x0) * 0.15, y0), (x0 + (x1 - x0) * 0.32, y0), (x0 + (x1 - x0) * 0.08, y1), (x0, y1), (x0, y1 - 20)],
           rgba(255, 250, 236, 38))
    L.rect(x0 - t - 14, y1 + t, x1 + t + 14, y1 + t + 12, rgba(150, 106, 70))  # 창턱
    L.rect(x0 - t - 14, y1 + t, x1 + t + 14, y1 + t + 3, light_c)
    if curtain:
        for side in (-1, 1):
            cx = x0 - 6 if side < 0 else x1 + 6
            pts = [(cx, y0 - 30), (cx - side * 46, y0 - 30), (cx - side * 30, y1 * 0.5 + y0 * 0.5),
                   (cx - side * 56, y1 + 40), (cx, y1 + 40)]
            L.poly(pts, curtain)
            L.line([(cx - side * 20, y0 - 20), (cx - side * 14, y1 + 30)], pa.lerp_color(curtain, rgba(40, 20, 20), 0.3), 4)
        L.rect(x0 - 70, y0 - 40, x1 + 70, y0 - 32, rgba(96, 66, 44))  # 커튼 봉


def _lily(L: Layer, x: float, y: float, s: float) -> None:
    """흰 백합 한 송이(장례 꽃): 나팔 모양 꽃잎 여섯, 노란 꽃밥."""
    petal, sh = rgba(250, 248, 240), rgba(214, 212, 206)
    for k in range(6):
        a = -math.pi / 2 + (k - 2.5) * 0.42
        ex, ey = x + math.cos(a) * 26 * s, y + math.sin(a) * 22 * s
        L.poly([(x, y + 6 * s), (ex - 6 * s, ey + 2 * s), (ex + math.cos(a) * 8 * s, ey + math.sin(a) * 8 * s), (ex + 6 * s, ey + 4 * s)],
               petal if k % 2 else sh)
    for k in range(3):
        L.line([(x, y), (x + (k - 1) * 8 * s, y - 16 * s)], rgba(200, 150, 60), 1.5)


def _armchair(L: Layer, x: float, base: float, c: rgba, dark) -> None:
    L.poly([(x - 90, base - 70), (x + 90, base - 70), (x + 96, base - 210), (x - 76, base - 220)], c)  # 등받이
    L.rect(x - 110, base - 100, x + 110, base - 60, c)  # 앉는 자리
    for ax in (x - 120, x + 96):
        L.poly([(ax, base - 140), (ax + 26, base - 140), (ax + 26, base - 50), (ax, base - 50)], dark)
    for lx in (x - 100, x + 96):
        L.rect(lx, base - 60, lx + 10, base, dark)


def _bookshelf(L: Layer, rng: random.Random, x0: float, x1: float, y0: float, base: float, wood, dark) -> None:
    L.rect(x0, y0, x1, base, dark)
    shelves = 5
    for k in range(shelves):
        sy = y0 + 14 + (base - y0 - 20) * k / shelves
        ey = y0 + 14 + (base - y0 - 20) * (k + 1) / shelves - 8
        L.rect(x0 + 8, ey, x1 - 8, ey + 8, wood)
        bx = x0 + 12
        while bx < x1 - 20:
            bw = rng.uniform(9, 18)
            bh = (ey - sy) * rng.uniform(0.6, 0.95)
            c = rng.choice([rgba(140, 60, 48), rgba(70, 96, 112), rgba(160, 126, 70), rgba(92, 110, 70), rgba(120, 84, 60)])
            if rng.random() < 0.12:  # 비스듬히 기댄 책
                L.poly([(bx, ey), (bx + bw, ey), (bx + bw + bh * 0.35, ey - bh), (bx + bh * 0.35, ey - bh)], c)
                bx += bw + bh * 0.35
            else:
                L.rect(bx, ey - bh, bx + bw, ey, c)
                bx += bw + 1
    L.rect(x0, y0, x1, y0 + 14, wood)


def _clock(L: Layer, x: float, base: float, wood, dark, face) -> None:
    """괘종시계: 긴 나무 몸통, 둥근 판, 추."""
    L.rect(x - 34, base - 420, x + 34, base, wood)
    L.poly([(x - 44, base - 420), (x + 44, base - 420), (x + 30, base - 456), (x - 30, base - 456)], dark)
    L.ellipse((x - 26, base - 400, x + 26, base - 348), face)
    L.line([(x, base - 374), (x + 10, base - 386)], dark, 3)
    L.line([(x, base - 374), (x - 4, base - 356)], dark, 2)
    L.rect(x - 20, base - 330, x + 20, base - 120, dark)
    L.line([(x, base - 326), (x, base - 180)], rgba(200, 166, 90), 2)
    L.ellipse((x - 12, base - 192, x + 12, base - 168), rgba(214, 178, 96))


def _stairs(L: Layer, x0: float, base: float, wood, dark, steps: int = 11) -> None:
    """다락으로 오르는 나무 계단(오른쪽 위로). 난간과 기둥."""
    sw, sh = 30, 56
    for k in range(steps):
        sx = x0 + k * sw
        sy = base - (k + 1) * sh
        L.rect(sx, sy, sx + sw + 2, base, dark if k % 2 else wood)
        L.rect(sx, sy, sx + sw + 2, sy + 6, rgba(196, 146, 96))
    top = (x0 + steps * sw, base - steps * sh)
    L.line([(x0, base - 120), (top[0], top[1] - 120)], dark, 8)  # 난간
    for k in range(0, steps, 2):
        px = x0 + k * sw + 10
        L.line([(px, base - (k + 1) * sh), (px, base - (k + 1) * sh - 120 + 0)], dark, 4)
    L.rect(top[0] - 14, top[1] - 170, top[0] + 210, top[1] + 8, rgba(110, 76, 50))  # 다락 입구 테
    L.rect(top[0] - 4, top[1] - 160, top[0] + 200, top[1], rgba(76, 52, 36))  # 다락 입구
    L.haze([("poly", [(top[0] + 40, top[1] - 150), (top[0] + 130, top[1] - 150), (top[0] + 60, top[1]), (top[0] - 10, top[1])],
             rgba(255, 220, 150, 90))], 12)  # 다락 창에서 새는 빛


def _painting(L: Layer, rng: random.Random, x: float, y: float, w: float, h: float, frame, kind: str) -> None:
    """벽에 건 작은 그림: 금빛 액자 안에 산·바다·꽃 풍경."""
    L.rect(x - 8, y - 8, x + w + 8, y + h + 8, frame)
    L.rect(x - 8, y - 8, x + w + 8, y - 4, rgba(236, 200, 120))
    if kind == "hills":
        L.rect(x, y, x + w, y + h, rgba(196, 212, 222))
        L.poly([(x, y + h * 0.6), (x + w * 0.3, y + h * 0.35), (x + w * 0.6, y + h * 0.55), (x + w, y + h * 0.4), (x + w, y + h), (x, y + h)], rgba(120, 140, 100))
        L.poly([(x, y + h * 0.8), (x + w * 0.5, y + h * 0.65), (x + w, y + h * 0.75), (x + w, y + h), (x, y + h)], rgba(170, 150, 80))
    elif kind == "sea":
        L.rect(x, y, x + w, y + h * 0.55, rgba(232, 200, 160))
        L.rect(x, y + h * 0.55, x + w, y + h, rgba(90, 120, 150))
        L.ellipse((x + w * 0.6, y + h * 0.3, x + w * 0.8, y + h * 0.5), rgba(250, 220, 160))
        L.poly([(x + w * 0.2, y + h * 0.55), (x + w * 0.3, y + h * 0.3), (x + w * 0.32, y + h * 0.55)], rgba(244, 236, 220))
    else:
        L.rect(x, y, x + w, y + h, rgba(70, 60, 56))
        for _ in range(7):
            fx, fy = x + rng.uniform(0.2, 0.8) * w, y + rng.uniform(0.2, 0.7) * h
            L.ellipse((fx - 8, fy - 8, fx + 8, fy + 8), rng.choice([rgba(214, 96, 70), rgba(240, 214, 120), rgba(236, 232, 220)]))
        L.poly([(x + w * 0.35, y + h), (x + w * 0.65, y + h), (x + w * 0.6, y + h * 0.7), (x + w * 0.4, y + h * 0.7)], rgba(150, 110, 80))


def _sconce(L: Layer, x: float, y: float, dark) -> None:
    L.rect(x - 4, y, x + 4, y + 40, dark)
    L.poly([(x - 16, y - 6), (x + 16, y - 6), (x + 10, y - 34), (x - 10, y - 34)], rgba(246, 222, 170))


def paint(width: float, markers: dict[str, float]) -> dict[str, Layer]:
    rng = random.Random("house2")
    mk = markers.get
    layers: dict[str, Layer] = {}

    # ---------------- 하늘: 늦가을 오후. 창과 마당 위로만 보인다.
    w = pa.layer_width(width, "sky")
    sky = pa.vertical_gradient(w, [
        (0.0, (104, 146, 196)), (0.35, (162, 190, 214)), (0.6, (232, 216, 186)), (0.75, (246, 204, 152)), (1.0, (236, 190, 140)),
    ])
    pa.add_glow(sky, w * 0.15, 520, 1000, (255, 220, 160), 0.45)
    pa.paint_clouds(sky, rng, 5, w, 150, 380, (w * 0.15, 520), lit=(255, 246, 232), shade=(190, 176, 198), glow=(255, 204, 160))
    layers["sky"] = Layer(w, sky)

    # ---------------- 지평선: 집 뒤의 큰 산(산 아래 할아버지 집)
    w = pa.layer_width(width, "horizon")
    layers["horizon"] = L = Layer(w)
    pts = pa.ridge(rng, w, 380, 220, waves=3)
    L.poly(pts, rgba(150, 140, 170))
    pa._slope_shade(L, pts, rgba(96, 90, 136, 80), 300, 30)
    dots = []
    for _ in range(int(w / 6)):  # 산허리 단풍 숲: 작은 점
        x = rng.uniform(0, w)
        y = pa._ridge_y(pts, x) + rng.uniform(30, 300)
        r = rng.uniform(5, 10)
        c = rng.choice([rgba(196, 140, 120, 150), rgba(206, 166, 120, 150), rgba(170, 128, 130, 150)])
        dots.append(("ellipse", (x - r, y - r, x + r, y + r), c))
    _over(L, dots, 1.0)
    L.haze([("poly", [(-20, 560), (w + 20, 560), (w + 20, 660), (-20, 660)], rgba(248, 220, 176, 140))], 30)

    # ---------------- 먼 언덕: 단풍 든 숲 덩어리, 작은 교회 첨탑
    w = pa.layer_width(width, "far")
    layers["far"] = L = Layer(w)
    pts = pa.ridge(rng, w, 520, 70, waves=3)
    body = rgba(176, 130, 110)
    L.poly(pts, body)
    for _ in range(int(w / 14)):
        x = rng.uniform(0, w)
        y = pa._ridge_y(pts, x) + rng.uniform(-4, 60)
        r = rng.uniform(12, 24)
        c = rng.choice([rgba(214, 140, 92), rgba(198, 108, 80), rgba(222, 176, 96), rgba(170, 120, 96)])
        L.ellipse((x - r, y - r * 1.2, x + r, y + r * 0.5), c)
    pa._village(L, rng, w * 0.45, lambda gx: pa._ridge_y(pts, gx), rgba(176, 140, 130), rgba(255, 226, 170, 200))
    L.haze([("poly", [(-20, 600), (w + 20, 600), (w + 20, 680), (-20, 680)], rgba(248, 222, 180, 110))], 24)

    # ---------------- 구릉: 가까운 단풍 나무들(창밖으로 가장 잘 보인다)
    w = pa.layer_width(width, "hills")
    layers["hills"] = L = Layer(w)
    pts = pa.ridge(rng, w, 600, 40, waves=3)
    L.poly(pts, rgba(160, 120, 76))
    x = 40.0
    while x < w:
        r = rng.uniform(40, 80)
        c = rng.choice([rgba(222, 130, 60), rgba(206, 90, 54), rgba(234, 184, 82), rgba(168, 118, 64), rgba(196, 150, 70)])
        pa._blob_tree(L, rng, x, pa._ridge_y(pts, x) + 8, r, c, rgba(255, 220, 150, 230))
        x += rng.uniform(60, 150)

    # ---------------- 가운데: 담 너머 이웃집 지붕과 나무
    w = pa.layer_width(width, "mid")
    layers["mid"] = L = Layer(w)
    hill = pa.ridge(rng, w, 660, 20, waves=2)
    L.poly(hill, rgba(150, 110, 70))
    for k in range(int(w / 900)):
        fx = rng.uniform(200, w - 300)
        pa._farmhouse(L, fx, pa._ridge_y(hill, fx) + 10, 1.0, rgba(232, 214, 186), rgba(170, 72, 52), rgba(255, 224, 160, 230))
    x = 60.0
    while x < w:
        c = rng.choice([rgba(200, 96, 50), rgba(226, 160, 66), rgba(150, 96, 52), rgba(186, 70, 48)])
        pa._oak(L, rng, x, pa._ridge_y(hill, x) + 8, rng.uniform(40, 60), c, rgba(255, 222, 150, 230), rgba(90, 60, 40))
        x += rng.uniform(260, 560)

    # ---------------- 가까운 곳: 마당 돌담 너머 산울타리와 꽃덤불(마당에서 담 위로 보인다)
    w = pa.layer_width(width, "near")
    layers["near"] = L = Layer(w)
    band = pa.ridge(rng, w, 600, 16, step=30)
    L.poly(band, rgba(120, 104, 58))
    x = 0.0
    while x < w:
        r = rng.uniform(30, 56)
        pa._blob_tree(L, rng, x, pa._ridge_y(band, x) + 30, r, rgba(112, 104, 54), rgba(255, 220, 150, 220), trunk=False)
        x += rng.uniform(36, 70)
    for _ in range(int(w / 12)):
        x = rng.uniform(0, w)
        y = pa._ridge_y(band, x) + rng.uniform(-30, 30)
        c = rng.choice([rgba(222, 110, 70), rgba(246, 210, 120), rgba(240, 236, 226)])
        L.ellipse((x - 3, y - 3, x + 3, y + 3), c)

    # ---------------- 땅: 집 안 나무 바닥(러그 셋), 마당 흙과 낙엽
    w = pa.layer_width(width, "ground")
    layers["ground"] = L = Layer(w)
    L.rect(-20, 792, YARD_X + 10, H, rgba(150, 96, 56))
    for y in range(810, H, 30):  # 마루 널
        L.line([(-20, y), (YARD_X, y)], rgba(118, 74, 42), 2)
    for _ in range(int(YARD_X / 60)):
        x, y = rng.uniform(0, YARD_X), rng.choice(range(792, H, 30))
        L.line([(x, y + 2), (x, y + 28)], rgba(118, 74, 42), 2)
    grain = []
    for _ in range(int(YARD_X / 30)):  # 나뭇결
        x, y = rng.uniform(0, YARD_X), rng.uniform(796, H)
        grain.append(("line", [(x, y), (x + rng.uniform(40, 140), y + rng.uniform(-1, 1))], rgba(170, 112, 66, 120), 1.4))
    _over(L, grain)
    L.rect(-20, 792, YARD_X + 10, 798, rgba(196, 140, 88))
    for rx0, rx1, c, edge in ((260, 900, rgba(150, 56, 46), rgba(214, 168, 96)),
                               (1900, 2560, rgba(70, 86, 110), rgba(206, 170, 110)),
                               (3080, 3600, rgba(120, 76, 56), rgba(206, 170, 110))):
        L.poly([(rx0, 812), (rx1, 812), (rx1 + 60, 900), (rx0 - 60, 900)], c)  # 러그(원근)
        L.line([(rx0 + 10, 818), (rx1 - 10, 818)], edge, 3)
        L.line([(rx0 - 40, 892), (rx1 + 40, 892)], edge, 3)
        for k in range(1, 6):
            t = k / 6
            L.line([(rx0 + (rx1 - rx0) * t, 822), (rx0 - 60 + (rx1 - rx0 + 120) * t, 888)], pa.lerp_color(c, rgba(0, 0, 0), 0.15), 2)
    L.rect(YARD_X, 792, w + 20, H, rgba(170, 140, 98))  # 마당 흙
    pa.pebbles(L, rng, YARD_X, w, 800, H, int((w - YARD_X) / 6), rgba(150, 124, 90), rgba(200, 172, 128))
    for _ in range(int((w - YARD_X) / 4)):  # 떨어진 단풍잎
        x, y = rng.uniform(YARD_X, w), rng.uniform(800, H)
        c = rng.choice([rgba(214, 110, 50), rgba(232, 170, 70), rgba(186, 70, 46)])
        a = rng.uniform(0, math.tau)
        L.poly([(x + math.cos(a) * 7, y + math.sin(a) * 3), (x + math.cos(a + 2.1) * 6, y + math.sin(a + 2.1) * 3),
                (x + math.cos(a + 4.2) * 6, y + math.sin(a + 4.2) * 3)], c)
    pa.strokes(L, rng, YARD_X + 300, w, 792, 808, int((w - YARD_X) / 8), rgba(120, 110, 60), rgba(180, 160, 90), (10, 34))
    L.rect(YARD_X - 60, 786, YARD_X + 120, 812, rgba(160, 152, 140))  # 문간 돌계단
    L.rect(YARD_X - 60, 786, YARD_X + 120, 790, rgba(214, 206, 190))

    # ---------------- 하윤 뒤 물건: 벽·창·가구, 바깥벽·사과나무·돌담·대문
    w = pa.layer_width(width, "props")
    layers["props"] = L = Layer(w)
    plaster, plaster_dk = rgba(222, 196, 156), rgba(196, 166, 126)
    wood, dark, frame = rgba(150, 100, 62), rgba(98, 64, 42), rgba(120, 80, 50)
    windows = [(110.0, 300.0, 630.0, 620.0), (2380.0, 300.0, 2620.0, 560.0), (4040.0, 300.0, 4320.0, 600.0)]
    L.rect(-20, 0, YARD_X, WALL_TOP, rgba(110, 76, 52))  # 천장
    for x in range(0, int(YARD_X), 220):  # 들보
        L.rect(x, 0, x + 26, WALL_TOP, rgba(86, 58, 40))
        L.rect(x + 20, 0, x + 26, WALL_TOP, rgba(150, 104, 70))
    _wall_with_holes(L, -20, YARD_X, WALL_TOP, 560, windows, plaster)  # 윗벽(회벽)
    stripes = []
    for x in range(-20, int(YARD_X), 64):  # 벽지 줄무늬(옅게) — 창 구멍은 건너뛴다
        for (a0, b0, a1, b1) in [(x, WALL_TOP, x + 26, 560)]:
            ys = [(WALL_TOP, 560)]
            for hx0, hy0, hx1, hy1 in windows:
                if a1 > hx0 - 12 and a0 < hx1 + 12:
                    ys = [(WALL_TOP, hy0 - 12)]
            for y0, y1 in ys:
                stripes.append(("poly", [(a0, y0), (a1, y0), (a1, y1), (a0, y1)], rgba(255, 240, 210, 30)))
    _over(L, stripes, 0.8)
    _wall_with_holes(L, -20, YARD_X, 560, 762, windows, wood)  # 아래 나무 판벽
    for x in range(-20, int(YARD_X), 120):
        L.rect(x, 572, x + 4, 760, dark)
    L.rect(-20, 556, YARD_X, 566, dark)  # 판벽 위 몰딩
    L.rect(-20, 762, YARD_X, 792, dark)  # 걸레받이
    L.rect(-20, WALL_TOP, YARD_X, WALL_TOP + 22, dark)  # 천장 몰딩
    deco = random.Random("house_deco")
    dots = []
    for x in range(-10, int(YARD_X), 64):  # 벽지 잔무늬(작은 꽃점)
        for y in range(int(WALL_TOP) + 50, 540, 70):
            if any(hx0 - 30 < x < hx1 + 30 and hy0 - 40 < y < hy1 + 40 for hx0, hy0, hx1, hy1 in windows):
                continue
            if 1150 < x < 1530 and 260 < y < 500:  # 영정 자리
                continue
            dots.append(("ellipse", (x + 32 - 3, y - 3 + (x // 64 % 2) * 35, x + 32 + 3, y + 3 + (x // 64 % 2) * 35), rgba(190, 150, 110, 120)))
    _over(L, dots, 0.5)
    # 벽 그림·접시 선반·벽등(빈 벽을 채운다)
    _painting(L, deco, 700, 250, 120, 86, rgba(176, 136, 70), "flowers")
    _painting(L, deco, 1700, 300, 180, 120, rgba(176, 136, 70), "hills")
    _painting(L, deco, 2040, 260, 110, 150, rgba(150, 110, 60), "sea")
    _painting(L, deco, 3560, 250, 96, 70, rgba(176, 136, 70), "flowers")
    L.rect(4420, 420, 4660, 432, dark)  # 접시 선반
    for k in range(4):
        cx = 4450 + k * 58
        L.ellipse((cx - 24, 370, cx + 24, 420), rgba(236, 232, 222))
        L.ellipse((cx - 14, 382, cx + 14, 408), rgba(110, 140, 170))
    for sx in (1060, 2650, 3960):
        _sconce(L, sx, 330, dark)
    glows = [("ellipse", (sx - 70, 230, sx + 70, 380), rgba(255, 226, 160, 50)) for sx in (1060, 2650, 3960)]
    glows += [("ellipse", (lx - 120, 200, lx + 120, 360), rgba(255, 226, 160, 46)) for lx in (520.0, 2200.0, 3420.0)]
    L.haze(glows, 30)
    for x in (1000, 2700, 3900):
        L.rect(x - 16, WALL_TOP, x + 16, 792, dark)
        L.rect(x + 6, WALL_TOP, x + 16, 792, rgba(150, 104, 70))
    for (x0, y0, x1, y1), cur in zip(windows, [rgba(176, 72, 60), rgba(120, 140, 100), rgba(176, 72, 60)]):
        _window(L, x0, y0, x1, y1, frame, rgba(232, 190, 130), curtain=cur)
    # 창으로 드는 빛(바닥까지 비스듬히)
    shafts = []
    for x0, y0, x1, y1 in windows:
        shafts.append(("poly", [(x0, y0), (x1, y0), (x1 + 520, 792), (x0 + 520, 792)], rgba(255, 228, 170, 62)))
    L.haze(shafts, 26)
    # 매달린 등
    for lx in (520.0, 2200.0, 3420.0):
        L.line([(lx, 0), (lx, 230)], dark, 2)
        L.poly([(lx - 40, 270), (lx + 40, 270), (lx + 18, 228), (lx - 18, 228)], rgba(176, 116, 64))
        L.ellipse((lx - 10, 262, lx + 10, 282), rgba(255, 232, 170))
    # 1-1 방: 안락의자, 라디오 장, 책장
    _armchair(L, 260, 792, rgba(140, 70, 56), dark)
    x = mk("1-1", 570) + 220
    L.rect(x - 130, 640, x + 130, 792, wood)
    L.rect(x - 130, 640, x + 130, 652, rgba(196, 146, 96))
    L.rect(x - 90, 560, x + 90, 640, rgba(124, 76, 46))
    L.ellipse((x - 76, 574, x - 16, 630), rgba(220, 200, 160))
    L.rect(x + 6, 584, x + 74, 606, rgba(232, 214, 176))
    L.line([(x + 60, 560), (x + 100, 500)], dark, 2)  # 안테나
    _bookshelf(L, rng, 860, 980, 330, 792, wood, dark)
    # 1-2 현관 쪽: 옷걸이의 검은 외투, 검은 구두 줄, 식탁과 흰 백합(영정 자리 1170~1510 y 280~480은 비워 둔다)
    x = mk("1-2", 1340)
    L.rect(1120, 520, 1560, 532, dark)  # 영정 아래 선반
    for cx in (1190, 1490):  # 촛대
        L.rect(cx - 6, 470, cx + 6, 520, rgba(240, 232, 214))
        L.ellipse((cx - 5, 452, cx + 5, 472), rgba(255, 214, 120))
    for i in range(6):
        sx = x - 260 + i * 62
        for dx in (0, 24):
            L.ellipse((sx + dx, 780, sx + dx + 26, 796), rgba(30, 26, 28))
            L.ellipse((sx + dx + 4, 781, sx + dx + 14, 786), rgba(120, 110, 110))
    tx = x + 420
    L.rect(tx - 140, 680, tx + 140, 696, wood)
    L.rect(tx - 140, 680, tx + 140, 684, rgba(206, 156, 104))
    for lx in (tx - 120, tx + 120):
        L.rect(lx - 7, 696, lx + 7, 792, dark)
    L.poly([(tx - 120, 680), (tx + 120, 680), (tx + 100, 700), (tx - 100, 700)], rgba(244, 238, 226))  # 식탁보
    L.poly([(tx - 14, 680), (tx + 14, 680), (tx + 10, 630), (tx - 10, 630)], rgba(214, 220, 222))  # 꽃병
    L.line([(tx, 630), (tx + 4, 560)], rgba(100, 130, 70), 3)
    L.line([(tx + 2, 600), (tx + 26, 590)], rgba(100, 130, 70), 3)
    _lily(L, tx + 4, 556, 1.0)
    for cx in (tx - 100, tx + 100):  # 의자
        L.rect(cx - 30, 720, cx + 30, 732, dark)
        L.rect(cx - 30, 620, cx - 22, 792, dark)
        L.rect(cx + 22, 732, cx + 30, 792, dark)
    # 1-3 거실: 낮은 탁자와 앨범, 소파
    x = mk("1-3", 2220)
    L.poly([(x - 330, 792), (x - 320, 640), (x - 120, 630), (x - 110, 792)], rgba(96, 112, 120))  # 소파 옆모습
    L.rect(x - 340, 700, x - 100, 760, rgba(110, 128, 136))
    L.rect(x - 110, 740, x + 110, 752, wood)
    for lx in (x - 100, x + 96):
        L.rect(lx, 752, lx + 8, 792, dark)
    L.rect(x - 48, 726, x + 48, 740, rgba(140, 62, 54))  # 앨범
    L.rect(x - 44, 726, x + 44, 729, rgba(232, 222, 200))
    # 1-4·1-5 서재: 다락 계단, 책상(잠긴 서랍), 벽의 가족사진, 괘종시계
    _stairs(L, 2730, 792, wood, dark)
    x = mk("1-4", 3320)
    L.rect(x - 190, 640, x + 190, 658, wood)
    L.rect(x - 190, 640, x + 190, 644, rgba(206, 156, 104))
    L.rect(x - 180, 658, x - 20, 792, dark)
    L.rect(x - 170, 672, x - 30, 722, wood)  # 서랍
    L.ellipse((x - 106, 690, x - 94, 702), rgba(214, 180, 96))  # 열쇠 구멍 자리(1-5 서랍 3220)
    L.rect(x + 160, 658, x + 180, 792, dark)
    L.rect(x - 120, 600, x - 60, 640, rgba(180, 160, 120))  # 책 더미
    L.rect(x - 112, 584, x - 66, 600, rgba(140, 60, 48))
    L.line([(x + 110, 640), (x + 90, 560), (x + 130, 540)], dark, 4)  # 책상 등
    L.poly([(x + 110, 530), (x + 160, 530), (x + 146, 556), (x + 124, 556)], rgba(120, 140, 90))
    L.rect(x + 20, 360, x + 200, 480, dark)  # 가족사진 액자(1-4, 3430)
    L.rect(x + 32, 372, x + 188, 468, rgba(222, 210, 186))
    for hx, hy, r in ((x + 70, 420, 14), (x + 110, 410, 17), (x + 150, 424, 11)):
        L.ellipse((hx - r, hy - r, hx + r, hy + r), rgba(150, 132, 110))
    _clock(L, 3740, 792, wood, dark, rgba(240, 230, 204))
    # 현관문 옆: 우산꽂이·모자걸이, 열린 현관문
    L.rect(4440, 700, 4500, 792, rgba(110, 120, 96))
    L.line([(4450, 700), (4440, 600)], dark, 4)
    L.line([(4580, 792), (4580, 420)], dark, 6)
    for hy, c in ((440, rgba(60, 56, 54)), (470, rgba(150, 120, 80))):
        L.ellipse((4560, hy - 10, 4600, hy + 10), c)
    L.rect(YARD_X - 40, WALL_TOP, YARD_X, 792, dark)  # 문틀
    L.poly([(YARD_X - 160, 260), (YARD_X - 40, 240), (YARD_X - 40, 792), (YARD_X - 160, 780)], rgba(120, 78, 48))  # 열린 문짝
    L.poly([(YARD_X - 150, 290), (YARD_X - 52, 274), (YARD_X - 52, 420), (YARD_X - 150, 430)], rgba(150, 100, 64))
    # 바깥: 지붕 끝(슬레이트), 바깥벽, 화분, 장작더미
    L.rect(YARD_X, 120, YARD_X + 40, 792, rgba(206, 186, 150))
    L.poly([(YARD_X - 80, 110), (YARD_X + 340, 210), (YARD_X + 340, 238), (YARD_X - 80, 150)], rgba(84, 78, 88))
    for k in range(8):
        sx = YARD_X - 70 + k * 52
        sy = 120 + k * 52 * 100 / 420
        L.line([(sx, sy), (sx + 6, sy + 30)], rgba(60, 56, 66), 2)
    for px, c in ((YARD_X + 90, rgba(206, 80, 60)), (YARD_X + 150, rgba(240, 200, 90))):
        L.poly([(px - 22, 792), (px + 22, 792), (px + 28, 750), (px - 28, 750)], rgba(176, 96, 64))
        for k in range(7):
            fx, fy = px + rng.uniform(-30, 30), 740 - rng.uniform(0, 40)
            L.ellipse((fx - 9, fy - 9, fx + 9, fy + 9), c if k % 3 else rgba(96, 120, 60))
    for k in range(4):  # 장작
        for j in range(5 - k):
            cx, cy = YARD_X + 230 + j * 30 + k * 15, 780 - k * 26
            L.ellipse((cx - 14, cy - 13, cx + 14, cy + 13), rgba(140, 96, 60))
            L.ellipse((cx - 8, cy - 7, cx + 8, cy + 7), rgba(206, 164, 110))
    # 1-6 마당: 낮은 돌담, 사과나무(밑동 5070), 나무 대문
    wall_y = 600
    L.rect(YARD_X + 300, wall_y, w + 20, 792, rgba(150, 140, 126))
    for _ in range(int((w - YARD_X) / 6)):
        sx, sy = rng.uniform(YARD_X + 300, w), rng.uniform(wall_y + 6, 786)
        rw, rh = rng.uniform(14, 26), rng.uniform(9, 14)
        c = pa.lerp_color(rgba(130, 120, 108), rgba(196, 186, 170), rng.random())
        L.ellipse((sx - rw, sy - rh, sx + rw, sy + rh), c)
    L.rect(YARD_X + 290, wall_y - 14, w + 20, wall_y + 4, rgba(176, 166, 150))  # 담 머릿돌
    for _ in range(40):  # 담을 타는 담쟁이(붉게 물든)
        sx, sy = rng.uniform(YARD_X + 300, w), rng.uniform(wall_y, wall_y + 120)
        L.ellipse((sx - 8, sy - 6, sx + 8, sy + 6), rng.choice([rgba(186, 60, 44), rgba(214, 104, 50)]))
    tx = mk("1-6", 5190) - 120
    trunk = rgba(98, 70, 50)
    L.poly([(tx - 30, 792), (tx + 30, 792), (tx + 16, 420), (tx - 14, 420)], trunk)
    for ang, ln, wd in ((-60, 230, 14), (-115, 260, 14), (-30, 190, 10), (-150, 180, 10), (-85, 220, 12)):
        a = math.radians(ang)
        L.line([(tx, 440), (tx + math.cos(a) * ln, 440 + math.sin(a) * ln)], trunk, wd)
    leaves = [rgba(170, 150, 64), rgba(196, 160, 70), rgba(150, 132, 60), rgba(212, 130, 60)]
    L.ellipse((tx - 230, 220, tx + 230, 470), rgba(150, 132, 60))  # 우거진 가운데(빈틈 없이)
    for _ in range(70):
        a, r = rng.uniform(math.pi * 1.02, math.tau * 0.99), rng.uniform(40, 270)
        px, py = tx + math.cos(a) * r, 400 + math.sin(a) * r * 0.75
        rr = rng.uniform(22, 40)
        L.ellipse((px - rr, py - rr * 0.75, px + rr, py + rr * 0.75), rng.choice(leaves))
    for _ in range(26):  # 사과
        a, r = rng.uniform(math.pi * 1.05, math.tau * 0.95), rng.uniform(60, 250)
        px, py = tx + math.cos(a) * r, 410 + math.sin(a) * r * 0.75
        L.ellipse((px - 11, py - 11, px + 11, py + 11), rgba(200, 46, 38))
        L.ellipse((px - 6, py - 7, px, py - 1), rgba(250, 140, 110))
    gx = width - 330
    for px in (gx - 16, gx + 196):
        L.rect(px, 440, px + 22, 792, dark)
        L.poly([(px - 4, 440), (px + 26, 440), (px + 11, 420)], dark)
    L.rect(gx - 30, 456, gx + 236, 472, dark)
    L.poly([(gx + 6, 500), (gx + 76, 520), (gx + 76, 792), (gx + 6, 792)], rgba(150, 108, 68))  # 열린 문짝
    for k in range(3):
        L.line([(gx + 20 + k * 20, 506 + k * 6), (gx + 20 + k * 20, 792)], rgba(110, 76, 46), 3)

    # ---------------- 앞: 가는 기둥(초점 나감), 사과나무 가지
    w = pa.layer_width(width, "front")
    layers["front"] = L = Layer(w)
    L.haze([pa.soft_rect(pa.layer_x(wx, "front") - 12, -10, pa.layer_x(wx, "front") + 12, H + 10, rgba(80, 56, 40))
            for wx in (1000, 2700, 3900)], 5)
    fx = pa.layer_x(mk("1-6", 5190) + 200, "front")
    for k in range(4):
        sx, ln = fx + k * 70, rng.uniform(220, 380)
        pts = pa.sag(sx, -10, sx - 180, ln, 30, 10)
        L.line(pts, rgba(64, 46, 34), 10 - k)
        for j in range(4):
            px, py = pts[min(len(pts) - 1, 4 + j * 3)]
            L.ellipse((px - 18, py - 12, px + 18, py + 12), rgba(110, 100, 48))
        px, py = pts[-1]
        L.ellipse((px - 16, py - 16, px + 16, py + 16), rgba(190, 44, 36))
    return pa.finish(layers, "house", LIGHT, SHADE)
