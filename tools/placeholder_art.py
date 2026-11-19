#!/usr/bin/env python3
"""코드로 그리는 임시 배경. 진짜 그림이 오기 전까지 회색 네모 대신 쓴다.

    python3 tools/placeholder_art.py field        # 장소 하나
    python3 tools/placeholder_art.py --all        # 그릴 수 있는 장소 전부

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
        self.blur_groups: list[tuple[list[tuple], float]] = []  # (도형들, 흐림 반지름)

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

    def _render_tile(self, x0: int, w: int) -> Image.Image:
        big = Image.new("RGBA", (w * SS, H * SS), (0, 0, 0, 0))
        for shapes, radius in self.blur_groups:
            # 투명한 곳(검정)이 섞여 번지지 않게, 모양(알파)만 흐리고 색은 한 가지로 칠한다.
            color = shapes[0][2]
            mask = Image.new("RGBA", big.size, (0, 0, 0, 0))
            self._draw(mask, [(s[0], s[1], (255, 255, 255, s[2][3])) + s[3:] for s in shapes], x0)
            alpha = mask.getchannel("A").filter(ImageFilter.GaussianBlur(radius * SS))
            soft = Image.new("RGBA", big.size, color[:3] + (0,))
            soft.putalpha(alpha)
            big = Image.alpha_composite(big, soft)
        self._draw(big, self.shapes, x0)
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


def reed_clump(L: Layer, rng: random.Random, x: float, scale: float) -> None:
    """억새 한 덤불: 줄기 여럿 + 끝의 은빛·금빛 이삭. 바람에 왼쪽으로 기운다."""
    stem, plume_a, plume_b = rgba(150, 128, 84), rgba(236, 226, 196), rgba(222, 196, 140)
    for _ in range(int(rng.randint(9, 16) * scale)):
        bx = x + rng.gauss(0, 50 * scale)
        h = rng.uniform(260, 470) * scale
        lean = rng.uniform(-110, -20) * scale
        pts = []
        for i in range(13):
            t = i / 12
            pts.append((bx + lean * t * t, H + 10 - h * t))
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
            L.line(sag(lx, H + 10, lx + rng.choice((-1, 1)) * rng.uniform(80, 160) * scale, H - rng.uniform(90, 200) * scale, -30 * scale, 8), stem, 4 * scale)


# ---------------------------------------------------------------- 실행

PAINTERS = {"field": field}


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
    places = list(PAINTERS) if args.all else args.places
    if not places:
        parser.error("장소를 하나 이상 적거나 --all")
    for p in places:
        if p not in PAINTERS:
            sys.exit(f"'{p}'은 아직 그릴 수 없다 (있는 것: {', '.join(PAINTERS)})")
        build(p)
    return 0


if __name__ == "__main__":
    sys.exit(main())
