"""집 물건 그리기(#151). 세계 크기(하윤 줄, 바닥 y 810) 좌표, 원점은 물건 바닥 가운데(x, 바닥 y).

눈높이가 y 210(소실점)이라 방 안 물건은 위에서 조금 내려다본다: 위를 향한 면(탁자 윗면, 의자 앉는 판,
바구니 입구)이 얇게 보인다. 높이 y의 면에서 앞뒤 깊이 d는 화면에서 top_h(y, d)만큼 두께로 보인다.

`python3 tools/painters/house_objects.py <이름…> <출력.png>`로 물건만 따로 크게 그려 본다(보면서 고치기).
"""
from __future__ import annotations

import math
import random
import sys

import ink
from ink import Ink, alpha, dark, lite, mix

VP_Y = 210.0
LINE = ink.LINE


def top_h(y: float, d: float) -> float:
    """높이 y에 있는 깊이 d짜리 수평면이 화면에서 보이는 두께."""
    return max(0.0, (y - VP_Y) / 600.0 * d * 0.5)


def ell(c: Ink, cx, cy, rx, ry, fill, lw=1.8, lc=None, cast=False, grad=None):
    pts = ink.ellipse_pts(cx - rx, cy - ry, cx + rx, cy + ry, 48)
    if grad:
        c.grad(pts, grad[0], grad[1], axis=grad[2] if len(grad) > 2 else "y", lw=lw, lc=lc, cast=cast)
    else:
        c.poly(pts, fill, lw=lw, lc=lc, cast=cast)


def leg(c: Ink, x, y0, y1, w, col, taper=0.7, turned=True):
    """깎은 나무 다리(아래로 갈수록 가늘고, 가운데 마디)."""
    w2 = w * taper
    c.grad([(x - w / 2, y0), (x + w / 2, y0), (x + w2 / 2, y1), (x - w2 / 2, y1)], lite(col, 0.2), dark(col, 0.25), axis="x", lw=1.4, cast=True)
    if turned:
        m = y0 + (y1 - y0) * 0.3
        ell(c, x, m, w * 0.62, 4, lite(col, 0.1), lw=1.2)


# ---------------------------------------------------------------- 거실


def armchair(c: Ink, x, base, col=(124, 96, 124, 255)):
    """날개 안락의자(조금 비스듬히 앞에서). 폭 330, 높이 300."""
    lt, dk = lite(col, 0.22), dark(col, 0.25)
    # 등받이(위가 둥글고 양옆이 날개처럼 벌어진다)
    back = [(x - 120, base - 150), (x - 128, base - 250), (x - 110, base - 292), (x - 60, base - 306), (x + 60, base - 306),
            (x + 110, base - 292), (x + 128, base - 250), (x + 120, base - 150)]
    c.grad(back, lt, col, cast=True)
    for i in range(3):  # 단추 누빔(마름모로 접힌 자국)
        for j in range(2):
            bx, by = x - 60 + i * 60, base - 262 + j * 52
            c.ellipse(bx - 3, by - 3, bx + 3, by + 3, dk, line=False)
            for dx, dy in ((-14, -12), (14, -12), (-14, 12), (14, 12)):
                c.stroke([(bx, by), (bx + dx, by + dy)], 1.0, alpha(dark(col, 0.3), 120))
    c.stroke([(x - 100, base - 160), (x + 100, base - 160)], 1.4, dark(col, 0.35))
    # 앉는 방석: 윗면(밝다) + 앞면
    th = top_h(base - 130, 140)
    th += 16
    c.grad([(x - 118, base - 130 - th), (x + 118, base - 130 - th), (x + 126, base - 130), (x - 126, base - 130)], mix(col, (255, 255, 255, 255), 0.14), col, line=False)
    c.grad(ink.round_rect_pts(x - 128, base - 132, x + 128, base - 70, 14), col, dk, lw=1.8, cast=True)
    c.stroke([(x - 110, base - 104), (x + 110, base - 104)], 1.2, alpha(dark(col, 0.3), 160))
    # 팔걸이: 둥글게 말린 윗부분 + 옆면
    for k in (-1, 1):
        ax = x + k * 138
        arm = [(ax - 26, base - 70), (ax - 26, base - 168), (ax - 20, base - 192), (ax, base - 200), (ax + 20, base - 192), (ax + 26, base - 168), (ax + 26, base - 70)]
        c.grad(arm, lt, dk, axis="x" if k < 0 else "x", cast=True)
        ell(c, ax, base - 178, 18, 18, lite(col, 0.3), lw=1.4)
        ell(c, ax, base - 178, 8, 8, dark(col, 0.15), lw=1.0)
    # 치마 단과 다리
    c.rect(x - 160, base - 70, x + 160, base - 46, dark(col, 0.15), lw=1.6, cast=True)
    for k in range(17):
        xx = x - 152 + k * 19
        c.stroke([(xx, base - 68), (xx, base - 48)], 1.0, alpha(dark(col, 0.35), 140))
    for k in (-1, 1):
        leg(c, x + k * 140, base - 46, base, 16, (96, 64, 42, 255))
    # 뜨개 덮개: 왼쪽 팔걸이 위에 접혀 걸쳐 양쪽으로 늘어진다(술 달린 끝)
    th_col = (238, 226, 198, 255)
    ax = x - 138
    throw = [(ax - 34, base - 112), (ax - 32, base - 176), (ax - 18, base - 202), (ax, base - 208), (ax + 18, base - 202), (ax + 32, base - 176),
             (ax + 36, base - 118), (ax + 20, base - 108), (ax + 4, base - 116), (ax - 14, base - 104)]
    c.grad(throw, lite(th_col, 0.12), dark(th_col, 0.15), axis="x", lw=1.6)
    for k in range(5):
        xx = ax - 24 + k * 12
        c.stroke([(xx, base - 196 + abs(k - 2) * 4), (xx + 1, base - 116)], 1.0, alpha(dark(th_col, 0.25), 150))
    for k in range(12):
        xx = ax - 32 + k * 6
        c.stroke([(xx, base - 110 + (k % 3)), (xx - 1, base - 98 + (k % 3))], 1.2, dark(th_col, 0.12))


def side_table(c: Ink, x, base, col=(150, 96, 58, 255)):
    """둥근 옆 탁자(외다리 + 세 발) 위에 작은 스탠드와 찻잔."""
    top = base - 200
    th = top_h(top, 90)
    ell(c, x, top, 62, th / 2 + 2, lite(col, 0.3), lw=1.6)
    c.grad([(x - 62, top), (x + 62, top), (x + 62, top + 10), (x - 62, top + 10)], col, dark(col, 0.2), lw=1.4, cast=True)
    leg(c, x, top + 10, base - 30, 14, col, taper=0.8)
    for k in (-1, 0, 1):
        c.stroke([(x, base - 34), (x + k * 40, base - 4)], 6, dark(col, 0.1))
        c.stroke([(x, base - 34), (x + k * 40, base - 4)], 2, lite(col, 0.2))
    # 스탠드: 둥근 받침, 가는 기둥, 위가 좁은 갓
    ell(c, x - 14, top - 4, 22, 5, (120, 100, 80, 255), lw=1.2)
    c.stroke([(x - 14, top - 6), (x - 14, top - 86)], 3, (110, 90, 70, 255))
    shade = (246, 222, 170, 255)
    c.grad([(x - 46, top - 82), (x + 18, top - 82), (x + 4, top - 130), (x - 32, top - 130)], lite(shade, 0.15), dark(shade, 0.12), lw=1.6, cast=True)
    ell(c, x - 14, top - 130, 18, 3, lite(shade, 0.3), lw=1.0)
    # 찻잔과 받침
    ell(c, x + 30, top - 2, 18, 4, (240, 236, 226, 255), lw=1.2)
    c.grad([(x + 18, top - 18), (x + 42, top - 18), (x + 38, top - 4), (x + 22, top - 4)], (250, 248, 240, 255), (214, 210, 200, 255), lw=1.2)
    c.stroke([(x + 42, top - 15), (x + 49, top - 12), (x + 41, top - 7)], 1.6)


def yarn_basket(c: Ink, x, base):
    """털실 바구니: 입구가 보이는 둥근 바구니, 털실 공은 반쯤 잠기고 뜨개바늘이 꽂혀 있다."""
    wick = (186, 140, 90, 255)
    rim_y = base - 64
    rx, ry = 52, top_h(rim_y, 100) / 2 + 4
    ell(c, x, rim_y, rx, ry, dark(wick, 0.45), lw=1.6)  # 안쪽(어둡다)
    for bx, by, col in ((-20, -6, (200, 80, 70, 255)), (14, -10, (110, 140, 180, 255)), (34, -2, (230, 200, 110, 255))):
        ell(c, x + bx, rim_y + by, 19, 19, None, grad=(lite(col, 0.25), dark(col, 0.2)))
        for k in range(3):
            c.stroke([(x + bx - 14, rim_y + by - 8 + k * 7), (x + bx + 14, rim_y + by - 12 + k * 7)], 1.0, alpha(dark(col, 0.3), 170))
    c.stroke([(x - 4, rim_y - 4), (x - 30, rim_y - 52)], 2.4, (200, 196, 190, 255))
    c.stroke([(x + 6, rim_y - 4), (x - 10, rim_y - 56)], 2.4, (200, 196, 190, 255))
    body = [(x - rx, rim_y), (x + rx, rim_y), (x + rx - 8, base - 4), (x + rx - 14, base), (x - rx + 14, base), (x - rx + 8, base - 4)]
    c.grad(body, lite(wick, 0.15), dark(wick, 0.25), axis="x", cast=True)
    for k in range(1, 5):
        y = rim_y + (base - rim_y) * k / 5
        c.stroke([(x - rx + 4 + k, y), (x + rx - 4 - k, y)], 1.2, dark(wick, 0.3))
    ell(c, x, rim_y, rx, ry, None, lw=2.2)  # 입구 테(앞쪽이 털실 공 위로)
    c.stroke(ink.ellipse_pts(x - rx, rim_y - ry, x + rx, rim_y + ry, 48)[0:25], 6, lite(wick, 0.2))
    c.stroke(ink.ellipse_pts(x - rx, rim_y - ry, x + rx, rim_y + ry, 48)[0:25], 1.6)


# ---------------------------------------------------------------- 식당


def ladder_chair(c: Ink, x, base, col=(150, 104, 66, 255), facing=1):
    """등받이 사다리 의자(앞에서 조금 비스듬히): 두 기둥 사이 가로살 셋, 골풀 엮은 앉는 판, 다리 넷."""
    seat_y = base - 150
    hw = 52
    th = top_h(seat_y, 120) + 10
    far = dark(col, 0.3)
    sk = 10 * facing  # 뒤쪽이 옆으로 비킨 만큼(비스듬히)
    # 뒤 다리 둘(먼 쪽, 짧게 보인다)
    for dx in (-hw + 6, hw - 6):
        leg(c, x + dx + sk, seat_y - th + 8, base - 16, 9, far, turned=False)
    # 등받이: 뒤 기둥 둘 + 가로살 셋(앞에서 보여 사다리처럼)
    top = seat_y - th - 190
    for dx in (-hw + 6, hw - 6):
        c.grad([(x + dx + sk - 6, top), (x + dx + sk + 6, top), (x + dx + sk + 6, seat_y - th + 4), (x + dx + sk - 6, seat_y - th + 4)],
               lite(col, 0.2), dark(col, 0.2), axis="x", lw=1.4, cast=True)
        ell(c, x + dx + sk, top - 4, 8, 7, lite(col, 0.15), lw=1.2)
    for k in range(3):
        y = top + 22 + k * 46
        bow = 2
        c.grad([(x - hw + 12 + sk, y), (x + sk, y + bow), (x + hw - 12 + sk, y), (x + hw - 12 + sk, y + 16), (x + sk, y + 16 + bow), (x - hw + 12 + sk, y + 16)],
               lite(col, 0.25), dark(col, 0.1), lw=1.4, cast=True)
    # 앉는 판: 윗면(골풀) + 앞 두께
    rush = (206, 176, 112, 255)
    seat = [(x - hw + 4 + sk, seat_y - th), (x + hw - 4 + sk, seat_y - th), (x + hw + 4, seat_y), (x - hw - 4, seat_y)]
    c.grad(seat, lite(rush, 0.25), rush, lw=1.6, cast=True)
    for k in range(1, 8):
        t = k / 8
        c.stroke([(x - hw + 4 + sk + (2 * hw - 8) * t, seat_y - th + 2), (x - hw - 4 + (2 * hw + 8) * t, seat_y - 2)], 1.0, alpha(dark(rush, 0.3), 150))
    c.grad([(x - hw - 4, seat_y), (x + hw + 4, seat_y), (x + hw + 4, seat_y + 12), (x - hw - 4, seat_y + 12)], col, dark(col, 0.15), lw=1.4)
    # 앞 다리 둘 + 가로대
    for dx in (-hw + 2, hw - 2):
        leg(c, x + dx, seat_y + 12, base, 12, col)
    c.grad([(x - hw + 4, base - 56), (x + hw - 4, base - 56), (x + hw - 4, base - 48), (x - hw + 4, base - 48)], col, dark(col, 0.2), lw=1.2)


def dining_table(c: Ink, x, base, w=340, cloth=(246, 242, 232, 255), col=(150, 96, 58, 255)):
    """식탁: 윗면이 보이고(위에서 내려다본다) 식탁보가 둥근 물결로 늘어진다."""
    top = base - 175
    th = top_h(top, 160) + 18
    hw = w / 2
    for dx in (-hw + 26, hw - 26):
        leg(c, x + dx, top + 44, base, 16, col)
    c.grad([(x - hw + 10, top - th), (x + hw - 10, top - th), (x + hw + 6, top), (x - hw - 6, top)], lite(cloth, 0.1), dark(cloth, 0.04), lw=1.6)
    hem = [(x - hw - 6, top)]
    n = 7
    for k in range(n):
        x0_ = x - hw - 6 + (w + 12) * k / n
        x1_ = x - hw - 6 + (w + 12) * (k + 1) / n
        for j in range(7):
            t = j / 6
            hem.append((x0_ + (x1_ - x0_) * t, top + 50 + math.sin(t * math.pi) * 8))
    hem.append((x + hw + 6, top))
    c.grad(hem, (238, 234, 224, 255), (206, 200, 192, 255), cast=True, lw=1.6)
    for k in range(1, n):
        xx = x - hw - 6 + (w + 12) * k / n
        c.stroke([(xx, top + 4), (xx, top + 48)], 1.2, alpha((186, 178, 170, 255), 170))


def rocking_chair(c: Ink, x, base, col=(156, 104, 64, 255)):
    """흔들의자(옆에서, 오른쪽을 본다): 위로 휜 흔들판, 살 등받이, 팔걸이."""
    far = dark(col, 0.3)
    seat_y = base - 140

    def rocker(off, cc, wv):
        pts = [(x - 120 + 240 * k / 24 + off, base - 4 - off * 0.5 - 30 * (2 * k / 24 - 1) ** 2) for k in range(25)]
        c.stroke(pts, wv, dark(cc, 0.2))
        c.stroke(pts, wv - 5, lite(cc, 0.12))
    rocker(10, far, 9)
    for dx in (-70, 66):  # 먼 다리
        c.stroke([(x + dx + 10, base - 10), (x + dx + 10, seat_y)], 7, far)
    # 등받이: 뒤로 조금 기운 두 기둥, 머리판, 살 다섯
    b0, b1 = (x - 66, seat_y), (x - 96, base - 400)
    for off, cc in ((10, far), (0, col)):
        c.stroke([(b0[0] + off, b0[1]), (b1[0] + off, b1[1])], 9, dark(cc, 0.15))
        c.stroke([(b0[0] + off - 1, b0[1]), (b1[0] + off - 1, b1[1])], 3, lite(cc, 0.15))
    head = [(b1[0] - 10, b1[1] - 2), (b1[0] + 24, b1[1] - 6), (b1[0] + 22, b1[1] + 30), (b1[0] - 8, b1[1] + 34)]
    c.grad(head, lite(col, 0.25), col, lw=1.6, cast=True)
    # 살: 머리판 아래에서 앉는 판까지, 기둥과 나란히
    for k in range(5):
        dx = -4 + k * 4
        c.stroke([(b0[0] + 5 + dx, seat_y - 4), (b1[0] + 6 + dx, b1[1] + 32)], 2.4, lite(col, 0.05))
    # 앉는 판(윗면 + 두께)
    th = top_h(seat_y, 110) + 8
    c.grad([(x - 72, seat_y - th), (x + 66, seat_y - th), (x + 74, seat_y), (x - 74, seat_y)], lite(col, 0.32), lite(col, 0.12), lw=1.6, cast=True)
    c.rect(x - 74, seat_y, x + 74, seat_y + 12, col, lw=1.4)
    # 가까운 다리, 흔들판
    for dx in (-72, 64):
        c.stroke([(x + dx, base - 14), (x + dx, seat_y + 10)], 9, dark(col, 0.1))
        c.stroke([(x + dx - 2, base - 14), (x + dx - 2, seat_y + 10)], 3, lite(col, 0.2))
    rocker(0, col, 11)
    # 팔걸이와 받침 살
    c.stroke([(x - 74, seat_y - 92), (x + 74, seat_y - 84)], 10, dark(col, 0.1))
    c.stroke([(x - 74, seat_y - 94), (x + 74, seat_y - 86)], 4, lite(col, 0.2))
    for xx in (x + 64, x + 20, x - 24):
        c.stroke([(xx, seat_y - 86), (xx, seat_y)], 4, dark(col, 0.05))


def newspapers(c: Ink, x, base):
    """쌓인 신문: 접힌 종이가 조금씩 어긋나 쌓였고 윗면에 글줄."""
    paper = (232, 226, 210, 255)
    y = base
    for k in range(5):
        h = 9
        off = ((k * 37) % 11) - 5
        th = top_h(y - h, 70)
        c.grad([(x - 44 + off, y - h), (x + 44 + off, y - h), (x + 44 + off, y), (x - 44 + off, y)], paper, dark(paper, 0.12), lw=1.2)
        if k == 4:
            c.poly([(x - 44 + off, y - h), (x + 44 + off, y - h), (x + 40 + off, y - h - th), (x - 40 + off, y - h - th)], lite(paper, 0.2), lw=1.2)
            for j in range(4):
                yy = y - h - th + 3 + j * (th - 4) / 4
                c.stroke([(x - 34 + off, yy), (x + (10 if j % 2 else 28) + off, yy)], 1.0, (150, 140, 130, 255))
        y -= h


def _blob(cx, cy, r, rng, n=None, rough=0.09, squash=0.82):
    """잎 덩어리 윤곽: 가장자리가 작은 잎처럼 오글오글한(조개 모양) 둥근 덩어리."""
    bumps = max(8, int(r / 4.5))
    n = n or bumps * 6
    ph = rng.uniform(0, math.tau)
    pts = []
    for k in range(n):
        a = k / n * math.tau
        rr = r * (1 + rough * 0.5 * math.sin(a * 2 + ph) + 0.11 * abs(math.sin(a * bumps / 2 + ph)))
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr * squash))
    return pts


def leaf_mass(c: Ink, rng, blobs, cols, light_dir=(-0.6, -0.8), outline=LINE):
    """셀 그늘로 칠한 나무갓(컷신 화풍): 덩어리마다 가운데 색 + 빛 쪽(왼쪽 위) 밝은 조개 모양 하나.
    아래쪽 덩어리일수록 어둡다. 바깥 윤곽만 선이 남는다(덩어리를 조금 크게 선 색으로 먼저 깐다)."""
    shapes = [_blob(x, y, r, rng) for x, y, r in blobs]
    for (x, y, r) in blobs:
        c.poly(_blob(x, y, r + 2.6, random.Random(int(x * 7 + y))), outline, line=False)
    y_min = min(b[1] for b in blobs)
    y_max = max(b[1] for b in blobs)
    order = sorted(range(len(blobs)), key=lambda i: blobs[i][1])
    for i in reversed(order):  # 아래(그늘)부터 그리고 위가 덮는다
        x, y, r = blobs[i]
        t = (y - y_min) / (y_max - y_min + 1)
        base = mix(cols[0], cols[2], t)
        c.poly(shapes[i], base, line=False)
        c.poly(_blob(x - r * 0.18, y - r * 0.22, r * 0.68, rng), mix(cols[1], base, t * 0.6), line=False)
        c.stroke(shapes[i][len(shapes[i]) // 8: len(shapes[i]) * 3 // 8], 1.1, alpha(dark(base, 0.35), 150))  # 아래쪽 안 윤곽(덩어리 구분)


def apple_tree_canopy(c: Ink, rng, cx, cy, wr=260, hr=150, apples=16):
    cols = [(176, 154, 72, 255), (226, 198, 104, 255), (108, 98, 54, 255)]  # 가운데·빛·그늘(누렇게 물든 늦가을 사과나무 잎)
    blobs = []
    for _ in range(16):  # 큰 덩어리
        a = rng.uniform(0, math.tau)
        rr = rng.uniform(0, 1) ** 0.6
        blobs.append((cx + math.cos(a) * wr * rr * 0.7, cy + math.sin(a) * hr * rr * 0.6, rng.uniform(60, 90)))
    for k in range(22):  # 가장자리 작은 잎 뭉치
        a = k / 22 * math.tau + rng.uniform(-0.1, 0.1)
        blobs.append((cx + math.cos(a) * wr * 0.78, cy + math.sin(a) * hr * 0.72, rng.uniform(34, 48)))
    leaf_mass(c, rng, blobs, cols)
    for _ in range(apples):
        a = rng.uniform(0, math.tau)
        rr = rng.uniform(0.25, 0.9)
        ax, ay = cx + math.cos(a) * wr * 0.8 * rr, cy + 10 + math.sin(a) * hr * 0.7 * rr
        c.grad(ink.ellipse_pts(ax - 10, ay - 10, ax + 10, ay + 10), (232, 70, 60, 255), (160, 28, 32, 255), lw=1.4)
        c.ellipse(ax - 5, ay - 7, ax - 1, ay - 3, (255, 214, 196, 255), line=False)
        c.stroke([(ax, ay - 9), (ax + 2, ay - 15)], 1.4, (90, 64, 40, 255))


def _leaf(c: Ink, x0, y0, ang, L, W, col):
    """잎 하나: 끝이 뾰족한 볼록한 잎(두 호), 가운데 잎맥."""
    ux, uy = math.cos(ang), math.sin(ang)
    nx, ny = -uy, ux
    side1, side2 = [], []
    for k in range(13):
        t = k / 12
        w = W * math.sin(math.pi * t) ** 0.8 * (1 - 0.25 * t)
        bend = math.sin(math.pi * t) * L * 0.08
        px, py = x0 + ux * L * t + nx * bend, y0 + uy * L * t + ny * bend + L * 0.12 * t * t
        side1.append((px + nx * w, py + ny * w))
        side2.append((px - nx * w, py - ny * w))
    pts = side1 + side2[::-1]
    c.grad(pts, lite(col, 0.25), dark(col, 0.2), lw=1.4)
    c.stroke([(x0, y0)] + [((a[0] + b[0]) / 2, (a[1] + b[1]) / 2) for a, b in zip(side1[1:-1], side2[1:-1])] + [side1[-1]], 1.1, lite(col, 0.4))


def potted_plant(c: Ink, x, base, rng, s=1.0):
    """큰 잎 화분(맨 앞 층용): 둥근 토분, 휘어 늘어지는 줄기 끝에 끝이 뾰족한 넓은 잎."""
    leaf = (78, 116, 70, 255)
    top = base - 86 * s
    leaves = []
    for k in range(10):
        a = math.radians(-165 + k * 16 + rng.uniform(-5, 5))
        ln = rng.uniform(110, 190) * s
        ex = x + math.cos(a) * ln
        ey = top + math.sin(a) * ln * 0.8 + (abs(math.cos(a)) ** 2) * 40 * s  # 옆으로 뻗은 줄기는 처진다
        leaves.append((a, ln, ex, ey))
    for a, ln, ex, ey in sorted(leaves, key=lambda v: -abs(math.cos(v[0]))):
        mx, my = (x + ex) / 2, (top + ey) / 2 - 24 * s
        bez = [((1 - t) ** 2 * x + 2 * (1 - t) * t * mx + t * t * ex, (1 - t) ** 2 * top + 2 * (1 - t) * t * my + t * t * ey) for t in [k / 10 for k in range(11)]]
        c.stroke(bez, 3 * s, dark(leaf, 0.25))
        col = mix(leaf, (116, 156, 86, 255), rng.uniform(0, 0.7))
        ang = math.atan2(ey - my, ex - mx) + 0.25 * (1 if ex > x else -1)
        _leaf(c, ex, ey, ang, rng.uniform(70, 96) * s, rng.uniform(20, 28) * s, col)
    pot = (184, 104, 66, 255)
    c.grad([(x - 56 * s, base - 76 * s), (x + 56 * s, base - 76 * s), (x + 44 * s, base), (x - 44 * s, base)], lite(pot, 0.15), dark(pot, 0.25), axis="x", lw=1.8)
    c.grad([(x - 62 * s, base - 94 * s), (x + 62 * s, base - 94 * s), (x + 62 * s, base - 74 * s), (x - 62 * s, base - 74 * s)], lite(pot, 0.25), pot, lw=1.6)
    O_ = top_h(base - 94 * s, 110 * s)
    ell(c, x, base - 94 * s, 60 * s, O_ / 2 + 3, (70, 50, 36, 255), lw=1.2)


OBJECTS = {
    "armchair": (armchair, 420, 340), "side_table": (side_table, 200, 360), "yarn_basket": (yarn_basket, 160, 140),
    "ladder_chair": (ladder_chair, 200, 380), "dining_table": (dining_table, 420, 260), "rocking_chair": (rocking_chair, 320, 420),
    "newspapers": (newspapers, 140, 90),
    "apple": (lambda c, x, b: apple_tree_canopy(c, __import__("random").Random(3), x, b - 200), 640, 420),
    "plant": (lambda c, x, b: potted_plant(c, x, b, __import__("random").Random(5)), 520, 360),
}


def preview(names, out):
    """물건만 따로 크게: 이름마다 칸 하나, 바닥선, 2배 확대."""
    from PIL import Image
    tiles = []
    for n in names:
        fn, w, h = OBJECTS[n]
        c = Ink(w + 40, h + 40)
        fn(c, (w + 40) / 2, h + 20)
        img = c.finish()
        bg = Image.new("RGBA", img.size, (232, 214, 180, 255))
        bg.alpha_composite(img)
        tiles.append(bg.resize((bg.width * 2, bg.height * 2), Image.LANCZOS))
    W = sum(t.width for t in tiles) + 10 * len(tiles)
    H = max(t.height for t in tiles)
    sheet = Image.new("RGB", (W, H), (80, 80, 80))
    x = 0
    for t in tiles:
        sheet.paste(t.convert("RGB"), (x, H - t.height))
        x += t.width + 10
    sheet.save(out)


if __name__ == "__main__":
    preview(sys.argv[1:-1], sys.argv[-1])
