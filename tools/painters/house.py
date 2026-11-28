"""1. 산 아래 할아버지 집 — 컷신 화풍으로 새로 그림 (#151).

기준 그림은 일러스트 담당의 1-5 컷신 `cut_map`(다락에서 지도를 펼치는 하윤): 따뜻한 갈색 윤곽선,
평면 색 + 그늘 한 톤, 창으로 드는 금빛 빛줄기와 바닥의 빛 웅덩이, 물건이 빽빽한 방.

집 씬은 카메라 구역 둘(`camera_rooms` [1920]):
  다락(0~1920, 한 화면, 카메라 고정) — 비스듬한 지붕, 책장, 벽시계, 할아버지 책상과 잠긴 서랍(1-5 x 700),
      가족사진 액자(1-4 x 1080), 오른쪽 창(빛줄기), 바닥 뚜껑문과 사다리(내려가기 x 1700).
  아래층(1920~7680) — 거실(깨어남 1-1, 라디오) → 영정·식탁(1-2) → 책장과 앨범(1-3) → 다락 계단(x 5240) →
      복도·현관문 → 마당(6670~, 사과나무 6990·손전등 6820·나무 대문 7220).
빛은 늦가을 오후 해: 아래층은 왼쪽 창에서, 다락은 오른쪽 창에서 비스듬히 든다.
창은 구멍(유리는 옅게 남김)이라 뒤 층(하늘·산·단풍 숲)이 시차로 비친다.
"""
from __future__ import annotations

import math
import random

from PIL import Image

import placeholder_art as pa
import ink
from ink import Ink, LightMap, alpha, dark, lite, mix

ATTIC_W = 1920.0
YARD_X = 6670.0
CEIL, WAIN, BASE, FLOOR = 118.0, 560.0, 770.0, 796.0

# 색
PLASTER = (238, 214, 172, 255)
WAINSCOT = (170, 112, 70, 255)
BEAM = (112, 70, 44, 255)
FLOORC = (182, 122, 74, 255)
ATTIC_WALL = (212, 164, 114, 255)
WOOD = (150, 96, 58, 255)
WOOD_L = (196, 140, 88, 255)
PAPER = (246, 232, 204, 255)
GLASS = (255, 244, 214)
SUN = (255, 214, 150)
SHADE = (96, 72, 112)


# ================================================================ 작은 물건


def book_row(c: Ink, rng, x0, x1, base, hmin=60, hmax=110, lean_end=True):
    """책 한 줄: 높이·색이 다른 책등, 끝은 기울어진 책."""
    cols = [(152, 62, 48), (70, 92, 120), (188, 150, 80), (96, 112, 70), (140, 96, 62), (210, 190, 150), (120, 70, 90)]
    x = x0
    while x < x1 - 20:
        w = rng.uniform(14, 30)
        h = rng.uniform(hmin, hmax)
        col = rng.choice(cols) + (255,)
        if lean_end and x1 - x < 70 and rng.random() < 0.6:
            a = math.radians(rng.uniform(12, 22))
            pts = [(x, base), (x + w * math.cos(a), base - w * math.sin(a)),
                   (x + w * math.cos(a) + h * math.sin(a), base - w * math.sin(a) - h * math.cos(a)),
                   (x + h * math.sin(a), base - h * math.cos(a))]
            c.poly(pts, col, lw=1.8)
            break
        c.rect(x, base - h, x + w, base, col, lw=1.8)
        c.rect(x + w * 0.62, base - h + 2, x + w - 1.5, base - 1, dark(col, 0.18), line=False)
        for yy in (base - h + 12, base - 14):
            c.stroke([(x + 3, yy), (x + w - 3, yy)], 1.4, lite(col, 0.45))
        x += w + rng.uniform(0, 2)


def jar(c: Ink, x, base, w, h, fill=(226, 206, 176, 255)):
    c.rrect(x, base - h, x + w, base, 8, fill, lw=2)
    c.rect(x + w * 0.1, base - h - 14, x + w * 0.9, base - h + 2, dark(fill, 0.15), lw=2)
    c.rect(x + w * 0.62, base - h + 6, x + w - 5, base - 6, dark(fill, 0.12), line=False)
    c.stroke([(x + w * 0.2, base - h + 14), (x + w * 0.2, base - 16)], 3, lite(fill, 0.7))


def box(c: Ink, x0, y0, x1, y1, fill, top=26, side=0.0, lid=True):
    """상자: 앞면 + 위 뚜껑면(조금 내려다봄). side > 0이면 오른쪽 옆면."""
    c.rect(x0, y0, x1, y1, fill)
    if top:
        c.poly([(x0, y0), (x0 + top * 0.6, y0 - top), (x1 + top * 0.6, y0 - top), (x1, y0)], lite(fill, 0.22))
    if side:
        c.poly([(x1, y0), (x1 + top * 0.6, y0 - top), (x1 + top * 0.6, y1 - top), (x1, y1)], dark(fill, 0.25))
    if lid:
        c.stroke([(x0, y0 + 18), (x1, y0 + 18)], 2)


def scroll_roll(c: Ink, x, y, length, r, angle, fill=PAPER):
    """말린 종이(지도) 한 통."""
    a = math.radians(angle)
    dx, dy = math.cos(a) * length, math.sin(a) * length
    nx, ny = -math.sin(a) * r, math.cos(a) * r
    c.poly([(x + nx, y + ny), (x + dx + nx, y + dy + ny), (x + dx - nx, y + dy - ny), (x - nx, y - ny)], fill)
    c.poly([(x + dx * 0.0 + nx * 0.5, y + ny * 0.5), (x + dx + nx * 0.5, y + dy + ny * 0.5),
            (x + dx + nx, y + dy + ny), (x + nx, y + ny)], dark(fill, 0.12), line=False)
    c.ellipse(x + dx - r * 0.7, y + dy - r, x + dx + r * 0.7, y + dy + r, lite(fill, 0.2), lw=1.8)
    c.ellipse(x + dx - r * 0.3, y + dy - r * 0.45, x + dx + r * 0.3, y + dy + r * 0.45, dark(fill, 0.3), lw=1.2)


def lily(c: Ink, x, y, s=1.0):
    """흰 백합 한 송이(장례 꽃): 꽃잎 여섯, 노란 꽃밥."""
    petal = (252, 250, 242, 255)
    for k in range(6):
        a = -math.pi / 2 + (k - 2.5) * 0.46
        ex, ey = x + math.cos(a) * 30 * s, y + math.sin(a) * 26 * s
        mx, my = x + math.cos(a) * 15 * s, y + math.sin(a) * 13 * s
        nx, ny = -math.sin(a) * 7 * s, math.cos(a) * 7 * s
        c.poly([(x, y), (mx + nx, my + ny), (ex, ey), (mx - nx, my - ny)], petal if k % 2 else mix(petal, (220, 218, 210), 0.5), lw=1.4)
    for k in range(3):
        c.stroke([(x, y), (x + (k - 1) * 8 * s, y - 20 * s)], 1.2, (190, 150, 60, 255))
        c.ellipse(x + (k - 1) * 8 * s - 3, y - 20 * s - 3, x + (k - 1) * 8 * s + 3, y - 20 * s + 3, (226, 160, 60, 255), line=False)


def vase(c: Ink, x, base, h=70, fill=(214, 226, 226, 255)):
    c.poly([(x - 14, base), (x + 14, base), (x + 20, base - h * 0.55), (x + 8, base - h), (x - 8, base - h), (x - 20, base - h * 0.55)], alpha(fill, 255), lw=1.8)
    c.stroke([(x - 8, base - h * 0.85), (x - 12, base - h * 0.2)], 3, (255, 255, 255, 150))


def frame(c: Ink, x0, y0, x1, y1, inner, wood=(140, 94, 56, 255), mat=True):
    """액자: 나무 테 + 흰 깔개 + 그림(inner(c, 안쪽 사각형))."""
    c.rect(x0, y0, x1, y1, wood)
    t = max(8, (x1 - x0) * 0.08)
    c.rect(x0 + t * 0.35, y0 + t * 0.35, x1 - t * 0.35, y1 - t * 0.35, lite(wood, 0.25), line=False)
    if mat:
        c.rect(x0 + t, y0 + t, x1 - t, y1 - t, (240, 230, 210, 255), lw=1.5)
        t2 = t * 1.8
    else:
        t2 = t
    inner(c, (x0 + t2, y0 + t2, x1 - t2, y1 - t2))


def landscape(c: Ink, r):
    x0, y0, x1, y1 = r
    c.rect(x0, y0, x1, y1, (176, 204, 214, 255), line=False)
    c.poly([(x0, y1 - (y1 - y0) * 0.35), (x0 + (x1 - x0) * 0.4, y0 + (y1 - y0) * 0.3), (x1, y1 - (y1 - y0) * 0.45), (x1, y1), (x0, y1)], (124, 150, 112, 255), lw=1.2)
    c.poly([(x0, y1 - (y1 - y0) * 0.15), (x1, y1 - (y1 - y0) * 0.25), (x1, y1), (x0, y1)], (210, 176, 96, 255), lw=1.2)


def family_photo(c: Ink, r):
    """가족사진(세피아): 할아버지와 아기 하윤, 흰 개 — 실루엣만."""
    x0, y0, x1, y1 = r
    c.rect(x0, y0, x1, y1, (222, 198, 158, 255), line=False)
    w, h = x1 - x0, y1 - y0
    sep = (132, 100, 72, 255)
    gx = x0 + w * 0.42
    c.ellipse(gx - w * 0.09, y0 + h * 0.18, gx + w * 0.09, y0 + h * 0.4, sep, line=False)   # 할아버지 머리
    c.poly([(gx - w * 0.2, y1), (gx - w * 0.15, y0 + h * 0.46), (gx + w * 0.15, y0 + h * 0.46), (gx + w * 0.2, y1)], sep, line=False)
    c.ellipse(gx + w * 0.02, y0 + h * 0.5, gx + w * 0.16, y0 + h * 0.66, (236, 220, 196, 255), line=False)  # 안긴 아기
    dx = x0 + w * 0.76
    c.ellipse(dx - w * 0.1, y1 - h * 0.28, dx + w * 0.12, y1 - h * 0.05, (246, 238, 222, 255), line=False)  # 흰 개
    c.ellipse(dx + w * 0.04, y1 - h * 0.4, dx + w * 0.16, y1 - h * 0.22, (246, 238, 222, 255), line=False)


def clock_face(c: Ink, cx, cy, r, case=(150, 98, 60, 255)):
    c.ellipse(cx - r - 10, cy - r - 10, cx + r + 10, cy + r + 10, case)
    c.ellipse(cx - r, cy - r, cx + r, cy + r, (246, 236, 214, 255), lw=1.8)
    for k in range(12):
        a = k / 12 * math.tau
        c.stroke([(cx + math.cos(a) * r * 0.78, cy + math.sin(a) * r * 0.78), (cx + math.cos(a) * r * 0.9, cy + math.sin(a) * r * 0.9)], 1.6)
    c.stroke([(cx, cy), (cx + r * 0.45, cy - r * 0.3)], 2.4)
    c.stroke([(cx, cy), (cx - r * 0.1, cy - r * 0.72)], 1.8)


def chair_ladder(c: Ink, x, base, s=1.0, wood=WOOD_L):
    """등받이 사다리 의자(옆에서 조금 비스듬히)."""
    h = 300 * s
    c.rect(x, base - h, x + 14 * s, base, wood)                # 뒷다리·등받이
    c.rect(x + 110 * s, base - h * 0.5, x + 124 * s, base, wood)  # 앞다리
    for k in range(3):
        y = base - h + 40 * s + k * 40 * s
        c.rrect(x - 4 * s, y, x + 70 * s, y + 16 * s, 6, wood)
    c.poly([(x - 6 * s, base - h * 0.5), (x + 130 * s, base - h * 0.5), (x + 136 * s, base - h * 0.5 + 18 * s), (x - 6 * s, base - h * 0.5 + 18 * s)], lite(wood, 0.2))
    c.ellipse(x - 6 * s, base - h - 14 * s, x + 20 * s, base - h + 4 * s, wood)


def leaf_shadow(lm: LightMap, rng, x0, y0, x1, y1, n, amount=-0.35):
    """창에 비친 나뭇잎 그림자(빛 지도에서 뺀다)."""
    for _ in range(n):
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        r = rng.uniform(10, 26)
        lm.glow(x, y, r, r * 0.7, amount, blur=6)


# ================================================================ 창


def window(c: Ink, x0, y0, x1, y1, cols, rows, frame_c=(150, 98, 60, 255), sill=True, curtain=None):
    """창: 유리는 구멍(뒤 층이 비친다, 옅게 남김) + 창살 + 테 + 창턱 + 커튼."""
    t = 14
    c.erase([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], keep=0)
    # 유리 위에 아주 옅은 빛(바깥이 환하게 날아간 느낌)
    c.rect(x0, y0, x1, y1, alpha(GLASS, 70), line=False)
    for k in range(1, cols):
        x = x0 + (x1 - x0) * k / cols
        c.rect(x - 5, y0, x + 5, y1, frame_c, lw=1.6)
    for k in range(1, rows):
        y = y0 + (y1 - y0) * k / rows
        c.rect(x0, y - 5, x1, y + 5, frame_c, lw=1.6)
    c.rect(x0 - t, y0 - t, x1 + t, y0, frame_c)
    c.rect(x0 - t, y1, x1 + t, y1 + t, frame_c)
    c.rect(x0 - t, y0, x0, y1, frame_c)
    c.rect(x1, y0, x1 + t, y1, frame_c)
    # 유리 반사(비스듬한 띠)
    c.poly([(x0 + (x1 - x0) * 0.55, y0), (x0 + (x1 - x0) * 0.68, y0), (x0 + (x1 - x0) * 0.3, y1), (x0 + (x1 - x0) * 0.17, y1)],
           (255, 255, 250, 40), line=False)
    if sill:
        c.rect(x0 - t - 18, y1 + t, x1 + t + 18, y1 + t + 16, lite(frame_c, 0.15))
        c.rect(x0 - t - 10, y1 + t + 16, x1 + t + 10, y1 + t + 24, dark(frame_c, 0.2))
    if curtain:
        for side in (-1, 1):
            cx = x0 - t if side < 0 else x1 + t
            pts = [(cx + side * 4, y0 - 44), (cx - side * 54, y0 - 44), (cx - side * 30, (y0 + y1) / 2 - 20),
                   (cx - side * 52, y1 + 24), (cx - side * 20, y1 + 60), (cx + side * 10, y1 + 60)]
            c.poly(pts, curtain)
            for k in (0.35, 0.7):
                c.stroke([(cx - side * 54 * k, y0 - 36), (cx - side * 40 * k, y1 + 50)], 1.6, dark(curtain, 0.3))
            c.rrect(cx - side * 44 - 12, (y0 + y1) / 2 - 8, cx - side * 44 + 12, (y0 + y1) / 2 + 8, 6, dark(curtain, 0.2), lw=1.4)
        c.rect(x0 - 90, y0 - 54, x1 + 90, y0 - 44, (110, 74, 48, 255), lw=1.6)
        for xe in (x0 - 96, x1 + 86):
            c.ellipse(xe, y0 - 58, xe + 10, y0 - 40, (110, 74, 48, 255), lw=1.4)


# ================================================================ 다락 (0~1920)


def attic_ground(c: Ink, rng, lm: LightMap, mk):
    W = ATTIC_W
    # 뒷벽: 세로 판자
    c.planks_v(rng, 0, 0, W, FLOOR, ATTIC_WALL, step=72, jitter=12)
    # 바닥
    _attic_floor(c, rng)
    c.rect(0, FLOOR - 16, W, FLOOR, (150, 100, 62, 255))  # 걸레받이
    # 비스듬한 지붕 밑면(왼쪽·오른쪽), 판자를 비스듬히
    roof = (150, 100, 66, 255)
    left = [(-10, -10), (760, -10), (-10, 600)]
    right = [(1320, -10), (W + 10, -10), (W + 10, 520)]
    for tri, slope in ((left, (-10, 600, 760, -10)), (right, (1320, -10, W + 10, 520))):
        c.poly(tri, roof, line=False)
        xa, ya, xb, yb = slope
        ln = math.hypot(xb - xa, yb - ya)
        ux, uy = (xb - xa) / ln, (yb - ya) / ln
        nx, ny = uy, -ux
        for k in range(1, 12):  # 지붕 판자 이음: 서까래와 나란히
            off = k * 62
            c.stroke([(xa + nx * off - ux * 400, ya + ny * off - uy * 400), (xb + nx * off + ux * 400, yb + ny * off + uy * 400)], 1.4, dark(roof, 0.3))
    # 서까래(굵은 비스듬한 보)
    rafter = (126, 80, 50, 255)
    c.poly([(-10, 600), (760, -10), (812, -10), (-10, 660)], rafter)
    c.poly([(1268, -10), (1320, -10), (W + 10, 520), (W + 10, 580)], rafter)
    c.poly([(-10, 640), (790, -10), (812, -10), (-10, 660)], dark(rafter, 0.2), line=False)
    # 가로 보(위)와 기둥
    c.rect(520, 70, 1560, 104, rafter)
    c.rect(520, 96, 1560, 104, dark(rafter, 0.25), line=False)
    for x in (900, 1290):
        c.rect(x, 104, x + 26, FLOOR - 16, (140, 92, 58, 255))
        c.rect(x + 18, 104, x + 26, FLOOR - 16, dark((140, 92, 58, 255), 0.25), line=False)
    # 오른쪽 창(박공 창): 여섯 칸
    wx0, wy0, wx1, wy1 = 1440, 200, 1700, 560
    window(c, wx0, wy0, wx1, wy1, 2, 3, frame_c=(156, 104, 64, 255))
    vase(c, 1600, wy1 + 14, 64, (214, 230, 232, 255))
    c.stroke([(1600, wy1 - 50), (1606, wy1 - 100)], 2, (110, 140, 70, 255))
    for k in range(5):
        a = k / 5 * math.tau
        c.ellipse(1606 + math.cos(a) * 9 - 7, wy1 - 112 + math.sin(a) * 9 - 7, 1606 + math.cos(a) * 9 + 7, wy1 - 112 + math.sin(a) * 9 + 7, (248, 238, 200, 255), lw=1.2)
    c.ellipse(1600, wy1 - 118, 1612, wy1 - 106, (230, 170, 60, 255), lw=1.2)
    # 빛: 다락은 대체로 어둑하고 창 둘레와 빛 웅덩이만 환하다
    lm.add([(-40, -40), (1960, -40), (1960, 160), (-40, 160)], -0.3, 80)
    lm.add([(-40, 0), (300, 0), (300, 1080), (-40, 1080)], -0.2, 120)
    lm.glow(1570, 380, 420, 380, 0.55)
    lm.add([(wx0, wy0), (wx1, wy0), (wx1, wy1), (wx0, wy1)], 0.5, 20)
    leaf_shadow(lm, rng, wx0, wy0, wx1, wy1, 16)
    # 바닥 빛 웅덩이(창 모양이 기울어 늘어진다)
    for col in range(2):
        for row in range(3):
            px0 = 820 + col * 150 + row * 70
            py0 = 860 + row * 48
            lm.add([(px0, py0), (px0 + 130, py0), (px0 + 168, py0 + 40), (px0 + 38, py0 + 40)], 0.85, 6)
    lm.add([(1440, 560), (1700, 560), (1300, 1080), (700, 1080)], 0.25, 60)  # 빛줄기가 닿는 쪽 전체


def _attic_floor(c: Ink, rng):
    """다락 바닥: 판자가 화면 안쪽으로 뻗어 소실점(960, 210)으로 모인다(아래층 바닥과 같은 원근, 카메라가 서 있어 그림으로)."""
    base = (176, 120, 76, 255)
    s0, s1 = (FLOOR - 210) / 600, (1080 - 210) / 600
    X = lambda p, s: (p - 960) * s + 960  # noqa: E731
    Y = lambda s: 210 + 600 * s  # noqa: E731
    p = -1200.0
    while p < 3200:
        w = 96
        col = mix(base, dark(base, 0.14) if rng.random() < 0.5 else lite(base, 0.1), rng.uniform(0.15, 0.85))
        c.poly([(X(p, s0), FLOOR), (X(p + w, s0), FLOOR), (X(p + w, s1), 1080), (X(p, s1), 1080)], col, lw=1.4, lc=dark(base, 0.45))
        inv = rng.uniform(1.0 / s1, 1.0 / s0)
        while inv < 1.0 / s0:
            s = 1.0 / inv
            c.stroke([(X(p, s), Y(s)), (X(p + w, s), Y(s))], 1.2, dark(base, 0.4))
            inv += rng.uniform(0.15, 0.3)
        p += w


def attic_props(c: Ink, rng, lm: LightMap, mk):
    W = ATTIC_W
    # ---- 왼쪽 큰 책장(지붕 밑까지)
    sx0, sx1 = 0, 470
    shelf = (150, 98, 60, 255)
    c.rect(sx0 - 10, 40, sx1, FLOOR + 6, shelf, cast=True)
    c.rect(sx0, 60, sx1 - 24, FLOOR - 10, dark(shelf, 0.45), line=False)  # 책장 안쪽 그늘
    ys = [60, 230, 400, 570, FLOOR - 10]
    for y in ys[1:-1]:
        c.rect(sx0 - 10, y - 14, sx1, y + 4, lite(shelf, 0.15))
    c.rect(sx1 - 26, 40, sx1, FLOOR + 6, shelf)
    # 윗칸: 단지들
    for k, x in enumerate((14, 104, 194, 284)):
        jar(c, x, ys[1] - 14, 78, 120 if k % 2 == 0 else 104)
    # 둘째 칸: 책 + 상자
    book_row(c, rng, 210, sx1 - 30, ys[2] - 14)
    box(c, 10, ys[2] - 130, 200, ys[2] - 14, (204, 168, 112, 255), top=0)
    c.rrect(70, ys[2] - 80, 140, ys[2] - 66, 6, dark((204, 168, 112, 255), 0.2), lw=1.4)
    # 셋째 칸: 책
    book_row(c, rng, 10, 250, ys[3] - 14)
    c.rect(270, ys[3] - 60, 440, ys[3] - 14, (226, 210, 180, 255))  # 눕힌 책 더미
    c.rect(280, ys[3] - 94, 430, ys[3] - 60, (120, 86, 62, 255))
    # 아랫칸: 책 + 상자
    book_row(c, rng, 10, 180, ys[4])
    box(c, 200, ys[4] - 120, 440, ys[4], (196, 158, 104, 255), top=0)

    # ---- 벽시계(추가 달린)
    clock_face(c, 760, 210, 48)
    c.rect(726, 262, 794, 520, (150, 98, 60, 255))
    c.rect(738, 276, 782, 500, (212, 188, 150, 255), lw=1.6)
    c.rect(738, 276, 782, 500, (60, 44, 34, 90), line=False)  # 추는 따로 흔들린다(room_house_pendulum_attic)

    # ---- 빨랫줄에 매단 종이(그림·쪽지)
    rope = [(940, 128), (1160, 152), (1420, 132)]
    c.stroke(rope, 1.8, (110, 80, 56, 255))
    for x0, w, h, ang in ((990, 90, 120, -4), (1110, 70, 90, 3), (1230, 110, 150, -2)):
        y = 146 if x0 < 1160 else 150
        a = math.radians(ang)
        pts = [(x0, y), (x0 + w, y + w * math.sin(a)), (x0 + w - h * math.sin(a), y + h), (x0 - h * math.sin(a), y + h)]
        c.poly(pts, PAPER, lw=1.6)
        c.rect(x0 + w * 0.4, y - 10, x0 + w * 0.4 + 10, y + 10, (190, 150, 100, 255), lw=1.2)  # 집게
    # 리본(천장에서 늘어진 끈)
    c.stroke([(1180, 104), (1170, 190), (1186, 240)], 3, (220, 196, 150, 255))

    # ---- 가족사진 액자(1-4): 서랍장 위 벽에 비스듬히
    fx = mk("1-4", 1080.0)
    c.casters.append([(fx - 70, 250), (fx + 70, 250), (fx + 70, 420), (fx - 70, 420)])
    frame(c, fx - 70, 250, fx + 70, 420, family_photo, wood=(120, 80, 50, 255))
    c.stroke([(fx - 40, 252), (fx, 214), (fx + 40, 252)], 1.6, (90, 64, 44, 255))  # 거는 줄
    c.ellipse(fx - 5, 208, fx + 5, 218, (180, 150, 90, 255), lw=1.2)

    # ---- 서랍장 + 위에 둘둘 만 침낭(가죽 띠)
    dx0, dx1 = 960, 1220
    chest = (196, 150, 98, 255)
    c.rect(dx0, 520, dx1, FLOOR + 4, chest, cast=True)
    for k in range(3):
        y = 540 + k * 82
        c.rect(dx0 + 16, y, dx1 - 16, y + 70, lite(chest, 0.12), lw=1.8)
        c.ellipse((dx0 + dx1) / 2 - 7, y + 28, (dx0 + dx1) / 2 + 7, y + 42, (120, 80, 50, 255), lw=1.2)
    c.rect(dx1 - 30, 520, dx1, FLOOR + 4, dark(chest, 0.2), line=False)
    c.rect(dx0 - 8, 506, dx1 + 8, 522, lite(chest, 0.2))
    roll = (236, 222, 196, 255)
    c.rrect(dx0 + 10, 440, dx1 - 10, 506, 32, roll, lw=2.2)
    c.ellipse(dx1 - 46, 440, dx1 - 6, 506, lite(roll, 0.2), lw=2)
    c.stroke([(dx1 - 34, 452), (dx1 - 22, 474), (dx1 - 30, 492)], 1.4, dark(roll, 0.3))
    for bx in (dx0 + 60, dx1 - 90):
        c.rect(bx, 436, bx + 26, 510, (120, 78, 48, 255), lw=1.6)
        c.rect(bx + 4, 462, bx + 22, 480, (200, 170, 110, 255), lw=1.2)

    # ---- 할아버지 책상(1-5): 잠긴 서랍, 위에 말린 지도들·잉크병·스탠드
    tx = mk("1-5", 700.0)
    desk = (132, 84, 52, 255)
    top_y = 600
    c.rect(tx - 190, top_y + 22, tx - 168, FLOOR + 6, desk)
    c.rect(tx + 168, top_y + 22, tx + 190, FLOOR + 6, desk)
    c.rect(tx - 176, top_y + 22, tx + 176, top_y + 108, lite(desk, 0.08), cast=True)
    c.rect(tx - 90, top_y + 34, tx + 90, top_y + 96, lite(desk, 0.2), lw=2)  # 서랍
    c.rect(tx - 22, top_y + 58, tx + 22, top_y + 70, (200, 160, 80, 255), lw=1.4)  # 손잡이
    c.ellipse(tx - 5, top_y + 74, tx + 5, top_y + 86, (60, 40, 30, 255), line=False)  # 열쇠 구멍
    c.poly([(tx - 206, top_y), (tx + 206, top_y), (tx + 196, top_y + 22), (tx - 196, top_y + 22)], lite(desk, 0.18))
    c.stroke([(tx - 168, FLOOR - 40), (tx + 168, FLOOR - 40)], 6, desk)  # 다리 사이 가로대
    # 책상 위
    scroll_roll(c, tx - 170, top_y - 18, 150, 14, -8)
    scroll_roll(c, tx - 120, top_y - 6, 120, 12, 4, (238, 220, 186, 255))
    c.rect(tx + 20, top_y - 30, tx + 120, top_y, (226, 214, 190, 255), lw=1.6)  # 공책 더미
    c.rect(tx + 26, top_y - 44, tx + 112, top_y - 30, (150, 80, 60, 255), lw=1.6)
    c.ellipse(tx + 140, top_y - 36, tx + 176, top_y - 2, (40, 50, 70, 255), lw=1.6)  # 잉크병
    c.stroke([(tx + 160, top_y - 30), (tx + 186, top_y - 96)], 2, (230, 220, 200, 255))  # 깃펜
    # 스탠드(꺼진 등)
    c.stroke([(tx + 70, top_y - 44), (tx + 54, top_y - 150), (tx + 96, top_y - 200)], 5, (90, 80, 70, 255))
    c.poly([(tx + 80, top_y - 222), (tx + 130, top_y - 206), (tx + 118, top_y - 172), (tx + 70, top_y - 190)], (88, 110, 90, 255), lw=2)

    # ---- 오른쪽: 등받이 의자, 기대 세운 액자 뒷면, 큰 상자들
    chair_ladder(c, 1330, FLOOR + 6, 0.9)
    c.poly([(1760, 560), (1900, 560), (1920, 520), (1920, FLOOR + 6), (1740, FLOOR + 6)], (176, 128, 84, 255))  # 큰 상자 앞면
    box(c, 1750, 560, 1930, FLOOR + 6, (186, 138, 90, 255), top=40)
    box(c, 1780, 420, 1930, 560, (204, 160, 108, 255), top=30)
    c.poly([(1530, FLOOR + 4), (1590, 640), (1610, 646), (1556, FLOOR + 4)], (96, 66, 46, 255))  # 세운 액자 다리
    # ---- 바닥 뚜껑문(열려 있음)과 사다리 끝
    hx0, hx1 = 1600, 1820
    c.poly([(hx0, 830), (hx1, 830), (hx1 + 26, 874), (hx0 - 26, 874)], (40, 28, 24, 255))
    c.poly([(hx0 - 26, 874), (hx1 + 26, 874), (hx1 + 26, 884), (hx0 - 26, 884)], (110, 72, 46, 255))
    c.poly([(hx1 + 8, 828), (hx1 + 8, 690), (hx1 + 40, 676), (hx1 + 40, 820)], (160, 108, 66, 255))  # 열린 뚜껑
    rail = (176, 122, 76, 255)
    for x in (hx0 + 40, hx1 - 56):  # 사다리 기둥: 구멍에서 올라와 위가 둥글게 꺾인다
        c.poly([(x, 870), (x, 650), (x + 8, 628), (x + 26, 622), (x + 26, 642), (x + 18, 650), (x + 18, 870)], rail)
    for y in (680, 740, 800, 852):
        c.rect(hx0 + 58, y, hx1 - 56, y + 12, lite(rail, 0.12) if y < 830 else dark(rail, 0.4), lw=1.6)
    lm.glow(1710, 850, 160, 40, -0.5, blur=20)  # 구멍 속은 어둡게


def attic_front(c: Ink, rng):
    """다락 맨 앞(초점이 나간 것): 왼쪽 아래 말린 종이 다발과 리본 상자, 오른쪽 아래 상자 모서리."""
    box(c, -20, 900, 300, 1100, (170, 124, 82, 255), top=0)
    for k, (x, ang, ln) in enumerate(((40, -78, 260), (110, -64, 220), (190, -84, 290), (250, -58, 200), (0, -70, 240))):
        scroll_roll(c, x, 1000, ln, 24, ang, mix((228, 206, 168, 255), (196, 160, 120, 255), (k % 3) / 3))
    c.stroke([(-20, 960), (300, 940)], 6, (200, 80, 90, 255))
    c.stroke([(140, 950), (118, 910), (150, 920), (140, 950), (170, 912), (176, 940)], 4, (200, 80, 90, 255))
    box(c, 1720, 930, 1960, 1100, (160, 116, 76, 255), top=36)


# ================================================================ 바깥(창으로·마당에서 보이는 것)


def sky_layer(width, rng) -> Image.Image:
    w = pa.layer_width(width, "sky")
    sky = pa.vertical_gradient(w, [
        (0.0, (122, 160, 206)), (0.35, (176, 200, 220)), (0.6, (240, 222, 190)), (0.78, (250, 210, 156)), (1.0, (240, 196, 146)),
    ])
    pa.add_glow(sky, w * 0.12, 560, 1100, (255, 222, 164), 0.5)
    pa.paint_clouds(sky, rng, 6, w, 140, 400, (w * 0.12, 560), lit=(255, 246, 232), shade=(196, 180, 204), glow=(255, 206, 160))
    return sky


def back_layer(name, width, rng, build) -> Image.Image:
    w = pa.layer_width(width, name)
    c = Ink(w)
    c.lc = alpha(mix((128, 86, 58, 255), (240, 210, 170, 255), {"far": 0.55, "hills": 0.35, "mid": 0.15}[name]), 255)
    c.lw = {"far": 1.4, "hills": 1.8, "mid": 2.2}[name]
    build(c, w, rng)
    img = c.finish()
    return ink.soften(img, {"far": 1.6, "hills": 1.0, "mid": 0.6}[name])


def far_build(c: Ink, w, rng):
    """먼 산(산 아래 할아버지 집): 푸르스름한 큰 산과 산허리 단풍."""
    pts = pa.ridge(rng, w, 360, 220, waves=3)
    body = (164, 156, 186, 255)
    c.poly(pts, body)
    for _ in range(int(w / 10)):
        x = rng.uniform(0, w)
        y = pa._ridge_y(pts, x) + rng.uniform(40, 360)
        r = rng.uniform(8, 16)
        c.ellipse(x - r, y - r * 0.7, x + r, y + r * 0.7, rng.choice([(200, 160, 150, 255), (210, 178, 150, 255), (180, 150, 160, 255)]), line=False)
    c.glaze(lambda d, s: d.rectangle([*s([(-10, 580)])[0], *s([(w + 10, 700)])[0]], fill=(250, 226, 190, 150)), (-10, 580, w + 10, 700), blur=30)


def hills_build(c: Ink, w, rng):
    """단풍 든 언덕 숲."""
    pts = pa.ridge(rng, w, 560, 60, waves=3)
    c.poly(pts, (176, 130, 84, 255))
    x = 20.0
    while x < w:
        r = rng.uniform(44, 86)
        y = pa._ridge_y(pts, x) + 20
        col = rng.choice([(226, 140, 70), (210, 100, 60), (236, 190, 96), (180, 128, 70), (200, 160, 80)]) + (255,)
        c.rect(x - 5, y - 10, x + 5, y + 50, (110, 80, 60, 255), line=False)
        c.ellipse(x - r, y - r * 1.5, x + r, y + r * 0.2, col)
        c.ellipse(x - r * 0.6, y - r * 1.4, x + r * 0.5, y - r * 0.7, lite(col, 0.3), line=False)
        x += rng.uniform(50, 130)


def mid_build(c: Ink, w, rng):
    """가까운 과수원과 이웃집 지붕(마당 돌담 너머)."""
    hill = pa.ridge(rng, w, 640, 18, waves=2)
    c.poly(hill, (160, 132, 80, 255))
    for k in range(int(w / 1100)):
        fx = rng.uniform(300, w - 300)
        gy = pa._ridge_y(hill, fx) + 10
        c.rect(fx - 90, gy - 120, fx + 90, gy, (236, 220, 192, 255))
        c.poly([(fx - 110, gy - 116), (fx, gy - 200), (fx + 110, gy - 116)], (176, 80, 58, 255))
        c.rect(fx - 20, gy - 70, fx + 10, gy - 30, (120, 150, 170, 255), lw=1.4)
        c.rect(fx + 40, gy - 170, fx + 60, gy - 130, (150, 110, 90, 255), lw=1.4)
    x = 60.0
    while x < w:
        gy = pa._ridge_y(hill, x) + 10
        r = rng.uniform(46, 70)
        col = rng.choice([(206, 104, 54), (228, 164, 70), (160, 110, 56), (190, 76, 50)]) + (255,)
        c.rect(x - 7, gy - r, x + 7, gy, (100, 70, 50, 255))
        c.ellipse(x - r, gy - r * 2.4, x + r, gy - r * 0.6, col)
        c.ellipse(x - r * 0.6, gy - r * 2.3, x + r * 0.4, gy - r * 1.5, lite(col, 0.3), line=False)
        x += rng.uniform(220, 480)


# ================================================================ 그리기


def _attic_only(img: Image.Image) -> Image.Image:
    """다락 그림이 아래층(x 1920~)으로 삐져나간 선(지붕 판자 이음 등)을 지운다."""
    img.paste((0, 0, 0, 0), (int(ATTIC_W), 0, img.width, img.height))
    return img


def _save(img: Image.Image, name: str) -> None:
    out = pa.OUT_DIR / "house" / f"{name}.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    img.save(out, optimize=True)
    print(f"{out.relative_to(pa.ROOT)}  {img.width}x{img.height}  {out.stat().st_size // 1024} KB")


def paint(width: float, markers: dict[str, float]) -> dict:
    import house_down as D
    rng = random.Random("house-ink")
    mk = markers.get
    layers = {}

    layers["sky"] = ink.as_layer(sky_layer(width, rng), pa.layer_width(width, "sky"))
    w = pa.layer_width(width, "horizon")  # 이 집에서는 쓰지 않는 층(투명)
    layers["horizon"] = ink.as_layer(Image.new("RGBA", (w, 1080), (0, 0, 0, 0)), w)
    layers["far"] = ink.as_layer(back_layer("far", width, rng, far_build), pa.layer_width(width, "far"))
    layers["hills"] = ink.as_layer(back_layer("hills", width, rng, hills_build), pa.layer_width(width, "hills"))
    layers["mid"] = ink.as_layer(back_layer("mid", width, rng, mid_build), pa.layer_width(width, "mid"))

    # ---- 다락(카메라가 움직이지 않는 한 화면): 땅·물건 층에 정면 그림으로
    gw = pa.layer_width(width, "ground")
    lm = LightMap(gw, 0.62)
    g = Ink(gw)
    attic_ground(g, rng, lm, mk)
    p = Ink(pa.layer_width(width, "props"))
    attic_props(p, rng, lm, mk)
    ink.drop_shadow(lm, p.casters, -30, 14, 14, 0.3)  # 다락 빛은 오른쪽 창: 그림자는 왼쪽으로
    for x0_, x1_ in ((-10, 470), (520, 900), (960, 1220), (1330, 1460), (1740, 1920)):
        lm.add([(x0_ - 40, FLOOR), (x1_ - 40, FLOOR), (x1_ - 140, FLOOR + 60), (x0_ - 140, FLOOR + 60)], -0.35, 16)  # 바닥에 닿는 그림자
    L = lm.array()
    ground = ink.light(_attic_only(g.finish()), L, SUN, SHADE)
    props = ink.light(_attic_only(p.finish()), L, SUN, SHADE)
    props = ink.rim_light(props, p.casters, 4, -4, (255, 226, 170), 0.45)  # 다락 빛은 오른쪽 창에서
    beams = [
        ([(1440, 200), (1700, 200), (1130, 1080), (700, 1080)], 0.9),
        ([(1500, 230), (1580, 230), (1000, 1080), (880, 1080)], 0.6),
    ]
    props.alpha_composite(ink.rays(props.width, beams))
    ink.motes(props, rng, 900, [(1440, 200), (1700, 200), (1130, 1080), (700, 1080)])
    ink.bokeh(props, rng, 14, 1100, 1750, 150, 700)
    layers["ground"] = ink.as_layer(ground, gw)
    layers["props"] = ink.as_layer(props, pa.layer_width(width, "props"))

    # ---- 아래층·마당: 깊이 판들
    near, wall_glow = D.wall_layer(width, mk, rng)
    layers["near"] = ink.as_layer(near, pa.layer_width(width, "near"))
    _save(wall_glow.resize((wall_glow.width // 4, wall_glow.height // 4), Image.LANCZOS), "room_house_wallglow")
    furn, canopy, fw = D.furniture_layer(width, mk, rng)
    _save(furn, "room_house_furniture")
    _save(canopy, "room_house_canopy")
    floor, floor_glow = D.floor_texture(mk, rng)
    _save(floor, "room_house_floor")
    _save(floor_glow, "room_house_floor_glow")
    _save(D.ceiling_texture(rng), "room_house_ceiling")
    _save(D.endwall_texture(True, rng), "room_house_endwall_door")
    _save(D.endwall_texture(False, rng), "room_house_endwall")
    for name, (_wx0, wy0, _wx1, wy1, col) in zip(("living", "study"), D.WINDOWS[:2]):
        h = wy1 - wy0 + 120
        _save(D.curtain(col, h, False), f"room_house_curtain_{name}_l")
        _save(D.curtain(col, h, True), f"room_house_curtain_{name}_r")
    _save(D.pendulum(230, 16), "room_house_pendulum")
    _save(D.pendulum(170, 18), "room_house_pendulum_attic")
    fl, fl_glow = D.flame()
    _save(fl, "room_house_flame")
    _save(fl_glow, "room_house_flame_glow")

    # ---- 맨 앞: 다락 앞 물건(정면) + 아래층(깊이 1.25)
    fw_ = pa.layer_width(width, "front")
    fc = Ink(fw_)
    attic_front(fc, rng)
    front = ink.soften(fc.finish(), 7.0)
    down = ink.to_plane(D.front_world(width, mk, rng), D.FRONT_S, fw_)
    front.alpha_composite(ink.soften(down, 5.0))
    layers["front"] = ink.as_layer(front, fw_)
    return layers
