"""6. 낡은 철교 (실루엣 화풍, #140).

밤으로 넘어가는 남보라 하늘, 녹슨 갈색 철교, 안개 속 희미한 빛. 해는 오른쪽 지평선 아래로 막 졌고
(오른쪽 낮은 하늘에 노을 끝자락), 왼쪽 위에 달이 떴다. 빛은 달빛(차고 푸른)과 노을 끝(분홍), 그리고
강 건너 마을 창문·강둑 가로등의 따뜻한 점 몇 개뿐이다.

게임과 맞춘 것(바꾸지 말 것):
- 6-2에서 철교가 끊긴다: break_x = 6-2 + 260 (3700). 끊긴 끝 아래로 강과 안개가 보이고,
  BankLight_6-3의 디딤돌(코드가 그린다, x 3725~4145, y 965~1036)이 그 안개 속에 있다.
- 강둑: bank_x = break_x + 420. 강둑 비탈은 (bank_x - 160, 화면 아래)에서 (bank_x + 120, 792)로 오른다.
  그 오른쪽이 6-3 강둑 길(땅 y = 792).
- 교각 자리(mid 층 세계 x 300·1500·2700), 위 현과 수직재·사재(props, 320px 간격).
"""

from __future__ import annotations

import math
import random

import placeholder_art as pa
from placeholder_art import H, Layer, rgba

MOON = (0.2, 190)              # 하늘 층 폭 비율, y
GLOW = (0.82, 640)             # 노을 끝자락
FOG = (150, 140, 186)          # 안개·먼 공기 색


def _mix(c, t, target=FOG, a=255):
    return rgba(*(round(c[i] + (target[i] - c[i]) * t) for i in range(3)), a)


def _finish(layers, place_id, light, shade, tweak=None):
    """pa.finish와 같지만, 층별 마무리 값을 이 장소에 맞게 조금 바꾼다(tweak: 이름 → 7개 값)."""
    saved = dict(pa.PAINT)
    try:
        for k, v in (tweak or {}).items():
            pa.PAINT[k] = v
        return pa.finish(layers, place_id, light, shade)
    finally:
        pa.PAINT.clear()
        pa.PAINT.update(saved)


def _pine(L: Layer, x: float, y: float, h: float, body, rim) -> None:
    """뾰족한 전나무: 층층이 처진 가지."""
    wd = h * 0.32
    pts = [(x, y - h)]
    for k in range(1, 6):
        t = k / 5
        pts.append((x + wd * t * 0.9, y - h + h * t * 0.86))
        pts.append((x + wd * t * 0.55, y - h + h * t * 0.86 - h * 0.05))
    pts.append((x + wd * 0.08, y))
    pts.append((x - wd * 0.08, y))
    left = [(2 * x - px, py) for px, py in reversed(pts[1:-2])]
    shape = pts[:-2] + [pts[-2], pts[-1]] + left
    L.poly([(px + 2, py - 2) for px, py in shape], rim)
    L.poly(shape, body)


def _lit_window(L: Layer, x: float, y: float, s: float = 1.0) -> None:
    L.rect(x, y, x + 5 * s, y + 6 * s, rgba(255, 206, 128, 235))


def _lamp(L: Layer, x: float, base: float, glow_layer: Layer) -> None:
    """강둑의 낡은 가로등: 가는 쇠기둥, 굽은 팔, 따뜻한 등과 안개 속 번진 빛."""
    pole = rgba(46, 38, 46)
    L.rect(x - 4, base - 300, x + 4, base, pole)
    L.rect(x - 10, base - 14, x + 10, base, pole)
    L.line([(x, base - 296), (x + 18, base - 318), (x + 44, base - 316)], pole, 5)
    L.poly([(x + 32, base - 316), (x + 56, base - 316), (x + 52, base - 296), (x + 36, base - 296)], pole)
    L.ellipse((x + 37, base - 300, x + 51, base - 288), rgba(255, 220, 150))
    glow_layer.haze([("ellipse", (x - 90, base - 420, x + 180, base - 170), rgba(255, 200, 130, 40)),
                     ("ellipse", (x + 10, base - 330, x + 80, base - 262), rgba(255, 226, 170, 120)),
                     ("poly", [(x + 36, base - 292), (x + 52, base - 292), (x + 120, base), (x - 30, base)], rgba(255, 210, 150, 30))], 30)


def paint(width: float, markers: dict[str, float]) -> dict[str, Layer]:
    rng = random.Random("bridge")
    deco = random.Random("bridge_deco")
    mk = markers.get
    layers: dict[str, Layer] = {}
    break_x = mk("6-2", 3440) + 260
    bank_x = break_x + 420

    # ---------------------------------------------------------------- 하늘
    w = pa.layer_width(width, "sky")
    sky = pa.vertical_gradient(w, [
        (0.0, (14, 14, 38)), (0.28, (34, 30, 70)), (0.48, (70, 56, 106)),
        (0.62, (122, 92, 138)), (0.7, (176, 122, 150)), (1.0, (96, 74, 120)),
    ])
    mx, my = w * MOON[0], MOON[1]
    gx, gy = w * GLOW[0], GLOW[1]
    pa.add_glow(sky, gx, gy, 1200, (236, 150, 150), 0.35)
    pa.add_glow(sky, gx, gy, 380, (255, 190, 160), 0.35)
    pa.add_glow(sky, mx, my, 700, (150, 160, 210), 0.35)
    pa.add_glow(sky, mx, my, 140, (220, 224, 245), 0.55)
    layers["sky"] = L = Layer(w, sky)
    # 밤 구름: 길고 얇은 층구름. 몸은 어둡고, 아랫단은 노을 끝에, 윗단은 달빛에 물든다.
    bands_dark, bands_low, bands_top = [], [], []
    for _ in range(9):
        cx, cy = rng.uniform(0, w), rng.uniform(300, 520)
        cw, ch = rng.uniform(500, 1100), rng.uniform(16, 34)
        near_glow = max(0.0, 1 - abs(cx - gx) / 1400)
        bands_dark.append(("ellipse", (cx - cw / 2, cy - ch / 2, cx + cw / 2, cy + ch / 2), rgba(52, 44, 86, 200)))
        bands_low.append(("ellipse", (cx - cw * 0.45, cy + ch * 0.05, cx + cw * 0.42, cy + ch * 0.5),
                          rgba(214, 140, 150, int(60 + 120 * near_glow))))
        bands_top.append(("ellipse", (cx - cw * 0.35, cy - ch * 0.5, cx + cw * 0.3, cy - ch * 0.1), rgba(170, 170, 220, 70)))
    L.under(bands_dark, 6)
    L.haze(bands_low, 5)
    L.haze(bands_top, 6)
    for _ in range(220):  # 별: 위로 갈수록 많고 또렷하다
        x, y = deco.uniform(0, w), deco.uniform(8, 470) ** 1.0
        y = 8 + (y - 8) * deco.random() ** 0.6
        r = deco.uniform(0.6, 1.8)
        L.ellipse((x - r, y - r, x + r, y + r), rgba(226, 228, 250, int(230 - y * 0.35)))
    L.ellipse((mx - 34, my - 34, mx + 34, my + 34), rgba(240, 240, 252))  # 달
    L.ellipse((mx - 18, my - 20, mx + 2, my - 2), rgba(222, 224, 240))  # 달 무늬
    L.ellipse((mx + 6, my + 4, mx + 20, my + 16), rgba(226, 228, 244))
    wisps = []
    for _ in range(10):  # 달빛을 받은 가는 구름 줄
        cx, cy = deco.uniform(0, w), deco.uniform(120, 300)
        ln = deco.uniform(260, 620)
        wisps.append(("line", [(cx, cy), (cx + ln * 0.5, cy - 4), (cx + ln, cy + 3)], rgba(180, 176, 220, 60), deco.uniform(5, 10)))
    L.haze(wisps, 6)

    # ---------------------------------------------------------------- 지평선: 아주 먼 산맥
    w = pa.layer_width(width, "horizon")
    layers["horizon"] = L = Layer(w)
    pts = pa.ridge(rng, w, 560, 110, waves=4)
    pa._rim_ridge(L, pts, _mix((62, 56, 112), 0.4), rgba(170, 150, 200, 110), 1.5)
    pa._slope_shade(L, pts, rgba(40, 34, 80, 70), 220, 28)
    L.haze([("poly", [(-20, 600), (w + 20, 600), (w + 20, 690), (-20, 690)], rgba(*FOG, 150))], 30)

    # ---------------------------------------------------------------- 먼 강 건너: 숲 언덕과 불 켜진 마을
    w = pa.layer_width(width, "far")
    layers["far"] = L = Layer(w)
    body = _mix((40, 36, 74), 0.26)
    rim = rgba(150, 140, 196, 120)
    pts = pa.ridge(rng, w, 628, 60, waves=3)
    pa._rim_ridge(L, pts, body, rim, 2)
    pa._slope_shade(L, pts, rgba(30, 26, 60, 80), 160, 20)
    x = 60.0
    while x < w:  # 능선을 덮은 전나무 숲
        _pine(L, x, pa._ridge_y(pts, x) + 8, deco.uniform(34, 70), body, rim)
        x += deco.uniform(14, 40) if deco.random() < 0.8 else deco.uniform(150, 400)
    for vx in (w * 0.18, w * 0.58):
        pa._village(L, deco, vx, lambda gx_: pa._ridge_y(pts, gx_), body, rim)
        for _ in range(9):  # 창문 몇 개에 불이 켜졌다
            wx = vx + deco.uniform(10, 300)
            _lit_window(L, wx, pa._ridge_y(pts, wx) - deco.uniform(4, 18), 0.8)
    L.haze([("ellipse", (vx - 80, 560, vx + 380, 660), rgba(255, 196, 140, 40)) for vx in (w * 0.18, w * 0.58)], 30)
    L.haze([("poly", [(-20, 650), (w + 20, 650), (w + 20, 720), (-20, 720)], rgba(*FOG, 130))], 24)

    # ---------------------------------------------------------------- 가까운 강 건너: 버드나무·갈대 둑
    w = pa.layer_width(width, "hills")
    layers["hills"] = L = Layer(w)
    body = _mix((24, 22, 44), 0.1)
    rim = rgba(130, 124, 180, 130)
    pts = pa.ridge(rng, w, 690, 22, waves=3)
    pa._rim_ridge(L, pts, body, rim, 2.5)
    x = deco.uniform(100, 300)
    while x < w:
        if deco.random() < 0.55:
            pa._blob_tree(L, deco, x, pa._ridge_y(pts, x) + 6, deco.uniform(30, 52), body, rim)
        else:
            pa._poplar(L, x, pa._ridge_y(pts, x) + 6, deco.uniform(110, 170), body, rim)
        x += deco.uniform(120, 420)
    # 강가 작은 오두막(불빛 하나)
    hx = w * 0.42
    hy = pa._ridge_y(pts, hx) + 8
    L.rect(hx, hy - 40, hx + 60, hy + 4, body)
    L.poly([(hx - 8, hy - 40), (hx + 30, hy - 70), (hx + 68, hy - 40)], body)
    _lit_window(L, hx + 22, hy - 28, 1.4)
    L.haze([("ellipse", (hx - 40, hy - 70, hx + 100, hy + 10), rgba(255, 196, 140, 50))], 16)

    # ---------------------------------------------------------------- 강(가운데): 하늘빛이 비친 물, 교각, 달빛 길
    w = pa.layer_width(width, "mid")
    layers["mid"] = L = Layer(w)
    L.rect(-20, 716, w + 20, H, rgba(44, 42, 76))
    L.rect(-20, 716, w + 20, 760, rgba(92, 74, 112))  # 먼 물은 노을빛을 받아 밝다
    L.haze([("poly", [(-20, 740), (w + 20, 740), (w + 20, 820), (-20, 820)], rgba(70, 60, 104, 200))], 20)
    pa.water_streaks(L, rng, 0, w, 722, H, int(w / 20), rgba(150, 140, 190, 110))
    mxl = w * 0.2  # 달빛 길(달 아래쪽 물)
    for k in range(90):
        y = 724 + k * 3.8
        half = 14 + k * 1.6
        cx = mxl + deco.uniform(-10, 10)
        if deco.random() < 0.75:
            L.line([(cx - half * deco.uniform(0.2, 1), y), (cx + half * deco.uniform(0.2, 1), y)],
                   rgba(214, 214, 240, int(170 - k * 1.4)), deco.uniform(1.2, 2.4))
    gxl = pa.layer_x(7200, "mid")  # 노을 끝 빛이 물에
    for k in range(40):
        y = 722 + k * 3
        L.line([(gxl - 60 - k * 4, y), (gxl + 60 + k * 4, y)], rgba(236, 160, 160, int(110 - k * 2.5)), 1.6)
    for wx in (300, 1500, 2700):  # 철교 교각(돌, 아래는 물에 잠긴다)
        px = pa.layer_x(wx, "mid")
        L.poly([(px - 46, 690), (px + 46, 690), (px + 54, H), (px - 54, H)], rgba(62, 52, 66))
        L.rect(px + 22, 690, px + 46, H, rgba(84, 70, 84))  # 노을 쪽 면
        for by in range(700, 1060, 34):
            L.line([(px - 50, by), (px + 50, by)], rgba(50, 42, 56), 2)
        L.line([(px - 70, 760), (px + 70, 760)], rgba(150, 140, 190, 120), 2)  # 물에 닿은 자리
    L.haze(pa.mist(rng, 0, w, 735, 110, rgba(160, 150, 196, 120), int(w / 200)), 30)

    # ---------------------------------------------------------------- 가까운 물: 잔물결, 떠도는 안개
    w = pa.layer_width(width, "near")
    layers["near"] = L = Layer(w)
    pa.water_streaks(L, rng, 0, w, 800, H, int(w / 14), rgba(132, 124, 176, 120))
    for _ in range(int(w / 60)):  # 달빛을 받은 물결 끝
        x, y = deco.uniform(0, w), deco.uniform(820, H)
        L.line([(x, y), (x + deco.uniform(14, 40), y)], rgba(210, 210, 240, 150), 1.6)
    L.haze(pa.mist(rng, 0, w, 900, 150, rgba(170, 160, 204, 110), int(w / 160)), 34)

    # ---------------------------------------------------------------- 땅: 철판 바닥·거더, 끊긴 끝, 강둑
    w = pa.layer_width(width, "ground")
    layers["ground"] = L = Layer(w)
    deck, deck_lit, dark = rgba(96, 64, 58), rgba(140, 92, 74), rgba(64, 44, 44)
    L.rect(-20, 792, break_x, 838, deck)
    L.rect(-20, 792, break_x, 798, deck_lit)  # 판 위 끝(달빛)
    for x in range(0, int(break_x), 120):
        L.line([(x, 794), (x, 836)], dark, 2)
        for ry in (804, 828):
            L.ellipse((x + 10, ry - 3, x + 16, ry + 3), rgba(150, 108, 86))
    for _ in range(int(break_x / 50)):  # 녹물 자국
        x = deco.uniform(0, break_x - 60)
        L.line([(x, 806), (x + deco.uniform(-3, 3), 836)], rgba(140, 82, 52, 120), deco.uniform(2, 5))
    for ry in (796, 816):  # 낡은 레일 두 줄
        L.rect(-20, ry - 3, break_x - 30, ry + 2, rgba(118, 96, 88))
        L.rect(-20, ry - 3, break_x - 30, ry - 2, rgba(170, 150, 150))
    L.rect(-20, 838, break_x - 40, 900, dark)  # 거더
    x = 0
    while x < break_x - 90:  # 거더의 X자 격자
        L.line([(x, 842), (x + 60, 896)], rgba(50, 34, 36), 5)
        L.line([(x + 60, 842), (x, 896)], rgba(50, 34, 36), 5)
        L.line([(x, 842), (x, 896)], rgba(80, 56, 52), 4)
        x += 60
    L.rect(-20, 838, break_x - 40, 844, rgba(110, 76, 64))
    L.poly([(break_x - 120, 792), (break_x, 796), (break_x - 30, 812), (break_x + 20, 826), (break_x - 60, 838),
            (break_x - 40, 870), (break_x - 140, 900), (break_x - 140, 792)], deck)  # 끊긴 끝
    L.line([(break_x - 30, 796), (break_x + 40, 830), (break_x + 60, 880)], rgba(118, 96, 88), 4)  # 휘어 늘어진 레일
    L.line([(break_x - 60, 816), (break_x + 10, 860), (break_x + 18, 930)], rgba(118, 96, 88), 4)
    # 강둑: 비탈과 그 위 길
    bank = [(bank_x - 160, H + 10), (bank_x - 60, 960), (bank_x + 20, 880), (bank_x + 120, 792), (w + 20, 792), (w + 20, H + 10)]
    L.poly(bank, rgba(42, 40, 58))
    L.poly([(bank_x + 120, 792), (w + 20, 792), (w + 20, 806), (bank_x + 110, 806)], rgba(90, 86, 104))  # 길 윗면(달빛)
    pa.pebbles(L, rng, bank_x, w, 812, H, int((w - bank_x) / 40), rgba(48, 46, 62), rgba(70, 68, 86))
    L.haze([("poly", [(bank_x, 900), (w + 20, 900), (w + 20, H + 10), (bank_x, H + 10)], rgba(28, 26, 44, 150))], 30)
    # 강둑 길: 흙길 띠, 그 아래는 풀 덮인 비탈(풀 포기, 끝이 달빛에 은빛)
    L.poly([(bank_x + 120, 800), (w + 20, 800), (w + 20, 846), (bank_x + 60, 846)], rgba(74, 66, 80))
    for _ in range(int((w - bank_x) / 30)):
        x = deco.uniform(bank_x + 120, w)
        L.line([(x, 812 + deco.uniform(0, 30)), (x + deco.uniform(30, 90), 812 + deco.uniform(0, 30))], rgba(92, 84, 100, 140), 2)
    x = bank_x + 40
    while x < w:
        base = deco.uniform(856, H + 10)
        for _ in range(deco.randint(6, 12)):
            bx = x + deco.gauss(0, 14)
            hh = deco.uniform(20, 60) * (0.6 + (base - 850) / 400)
            lean = deco.uniform(-16, 4)
            L.line([(bx, base), (bx + lean * 0.4, base - hh * 0.6), (bx + lean, base - hh)], rgba(44, 52, 62), 2.2)
            L.line([(bx + lean * 0.7, base - hh * 0.75), (bx + lean, base - hh)], rgba(150, 156, 196, 180), 1.6)
        x += deco.uniform(30, 90)
    for _ in range(40):  # 비탈의 돌
        t = deco.random()
        sx = bank_x - 140 + t * 240
        sy = H - t * 260 + deco.uniform(-10, 10)
        r = deco.uniform(8, 18)
        L.ellipse((sx - r, sy - r * 0.6, sx + r, sy + r * 0.6), rgba(70, 68, 86))

    # ---------------------------------------------------------------- 하윤 뒤: 트러스, 가로등, 강둑 갈대
    w = pa.layer_width(width, "props")
    layers["props"] = L = Layer(w)
    rust, rust_lit, rust_dark = rgba(108, 70, 60), rgba(158, 100, 82), rgba(70, 46, 46)
    end = break_x - 60
    L.line([(-20, 300), (end - 80, 300), (end, 360)], rust, 16)  # 위 현(끝이 꺾였다)
    L.line([(-20, 294), (end - 80, 294)], rust_lit, 4)
    for xx in range(0, int(end - 100), 40):  # 위 현의 리벳
        L.ellipse((xx - 2, 297, xx + 2, 301), rust_dark)
    x = 0
    while x < end - 100:
        L.line([(x, 300), (x, 792)], rust, 12)
        L.line([(x + 4, 300), (x + 4, 792)], rust_lit, 3)
        nx = min(x + 320, end - 40)
        L.line([(x, 300), (nx, 792)], rgba(96, 60, 54), 8)
        L.line([(x + 160, 320), (x + 160, 360), (x + 20, 340)], rust_dark, 3)  # 가로 보강재 끝
        L.line([(x, 560), (x + 320, 560)], rgba(90, 58, 52), 5)  # 중간 가로재
        for ry in range(320, 780, 46):
            L.ellipse((x - 3, ry - 3, x + 3, ry + 3), rust_dark)
        x += 320
    L.line([(end - 40, 360), (end - 10, 520)], rust, 9)  # 늘어진 부재
    L.line([(end - 10, 520), (end + 6, 600)], rust, 6)
    L.line([(end - 90, 300), (end - 60, 250), (end - 30, 236)], rust, 6)  # 꺾여 솟은 끝
    for _ in range(14):  # 녹물 줄기
        sx = deco.uniform(0, end - 120)
        L.line([(sx, 304), (sx + deco.uniform(-2, 2), 304 + deco.uniform(30, 120))], rgba(150, 84, 50, 110), deco.uniform(2, 4))
    for lx in (bank_x + 600, bank_x + 2200):
        _lamp(L, lx, 794, L)
    x = bank_x + 200
    while x < w:
        pa.reeds(L, rng, x, 0.6, rgba(58, 60, 76), rgba(52, 48, 66), base=796)
        x += rng.uniform(500, 1100)

    # ---------------------------------------------------------------- 앞: 흐린 트러스 사재, 강둑 갈대, 안개
    w = pa.layer_width(width, "front")
    layers["front"] = L = Layer(w)
    fend = pa.layer_x(break_x, "front")
    x = 400.0
    while x < fend - 200:
        L.haze([pa.soft_rect(x - 9, -10, x + 9, H + 10, rgba(58, 40, 42, 200)),
                ("line", [(x, -10), (x + 520, H + 10)], rgba(62, 42, 42, 150), 9)], 5)
        x += 900
    x = pa.layer_x(bank_x, "front") + 300
    while x < w:
        pa.reeds(L, rng, x, 1.0, rgba(34, 34, 50), rgba(30, 28, 42))
        x += rng.uniform(900, 1700)
    L.haze(pa.mist(rng, 0, w, H - 60, 160, rgba(160, 150, 196, 90), int(w / 300)), 30)

    return _finish(layers, "bridge", (210, 180, 220), (40, 40, 90), tweak={
        "ground": (0.0, 0.06, 0.02, 0.04, 0.16, 0.45, 0.2),
        "props": (0.0, 0.05, 0.016, 0.04, 0.14, 0.7, 0.3),
    })
