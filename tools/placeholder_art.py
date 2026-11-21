#!/usr/bin/env python3
"""코드로 그리는 임시 배경. 진짜 그림이 오기 전까지 회색 네모 대신 쓴다.

    python3 tools/placeholder_art.py field        # 장소 하나
    python3 tools/placeholder_art.py --all        # 그릴 수 있는 장소 전부
    python3 tools/placeholder_art.py prop         # 움직이는 소품(접힌 지도 등)

결과: assets/art/placeholder/<place_id>/bg_<place_id>_<layer>[_NN].png
그다음 그림 가져오기 도구로 장소 씬에 넣는다:
    godot --headless --path . --import
    godot --headless --path . --script res://tools/art_import.gd

진짜 그림이 오면 assets/art/placeholder/<place_id>/ 를 지우고 도구를 다시 돌린다
(같은 이름이 두 곳에 있으면 도구가 "번호가 겹친다"로 막는다).

필요한 것: pip install pillow numpy
색은 docs/design.md "아트 방향" 표, 물건은 docs/story.md 장면표를 따른다.
같은 장소는 늘 같은 그림이 나온다(난수 씨앗 고정).
"""

from __future__ import annotations

import argparse
import math
import random
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets/art/placeholder"

H = 1080
SCREEN_W = 1920
GROUND_Y = 810
MAX_TILE_W = 8192
SS = 2  # 2배로 그려 줄여서 가장자리를 부드럽게
SCROLL = {"sky": 0.1, "far": 0.3, "mid": 0.6, "ground": 1.0, "props": 1.0, "front": 1.25}

Color = tuple[int, int, int, int]


def rgba(r: int, g: int, b: int, a: int = 255) -> Color:
    return (r, g, b, a)


# ---------------------------------------------------------------- 장소 정보


def read_place(place_id: str) -> tuple[float, dict[str, float]]:
    """장소 씬에서 폭과 장면 표시 x를 읽는다."""
    text = (ROOT / f"scenes/places/{place_id}.tscn").read_text(encoding="utf-8")
    m = re.search(r"^width = ([\d.]+)", text, re.MULTILINE)
    width = float(m.group(1)) if m else float(SCREEN_W)
    markers = {}
    for name, x in re.findall(
        r'\[node name="([\d-]+)" type="Marker2D" parent="Markers"[^\]]*\]\s*position = Vector2\(([-\d.]+),',
        text,
    ):
        markers[name] = float(x)
    return width, markers


def layer_width(width: float, layer: str) -> int:
    need = SCREEN_W + max(width - SCREEN_W, 0) * SCROLL[layer]
    return int(math.ceil(need / 8.0) * 8) + 16  # 끝이 딱 맞으면 반올림으로 1px 빌 수 있어 조금 여유


# ---------------------------------------------------------------- 그리기 바탕
#
# 층마다 "도형 목록"을 층 좌표(1x)로 만든 뒤, 조각(tile)마다 2x로 그려 줄인다.
# 도형: ("poly", 점들, 색) / ("line", 점들, 색, 굵기) / ("ellipse", (x0,y0,x1,y1), 색)


class Layer:
    def __init__(self, width: int, background: Image.Image | None = None):
        self.width = width
        self.shapes: list[tuple] = []
        self.background = background  # 1x, 층 전체 폭 (하늘처럼 픽셀로 만든 바탕)
        self.blur_groups: list[tuple[list[tuple], float]] = []  # (도형들, 흐림 반지름) 도형 아래
        self.haze_groups: list[tuple[list[tuple], float]] = []  # 도형 위

    def rect(self, x0, y0, x1, y1, color):
        self.poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], color)

    def haze(self, shapes: list[tuple], radius: float) -> None:
        if shapes:
            self.haze_groups.append((shapes, radius))

    def under(self, shapes: list[tuple], radius: float) -> None:
        if shapes:
            self.blur_groups.append((shapes, radius))

    def poly(self, pts, color):
        self.shapes.append(("poly", pts, color))

    def line(self, pts, color, width):
        self.shapes.append(("line", pts, color, width))

    def ellipse(self, box, color):
        self.shapes.append(("ellipse", box, color))

    def render(self) -> list[Image.Image]:
        n = math.ceil(self.width / MAX_TILE_W)
        tile_w = math.ceil(self.width / n)
        tiles = []
        for i in range(n):
            x0 = i * tile_w
            w = min(tile_w, self.width - x0)
            tiles.append(self._render_tile(x0, w))
        return tiles

    def _draw(self, img: Image.Image, shapes, x0: int) -> None:
        d = ImageDraw.Draw(img, "RGBA")

        def tr(pts):
            return [((x - x0) * SS, y * SS) for x, y in pts]

        for s in shapes:
            kind = s[0]
            if kind == "poly":
                xs = [p[0] for p in s[1]]
                if max(xs) < x0 - 50 or min(xs) > x0 + img.width / SS + 50:
                    continue
                d.polygon(tr(s[1]), fill=s[2])
            elif kind == "line":
                xs = [p[0] for p in s[1]]
                if max(xs) < x0 - 50 or min(xs) > x0 + img.width / SS + 50:
                    continue
                d.line(tr(s[1]), fill=s[2], width=max(1, round(s[3] * SS)), joint="curve")
            elif kind == "ellipse":
                bx0, by0, bx1, by1 = s[1]
                if bx1 < x0 - 50 or bx0 > x0 + img.width / SS + 50:
                    continue
                d.ellipse(((bx0 - x0) * SS, by0 * SS, (bx1 - x0) * SS, by1 * SS), fill=s[2])

    def _soft(self, big: Image.Image, shapes, radius: float, x0: int) -> Image.Image:
        # 투명한 곳(검정)이 섞여 번지지 않게, 모양(알파)만 흐리고 색은 한 가지로 칠한다.
        color = shapes[0][2]
        mask = Image.new("RGBA", big.size, (0, 0, 0, 0))
        self._draw(mask, [(s[0], s[1], (255, 255, 255, s[2][3])) + s[3:] for s in shapes], x0)
        alpha = mask.getchannel("A").filter(ImageFilter.GaussianBlur(radius * SS))
        soft = Image.new("RGBA", big.size, color[:3] + (0,))
        soft.putalpha(alpha)
        return Image.alpha_composite(big, soft)

    def _render_tile(self, x0: int, w: int) -> Image.Image:
        big = Image.new("RGBA", (w * SS, H * SS), (0, 0, 0, 0))
        for shapes, radius in self.blur_groups:
            big = self._soft(big, shapes, radius, x0)
        self._draw(big, self.shapes, x0)
        for shapes, radius in self.haze_groups:  # 안개·빛줄기: 도형 위에 얹는다
            big = self._soft(big, shapes, radius, x0)
        tile = big.resize((w, H), Image.LANCZOS)
        if self.background is not None:
            bg = self.background.crop((x0, 0, x0 + w, H))
            tile = Image.alpha_composite(bg, tile)
        return tile


def vertical_gradient(width: int, stops: list[tuple[float, tuple[int, int, int]]]) -> Image.Image:
    """세로 그라데이션. 무손실 PNG로 저장하므로 압축 색 띠는 없다."""
    ys = np.linspace(0.0, 1.0, H)
    cols = np.zeros((H, 3))
    for c in range(3):
        cols[:, c] = np.interp(ys, [s[0] for s in stops], [s[1][c] for s in stops])
    img = np.repeat(cols[:, None, :], width, axis=1)
    arr = np.clip(np.round(img), 0, 255).astype(np.uint8)
    alpha = np.full((H, width, 1), 255, np.uint8)
    return Image.fromarray(np.concatenate([arr, alpha], axis=2), "RGBA")


def add_glow(img: Image.Image, cx: float, cy: float, radius: float, color: tuple[int, int, int], strength: float) -> None:
    """해 둘레의 번진 빛. img를 직접 바꾼다."""
    arr = np.asarray(img).astype(np.float64)
    yy, xx = np.mgrid[0:img.height, 0:img.width]
    dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / radius
    a = np.clip(1.0 - dist, 0.0, 1.0) ** 2.2 * strength
    for c in range(3):
        arr[:, :, c] = arr[:, :, c] * (1 - a) + color[c] * a
    img.paste(Image.fromarray(np.clip(np.round(arr), 0, 255).astype(np.uint8), "RGBA"))


def ridge(rng: random.Random, width: int, base: float, amp: float, step: int = 24, waves: int = 4) -> list[tuple[float, float]]:
    """여러 사인파를 겹친 능선. 아래(H)까지 닫힌 다각형 점들."""
    comps = [(rng.uniform(0.6, 1.0) / (k + 1), rng.uniform(1.0, 2.2) * (k + 1), rng.uniform(0, math.tau)) for k in range(waves)]
    pts = [(-20.0, float(H))]
    for x in range(-20, width + 40, step):
        t = x / 1920.0
        y = base - amp * sum(a * math.sin(f * t * math.tau / 2 + p) for a, f, p in comps)
        pts.append((float(x), y))
    pts.append((float(width + 40), float(H)))
    return pts


def lerp_color(a: Color, b: Color, t: float) -> Color:
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(4))  # type: ignore[return-value]


# ---------------------------------------------------------------- 억새 들판
# 해 기우는 오후. 은빛·금빛 억새, 옅은 하늘색. 해는 오른쪽 낮게, 그림자는 왼쪽으로 길다.

# 2-3 지도가 걸리는 억새 덤불(땅 x). field.tscn MapChase_2-3의 position.x + stops와 같아야 한다(스모크 검사가 본다).
FIELD_SNAGS = [5000, 5900, 6800]


def field(width: float, markers: dict[str, float]) -> dict[str, Layer]:
    rng = random.Random("field")
    layers: dict[str, Layer] = {}

    # 하늘: 위는 옅은 하늘색, 지평선은 바랜 금빛. 해는 오른쪽 낮게.
    w = layer_width(width, "sky")
    sky = vertical_gradient(w, [
        (0.0, (122, 162, 204)), (0.35, (168, 196, 220)),
        (0.58, (226, 214, 184)), (0.70, (240, 206, 150)), (1.0, (236, 196, 140)),
    ])
    add_glow(sky, w * 0.82, 600, 900, (255, 222, 160), 0.55)
    add_glow(sky, w * 0.82, 600, 160, (255, 240, 205), 0.8)
    layers["sky"] = L = Layer(w, sky)
    L.ellipse((w * 0.82 - 34, 566, w * 0.82 + 34, 634), rgba(255, 246, 222))
    clouds: list[tuple] = []
    for _ in range(9):
        cx, cy = rng.uniform(0, w), rng.uniform(170, 470)
        cw, ch = rng.uniform(260, 700), rng.uniform(14, 34)
        clouds.append(("ellipse", (cx - cw / 2, cy - ch / 2, cx + cw / 2, cy + ch / 2), rgba(255, 240, 226, 120)))
    L.blur_groups.append((clouds, 10))

    # 먼 산: 두 겹. 멀수록 하늘색에 묻힌다.
    w = layer_width(width, "far")
    layers["far"] = L = Layer(w)
    L.poly(ridge(rng, w, 560, 70), rgba(160, 172, 190))
    L.poly(ridge(rng, w, 615, 55), rgba(132, 142, 160))

    # 중간: 완만한 언덕, 나무 덩어리, 멀리까지 이어진 전봇대 줄(2-1).
    w = layer_width(width, "mid")
    layers["mid"] = L = Layer(w)
    hill = ridge(rng, w, 672, 34, waves=3)
    L.poly(hill, rgba(168, 150, 98))

    def hill_y(x: float) -> float:
        for (xa, ya), (xb, yb) in zip(hill[1:-2], hill[2:-1]):
            if xa <= x <= xb:
                return ya + (yb - ya) * (x - xa) / (xb - xa)
        return 672.0

    x = rng.uniform(100, 400)
    while x < w:
        y = hill_y(x)
        for _ in range(rng.randint(2, 4)):
            r = rng.uniform(26, 48)
            ox = rng.uniform(-40, 40)
            L.ellipse((x + ox - r, y - r * 1.5, x + ox + r, y + r * 0.4), rgba(112, 108, 72))
        x += rng.uniform(500, 1400)
    tops = []
    for x in range(160, w, 300):
        y = hill_y(x) + 4
        L.line([(x, y), (x, y - 92)], rgba(96, 88, 70), 3)
        L.line([(x - 10, y - 84), (x + 10, y - 84)], rgba(96, 88, 70), 2)
        tops.append((x, y - 84))
    for (xa, ya), (xb, yb) in zip(tops, tops[1:]):
        L.line(sag(xa, ya, xb, yb, 10), rgba(96, 88, 70, 170), 1.2)

    # 땅: 하윤 뒤의 억새밭 + 흙길. 하윤 발은 y = 810, 흙길 위.
    w = layer_width(width, "ground")
    layers["ground"] = L = Layer(w)
    L.poly(ridge(rng, w, 728, 10, step=40), rgba(200, 172, 108))  # 억새밭 바탕
    L.poly([(-20, 792), (w + 20, 792), (w + 20, H), (-20, H)], rgba(150, 126, 86))  # 길 아래 흙
    path_top = [(float(x), 792 + rng.uniform(-3, 3)) for x in range(-20, w + 40, 60)]
    path_bot = [(float(x), 872 + rng.uniform(-6, 6)) for x in range(w + 40, -40, -60)]
    L.poly(path_top + path_bot, rgba(186, 158, 118))  # 흙길
    L.poly([(-20, 872), (w + 20, 872), (w + 20, H), (-20, H)], rgba(170, 142, 92))  # 길 앞 풀
    # 억새밭 결: 위로 뻗은 획, 오른쪽(해 쪽) 끝이 밝다
    for _ in range(int(w / 9)):
        x = rng.uniform(0, w)
        y0 = rng.uniform(745, 795)
        h = rng.uniform(18, 60)
        lean = rng.uniform(-14, -4)
        c = lerp_color(rgba(176, 148, 92), rgba(236, 214, 160), rng.random())
        L.line([(x, y0), (x + lean, y0 - h)], c, rng.uniform(1.2, 2.4))
    for _ in range(int(w / 30)):  # 길 앞 풀
        x = rng.uniform(0, w)
        y0 = rng.uniform(880, 1080)
        L.line([(x, y0), (x - rng.uniform(4, 12), y0 - rng.uniform(10, 26))], rgba(150, 124, 78), 2)
    for _ in range(int(w / 40)):  # 흙길 자국
        x = rng.uniform(0, w)
        y = rng.uniform(800, 866)
        L.line([(x, y), (x + rng.uniform(20, 70), y + rng.uniform(-1, 1))], rgba(168, 140, 102, 140), 2)

    # 하윤 뒤 물건: 전봇대(그림자는 왼쪽으로 길게), 버스 정류장(2-5, 3시 17분에 멈춘 시계).
    w = layer_width(width, "props")
    layers["props"] = L = Layer(w)
    stop_x = markers.get("2-5", width * 0.8)
    pole_xs = [x for x in range(700, w, 1450) if abs(x - stop_x) > 500]
    shadows: list[tuple] = []
    tops = []
    for x in pole_xs:
        base = 792
        shadows.append(("poly", [(x - 9, base), (x + 9, base), (x - 470, base + 34), (x - 500, base + 34)], rgba(70, 50, 30, 110)))
        L.poly([(x - 9, base), (x + 9, base), (x + 6, base - 560), (x - 6, base - 560)], rgba(92, 78, 62))
        L.poly([(x + 2, base), (x + 9, base), (x + 6, base - 560), (x + 2, base - 560)], rgba(150, 120, 86))  # 해 쪽 면
        L.line([(x - 46, base - 520), (x + 46, base - 520)], rgba(80, 68, 54), 7)
        tops.append((x, base - 520))
    for (xa, ya), (xb, yb) in zip(tops, tops[1:]):
        for dx in (-40, 40):
            L.line(sag(xa + dx, ya, xb + dx, yb, 46), rgba(70, 60, 50, 200), 2)
    L.blur_groups.append((shadows, 3))
    bus_stop(L, stop_x, 792, shadows)
    # 2-3 날아간 지도가 걸리는 억새 덤불 셋(하윤 뒤). 자리는 MapChase_2-3의 stops와 같다.
    snag_rng = random.Random("field_snags")
    for x in FIELD_SNAGS:
        reed_clump(L, snag_rng, x, 0.62, base=800)

    # 앞: 억새 덤불. 하윤 앞을 지나간다. 듬성듬성, 낮게.
    w = layer_width(width, "front")
    layers["front"] = L = Layer(w)
    x = rng.uniform(300, 700)
    while x < w:
        reed_clump(L, rng, x, rng.uniform(0.7, 1.25))
        x += rng.uniform(900, 1900)
    return layers


def sag(xa: float, ya: float, xb: float, yb: float, depth: float, n: int = 16) -> list[tuple[float, float]]:
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append((xa + (xb - xa) * t, ya + (yb - ya) * t + depth * 4 * t * (1 - t)))
    return pts


def bus_stop(L: Layer, cx: float, base: float, shadows: list[tuple]) -> None:
    """시골 버스 정류장: 비스듬한 지붕, 뒷벽, 벤치, 시간표, 멈춘 시계(3:17)."""
    wall, dark, roof = rgba(150, 132, 108), rgba(96, 82, 66), rgba(120, 72, 56)
    left, right = cx - 260, cx + 260
    shadows.append(("poly", [(left, base), (right, base), (right - 600, base + 40), (left - 600, base + 40)], rgba(70, 50, 30, 100)))
    L.poly([(left + 20, base), (right - 20, base), (right - 20, base - 300), (left + 20, base - 300)], wall)  # 뒷벽
    L.poly([(right - 120, base - 290), (right - 30, base - 290), (right - 30, base - 60), (right - 120, base - 60)], rgba(178, 160, 132))  # 햇빛 든 벽
    for px in (left + 24, right - 24):
        L.poly([(px - 8, base), (px + 8, base), (px + 8, base - 340), (px - 8, base - 340)], dark)
    L.poly([(left - 40, base - 330), (right + 50, base - 360), (right + 50, base - 380), (left - 40, base - 352)], roof)
    # 벤치
    L.poly([(left + 70, base - 96), (right - 70, base - 96), (right - 70, base - 82), (left + 70, base - 82)], dark)
    for bx in (left + 90, right - 90):
        L.poly([(bx - 5, base), (bx + 5, base), (bx + 5, base - 90), (bx - 5, base - 90)], dark)
    # 시간표 판
    L.poly([(left + 60, base - 260), (left + 190, base - 260), (left + 190, base - 140), (left + 60, base - 140)], rgba(226, 216, 190))
    for i in range(6):
        y = base - 245 + i * 17
        L.line([(left + 74, y), (left + 176 - (i % 3) * 18, y)], rgba(120, 110, 96), 2)
    # 시계: 3시 17분에 멈췄다
    ccx, ccy, r = right - 70, base - 250, 30
    L.ellipse((ccx - r - 4, ccy - r - 4, ccx + r + 4, ccy + r + 4), dark)
    L.ellipse((ccx - r, ccy - r, ccx + r, ccy + r), rgba(240, 232, 212))
    for ang, length, width in (((3 + 17 / 60) * 30, 15, 4), (17 * 6, 24, 2.5)):
        a = math.radians(ang - 90)
        L.line([(ccx, ccy), (ccx + math.cos(a) * length, ccy + math.sin(a) * length)], rgba(50, 44, 40), width)


def reed_clump(L: Layer, rng: random.Random, x: float, scale: float, base: float = H + 10) -> None:
    """억새 한 덤불: 줄기 여럿 + 끝의 은빛·금빛 이삭. 바람에 왼쪽으로 기운다. base = 뿌리 높이."""
    stem, plume_a, plume_b = rgba(150, 128, 84), rgba(236, 226, 196), rgba(222, 196, 140)
    for _ in range(int(rng.randint(9, 16) * scale)):
        bx = x + rng.gauss(0, 50 * scale)
        h = rng.uniform(260, 470) * scale
        lean = rng.uniform(-110, -20) * scale
        pts = []
        for i in range(13):
            t = i / 12
            pts.append((bx + lean * t * t, base - h * t))
        L.line(pts, stem, 3.2 * scale)
        tip = pts[-1]
        for k in range(7):  # 이삭: 가는 획 여러 개
            a = math.radians(rng.uniform(200, 250))
            ln = rng.uniform(40, 80) * scale
            c = plume_a if k % 2 else plume_b
            L.line([(tip[0], tip[1] + k * 6), (tip[0] + math.cos(a) * ln * 0.6, tip[1] + k * 6 + math.sin(a) * ln * -0.9 + ln)], c, 3 * scale)
        # 잎: 아래쪽에서 휘어 나간다
        if rng.random() < 0.6:
            lx = bx + rng.uniform(-10, 10)
            L.line(sag(lx, base, lx + rng.choice((-1, 1)) * rng.uniform(80, 160) * scale, base - 10 - rng.uniform(90, 200) * scale, -30 * scale, 8), stem, 4 * scale)


# ---------------------------------------------------------------- 여러 장소가 같이 쓰는 것


def layer_x(world_x: float, layer: str) -> float:
    """세계 x에 있는 것이 화면 가운데에 올 때, 그 층 그림에서의 x."""
    return (world_x - SCREEN_W / 2) * SCROLL[layer] + SCREEN_W / 2


def sky_layer(width: float, stops, glows=(), sun=None) -> Layer:
    """glows: [(x 비율, y, 반지름, 색, 세기)], sun: (x 비율, y, 반지름, 색)"""
    w = layer_width(width, "sky")
    img = vertical_gradient(w, stops)
    for fx, y, r, c, s in glows:
        add_glow(img, w * fx, y, r, c, s)
    L = Layer(w, img)
    if sun:
        fx, y, r, c = sun
        L.ellipse((w * fx - r, y - r, w * fx + r, y + r), c)
    return L


def streak_clouds(L: Layer, rng: random.Random, n: int, y0: float, y1: float, color: Color, blur: float = 10) -> None:
    shapes = []
    for _ in range(n):
        cx, cy = rng.uniform(0, L.width), rng.uniform(y0, y1)
        cw, ch = rng.uniform(260, 700), rng.uniform(12, 30)
        shapes.append(("ellipse", (cx - cw / 2, cy - ch / 2, cx + cw / 2, cy + ch / 2), color))
    L.under(shapes, blur)


def stars(L: Layer, rng: random.Random, n: int, y_max: float, color: Color) -> None:
    for _ in range(n):
        x, y, r = rng.uniform(0, L.width), rng.uniform(10, y_max), rng.uniform(0.8, 2.0)
        L.ellipse((x - r, y - r, x + r, y + r), color)


def mist(rng: random.Random, x0: float, x1: float, y: float, h: float, color: Color, n: int) -> list[tuple]:
    shapes = []
    for _ in range(n):
        cx = rng.uniform(x0, x1)
        cw, ch = rng.uniform(300, 900), rng.uniform(h * 0.4, h)
        cy = y + rng.uniform(-h * 0.3, h * 0.3)
        shapes.append(("ellipse", (cx - cw / 2, cy - ch / 2, cx + cw / 2, cy + ch / 2), color))
    return shapes


def strokes(L: Layer, rng: random.Random, x0: float, x1: float, y0: float, y1: float, n: int,
            c0: Color, c1: Color, h: tuple[float, float], lean: tuple[float, float] = (-10, 0),
            width: tuple[float, float] = (1.2, 2.4)) -> None:
    """풀 획. 아래 끝(y0~y1)에서 위로 뻗는다."""
    for _ in range(n):
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        L.line([(x, y), (x + rng.uniform(*lean), y - rng.uniform(*h))], lerp_color(c0, c1, rng.random()), rng.uniform(*width))


def pebbles(L: Layer, rng: random.Random, x0: float, x1: float, y0: float, y1: float, n: int, c0: Color, c1: Color) -> None:
    for _ in range(n):
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        rw, rh = rng.uniform(6, 20), rng.uniform(3, 8)
        L.ellipse((x - rw, y - rh, x + rw, y + rh), lerp_color(c0, c1, rng.random()))


def water_streaks(L: Layer, rng: random.Random, x0: float, x1: float, y0: float, y1: float, n: int, color: Color) -> None:
    for _ in range(n):
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        L.line([(x, y), (x + rng.uniform(30, 160), y)], color, rng.uniform(1.5, 3))


def tree(L: Layer, rng: random.Random, x: float, base: float, h: float, trunk_w: float, trunk: Color,
         canopy: Color | None, blobs: int = 5, spread: float = 1.0) -> None:
    L.poly([(x - trunk_w / 2, base), (x + trunk_w / 2, base), (x + trunk_w * 0.3, base - h), (x - trunk_w * 0.3, base - h)], trunk)
    if canopy is None:
        return
    for _ in range(blobs):
        r = rng.uniform(0.18, 0.3) * h * spread
        cx, cy = x + rng.uniform(-0.25, 0.25) * h * spread, base - h + rng.uniform(-0.15, 0.2) * h
        L.ellipse((cx - r, cy - r * 0.8, cx + r, cy + r * 0.8), canopy)


def bench(L: Layer, x: float, base: float, color: Color, w: float = 240) -> None:
    L.rect(x - w / 2, base - 92, x + w / 2, base - 78, color)
    L.rect(x - w / 2, base - 150, x + w / 2, base - 136, color)  # 등받이
    for bx in (x - w / 2 + 16, x + w / 2 - 16):
        L.rect(bx - 5, base - 150, bx + 5, base, color)


def chrysanthemum(L: Layer, x: float, y: float, r: float, petal: Color = rgba(246, 244, 236), heart: Color = rgba(232, 220, 160)) -> None:
    """흰 국화 한 송이: 꽃잎 고리 둘 + 가운데."""
    for ring, rr in ((1.0, r), (0.6, r * 0.75)):
        for k in range(12):
            a = math.tau * k / 12 + ring
            px, py = x + math.cos(a) * rr * 0.6, y + math.sin(a) * rr * 0.45
            L.ellipse((px - rr * 0.35, py - rr * 0.22, px + rr * 0.35, py + rr * 0.22), petal)
    L.ellipse((x - r * 0.25, y - r * 0.2, x + r * 0.25, y + r * 0.2), heart)


def reeds(L: Layer, rng: random.Random, x: float, scale: float, stem: Color, head: Color, base: float = H + 10) -> None:
    """갈대: 곧은 줄기 + 짙은 이삭."""
    for _ in range(int(rng.randint(8, 14) * scale)):
        bx = x + rng.gauss(0, 40 * scale)
        h = rng.uniform(280, 520) * scale
        lean = rng.uniform(-30, 20) * scale
        top = (bx + lean, base - h)
        L.line([(bx, base), top], stem, 2.6 * scale)
        L.line([top, (top[0] - 4 * scale, top[1] + 70 * scale)], head, 9 * scale)


# ---------------------------------------------------------------- 1. 산 아래 할아버지 집
# 늦가을 오후, 감빛·마루 갈색. 빛은 왼쪽 창에서. 방 → 마루·거실 → 마당.

def house(width: float, markers: dict[str, float]) -> dict[str, Layer]:
    rng = random.Random("house")
    mk = markers.get
    yard_x = 4750.0  # 여기까지 집 안, 그다음 마당
    layers: dict[str, Layer] = {}

    layers["sky"] = L = sky_layer(width, [
        (0.0, (150, 178, 206)), (0.45, (206, 208, 200)), (0.7, (240, 214, 170)), (1.0, (236, 198, 150)),
    ], glows=[(0.2, 420, 900, (255, 224, 170), 0.45)])
    streak_clouds(L, rng, 6, 160, 420, rgba(255, 240, 220, 110))

    w = layer_width(width, "far")
    layers["far"] = L = Layer(w)
    L.poly(ridge(rng, w, 440, 170, waves=3), rgba(176, 146, 126))  # 집 뒤 큰 산
    L.poly(ridge(rng, w, 585, 50), rgba(160, 118, 92))

    w = layer_width(width, "mid")
    layers["mid"] = L = Layer(w)
    L.poly(ridge(rng, w, 700, 20, waves=2), rgba(150, 112, 80))
    x = 120.0
    while x < w:
        tree(L, rng, x, 700, rng.uniform(140, 220), 14, rgba(96, 70, 52),
             rng.choice([rgba(214, 132, 60), rgba(196, 92, 54), rgba(222, 178, 80), rgba(170, 120, 70)]))
        x += rng.uniform(220, 520)

    w = layer_width(width, "ground")
    layers["ground"] = L = Layer(w)
    L.rect(-20, 792, yard_x + 10, H, rgba(150, 102, 64))  # 마루
    for y in range(820, H, 34):
        L.line([(-20, y), (yard_x, y)], rgba(122, 82, 52), 2)
    for _ in range(int(yard_x / 90)):
        x, y = rng.uniform(0, yard_x), rng.choice(range(792, H, 34))
        L.line([(x, y + 2), (x, y + 32)], rgba(122, 82, 52), 2)
    L.rect(-20, 792, yard_x + 10, 800, rgba(176, 124, 80))  # 마루 앞 끝의 밝은 면
    L.rect(yard_x, 792, w + 20, H, rgba(178, 150, 108))  # 마당 흙
    pebbles(L, rng, yard_x, w, 800, H, int((w - yard_x) / 8), rgba(160, 132, 96), rgba(196, 170, 128))
    L.rect(yard_x - 60, 786, yard_x + 120, 812, rgba(150, 146, 140))  # 댓돌

    w = layer_width(width, "props")
    layers["props"] = L = Layer(w)
    wood, dark = rgba(118, 82, 54), rgba(92, 64, 44)
    L.rect(-20, 0, yard_x, 170, rgba(104, 74, 50))  # 천장
    for x in range(0, int(yard_x), 160):
        L.line([(x, 0), (x + 40, 170)], rgba(88, 62, 42), 5)
    L.rect(-20, 170, yard_x, 792, rgba(206, 180, 140))  # 벽
    L.rect(-20, 170, yard_x, 200, dark)  # 인방
    L.rect(-20, 762, yard_x, 792, wood)  # 굽도리
    for x in (0, 1000, 2700, 3900, yard_x):
        L.rect(x - 14, 170, x + 14, 792, dark)
    # 왼쪽 창과 창으로 드는 빛
    L.rect(110, 290, 630, 630, dark)
    L.rect(124, 304, 616, 616, rgba(240, 226, 192))
    for gx in range(124, 616, 41):
        L.line([(gx, 304), (gx, 616)], rgba(170, 136, 100), 2)
    for gy in range(304, 616, 52):
        L.line([(124, gy), (616, gy)], rgba(170, 136, 100), 2)
    L.haze([("poly", [(124, 304), (616, 304), (1180, 792), (560, 792)], rgba(255, 232, 176, 70))], 22)
    # 마루 쪽 창호 문
    for i, x in enumerate(range(2740, 3880, 190)):
        L.rect(x, 250, x + 170, 740, rgba(232, 218, 188) if i % 2 else rgba(222, 206, 174))
        for gx in range(x + 20, x + 170, 30):
            L.line([(gx, 250), (gx, 740)], rgba(176, 146, 112), 2)
        for gy in range(270, 740, 60):
            L.line([(x, gy), (x + 170, gy)], rgba(176, 146, 112), 2)
    # 1-1 라디오
    x = mk("1-1", 570) + 220
    L.rect(x - 130, 640, x + 130, 792, wood)
    L.rect(x - 90, 560, x + 90, 640, rgba(124, 80, 50))
    L.ellipse((x - 76, 574, x - 16, 630), rgba(218, 200, 164))
    L.rect(x + 6, 584, x + 74, 606, rgba(230, 214, 176))
    # 1-2 현관의 검은 구두 줄, 식탁과 흰 국화
    x = mk("1-2", 1340)
    for i in range(6):
        sx = x - 260 + i * 62
        for dx in (0, 24):
            L.ellipse((sx + dx, 782, sx + dx + 26, 798), rgba(34, 30, 32))
    tx = x + 420
    L.rect(tx - 120, 694, tx + 120, 708, wood)
    for lx in (tx - 104, tx + 104):
        L.rect(lx - 6, 708, lx + 6, 792, wood)
    L.poly([(tx - 14, 694), (tx + 14, 694), (tx + 10, 650), (tx - 10, 650)], rgba(214, 214, 210))
    L.line([(tx, 650), (tx + 6, 600)], rgba(110, 130, 80), 3)
    chrysanthemum(L, tx + 6, 592, 18)
    # 1-3 앨범
    x = mk("1-3", 2220)
    L.rect(x - 48, 774, x + 48, 792, rgba(140, 62, 54))
    L.rect(x - 44, 774, x + 44, 778, rgba(226, 216, 196))
    # 1-4 책상(잠긴 서랍), 벽의 가족사진
    x = mk("1-4", 3320)
    L.rect(x - 190, 640, x + 190, 656, wood)
    L.rect(x - 180, 656, x - 20, 792, dark)
    L.rect(x - 170, 670, x - 30, 720, wood)
    L.ellipse((x - 106, 690, x - 94, 702), rgba(200, 170, 90))
    L.rect(x + 160, 656, x + 180, 792, dark)
    L.rect(x + 20, 360, x + 200, 480, dark)
    L.rect(x + 32, 372, x + 188, 468, rgba(222, 210, 186))
    for hx, hy, r in ((x + 70, 420, 14), (x + 110, 410, 17), (x + 150, 424, 11)):
        L.ellipse((hx - r, hy - r, hx + r, hy + r), rgba(150, 132, 110))
    # 집 끝: 처마
    L.poly([(yard_x - 40, 130), (yard_x + 300, 220), (yard_x + 300, 246), (yard_x - 40, 170)], rgba(74, 70, 74))
    # 1-6 마당: 흙담, 감나무, 대문
    L.rect(yard_x + 300, 610, w + 20, 792, rgba(196, 164, 122))
    L.rect(yard_x + 290, 594, w + 20, 614, rgba(84, 80, 84))
    for _ in range(40):
        sx, sy = rng.uniform(yard_x + 300, w), rng.uniform(620, 780)
        L.ellipse((sx - 14, sy - 8, sx + 14, sy + 8), rgba(176, 144, 104))
    tx = mk("1-6", 5190) - 120
    L.poly([(tx - 26, 792), (tx + 26, 792), (tx + 14, 330), (tx - 12, 330)], rgba(96, 70, 52))
    for ang, ln in ((-60, 230), (-115, 260), (-30, 180), (-150, 170), (-85, 200)):
        a = math.radians(ang)
        L.line([(tx, 400), (tx + math.cos(a) * ln, 400 + math.sin(a) * ln)], rgba(96, 70, 52), 9)
    for _ in range(26):
        a, r = rng.uniform(math.pi, math.tau), rng.uniform(60, 240)
        px, py = tx + math.cos(a) * r, 380 + math.sin(a) * r * 0.8
        L.ellipse((px - 11, py - 11, px + 11, py + 11), rgba(238, 128, 40))
    gx = width - 330
    L.rect(gx - 16, 470, gx + 4, 792, dark)
    L.rect(gx + 196, 470, gx + 216, 792, dark)
    L.poly([(gx - 50, 470), (gx + 250, 470), (gx + 230, 430), (gx - 30, 430)], rgba(84, 80, 84))
    L.poly([(gx + 4, 500), (gx + 70, 520), (gx + 70, 792), (gx + 4, 792)], rgba(150, 110, 70))  # 열린 문짝

    # 앞: 문틀, 마루 기둥, 감나무 가지
    w = layer_width(width, "front")
    layers["front"] = L = Layer(w)
    for wx in (1000, 2700, 3900):
        fx = layer_x(wx, "front")
        L.rect(fx - 30, -10, fx + 30, H + 10, rgba(70, 48, 32))
    fx = layer_x(mk("1-6", 5190) + 200, "front")
    for k in range(4):
        sx, ln = fx + k * 70, rng.uniform(220, 380)
        pts = sag(sx, -10, sx - 180, ln, 30, 10)
        L.line(pts, rgba(70, 52, 38), 10 - k)
        px, py = pts[-1]
        L.ellipse((px - 16, py - 16, px + 16, py + 16), rgba(232, 120, 36))
    return layers


# ---------------------------------------------------------------- 3. 버려진 간이역
# 노을, 주황·분홍과 녹슨 붉은색. 해는 오른쪽 아래.

def station(width: float, markers: dict[str, float]) -> dict[str, Layer]:
    rng = random.Random("station")
    mk = markers.get
    layers: dict[str, Layer] = {}

    layers["sky"] = L = sky_layer(width, [
        (0.0, (74, 62, 112)), (0.3, (152, 92, 132)), (0.55, (226, 122, 112)), (0.68, (250, 162, 92)), (1.0, (238, 140, 82)),
    ], glows=[(0.86, 730, 1100, (255, 176, 112), 0.6), (0.86, 730, 200, (255, 214, 160), 0.8)],
        sun=(0.86, 740, 46, rgba(255, 222, 170)))
    streak_clouds(L, rng, 10, 200, 560, rgba(255, 168, 150, 150), 8)

    w = layer_width(width, "far")
    layers["far"] = L = Layer(w)
    L.poly(ridge(rng, w, 600, 50), rgba(118, 72, 102))
    L.poly(ridge(rng, w, 650, 30), rgba(92, 56, 84))

    w = layer_width(width, "mid")
    layers["mid"] = L = Layer(w)
    L.poly(ridge(rng, w, 690, 12, waves=2), rgba(84, 46, 62))
    x = 80.0
    while x < w:
        tree(L, rng, x, 690, rng.uniform(80, 170), 10, rgba(70, 38, 52), rgba(80, 44, 60), 4)
        x += rng.uniform(160, 460)
    tops = []
    for x in range(120, w, 340):
        L.line([(x, 694), (x, 600)], rgba(66, 36, 48), 4)
        tops.append((x, 608))
    for (xa, ya), (xb, yb) in zip(tops, tops[1:]):
        L.line(sag(xa, ya, xb, yb, 12), rgba(66, 36, 48, 180), 1.4)

    w = layer_width(width, "ground")
    layers["ground"] = L = Layer(w)
    L.rect(-20, 692, w + 20, 776, rgba(112, 74, 70))  # 자갈 바닥
    pebbles(L, rng, 0, w, 696, 772, int(w / 6), rgba(92, 60, 58), rgba(150, 104, 92))
    for x in range(0, w, 62):
        L.rect(x, 712, x + 20, 760, rgba(72, 46, 42))  # 침목
    for y in (718, 748):
        L.rect(-20, y - 4, w + 20, y + 4, rgba(150, 78, 56))
        L.rect(-20, y - 4, w + 20, y - 2, rgba(230, 150, 100))  # 노을빛 받은 윗면
    L.rect(-20, 776, w + 20, H, rgba(176, 140, 132))  # 플랫폼
    L.rect(-20, 776, w + 20, 790, rgba(214, 172, 150))  # 플랫폼 끝 선
    for _ in range(int(w / 120)):
        x, y = rng.uniform(0, w), rng.uniform(800, H)
        L.line([(x, y), (x + rng.uniform(-60, 60), y + rng.uniform(10, 50))], rgba(140, 108, 104), 2)
    strokes(L, rng, 0, w, 790, H, int(w / 14), rgba(112, 112, 60), rgba(160, 150, 80), (10, 40))

    w = layer_width(width, "props")
    layers["props"] = L = Layer(w)
    rust, wall, dark = rgba(130, 62, 46), rgba(178, 124, 104), rgba(90, 52, 44)
    # 3-1 역명판 (이름은 아직 정하지 않았다)
    x = mk("3-1", 776)
    for px in (x - 120, x + 120):
        L.rect(px - 6, 540, px + 6, 776, dark)
    L.rect(x - 170, 460, x + 170, 548, dark)
    L.rect(x - 160, 470, x + 160, 538, rgba(226, 210, 184))
    L.poly([(x + 60, 470), (x + 90, 470), (x + 74, 538), (x + 58, 538)], rgba(176, 100, 70, 150))  # 녹물
    # 3-2 역사와 잠긴 대합실 문, 벤치(밑에 열쇠)
    x = mk("3-2", 2118)
    L.rect(x - 650, 380, x + 460, 776, wall)
    L.poly([(x - 720, 390), (x + 530, 390), (x + 470, 320), (x - 660, 320)], rgba(104, 54, 50))
    for wx in (x - 520, x - 330, x + 230):
        L.rect(wx, 470, wx + 130, 600, dark)
        L.rect(wx + 8, 478, wx + 122, 592, rgba(240, 150, 96))
    L.rect(x - 70, 580, x + 70, 776, rgba(96, 58, 46))
    L.rect(x - 50, 600, x + 50, 660, rgba(64, 40, 36))
    L.ellipse((x + 44, 690, x + 56, 702), rgba(200, 170, 100))
    bench(L, x + 300, 776, dark)
    L.ellipse((x + 296, 766, x + 308, 774), rgba(255, 226, 130))  # 벤치 밑 열쇠
    # 3-3 앉는 벤치, 3-5 근처 벤치
    bench(L, mk("3-3", 3325), 776, dark)
    bench(L, mk("3-5", 6946), 776, dark)
    # 플랫폼 등
    for lx in (mk("3-3", 3325) + 600, mk("3-4", 4934) + 500, mk("3-5", 6946) - 500):
        L.rect(lx - 5, 430, lx + 5, 776, rust)
        L.poly([(lx - 30, 430), (lx + 30, 430), (lx + 18, 410), (lx - 18, 410)], rust)
    # 3-6 대합실 안
    x0 = mk("3-6", 8555) - 700
    L.rect(x0, 0, w + 20, 170, rgba(80, 46, 40))
    L.rect(x0, 170, w + 20, 776, rgba(150, 92, 80))
    L.rect(x0, 740, w + 20, 776, dark)
    beams = []
    for wx in range(int(x0 + 160), int(w - 200), 420):
        L.rect(wx, 300, wx + 200, 560, dark)
        L.rect(wx + 10, 310, wx + 190, 550, rgba(252, 172, 110))
        L.line([(wx + 100, 310), (wx + 100, 550)], dark, 6)
        beams.append(("poly", [(wx + 10, 310), (wx + 190, 310), (wx + 420, 776), (wx + 200, 776)], rgba(255, 170, 110, 60)))
    L.haze(beams, 20)
    for cx in range(int(x0 + 120), int(w - 100), 110):
        L.rect(cx - 36, 690, cx + 36, 704, rgba(70, 44, 40))
        L.rect(cx - 36, 640, cx - 26, 776, rgba(70, 44, 40))
        L.rect(cx + 26, 704, cx + 34, 776, rgba(70, 44, 40))
    L.rect(x0 - 16, 0, x0 + 16, 776, dark)

    # 앞: 플랫폼 기둥, 녹슨 신호기, 웃자란 풀
    w = layer_width(width, "front")
    layers["front"] = L = Layer(w)
    for i, wx in enumerate(range(1500, int(mk("3-6", 8555) - 900), 1700)):
        fx = layer_x(wx, "front")
        L.rect(fx - 24, -10, fx + 24, H + 10, rgba(84, 46, 44))
        L.rect(fx + 8, -10, fx + 24, H + 10, rgba(150, 84, 64))  # 노을 받는 쪽
    fx = layer_x(mk("3-4", 4934) + 700, "front")
    L.rect(fx - 10, 320, fx + 10, H + 10, rgba(110, 54, 42))
    L.rect(fx - 40, 300, fx + 40, 470, rgba(70, 38, 36))
    for ly in (340, 420):
        L.ellipse((fx - 24, ly - 24, fx + 24, ly + 24), rgba(120, 40, 34))
    x = rng.uniform(200, 600)
    while x < w:
        strokes(L, rng, x - 120, x + 120, H - 20, H + 10, rng.randint(25, 45),
                rgba(104, 96, 54), rgba(150, 130, 70), (120, 320), (-40, 20), (2.5, 4.5))
        x += rng.uniform(700, 1500)
    return layers


# ---------------------------------------------------------------- 4. 빛이 많은 숲
# 4-2 갈림길: (이끼 바위 x, [빛줄기 세 개 x]) — 장면 표시 4-2 기준. 장소 씬의 부품 자리와 맞춘다.
FOREST_FORKS = [(0, [329, 629, 929]), (1529, [300, 600, 900])]
# 해 진 직후, 청록 그림자와 금빛 빛 알갱이. 빛줄기가 위에서 내린다.

def forest(width: float, markers: dict[str, float]) -> dict[str, Layer]:
    rng = random.Random("forest")
    mk = markers.get
    layers: dict[str, Layer] = {}
    gold = rgba(255, 222, 150, 70)

    layers["sky"] = sky_layer(width, [
        (0.0, (22, 42, 56)), (0.45, (60, 104, 110)), (0.75, (124, 152, 132)), (1.0, (92, 120, 108)),
    ], glows=[(0.5, 420, 900, (200, 210, 160), 0.25)])

    w = layer_width(width, "far")
    layers["far"] = L = Layer(w)
    L.rect(-20, 700, w + 20, H, rgba(36, 66, 66))
    x = 0.0
    while x < w:
        tree(L, rng, x, 720, rng.uniform(420, 680), rng.uniform(14, 26), rgba(40, 74, 74), rgba(38, 72, 72), 4, 0.6)
        x += rng.uniform(60, 160)

    w = layer_width(width, "mid")
    layers["mid"] = L = Layer(w)
    L.rect(-20, 740, w + 20, H, rgba(30, 56, 54))
    x = 0.0
    while x < w:
        tree(L, rng, x, 760, rng.uniform(700, 900), rng.uniform(28, 52), rgba(30, 58, 56), None)
        x += rng.uniform(140, 320)
    for _ in range(int(w / 60)):
        cx, cy, r = rng.uniform(0, w), rng.uniform(-40, 160), rng.uniform(90, 200)
        L.ellipse((cx - r, cy - r * 0.6, cx + r, cy + r * 0.6), rgba(24, 48, 48))
    shafts = []
    for _ in range(int(w / 900)):
        sx = rng.uniform(0, w)
        shafts.append(("poly", [(sx, -10), (sx + 60, -10), (sx + 260, 760), (sx + 150, 760)], rgba(220, 220, 160, 40)))
    L.haze(shafts, 14)

    w = layer_width(width, "ground")
    layers["ground"] = L = Layer(w)
    L.rect(-20, 770, w + 20, H, rgba(46, 58, 44))
    path_top = [(float(x), 792 + rng.uniform(-3, 3)) for x in range(-20, w + 40, 60)]
    path_bot = [(float(x), 860 + rng.uniform(-8, 8)) for x in range(w + 40, -40, -60)]
    L.poly(path_top + path_bot, rgba(78, 82, 60))
    for _ in range(int(w / 50)):
        x, y, r = rng.uniform(0, w), rng.uniform(870, H), rng.uniform(20, 60)
        L.ellipse((x - r, y - r * 0.3, x + r, y + r * 0.3), rgba(64, 92, 56))
    strokes(L, rng, 0, w, 770, 796, int(w / 8), rgba(44, 76, 56), rgba(80, 112, 70), (10, 36))
    pebbles(L, rng, 0, w, 796, 856, int(w / 12), rgba(88, 84, 62), rgba(120, 110, 80))

    w = layer_width(width, "props")
    layers["props"] = L = Layer(w)
    x = 100.0
    while x < w:  # 하윤 바로 뒤 나무
        if all(abs(x - mk(k, -9999)) > 500 for k in ("4-2", "4-3")):
            tree(L, rng, x, 790, 900, rng.uniform(46, 80), rgba(34, 60, 56), None)
        x += rng.uniform(500, 1100)
    # 4-2 빛 갈림길 두 번: 이끼 바위 + 앞쪽 세 갈래 빛줄기. 자리는 장소 씬 부품과 같다(FOREST_FORKS).
    x0 = mk("4-2", 3171)
    for rock_dx, shaft_dxs in FOREST_FORKS:
        x = x0 + rock_dx
        L.ellipse((x - 180, 620, x + 180, 820), rgba(84, 94, 86))
        L.ellipse((x - 150, 612, x + 140, 700), rgba(82, 124, 70))
        # 덤불 벽: 빛줄기 셋 앞에서 길을 막고, 빛 자리마다 굴 같은 입구가 난다(옆으로 못 가고 입구를 골라야 한다는 게 보이게).
        hx0, hx1 = x + shaft_dxs[0] - 220, x + shaft_dxs[-1] + 260
        hr = random.Random(f"hedge{rock_dx}")  # 숲의 다른 그림(rng 순서)이 바뀌지 않게 따로
        for _ in range(int((hx1 - hx0) / 26)):
            cx, cy, r = hr.uniform(hx0, hx1), hr.uniform(380, 760), hr.uniform(60, 130)
            L.ellipse((cx - r, cy - r * 0.8, cx + r, cy + r * 0.8), rgba(22, 44, 40))
        for _ in range(int((hx1 - hx0) / 40)):
            cx, cy, r = hr.uniform(hx0, hx1), hr.uniform(340, 720), hr.uniform(30, 70)
            L.ellipse((cx - r, cy - r * 0.7, cx + r, cy + r * 0.7), rgba(36, 70, 56))
        L.rect(hx0 + 40, 620, hx1 - 40, 800, rgba(22, 44, 40))
        for dx in shaft_dxs:
            ex = x + dx
            L.ellipse((ex - 92, 470, ex + 92, 640), rgba(58, 82, 60))  # 입구 테두리(빛 받은 잎)
            L.rect(ex - 92, 556, ex + 92, 800, rgba(58, 82, 60))
            L.ellipse((ex - 74, 488, ex + 74, 620), rgba(10, 20, 18))  # 굴 안쪽 어둠
            L.rect(ex - 74, 554, ex + 74, 800, rgba(10, 20, 18))
        L.haze([("poly", [(x + dx - 160, -10), (x + dx - 60, -10), (x + dx + 70, 792), (x + dx - 70, 792)], gold)
                for dx in shaft_dxs], 18)
    # 4-3 빈터: 큰 빛과 떠 있는 빛 알갱이(움직임은 나중에 코드로)
    x = mk("4-3", 6266)
    L.ellipse((x - 520, 770, x + 520, 830), rgba(110, 112, 72))
    L.haze([("poly", [(x - 420, -10), (x + 220, -10), (x + 480, 792), (x - 300, 792)], rgba(255, 226, 150, 80))], 30)
    for _ in range(70):
        px, py, r = x + rng.uniform(-600, 600), rng.uniform(260, 780), rng.uniform(2, 5)
        L.ellipse((px - r, py - r, px + r, py + r), rgba(255, 228, 150, 220))
    # 4-4 숲 끝 안개
    x = mk("4-4", 8546)
    L.haze(mist(rng, x - 900, w + 200, 760, 160, rgba(190, 214, 208, 120), 18), 30)

    # 앞: 나무 기둥, 고사리, 늘어진 가지
    w = layer_width(width, "front")
    layers["front"] = L = Layer(w)
    x = rng.uniform(300, 700)
    while x < w:
        tw = rng.uniform(90, 170)
        L.rect(x - tw / 2, -10, x + tw / 2, H + 10, rgba(18, 34, 34))
        x += rng.uniform(1300, 2400)
    x = rng.uniform(100, 400)
    while x < w:
        for _ in range(rng.randint(6, 10)):
            a = math.radians(rng.uniform(200, 340))
            ln = rng.uniform(120, 220)
            pts = sag(x, H + 10, x + math.cos(a) * ln, H + 10 + math.sin(a) * ln, -20, 8)
            L.line(pts, rgba(34, 66, 46), 7)
        x += rng.uniform(500, 1100)
    x = rng.uniform(400, 900)
    while x < w:
        for k in range(rng.randint(2, 4)):
            sx = x + k * 50
            L.line(sag(sx, -10, sx + rng.uniform(-80, 80), rng.uniform(160, 300), 20, 8), rgba(26, 50, 40), 5)
        x += rng.uniform(1100, 2000)
    return layers


# ---------------------------------------------------------------- 5. 강가
# 푸른 황혼, 푸른 회색과 은빛 물안개. 빛은 물에서 반사된다.

def riverside(width: float, markers: dict[str, float]) -> dict[str, Layer]:
    rng = random.Random("riverside")
    mk = markers.get
    layers: dict[str, Layer] = {}
    water = rgba(104, 124, 156)

    layers["sky"] = L = sky_layer(width, [
        (0.0, (56, 70, 106)), (0.45, (122, 140, 176)), (0.6, (188, 196, 212)), (1.0, (150, 164, 190)),
    ])
    streak_clouds(L, rng, 7, 180, 480, rgba(200, 206, 224, 110))

    w = layer_width(width, "far")
    layers["far"] = L = Layer(w)
    L.poly(ridge(rng, w, 560, 70), rgba(100, 114, 144))
    L.poly(ridge(rng, w, 610, 40), rgba(82, 96, 128))

    w = layer_width(width, "mid")
    layers["mid"] = L = Layer(w)
    L.rect(-20, 636, w + 20, 650, rgba(70, 84, 110))  # 건너편 둑
    L.rect(-20, 648, w + 20, H, water)
    water_streaks(L, rng, 0, w, 656, 790, int(w / 18), rgba(206, 214, 230, 140))
    x = layer_x(mk("5-4", 6390), "mid")  # 5-4 여울
    water_streaks(L, rng, x - 500, x + 500, 690, 790, 90, rgba(236, 240, 246, 210))
    L.haze(mist(rng, 0, w, 650, 80, rgba(212, 220, 232, 130), int(w / 260)), 26)

    w = layer_width(width, "ground")
    layers["ground"] = L = Layer(w)
    L.rect(-20, 792, w + 20, 864, rgba(140, 140, 148))  # 조약돌 길
    pebbles(L, rng, 0, w, 796, 862, int(w / 3), rgba(112, 112, 122), rgba(186, 186, 192))
    L.rect(-20, 862, w + 20, H, rgba(96, 116, 148))  # 앞 물
    water_streaks(L, rng, 0, w, 872, H, int(w / 30), rgba(190, 202, 222, 140))
    x = mk("5-2", 2040)  # 5-2 얕은 물가
    L.poly([(x - 340, 792), (x + 320, 792), (x + 380, 864), (x - 400, 864)], rgba(110, 134, 166, 150))
    water_streaks(L, rng, x - 300, x + 300, 800, 860, 30, rgba(210, 220, 236, 170))
    x = mk("5-3", 3990)  # 5-3 징검다리
    L.rect(x - 480, 788, x + 480, 866, water)
    water_streaks(L, rng, x - 460, x + 460, 796, 860, 40, rgba(206, 214, 230, 160))
    for sx in range(int(x - 420), int(x + 440), 140):
        L.ellipse((sx - 56, 792, sx + 56, 822), rgba(110, 108, 116))
        L.ellipse((sx - 50, 790, sx + 50, 810), rgba(146, 144, 150))

    w = layer_width(width, "props")
    layers["props"] = L = Layer(w)
    x = rng.uniform(100, 500)
    while x < w:
        if abs(x - mk("5-3", 3990)) > 600:
            reeds(L, rng, x, 0.6, rgba(110, 104, 96), rgba(98, 84, 78), base=796)
        x += rng.uniform(500, 1200)
    for _ in range(int(w / 700)):
        x = rng.uniform(0, w)
        L.ellipse((x - 70, 752, x + 70, 800), rgba(86, 90, 104))

    w = layer_width(width, "front")
    layers["front"] = L = Layer(w)
    x = rng.uniform(300, 700)
    while x < w:
        reeds(L, rng, x, rng.uniform(0.8, 1.2), rgba(112, 100, 84), rgba(108, 80, 70))
        if rng.random() < 0.5:
            rx = x + rng.uniform(120, 300)
            L.ellipse((rx - 110, H - 90, rx + 110, H + 60), rgba(58, 64, 80))
        x += rng.uniform(900, 1800)
    return layers


# ---------------------------------------------------------------- 6. 낡은 철교
# 밤으로 넘어가는 남보라, 녹슨 갈색. 안개 속 희미한 빛.
# 6-2에서 철교가 끊긴다. 그 뒤는 6-3 강둑 길(지금 바닥은 평평하다 — 높낮이는 A와 맞출 것).

def bridge(width: float, markers: dict[str, float]) -> dict[str, Layer]:
    rng = random.Random("bridge")
    mk = markers.get
    layers: dict[str, Layer] = {}
    break_x = mk("6-2", 3440) + 260
    bank_x = break_x + 420
    rust, dark_rust = rgba(112, 72, 60), rgba(70, 48, 46)

    layers["sky"] = L = sky_layer(width, [
        (0.0, (18, 18, 42)), (0.5, (56, 46, 92)), (0.75, (110, 92, 132)), (1.0, (80, 70, 110)),
    ], glows=[(0.7, 520, 700, (190, 176, 210), 0.3)])
    stars(L, rng, 120, 420, rgba(220, 220, 240, 170))

    w = layer_width(width, "far")
    layers["far"] = L = Layer(w)
    L.poly(ridge(rng, w, 600, 60), rgba(46, 40, 72))

    w = layer_width(width, "mid")
    layers["mid"] = L = Layer(w)
    L.rect(-20, 720, w + 20, H, rgba(42, 42, 72))  # 아래 강
    water_streaks(L, rng, 0, w, 730, H, int(w / 40), rgba(110, 106, 150, 110))
    for wx in (300, 1500, 2700):  # 철교 교각
        px = layer_x(wx, "mid")
        L.rect(px - 40, 690, px + 40, H, rgba(60, 52, 66))
    L.haze(mist(rng, 0, w, 700, 120, rgba(140, 130, 176, 120), int(w / 240)), 30)

    w = layer_width(width, "ground")
    layers["ground"] = L = Layer(w)
    L.rect(-20, 792, break_x, 838, rgba(92, 64, 58))  # 철판 바닥
    for x in range(0, int(break_x), 120):
        L.line([(x, 794), (x, 836)], dark_rust, 2)
        for ry in (800, 830):
            L.ellipse((x + 10, ry - 3, x + 16, ry + 3), rgba(140, 100, 80))
    L.rect(-20, 838, break_x - 40, 900, dark_rust)  # 거더
    for x in range(0, int(break_x - 60), 90):
        L.line([(x, 840), (x + 45, 898)], rgba(56, 40, 40), 5)
    L.poly([(break_x - 120, 792), (break_x, 796), (break_x - 30, 812), (break_x + 20, 826), (break_x - 60, 838),
            (break_x - 40, 870), (break_x - 140, 900), (break_x - 140, 792)], rgba(92, 64, 58))  # 끊긴 끝
    L.poly([(bank_x - 160, H + 10), (bank_x + 120, 792), (w + 20, 792), (w + 20, H + 10)], rgba(54, 56, 70))  # 강둑
    strokes(L, rng, bank_x, w, 794, H, int((w - bank_x) / 6), rgba(56, 66, 70), rgba(90, 96, 104), (14, 46))

    w = layer_width(width, "props")
    layers["props"] = L = Layer(w)
    end = break_x - 60
    L.line([(-20, 300), (end - 80, 300), (end, 360)], rust, 14)  # 위 현(끝이 꺾였다)
    x = 0
    while x < end - 100:
        L.line([(x, 300), (x, 792)], rust, 10)
        L.line([(x, 300), (min(x + 320, end - 40), 792)], rgba(100, 64, 56), 7)
        x += 320
    L.line([(end - 40, 360), (end - 10, 520)], rust, 8)  # 늘어진 부재
    x = bank_x + 200
    while x < w:
        reeds(L, rng, x, 0.6, rgba(60, 62, 76), rgba(54, 50, 66), base=796)
        x += rng.uniform(500, 1100)

    w = layer_width(width, "front")
    layers["front"] = L = Layer(w)
    fend = layer_x(break_x, "front")
    x = 400.0
    while x < fend - 200:
        L.rect(x - 22, -10, x + 22, H + 10, rgba(54, 38, 38))
        L.line([(x, -10), (x + 520, H + 10)], rgba(60, 42, 40), 26)
        x += 900
    x = layer_x(bank_x, "front") + 300
    while x < w:
        reeds(L, rng, x, 1.0, rgba(40, 40, 54), rgba(36, 32, 46))
        x += rng.uniform(900, 1700)
    L.haze(mist(rng, 0, w, H - 60, 160, rgba(150, 140, 180, 90), int(w / 300)), 30)
    return layers


# ---------------------------------------------------------------- 7. 나루터
# 시간을 알 수 없는 하얀 빛, 흰색과 옅은 금빛. 흰 국화 꽃밭과 작은 나루터, 나룻배 한 척.

def ferry(width: float, markers: dict[str, float]) -> dict[str, Layer]:
    rng = random.Random("ferry")
    mk = markers.get
    layers: dict[str, Layer] = {}
    dock_x = mk("7-3", 1220) - 260

    layers["sky"] = sky_layer(width, [
        (0.0, (236, 234, 226)), (0.5, (248, 244, 232)), (0.75, (250, 240, 214)), (1.0, (246, 232, 204)),
    ], glows=[(0.8, 560, 1400, (255, 252, 240), 0.7), (0.8, 560, 600, (255, 238, 196), 0.5)])

    w = layer_width(width, "far")
    layers["far"] = L = Layer(w)
    L.poly(ridge(rng, w, 600, 40), rgba(226, 222, 212))

    w = layer_width(width, "mid")
    layers["mid"] = L = Layer(w)
    L.rect(-20, 650, w + 20, H, rgba(228, 230, 230))
    water_streaks(L, rng, 0, w, 660, 790, int(w / 14), rgba(255, 244, 214, 170))
    L.haze(mist(rng, 0, w, 660, 90, rgba(252, 252, 248, 160), int(w / 200)), 28)

    w = layer_width(width, "ground")
    layers["ground"] = L = Layer(w)
    L.rect(-20, 740, dock_x + 20, H, rgba(214, 208, 184))  # 꽃밭
    for _ in range(int(dock_x / 6)):
        chrysanthemum(L, rng.uniform(0, dock_x), rng.uniform(744, 790), rng.uniform(7, 12))
    L.rect(-20, 792, dock_x, 860, rgba(222, 212, 186))  # 길
    for _ in range(int(dock_x / 12)):
        chrysanthemum(L, rng.uniform(0, dock_x), rng.uniform(868, H), rng.uniform(10, 18))
    L.rect(dock_x, 830, w + 20, H, rgba(230, 232, 232))  # 데크 아래 물
    water_streaks(L, rng, dock_x, w, 860, H, 40, rgba(255, 242, 210, 170))
    L.rect(dock_x, 792, w + 20, 830, rgba(198, 170, 128))  # 나루터 데크
    for x in range(int(dock_x), int(w), 44):
        L.line([(x, 794), (x, 828)], rgba(170, 142, 104), 2)
    for x in range(int(dock_x) + 40, int(w), 300):
        L.rect(x - 10, 830, x + 10, 960, rgba(168, 138, 100))

    w = layer_width(width, "props")
    layers["props"] = L = Layer(w)
    bx = mk("7-3", 1220) + 260
    L.poly([(bx - 280, 762), (bx + 290, 758), (bx + 220, 806), (bx - 220, 808)], rgba(150, 116, 82))  # 나룻배
    L.line([(bx - 270, 764), (bx + 280, 760)], rgba(208, 180, 140), 5)
    L.rect(bx - 90, 770, bx + 90, 778, rgba(120, 92, 66))
    L.rect(dock_x + 40, 700, dock_x + 56, 792, rgba(150, 120, 88))  # 말뚝
    L.line([(dock_x + 50, 712), (bx - 270, 768)], rgba(170, 150, 120), 2)  # 밧줄
    for x in range(int(dock_x + 300), int(w), 400):
        L.rect(x - 8, 740, x + 8, 792, rgba(170, 140, 104))

    w = layer_width(width, "front")
    layers["front"] = L = Layer(w)
    fend = layer_x(dock_x, "front")
    x = 120.0
    while x < fend:
        for _ in range(rng.randint(5, 9)):
            fx, fy = x + rng.gauss(0, 60), H - rng.uniform(20, 180)
            L.line([(fx, H + 10), (fx + rng.uniform(-20, 20), fy)], rgba(160, 172, 130), 3)
            chrysanthemum(L, fx, fy, rng.uniform(22, 34))
        x += rng.uniform(500, 1000)
    L.haze(mist(rng, 0, w, H - 40, 140, rgba(255, 255, 252, 130), int(w / 260)), 30)
    return layers


# ---------------------------------------------------------------- 7-6 강 위 구간
# 나룻배가 흘러가는 강. 걷는 땅 없이 물뿐. 강 건너 안개에는 지나온 장소가 코드로 비친다(boat_ride.gd).

def crossing(width: float, markers: dict[str, float]) -> dict[str, Layer]:
    rng = random.Random("crossing")
    layers: dict[str, Layer] = {}
    layers["sky"] = sky_layer(width, [
        (0.0, (240, 238, 230)), (0.5, (250, 246, 236)), (0.75, (252, 244, 222)), (1.0, (248, 238, 212)),
    ], glows=[(0.85, 560, 1600, (255, 252, 240), 0.75), (0.85, 560, 700, (255, 240, 200), 0.5)])
    w = layer_width(width, "far")
    layers["far"] = L = Layer(w)
    L.poly(ridge(rng, w, 560, 30), rgba(232, 228, 218, 200))  # 아주 먼 강 건너
    L.haze(mist(rng, 0, w, 560, 120, rgba(255, 255, 252, 170), int(w / 220)), 34)
    w = layer_width(width, "mid")
    layers["mid"] = L = Layer(w)
    L.rect(-20, 600, w + 20, H, rgba(228, 232, 234))
    water_streaks(L, rng, 0, w, 610, H, int(w / 10), rgba(255, 246, 218, 170))
    L.haze(mist(rng, 0, w, 610, 90, rgba(252, 252, 250, 160), int(w / 200)), 30)
    w = layer_width(width, "ground")
    layers["ground"] = L = Layer(w)
    L.rect(-20, 818, w + 20, H, rgba(220, 226, 230))  # 배 아래 물
    water_streaks(L, rng, 0, w, 826, H, int(w / 12), rgba(255, 244, 214, 180))
    layers["props"] = Layer(layer_width(width, "props"))
    w = layer_width(width, "front")
    layers["front"] = L = Layer(w)
    L.haze(mist(rng, 0, w, H - 30, 150, rgba(255, 255, 252, 140), int(w / 240)), 32)
    return layers


# ---------------------------------------------------------------- 손그림 컷신 자리(임시)
# 진짜 컷신은 일러스트 담당이 손으로 그린다(장면표). 이건 연출 길이·글자 자리를 맞춰 보는 임시 그림.
# 글자(팔찌 "이하윤 / 9세")는 그리지 않는다 — 게임이 글꼴로 얹는다(scripts/game/ending.gd).

def cut_bracelet() -> Image.Image:
    """7-4 손목 클로즈업: 할아버지의 큰 손이 아이 손목을 잡고 있다. 손목에 흰 팔찌(글자 자리는 비움)."""
    bg = vertical_gradient(SCREEN_W, [(0.0, (248, 240, 222)), (0.6, (244, 230, 200)), (1.0, (236, 218, 186))])
    add_glow(bg, 1500, 200, 1300, (255, 250, 236), 0.6)
    L = Layer(SCREEN_W, bg)
    L.poly([(-20, 760), (700, 600), (1140, 560), (1160, 700), (720, 760), (-20, 940)], rgba(238, 206, 186))  # 아이 팔
    L.ellipse((1060, 520, 1300, 720), rgba(240, 210, 190))  # 아이 손
    L.poly([(820, 560), (1010, 540), (1030, 690), (840, 716)], rgba(250, 250, 246))  # 흰 팔찌
    L.line([(822, 566), (842, 712)], rgba(210, 212, 214), 4)
    L.line([(1008, 546), (1028, 686)], rgba(210, 212, 214), 4)
    L.poly([(1940, 260), (1500, 360), (1180, 470), (1120, 560), (1200, 640), (1500, 600), (1940, 520)], rgba(196, 150, 120))  # 할아버지 팔·소매
    L.poly([(1940, 220), (1640, 300), (1660, 380), (1940, 330)], rgba(110, 100, 92))  # 외투 소매
    for i, (fx, fy) in enumerate(((1130, 520), (1100, 585), (1095, 650), (1120, 712))):  # 손가락
        L.line(sag(1260, fy - 30, fx, fy + 20, -12, 6), rgba(184, 138, 110), 34 - i * 3)
    L.line(sag(1220, 470, 1000, 520, 20, 8), rgba(184, 138, 110), 30)  # 엄지
    for k in range(6):  # 주름
        x0 = 1300 + k * 70
        L.line([(x0, 420 + k * 4), (x0 + 40, 440 + k * 4)], rgba(160, 118, 94), 3)
    return L.render()[0].convert("RGB")


def cut_boat() -> Image.Image:
    """7-7 나룻배가 빛 속으로: 하얀 빛, 물 위 작은 배와 셋의 실루엣."""
    bg = vertical_gradient(SCREEN_W, [(0.0, (252, 250, 244)), (0.55, (250, 244, 226)), (0.62, (236, 230, 214)), (1.0, (222, 220, 214))])
    add_glow(bg, 1500, 560, 1400, (255, 252, 240), 0.9)
    L = Layer(SCREEN_W, bg)
    rng = random.Random("cut_boat")
    water_streaks(L, rng, 0, SCREEN_W, 680, 1080, 160, rgba(255, 246, 220, 160))
    bx, by = 900, 700
    L.poly([(bx - 220, by), (bx + 240, by - 6), (bx + 180, by + 44), (bx - 170, by + 46)], rgba(120, 100, 86, 230))
    for dx, h, w in ((-110, 150, 46), (-20, 110, 38), (140, 60, 56)):  # 할아버지, 하윤, 하늘이(뱃머리)
        L.poly([(bx + dx - w / 2, by), (bx + dx + w / 2, by), (bx + dx + w / 2 - 6, by - h), (bx + dx - w / 2 + 6, by - h)], rgba(110, 96, 86, 220))
        L.ellipse((bx + dx - w * 0.35, by - h - w * 0.7, bx + dx + w * 0.35, by - h), rgba(110, 96, 86, 220))
    L.haze(mist(rng, 0, SCREEN_W, 660, 140, rgba(255, 255, 250, 150), 10), 30)
    return L.render()[0].convert("RGB")


def cut_accident() -> Image.Image:
    """0-1 오프닝, 사고 뒤 비 오는 밤 길가. 깨진 헤드라이트 빛 속에 둥근 모자와 필름 카메라가 젖은 길에 떨어져 있다.
    사람은 그리지 않는다. 하윤의 물건도 없다(반전을 지킨다)."""
    bg = vertical_gradient(SCREEN_W, [(0.0, (14, 16, 22)), (0.55, (22, 26, 34)), (0.62, (30, 32, 38)), (1.0, (18, 20, 24))])
    add_glow(bg, 1450, 640, 700, (210, 200, 170), 0.35)  # 헤드라이트 빛
    add_glow(bg, 1450, 640, 160, (240, 232, 205), 0.5)
    L = Layer(SCREEN_W, bg)
    rng = random.Random("cut_accident")
    for _ in range(60):  # 젖은 길의 빛 반사
        x, y = rng.uniform(600, 1900), rng.uniform(700, 1060)
        L.line([(x, y), (x + rng.uniform(40, 160), y)], rgba(200, 190, 160, rng.randint(30, 90)), rng.uniform(2, 4))
    L.line([(0, 690), (1920, 640)], rgba(220, 220, 200, 60), 6)  # 길 가장자리 선
    for _ in range(14):  # 깨진 유리 조각
        x, y = rng.uniform(1100, 1600), rng.uniform(760, 900)
        L.poly([(x, y), (x + rng.uniform(6, 16), y - rng.uniform(2, 8)), (x + rng.uniform(4, 12), y + rng.uniform(4, 10))], rgba(220, 225, 230, 160))
    # 둥근 모자(뒤집혀 젖은 길에)
    L.ellipse((640, 860, 860, 910), rgba(48, 44, 42))
    L.ellipse((690, 820, 810, 880), rgba(58, 52, 48))
    # 필름 카메라(조금 떨어져서, 렌즈가 빛을 받는다)
    L.rect(980, 900, 1130, 980, rgba(34, 34, 36))
    L.rect(1000, 885, 1050, 902, rgba(34, 34, 36))
    L.ellipse((1030, 912, 1090, 972), rgba(60, 62, 66))
    L.ellipse((1044, 926, 1076, 958), rgba(150, 150, 140))
    L.line([(1130, 930), (1300, 990), (1420, 970)], rgba(40, 38, 36), 4)  # 끈
    for _ in range(420):  # 빗줄기
        x, y = rng.uniform(0, SCREEN_W), rng.uniform(0, 1080)
        L.line([(x, y), (x - 10, y + rng.uniform(30, 60))], rgba(180, 190, 210, rng.randint(25, 70)), 1.5)
    return L.render()[0].convert("RGB")


CUTS = {"cut_bracelet": cut_bracelet, "cut_boat": cut_boat, "cut_accident": cut_accident}


def build_cuts() -> None:
    out = OUT_DIR / "cut"
    out.mkdir(parents=True, exist_ok=True)
    for name, fn in CUTS.items():
        path = out / f"{name}.png"
        fn().save(path, optimize=True)
        print(f"{path.relative_to(ROOT)}  {path.stat().st_size // 1024} KB")


# ---------------------------------------------------------------- 기억 장면(임시)
# 진짜 기억 장면은 일러스트 담당이 단색 선 스케치로 그린다(장면표 2-2, 3-1, 4-3, 5-4).
# 투명 바탕에 어두운 선만. 게임이 셰이더로 색을 입히고 희미하게 겹친다(shaders/memory.gdshader).

MEM_W, MEM_H = 1600, 900
INK = (52, 44, 38, 255)


class Sketch:
    """흔들리는 손 선. 같은 선을 두 번 살짝 어긋나게 긋는다."""

    def __init__(self, seed: str):
        self.img = Image.new("RGBA", (MEM_W * SS, MEM_H * SS), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)
        self.rng = random.Random(seed)

    def line(self, pts, width: float = 5, passes: int = 2) -> None:
        for k in range(passes):
            j = 3.0 if k else 0.0
            q = [((x + self.rng.uniform(-j, j)) * SS, (y + self.rng.uniform(-j, j)) * SS) for x, y in pts]
            self.d.line(q, fill=INK if k == 0 else INK[:3] + (150,), width=max(1, int(width * SS * (0.6 if k else 1))), joint="curve")

    def curve(self, pts, width: float = 5, n: int = 10) -> None:
        """점 목록을 지나는 부드러운 선(캣멀-롬)."""
        pts = [pts[0]] + list(pts) + [pts[-1]]
        out = []
        for i in range(1, len(pts) - 2):
            p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
            for k in range(n):
                t = k / n
                t2, t3 = t * t, t * t * t
                out.append(tuple(0.5 * (2 * p1[a] + (-p0[a] + p2[a]) * t + (2 * p0[a] - 5 * p1[a] + 4 * p2[a] - p3[a]) * t2
                                       + (-p0[a] + 3 * p1[a] - 3 * p2[a] + p3[a]) * t3) for a in (0, 1)))
        out.append(pts[-2])
        self.line(out, width)

    def circle(self, cx, cy, r, width: float = 5) -> None:
        self.curve([(cx + r * math.cos(a / 12 * math.tau), cy + r * math.sin(a / 12 * math.tau)) for a in range(13)], width)

    def hatch(self, x0, y0, x1, y1, step: float = 9, width: float = 2.5) -> None:
        x = x0
        while x + (y1 - y0) * 0.6 < x1:
            self.line([(x, y1), (x + (y1 - y0) * 0.6, y0)], width, passes=1)
            x += step

    def grass(self, x0, x1, base, lean: float, every: float = 26) -> None:
        x = x0
        while x < x1:
            h = self.rng.uniform(40, 110)
            self.curve([(x, base), (x + lean * 0.3, base - h * 0.6), (x + lean, base - h)], 3)
            x += every * self.rng.uniform(0.6, 1.4)

    def render(self) -> Image.Image:
        return self.img.resize((MEM_W, MEM_H), Image.LANCZOS)


def grandpa_back(S: Sketch, x: float, base: float, arm_to=None) -> None:
    """할아버지 뒷모습: 둥근 모자, 넓은 등, 지팡이 없이 곧게."""
    S.circle(x, base - 400, 42)
    S.curve([(x - 70, base - 430), (x, base - 470), (x + 70, base - 430)], 5)  # 모자
    S.line([(x - 90, base - 432), (x + 90, base - 432)], 5)
    S.curve([(x - 40, base - 360), (x - 95, base - 330), (x - 110, base - 180), (x - 80, base - 150)], 6)
    S.curve([(x + 40, base - 360), (x + 95, base - 330), (x + 110, base - 180), (x + 80, base - 150)], 6)
    S.line([(x - 80, base - 150), (x - 60, base), (x - 20, base)], 6)  # 다리
    S.line([(x + 80, base - 150), (x + 60, base), (x + 20, base)], 6)
    if arm_to:
        S.curve([(x + 90, base - 320), ((x + arm_to[0]) / 2, (base - 320 + arm_to[1]) / 2 - 20), arm_to], 6)
    else:
        S.line([(x + 95, base - 320), (x + 105, base - 190)], 6)
    S.line([(x - 95, base - 320), (x - 108, base - 190)], 6)


def mem_wind() -> Image.Image:
    """2-2 바람을 가리키는 할아버지의 뒷모습. 억새가 한쪽으로 눕는다."""
    S = Sketch("mem_wind")
    S.curve([(0, 760), (400, 720), (900, 700), (1600, 740)], 5)  # 언덕
    S.grass(40, 1560, 760, 60)
    grandpa_back(S, 640, 720, arm_to=(980, 300))
    for k in range(4):  # 바람 결
        y = 200 + k * 90
        x0 = 1000 + k * 40
        S.curve([(x0, y), (x0 + 150, y - 25), (x0 + 300, y + 10), (x0 + 380, y - 30), (x0 + 350, y - 60), (x0 + 310, y - 35)], 3)
    return S.render()


def mem_train() -> Image.Image:
    """3-1 기차 창가에 앉은 젊은 할아버지(옆모습). 창밖으로 들판이 지나간다."""
    S = Sketch("mem_train")
    S.line([(260, 120), (1340, 120), (1340, 640), (260, 640), (260, 120)], 7)  # 창틀
    S.line([(800, 120), (800, 640)], 5)
    S.curve([(260, 520), (600, 480), (1000, 500), (1340, 470)], 3)  # 창밖 언덕
    for x in range(300, 1320, 60):
        S.line([(x, 560 + (x % 3) * 10), (x + 40, 560 + (x % 3) * 10)], 2.5, passes=1)  # 지나가는 선
    S.circle(1060, 340, 22)  # 해
    x, y = 520, 430  # 젊은 할아버지 머리
    S.circle(x, y, 60)
    S.curve([(x - 55, y - 30), (x - 20, y - 75), (x + 40, y - 70), (x + 62, y - 20)], 6)  # 머리칼
    S.curve([(x - 30, y + 60), (x - 120, y + 160), (x - 160, y + 420)], 6)  # 등
    S.curve([(x + 30, y + 60), (x + 70, y + 200), (x + 40, y + 300)], 6)  # 팔
    S.line([(x + 40, y + 300), (x + 60, y + 60)], 6)  # 턱 괸 손
    S.line([(140, 860), (1460, 860)], 6)  # 창 아래 턱
    S.hatch(140, 640, 1460, 860, 26)
    return S.render()


def mem_pup() -> Image.Image:
    """4-3 할아버지와 어린 흰 개. 개의 왼쪽 귀 끝만 짙게(진짜 그림은 갈색) — 하늘이와 같은 무늬."""
    S = Sketch("mem_pup")
    S.curve([(0, 800), (800, 780), (1600, 800)], 4)
    for x in (260, 420, 1200, 1380):  # 빛줄기
        S.line([(x, 0), (x + 120, 780)], 2.5, passes=1)
    gx, base = 640, 790  # 쪼그려 앉은 할아버지(옆모습)
    S.circle(gx, base - 330, 44)
    S.curve([(gx - 72, base - 360), (gx, base - 400), (gx + 72, base - 360)], 5)
    S.line([(gx - 94, base - 362), (gx + 94, base - 362)], 5)
    S.curve([(gx - 30, base - 290), (gx - 110, base - 200), (gx - 90, base - 80)], 6)  # 등
    S.curve([(gx - 90, base - 80), (gx - 20, base - 120), (gx + 80, base - 80), (gx + 60, base)], 6)  # 무릎·정강이
    S.curve([(gx + 20, base - 260), (gx + 130, base - 170), (gx + 220, base - 150)], 6)  # 내민 팔
    S.circle(gx + 240, base - 150, 18, 4)  # 손
    px, py = 960, base  # 어린 개(옆모습, 고개 들어 손을 본다)
    S.curve([(px - 120, py - 70), (px - 60, py - 105), (px + 40, py - 100), (px + 80, py - 80)], 5)  # 등
    S.curve([(px - 120, py - 70), (px - 110, py - 30), (px - 60, py - 20), (px + 40, py - 25), (px + 80, py - 50)], 5)  # 배
    for lx in (-100, -70, 30, 60):
        S.line([(px + lx, py - 25), (px + lx - 4, py)], 5)
    S.curve([(px - 120, py - 70), (px - 160, py - 110), (px - 150, py - 140)], 4)  # 꼬리(흔든다)
    S.curve([(px - 160, py - 105), (px - 180, py - 125)], 3)
    hx, hy = px + 110, py - 130
    S.circle(hx, hy, 42)
    S.curve([(hx + 30, hy + 5), (hx + 75, hy + 15), (hx + 70, hy + 35), (hx + 30, hy + 32)], 4)  # 주둥이
    S.circle(hx + 12, hy - 8, 4, 4)  # 눈
    ear = [(hx - 30, hy - 30), (hx - 50, hy + 30), (hx - 30, hy + 50), (hx - 10, hy - 10)]
    S.curve(ear, 4)  # 왼쪽(화면 앞) 귀
    S.hatch(hx - 52, hy + 22, hx - 26, hy + 52, 6, 2.5)  # 귀 끝 무늬
    return S.render()


def mem_skip() -> Image.Image:
    """5-4 할아버지의 돌이 다섯 번 튄다. 물 위에 동그란 물결 다섯."""
    S = Sketch("mem_skip")
    S.curve([(0, 640), (500, 630), (1100, 640), (1600, 632)], 4)  # 물가
    for k in range(5):
        S.line([(80 + k * 290, 720 + k * 25), (240 + k * 290, 720 + k * 25)], 2.5, passes=1)
    gx, base = 300, 640
    grandpa_back(S, gx, base, arm_to=(gx + 260, base - 260))
    x, y = gx + 280, base - 270
    for i in range(5):  # 튀는 자리
        bx = 760 + i * 150 - i * i * 6
        S.curve([(x, y), ((x + bx) / 2, min(y, 660) - 80 + i * 18), (bx, 680)], 2.5)
        S.curve([(bx - 40 + i * 4, 690), (bx, 676), (bx + 40 - i * 4, 690), (bx, 702), (bx - 40 + i * 4, 690)], 3)
        x, y = bx, 680
    S.circle(x + 60, 690, 9, 4)  # 가라앉는 돌
    return S.render()


MEMORIES = {"mem_wind": mem_wind, "mem_train": mem_train, "mem_pup": mem_pup, "mem_skip": mem_skip}


def build_memories() -> None:
    out = OUT_DIR / "memory"
    out.mkdir(parents=True, exist_ok=True)
    for name, fn in MEMORIES.items():
        path = out / f"{name}.png"
        fn().save(path, optimize=True)
        print(f"{path.relative_to(ROOT)}  {path.stat().st_size // 1024} KB")


# ---------------------------------------------------------------- 움직이는 소품(임시)
# 진짜 소품 그림은 일러스트 담당이 준다(장면표 그림 목록 "움직이거나 바뀌는 소품"). 같은 이름이면 그쪽이 먼저다.


def prop_map_folded() -> Image.Image:
    """접힌 지도(2-3 날아가는 지도도 이 그림). 누런 종이 세 겹 접힘, 연필 길과 붉은 동그라미가 비친다."""
    w, h = 180, 130
    L = Layer(w)
    L.poly([(14, 22), (166, 8), (172, 112), (8, 122)], rgba(222, 196, 146))
    L.poly([(14, 22), (64, 17), (60, 118), (8, 122)], rgba(206, 178, 128))  # 접힌 면 그늘
    L.poly([(116, 12), (166, 8), (172, 112), (120, 115)], rgba(232, 208, 160))
    for xa, ya, xb, yb in ((64, 17, 60, 118), (116, 12, 120, 115)):
        L.line([(xa, ya), (xb, yb)], rgba(150, 120, 80, 200), 2)
    L.line([(24, 96), (52, 70), (90, 84), (130, 50), (156, 60)], rgba(80, 66, 52, 200), 2.4)
    L.line([(91 + 11 * math.cos(a / 10 * math.tau), 81 + 11 * math.sin(a / 10 * math.tau)) for a in range(11)], rgba(184, 76, 66, 220), 2.4)
    img = L.render()[0]
    return img.crop((0, 0, w, h))


def prop_tractor() -> Image.Image:
    """2-4 농부와 경운기 실루엣. 왼쪽으로 간다(앞이 왼쪽). 농부는 앞만 본다(고개를 돌리지 않는다)."""
    w, h = 560, 330
    ink = rgba(70, 58, 48, 235)
    L = Layer(w)
    base = h - 4
    L.ellipse((330, base - 150, 480, base), ink)  # 큰 뒷바퀴
    L.ellipse((368, base - 112, 442, base - 38), rgba(120, 100, 80, 235))
    L.ellipse((40, base - 70, 110, base), ink)  # 앞바퀴
    L.poly([(60, base - 70), (330, base - 110), (340, base - 60), (90, base - 40)], ink)  # 몸통·짐칸 이음
    L.poly([(30, base - 150), (150, base - 160), (160, base - 70), (40, base - 70)], ink)  # 엔진
    L.rect(70, base - 200, 86, base - 150, ink)  # 굴뚝
    L.line([(150, base - 140), (260, base - 210), (300, base - 205)], ink, 8)  # 손잡이
    L.poly([(250, base - 100), (500, base - 112), (520, base - 40), (260, base - 40)], ink)  # 짐칸
    # 농부: 짐칸 앞에 앉아 앞(왼쪽)만 본다. 둥근 밀짚모자.
    L.poly([(272, base - 108), (318, base - 108), (312, base - 200), (276, base - 200)], ink)
    L.ellipse((276, base - 246, 316, base - 204), ink)
    L.ellipse((252, base - 240, 340, base - 222), ink)
    L.line([(282, base - 180), (262, base - 205)], ink, 9)  # 손잡이 잡은 팔
    img = L.render()[0]
    return img.crop((0, 0, w, h))


def prop_persimmon() -> Image.Image:
    """1-6 감나무에서 떨어지는 감 하나. 그림 아래 끝이 땅에 닿는 곳."""
    w, h = 44, 44
    L = Layer(w)
    L.ellipse((3, 8, 41, 43), rgba(226, 112, 34))
    L.ellipse((10, 13, 22, 23), rgba(246, 170, 96, 200))  # 빛
    L.poly([(14, 10), (22, 4), (30, 10), (22, 13)], rgba(86, 96, 48))  # 꼭지
    L.line([(22, 6), (24, 0)], rgba(80, 60, 40), 2.5)
    return L.render()[0].crop((0, 0, w, h))


def _portrait(sitter) -> Image.Image:
    """영정사진 액자: 짙은 나무 테, 흑백 사진, 위 두 모서리에 검은 띠. sitter가 사진 속 사람을 그린다."""
    w, h = 150, 196
    L = Layer(w)
    L.rect(0, 0, w, h, rgba(52, 40, 32))  # 테
    L.rect(12, 12, w - 12, h - 12, rgba(206, 204, 198))  # 사진 바탕
    L.rect(12, 120, w - 12, h - 12, rgba(184, 182, 178))
    sitter(L, w / 2)
    frame = rgba(52, 40, 32)  # 테를 사람 위에 다시(어깨가 테 밖으로 나가지 않게)
    L.rect(0, 0, w, 12, frame)
    L.rect(0, h - 12, w, h, frame)
    L.rect(0, 0, 12, h, frame)
    L.rect(w - 12, 0, w, h, frame)
    for x0, x1 in ((0, 46), (w, w - 46)):  # 검은 띠(리본)
        L.poly([(x0, 0), (x1, 0), (x0, abs(x1 - x0))], rgba(20, 20, 22))
    return L.render()[0].crop((0, 0, w, h))


def prop_portrait_grandpa() -> Image.Image:
    """1-2 할아버지 영정(흑백). 둥근 모자, 넓은 어깨."""
    def sitter(L, cx):
        ink = rgba(70, 68, 66)
        L.ellipse((cx - 50, 128, cx + 50, 230), ink)  # 어깨
        L.ellipse((cx - 26, 70, cx + 26, 128), rgba(150, 146, 140))  # 얼굴
        L.ellipse((cx - 42, 62, cx + 42, 78), ink)  # 모자 챙
        L.ellipse((cx - 24, 40, cx + 24, 74), ink)  # 모자
    return _portrait(sitter)


def prop_portrait_hayun() -> Image.Image:
    """1-2 하윤 영정(흑백). 단발 아이. 게임이 흐리게 했다가 7-8에서 또렷하게 한다."""
    def sitter(L, cx):
        ink = rgba(64, 62, 62)
        L.ellipse((cx - 38, 140, cx + 38, 230), rgba(120, 118, 116))  # 어깨
        L.ellipse((cx - 32, 58, cx + 32, 130), ink)  # 머리카락
        L.ellipse((cx - 23, 74, cx + 23, 132), rgba(168, 164, 158))  # 얼굴
        L.rect(cx - 25, 66, cx + 25, 86, ink)  # 앞머리
    return _portrait(sitter)


def prop_key() -> Image.Image:
    """1-4 액자 뒤에서 찾는 작은 열쇠(주웠을 때 떠오르는 그림). 놋쇠 빛, 둥근 손잡이, 이 두 개. 진한 테두리로 밝은 벽 앞에서도 보이게."""
    w, h = 96, 44
    L = Layer(w)
    edge, brass, shine = rgba(70, 50, 28), rgba(214, 170, 74), rgba(246, 222, 150)
    L.ellipse((2, 4, 40, 40), edge)
    L.ellipse((6, 8, 36, 36), brass)
    L.ellipse((14, 16, 28, 28), edge)  # 고리 구멍
    L.ellipse((16, 18, 26, 26), rgba(0, 0, 0, 0))
    L.rect(34, 17, 92, 27, edge)
    L.rect(36, 19, 90, 25, brass)
    L.rect(70, 25, 78, 38, edge)  # 이
    L.rect(82, 25, 90, 34, edge)
    L.rect(72, 25, 76, 36, brass)
    L.rect(84, 25, 88, 32, brass)
    L.line([(10, 14), (18, 9)], shine, 2.5)
    L.line([(40, 20), (84, 20)], shine, 1.5)
    return L.render()[0].crop((0, 0, w, h))


def prop_thicket() -> Image.Image:
    """4-2 갈림길 끝에서 길을 막는 덤불(하윤 앞에 그린다, Gate.art). 그림 아래 가운데가 땅."""
    w, h = 200, 560  # 폭 200: 벽(입구 셋 끝 +200)에 가운데를 두면 셋째 입구를 가리지 않는다
    L = Layer(w)
    rng = random.Random("thicket")
    for _ in range(40):
        cx, cy, r = rng.uniform(50, w - 50), rng.uniform(140, h - 40), rng.uniform(36, 60)
        L.ellipse((cx - r, cy - r * 0.85, cx + r, cy + r * 0.85), rgba(20, 40, 36))
    for _ in range(30):
        cx, cy, r = rng.uniform(40, w - 40), rng.uniform(120, h - 60), rng.uniform(20, 46)
        L.ellipse((cx - r, cy - r * 0.8, cx + r, cy + r * 0.8), rgba(44, 82, 60))
    for _ in range(14):  # 가시 가지
        x0, y0 = rng.uniform(30, w - 30), rng.uniform(140, h - 40)
        L.line([(x0, y0), (x0 + rng.uniform(-60, 60), y0 - rng.uniform(30, 80))], rgba(30, 30, 24), 4)
    L.rect(20, h - 60, w - 20, h, rgba(20, 40, 36))
    return L.render()[0].crop((0, 0, w, h))


def prop_deer() -> Image.Image:
    """4-1 숲에서 나무 사이로 지나가는 사슴 실루엣(작은 순간). 오른쪽을 본다. 청록 그림자 색."""
    w, h = 240, 230
    L = Layer(w)
    c = rgba(30, 58, 54, 235)
    L.ellipse((50, 92, 182, 152), c)  # 몸통
    L.poly([(160, 104), (196, 46), (214, 52), (186, 118)], c)  # 목
    L.ellipse((188, 30, 230, 62), c)  # 머리
    for x0 in (62, 82, 150, 168):  # 다리
        L.rect(x0, 140, x0 + 9, 226, c)
    L.line([(204, 34), (194, 6), (184, 0)], c, 4)  # 뿔
    L.line([(212, 34), (220, 8), (230, 2)], c, 4)
    L.line([(196, 18), (186, 14)], c, 3)
    L.ellipse((40, 96, 58, 112), c)  # 꼬리
    return L.render()[0].crop((0, 0, w, h))


def prop_heron() -> Image.Image:
    """5-3~5-4 강가 물안개에서 날아오르는 왜가리(작은 순간). 오른쪽으로 난다. 푸른 회색."""
    w, h = 200, 110
    L = Layer(w)
    c, d = rgba(150, 164, 176, 235), rgba(84, 96, 110, 235)
    L.poly([(30, 40), (110, 8), (150, 30), (100, 46)], c)  # 위 날개
    L.poly([(40, 62), (120, 96), (150, 70), (100, 58)], d)  # 아래 날개
    L.ellipse((80, 44, 150, 66), c)  # 몸통
    L.line([(148, 52), (170, 46), (178, 54)], c, 6)  # 목(접힘)
    L.poly([(176, 50), (198, 54), (176, 58)], rgba(196, 160, 80, 235))  # 부리
    L.line([(82, 58), (20, 66)], d, 3)  # 다리
    return L.render()[0].crop((0, 0, w, h))


def prop_dragonfly() -> Image.Image:
    """2-4 들판에서 하윤 주위를 도는 고추잠자리(작은 순간). 오른쪽을 본다."""
    w, h = 54, 30
    L = Layer(w)
    L.ellipse((6, 2, 30, 13), rgba(240, 244, 236, 170))  # 날개
    L.ellipse((24, 2, 46, 13), rgba(240, 244, 236, 170))
    L.ellipse((6, 15, 28, 26), rgba(240, 244, 236, 150))
    L.ellipse((26, 15, 46, 26), rgba(240, 244, 236, 150))
    L.line([(4, 15), (44, 14)], rgba(206, 70, 46), 4)  # 몸
    L.ellipse((42, 10, 52, 19), rgba(170, 52, 36))  # 머리
    return L.render()[0].crop((0, 0, w, h))


PROPS = {"prop_map_folded": prop_map_folded, "prop_key": prop_key, "prop_thicket": prop_thicket,
         "prop_deer": prop_deer, "prop_heron": prop_heron, "prop_dragonfly": prop_dragonfly, "prop_tractor": prop_tractor, "prop_persimmon": prop_persimmon,
         "prop_portrait_grandpa": prop_portrait_grandpa, "prop_portrait_hayun": prop_portrait_hayun}


def build_props() -> None:
    out = OUT_DIR / "prop"
    out.mkdir(parents=True, exist_ok=True)
    for name, fn in PROPS.items():
        path = out / f"{name}.png"
        fn().save(path, optimize=True)
        print(f"{path.relative_to(ROOT)}  {path.stat().st_size // 1024} KB")


# ---------------------------------------------------------------- 실행

PAINTERS = {
    "house": house, "field": field, "station": station, "forest": forest,
    "riverside": riverside, "bridge": bridge, "ferry": ferry, "crossing": crossing,
}


def build(place_id: str) -> None:
    width, markers = read_place(place_id)
    layers = PAINTERS[place_id](width, markers)
    out = OUT_DIR / place_id
    out.mkdir(parents=True, exist_ok=True)
    for old in out.glob(f"bg_{place_id}_*.png"):
        old.unlink()
    for name, layer in layers.items():
        tiles = layer.render()
        for i, tile in enumerate(tiles):
            suffix = f"_{i + 1:02d}" if len(tiles) > 1 else ""
            path = out / f"bg_{place_id}_{name}{suffix}.png"
            tile.save(path, optimize=True)
            print(f"{path.relative_to(ROOT)}  {tile.width}x{tile.height}  {path.stat().st_size // 1024} KB")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("places", nargs="*", help="place_id (그릴 수 있는 것: %s)" % ", ".join(PAINTERS))
    parser.add_argument("--all", action="store_true")
    args = parser.parse_args()
    places = list(PAINTERS) + ["cut", "memory", "prop"] if args.all else args.places
    if not places:
        parser.error("장소를 하나 이상 적거나 --all")
    for p in places:
        if p == "cut":  # 손그림 컷신 자리(임시)
            build_cuts()
            continue
        if p == "memory":  # 기억 장면 자리(임시)
            build_memories()
            continue
        if p == "prop":  # 움직이는 소품(임시)
            build_props()
            continue
        if p not in PAINTERS:
            sys.exit(f"'{p}'은 아직 그릴 수 없다 (있는 것: {', '.join(PAINTERS)})")
        build(p)
    return 0


if __name__ == "__main__":
    sys.exit(main())
