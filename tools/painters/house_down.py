"""1. 할아버지 집 아래층과 마당 — 깊이가 있는 방 (#151).

방을 정면에서 납작하게 그리지 않고, 깊이(스크롤 빠르기 s)가 다른 판 여럿으로 나눈다.
모든 판은 "세계 크기"(하윤 줄, 깊이 1: 바닥 y 810, 천장 y 97.5)로 그린 뒤 소실점(960, 210)을 축으로 s배 줄인다(ink.to_plane).
  뒷벽       s 0.80  Near 층 (bg_house_near)              — 벽·창·벽에 붙은 가구, 마당 돌담
  가구       s 0.95  Furniture 층 (room_house_furniture)  — 방 가운데 가구, 매단 등, 사과나무
  하윤       s 1.00
  맨 앞      s 1.25  Front 층 (bg_house_front)            — 천장 앞 보, 낮은 화분·바구니, 사과나무 가지
  바닥·천장  room_house_floor / room_house_ceiling        — 평면 좌표(p = 세계 x) × 화면 줄. shaders/room_plane이 원근으로 편다
  옆벽       room_house_endwall_*                         — 방 왼쪽 끝(p 1920)과 현관 쪽 끝(p 6670, 문). PerspectivePlane
빛은 왼쪽 뒤 창에서 든다: 물건 그림자는 오른쪽·앞으로, 빛 쪽(왼쪽 위) 가장자리는 밝게(rim).
수(소실점, 바닥 기울기)는 scripts/game/room_perspective.gd와 같다.
"""
from __future__ import annotations

import math
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import placeholder_art as pa
import ink
from ink import Ink, LightMap, alpha, dark, lite, mix

VP_Y, FLOOR_K, CEIL_K = 210.0, 600.0, 112.5
WALL_S, FURN_S, FRONT_S = 0.8, 0.95, 1.25
FLOOR_W, CEIL_W = 810.0, 97.5             # 세계 크기에서 바닥·천장 y
ROOM_X0, YARD_X = 1920.0, 6670.0
WORLD_W = 8000                              # 세계 크기 그림 폭(p 0 ~ 8000)
P0, P_W = 1600, 6400                        # 바닥·천장 그림이 덮는 p
SUN = (255, 214, 150)
SHADE = (92, 70, 112)

PLASTER = (236, 212, 170, 255)
WAINSCOT = (166, 108, 68, 255)
BEAM = (104, 66, 42, 255)
FLOORC = (184, 124, 76, 255)
WOOD = (150, 96, 58, 255)
PAPER = (246, 232, 204, 255)

# 아래층 창(세계 x, 세계 y)
WINDOWS = [(2060, 240, 2440, 560, (176, 62, 52, 255)), (4500, 260, 4760, 540, (92, 126, 90, 255)), (6020, 270, 6200, 500, None)]
RAIL, WAIN_TOP, BASE_TOP = 560.0, 578.0, 780.0


def floor_y(s: float) -> float:
    return VP_Y + FLOOR_K * s


def ceil_y(s: float) -> float:
    return VP_Y - CEIL_K * s


def s_of_floor_y(y: float) -> float:
    return (y - VP_Y) / FLOOR_K


def layer_u(p: float, s: float) -> float:
    return (p - 960.0) * s + 960.0


# ================================================================ 뒷벽 (세계 크기로 그린다)


def _wall(c: Ink, rng, lm: LightMap):
    x0, x1 = ROOM_X0, YARD_X
    # 회반죽 벽: 위가 어둑하고 가운데가 밝다
    c.grad([(x0, CEIL_W), (x1, CEIL_W), (x1, RAIL), (x0, RAIL)], dark(PLASTER, 0.18), PLASTER, line=False, power=0.6)

    def stripes(d, t):
        x = x0
        while x < x1:
            d.rectangle([*t([(x, CEIL_W + 30)])[0], *t([(x + 14, RAIL)])[0]], fill=alpha(dark(PLASTER, 0.1), 30))
            x += 46
    c.glaze(stripes, (x0, CEIL_W, x1, RAIL))

    def sprigs(d, t):
        for yy in range(int(CEIL_W) + 70, int(RAIL) - 20, 70):
            for xx in range(int(x0) + 23 + (yy // 70 % 2) * 23, int(x1), 92):
                for k in range(3):
                    a = k * 2.1 + yy
                    q = t([(xx + math.cos(a) * 5 - 3.5, yy + math.sin(a) * 5 - 3.5), (xx + math.cos(a) * 5 + 3.5, yy + math.sin(a) * 5 + 3.5)])
                    d.ellipse([*q[0], *q[1]], fill=alpha((190, 116, 92), 52))
                q = t([(xx - 2, yy - 2), (xx + 2, yy + 2)])
                d.ellipse([*q[0], *q[1]], fill=alpha((150, 120, 60), 70))
    c.glaze(sprigs, (x0, CEIL_W, x1, RAIL))
    # 천장 아래 돌림띠와 보
    c.grad([(x0, CEIL_W), (x1, CEIL_W), (x1, CEIL_W + 34), (x0, CEIL_W + 34)], dark(BEAM, 0.1), BEAM, line=False)
    c.stroke([(x0, CEIL_W + 34), (x1, CEIL_W + 34)], 2)
    c.rect(x0, CEIL_W + 34, x1, CEIL_W + 44, lite(BEAM, 0.25), lw=1.4)
    # 징두리 판자 + 걸레받이
    c.planks_v(rng, x0, WAIN_TOP, x1, BASE_TOP, WAINSCOT, step=110, jitter=0, grain_n=3)
    for x in np.arange(x0 + 20, x1, 110):  # 판자마다 테두리(움푹한 판)
        c.rect(x + 10, WAIN_TOP + 22, x + 92, BASE_TOP - 22, None, lw=1.4, lc=alpha(dark(WAINSCOT, 0.35), 255))
        c.stroke([(x + 12, WAIN_TOP + 24), (x + 90, WAIN_TOP + 24)], 1.4, lite(WAINSCOT, 0.3))
    c.rect(x0, RAIL - 8, x1, WAIN_TOP + 4, lite(WAINSCOT, 0.18))
    c.stroke([(x0, RAIL - 8), (x1, RAIL - 8)], 2, lite(WAINSCOT, 0.5))
    c.grad([(x0, BASE_TOP), (x1, BASE_TOP), (x1, FLOOR_W + 6), (x0, FLOOR_W + 6)], dark(WAINSCOT, 0.2), dark(WAINSCOT, 0.45))
    # 기둥(벽에 박힌 굵은 기둥)
    for px in (3040, 3960, 4860, 5700):
        c.grad([(px, CEIL_W + 34), (px + 46, CEIL_W + 34), (px + 46, FLOOR_W + 6), (px, FLOOR_W + 6)], lite(BEAM, 0.15), dark(BEAM, 0.3), axis="x", cast=True)
        c.stroke([(px + 8, CEIL_W + 50), (px + 8, FLOOR_W - 6)], 2, lite(BEAM, 0.35))

    # 창: 구멍(뒤 층 하늘·산이 비친다), 창살, 창턱. 커튼은 따로 그린 그림(살랑인다)
    for wx0, wy0, wx1, wy1, curtain in WINDOWS:
        _window(c, wx0, wy0, wx1, wy1)
        lm.glow((wx0 + wx1) / 2, (wy0 + wy1) / 2, (wx1 - wx0) * 1.1, 360, 0.3)
        lm.add([(wx0, wy0), (wx1, wy0), (wx1, wy1), (wx0, wy1)], 0.5, 14)
        dx = wx1 - wx0
        # 벽에 비친 창빛(오른쪽 아래로 비스듬히) — 나뭇잎 그림자는 dapple 셰이더가 움직인다
        lm.add([(wx1 + 60, wy0 + 130), (wx1 + 60 + dx * 0.75, wy0 + 210), (wx1 + 60 + dx * 0.75, wy1 + 150), (wx1 + 60, wy1 + 70)], 0.3, 18)
    # 어둑한 곳: 천장 쪽, 방 왼쪽 끝 구석, 바닥 가까이
    lm.add([(x0 - 40, 0), (x1, 0), (x1, CEIL_W + 120), (x0 - 40, CEIL_W + 120)], -0.3, 70)
    lm.add([(x0 - 80, 0), (x0 + 160, 0), (x0 + 160, 1080), (x0 - 80, 1080)], -0.3, 90)
    lm.add([(x0, 760), (x1, 760), (x1, 830), (x0, 830)], -0.25, 20)


def _window(c: Ink, x0, y0, x1, y1, frame_c=(150, 98, 60, 255)):
    t = 16
    c.erase([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], keep=0)
    c.rect(x0, y0, x1, y1, alpha((255, 244, 214), 60), line=False)
    cols = 3 if x1 - x0 > 300 else 2
    for k in range(1, cols):
        x = x0 + (x1 - x0) * k / cols
        c.rect(x - 5, y0, x + 5, y1, frame_c, lw=1.6)
    my = y0 + (y1 - y0) * 0.45
    c.rect(x0, my - 5, x1, my + 5, frame_c, lw=1.6)
    # 창 깊이(벽 두께): 왼쪽·위 안쪽 면
    c.poly([(x0, y0), (x1, y0), (x1 - 4, y0 + 12), (x0 + 12, y0 + 12)], dark(frame_c, 0.25), line=False)
    c.poly([(x0, y0), (x0 + 12, y0 + 12), (x0 + 12, y1), (x0, y1)], dark(frame_c, 0.15), line=False)
    for (a, b) in (((x0 - t, y0 - t), (x1 + t, y0)), ((x0 - t, y1), (x1 + t, y1 + t)), ((x0 - t, y0), (x0, y1)), ((x1, y0), (x1 + t, y1))):
        c.rect(a[0], a[1], b[0], b[1], frame_c, cast=True)
    c.poly([(x0 + (x1 - x0) * 0.55, y0), (x0 + (x1 - x0) * 0.68, y0), (x0 + (x1 - x0) * 0.3, y1), (x0 + (x1 - x0) * 0.17, y1)], (255, 255, 250, 36), line=False)
    c.grad([(x0 - t - 20, y1 + t), (x1 + t + 20, y1 + t), (x1 + t + 20, y1 + t + 18), (x0 - t - 20, y1 + t + 18)], lite(frame_c, 0.3), frame_c, cast=True)
    c.rect(x0 - t - 12, y1 + t + 18, x1 + t + 12, y1 + t + 26, dark(frame_c, 0.25))
    c.rect(x0 - 100, y0 - 62, x1 + 100, y0 - 50, (110, 74, 48, 255), lw=1.6)  # 커튼 봉(커튼 그림은 따로)
    for xe in (x0 - 108, x1 + 96):
        c.ellipse(xe, y0 - 66, xe + 12, y0 - 46, (110, 74, 48, 255), lw=1.4)


def _wall_things(c: Ink, rng, lm: LightMap, mk):
    import house as H  # 작은 물건 그리기(책 줄·액자·백합 등)는 다락과 같이 쓴다
    # ---------- 거실: 라디오 장식장, 벽 선반(접시·작은 그림), 벽등
    rx = 2710
    cab = (138, 90, 56, 255)
    c.grad([(rx - 120, 630), (rx + 120, 630), (rx + 120, FLOOR_W), (rx - 120, FLOOR_W)], lite(cab, 0.1), dark(cab, 0.25), cast=True)
    c.rect(rx - 104, 654, rx + 104, 770, lite(cab, 0.08), lw=1.8)
    c.stroke([(rx, 654), (rx, 770)], 1.6)
    for xx in (rx - 16, rx + 16):
        c.ellipse(xx - 6, 704, xx + 6, 716, (210, 170, 90, 255), lw=1.2)
    c.rect(rx - 132, 618, rx + 132, 632, lite(cab, 0.25), cast=True)
    radio = (176, 120, 70, 255)
    c.grad([(rx - 96, 618), (rx - 96, 548), (rx - 74, 516), (rx + 74, 516), (rx + 96, 548), (rx + 96, 618)], lite(radio, 0.2), dark(radio, 0.2), cast=True)
    c.rrect(rx - 80, 540, rx + 8, 606, 8, (224, 206, 164, 255), lw=1.6)
    for k in range(5):
        c.stroke([(rx - 72 + k * 16, 546), (rx - 72 + k * 16, 600)], 1.2, dark((224, 206, 164, 255), 0.2))
    c.rrect(rx + 22, 544, rx + 80, 572, 4, (246, 226, 170, 255), lw=1.4)
    c.stroke([(rx + 46, 546), (rx + 46, 570)], 1.4, (180, 60, 40, 255))
    for cx in (rx + 34, rx + 68):
        c.ellipse(cx - 11, 580, cx + 11, 602, (110, 72, 44, 255), lw=1.4)
    c.stroke([(rx + 60, 516), (rx + 100, 420)], 2, (90, 90, 90, 255))
    lm.glow(rx + 50, 560, 30, 14, 0.35, 8)  # 눈금창 불빛
    c.grad([(2520, 330), (2900, 330), (2900, 346), (2520, 346)], lite(WOOD, 0.2), WOOD, cast=True)
    for k, x in enumerate((2540, 2620, 2700, 2790)):
        if k == 2:
            H.frame(c, x, 238, x + 70, 330, H.landscape, mat=False)
        else:
            c.ellipse(x, 262, x + 62, 324, (236, 232, 222, 255), lw=1.8, cast=True)
            c.ellipse(x + 12, 274, x + 50, 312, (110, 140, 176, 255), lw=1.2)
    c.rect(2960, 330, 2990, 380, (180, 140, 90, 255), lw=1.4)  # 벽등
    c.poly([(2950, 300), (3000, 300), (2990, 334), (2960, 334)], (240, 214, 160, 255), lw=1.4)

    # ---------- 1-2 영정 자리(사진은 게임이 그린다): 선반 턱, 흰 천 덮은 낮은 장, 초(불꽃은 따로), 백합
    px = mk("1-2", 3260.0)
    c.rect(px - 210, 506, px + 210, 520, WOOD, cast=True)  # 사진 아래 선반 턱
    cab = (120, 80, 50, 255)
    c.grad([(px - 210, 640), (px + 210, 640), (px + 210, FLOOR_W), (px - 210, FLOOR_W)], cab, dark(cab, 0.3), cast=True)
    c.grad([(px - 220, 626), (px + 220, 626), (px + 230, 700), (px + 200, 690), (px + 170, 714), (px - 170, 714), (px - 200, 690), (px - 230, 700)],
           (250, 248, 240, 255), (214, 210, 204, 255), cast=True)
    for k in range(5):
        x = px - 160 + k * 80
        c.stroke([(x, 640), (x + 8, 706)], 1.2, (200, 196, 190, 255))
    for x in (px - 150, px + 150):
        c.grad([(x - 10, 560), (x + 10, 560), (x + 10, 626), (x - 10, 626)], (255, 252, 240, 255), (220, 214, 200, 255), axis="x", cast=True)
        c.rect(x - 16, 618, x + 16, 630, (200, 170, 100, 255), lw=1.4)
        lm.glow(x, 545, 70, 70, 0.45, 26)
    H.vase(c, px, 626, 70, (238, 236, 230, 255))
    for dx, dy in ((-26, -100), (8, -122), (30, -92)):
        c.stroke([(px, 560), (px + dx, 560 + dy + 26)], 2, (110, 140, 80, 255))
        H.lily(c, px + dx, 560 + dy + 14, 0.8)

    # ---------- 찬장(접시와 컵), 안쪽 문간(현관 쪽)
    hx0, hx1 = 3500, 3760
    hut = (140, 92, 58, 255)
    c.grad([(hx0, 300), (hx1, 300), (hx1, FLOOR_W), (hx0, FLOOR_W)], lite(hut, 0.12), dark(hut, 0.3), axis="x", cast=True)
    c.rect(hx0 - 10, 286, hx1 + 10, 304, lite(hut, 0.2))
    c.rect(hx0 + 14, 318, hx1 - 14, 560, dark(hut, 0.45), lw=1.6)  # 유리문 안
    for y in (400, 480, 560):
        c.rect(hx0 + 14, y - 8, hx1 - 14, y, lite(hut, 0.15), lw=1.2)
        for k in range(5):
            x = hx0 + 30 + k * 44
            if y == 400:
                c.ellipse(x, y - 70, x + 36, y - 10, (236, 232, 220, 255), lw=1.4)
                c.ellipse(x + 8, y - 60, x + 28, y - 20, (120, 150, 180, 255), lw=1.0)
            else:
                c.rrect(x + 4, y - 44, x + 30, y - 8, 4, (226, 220, 206, 255), lw=1.4)
    c.stroke([((hx0 + hx1) / 2, 318), ((hx0 + hx1) / 2, 560)], 2, hut)
    c.poly([(hx0 + 20, 320), (hx0 + 60, 320), (hx0 + 20, 400)], (255, 255, 255, 50), line=False)
    c.rect(hx0, 570, hx1, FLOOR_W, lite(hut, 0.05), lw=1.8)
    for y in (600, 680):
        c.rect(hx0 + 20, y, hx1 - 20, y + 60, None, lw=1.4)
        c.ellipse((hx0 + hx1) / 2 - 6, y + 24, (hx0 + hx1) / 2 + 6, y + 36, (210, 170, 90, 255), lw=1.0)
    c.rect(3800, 300, 3940, FLOOR_W, (64, 44, 36, 255))
    c.grad([(3800, 300), (3940, 300), (3940, FLOOR_W), (3800, FLOOR_W)], (90, 64, 50, 255), (40, 28, 24, 255), line=False)
    c.rect(3786, 286, 3954, 304, BEAM, cast=True)
    c.rect(3786, 300, 3804, FLOOR_W, BEAM, cast=True)
    c.rect(3936, 300, 3954, FLOOR_W, BEAM, cast=True)
    lm.add([(3800, 300), (3940, 300), (3940, FLOOR_W), (3800, FLOOR_W)], -0.3, 12)

    # ---------- 1-3 책장
    bx0, bx1 = 4000, 4290
    shelf = (130, 84, 52, 255)
    c.grad([(bx0, 300), (bx1, 300), (bx1, FLOOR_W), (bx0, FLOOR_W)], lite(shelf, 0.15), dark(shelf, 0.25), axis="x", cast=True)
    c.rect(bx0 + 14, 314, bx1 - 14, FLOOR_W - 12, dark(shelf, 0.5), line=False)
    for y in (420, 540, 660, FLOOR_W - 12):
        H.book_row(c, rng, bx0 + 18, bx1 - 20, y - 10, 70, 104)
        c.rect(bx0 + 10, y - 10, bx1 - 10, y, lite(shelf, 0.15), lw=1.6)
    c.rect(bx0 - 8, 290, bx1 + 8, 306, lite(shelf, 0.2))
    c.ellipse(bx0 + 30, 236, bx0 + 90, 290, (130, 160, 110, 255), cast=True)
    c.rect(bx0 + 40, 262, bx0 + 80, 292, (190, 110, 70, 255))
    lm.add([(bx0 + 14, 314), (bx1 - 14, 314), (bx1 - 14, FLOOR_W - 12), (bx0 + 14, FLOOR_W - 12)], -0.2, 10)
    H.frame(c, 4330, 330, 4430, 450, H.family_photo, wood=(120, 80, 50, 255))
    c.rect(4790, 360, 4830, 420, (200, 180, 140, 255), lw=1.4)  # 달력

    # ---------- 다락 계단(오른쪽 아래 5480 → 왼쪽 위 4920, 천장 구멍)
    st = (170, 116, 72, 255)
    n = 11
    foot_x, top_x = 5480.0, 4920.0
    c.rect(4880, CEIL_W - 10, 5150, CEIL_W + 44, (36, 26, 22, 255))
    for k in range(n):
        x = foot_x - (foot_x - top_x) * (k + 1) / n
        y = FLOOR_W - (FLOOR_W - CEIL_W - 30) * (k + 1) / n
        sx = (foot_x - top_x) / n
        c.grad([(x, y), (x + sx + 6, y), (x + sx + 6, y + 14), (x, y + 14)], lite(st, 0.3), lite(st, 0.1), cast=True)
        c.rect(x + 4, y + 14, x + sx + 2, y + (FLOOR_W - CEIL_W) / n, dark(st, 0.2), lw=1.4)
    c.grad([(foot_x + 40, FLOOR_W), (top_x - 10, CEIL_W + 20), (top_x + 40, CEIL_W + 20), (foot_x + 80, FLOOR_W)], st, dark(st, 0.2), axis="x", cast=True)
    for k in range(0, n, 2):
        t = (k + 0.5) / n
        x = foot_x + 60 + (top_x + 30 - foot_x - 60) * t
        yb = FLOOR_W + (CEIL_W + 20 - FLOOR_W) * t
        c.stroke([(x, yb - 20), (x, yb - 190)], 5, (140, 92, 58, 255))
    c.stroke([(foot_x + 70, FLOOR_W - 190), (top_x + 40, CEIL_W - 150)], 10, (120, 78, 48, 255))
    c.grad([(foot_x + 50, FLOOR_W - 230), (foot_x + 86, FLOOR_W - 230), (foot_x + 86, FLOOR_W), (foot_x + 50, FLOOR_W)], (150, 100, 64, 255), (100, 66, 42, 255), axis="x", cast=True)
    c.ellipse(foot_x + 44, FLOOR_W - 252, foot_x + 92, FLOOR_W - 222, (130, 86, 54, 255), cast=True)
    lm.add([(4880, CEIL_W - 20), (5150, CEIL_W - 20), (5300, 420), (4880, 420)], -0.3, 50)

    # ---------- 괘종시계(추는 따로 그린 그림이 흔들린다)
    gx = 5600
    case = (110, 70, 44, 255)
    c.grad([(gx, 360), (gx + 80, 360), (gx + 80, FLOOR_W), (gx, FLOOR_W)], lite(case, 0.2), dark(case, 0.3), axis="x", cast=True)
    c.rect(gx + 12, 470, gx + 68, 720, (60, 44, 34, 255), lw=1.6)  # 추 상자(어둡다)
    c.rect(gx + 12, 470, gx + 68, 720, (255, 250, 230, 30), line=False)
    c.poly([(gx - 8, 360), (gx + 88, 360), (gx + 70, 330), (gx + 10, 330)], case, cast=True)
    H.clock_face(c, gx + 40, 410, 28, case)

    # ---------- 복도: 외투걸이(할아버지 모자·외투), 창, 액자, 작은 탁자
    hx = 5820
    c.rect(hx - 70, 280, hx + 90, 296, (100, 66, 42, 255), cast=True)
    for dx in (-40, 20, 70):
        c.stroke([(hx + dx, 296), (hx + dx + 8, 316)], 4, (80, 56, 36, 255))
    coat = (96, 84, 72, 255)
    c.grad([(hx - 34, 300), (hx + 40, 300), (hx + 66, 600), (hx + 30, 640), (hx - 20, 630), (hx - 56, 590)], lite(coat, 0.15), dark(coat, 0.2), axis="x", cast=True)
    c.stroke([(hx + 4, 312), (hx + 2, 620)], 1.6, dark(coat, 0.3))
    for y in (380, 440, 500):
        c.ellipse(hx + 8, y, hx + 16, y + 8, (60, 50, 40, 255), line=False)
    hat = (150, 120, 80, 255)
    c.grad([(hx + 30, 330), (hx + 120, 330), (hx + 108, 322), (hx + 100, 290), (hx + 50, 290), (hx + 42, 322)], lite(hat, 0.15), dark(hat, 0.15), cast=True)  # 할아버지 모자
    c.rect(hx + 48, 312, hx + 102, 322, (90, 64, 44, 255), line=False)
    c.grad([(6260, 640), (6420, 640), (6420, 656), (6260, 656)], lite(WOOD, 0.2), WOOD, cast=True)
    c.rect(6270, 656, 6282, FLOOR_W, WOOD, cast=True)
    c.rect(6398, 656, 6410, FLOOR_W, WOOD, cast=True)
    c.ellipse(6300, 624, 6360, 644, (200, 180, 140, 255), lw=1.4)
    H.vase(c, 6390, 640, 50, (214, 226, 226, 255))
    for fx0, fy0, fw, fh in ((6260, 300, 90, 110), (6370, 330, 70, 80)):
        H.frame(c, fx0, fy0, fx0 + fw, fy0 + fh, H.landscape)


def _yard_back(c: Ink, rng, lm: LightMap):
    """마당 뒤: 낮은 돌담과 덤불(뒷벽과 같은 깊이)."""
    x0, x1 = YARD_X, WORLD_W
    stone = (176, 166, 150, 255)
    top = 600.0
    c.rect(x0, top, x1, FLOOR_W + 4, stone, line=False)
    y = top
    row = 0
    while y < FLOOR_W:
        h = rng.uniform(40, 56)
        x = x0 - (row % 2) * 50
        while x < x1:
            sw = rng.uniform(70, 140)
            col = mix(stone, rng.choice([(150, 140, 126, 255), (204, 194, 178, 255), (168, 160, 140, 255)]), rng.uniform(0.2, 0.8))
            pts = ink.round_rect_pts(x + 3, y + 3, x + sw - 3, min(FLOOR_W + 4, y + h) - 3, 12)
            c.grad(pts, lite(col, 0.18), dark(col, 0.2), lw=1.8)
            x += sw
        y += h
        row += 1
    c.grad([(x0 - 10, top - 26), (x1, top - 26), (x1, top + 4), (x0 - 10, top + 4)], (180, 170, 152, 255), (130, 120, 106, 255))
    # 담 위 덤불·꽃
    for _ in range(int((x1 - x0) / 22)):
        x = rng.uniform(x0, x1)
        r = rng.uniform(26, 50)
        col = rng.choice([(110, 124, 64, 255), (130, 140, 70, 255), (96, 110, 60, 255)])
        c.grad(ink.ellipse_pts(x - r, top - 26 - r * 1.3, x + r, top - 20 + r * 0.2), lite(col, 0.25), dark(col, 0.2), lw=1.6)
    for _ in range(int((x1 - x0) / 10)):
        x = rng.uniform(x0, x1)
        y = top - rng.uniform(30, 90)
        col = rng.choice([(222, 110, 80, 255), (246, 214, 120, 255), (244, 240, 230, 255), (200, 120, 170, 255)])
        c.ellipse(x - 5, y - 5, x + 5, y + 5, col, lw=1.0)
    lm.add([(x0, 0), (x1 + 40, 0), (x1 + 40, 1080), (x0, 1080)], 0.35, 30)


def wall_layer(width: float, mk, rng) -> tuple[Image.Image, Image.Image]:
    """뒷벽 층(Near, 깊이 0.8)과 벽에 비친 창빛 자리(dapple용, 같은 층 좌표의 알파)."""
    c = Ink(WORLD_W)
    lm = LightMap(WORLD_W, 0.66)
    _wall(c, rng, lm)
    _wall_things(c, rng, lm, mk)
    _yard_back(c, rng, lm)
    ink.drop_shadow(lm, c.casters, 26, 12, 12, 0.32)
    img = ink.light(c.finish(), lm.array(), SUN, SHADE)
    img = ink.rim_light(img, c.casters, -3, -3, (255, 226, 170), 0.5)
    noise = ink.plane_noise(img.width, img.height, 7, 160, 0.035)
    arr = np.asarray(img).astype(np.float32)
    arr[:, :, :3] *= noise[:, :, None]
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
    # 창빛 자리(움직이는 나뭇잎 그림자를 얹을 곳)
    glow = Image.new("L", (WORLD_W, 1080), 0)
    d = ImageDraw.Draw(glow)
    for wx0, wy0, wx1, wy1, _c in WINDOWS:
        dx = wx1 - wx0
        d.polygon([(wx1 + 60, wy0 + 130), (wx1 + 60 + dx * 0.75, wy0 + 210), (wx1 + 60 + dx * 0.75, wy1 + 150), (wx1 + 60, wy1 + 70)], fill=200)
        d.rectangle([wx0, wy0, wx1, wy1], fill=120)
    glow = glow.filter(ImageFilter.GaussianBlur(24))
    gimg = Image.new("RGBA", glow.size, (255, 255, 255, 0))
    gimg.putalpha(glow)
    w = pa.layer_width(width, "near")
    return ink.to_plane(img, WALL_S, w), ink.to_plane(gimg, WALL_S, w)


# ================================================================ 방 가운데 가구 (깊이 0.95)


def furniture_layer(width: float, mk, rng) -> tuple[Image.Image, Image.Image, int]:
    import house as H
    import house_objects as O
    c = Ink(WORLD_W)
    lm = LightMap(WORLD_W, 0.72)
    # 매단 등(천장에서)
    for lx in (2500, 3640, 4420, 6000):
        c.stroke([(lx, CEIL_W - 10), (lx, 200)], 2, (80, 60, 44, 255))
        c.grad([(lx - 46, 238), (lx + 46, 238), (lx + 18, 198), (lx - 18, 198)], (232, 186, 104, 255), (176, 120, 60, 255), cast=True)
        c.ellipse(lx - 12, 230, lx + 12, 248, (255, 244, 210, 255), lw=1.2)
    # 거실: 안락의자, 옆 탁자와 작은 스탠드, 털실 바구니
    O.armchair(c, 2300, FLOOR_W)
    O.side_table(c, 2560, FLOOR_W)
    lm.glow(2546, FLOOR_W - 300, 110, 80, 0.35, 40)
    O.yarn_basket(c, 2700, FLOOR_W)

    # 식탁(1-2) + 흰 백합 한 송이 + 의자 둘
    tx = 3640
    O.ladder_chair(c, tx - 230, FLOOR_W, facing=1)
    O.dining_table(c, tx, FLOOR_W)
    top = FLOOR_W - 175
    H.vase(c, tx + 40, top - 10, 56, (220, 234, 238, 255))
    c.stroke([(tx + 40, top - 60), (tx + 56, top - 120)], 2, (110, 140, 80, 255))
    H.lily(c, tx + 58, top - 124, 0.75)
    O.ell(c, tx - 70, top - 12, 32, 7, (236, 232, 222, 255), lw=1.4)
    O.ladder_chair(c, tx + 230, FLOOR_W, facing=-1)

    # 1-3 앨범 낮은 탁자와 앨범, 흔들의자, 쌓인 신문
    ax = mk("1-3", 4140.0) + 220
    c.grad([(ax - 116, 694), (ax + 116, 694), (ax + 116, 710), (ax - 116, 710)], lite(WOOD, 0.25), WOOD, cast=True)
    for lx in (ax - 100, ax + 86):
        c.rect(lx, 710, lx + 14, FLOOR_W, WOOD, cast=True)
    c.grad([(ax - 72, 694), (ax + 62, 694), (ax + 72, 676), (ax - 62, 676)], (140, 70, 52, 255), (110, 54, 42, 255), cast=True)
    c.poly([(ax - 66, 676), (ax + 58, 676), (ax + 62, 670), (ax - 62, 670)], (242, 232, 208, 255), lw=1.2)
    c.stroke([(ax + 30, 672), (ax + 40, 696)], 2, (200, 60, 60, 255))  # 책갈피 끈
    O.rocking_chair(c, 4640, FLOOR_W)
    O.newspapers(c, 4800, FLOOR_W)

    # 복도: 우산꽂이, 낮은 의자
    c.grad(ink.round_rect_pts(5940, 690, 5992, FLOOR_W, 8), (110, 136, 148, 255), (70, 90, 100, 255), axis="x", cast=True)
    c.stroke([(5956, 690), (5948, 590), (5936, 580)], 4, (40, 40, 50, 255))
    c.stroke([(5978, 690), (5990, 610)], 4, (150, 60, 50, 255))

    # 마당: 화분, 장작더미, 사과나무 줄기(잎 덩어리는 따로 살랑인다), 대문 뒤 기둥과 열린 문짝
    for px, col in ((6740, (220, 90, 70, 255)), (6810, (240, 200, 90, 255))):
        c.grad([(px - 28, 750), (px + 28, 750), (px + 22, FLOOR_W), (px - 22, FLOOR_W)], (196, 116, 76, 255), (150, 84, 54, 255), cast=True)
        for j in range(6):
            a = j / 6 * math.tau
            c.ellipse(px + math.cos(a) * 16 - 10, 730 + math.sin(a) * 10 - 10, px + math.cos(a) * 16 + 10, 730 + math.sin(a) * 10 + 10, col, lw=1.2)
    for k in range(9):
        lx = 6870 + (k % 3) * 44 + (k // 3) * 20
        ly = FLOOR_W - 42 - (k // 3) * 40
        c.grad(ink.ellipse_pts(lx, ly, lx + 44, ly + 40), (206, 166, 116, 255), (160, 120, 80, 255), lw=1.6, cast=True)
        c.ellipse(lx + 12, ly + 10, lx + 32, ly + 30, (150, 110, 70, 255), lw=1.0)
    tx = mk("1-6", 7110.0) - 120
    bark = (110, 78, 56, 255)
    c.grad([(tx - 36, FLOOR_W + 4), (tx - 20, 560), (tx - 64, 360), (tx - 30, 356), (tx + 4, 520), (tx + 44, 340),
            (tx + 76, 352), (tx + 26, 560), (tx + 38, FLOOR_W + 4)], (140, 104, 76, 255), (90, 62, 44, 255), axis="x", cast=True)
    for k in range(5):
        c.stroke([(tx - 18 + k * 9, 780), (tx - 12 + k * 7, 600)], 1.4, dark(bark, 0.3))
    for _ in range(5):
        ax2 = tx + rng.uniform(-200, 200)
        c.ellipse(ax2 - 11, FLOOR_W - 18, ax2 + 11, FLOOR_W + 2, (196, 44, 40, 255), lw=1.4)
    gx = 7220
    post = (120, 84, 56, 255)
    c.grad([(gx - 140, 520), (gx - 104, 520), (gx - 104, FLOOR_W + 6), (gx - 140, FLOOR_W + 6)], lite(post, 0.2), dark(post, 0.25), axis="x", cast=True)
    c.poly([(gx - 148, 520), (gx - 96, 520), (gx - 122, 494)], dark(post, 0.1), cast=True)
    gate = (164, 120, 78, 255)
    c.grad([(gx - 104, 590), (gx + 10, 560), (gx + 10, 790), (gx - 104, FLOOR_W)], lite(gate, 0.15), dark(gate, 0.2), axis="x", cast=True)  # 안쪽으로 열린 문짝
    for k in range(1, 4):
        t = k / 4
        c.stroke([(gx - 104 + 114 * t, 590 - 30 * t), (gx - 104 + 114 * t, FLOOR_W - 20 * t)], 1.6, dark(gate, 0.3))
    c.stroke([(gx - 104, 690), (gx + 10, 670)], 6, dark(gate, 0.15))

    ink.drop_shadow(lm, c.casters, 18, 8, 10, 0.22)
    img = ink.light(c.finish(), lm.array(), SUN, SHADE)
    img = ink.rim_light(img, c.casters, -3, -3, (255, 226, 170), 0.55)
    w = int(math.ceil((1920 + (width - 1920) * FURN_S) / 8) * 8) + 16
    canopy = _apple_canopy(rng, tx)
    return ink.to_plane(img, FURN_S, w), canopy, w


def _apple_canopy(rng, tx) -> Image.Image:
    """사과나무 잎 덩어리(따로 그려 살랑이게). 세계 크기, 둘레 여백."""
    import house_objects as O
    W, Hh = 700, 420
    c = Ink(W, Hh)
    O.apple_tree_canopy(c, rng, W / 2, 230, 270, 150, 16)
    return c.finish()


# ================================================================ 바닥·천장 (평면 좌표)


def floor_texture(mk, rng) -> tuple[Image.Image, Image.Image]:
    """바닥 그림: 가로 = p(P0 ~ P0+P_W), 세로 = 화면 줄 y 690 ~ 1080(깊이 0.8 ~ 1.45)."""
    y0, y1 = 690, 1080
    rows = y1 - y0
    c = Ink(P_W, rows)
    X = lambda p: p - P0  # noqa: E731
    Y = lambda s: floor_y(s) - y0  # noqa: E731
    # 마루: 판자가 화면 안쪽으로 뻗는다(같은 p = 소실점으로 모이는 선)
    x = X(ROOM_X0)
    while x < X(YARD_X):
        w = 92
        col = mix(FLOORC, dark(FLOORC, 0.14) if rng.random() < 0.5 else lite(FLOORC, 0.1), rng.uniform(0.15, 0.85))
        c.rect(x, 0, min(x + w, X(YARD_X)), rows, col, line=False)
        c.grain(rng, x, 0, x + w, rows, alpha(dark(col, 0.3), 60), 3, vertical=True)
        c.stroke([(x, 0), (x, rows)], 1.4, dark(FLOORC, 0.45))
        # 판자 끝 이음(깊이를 고르게: 1/s로)
        inv = rng.uniform(0.69, 1.25)
        while inv > 0.69:
            s = 1.0 / inv
            c.stroke([(x + 1, Y(s)), (x + w - 1, Y(s))], 1.2, dark(FLOORC, 0.4))
            inv -= rng.uniform(0.18, 0.34)
        x += w
    # 러그(원근으로 놓인 네모)
    def rug(pa_, pb, sa, sb, col, edge, n):
        c.poly([(X(pa_), Y(sa)), (X(pb), Y(sa)), (X(pb), Y(sb)), (X(pa_), Y(sb))], col, lw=1.6)
        c.poly([(X(pa_) + 18, Y(sa) + 6), (X(pb) - 18, Y(sa) + 6), (X(pb) - 18, Y(sb) - 8), (X(pa_) + 18, Y(sb) - 8)], None, lw=2.2, lc=edge)
        for k in range(1, n):
            xx = X(pa_) + (X(pb) - X(pa_)) * k / n
            c.stroke([(xx, Y(sa) + 4), (xx, Y(sb) - 4)], 1.4, dark(col, 0.18))
        for xx in np.arange(X(pa_), X(pb), 12):
            c.stroke([(xx, Y(sb)), (xx - 1, Y(sb) + 10)], 1.2, (226, 200, 156, 255))
    rug(2060, 2780, 0.9, 1.18, (166, 64, 54, 255), (226, 176, 104, 255), 9)
    rug(3420, 3880, 0.9, 1.08, (120, 84, 66, 255), (210, 176, 120, 255), 6)
    rug(4180, 4780, 0.88, 1.12, (74, 92, 120, 255), (206, 176, 120, 255), 8)
    # 현관 쪽 깔개와 검은 구두 줄(1-2, 조문객) — 안쪽 문간 앞, 벽 가까이
    c.poly([(X(3760), Y(0.82)), (X(4020), Y(0.82)), (X(4020), Y(0.9)), (X(3760), Y(0.9))], (120, 100, 80, 255), lw=1.4)
    for k in range(5):
        sx = X(3772 + k * 50)
        yb = Y(0.87)
        c.poly([(sx, yb), (sx + 3, yb - 14), (sx + 16, yb - 18), (sx + 28, yb - 12), (sx + 42, yb - 7), (sx + 44, yb)], (36, 32, 36, 255), lw=1.2)
        c.stroke([(sx + 6, yb - 13), (sx + 18, yb - 15)], 1.6, (150, 150, 160, 255))
    # 문턱 돌(현관 → 마당)
    c.poly([(X(YARD_X) - 20, 0), (X(YARD_X) + 40, 0), (X(YARD_X) + 40, rows), (X(YARD_X) - 20, rows)], (170, 160, 150, 255), lw=1.6)
    # 마당 흙: 길은 하윤 줄(깊이 1) 둘레, 앞·뒤는 풀
    dirt = (196, 160, 112, 255)
    c.rect(X(YARD_X) + 40, 0, P_W, rows, dirt, line=False)
    for _ in range(3000):
        p = rng.uniform(YARD_X + 40, P0 + P_W)
        s = 1.0 / rng.uniform(0.69, 1.25)
        ln = rng.uniform(20, 80)
        c.stroke([(X(p), Y(s)), (X(p + ln), Y(s))], 1.0, alpha(dark(dirt, 0.25), 80))
    for k in range(10):  # 디딤돌
        p = YARD_X + 80 + k * 150 + rng.uniform(-10, 10)
        sa, sb = 0.97 + (k % 2) * 0.05, 1.03 + (k % 2) * 0.05
        c.grad(ink.ellipse_pts(X(p), Y(sa), X(p + 110), Y(sb)), (214, 208, 196, 255), (160, 154, 144, 255), lw=1.6)
    for band in ((0.8, 0.9), (1.2, 1.45)):  # 풀 띠
        for _ in range(1400):
            p = rng.uniform(YARD_X + 40, P0 + P_W)
            s = rng.uniform(*band)
            col = rng.choice([(120, 130, 60, 255), (150, 150, 70, 255), (100, 110, 54, 255)])
            hh = rng.uniform(6, 16)
            c.stroke([(X(p), Y(s)), (X(p) + rng.uniform(-3, 3), Y(s) - hh)], 1.4, col)
    for _ in range(900):  # 낙엽
        p = rng.uniform(YARD_X + 40, P0 + P_W)
        s = 1.0 / rng.uniform(0.69, 1.25)
        col = rng.choice([(214, 110, 50, 255), (232, 170, 70, 255), (186, 70, 46, 255), (200, 60, 50, 255)])
        a = rng.uniform(0, math.tau)
        r = rng.uniform(5, 9)
        x, y = X(p), Y(s)
        c.poly([(x + math.cos(a) * r, y + math.sin(a) * r * 0.45), (x + math.cos(a + 2.2) * r * 0.7, y + math.sin(a + 2.2) * r * 0.3),
                (x + math.cos(a + 4.1) * r * 0.7, y + math.sin(a + 4.1) * r * 0.3)], col, lw=0.8)

    # 빛·그늘
    lm = LightMap(P_W, 0.8, rows)
    lm.add([(0, -20), (P_W, -20), (P_W, 30), (0, 30)], -0.25, 20)    # 벽 밑 구석(AO)
    lm.add([(0, rows - 120), (P_W, rows - 120), (P_W, rows + 40), (0, rows + 40)], -0.25, 60)  # 화면 앞은 어둑
    # 가구 그림자(가구는 깊이 0.95, 벽 가구는 0.8): 빛 반대쪽(오른쪽 앞)으로
    for pa_, pb, s in ((2120, 2480, 0.95), (3470, 3810, 0.95), (4320, 4420, 0.95), (4560, 4740, 0.95), (2520, 2620, 0.95),
                       (2590, 2830, 0.8), (3050, 3470, 0.8), (3500, 3760, 0.8), (4000, 4290, 0.8), (4880, 5560, 0.8), (5600, 5680, 0.8),
                       (6260, 6420, 0.8), (6840, 7000, 0.95), (7000, 7300, 0.95)):
        lm.add([(X(pa_ + 10), Y(s) - 4), (X(pb + 10), Y(s) - 4), (X(pb + 90), Y(s) + 26), (X(pa_ + 60), Y(s) + 26)], -0.4, 10)
    tree = mk("1-6", 7110.0) - 120
    lm.add(ink.ellipse_pts(X(tree - 260), Y(0.92), X(tree + 320), Y(1.12)), -0.35, 20)
    lm.add([(X(YARD_X), 0), (P_W, 0), (P_W, rows), (X(YARD_X), rows)], 0.25, 20)
    # 창빛 웅덩이: 창을 지나 오른쪽 앞으로 늘어진 창 모양(창살 그림자까지)
    glow = Image.new("L", (P_W // 4, max(1, rows // 4)), 0)
    gd = ImageDraw.Draw(glow)
    for wx0, wy0, wx1, wy1, _c in WINDOWS:
        cols = 3 if wx1 - wx0 > 300 else 2
        for col_i in range(cols):
            for row_i in range(2):
                pa_ = wx0 + (wx1 - wx0) * col_i / cols + 10
                pb = wx0 + (wx1 - wx0) * (col_i + 1) / cols - 10
                sa = 0.98 + row_i * 0.14
                sb = sa + 0.12
                off_a, off_b = 220 + (sa - 0.9) * 600, 220 + (sb - 0.9) * 600
                quad = [(X(pa_ + off_a), Y(sa)), (X(pb + off_a), Y(sa)), (X(pb + off_b), Y(sb)), (X(pa_ + off_b), Y(sb))]
                lm.add(quad, 0.55, 5)
                gd.polygon([(x / 4, y / 4) for x, y in quad], fill=255)
    door_pool = [(X(YARD_X - 380), Y(0.95)), (X(YARD_X), Y(0.95)), (X(YARD_X), Y(1.4)), (X(YARD_X - 520), Y(1.4))]
    lm.add(door_pool, 0.35, 30)
    img = ink.light(c.finish(), lm.array(), SUN, SHADE)
    noise = ink.plane_noise(img.width, img.height, 11, 90, 0.03)
    arr = np.asarray(img).astype(np.float32)
    arr[:, :, :3] *= noise[:, :, None]
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
    glow = glow.filter(ImageFilter.GaussianBlur(2))
    gimg = Image.new("RGBA", glow.size, (255, 255, 255, 0))
    gimg.putalpha(glow)
    return img, gimg


def ceiling_texture(rng) -> Image.Image:
    """천장 그림: 가로 = p, 세로 = 화면 줄 0 ~ 120(깊이 1.87 ~ 0.8). 판자와 보는 벽과 나란히 놓여
    깊이마다 한 줄씩(가까울수록 간격이 넓다) — 화면 안쪽으로 뻗은 선은 너무 급하게 기울어 어지러웠다. 마당 위는 비운다."""
    rows = 120
    c = Ink(P_W, rows)
    X = lambda p: p - P0  # noqa: E731
    Y = lambda s: VP_Y - CEIL_K * s  # noqa: E731
    x0, x1 = X(ROOM_X0), X(YARD_X)
    board = (150, 104, 68, 255)
    c.grad([(x0, 0), (x1, 0), (x1, rows), (x0, rows)], dark(board, 0.3), board, line=False)
    inv = 1.0 / 0.8
    k = 0
    while inv > 1.0 / 1.9:
        s = 1.0 / inv
        y = Y(s)
        if k % 5 == 4:  # 굵은 보(아래 면이 보인다)
            c.grad([(x0, y - 9 * s), (x1, y - 9 * s), (x1, y + 4), (x0, y + 4)], (120, 80, 52, 255), (78, 50, 32, 255), lw=1.4)
        else:
            c.stroke([(x0, y), (x1, y)], 1.2, dark(board, 0.45))
        inv -= 0.075
        k += 1
    lm = LightMap(P_W, 0.62, rows)
    for wx0, wy0, wx1, wy1, _c in WINDOWS:
        lm.glow(X((wx0 + wx1) / 2 + 200), 110, 420, 40, 0.25)
    return ink.light(c.finish(), lm.array(), SUN, SHADE)


def endwall_texture(door: bool, rng) -> Image.Image:
    """옆벽 그림(PerspectivePlane): 가로 = 깊이 0.8 → 1.45(1/s로 고르게), 세로 = 천장(0) → 바닥(1).
    door면 깊이 0.92 ~ 1.08에 열린 문(구멍)이 있다(현관 → 마당)."""
    W, Hh = 640, 712
    c = Ink(W, Hh)
    t = lambda s: (1.25 - 1.0 / s) / (1.25 - 1.0 / 1.45) * W  # noqa: E731
    v = lambda h: Hh - h  # 바닥에서 높이 h(세계 px) → 세로 자리  # noqa: E731
    c.grad([(0, 0), (W, 0), (W, v(232)), (0, v(232))], dark(PLASTER, 0.42), dark(PLASTER, 0.22), axis="x", line=False)
    c.rect(0, 0, W, 34, BEAM, line=False)
    c.rect(0, v(232), W, v(30), dark(WAINSCOT, 0.3), line=False)
    for k in range(1, 8):
        xx = W * k / 8
        c.stroke([(xx, v(232)), (xx, v(30))], 1.4, dark(WAINSCOT, 0.4))
    c.rect(0, v(250), W, v(232), WAINSCOT, line=False)
    c.rect(0, v(30), W, Hh, dark(WAINSCOT, 0.4), line=False)
    if door:
        a, b = t(0.92), t(1.08)
        c.rect(a - 22, v(560), b + 22, Hh, BEAM)
        c.erase([(a, v(540)), (b, v(540)), (b, Hh + 4), (a, Hh + 4)], keep=0)
        c.stroke([(a, v(540)), (b, v(540))], 2.4)
    return c.finish()


# ================================================================ 움직이는 조각


def curtain(col, h, flip: bool) -> Image.Image:
    """커튼 한 폭(여백 24px). 위가 고정, 아래가 살랑인다."""
    W, Hh = 130, int(h) + 40
    c = Ink(W, Hh)
    x0, x1 = 24, W - 24
    pts = [(x0, 4), (x1, 4), (x1 - 6, Hh * 0.45), (x1 + 2, Hh - 30), (x1 - 30, Hh - 10), (x0 + 6, Hh - 20), (x0 + 14, Hh * 0.5)]
    c.grad(pts, lite(col, 0.25), dark(col, 0.25), axis="x")
    for k in (0.3, 0.55, 0.8):
        xx = x0 + (x1 - x0) * k
        c.stroke([(xx, 10), (xx + 4, Hh - 24)], 1.6, dark(col, 0.35))
        c.stroke([(xx - 8, 14), (xx - 5, Hh - 30)], 3, alpha(lite(col, 0.4), 120))
    c.rrect(x0 - 4, Hh * 0.5 - 8, x1 + 4, Hh * 0.5 + 8, 6, dark(col, 0.2), lw=1.4)  # 커튼 끈
    img = c.finish()
    return img.transpose(Image.FLIP_LEFT_RIGHT) if flip else img


def pendulum(length: float, bob: float, rod=(190, 150, 70, 255), weight=(214, 170, 80, 255)) -> Image.Image:
    """추(매달린 자리가 위 가운데). 세계 크기."""
    W, Hh = int(bob * 2 + 16), int(length + bob + 16)
    c = Ink(W, Hh)
    cx = W / 2
    c.stroke([(cx, 4), (cx, length)], 2.4, rod)
    c.grad(ink.ellipse_pts(cx - bob, length - bob, cx + bob, length + bob), lite(weight, 0.35), dark(weight, 0.2), lw=1.6)
    c.ellipse(cx - bob * 0.5, length - bob * 0.6, cx - bob * 0.1, length - bob * 0.2, (255, 240, 200, 255), line=False)
    return c.finish()


def flame() -> tuple[Image.Image, Image.Image]:
    """촛불 불꽃과 둘레 빛(빛은 더하기로 얹는다)."""
    c = Ink(24, 40)
    c.poly([(12, 2), (19, 20), (16, 32), (12, 36), (8, 32), (5, 20)], (255, 216, 120, 255), lw=1.0, lc=(230, 140, 60, 255))
    c.poly([(12, 16), (15, 26), (12, 33), (9, 26)], (255, 250, 220, 255), line=False)
    g = Image.new("L", (160, 160), 0)
    ImageDraw.Draw(g).ellipse((40, 40, 120, 120), fill=200)
    g = g.filter(ImageFilter.GaussianBlur(22))
    glow = Image.new("RGBA", g.size, (255, 190, 110, 0))
    glow.putalpha(g)
    return c.finish(), glow


# ================================================================ 맨 앞 (깊이 1.25)


def front_world(width: float, mk, rng) -> Image.Image:
    """맨 앞 층에 얹을 것(세계 크기로 그려 1.25배): 천장 앞 보, 낮은 화분·바구니, 사과나무 가지."""
    c = Ink(WORLD_W)
    import house_objects as O
    for px in (2700, 4300, 5880):  # 큰 화분(화면 아래 가장자리에서 잎이 올라온다)
        O.potted_plant(c, px, FLOOR_W + 60, rng, 1.0)
    # 마당 사과나무 가지(위에서 늘어진다)
    ax = mk("1-6", 7110.0) + 40
    c.stroke([(ax - 420, -20), (ax - 160, 40), (ax + 160, 20)], 18, (90, 64, 46, 255))
    blobs = [(ax - 360 + k * 70 + rng.uniform(-20, 20), 50 + rng.uniform(-20, 40), rng.uniform(36, 56)) for k in range(10)]
    O.leaf_mass(c, rng, blobs, [(176, 154, 72, 255), (226, 198, 104, 255), (108, 98, 54, 255)])
    for _ in range(5):
        bx, by = ax - 300 + rng.uniform(0, 460), rng.uniform(70, 120)
        c.grad(ink.ellipse_pts(bx - 11, by - 11, bx + 11, by + 11), (232, 70, 60, 255), (160, 28, 32, 255), lw=1.4)
    img = c.finish()
    lm = LightMap(WORLD_W, 0.55)
    img = ink.light(img, lm.array(), SUN, SHADE)
    return img
