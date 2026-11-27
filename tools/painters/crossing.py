"""7-6 강 위 구간 (실루엣 화풍, #140).

나룻배가 저절로 흘러가는 강. 걷는 땅 없이 물뿐이고, 나루터와 같은 흰 금빛이 화면을 채운다.
강 건너 안개에는 지나온 장소 다섯이 코드로 비친다(boat_ride.gd가 bg_<장소>_mid를 바래게 얹는다,
그림 아래 끝 y 650). 그래서 y 650 위쪽 강 건너는 조용하고 밝게 둔다(비친 장소가 잘 읽히게).

게임과 맞춘 것: 배는 y 810 물 위를 지나간다(배 아래 물 ground 층 y 818~). 물그림자는 코드가 그린다.
"""

from __future__ import annotations

import math
import os
import random
import sys

import placeholder_art as pa
from placeholder_art import H, Layer, rgba

sys.path.insert(0, os.path.dirname(__file__))
import ferry as fr  # noqa: E402  같은 빛·백합·물비늘을 쓴다


def water_lily(L: Layer, rng: random.Random, x: float, y: float, r: float, pad, petal) -> None:
    """물에 뜬 수련 잎(한쪽이 갈라진 납작한 타원)과 가끔 흰 꽃 한 송이."""
    L.ellipse((x - r, y - r * 0.28, x + r, y + r * 0.28), pad)
    L.poly([(x, y), (x + r * 0.9, y - r * 0.06), (x + r * 0.9, y + r * 0.1)], rgba(236, 238, 238, 255))
    if rng.random() < 0.45:
        fr.lily(L, x - r * 0.2, y - r * 0.18, r * 0.45, rng, petal=petal, back=rgba(232, 230, 222), tilt=rng.uniform(-0.3, 0.3))


def paint(width: float, markers: dict[str, float]) -> dict[str, Layer]:
    rng = random.Random("crossing")
    deco = random.Random("crossing_deco")
    layers: dict[str, Layer] = {}

    # ---------------------------------------------------------------- 하늘
    w = pa.layer_width(width, "sky")
    sky = pa.vertical_gradient(w, [
        (0.0, (230, 232, 234)), (0.35, (244, 242, 234)), (0.58, (253, 248, 232)), (0.7, (255, 242, 212)), (1.0, (252, 238, 210)),
    ])
    sx, sy = w * 0.85, 560
    pa.add_glow(sky, sx, sy, 1700, (255, 250, 232), 0.8)
    pa.add_glow(sky, sx, sy, 600, (255, 236, 190), 0.55)
    pa.add_glow(sky, sx, sy, 180, (255, 253, 244), 0.95)
    pa.paint_clouds(sky, rng, 6, w, 130, 360, (sx, sy), lit=(255, 253, 246), shade=(234, 230, 226),
                    glow=(255, 234, 200), size=(300, 620))
    layers["sky"] = L = Layer(w, sky)
    rays = []
    for k in range(12):
        a = math.radians(150 + k * 20 + deco.uniform(-5, 5))
        a2 = a + math.radians(deco.uniform(4, 8))
        ln = deco.uniform(1300, 2200)
        rays.append(("poly", [(sx, sy), (sx + math.cos(a) * ln, sy + math.sin(a) * ln),
                              (sx + math.cos(a2) * ln, sy + math.sin(a2) * ln)], rgba(255, 246, 222, 36)))
    L.haze(rays, 26)
    for _ in range(3):  # 아주 먼 새 떼
        pa._flock(L, deco, deco.uniform(200, w - 200), deco.uniform(240, 420), deco.randint(3, 6), rgba(190, 184, 176, 150))

    # ---------------------------------------------------------------- 지평선: 빛 속으로 사라지는 강 건너(아주 낮고 옅게)
    w = pa.layer_width(width, "horizon")
    layers["horizon"] = L = Layer(w)
    pts = pa.ridge(rng, w, 632, 14, waves=3)
    body = fr._pale((168, 176, 166), 0.6, 190)
    L.poly(pts, body)
    x = deco.uniform(40, 200)
    while x < w:  # 빛에 잠긴 먼 강 건너 나무들(비친 장소들 아래에 낮게)
        if deco.random() < 0.65:
            pa._blob_tree(L, deco, x, pa._ridge_y(pts, x) + 4, deco.uniform(12, 22), body, rgba(255, 248, 228, 200), trunk=False)
        else:
            pa._poplar(L, x, pa._ridge_y(pts, x) + 4, deco.uniform(40, 70), body, rgba(255, 248, 228, 200))
        x += deco.uniform(40, 220)
    L.haze([("poly", [(-20, 600), (w + 20, 600), (w + 20, 690), (-20, 690)], rgba(*fr.HAZE, 220))], 36)

    # ---------------------------------------------------------------- 먼 물: 물안개 띠
    w = pa.layer_width(width, "far")
    layers["far"] = L = Layer(w)
    L.rect(-20, 640, w + 20, H, rgba(236, 238, 238))
    pa.water_streaks(L, rng, 0, w, 646, 760, int(w / 16), rgba(214, 220, 226, 130))
    L.haze(pa.mist(rng, 0, w, 646, 70, rgba(255, 254, 248, 200), int(w / 160)), 30)

    # ---------------------------------------------------------------- 가운데 물: 빛 길
    w = pa.layer_width(width, "mid")
    layers["mid"] = L = Layer(w)
    L.rect(-20, 690, w + 20, H, rgba(222, 228, 232))
    L.haze([("poly", [(-20, 820), (w + 20, 820), (w + 20, H + 10), (-20, H + 10)], rgba(196, 206, 216, 150))], 40)
    refl = []
    for _ in range(int(w / 500)):  # 물에 비친 구름
        cx, cy = deco.uniform(0, w), deco.uniform(720, 800)
        cw = deco.uniform(220, 480)
        refl.append(("ellipse", (cx - cw / 2, cy - 14, cx + cw / 2, cy + 14), rgba(255, 250, 240, 130)))
    L.haze(refl, 12)
    L.haze([("poly", [(-20, 690), (w + 20, 690), (w + 20, 720), (-20, 720)], rgba(255, 250, 236, 220))], 12)
    pa.water_streaks(L, rng, 0, w, 700, H, int(w / 12), rgba(208, 216, 224, 150))
    for gx in range(600, int(w), 1400):  # 빛 길이 여러 군데(배가 흘러가도 늘 앞에 빛이 있다)
        fr.glitter(L, deco, gx, 700, 900, 220, 260, rgba(255, 238, 190, 200))
    L.haze(pa.mist(rng, 0, w, 706, 80, rgba(255, 253, 246, 160), int(w / 200)), 28)

    # ---------------------------------------------------------------- 가까운 물: 수련 잎과 꽃
    w = pa.layer_width(width, "near")
    layers["near"] = L = Layer(w)
    pa.water_streaks(L, rng, 0, w, 760, H, int(w / 14), rgba(212, 220, 226, 140))
    x = deco.uniform(200, 600)
    while x < w:
        for _ in range(deco.randint(2, 5)):
            water_lily(L, deco, x + deco.gauss(0, 90), deco.uniform(780, 920), deco.uniform(26, 52),
                       rgba(160, 186, 132, 240), rgba(253, 252, 246))
        x += deco.uniform(160, 460)

    # ---------------------------------------------------------------- 배 아래 물
    w = pa.layer_width(width, "ground")
    layers["ground"] = L = Layer(w)
    L.under([("poly", [(-20, 830), (w + 20, 830), (w + 20, H + 60), (-20, H + 60)], rgba(214, 222, 230, 230))], 24)
    pa.water_streaks(L, rng, 0, w, 826, H, int(w / 10), rgba(255, 244, 214, 180))
    for gx in range(900, int(w), 1600):
        fr.glitter(L, deco, gx, 830, H, 300, 200, rgba(255, 240, 196, 190))
    for _ in range(int(w / 120)):  # 흘러가는 흰 꽃잎
        x, y = deco.uniform(0, w), deco.uniform(840, H)
        r = deco.uniform(4, 9)
        L.ellipse((x - r, y - r * 0.4, x + r, y + r * 0.4), rgba(255, 252, 244, 220))

    layers["props"] = Layer(pa.layer_width(width, "props"))

    # ---------------------------------------------------------------- 앞: 물안개, 가끔 흐린 수련 잎
    w = pa.layer_width(width, "front")
    layers["front"] = L = Layer(w)
    x = deco.uniform(600, 1400)
    while x < w:
        water_lily(L, deco, x, deco.uniform(1030, 1070), deco.uniform(60, 90), rgba(170, 190, 146, 220), rgba(253, 252, 246))
        x += deco.uniform(1500, 2600)
    L.haze(pa.mist(rng, 0, w, H - 30, 150, rgba(255, 255, 252, 140), int(w / 240)), 32)

    return fr._finish(layers, "crossing", (255, 248, 228), (236, 234, 230), tweak=fr.BRIGHT_TWEAK)
