"""5. 강가 (실루엣 화풍, #140).

푸른 황혼. 해는 왼쪽 산 너머로 졌고, 지평선만 분홍빛으로 남았다. 넓은 강이 하늘을 비추고, 물 위에 은빛 물안개.
건너편 둑에는 버드나무와 물레방앗간, 멀리 돌다리와 불 켜진 마을. 유럽 동화풍(#136).

게임 자리와 맞춘 것(바꾸면 장소 씬 부품도 같이):
- 땅 층: 조약돌 길 792~864, 그 앞은 물. 5-2 얕은 물가(물그림자 Reflection_5-2, 물 위 선 y 816),
  5-3 징검다리(x ± 480, 돌 자리 그대로), 5-4 여울(물수제비, 가운데 층 물결).
- 가운데 층 물(648~)에서 물수제비 돌이 튄다.
"""

from __future__ import annotations

import math
import random

import placeholder_art as pa
from placeholder_art import Layer, rgba, H

HAZE = (176, 182, 210)      # 물안개·먼 층이 녹는 색
LIGHT = (255, 214, 196)     # 노을 남은 빛
SHADE = (66, 80, 138)


def fog(c: tuple[int, int, int], t: float, a: int = 255):
    return rgba(*(round(c[i] + (HAZE[i] - c[i]) * t) for i in range(3)), a)


def willow(L: Layer, rng: random.Random, x: float, base: float, h: float, body, lit=None) -> None:
    """버드나무: 굽은 줄기 위로 넓게 퍼진 머리, 가장자리에서 가는 가지가 커튼처럼 물가까지 늘어진다."""
    L.poly([(x - h * 0.05, base), (x + h * 0.06, base), (x + h * 0.1, base - h * 0.5), (x + h * 0.02, base - h * 0.5)], body)
    cx, top = x + h * 0.06, base - h * 0.92
    crown_w = h * 0.55
    for _ in range(10):  # 머리: 위는 둥글고 옆·아래로 처지는 덩어리
        r = h * rng.uniform(0.1, 0.18)
        bx = cx + rng.uniform(-1, 1) * crown_w * 0.7
        by = top + h * 0.12 + abs(bx - cx) / crown_w * h * 0.2 + rng.uniform(-0.05, 0.05) * h
        L.ellipse((bx - r, by - r * 0.8, bx + r, by + r * 1.1), body)
    for _ in range(int(h * 0.9)):  # 늘어진 가지: 머리 가장자리에서 아래로, 바깥일수록 길게
        u = rng.uniform(-1, 1)
        sx = cx + u * crown_w * 0.85
        sy = top + h * 0.12 + abs(u) * h * 0.18 + rng.uniform(-6, 10)
        ln = (base - sy) * rng.uniform(0.55, 1.0) * (0.6 + abs(u) * 0.4)
        L.line([(sx, sy), (sx + u * 4 + rng.uniform(-3, 3), sy + ln * 0.5), (sx + u * 8 + rng.uniform(-4, 4), sy + ln)],
               body, max(1.2, h * 0.008))
    if lit is not None:  # 하늘빛 받은 머리 위
        for _ in range(5):
            r = h * rng.uniform(0.05, 0.08)
            bx, by = cx + rng.uniform(-0.6, 0.3) * crown_w, top + h * rng.uniform(0.02, 0.08)
            L.ellipse((bx - r, by - r * 0.45, bx + r, by + r * 0.45), lit)


def mill(L: Layer, x: float, base: float, s: float, wall, roof, wheel, window) -> None:
    """물레방앗간: 돌벽, 가파른 지붕, 물가의 큰 바퀴, 불 켜진 창."""
    w, h = 150 * s, 90 * s
    L.rect(x, base - h, x + w, base, wall)
    L.poly([(x - 12 * s, base - h), (x + w * 0.5, base - h - 70 * s), (x + w + 12 * s, base - h)], roof)
    L.rect(x + w * 0.7, base - h - 60 * s, x + w * 0.8, base - h - 20 * s, roof)  # 굴뚝
    for wx in (x + w * 0.2, x + w * 0.55):
        L.rect(wx, base - h * 0.62, wx + 20 * s, base - h * 0.3, window)
    cx, cy, r = x - 30 * s, base - 30 * s, 62 * s
    L.ellipse((cx - r, cy - r, cx + r, cy + r), wheel)
    L.ellipse((cx - r * 0.78, cy - r * 0.78, cx + r * 0.78, cy + r * 0.78), wall)
    for k in range(8):
        a = k * math.pi / 4
        L.line([(cx, cy), (cx + math.cos(a) * r, cy + math.sin(a) * r)], wheel, 4 * s)


def stone_bridge(L: Layer, x: float, base: float, w: float, body, dark) -> None:
    """먼 돌다리: 아치 셋."""
    L.rect(x, base - 60, x + w, base - 40, body)
    for k in range(3):
        ax = x + w * (k + 0.5) / 3
        aw = w / 3 * 0.8
        L.rect(ax - aw / 2 - 6, base - 44, ax - aw / 2 + 4, base + 6, body)
        L.rect(ax + aw / 2 - 4, base - 44, ax + aw / 2 + 6, base + 6, body)
        L.ellipse((ax - aw / 2, base - 44, ax + aw / 2, base + 28), dark)


def reeds(L: Layer, rng: random.Random, x: float, base: float, scale: float, stem, head, n: int | None = None) -> None:
    """부들·갈대: 가는 잎이 휘고, 몇 줄기 끝에 갈색 부들 이삭."""
    for _ in range(n or rng.randint(10, 18)):
        bx = x + rng.gauss(0, 36 * scale)
        h = rng.uniform(160, 360) * scale
        lean = rng.uniform(-40, 30) * scale
        pts = [(bx + lean * t * t, base - h * t) for t in (0, 0.33, 0.66, 1.0)]
        L.line(pts, stem, max(1.4, 2.6 * scale))
        if rng.random() < 0.35:
            tx, ty = pts[-1]
            L.line([(tx, ty + 6 * scale), (tx - lean * 0.05, ty + 54 * scale)], head, 8 * scale)


def ripples(L: Layer, rng: random.Random, x0: float, x1: float, y0: float, y1: float, n: int, color, length=(30, 160)) -> None:
    """물결 반짝임: 가로로 긴 짧은 획, 멀수록(위) 짧고 가늘다."""
    for _ in range(n):
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        t = (y - y0) / max(y1 - y0, 1)
        ln = rng.uniform(*length) * (0.4 + t)
        L.line([(x, y), (x + ln, y + rng.uniform(-0.5, 0.5))], color, 1.0 + t * 2.2)


def paint(width: float, markers: dict[str, float]) -> dict[str, Layer]:
    rng = random.Random("riverside")
    mk = markers.get
    layers: dict[str, Layer] = {}

    # 하늘: 위는 짙은 푸른 저녁, 지평선은 분홍·살구빛. 해 진 쪽(왼쪽)이 밝다. 초승달과 이른 별.
    w = pa.layer_width(width, "sky")
    sky = pa.vertical_gradient(w, [
        (0.0, (30, 42, 86)), (0.3, (74, 96, 150)), (0.5, (150, 156, 196)),
        (0.6, (226, 196, 196)), (0.66, (246, 206, 180)), (1.0, (150, 158, 190)),
    ])
    pa.add_glow(sky, w * 0.18, 640, 1100, (255, 196, 170), 0.5)
    pa.paint_clouds(sky, random.Random("riverside_clouds"), 6, w, 200, 420, (w * 0.18, 660),
                    lit=(246, 212, 210), shade=(110, 116, 166), glow=(255, 184, 160), size=(200, 400))
    layers["sky"] = L = Layer(w, sky)
    pa.stars(L, random.Random("riverside_stars"), 70, 300, rgba(236, 240, 255, 170))
    mx, my = w * 0.72, 150
    L.ellipse((mx - 26, my - 26, mx + 26, my + 26), rgba(250, 246, 226))
    L.ellipse((mx - 16, my - 30, mx + 34, my + 22), rgba(*sky.getpixel((int(mx + 10), my))[:3]))  # 초승달
    L.haze([("ellipse", (mx - 90, my - 90, mx + 90, my + 90), rgba(240, 236, 220, 40))], 30)

    # 지평선: 먼 푸른 산 두 겹.
    w = pa.layer_width(width, "horizon")
    layers["horizon"] = L = Layer(w)
    pts = pa.ridge(rng, w, 540, 110, waves=4)
    L.poly(pts, fog((90, 104, 150), 0.55))
    pa._slope_shade(L, pts, rgba(70, 80, 140, 60), 220, 28)
    pts2 = pa.ridge(rng, w, 585, 60, waves=3)
    L.poly(pts2, fog((80, 92, 138), 0.42))
    L.haze([("poly", [(-20, 590), (w + 20, 590), (w + 20, 660), (-20, 660)], rgba(*HAZE, 150))], 30)

    # 먼 언덕: 미루나무 줄, 첨탑 마을(창에 불), 멀리 돌다리.
    w = pa.layer_width(width, "far")
    layers["far"] = L = Layer(w)
    body = fog((70, 80, 120), 0.36)
    pts = pa.ridge(rng, w, 612, 36, waves=3)
    L.poly(pts, body)
    deco = random.Random("riverside_far")
    x = 120.0
    while x < w:
        pa._poplar(L, x, pa._ridge_y(pts, x) + 8, deco.uniform(50, 80), body, rgba(*LIGHT, 120))
        x += deco.uniform(140, 420)
    for vx in (w * 0.35, w * 0.8):
        pa._village(L, deco, vx, lambda gx: pa._ridge_y(pts, gx), body, rgba(*LIGHT, 160))
        for _ in range(9):  # 불 켜진 창
            wx = vx + deco.uniform(10, 260)
            wy = pa._ridge_y(pts, wx) - deco.uniform(6, 20)
            L.rect(wx, wy, wx + 4, wy + 5, rgba(255, 214, 140))
    stone_bridge(L, w * 0.58, 632, 260, fog((86, 92, 124), 0.32), fog((60, 66, 100), 0.3))
    L.haze([("poly", [(-20, 620), (w + 20, 620), (w + 20, 680), (-20, 680)], rgba(*HAZE, 110))], 24)

    # 구릉: 건너편 둑 뒤 나무 덮인 언덕.
    w = pa.layer_width(width, "hills")
    layers["hills"] = L = Layer(w)
    body = fog((44, 56, 92), 0.24)
    pts = pa.ridge(rng, w, 630, 26, waves=3)
    L.poly(pts, body)
    hr = random.Random("riverside_hills")
    x = 0.0
    while x < w:
        pa._blob_tree(L, hr, x, pa._ridge_y(pts, x) + 10, hr.uniform(16, 30), body, rgba(*LIGHT, 140), trunk=False)
        x += hr.uniform(24, 60)

    # 가운데: 건너편 둑(버드나무·물레방앗간)과 넓은 강. 물은 하늘을 비추고, 나무 그림자가 물에 비친다.
    w = pa.layer_width(width, "mid")
    layers["mid"] = L = Layer(w)
    md = random.Random("riverside_mid")
    bank = pa.ridge(md, w, 640, 4, step=40)
    # 물: 둑 쪽은 지평선빛(분홍), 아래로 갈수록 위 하늘빛(푸름)
    bands = [(648, (200, 182, 200)), (670, (170, 166, 198)), (700, (126, 136, 180)), (740, (96, 112, 160)), (790, (80, 98, 148)), (H, (70, 88, 140))]
    for (ya, ca), (yb, _) in zip(bands, bands[1:]):
        L.rect(-20, ya, w + 20, yb + 2, rgba(*ca))
    water_soft = [("poly", [(-20, ya), (w + 20, ya), (w + 20, ya + 14), (-20, ya + 14)], rgba(*ca, 160)) for (ya, ca) in bands[1:-1]]
    L.haze(water_soft, 10)
    # 건너편 둑의 나무·집과 그 그림자(물에 비친 것은 어둡고 일렁인다)
    trees = []
    x = md.uniform(0, 200)
    while x < w:
        trees.append((x, md.uniform(150, 240)))
        x += md.uniform(260, 620)
    refl = []
    for tx, th in trees:  # 비친 나무: 물결에 부서진 어두운 가로 획(흐리게)
        for k in range(int(th * 0.6 / 5)):
            ry = 652 + k * 5
            spread = th * 0.32 * (1 - k * 5 / (th * 0.66)) + 6
            jx = md.uniform(-14, 14)
            refl.append(("line", [(tx - spread + jx, ry), (tx + spread + jx * 0.5, ry)], rgba(56, 64, 104, 120), 3))
    L.haze(refl, 2.5)
    L.poly(bank[1:-1] + [(w + 40, 652), (-20, 652)], fog((44, 52, 82), 0.18))  # 건너편 둑
    mill_x = w * 0.46
    for tx, th in trees:
        if abs(tx - mill_x) < 260:
            continue
        willow(L, md, tx, 644, th, fog((40, 52, 80), 0.2), None)
    mill(L, mill_x, 644, 0.8, fog((120, 116, 132), 0.2), fog((90, 60, 70), 0.2), fog((60, 54, 60), 0.2), rgba(255, 210, 140))
    reeds(L, md, mill_x + 260, 646, 0.25, fog((60, 70, 90), 0.2), fog((70, 60, 60), 0.2), 12)
    # 물빛 반짝임, 해 진 쪽 물에 비친 노을 길
    ripples(L, md, 0, w, 656, H, int(w / 10), rgba(220, 222, 240, 120))
    glow_x = w * 0.18
    ripples(L, md, glow_x - 400, glow_x + 400, 652, 760, 160, rgba(255, 214, 196, 170), (20, 90))
    x = pa.layer_x(mk("5-4", 6390), "mid")  # 5-4 여울: 물결이 밝게 부서진다
    ripples(L, md, x - 500, x + 500, 690, 790, 140, rgba(240, 244, 250, 210), (14, 70))
    L.haze(pa.mist(md, 0, w, 662, 70, rgba(*HAZE, 120), int(w / 220)), 26)

    # 가까운 물가: 물에 잠긴 돌과 부들 무리, 수련 잎(하윤 길 바로 뒤). 5-2·5-3·5-4 자리는 비운다.
    w = pa.layer_width(width, "near")
    layers["near"] = L = Layer(w)
    nd = random.Random("riverside_near")
    keep_out = [pa.layer_x(mk(k, d), "near") for k, d in (("5-2", 2040), ("5-3", 3990), ("5-4", 6390))]
    x = nd.uniform(0, 300)
    while x < w:
        if all(abs(x - k) > 420 for k in keep_out):
            for _ in range(nd.randint(2, 4)):  # 물에 반쯤 잠긴 돌: 물 위로 둥근 등만, 둘레에 물결
                rx, rr = x + nd.uniform(-80, 80), nd.uniform(12, 26)
                ry = nd.uniform(772, 786)
                L.ellipse((rx - rr * 1.3, ry - 2, rx + rr * 1.3, ry + 4), rgba(190, 196, 220, 130))
                L.ellipse((rx - rr, ry - rr * 0.55, rx + rr, ry + 1), rgba(64, 68, 92))
                L.ellipse((rx - rr * 0.6, ry - rr * 0.55, rx + rr * 0.3, ry - rr * 0.2), rgba(120, 124, 150))
            reeds(L, nd, x + nd.uniform(-60, 60), 792, nd.uniform(0.45, 0.7), rgba(70, 84, 86), rgba(96, 70, 58))
            for _ in range(nd.randint(3, 6)):  # 수련 잎과 흰 꽃
                px, py = x + nd.uniform(-160, 160), nd.uniform(744, 780)
                pr = nd.uniform(10, 20)
                L.ellipse((px - pr, py - pr * 0.3, px + pr, py + pr * 0.3), rgba(60, 96, 84))
                if nd.random() < 0.3:
                    L.ellipse((px - 4, py - 5, px + 4, py + 1), rgba(250, 244, 240))
        x += nd.uniform(500, 1100)

    # 땅: 젖은 조약돌 길과 그 앞 물(얕은 물가, 징검다리 자리는 그대로).
    w = pa.layer_width(width, "ground")
    layers["ground"] = L = Layer(w)
    gd = random.Random("riverside_ground")
    water = rgba(96, 112, 156)
    L.rect(-20, 792, w + 20, 864, rgba(132, 132, 146))  # 조약돌 길
    pa.pebbles(L, gd, 0, w, 796, 862, int(w / 3), rgba(104, 104, 120), rgba(178, 178, 192))
    for _ in range(int(w / 10)):  # 젖은 돌의 반짝임
        x, y = gd.uniform(0, w), gd.uniform(798, 860)
        L.ellipse((x - 3, y - 1.5, x + 3, y + 1.5), rgba(236, 236, 246, 200))
    L.rect(-20, 862, w + 20, H, rgba(86, 104, 150))  # 앞 물
    L.rect(-20, 862, w + 20, 872, rgba(150, 156, 186))  # 물가 거품 선
    ripples(L, gd, 0, w, 876, H, int(w / 16), rgba(196, 206, 228, 150), (40, 200))
    x = mk("5-2", 2040)  # 5-2 얕은 물가
    L.poly([(x - 340, 792), (x + 320, 792), (x + 380, 864), (x - 400, 864)], rgba(110, 134, 166, 150))
    ripples(L, gd, x - 300, x + 300, 800, 860, 40, rgba(214, 222, 240, 170), (20, 90))
    x = mk("5-3", 3990)  # 5-3 징검다리
    L.rect(x - 480, 788, x + 480, 866, water)
    ripples(L, gd, x - 460, x + 460, 796, 860, 50, rgba(210, 218, 236, 160), (20, 100))
    for sx in range(int(x - 420), int(x + 440), 140):
        L.ellipse((sx - 60, 796, sx + 60, 826), rgba(220, 226, 240, 120))  # 돌 둘레 물결
        L.ellipse((sx - 56, 792, sx + 56, 822), rgba(104, 102, 112))
        L.ellipse((sx - 50, 790, sx + 50, 810), rgba(146, 144, 152))
        L.ellipse((sx - 30, 791, sx + 18, 800), rgba(186, 184, 196))

    # 하윤 뒤 물건: 부들 무리, 큰 바위, 매어 둔 나룻배(물가 중간).
    w = pa.layer_width(width, "props")
    layers["props"] = L = Layer(w)
    pd = random.Random("riverside_props")
    x = pd.uniform(100, 500)
    while x < w:
        if abs(x - mk("5-3", 3990)) > 600 and abs(x - mk("5-2", 2040)) > 420:
            reeds(L, pd, x, 796, 0.6, rgba(88, 94, 92), rgba(104, 76, 60))
        x += pd.uniform(500, 1200)
    for _ in range(int(w / 700)):
        x = pd.uniform(0, w)
        if abs(x - mk("5-3", 3990)) > 600:
            L.poly([(x - 90, 800), (x - 70, 754), (x - 10, 736), (x + 60, 748), (x + 92, 800)], rgba(80, 84, 104))  # 땅에 박힌 바위
            L.poly([(x - 60, 760), (x - 10, 742), (x + 50, 752), (x + 30, 764), (x - 20, 768)], rgba(124, 126, 148))
            for j in range(8):  # 바위 밑 이끼·풀
                gx = x + (j - 4) * 22
                L.line([(gx, 800), (gx - 4, 784)], rgba(70, 96, 80), 3)
    bx = 5000.0  # 매어 둔 작은 배(징검다리와 여울 사이)
    L.poly([(bx - 110, 770), (bx + 110, 770), (bx + 80, 796), (bx - 90, 796)], rgba(92, 70, 56))
    L.poly([(bx - 110, 770), (bx + 110, 770), (bx + 104, 778), (bx - 104, 778)], rgba(150, 118, 86))
    L.rect(bx + 150, 700, bx + 160, 798, rgba(84, 66, 52))  # 말뚝
    L.line(pa.sag(bx + 104, 772, bx + 152, 716, 12, 8), rgba(170, 150, 120), 2)

    # 앞: 흐린 부들과 물가 바위(하윤을 가리지 않게 듬성듬성).
    w = pa.layer_width(width, "front")
    layers["front"] = L = Layer(w)
    fd = random.Random("riverside_front")
    x = fd.uniform(300, 700)
    while x < w:
        reeds(L, fd, x, H + 10, fd.uniform(0.8, 1.2), rgba(52, 60, 72), rgba(70, 54, 50))
        if fd.random() < 0.5:
            rx = x + fd.uniform(120, 300)
            L.ellipse((rx - 110, H - 90, rx + 110, H + 60), rgba(44, 50, 70))
        x += fd.uniform(900, 1800)
    return pa.finish(layers, "riverside", LIGHT, SHADE)
