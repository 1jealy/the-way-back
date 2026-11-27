"""3. 버려진 간이역 (#140, 실루엣 화풍 + 그림 마무리).

노을. 위는 보랏빛, 지평선은 주황·분홍, 해는 오른쪽 아래. 녹슨 붉은색.
역명판(3-1) → 역사와 잠긴 문, 벤치 밑 열쇠(3-2) → 앉는 벤치(3-3) → 철길 위 하늘이(3-4) → 부탁 벤치(3-5)
→ 긴 플랫폼(짐수레·우유통·역 시계) → 대합실 안(3-6, 문 7855부터).
뒤로는 풀에 덮인 철길, 먼 돌다리(고가교)와 마을, 급수탑·신호소·버려진 화차가 노을에 실루엣으로 선다.
게임 부품 자리(장면 표시, 벤치 밑 열쇠 2414, 앉는 벤치 3325, 대합실 문 7855)는 예전 그림과 같다.
"""
from __future__ import annotations

import math
import random

import placeholder_art as pa
from placeholder_art import H, Layer, rgba

LIGHT = (255, 196, 130)   # 노을빛
SHADE = (96, 70, 130)     # 그늘에 섞는 보랏빛
RIM = (255, 190, 120)
PLATFORM_Y = 776.0


def _over(L: Layer, shapes, radius: float = 0.6) -> None:
    """반투명 덧칠(불투명한 것 위): 같은 색끼리 haze로 합성한다(shapes에 그리면 알파가 바뀐다)."""
    groups: dict = {}
    for sh in shapes:
        groups.setdefault(sh[2], []).append(sh)
    for g in groups.values():
        L.haze(g, radius)


def _viaduct(L: Layer, x0: float, x1: float, top: float, base: float, body, rim) -> None:
    """먼 돌다리(아치 여럿)."""
    L.rect(x0, top - 4, x1, top + 18, rim)
    L.rect(x0, top, x1, base, body)
    span = 110
    x = x0 + 20
    while x + span < x1:
        L.rect(x + 16, top + 50, x + span - 16, base + 2, rgba(0, 0, 0, 0))
        x += span
    # 아치 구멍은 하늘색에 가까운 색으로(먼 층이라 비쳐 보이는 대신)
    x = x0 + 20
    while x + span < x1:
        L.ellipse((x + 16, top + 34, x + span - 16, top + 90), rgba(232, 150, 120))
        L.rect(x + 16, top + 62, x + span - 16, base, rgba(232, 150, 120))
        x += span


def _water_tower(L: Layer, x: float, base: float, body, rim) -> None:
    for lx in (x - 40, x + 34):
        L.line([(lx, base), (lx + (6 if lx < x else -6), base - 170)], body, 7)
    L.line([(x - 40, base - 60), (x + 34, base - 120)], body, 3)
    L.line([(x + 34, base - 60), (x - 40, base - 120)], body, 3)
    L.rect(x - 62, base - 260, x + 56, base - 170, body)
    L.rect(x - 62 + 4, base - 262, x + 56 + 4, base - 258, rim)
    L.poly([(x - 70, base - 258), (x + 64, base - 258), (x - 3, base - 300)], body)
    L.line([(x + 56, base - 230), (x + 110, base - 200), (x + 110, base - 150)], body, 5)


def _signal_box(L: Layer, x: float, base: float, body, win) -> None:
    L.rect(x - 70, base - 110, x + 70, base, body)
    L.rect(x - 80, base - 200, x + 80, base - 110, body)
    for k in range(4):
        L.rect(x - 70 + k * 36, base - 190, x - 70 + k * 36 + 28, base - 130, win)
    L.poly([(x - 96, base - 196), (x + 96, base - 196), (x, base - 250)], body)
    L.line([(x + 80, base - 100), (x + 120, base - 100)], body, 4)
    for k in range(5):  # 계단
        L.rect(x + 80 + k * 10, base - 20 * k - 20, x + 92 + k * 10, base - 20 * k, body)


def _wagon(L: Layer, x: float, base: float, body, dark, rim) -> None:
    """버려진 화차(녹슨 나무 짐칸, 바퀴 넷)."""
    L.rect(x - 160, base - 130, x + 160, base - 34, body)
    L.rect(x - 160, base - 134, x + 160, base - 128, rim)
    for k in range(7):
        L.line([(x - 150 + k * 50, base - 128), (x - 150 + k * 50, base - 38)], dark, 3)
    L.line([(x - 150, base - 128), (x - 30, base - 38)], dark, 4)
    L.line([(x + 30, base - 128), (x + 150, base - 38)], dark, 4)
    for wx in (x - 110, x - 60, x + 60, x + 110):
        L.ellipse((wx - 22, base - 44, wx + 22, base), dark)
    L.rect(x - 170, base - 40, x + 170, base - 30, dark)


def _semaphore(L: Layer, x: float, base: float, h: float, body, arm, lamp) -> None:
    """완목 신호기: 격자 기둥, 비스듬히 내린 팔, 등."""
    L.rect(x - 7, base - h, x + 7, base, body)
    for k in range(int(h / 40)):
        y = base - k * 40
        L.line([(x - 7, y), (x + 7, y - 40)], body, 2)
    L.poly([(x + 7, base - h + 20), (x + 130, base - h - 18), (x + 132, base - h + 2), (x + 7, base - h + 40)], arm)
    L.rect(x + 106, base - h - 16, x + 118, base - h - 2, rgba(240, 236, 226))
    L.ellipse((x - 18, base - h + 30, x - 2, base - h + 46), lamp)
    L.poly([(x - 26, base - h), (x + 26, base - h), (x, base - h - 20)], body)


def _lamp_post(L: Layer, x: float, base: float, iron, glass) -> None:
    """가스등 모양 플랫폼 등: 가는 쇠 기둥, 덩굴 장식, 등갓."""
    L.rect(x - 5, 440, x + 5, base, iron)
    L.rect(x - 12, base - 26, x + 12, base, iron)
    L.line([(x, 470), (x - 26, 456), (x - 30, 440)], iron, 3)
    L.line([(x, 470), (x + 26, 456), (x + 30, 440)], iron, 3)
    L.poly([(x - 22, 440), (x + 22, 440), (x + 16, 400), (x - 16, 400)], glass)
    L.poly([(x - 28, 400), (x + 28, 400), (x, 380)], iron)
    L.line([(x - 16, 400), (x - 22, 440)], iron, 2)
    L.line([(x + 16, 400), (x + 22, 440)], iron, 2)


def _bench(L: Layer, x: float, base: float, wood, iron, w: float = 240) -> None:
    """쇠 다리 나무 벤치(등받이 널 셋)."""
    for k in range(3):
        L.rect(x - w / 2, base - 150 + k * 18, x + w / 2, base - 140 + k * 18, wood)
    L.rect(x - w / 2, base - 92, x + w / 2, base - 80, wood)
    for bx in (x - w / 2 + 18, x + w / 2 - 18):
        L.line([(bx, base), (bx - 6, base - 86), (bx + 4, base - 156)], iron, 8)
        L.line([(bx - 14, base - 86), (bx + 14, base - 86)], iron, 6)


def paint(width: float, markers: dict[str, float]) -> dict[str, Layer]:
    rng = random.Random("station2")
    mk = markers.get
    layers: dict[str, Layer] = {}

    # ---------------- 하늘: 노을. 해는 오른쪽 아래, 구름 아랫면이 불타듯 물든다.
    w = pa.layer_width(width, "sky")
    sun_x, sun_y = w * 0.86, 700
    sky = pa.vertical_gradient(w, [
        (0.0, (58, 52, 104)), (0.22, (110, 76, 132)), (0.42, (186, 104, 134)), (0.56, (236, 132, 110)),
        (0.66, (252, 172, 98)), (0.74, (255, 204, 130)), (1.0, (242, 150, 90)),
    ])
    pa.add_glow(sky, sun_x, sun_y, 1400, (255, 170, 110), 0.55)
    pa.add_glow(sky, sun_x, sun_y, 240, (255, 232, 180), 0.9)
    pa.paint_clouds(sky, rng, 9, w, 140, 520, (sun_x, sun_y), lit=(255, 196, 150), shade=(132, 86, 138),
                    glow=(255, 150, 90), size=(260, 700))
    layers["sky"] = L = Layer(w, sky)
    L.ellipse((sun_x - 46, sun_y - 46, sun_x + 46, sun_y + 46), rgba(255, 238, 196))
    rays = []
    for k in range(10):
        a = math.radians(190 + k * 16 + rng.uniform(-4, 4))
        a2 = a + math.radians(rng.uniform(2, 5))
        ln = rng.uniform(900, 1600)
        rays.append(("poly", [(sun_x, sun_y), (sun_x + math.cos(a) * ln, sun_y + math.sin(a) * ln),
                              (sun_x + math.cos(a2) * ln, sun_y + math.sin(a2) * ln)], rgba(255, 214, 160, 40)))
    L.haze(rays, 18)
    for _ in range(3):
        pa._flock(L, rng, rng.uniform(200, w - 200), rng.uniform(260, 420), rng.randint(5, 9), rgba(70, 46, 70, 190))

    # ---------------- 지평선: 먼 산맥(보랏빛, 노을에 녹는다)
    w = pa.layer_width(width, "horizon")
    layers["horizon"] = L = Layer(w)
    pts = pa.ridge(rng, w, 560, 90, waves=4)
    L.poly(pts, rgba(156, 104, 140))
    pa._slope_shade(L, pts, rgba(110, 70, 120, 80), 220, 26)
    L.haze([("poly", [(-20, 600), (w + 20, 600), (w + 20, 680), (-20, 680)], rgba(255, 182, 130, 150))], 30)

    # ---------------- 먼 언덕: 돌다리(고가교), 마을과 첨탑, 미루나무
    w = pa.layer_width(width, "far")
    layers["far"] = L = Layer(w)
    body = rgba(130, 76, 110)
    pts = pa.ridge(rng, w, 620, 50, waves=3)
    L.poly(pts, body)
    pa._slope_shade(L, pts, rgba(90, 50, 96, 80), 160, 22)
    vx = w * 0.3
    _viaduct(L, vx, vx + 760, 540, pa._ridge_y(pts, vx + 380) + 30, body, rgba(*RIM, 200))
    pa._village(L, rng, w * 0.7, lambda gx: pa._ridge_y(pts, gx), body, rgba(*RIM, 200))
    x = 120.0
    while x < w:
        pa._poplar(L, x, pa._ridge_y(pts, x) + 8, rng.uniform(60, 100), body, rgba(*RIM, 170))
        x += rng.uniform(200, 700)
    L.haze([("poly", [(-20, 650), (w + 20, 650), (w + 20, 710), (-20, 710)], rgba(255, 176, 124, 110))], 24)

    # ---------------- 구릉: 밭과 나무 줄, 철길 따라 선 전신주
    w = pa.layer_width(width, "hills")
    layers["hills"] = L = Layer(w)
    body = rgba(110, 58, 84)
    rim = rgba(*RIM, 220)
    pts = pa.ridge(rng, w, 660, 30, waves=3)
    L.poly(pts, body)
    x = 60.0
    while x < w:
        run = rng.uniform(300, 700)
        tx = x
        while tx < min(x + run, w):
            pa._blob_tree(L, rng, tx, pa._ridge_y(pts, tx) + 6, rng.uniform(14, 24), rgba(92, 48, 72), rim, trunk=False)
            tx += rng.uniform(22, 36)
        x += run + rng.uniform(250, 700)
    tops = []
    for x in range(100, w, 260):
        y = pa._ridge_y(pts, x) + 6
        L.line([(x, y), (x, y - 70)], rgba(84, 42, 64), 3)
        L.line([(x - 9, y - 64), (x + 9, y - 64)], rgba(84, 42, 64), 2)
        tops.append((x, y - 64))
    for (xa, ya), (xb, yb) in zip(tops, tops[1:]):
        L.line(pa.sag(xa, ya, xb, yb, 8), rgba(84, 42, 64, 200), 1.2)

    # ---------------- 가운데: 급수탑, 신호소, 버려진 화차, 큰 나무 실루엣
    w = pa.layer_width(width, "mid")
    layers["mid"] = L = Layer(w)
    body, dark = rgba(86, 42, 60), rgba(64, 30, 46)
    rim = rgba(*RIM, 235)
    hill = pa.ridge(rng, w, 690, 12, waves=2)
    L.poly(hill, body)
    x = 80.0
    while x < w:
        if rng.random() < 0.6:
            pa._oak(L, rng, x, pa._ridge_y(hill, x) + 6, rng.uniform(40, 70), rgba(78, 40, 58), rim, dark)
        else:
            pa._poplar(L, x, pa._ridge_y(hill, x) + 6, rng.uniform(150, 220), rgba(78, 40, 58), rim)
        x += rng.uniform(300, 700)
    _water_tower(L, w * 0.22, pa._ridge_y(hill, w * 0.22) + 6, dark, rim)
    _signal_box(L, w * 0.55, pa._ridge_y(hill, w * 0.55) + 6, dark, rgba(255, 196, 120))
    _wagon(L, w * 0.75, pa._ridge_y(hill, w * 0.75) + 10, rgba(120, 52, 44), dark, rim)
    _semaphore(L, w * 0.4, pa._ridge_y(hill, w * 0.4) + 6, 260, dark, rgba(150, 50, 40), rgba(255, 120, 80))

    # ---------------- 가까운 곳: 철길 뒤 웃자란 풀, 들꽃, 끊긴 나무 울타리
    w = pa.layer_width(width, "near")
    layers["near"] = L = Layer(w)
    band = pa.ridge(rng, w, 700, 10, step=30)
    L.poly(band, rgba(120, 66, 60))
    grass = []
    for _ in range(int(w / 4)):
        x = rng.uniform(0, w)
        y0 = pa._ridge_y(band, x) + rng.uniform(4, 40)
        grass.append(("line", [(x, y0), (x + rng.uniform(-10, -2), y0 - rng.uniform(14, 44))],
                      pa.lerp_color(rgba(110, 60, 54), rgba(255, 196, 130), rng.random() ** 1.6), rng.uniform(1.2, 2.2)))
    for g in grass:
        L.line(g[1], g[2], g[3])
    prng = random.Random("station_plumes")
    for _ in range(int(w / 18)):
        x = prng.uniform(0, w)
        pa._plume(L, prng, x, pa._ridge_y(band, x) + prng.uniform(10, 40), prng.uniform(26, 46),
                  rgba(255, 214, 170, 170), rgba(120, 66, 56, 200))
    x = 0.0
    while x < w:
        c = rng.choice([rgba(230, 90, 70), rgba(250, 214, 140), rgba(200, 150, 220)])
        for _ in range(rng.randint(15, 35)):
            fx = x + rng.gauss(0, 50)
            fy = pa._ridge_y(band, fx) + rng.uniform(6, 40)
            r = rng.uniform(1.8, 3.2)
            L.ellipse((fx - r, fy - r, fx + r, fy + r), c)
        x += rng.uniform(200, 600)
    x = rng.uniform(100, 400)
    while x < w:
        run = rng.uniform(300, 800)
        posts = [x + i * 64 for i in range(int(run / 64))]
        for k, px in enumerate(posts):
            y = pa._ridge_y(band, px) + 18
            tilt = rng.uniform(-6, 6)
            L.line([(px, y), (px + tilt, y - 44)], rgba(70, 36, 40), 6)
        if len(posts) > 1:
            L.line([(px, pa._ridge_y(band, px) - 4) for px in posts[: len(posts) // 2 + 1]], rgba(70, 36, 40), 3)
        x += run + rng.uniform(500, 1400)

    # ---------------- 땅: 철길(자갈·침목·노을 받은 레일), 돌 플랫폼
    w = pa.layer_width(width, "ground")
    layers["ground"] = L = Layer(w)
    L.rect(-20, 692, w + 20, PLATFORM_Y + 4, rgba(104, 66, 66))  # 자갈
    pa.pebbles(L, rng, 0, w, 696, PLATFORM_Y, int(w / 4), rgba(84, 52, 56), rgba(160, 108, 96))
    for x in range(0, w, 58):
        L.poly([(x, 714), (x + 22, 714), (x + 26, 762), (x - 2, 762)], rgba(70, 42, 40))  # 침목
        L.line([(x + 2, 716), (x + 20, 716)], rgba(150, 96, 74), 2)
    for y in (720, 752):
        L.rect(-20, y - 5, w + 20, y + 5, rgba(120, 62, 48))
        L.rect(-20, y - 5, w + 20, y - 2, rgba(255, 186, 120))  # 노을빛 받은 레일 윗면
    weeds = []
    for _ in range(int(w / 10)):
        x, y = rng.uniform(0, w), rng.uniform(700, 774)
        weeds.append(("line", [(x, y), (x + rng.uniform(-8, 2), y - rng.uniform(8, 30))], rgba(120, 110, 60), 1.6))
    for g in weeds:
        L.line(g[1], g[2], g[3])
    # 플랫폼: 돌 판, 가장자리 돌, 갈라진 틈의 풀, 웅덩이
    L.rect(-20, PLATFORM_Y, w + 20, H, rgba(180, 142, 132))
    L.rect(-20, PLATFORM_Y, w + 20, PLATFORM_Y + 16, rgba(222, 186, 160))
    L.rect(-20, PLATFORM_Y + 16, w + 20, PLATFORM_Y + 20, rgba(140, 100, 96))
    for x in range(0, w, 160):
        L.rect(x, PLATFORM_Y, x + 3, PLATFORM_Y + 16, rgba(150, 112, 104))
    joints = []
    for y in range(int(PLATFORM_Y) + 60, H, 64):
        joints.append(("line", [(-20, y), (w + 20, y)], rgba(150, 112, 108, 160), 2))
        off = (y // 64 % 2) * 90
        for x in range(off, w, 180):
            joints.append(("line", [(x, y - 40), (x - 8, y)], rgba(150, 112, 108, 160), 2))
    _over(L, joints)
    for _ in range(int(w / 70)):
        x, y = rng.uniform(0, w), rng.uniform(PLATFORM_Y + 30, H)
        for k in range(rng.randint(3, 7)):
            L.line([(x + k * 4, y), (x + k * 4 + rng.uniform(-6, 4), y - rng.uniform(8, 24))], rgba(120, 120, 64), 1.8)
    puddles = []
    for _ in range(int(w / 900)):
        x, y = rng.uniform(200, w - 200), rng.uniform(900, 1040)
        puddles.append(("ellipse", (x - 120, y - 10, x + 120, y + 10), rgba(255, 190, 150, 120)))
    _over(L, puddles, 2)

    # ---------------- 하윤 뒤 물건: 역명판, 역사(잠긴 문, 벤치 밑 열쇠), 벤치, 등, 짐수레, 대합실
    w = pa.layer_width(width, "props")
    layers["props"] = L = Layer(w)
    iron, wood = rgba(70, 40, 40), rgba(136, 80, 56)
    brick, plaster = rgba(150, 74, 58), rgba(214, 166, 132)
    # 노을이 낮게 비쳐 물건 그림자가 플랫폼 위로 왼쪽으로 길게 눕는다(물건보다 먼저 깐다)
    shadow_c = rgba(80, 46, 90, 90)
    shadows = []
    def long_shadow(x0s, x1s, h):
        shadows.append(("poly", [(x0s, PLATFORM_Y + 2), (x1s, PLATFORM_Y + 2), (x1s - h * 1.6, PLATFORM_Y + 2 + h * 0.18),
                                 (x0s - h * 1.6, PLATFORM_Y + 2 + h * 0.18)], shadow_c))
    for lx in (mk("3-3", 3325) + 600, mk("3-4", 3800) + 500, mk("3-5", 4000) - 500, 5400, 6600, 7400, 6900):
        long_shadow(lx - 5, lx + 5, 380)
    for bxx in (mk("3-2", 2118) + 300, mk("3-3", 3325), mk("3-5", 4000)):
        long_shadow(bxx - 120, bxx + 120, 150)
    for px in (mk("3-1", 776) - 130, mk("3-1", 776) + 130):
        long_shadow(px - 7, px + 7, 320)
    long_shadow(5780, 6020, 140)
    long_shadow(mk("3-2", 2118) - 650, mk("3-2", 2118) + 460, 300)
    L.under(shadows, 6)
    # 3-1 역명판(글자 없이 — 이름은 아직 정하지 않았다)
    x = mk("3-1", 776)
    for px in (x - 130, x + 130):
        L.rect(px - 7, 530, px + 7, PLATFORM_Y, iron)
        L.ellipse((px - 12, 520, px + 12, 540), iron)
    L.rect(x - 180, 448, x + 180, 548, iron)
    L.rect(x - 168, 460, x + 168, 536, rgba(232, 222, 200))
    L.rect(x - 156, 472, x + 156, 524, rgba(60, 76, 110))  # 법랑 판 가운데(글자 자리)
    L.rect(x - 150, 478, x + 150, 518, rgba(70, 88, 126))
    L.poly([(x + 60, 460), (x + 90, 460), (x + 76, 536), (x + 58, 536)], rgba(176, 100, 70))  # 녹물
    # 3-2 역사: 벽돌 아랫단, 회벽, 박공지붕과 굴뚝, 플랫폼 차양(쇠 받침), 아치 창, 잠긴 문
    x = mk("3-2", 2118)
    bx0, bx1 = x - 650, x + 460
    L.rect(bx0, 300, bx1, PLATFORM_Y, plaster)
    L.rect(bx0, 620, bx1, PLATFORM_Y, brick)
    for yy in range(626, int(PLATFORM_Y), 18):  # 벽돌 줄눈
        L.line([(bx0, yy), (bx1, yy)], rgba(120, 56, 46), 2)
    L.poly([(bx0 - 60, 310), (bx1 + 60, 310), (bx1 - 40, 170), (bx0 + 40, 170)], rgba(100, 52, 56))
    for k in range(14):
        sy = 180 + k * 10
        L.line([(bx0 + 40 - k * 7, sy), (bx1 - 40 + k * 7, sy)], rgba(84, 42, 48), 2)
    L.rect(bx0 + 160, 110, bx0 + 210, 200, brick)
    L.rect(bx0 + 154, 104, bx0 + 216, 116, rgba(110, 52, 44))
    for wx in (x - 520, x - 330, x + 230):  # 아치 창: 노을을 비춘다
        L.rect(wx, 420, wx + 130, 600, iron)
        L.ellipse((wx, 380, wx + 130, 460), iron)
        L.rect(wx + 10, 430, wx + 120, 590, rgba(255, 170, 110))
        L.ellipse((wx + 10, 390, wx + 120, 470), rgba(255, 196, 140))
        L.rect(wx + 62, 400, wx + 68, 590, iron)
        L.rect(wx + 10, 500, wx + 120, 506, iron)
    L.rect(x - 80, 560, x + 80, PLATFORM_Y, iron)  # 잠긴 문
    L.rect(x - 66, 574, x + 66, PLATFORM_Y, rgba(110, 62, 50))
    L.line([(x, 574), (x, PLATFORM_Y)], iron, 4)
    L.ellipse((x + 40, 668, x + 54, 682), rgba(214, 176, 100))
    L.line([(x - 30, 650), (x + 30, 700)], rgba(160, 130, 90), 5)  # 빗장 사슬
    L.line([(x + 30, 650), (x - 30, 700)], rgba(160, 130, 90), 5)
    for px in (x - 300, x + 150):  # 빈 게시판(글자 없음)
        L.rect(px, 600, px + 90, 700, iron)
        L.rect(px + 6, 606, px + 84, 694, rgba(226, 206, 170))
    L.poly([(bx0 - 40, 400), (bx1 + 220, 400), (bx1 + 240, 430), (bx0 - 60, 430)], rgba(120, 60, 52))  # 차양
    for k in range(int((bx1 + 220 - bx0) / 40)):
        L.line([(bx0 - 40 + k * 40, 430), (bx0 - 40 + k * 40 + 20, 440)], rgba(120, 60, 52), 4)  # 차양 끝 장식
    for px in range(int(bx0 + 60), int(bx1 + 240), 380):
        L.rect(px - 6, 430, px + 6, PLATFORM_Y, iron)
        L.line([(px, 480), (px - 60, 432)], iron, 4)
        L.line([(px, 480), (px + 60, 432)], iron, 4)
    _bench(L, x + 300, PLATFORM_Y, wood, iron)
    L.ellipse((x + 290, 762, x + 306, 772), rgba(255, 226, 130))  # 벤치 밑 열쇠(3-2, 2414)
    L.haze([("ellipse", (x + 280, 752, x + 316, 782), rgba(255, 236, 160, 120))], 6)
    for px in (bx0 - 20, bx1 + 30):  # 화분(웃자란 제라늄)
        L.poly([(px - 30, PLATFORM_Y), (px + 30, PLATFORM_Y), (px + 36, PLATFORM_Y - 50), (px - 36, PLATFORM_Y - 50)], rgba(150, 74, 54))
        for _ in range(12):
            fx, fy = px + rng.uniform(-40, 40), PLATFORM_Y - 60 - rng.uniform(0, 50)
            L.ellipse((fx - 9, fy - 9, fx + 9, fy + 9), rng.choice([rgba(110, 120, 60), rgba(220, 70, 60)]))
    # 3-3 앉는 벤치, 3-5 부탁 자리 벤치, 플랫폼 등
    _bench(L, mk("3-3", 3325), PLATFORM_Y, wood, iron)
    _bench(L, mk("3-5", 4000), PLATFORM_Y, wood, iron)
    for lx in (mk("3-3", 3325) + 600, mk("3-4", 3800) + 500, mk("3-5", 4000) - 500, 5400, 6600, 7400):
        _lamp_post(L, lx, PLATFORM_Y, iron, rgba(255, 220, 150))
    # 긴 플랫폼: 짐수레와 가방, 우유통, 역 시계, 빈 꽃상자
    cx = 5900
    L.rect(cx - 120, PLATFORM_Y - 70, cx + 120, PLATFORM_Y - 56, wood)
    for wx in (cx - 90, cx + 90):
        L.ellipse((wx - 26, PLATFORM_Y - 52, wx + 26, PLATFORM_Y), iron)
        L.ellipse((wx - 8, PLATFORM_Y - 34, wx + 8, PLATFORM_Y - 18), wood)
    L.line([(cx + 120, PLATFORM_Y - 64), (cx + 200, PLATFORM_Y - 140)], iron, 5)
    for bx, by, bw, bh, c in ((-100, 0, 110, 56, rgba(120, 70, 50)), (14, 0, 90, 46, rgba(70, 86, 96)), (-70, -56, 80, 40, rgba(150, 110, 70))):
        L.rect(cx + bx, PLATFORM_Y - 70 + by - bh, cx + bx + bw, PLATFORM_Y - 70 + by, c)
        L.rect(cx + bx + bw / 2 - 10, PLATFORM_Y - 70 + by - bh - 8, cx + bx + bw / 2 + 10, PLATFORM_Y - 70 + by - bh, iron)
    for k, mx in enumerate((6250, 6300, 6345)):
        L.poly([(mx - 20, PLATFORM_Y), (mx + 20, PLATFORM_Y), (mx + 16, PLATFORM_Y - 70), (mx - 16, PLATFORM_Y - 70)], rgba(170, 160, 150))
        L.rect(mx - 12, PLATFORM_Y - 84, mx + 12, PLATFORM_Y - 70, rgba(140, 130, 124))
        L.rect(mx - 20, PLATFORM_Y - 40, mx + 20, PLATFORM_Y - 34, rgba(120, 110, 104))
    ck = 6900
    L.rect(ck - 6, 400, ck + 6, PLATFORM_Y, iron)
    L.ellipse((ck - 44, 330, ck + 44, 418), iron)
    L.ellipse((ck - 36, 338, ck + 36, 410), rgba(244, 234, 210))
    L.line([(ck, 374), (ck + 18, 362)], iron, 4)
    L.line([(ck, 374), (ck - 4, 344)], iron, 3)
    # 3-6 대합실 안(문 7855부터): 판벽, 노을 드는 창과 빛줄기, 긴 의자, 매표창, 난로, 시계
    x0 = mk("3-6", 8555) - 700
    L.rect(x0, 0, w + 20, 170, rgba(76, 44, 42))
    for bx in range(int(x0), int(w), 180):
        L.rect(bx, 0, bx + 22, 170, rgba(60, 34, 34))
    L.rect(x0, 170, w + 20, PLATFORM_Y, rgba(170, 108, 92))
    L.rect(x0, 560, w + 20, PLATFORM_Y, wood)
    for bx in range(int(x0), int(w), 60):
        L.rect(bx, 570, bx + 3, PLATFORM_Y - 30, rgba(110, 62, 46))
    L.rect(x0, 552, w + 20, 562, iron)
    L.rect(x0, PLATFORM_Y - 30, w + 20, PLATFORM_Y, iron)
    beams = []
    for wx in range(int(x0 + 200), int(w - 200), 460):
        L.rect(wx, 270, wx + 200, 520, iron)
        L.ellipse((wx, 230, wx + 200, 320), iron)
        L.rect(wx + 10, 280, wx + 190, 510, rgba(255, 176, 112))
        L.ellipse((wx + 10, 240, wx + 190, 320), rgba(255, 200, 140))
        L.rect(wx + 96, 250, wx + 104, 510, iron)
        L.rect(wx + 10, 390, wx + 190, 396, iron)
        beams.append(("poly", [(wx + 10, 280), (wx + 190, 280), (wx + 470, PLATFORM_Y), (wx + 250, PLATFORM_Y)], rgba(255, 180, 120, 70)))
    L.haze(beams, 22)
    seat = rgba(92, 50, 40)
    for cx in range(int(x0 + 140), int(w - 100), 300):  # 긴 의자(판벽보다 짙게)
        L.rect(cx - 110, 690, cx + 110, 704, seat)
        L.rect(cx - 110, 690, cx + 110, 693, rgba(200, 130, 90))
        L.rect(cx - 110, 620, cx + 110, 634, seat)
        for lx in (cx - 100, cx + 92):
            L.rect(lx, 620, lx + 8, PLATFORM_Y, iron)
    tw = x0 + 430  # 매표창(창 사이)
    L.rect(tw, 330, tw + 180, 520, iron)
    L.rect(tw + 12, 342, tw + 168, 470, rgba(60, 40, 40))
    for k in range(8):
        L.line([(tw + 12 + k * 20, 342), (tw + 12 + k * 20, 470)], rgba(160, 130, 90), 2)
    L.rect(tw - 10, 470, tw + 190, 486, wood)
    st = w - 420  # 난로와 연통
    L.rect(st - 50, 650, st + 50, PLATFORM_Y, iron)
    L.ellipse((st - 56, 620, st + 56, 670), iron)
    L.rect(st - 10, 170, st + 10, 640, iron)
    L.ellipse((st - 16, 690, st + 16, 720), rgba(140, 70, 50))
    L.ellipse((x0 + 520 - 40, 200, x0 + 520 + 40, 280), iron)  # 벽시계
    L.ellipse((x0 + 520 - 32, 208, x0 + 520 + 32, 272), rgba(240, 228, 204))
    L.line([(x0 + 520, 240), (x0 + 532, 228)], iron, 3)
    for lx in range(int(x0 + 300), int(w - 100), 600):  # 매달린 등
        L.line([(lx, 170), (lx, 300)], iron, 2)
        L.poly([(lx - 30, 330), (lx + 30, 330), (lx + 14, 300), (lx - 14, 300)], rgba(90, 60, 40))
        L.ellipse((lx - 8, 322, lx + 8, 338), rgba(255, 226, 160))
    L.haze([("ellipse", (lx - 110, 250, lx + 110, 400), rgba(255, 210, 150, 50)) for lx in range(int(x0 + 300), int(w - 100), 600)], 28)
    L.rect(x0 - 20, 0, x0 + 20, PLATFORM_Y, iron)  # 문틀
    L.rect(x0 + 8, 0, x0 + 20, PLATFORM_Y, rgba(150, 90, 70))

    # ---------------- 앞: 차양 기둥(가늘고 흐리게), 완목 신호기, 웃자란 풀
    w = pa.layer_width(width, "front")
    layers["front"] = L = Layer(w)
    for wx in range(1500, int(mk("3-6", 8555) - 900), 1700):
        fx = pa.layer_x(wx, "front")
        L.haze([pa.soft_rect(fx - 10, -10, fx + 10, H + 10, rgba(80, 40, 48)),
                pa.soft_rect(fx + 3, -10, fx + 10, H + 10, rgba(200, 110, 80))], 4)
    fx = pa.layer_x(mk("3-4", 3800) + 700, "front")
    _semaphore(L, fx, H + 10, 760, rgba(70, 34, 40), rgba(140, 40, 34), rgba(255, 110, 70))
    x = rng.uniform(200, 600)
    while x < w:
        tuft = Layer(w)
        pa._grass_tuft(tuft, rng, x, H + 10, rng.uniform(0.8, 1.2), rgba(70, 40, 40, 235), rgba(160, 90, 60, 235), rng.randint(8, 14))
        L.under(tuft.shapes, 4)
        x += rng.uniform(800, 1600)
    return pa.finish(layers, "station", LIGHT, SHADE)
