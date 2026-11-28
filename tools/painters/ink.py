"""선과 두 톤 그늘로 그리는 바탕 (#151).

컷신 `cut_map`(일러스트 담당) 화풍을 따른다: 따뜻한 갈색 윤곽선, 평면 색 + 그늘 한 톤,
창으로 드는 금빛 빛줄기·바닥의 빛 웅덩이·떠다니는 먼지와 빛망울.
예전 바탕(`placeholder_art.Layer` + `painterly`)은 회색 상자 배치에 질감을 덧칠한 것이라 화풍이 안 맞았다.

쓰는 법:
    c = Ink(층 폭)                 # 2배로 그린다
    c.poly(점들, 칠, 선=True)      # 칠하고 윤곽선
    c.glaze(lambda d, s: ...)       # 반투명 덧칠(합성)
    img = c.finish()                # 1배로 줄인 RGBA
    img = light(img, 빛 지도, ...)  # 빛·그늘 입히기(numpy)
    layer = as_layer(img)           # placeholder_art.Layer로 (tools/placeholder_art.py build가 저장)
"""
from __future__ import annotations

import math
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import placeholder_art as pa

S = 2  # 2배로 그려 줄인다
H = 1080

LINE = (92, 56, 36, 255)        # 기본 윤곽선(따뜻한 갈색)
LINE_SOFT = (128, 86, 58, 255)  # 빛 쪽·먼 것의 옅은 선


def mix(a, b, t: float):
    """두 색 섞기(알파는 a)."""
    out = tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))
    return out + ((a[3],) if len(a) == 4 else (255,))


def dark(c, k: float = 0.22, tint=(70, 50, 80)):
    """그늘 한 톤: 어둡게 + 보랏빛 쪽으로."""
    return mix(mix(c, (0, 0, 0), k), tint, k * 0.5)


def lite(c, k: float = 0.25, tint=(255, 226, 170)):
    """빛 받은 면: 밝고 꿀빛 쪽으로."""
    return mix(c, tint, k)


def alpha(c, a: int):
    return tuple(c[:3]) + (a,)


class Ink:
    def __init__(self, width: int, height: int = H):
        self.w, self.h = int(width), int(height)
        self.img = Image.new("RGBA", (self.w * S, self.h * S), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)
        self.lc = LINE
        self.lw = 2.4
        self.casters: list[list[tuple[float, float]]] = []  # 그림자·가장자리 빛을 만들 모양(cast=True로 그린 것)

    # ------------------------------------------------------------ 기본 도형
    @staticmethod
    def _p(pts):
        return [(x * S, y * S) for x, y in pts]

    def _visible(self, xs) -> bool:
        return max(xs) >= -40 and min(xs) <= self.w + 40

    def poly(self, pts, fill=None, line=True, lw=None, lc=None, cast=False):
        if not self._visible([p[0] for p in pts]):
            return
        if cast:
            self.casters.append(list(pts))
        if fill is not None:
            if len(fill) == 4 and fill[3] < 255:
                self.glaze(lambda d, s: d.polygon(s(pts), fill=fill), _bbox(pts))
            else:
                self.d.polygon(self._p(pts), fill=fill)
        if line:
            self.stroke(list(pts) + [pts[0]], lw, lc)

    def rect(self, x0, y0, x1, y1, fill=None, line=True, lw=None, lc=None, cast=False):
        self.poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], fill, line, lw, lc, cast)

    def rrect(self, x0, y0, x1, y1, r, fill=None, line=True, lw=None, lc=None, cast=False):
        self.poly(round_rect_pts(x0, y0, x1, y1, r), fill, line, lw, lc, cast)

    def grad(self, pts, c0, c1, axis: str = "y", line=True, lw=None, lc=None, cast=False, power: float = 1.0):
        """그라데이션 칠: c0(위·왼쪽) → c1(아래·오른쪽). 부피가 보이게 쓴다."""
        if not self._visible([p[0] for p in pts]):
            return
        if cast:
            self.casters.append(list(pts))
        bx0, by0, bx1, by1 = _bbox(pts)
        X0, Y0 = max(0, int(bx0 * S)), max(0, int(by0 * S))
        X1, Y1 = min(self.img.width, int(math.ceil(bx1 * S)) + 1), min(self.img.height, int(math.ceil(by1 * S)) + 1)
        if X1 <= X0 or Y1 <= Y0:
            return
        w, h = X1 - X0, Y1 - Y0
        mask = Image.new("L", (w, h), 0)
        ImageDraw.Draw(mask).polygon([(x * S - X0, y * S - Y0) for x, y in pts], fill=255)
        if axis == "y":
            t = np.linspace(0, 1, h, dtype=np.float32)[:, None].repeat(w, 1)
        else:
            t = np.linspace(0, 1, w, dtype=np.float32)[None, :].repeat(h, 0)
        t = t ** power
        a, b = np.array(c0[:3], np.float32), np.array(c1[:3], np.float32)
        rgb = a + (b - a) * t[:, :, None]
        tile = np.concatenate([rgb, np.full((h, w, 1), 255, np.float32)], axis=2).astype(np.uint8)
        g = Image.fromarray(tile, "RGBA")
        g.putalpha(mask)
        self.img.alpha_composite(g, dest=(X0, Y0))
        if line:
            self.stroke(list(pts) + [pts[0]], lw, lc)

    def ellipse(self, x0, y0, x1, y1, fill=None, line=True, lw=None, lc=None, cast=False):
        self.poly(ellipse_pts(x0, y0, x1, y1), fill, line, lw, lc, cast)

    def stroke(self, pts, lw=None, lc=None):
        """선(둥근 끝). lc의 알파가 255보다 작으면 합성한다."""
        if len(pts) < 2 or not self._visible([p[0] for p in pts]):
            return
        c = lc or self.lc
        w = max(1, round((lw or self.lw) * S))

        def draw(d, s):
            q = s(pts)
            d.line(q, fill=c, width=w, joint="curve")
            r = w / 2
            for x, y in (q[0], q[-1]):
                d.ellipse((x - r, y - r, x + r, y + r), fill=c)

        if len(c) == 4 and c[3] < 255:
            self.glaze(draw, _bbox(pts, (lw or self.lw) + 2))
        else:
            draw(self.d, self._p)

    def glaze(self, fn, box=None, blur: float = 0.0):
        """반투명 덧칠. fn(draw, 좌표변환)으로 따로 그려 합성한다(ImageDraw는 알파를 덮어쓴다).
        box = 그릴 곳(1배 x0, y0, x1, y1). 그 크기만 새로 만들어 빠르다."""
        pad = blur * 3 + 6
        if box is None:
            box = (0, 0, self.w, self.h)
        bx0 = max(0, int((box[0] - pad) * S))
        by0 = max(0, int((box[1] - pad) * S))
        bx1 = min(self.img.width, int(math.ceil((box[2] + pad) * S)))
        by1 = min(self.img.height, int(math.ceil((box[3] + pad) * S)))
        if bx1 <= bx0 or by1 <= by0:
            return
        over = Image.new("RGBA", (bx1 - bx0, by1 - by0), (0, 0, 0, 0))
        fn(ImageDraw.Draw(over), lambda pts: [(x * S - bx0, y * S - by0) for x, y in pts])
        if blur > 0:
            over = over.filter(ImageFilter.GaussianBlur(blur * S))
        self.img.alpha_composite(over, dest=(bx0, by0))

    def erase(self, pts, keep: int = 0):
        """구멍 뚫기(창 유리처럼 뒤 층이 비칠 곳). keep = 남길 알파."""
        mask = Image.new("L", self.img.size, 0)
        ImageDraw.Draw(mask).polygon(self._p(pts), fill=255)
        a = np.asarray(self.img.getchannel("A")).copy()
        m = np.asarray(mask) > 0
        a[m] = np.minimum(a[m], keep)
        self.img.putalpha(Image.fromarray(a))

    # ------------------------------------------------------------ 결·자잘한 것
    def grain(self, rng: random.Random, x0, y0, x1, y1, color, n: int, vertical: bool = False, lw: float = 1.0):
        """나뭇결: 가늘고 옅은 물결선."""
        def draw(d, s):
            for _ in range(n):
                if vertical:
                    x = rng.uniform(x0 + 3, x1 - 3)
                    ya = rng.uniform(y0, y1)
                    yb = min(y1, ya + rng.uniform(40, 220))
                    pts = [(x + math.sin(t * 0.9 + x) * 1.6, ya + (yb - ya) * t / 6) for t in range(7)]
                else:
                    y = rng.uniform(y0 + 2, y1 - 2)
                    xa = rng.uniform(x0, x1)
                    xb = min(x1, xa + rng.uniform(40, 260))
                    pts = [(xa + (xb - xa) * t / 6, y + math.sin(t * 0.9 + y) * 1.4) for t in range(7)]
                d.line(s(pts), fill=color, width=max(1, round(lw * S)))
        self.glaze(draw, (x0, y0, x1 + 260, y1 + 220))

    def planks_v(self, rng, x0, y0, x1, y1, base, step=64, jitter=10, seam=None, grain_n=2):
        """세로 판자 벽."""
        x = x0
        seam = seam or alpha(dark(base, 0.35), 255)
        while x < x1:
            w = step + rng.uniform(-jitter, jitter)
            xb = min(x1, x + w)
            c = mix(base, dark(base, 0.12) if rng.random() < 0.5 else lite(base, 0.08), rng.uniform(0.2, 0.9))
            self.rect(x, y0, xb, y1, c, line=False)
            self.grain(rng, x, y0, xb, y1, alpha(dark(c, 0.3), 70), grain_n, vertical=True)
            self.stroke([(xb, y0), (xb, y1)], 1.6, seam)
            x = xb

    def planks_h(self, rng, x0, y0, x1, y1, base, rows, seam=None, joint=(180, 420)):
        """가로 판자 바닥: 아래로 갈수록 판이 넓어진다(조금 내려다본 바닥)."""
        seam = seam or dark(base, 0.4)
        ys = [y0]
        total = sum(1.0 + i * 0.22 for i in range(rows))
        y = y0
        for i in range(rows):
            y += (y1 - y0) * (1.0 + i * 0.22) / total
            ys.append(y)
        for i, (ya, yb) in enumerate(zip(ys, ys[1:])):
            x = x0 - rng.uniform(0, joint[1])
            while x < x1:
                xb = x + rng.uniform(*joint) * (1 + i * 0.25)
                c = mix(base, dark(base, 0.14) if rng.random() < 0.5 else lite(base, 0.1), rng.uniform(0.15, 0.85))
                self.rect(max(x, x0), ya, min(xb, x1), yb, c, line=False)
                self.grain(rng, max(x, x0), ya, min(xb, x1), yb, alpha(dark(c, 0.3), 60), 2)
                if x0 < xb < x1:
                    self.stroke([(xb, ya + 1), (xb, yb - 1)], 1.4, seam)
                x = xb
            self.stroke([(x0, yb), (x1, yb)], 1.6, seam)

    # ------------------------------------------------------------ 마무리
    def finish(self) -> Image.Image:
        return self.img.resize((self.w, self.h), Image.LANCZOS)


def _bbox(pts, pad: float = 0.0):
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    return (min(xs) - pad, min(ys) - pad, max(xs) + pad, max(ys) + pad)


def caster_mask(casters, width: int, height: int = H) -> np.ndarray:
    """cast=True로 그린 모양들의 가림막(0~1, 1배)."""
    m = Image.new("L", (width, height), 0)
    d = ImageDraw.Draw(m)
    for pts in casters:
        d.polygon(pts, fill=255)
    return np.asarray(m, np.float32) / 255.0


def drop_shadow(lm: "LightMap", casters, dx: float, dy: float, blur: float, amount: float):
    """빛 반대쪽으로 비켜 깐 흐린 그림자(물건이 벽에 드리우는 그림자)."""
    for pts in casters:
        lm.add([(x + dx, y + dy) for x, y in pts], -amount, blur)


def rim_light(img: Image.Image, casters, dx: int = -4, dy: int = -4, color=(255, 230, 180), strength: float = 0.55, blur: float = 1.2):
    """빛 쪽(dx, dy) 가장자리를 밝힌다: 모양 안이면서 빛 쪽 이웃이 모양 밖인 자리."""
    m = caster_mask(casters, img.width, img.height)
    sh = np.zeros_like(m)
    h, w = m.shape
    ys0, ys1 = max(0, dy), h + min(0, dy)
    xs0, xs1 = max(0, dx), w + min(0, dx)
    sh[ys0:ys1, xs0:xs1] = m[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx]
    edge = np.clip(m - sh, 0, 1)
    edge = np.asarray(Image.fromarray((edge * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(blur)), np.float32) / 255.0
    edge *= m
    arr = np.asarray(img).astype(np.float32) / 255.0
    c = np.array(color, np.float32) / 255.0
    k = (edge * strength)[:, :, None]
    arr[:, :, :3] = 1 - (1 - arr[:, :, :3]) * (1 - c * k)
    return Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")


def to_plane(img: Image.Image, s: float, out_w: int, vp=(960.0, 210.0)) -> Image.Image:
    """세계 크기(하윤 줄, 깊이 1)로 그린 그림을 깊이 s의 층 그림으로: 소실점을 축으로 s배.
    층 좌표 u = s·p + 960(1-s), y = s·y + 210(1-s) — Parallax2D(scroll s)와 RoomPerspective가 쓰는 셈과 같다."""
    w, h = round(img.width * s), round(img.height * s)
    scaled = img.resize((w, h), Image.LANCZOS)
    out = Image.new("RGBA", (out_w, H), (0, 0, 0, 0))
    ox, oy = round(vp[0] * (1 - s)), round(vp[1] * (1 - s))
    out.alpha_composite(scaled.crop((max(0, -ox), max(0, -oy), min(w, out_w - ox), min(h, H - oy))), dest=(max(0, ox), max(0, oy)))
    return out


def plane_noise(width: int, height: int, seed: int, scale: float, amount: float) -> np.ndarray:
    """큰 얼룩(회반죽·흙 결): 1 ± amount. 작게 만들어 늘려 부드럽다."""
    rng = np.random.default_rng(seed)
    sw, sh = max(2, int(width / scale)), max(2, int(height / scale))
    small = rng.random((sh, sw)).astype(np.float32)
    img = Image.fromarray((small * 255).astype(np.uint8)).resize((width, height), Image.BICUBIC).filter(ImageFilter.GaussianBlur(scale * 0.3))
    return 1 + (np.asarray(img, np.float32) / 255.0 - 0.5) * 2 * amount


def round_rect_pts(x0, y0, x1, y1, r, n: int = 5):
    r = min(r, (x1 - x0) / 2, (y1 - y0) / 2)
    pts = []
    for cx, cy, a0 in ((x1 - r, y0 + r, -90), (x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180)):
        for k in range(n + 1):
            a = math.radians(a0 + 90 * k / n)
            pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def ellipse_pts(x0, y0, x1, y1, n: int = 40):
    cx, cy, rx, ry = (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2, (y1 - y0) / 2
    return [(cx + math.cos(2 * math.pi * k / n) * rx, cy + math.sin(2 * math.pi * k / n) * ry) for k in range(n)]


# ---------------------------------------------------------------- 빛


class LightMap:
    """빛 지도(0 = 그늘, 1 = 보통, 1보다 크면 햇빛). 1/4 크기로 그려 흐려 늘린다."""

    Q = 4

    def __init__(self, width: int, base: float, height: int = H):
        self.w = width
        self.h = height
        self.img = Image.new("F", (math.ceil(width / self.Q), math.ceil(height / self.Q)), base)
        self.adds: list[tuple[Image.Image, float]] = []

    def _q(self, pts):
        return [(x / self.Q, y / self.Q) for x, y in pts]

    def add(self, pts, amount: float, blur: float):
        """모양 안을 amount만큼 더한다(흐림 반지름 blur px, 1배 기준)."""
        m = Image.new("L", self.img.size, 0)
        ImageDraw.Draw(m).polygon(self._q(pts), fill=255)
        if blur > 0:
            m = m.filter(ImageFilter.GaussianBlur(blur / self.Q))
        self.adds.append((m, amount))

    def glow(self, cx, cy, rx, ry, amount, blur=None):
        self.add(ellipse_pts(cx - rx, cy - ry, cx + rx, cy + ry), amount, blur if blur is not None else min(rx, ry) * 0.8)

    def array(self) -> np.ndarray:
        a = np.asarray(self.img, np.float32).copy()
        for m, amount in self.adds:
            a += np.asarray(m, np.float32) / 255.0 * amount
        img = Image.fromarray(a, "F").resize((self.w, self.h), Image.BILINEAR)
        return np.asarray(img, np.float32)


def light(img: Image.Image, lm: np.ndarray, sun=(255, 214, 150), shade=(92, 70, 110), strength: float = 1.0) -> Image.Image:
    """빛 지도대로 색을 바꾼다. 1 = 그대로, 0 = 보랏빛 그늘, 1 넘으면 꿀빛으로 밝게(가장자리는 하얗게 타지 않게 눌러 줌)."""
    arr = np.asarray(img).astype(np.float32) / 255.0
    rgb, a = arr[:, :, :3], arr[:, :, 3:]
    L = lm[:, :, None]
    sh = np.array(shade, np.float32) / 255.0
    su = np.array(sun, np.float32) / 255.0
    dk = np.clip(1.0 - L, 0, 1) * strength
    rgb = rgb * (1 - dk * 0.72) + rgb * sh * dk * 0.72 * 1.25
    br = np.clip(L - 1.0, 0, 2) * strength
    rgb = 1 - (1 - rgb) * (1 - su * br * 0.6)  # 스크린 섞기: 꿀빛으로 밝게
    out = np.concatenate([np.clip(rgb, 0, 1), a], axis=2)
    return Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA")


def rays(width: int, beams, color=(255, 222, 160), blur: float = 26.0) -> Image.Image:
    """빛줄기 층(반투명 RGBA): beams = [(점들, 세기 0~1)]. 위가 진하고 아래로 갈수록 옅어진다."""
    q = 2
    m = Image.new("L", (math.ceil(width / q), math.ceil(H / q)), 0)
    for pts, a in beams:
        layer = Image.new("L", m.size, 0)
        ImageDraw.Draw(layer).polygon([(x / q, y / q) for x, y in pts], fill=int(255 * a))
        m = Image.fromarray(np.maximum(np.asarray(m), np.asarray(layer)))
    m = m.filter(ImageFilter.GaussianBlur(blur / q)).resize((width, H), Image.BILINEAR)
    a = np.asarray(m, np.float32) / 255.0
    fade = np.linspace(1.0, 0.45, H, dtype=np.float32)[:, None]
    a = a * fade
    out = np.zeros((H, width, 4), np.float32)
    out[:, :, :3] = np.array(color, np.float32)
    out[:, :, 3] = a * 255 * 0.7
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def bokeh(img: Image.Image, rng: random.Random, n: int, x0, x1, y0, y1, color=(255, 236, 196), r=(14, 46), a=(18, 52)):
    """빛망울: 옅은 원(가장자리가 조금 더 진하다)."""
    over = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    for _ in range(n):
        x, y, rr = rng.uniform(x0, x1), rng.uniform(y0, y1), rng.uniform(*r)
        al = int(rng.uniform(*a))
        d.ellipse((x - rr, y - rr, x + rr, y + rr), fill=color + (al,))
    over = over.filter(ImageFilter.GaussianBlur(3.0))
    img.alpha_composite(over)
    return img


def motes(img: Image.Image, rng: random.Random, n: int, area_pts, color=(255, 240, 206)):
    """빛줄기 속 먼지 알갱이."""
    xs = [p[0] for p in area_pts]
    ys = [p[1] for p in area_pts]
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon(area_pts, fill=255)
    over = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    for _ in range(n):
        x, y = rng.uniform(min(xs), max(xs)), rng.uniform(min(ys), max(ys))
        if not (0 <= x < img.width and 0 <= y < img.height) or mask.getpixel((int(x), int(y))) == 0:
            continue
        r = rng.uniform(0.6, 1.5)
        d.ellipse((x - r, y - r, x + r, y + r), fill=color + (int(rng.uniform(60, 170)),))
    img.alpha_composite(over.filter(ImageFilter.GaussianBlur(0.6)))
    return img


def soften(img: Image.Image, radius: float) -> Image.Image:
    """초점이 나간 듯 흐리기(미리 곱한 알파로, 가장자리가 검게 번지지 않게)."""
    pm = np.asarray(img).astype(np.float32)
    pm[:, :, :3] *= pm[:, :, 3:4] / 255.0
    bl = np.asarray(Image.fromarray(pm.astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(radius))).astype(np.float32)
    al = np.maximum(bl[:, :, 3:4], 1e-3)
    bl[:, :, :3] = np.where(al > 1, bl[:, :, :3] * 255.0 / al, 0)
    return Image.fromarray(np.clip(bl, 0, 255).astype(np.uint8), "RGBA")


def as_layer(img: Image.Image, width: int | None = None) -> pa.Layer:
    """다 그린 그림을 placeholder_art.Layer로(도형 없이 바탕만)."""
    w = width or img.width
    if img.width < w:
        full = Image.new("RGBA", (w, H), (0, 0, 0, 0))
        full.alpha_composite(img)
        img = full
    return pa.Layer(w, background=img.crop((0, 0, w, H)))
