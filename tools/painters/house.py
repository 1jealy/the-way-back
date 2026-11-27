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
    c.planks_h(rng, 0, FLOOR, W, 1080, (176, 120, 76, 255), rows=6)
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


def attic_props(c: Ink, rng, lm: LightMap, mk):
    W = ATTIC_W
    # ---- 왼쪽 큰 책장(지붕 밑까지)
    sx0, sx1 = 0, 470
    shelf = (150, 98, 60, 255)
    c.rect(sx0 - 10, 40, sx1, FLOOR + 6, shelf)
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
    c.stroke([(760, 276), (752, 452)], 2.2, (180, 140, 70, 255))
    c.ellipse(736, 440, 768, 472, (214, 170, 80, 255), lw=1.8)

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
    frame(c, fx - 70, 250, fx + 70, 420, family_photo, wood=(120, 80, 50, 255))
    c.stroke([(fx - 40, 252), (fx, 214), (fx + 40, 252)], 1.6, (90, 64, 44, 255))  # 거는 줄
    c.ellipse(fx - 5, 208, fx + 5, 218, (180, 150, 90, 255), lw=1.2)

    # ---- 서랍장 + 위에 둘둘 만 침낭(가죽 띠)
    dx0, dx1 = 960, 1220
    chest = (196, 150, 98, 255)
    c.rect(dx0, 520, dx1, FLOOR + 4, chest)
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
    c.rect(tx - 176, top_y + 22, tx + 176, top_y + 108, lite(desk, 0.08))
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


# ================================================================ 아래층 (1920~6670)


def downstairs_ground(c: Ink, rng, lm: LightMap, mk):
    x0, x1 = ATTIC_W, YARD_X
    # 위 벽(회반죽) + 아래 징두리 판자
    c.rect(x0, CEIL, x1, WAIN, PLASTER, line=False)
    # 벽지: 옅은 세로 줄무늬와 작은 꽃무늬
    def stripes(d, t):
        x = x0
        while x < x1:
            d.rectangle([*t([(x, CEIL)])[0], *t([(x + 14, WAIN)])[0]], fill=alpha(dark(PLASTER, 0.1), 34))
            x += 46
    c.glaze(stripes, (x0, CEIL, x1, WAIN))

    def sprigs(d, t):
        for yy in range(int(CEIL) + 40, int(WAIN) - 20, 70):
            for xx in range(int(x0) + 23 + (yy // 70 % 2) * 23, int(x1), 92):
                q = t([(xx - 4, yy - 4), (xx + 4, yy + 4)])
                d.ellipse([*q[0], *q[1]], fill=alpha((196, 120, 96), 60))
    c.glaze(sprigs, (x0, CEIL, x1, WAIN))
    c.planks_v(rng, x0, WAIN, x1, BASE, WAINSCOT, step=110, jitter=0, grain_n=3)
    c.rect(x0, WAIN - 8, x1, WAIN + 10, lite(WAINSCOT, 0.15))   # 띠(징두리 위 턱)
    c.rect(x0, BASE, x1, FLOOR, dark(WAINSCOT, 0.25))             # 걸레받이
    # 천장 보
    c.rect(x0, 0, x1, CEIL, (164, 116, 76, 255), line=False)
    c.planks_v(rng, x0, 0, x1, CEIL - 30, (170, 122, 80, 255), step=90, jitter=6, grain_n=1)
    c.rect(x0, CEIL - 34, x1, CEIL, BEAM)
    c.rect(x0, CEIL - 10, x1, CEIL, dark(BEAM, 0.3), line=False)
    # 바닥
    c.planks_h(rng, x0, FLOOR, x1, 1080, FLOORC, rows=6)
    # 기둥(방 나눔)
    for px in (x0, 3040, 3960, 4860, 5700):
        w = 44 if px != x0 else 70
        c.rect(px, 0, px + w, FLOOR, BEAM)
        c.rect(px + w - 10, CEIL, px + w, FLOOR, dark(BEAM, 0.3), line=False)
        c.stroke([(px + 8, CEIL + 10), (px + 8, FLOOR - 10)], 2, lite(BEAM, 0.3))
    # 창(빛은 왼쪽에서): 거실 큰 창, 책장 쪽 창, 복도 창
    window(c, 2060, 230, 2440, 540, 3, 2, curtain=(178, 64, 54, 255))
    window(c, 4500, 250, 4760, 520, 2, 2, curtain=(96, 128, 92, 255))
    window(c, 6020, 260, 6200, 500, 2, 2)
    # 현관문(열림): 문틀 안은 바깥(구멍), 밝은 빛이 쏟아진다
    dx0, dx1 = 6500, 6660
    c.erase([(dx0, 200), (dx1, 200), (dx1, FLOOR + 30), (dx0, FLOOR + 30)], keep=0)
    c.rect(dx0 - 22, 180, dx1 + 10, 200, BEAM)
    c.rect(dx0 - 22, 200, dx0, FLOOR + 6, BEAM)
    c.rect(dx1, 200, dx1 + 10, FLOOR + 6, BEAM)
    c.poly([(dx0 - 22, 206), (dx0 - 150, 160), (dx0 - 150, FLOOR + 40), (dx0 - 22, FLOOR + 6)], (120, 84, 54, 255))  # 안쪽으로 열린 문
    c.poly([(dx0 - 40, 240), (dx0 - 132, 210), (dx0 - 132, 420), (dx0 - 40, 440)], (220, 236, 230, 170))  # 문 위 유리
    c.ellipse(dx0 - 128, 520, dx0 - 112, 536, (210, 170, 80, 255), lw=1.2)
    c.rect(dx0 - 30, FLOOR + 4, dx1 + 40, FLOOR + 18, (170, 160, 150, 255))  # 문턱 돌
    # 집 바깥벽 끝(마당 쪽에서 보이는 두께)
    c.rect(dx1 + 10, 0, YARD_X + 30, FLOOR + 6, (200, 176, 140, 255))
    c.rect(dx1 + 10, 0, YARD_X + 30, 30, BEAM)

    # 빛 지도: 아래층은 왼쪽 창에서 든다
    for wx0, wy0, wx1, wy1, k in ((2060, 230, 2440, 540, 1.0), (4500, 250, 4760, 520, 0.8), (6020, 260, 6200, 500, 0.6)):
        lm.glow((wx0 + wx1) / 2, (wy0 + wy1) / 2, (wx1 - wx0) * 1.1, 360, 0.35 * k)
        lm.add([(wx0, wy0), (wx1, wy0), (wx1, wy1), (wx0, wy1)], 0.45, 14)
        leaf_shadow(lm, rng, wx0, wy0, wx1, wy1, 10)
        # 바닥 빛 웅덩이: 오른쪽 아래로 늘어진 창 모양
        dx = (wx1 - wx0)
        lm.add([(wx0 + 220, 840), (wx1 + 260, 840), (wx1 + 420, 1000), (wx0 + 380, 1000)], 0.75 * k, 10)
        # 벽에 비친 빛(창 오른쪽으로 비스듬히)
        lm.add([(wx1 + 40, wy0 + 120), (wx1 + 40 + dx * 0.7, wy0 + 200), (wx1 + 40 + dx * 0.7, wy1 + 160), (wx1 + 40, wy1 + 60)], 0.35 * k, 18)
    lm.add([(x0, -40), (x1, -40), (x1, 210), (x0, 210)], -0.28, 70)  # 천장 쪽은 어둑하게
    lm.add([(x0, 960), (x1, 960), (x1, 1120), (x0, 1120)], -0.15, 60)
    lm.glow(6580, 600, 260, 420, 0.7)  # 현관문 빛
    lm.add([(6500, 820), (6660, 820), (6420, 1080), (6000, 1080)], 0.6, 24)
    lm.glow(5100, 140, 500, 200, -0.25)  # 계단 위 어둠


def downstairs_props(c: Ink, rng, lm: LightMap, mk):
    # ---------- 거실: 러그, 안락의자, 라디오, 벽 선반
    rug = (168, 70, 58, 255)
    c.poly([(2080, 830), (2720, 830), (2800, 930), (2000, 930)], rug)
    c.poly([(2100, 840), (2700, 840), (2770, 920), (2030, 920)], None, lw=2, lc=(222, 176, 104, 255))
    for k in range(1, 8):
        t = k / 8
        c.stroke([(2080 + 640 * t, 834), (2000 + 800 * t, 926)], 1.4, dark(rug, 0.2))
    for x in range(2004, 2800, 14):  # 술
        c.stroke([(x, 930), (x - 2, 942)], 1.4, (222, 196, 150, 255))
    # 라디오(장식장 위)
    rx = 2710
    cab = (138, 90, 56, 255)
    c.rect(rx - 110, 640, rx + 110, FLOOR + 4, cab)
    c.rect(rx - 96, 660, rx + 96, 760, lite(cab, 0.1), lw=1.8)
    c.ellipse(rx - 6, 700, rx + 6, 712, (210, 170, 90, 255), lw=1.2)
    c.rect(rx - 120, 628, rx + 120, 642, lite(cab, 0.2))
    radio = (176, 120, 70, 255)
    c.poly([(rx - 90, 628), (rx - 90, 560), (rx - 70, 530), (rx + 70, 530), (rx + 90, 560), (rx + 90, 628)], radio)
    c.rrect(rx - 74, 552, rx + 10, 616, 8, (224, 206, 164, 255), lw=1.6)  # 스피커 천
    for k in range(5):
        c.stroke([(rx - 68 + k * 16, 558), (rx - 68 + k * 16, 610)], 1.2, dark((224, 206, 164, 255), 0.2))
    c.rrect(rx + 24, 556, rx + 74, 582, 4, (246, 226, 170, 255), lw=1.4)  # 눈금창
    c.stroke([(rx + 44, 558), (rx + 44, 580)], 1.4, (180, 60, 40, 255))
    for cx in (rx + 34, rx + 64):
        c.ellipse(cx - 10, 590, cx + 10, 610, (110, 72, 44, 255), lw=1.4)
    c.stroke([(rx + 60, 530), (rx + 96, 440)], 2, (90, 90, 90, 255))  # 안테나
    # 안락의자(창 앞, 하윤이 깨어나는 자리 뒤)
    ch = (122, 96, 120, 255)
    c.rrect(2180, 560, 2420, 720, 30, ch)  # 등받이
    c.rrect(2160, 680, 2440, 780, 18, lite(ch, 0.12))
    c.rrect(2140, 640, 2200, 780, 18, dark(ch, 0.1))
    c.rrect(2400, 640, 2460, 780, 18, dark(ch, 0.1))
    for x in (2170, 2420):
        c.rect(x, 780, x + 16, FLOOR + 8, (90, 60, 40, 255))
    c.poly([(2230, 600), (2330, 590), (2350, 660), (2240, 668)], (236, 222, 190, 255), lw=1.6)  # 뜨개 덮개
    # 벽 선반 + 접시·작은 그림
    c.rect(2520, 330, 2900, 346, WOOD)
    for k, x in enumerate((2540, 2620, 2700, 2790)):
        if k == 2:
            frame(c, x, 238, x + 70, 330, landscape, mat=False)
        else:
            c.ellipse(x, 262, x + 62, 324, (236, 232, 222, 255), lw=1.8)
            c.ellipse(x + 12, 274, x + 50, 312, (110, 140, 176, 255), lw=1.2)
    # 등(천장 갓등)
    for lx in (2500, 3500, 4400, 5900):
        c.stroke([(lx, CEIL), (lx, 200)], 2, (80, 60, 44, 255))
        c.poly([(lx - 44, 236), (lx + 44, 236), (lx + 18, 196), (lx - 18, 196)], (214, 168, 90, 255))
        c.ellipse(lx - 10, 230, lx + 10, 246, (255, 240, 200, 255), lw=1.2)

    # ---------- 1-2 영정 자리: 흰 천 덮은 낮은 장, 백합, 초 둘 (사진은 게임이 그린다)
    px = mk("1-2", 3260.0)
    c.rect(px - 230, 270, px + 230, 286, WOOD)  # 사진 아래 선반 턱
    cab = (120, 80, 50, 255)
    c.rect(px - 210, 640, px + 210, FLOOR + 4, cab)
    c.poly([(px - 220, 626), (px + 220, 626), (px + 230, 700), (px + 200, 690), (px + 170, 712), (px - 170, 712), (px - 200, 690), (px - 230, 700)],
           (246, 242, 232, 255))  # 흰 천
    for x in (px - 150, px + 150):
        c.rect(x - 10, 560, x + 10, 626, (250, 246, 236, 255), lw=1.6)
        c.rect(x - 16, 618, x + 16, 630, (200, 170, 100, 255), lw=1.4)
        c.poly([(x, 538), (x + 6, 552), (x, 562), (x - 6, 552)], (255, 214, 120, 255), lw=1.0)
        lm.glow(x, 550, 50, 50, 0.4, 20)
    vase(c, px, 626, 70, (238, 236, 230, 255))
    for k, (dx, dy) in enumerate(((-26, -100), (8, -122), (30, -92))):
        c.stroke([(px, 560), (px + dx, 560 + dy + 26)], 2, (110, 140, 80, 255))
        lily(c, px + dx, 560 + dy + 14, 0.8)

    # ---------- 식탁 + 흰 백합 한 송이
    tx = 3640
    c.rect(tx - 160, 650, tx + 160, 668, lite(WOOD, 0.15))
    c.rect(tx - 150, 668, tx - 134, FLOOR + 6, WOOD)
    c.rect(tx + 134, 668, tx + 150, FLOOR + 6, WOOD)
    c.poly([(tx - 120, 650), (tx + 130, 650), (tx + 120, 690), (tx - 110, 690)], (240, 236, 224, 255), lw=1.6)  # 식탁보
    vase(c, tx + 40, 650, 56, (220, 234, 238, 255))
    c.stroke([(tx + 40, 600), (tx + 56, 540)], 2, (110, 140, 80, 255))
    lily(c, tx + 58, 536, 0.75)
    c.ellipse(tx - 90, 636, tx - 30, 652, (236, 232, 222, 255), lw=1.4)  # 빈 접시
    chair_ladder(c, tx - 250, FLOOR + 6, 0.85, (150, 104, 66, 255))
    # 안쪽 문간(현관 쪽)과 검은 구두 줄
    c.rect(3800, 300, 3940, FLOOR, (92, 64, 50, 255))
    c.rect(3800, 290, 3940, 304, BEAM)
    c.rect(3790, 300, 3804, FLOOR, BEAM)
    c.rect(3936, 300, 3950, FLOOR, BEAM)
    lm.add([(3800, 300), (3940, 300), (3940, FLOOR), (3800, FLOOR)], -0.35, 10)
    c.poly([(3700, FLOOR + 12), (4000, FLOOR + 12), (4020, FLOOR + 52), (3680, FLOOR + 52)], (120, 100, 80, 255))  # 신발 깔개
    for k in range(5):  # 검은 구두 줄(조문객)
        sx = 3710 + k * 60
        sole = FLOOR + 44
        c.poly([(sx, sole), (sx + 4, sole - 20), (sx + 20, sole - 24), (sx + 34, sole - 16), (sx + 52, sole - 10), (sx + 54, sole)],
               (36, 32, 36, 255), lw=1.4)
        c.stroke([(sx + 8, sole - 18), (sx + 22, sole - 20)], 2, (140, 140, 150, 255))
        c.stroke([(sx + 2, sole - 2), (sx + 52, sole - 2)], 2, (80, 70, 70, 255))

    # ---------- 1-3 책장과 앨범
    bx0, bx1 = 4000, 4280
    shelf = (130, 84, 52, 255)
    c.rect(bx0, 300, bx1, FLOOR + 4, shelf)
    c.rect(bx0 + 14, 314, bx1 - 14, FLOOR - 10, dark(shelf, 0.45), line=False)
    for y in (420, 540, 660, FLOOR - 10):
        c.rect(bx0 + 10, y - 10, bx1 - 10, y, lite(shelf, 0.15), lw=1.6)
        book_row(c, rng, bx0 + 18, bx1 - 20, y - 10, 70, 104)
    c.rect(bx0 - 8, 290, bx1 + 8, 306, lite(shelf, 0.2))
    c.ellipse(bx0 + 30, 236, bx0 + 90, 290, (130, 160, 110, 255))  # 화분
    c.rect(bx0 + 40, 262, bx0 + 80, 292, (190, 110, 70, 255))
    # 앨범 탁자 + 앨범
    ax = mk("1-3", 4140.0) + 220
    c.rect(ax - 110, 700, ax + 110, 716, lite(WOOD, 0.1))
    c.rect(ax - 96, 716, ax - 84, FLOOR + 6, WOOD)
    c.rect(ax + 84, 716, ax + 96, FLOOR + 6, WOOD)
    c.poly([(ax - 70, 700), (ax + 60, 700), (ax + 70, 684), (ax - 60, 684)], (120, 60, 46, 255))
    c.poly([(ax - 66, 684), (ax + 56, 684), (ax + 60, 678), (ax - 60, 678)], (240, 230, 206, 255), lw=1.2)
    # 흔들의자
    rk = (156, 104, 64, 255)
    c.rect(4540, 600, 4556, 780, rk)
    for k in range(4):
        c.rect(4556, 610 + k * 40, 4610, 620 + k * 40, rk, lw=1.4)
    c.rect(4540, 700, 4700, 716, lite(rk, 0.15))
    c.rect(4680, 716, 4694, 790, rk)
    c.stroke([(4500, 790), (4560, 800), (4660, 800), (4740, 786)], 6, rk)
    c.poly([(4566, 640), (4650, 660), (4640, 700), (4560, 700)], (214, 196, 150, 255), lw=1.4)  # 숄

    # ---------- 다락 계단: 오른쪽 아래(5480)에서 왼쪽 위(4900, 천장 구멍)로
    st = (170, 116, 72, 255)
    n = 11
    foot_x, top_x = 5480.0, 4920.0
    top_y = CEIL
    c.rect(4880, 0, 5140, CEIL + 6, (36, 26, 22, 255))  # 천장 구멍(다락으로)
    lm.add([(4880, 0), (5140, 0), (5140, CEIL), (4880, CEIL)], 0.3, 20)
    for k in range(n):
        x = foot_x - (foot_x - top_x) * (k + 1) / n
        y = FLOOR - (FLOOR - top_y) * (k + 1) / n
        sx = (foot_x - top_x) / n
        c.rect(x, y, x + sx + 6, y + 14, lite(st, 0.2), lw=1.6)  # 디딤판
        c.rect(x + 4, y + 14, x + sx + 2, y + (FLOOR - top_y) / n, dark(st, 0.18), lw=1.4)  # 챌판
    c.poly([(foot_x + 40, FLOOR + 6), (top_x - 10, top_y - 10), (top_x + 40, top_y - 10), (foot_x + 80, FLOOR + 6)], st)  # 옆판
    # 난간
    rail = [(foot_x + 70, FLOOR - 190), (top_x + 40, top_y - 160)]
    c.stroke(rail, 10, (120, 78, 48, 255))
    for k in range(0, n, 2):
        t = (k + 0.5) / n
        x = foot_x + 60 + (top_x + 30 - foot_x - 60) * t
        yb = FLOOR + (top_y - FLOOR) * t
        c.stroke([(x, yb - 20), (x, yb - 190)], 5, (140, 92, 58, 255))
    c.rect(foot_x + 50, FLOOR - 230, foot_x + 86, FLOOR + 6, (120, 78, 48, 255))  # 엄지기둥
    c.ellipse(foot_x + 44, FLOOR - 252, foot_x + 92, FLOOR - 222, (130, 86, 54, 255))
    # 괘종시계
    gx = 5600
    c.rect(gx, 360, gx + 80, FLOOR + 6, (110, 70, 44, 255))
    c.rect(gx + 12, 470, gx + 68, 720, (200, 176, 140, 255), lw=1.6)
    c.stroke([(gx + 40, 470), (gx + 40, 680)], 2, (190, 150, 70, 255))
    c.ellipse(gx + 26, 670, gx + 54, 698, (210, 170, 80, 255), lw=1.4)
    c.poly([(gx - 8, 360), (gx + 88, 360), (gx + 70, 330), (gx + 10, 330)], (110, 70, 44, 255))
    clock_face(c, gx + 40, 410, 28, (110, 70, 44, 255))

    # ---------- 복도: 외투걸이(할아버지 모자·외투), 우산꽂이, 작은 탁자, 액자들
    hx = 5820
    c.rect(hx, 260, hx + 14, FLOOR + 6, (100, 66, 42, 255))
    c.rect(hx - 50, FLOOR - 4, hx + 64, FLOOR + 8, (100, 66, 42, 255))
    for dx in (-30, 44):
        c.stroke([(hx + 7, 290), (hx + dx, 320)], 4, (100, 66, 42, 255))
    coat = (96, 84, 72, 255)
    c.poly([(hx - 30, 320), (hx + 44, 320), (hx + 70, 600), (hx + 30, 640), (hx - 20, 630), (hx - 54, 590)], coat)
    c.stroke([(hx + 7, 330), (hx + 4, 620)], 1.6, dark(coat, 0.3))
    hat = (150, 120, 80, 255)
    c.poly([(hx - 50, 300), (hx + 64, 300), (hx + 48, 290), (hx + 40, 256), (hx - 26, 256), (hx - 34, 290)], hat)  # 할아버지 모자
    c.rect(hx - 30, 280, hx + 44, 290, (90, 64, 44, 255), line=False)
    c.rrect(5940, 700, 5990, FLOOR + 6, 8, (90, 110, 120, 255))  # 우산꽂이
    c.stroke([(5956, 700), (5948, 600), (5936, 590)], 4, (40, 40, 50, 255))
    c.rect(6260, 640, 6420, 656, WOOD)  # 작은 탁자
    c.rect(6270, 656, 6282, FLOOR + 6, WOOD)
    c.rect(6398, 656, 6410, FLOOR + 6, WOOD)
    c.ellipse(6300, 624, 6360, 644, (200, 180, 140, 255), lw=1.4)  # 열쇠 그릇
    for fx0, fy0, fw, fh in ((6260, 300, 90, 110), (6370, 330, 70, 80)):
        frame(c, fx0, fy0, fx0 + fw, fy0 + fh, landscape)


def yard_ground(c: Ink, rng, lm: LightMap, w):
    x0 = YARD_X
    dirt = (196, 160, 112, 255)
    c.rect(x0, FLOOR - 6, w, 1080, dirt, line=False)
    # 마당 흙: 가로 결, 그늘진 자국, 풀 포기, 낙엽
    for _ in range(int((w - x0) / 6)):
        x, y = rng.uniform(x0, w), rng.uniform(FLOOR, 1080)
        ln = rng.uniform(20, 80) * (1 + (y - FLOOR) / 300)
        c.stroke([(x, y), (x + ln, y + rng.uniform(-1, 1))], 1.2, alpha(dark(dirt, 0.25), 70))
    # 디딤돌 길(문간 → 대문)
    for k in range(8):
        sx = x0 + 60 + k * 150 + rng.uniform(-10, 10)
        sy = 840 + (k % 2) * 30
        c.ellipse(sx, sy, sx + 120, sy + 40, (182, 176, 166, 255), lw=1.6)
        c.ellipse(sx + 14, sy + 6, sx + 80, sy + 20, (214, 208, 196, 255), line=False)
    for _ in range(int((w - x0) / 5)):  # 낙엽
        x, y = rng.uniform(x0, w), rng.uniform(FLOOR + 4, 1076)
        col = rng.choice([(214, 110, 50, 255), (232, 170, 70, 255), (186, 70, 46, 255), (200, 60, 50, 255)])
        a = rng.uniform(0, math.tau)
        s = rng.uniform(5, 10)
        c.poly([(x + math.cos(a) * s, y + math.sin(a) * s * 0.45), (x + math.cos(a + 2.2) * s * 0.7, y + math.sin(a + 2.2) * s * 0.3),
                (x + math.cos(a + 4.1) * s * 0.7, y + math.sin(a + 4.1) * s * 0.3)], col, lw=0.8)
    lm.add([(x0, 0), (w + 40, 0), (w + 40, 1080), (x0, 1080)], 0.32, 30)  # 바깥은 환하다


def yard_props(c: Ink, rng, lm: LightMap, mk, w):
    x0 = YARD_X
    # 낮은 돌담(뒤쪽)
    stone = (176, 166, 150, 255)
    c.rect(x0 + 30, 640, w + 20, FLOOR + 4, stone, line=False)
    y = 640
    row = 0
    while y < FLOOR:
        h = rng.uniform(34, 48)
        x = x0 + 30 - (row % 2) * 40
        while x < w + 20:
            sw = rng.uniform(60, 120)
            c.rrect(x + 2, y + 2, x + sw - 2, min(FLOOR + 4, y + h) - 2, 10,
                    mix(stone, rng.choice([(150, 140, 126, 255), (200, 190, 174, 255), (168, 160, 140, 255)]), rng.uniform(0.2, 0.8)), lw=1.8)
            x += sw
        y += h
        row += 1
    c.rect(x0 + 20, 626, w + 20, 646, (150, 140, 124, 255))  # 담 위 갓돌
    for _ in range(int((w - x0) / 30)):  # 담 위 이끼·덩굴
        x = rng.uniform(x0 + 40, w)
        c.ellipse(x - 20, 620, x + 20, 640, (120, 130, 70, 255), line=False)
    # 화분 몇(문간)
    for k, (px, col) in enumerate(((6730, (220, 90, 70, 255)), (6800, (240, 200, 90, 255)))):
        c.poly([(px - 26, 760), (px + 26, 760), (px + 20, FLOOR + 6), (px - 20, FLOOR + 6)], (180, 100, 64, 255))
        for j in range(6):
            a = j / 6 * math.tau
            c.ellipse(px + math.cos(a) * 16 - 10, 740 + math.sin(a) * 10 - 10, px + math.cos(a) * 16 + 10, 740 + math.sin(a) * 10 + 10, col, lw=1.2)
    # 장작더미
    for k in range(9):
        lx = 6880 + (k % 3) * 44 + (k // 3) * 20
        ly = 776 - (k // 3) * 40
        c.ellipse(lx, ly, lx + 44, ly + 40, (190, 150, 100, 255), lw=1.6)
        c.ellipse(lx + 12, ly + 10, lx + 32, ly + 30, (150, 110, 70, 255), lw=1.0)
    # 사과나무(1-6): 굵은 줄기와 가지, 단풍 든 잎 덩어리, 빨간 사과
    tx = mk("1-6", 7110.0) - 120
    bark = (110, 78, 56, 255)
    c.poly([(tx - 34, FLOOR + 6), (tx - 20, 560), (tx - 60, 380), (tx - 30, 376), (tx + 4, 520), (tx + 40, 360),
            (tx + 70, 370), (tx + 26, 560), (tx + 36, FLOOR + 6)], bark)
    c.stroke([(tx - 10, 760), (tx - 4, 600)], 2, dark(bark, 0.3))
    leaf_cols = [(214, 150, 66), (196, 110, 54), (232, 186, 90), (170, 130, 60), (150, 140, 70)]
    blobs = []
    for _ in range(120):
        a = rng.uniform(0, math.tau)
        rr = rng.uniform(0, 1) ** 0.5
        bx = tx + math.cos(a) * 270 * rr
        by = 300 + math.sin(a) * 150 * rr
        r = rng.uniform(26, 50)
        blobs.append((bx, by, r))
    blobs.sort(key=lambda b: b[1])
    for bx, by, r in blobs:
        col = mix(rng.choice(leaf_cols) + (255,), (110, 70, 60, 255), max(0.0, (by - 260) / 400))
        c.ellipse(bx - r, by - r * 0.8, bx + r, by + r * 0.8, col, lw=1.6)
        c.ellipse(bx - r * 0.6, by - r * 0.7, bx + r * 0.4, by - r * 0.1, lite(col, 0.3), line=False)
    for _ in range(26):
        a = rng.uniform(0, math.tau)
        rr = rng.uniform(0.2, 1)
        ax, ay = tx + math.cos(a) * 240 * rr, 320 + math.sin(a) * 120 * rr
        c.ellipse(ax - 12, ay - 12, ax + 12, ay + 12, (200, 44, 40, 255), lw=1.6)
        c.ellipse(ax - 6, ay - 8, ax - 1, ay - 3, (255, 200, 180, 255), line=False)
    for _ in range(5):  # 떨어진 사과
        ax = tx + rng.uniform(-200, 200)
        c.ellipse(ax - 10, 870 + rng.uniform(0, 60), ax + 10, 890 + rng.uniform(0, 60), (190, 40, 40, 255), lw=1.4)
    lm.glow(tx, 520, 300, 160, -0.3)  # 나무 그늘
    lm.add([(tx - 220, FLOOR + 10), (tx + 260, FLOOR + 10), (tx + 300, FLOOR + 80), (tx - 240, FLOOR + 80)], -0.35, 24)
    # 나무 대문(1-6, 반쯤 열림)과 기둥
    gx = 7220
    post = (120, 84, 56, 255)
    for x in (gx - 120, gx + 120):
        c.rect(x - 18, 520, x + 18, FLOOR + 10, post)
        c.poly([(x - 26, 520), (x + 26, 520), (x, 494)], dark(post, 0.1))
    c.rect(gx - 150, 520, gx + 150, 540, post)  # 위 가로대
    gate = (164, 120, 78, 255)
    c.poly([(gx + 102, 590), (gx + 220, 640), (gx + 220, 830), (gx + 102, FLOOR + 6)], gate)  # 바깥으로 열린 문짝
    for k in range(1, 4):
        t = k / 4
        c.stroke([(gx + 102 + 118 * t, 590 + 50 * t), (gx + 102 + 118 * t, FLOOR + 6 + 24 * t)], 1.6, dark(gate, 0.3))
    c.stroke([(gx + 102, 690), (gx + 220, 720)], 6, dark(gate, 0.15))
    # 대문 너머 길
    lm.glow(gx + 300, 700, 400, 260, 0.2)


def front_layer(width: float, rng) -> Image.Image:
    """앞 층(scroll 1.25): 다락 앞 물건, 거실 화분, 마당 사과나무 가지. 모두 흐리게(기둥은 하윤을 가려 뺐다)."""
    w = pa.layer_width(width, "front")
    c = Ink(w)
    attic_front(c, rng)

    def fx(world_x):  # 그 자리가 화면 가운데일 때 앞 층 x
        return pa.layer_x(world_x, "front")

    # 거실 맨 앞 화분(큰 잎)
    px = fx(2600) - 820
    for k in range(9):
        a = math.radians(-160 + k * 18)
        c.poly([(px, 1080), (px + math.cos(a) * 260 - 30, 1080 + math.sin(a) * 300), (px + math.cos(a) * 300, 1080 + math.sin(a) * 320 + 30)],
               (70, 100, 64, 255), lw=2)
    c.poly([(px - 70, 1090), (px + 70, 1090), (px + 54, 990), (px - 54, 990)], (160, 90, 60, 255))
    # 마당 맨 앞 사과나무 가지
    ax = fx(7000) - 400
    c.stroke([(ax - 400, -20), (ax - 120, 60), (ax + 240, 40)], 22, (90, 64, 46, 255))
    for _ in range(30):
        bx, by = ax - 360 + rng.uniform(0, 640), rng.uniform(0, 140)
        r = rng.uniform(26, 46)
        c.ellipse(bx - r, by - r * 0.7, bx + r, by + r * 0.7, rng.choice([(196, 110, 54, 255), (224, 168, 80, 255), (170, 120, 60, 255)]), lw=1.6)
    img = c.finish()
    return ink.soften(img, 7.0)


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


def paint(width: float, markers: dict[str, float]) -> dict:
    rng = random.Random("house-ink")
    mk = markers.get
    layers = {}

    layers["sky"] = ink.as_layer(sky_layer(width, rng), pa.layer_width(width, "sky"))
    for name in ("horizon", "near"):  # 이 집에서는 쓰지 않는 층(투명)
        w = pa.layer_width(width, name)
        layers[name] = ink.as_layer(Image.new("RGBA", (w, 1080), (0, 0, 0, 0)), w)
    layers["far"] = ink.as_layer(back_layer("far", width, rng, far_build), pa.layer_width(width, "far"))
    layers["hills"] = ink.as_layer(back_layer("hills", width, rng, hills_build), pa.layer_width(width, "hills"))
    layers["mid"] = ink.as_layer(back_layer("mid", width, rng, mid_build), pa.layer_width(width, "mid"))

    # 땅(벽·바닥)과 물건은 같은 빛 지도를 쓴다.
    gw = pa.layer_width(width, "ground")
    lm = LightMap(gw, 0.62)
    g = Ink(gw)
    attic_ground(g, rng, lm, mk)
    downstairs_ground(g, rng, lm, mk)
    yard_ground(g, rng, lm, gw)
    p = Ink(pa.layer_width(width, "props"))
    attic_props(p, rng, lm, mk)
    downstairs_props(p, rng, lm, mk)
    yard_props(p, rng, lm, mk, gw)
    L = lm.array()
    ground = ink.light(g.finish(), L, SUN, SHADE)
    props = ink.light(p.finish(), L, SUN, SHADE)

    # 빛줄기(물건 층 위, 하윤 뒤): 다락 오른쪽 창 → 왼쪽 아래, 아래층 창들 → 오른쪽 아래
    beams = [
        ([(1440, 200), (1700, 200), (1130, 1080), (700, 1080)], 0.9),
        ([(1500, 230), (1580, 230), (1000, 1080), (880, 1080)], 0.6),
        ([(2060, 230), (2440, 230), (2860, 1000), (2420, 1000)], 0.55),
        ([(4500, 250), (4760, 250), (5080, 1000), (4800, 1000)], 0.45),
        ([(6020, 260), (6200, 260), (6420, 980), (6240, 980)], 0.35),
        ([(6500, 200), (6660, 200), (6620, 1080), (6300, 1080)], 0.5),
    ]
    props.alpha_composite(ink.rays(props.width, beams))
    ink.motes(props, rng, 900, [(1440, 200), (1700, 200), (1130, 1080), (700, 1080)])
    ink.motes(props, rng, 500, [(2060, 230), (2440, 230), (2860, 1000), (2420, 1000)])
    ink.bokeh(props, rng, 14, 1100, 1750, 150, 700)
    ink.bokeh(props, rng, 10, 2100, 2900, 200, 700)
    ink.bokeh(props, rng, 8, 6300, 6700, 200, 800)

    layers["ground"] = ink.as_layer(ground, gw)
    layers["props"] = ink.as_layer(props, pa.layer_width(width, "props"))
    layers["front"] = ink.as_layer(front_layer(width, rng), pa.layer_width(width, "front"))
    return layers
