#!/usr/bin/env python3
"""코드로 만드는 임시 소리. 진짜 녹음(CC0 등)이 오기 전까지 소리 없는 게임 대신 쓴다.

    python3 tools/placeholder_sound.py        # 전부 다시 만든다

결과: assets/audio/placeholder/ 아래 .ogg
  amb_<place_id>.ogg            장소 환경음(반복). 장소 씬의 Sound/Ambience가 튼다
  pos_<place_id>_<이름>.ogg      장소 안 한 자리에서 나는 소리(반복, 가까이 가면 커진다)
  step_<바닥>_NN.ogg            하윤 발소리(한 번). 재생은 A(하윤 스크립트)
  sfx_<이름>_NN.ogg             효과음(한 번)
진짜 소리로 바꿀 때는 같은 이름 파일을 assets/audio/ 아래에 넣고 placeholder 쪽을 지운다.

필요한 것: numpy, ffmpeg(libvorbis)
- 소리는 docs/design.md "사운드", docs/story.md 장면표 "복선·소리" 칸을 따른다.
- 기획서: "현실 소리가 점점 줄어든다" → 장소가 갈수록 소리 겹을 줄였다.
- 반복 소리는 주파수 영역에서 만들어(주기 잡음) 이음매 없이 돈다. 사건(풍경·풀벌레)도 끝에서 앞으로 감아 붙인다.
- 난수 씨앗을 고정해 늘 같은 소리가 나온다.
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/audio/placeholder"
RATE = 32000
LOOP = 24.0  # 환경음 길이(초)


# ---------------------------------------------------------------- 바탕


def n_samples(seconds: float) -> int:
    return int(round(seconds * RATE))


def shaped_noise(rng: np.random.Generator, seconds: float, shape) -> np.ndarray:
    """주파수마다 크기를 정한 잡음. 길이 그대로 주기적이라 이음매 없이 반복된다."""
    n = n_samples(seconds)
    freqs = np.fft.rfftfreq(n, 1.0 / RATE)
    mag = np.asarray(shape(np.maximum(freqs, 1.0)), dtype=np.float64)
    mag[0] = 0.0
    phase = rng.uniform(0, 2 * np.pi, len(freqs))
    x = np.fft.irfft(mag * np.exp(1j * phase), n)
    return x / (np.std(x) + 1e-12)


def band(lo: float, hi: float, tilt: float = 0.0):
    """lo~hi 사이를 부드럽게 통과. tilt: 주파수가 오를수록 dB/옥타브."""
    def f(fr):
        lo_g = 1.0 / (1.0 + (lo / fr) ** 4)
        hi_g = 1.0 / (1.0 + (fr / hi) ** 4)
        return lo_g * hi_g * (fr / 1000.0) ** (tilt / 6.02)
    return f


def periodic_lfo(rng: np.random.Generator, seconds: float, cycles: list[int], depth: float) -> np.ndarray:
    """반복 길이에 딱 맞는 느린 흔들림(0~1 근처). cycles: 한 바퀴에 몇 번 도는지."""
    t = np.arange(n_samples(seconds)) / RATE
    x = np.zeros_like(t)
    for c in cycles:
        x += np.sin(2 * np.pi * c * t / seconds + rng.uniform(0, 2 * np.pi)) / len(cycles)
    return np.clip(1.0 - depth + depth * (x * 0.5 + 0.5) * 2.0, 0.0, None)


def place_event(buf: np.ndarray, ev: np.ndarray, at: int, wrap: bool = True) -> None:
    """buf의 at 자리부터 ev를 더한다. wrap이면 끝을 넘친 부분은 앞으로 감는다."""
    n = len(buf)
    idx = (at + np.arange(len(ev)))
    if wrap:
        np.add.at(buf, idx % n, ev)
    else:
        keep = idx < n
        buf[idx[keep]] += ev[keep]


def env_ad(n: int, attack: float, decay: float) -> np.ndarray:
    """올라갔다 지수로 줄어드는 모양. 끝 25%는 0까지 부드럽게 내려 딸깍 소리를 막는다."""
    t = np.arange(n) / RATE
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    tail = np.ones(n)
    k = max(1, n // 4)
    tail[-k:] = 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, k))
    return a * np.exp(-t / decay) * tail


def db_rms(x: np.ndarray, db: float) -> np.ndarray:
    rms = np.sqrt(np.mean(x ** 2)) + 1e-12
    return x * (10 ** (db / 20.0) / rms)


def chime(rng: np.random.Generator, f0: float) -> np.ndarray:
    """처마 풍경 한 번: 어긋난 배음 + 긴 울림."""
    n = n_samples(5.0)
    t = np.arange(n) / RATE
    out = np.zeros(n)
    for ratio, amp, dec in ((1.0, 1.0, 1.6), (2.76, 0.45, 0.9), (5.4, 0.2, 0.5), (8.9, 0.08, 0.3)):
        out += amp * np.sin(2 * np.pi * f0 * ratio * t + rng.uniform(0, 6)) * np.exp(-t / dec)
    return out * env_ad(n, 0.002, 10.0)


def cricket(rng: np.random.Generator, seconds: float, f: float, rate: float, pulses: int, every: float) -> np.ndarray:
    """귀뚜라미 한 마리: f Hz 떨림이 rate Hz로 pulses번 끊겨 한 소리, every초마다."""
    buf = np.zeros(n_samples(seconds))
    pulse_n = n_samples(0.5 / rate)
    t = np.arange(pulse_n) / RATE
    pulse = np.sin(2 * np.pi * f * t) * np.sin(np.pi * np.arange(pulse_n) / pulse_n) ** 2
    pos = rng.uniform(0, every)
    while pos < seconds:
        for k in range(pulses):
            place_event(buf, pulse * rng.uniform(0.7, 1.0), n_samples(pos + k / rate))
        pos += every * rng.uniform(0.8, 1.25)
    return buf


def bubble(rng: np.random.Generator) -> np.ndarray:
    """물방울: 짧게 올라가는 음."""
    n = n_samples(rng.uniform(0.03, 0.07))
    t = np.arange(n) / RATE
    f0 = rng.uniform(350, 1100)
    f = f0 * (1 + 1.8 * t / t[-1])
    ph = 2 * np.pi * np.cumsum(f) / RATE
    return np.sin(ph) * np.sin(np.pi * np.arange(n) / n)


# ---------------------------------------------------------------- 장소 환경음


def amb_house(rng):
    # 방 공기 + 창밖 바람(먼) + 처마 풍경 가끔. 생활 소리가 남아 있는 집.
    room = db_rms(shaped_noise(rng, LOOP, band(40, 300, -3)), -46)
    wind = shaped_noise(rng, LOOP, band(80, 900, -4)) * periodic_lfo(rng, LOOP, [1, 2, 3], 0.6)
    out = room + db_rms(wind, -40)
    chimes = np.zeros_like(out)
    notes = [1568.0, 1760.0, 2093.0, 2349.0, 2637.0]  # 오음계
    for i in range(5):
        pos = n_samples(LOOP * (i + rng.uniform(0.1, 0.7)) / 5)
        for k in range(rng.integers(1, 3)):
            place_event(chimes, chime(rng, rng.choice(notes)) * rng.uniform(0.5, 1.0), pos + n_samples(k * rng.uniform(0.12, 0.3)))
    return out + db_rms(chimes, -38) * 1.0


def amb_field(rng):
    # 들판 바람(약·강이 오간다) + 억새 스치는 소리(바람 셀 때 커진다).
    gust = periodic_lfo(rng, LOOP, [1, 2, 5], 0.75)
    wind = shaped_noise(rng, LOOP, band(60, 1200, -5)) * gust
    rustle = shaped_noise(rng, LOOP, band(1800, 8000, -4)) * gust ** 2
    return db_rms(wind, -26) + db_rms(rustle, -37)


def amb_station(rng):
    # 노을 정적: 낮은 바람이 아주 조금, 멀리 웅웅거리는 공기.
    wind = shaped_noise(rng, LOOP, band(60, 600, -6)) * periodic_lfo(rng, LOOP, [1, 3], 0.5)
    air = shaped_noise(rng, LOOP, band(1500, 5000, -3))
    return db_rms(wind, -38) + db_rms(air, -52)


def amb_forest(rng):
    # 풀벌레 여러 마리 + 잎을 스치는 약한 바람.
    bugs = np.zeros(n_samples(LOOP))
    for f, rate, pulses, every, vol in ((4200, 28, 3, 0.9, 1.0), (4700, 32, 4, 1.4, 0.7), (3900, 24, 2, 0.7, 0.6),
                                         (5200, 36, 5, 2.1, 0.5), (4450, 30, 3, 1.1, 0.4)):
        bugs += cricket(rng, LOOP, f, rate, pulses, every) * vol
    leaves = shaped_noise(rng, LOOP, band(1200, 7000, -3)) * periodic_lfo(rng, LOOP, [2, 3], 0.6)
    return db_rms(bugs, -32) + db_rms(leaves, -42)


def amb_riverside(rng):
    # 강물: 넓게 흐르는 소리 + 가끔 물방울.
    flow = shaped_noise(rng, LOOP, band(120, 2500, -3)) * periodic_lfo(rng, LOOP, [3, 7], 0.25)
    low = shaped_noise(rng, LOOP, band(40, 250, -2))
    bub = np.zeros(n_samples(LOOP))
    for _ in range(int(LOOP * 6)):
        place_event(bub, bubble(rng) * rng.uniform(0.2, 1.0), int(rng.uniform(0, len(bub))))
    return db_rms(flow, -28) + db_rms(low, -36) + db_rms(bub, -40)


def amb_bridge(rng):
    # 철교 바람: 세찬 돌풍 + 쇠에 걸려 우는 좁은 음.
    gust = periodic_lfo(rng, LOOP, [1, 2, 4], 0.85)
    wind = shaped_noise(rng, LOOP, band(50, 1500, -5)) * gust
    whistle = shaped_noise(rng, LOOP, lambda f: np.exp(-((f - 880) / 40) ** 2) + 0.5 * np.exp(-((f - 1320) / 50) ** 2)) * gust ** 3
    return db_rms(wind, -28) + db_rms(whistle, -46)


def amb_ferry(rng):
    # 물소리만: 기슭에 닿는 잔물결이 천천히.
    out = np.zeros(n_samples(LOOP))
    lap_noise = shaped_noise(rng, 2.0, band(150, 1800, -4))
    env = env_ad(len(lap_noise), 0.35, 0.5)
    pos = 0.0
    while pos < LOOP:
        place_event(out, lap_noise * env * rng.uniform(0.5, 1.0), n_samples(pos))
        pos += rng.uniform(2.8, 4.6)
    bed = shaped_noise(rng, LOOP, band(100, 800, -5))
    return db_rms(out, -38) + db_rms(bed, -50)


# ---------------------------------------------------------------- 자리 소리


def pos_house_radio(rng):
    # 라디오에서 희미하게 흐르는 휘파람(1-1). 진짜 주제 선율이 오기 전 임시 선율(오음계).
    seconds = 16.0
    out = np.zeros(n_samples(seconds))
    melody = [(67, 0.6), (69, 0.6), (72, 0.9), (74, 0.6), (76, 1.2), (74, 0.6), (72, 0.6), (69, 1.5),
              (0, 0.8), (67, 0.6), (72, 0.6), (69, 0.9), (67, 0.6), (64, 1.2), (67, 2.0)]
    pos = 0.6
    for note, dur in melody:
        if note:
            n = n_samples(dur)
            t = np.arange(n) / RATE
            f = 440.0 * 2 ** ((note + 12 - 69) / 12)
            vib = 1 + 0.008 * np.sin(2 * np.pi * 5.5 * t)
            tone = np.sin(2 * np.pi * np.cumsum(f * vib) / RATE)
            breath = shaped_noise(rng, dur, band(f * 0.8, f * 1.3))[:n] * 0.08
            env = np.clip(t / 0.06, 0, 1) * np.clip((dur - t) / 0.12, 0, 1)
            place_event(out, (tone + breath) * env, n_samples(pos), wrap=False)
        pos += dur
    # 낡은 라디오: 좁은 대역 + 지직거림
    spec = np.fft.rfft(out)
    fr = np.fft.rfftfreq(len(out), 1 / RATE)
    out = np.fft.irfft(spec * band(400, 2800)(np.maximum(fr, 1)), len(out))
    hiss = shaped_noise(rng, seconds, band(1000, 6000, -2))
    return db_rms(out, -30) + db_rms(hiss, -50)


def pos_forest_water(rng):
    # 숲 끝(4-4)에서 들려오기 시작하는 물소리. 가까이 갈수록 커진다.
    flow = shaped_noise(rng, LOOP, band(150, 2200, -3)) * periodic_lfo(rng, LOOP, [4, 9], 0.25)
    return db_rms(flow, -24)


def amb_crossing(rng):
    # 7-6 강 위: 배 밑의 아주 작은 물소리만.
    flow = shaped_noise(rng, LOOP, band(120, 1400, -5)) * periodic_lfo(rng, LOOP, [2, 5], 0.35)
    return db_rms(flow, -44)


def whistle(rng, melody, tempo: float, start: float, out: np.ndarray) -> float:
    """휘파람 선율: (MIDI 음, 박) 목록. 0은 쉼. 끝난 시각을 돌려준다."""
    pos = start
    for note, beats in melody:
        dur = beats * tempo
        if note:
            n = n_samples(dur)
            t = np.arange(n) / RATE
            f = 440.0 * 2 ** ((note + 12 - 69) / 12)
            vib = 1 + 0.007 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t / 0.4, 0, 1)
            tone = np.sin(2 * np.pi * np.cumsum(f * vib) / RATE)
            breath = shaped_noise(rng, dur, band(f * 0.85, f * 1.25))[:n] * 0.06
            env = np.clip(t / 0.07, 0, 1) * np.clip((dur - t) / 0.18, 0, 1)
            place_event(out, (tone + breath) * env, n_samples(pos), wrap=False)
        pos += dur
    return pos


def mus_theme_full(rng):
    # 할아버지의 휘파람 주제 선율, 처음부터 끝까지(7-6). 진짜 곡이 오기 전 임시.
    # A는 집 라디오에서 희미하게 들리던 그 선율(pos_house_radio)과 같다.
    seconds = 72.0
    out = np.zeros(n_samples(seconds))
    A = [(67, .6), (69, .6), (72, .9), (74, .6), (76, 1.2), (74, .6), (72, .6), (69, 1.5),
         (0, .8), (67, .6), (72, .6), (69, .9), (67, .6), (64, 1.2), (67, 2.0)]
    B = [(74, .8), (76, .8), (79, 1.2), (76, .8), (74, .8), (72, 1.2), (0, .6),
         (72, .8), (74, .8), (76, 1.6), (74, .8), (69, 2.0)]
    CODA = [(67, 1.2), (69, 1.2), (72, 1.6), (69, 1.2), (67, 3.2)]
    pos = 1.5
    pos = whistle(rng, A, 1.35, pos, out) + 1.5
    pos = whistle(rng, B, 1.35, pos, out) + 1.5
    pos = whistle(rng, A, 1.35, pos, out) + 1.2
    pos = whistle(rng, CODA, 1.5, pos, out)
    melody = db_rms(out, -22)
    t = np.arange(len(out)) / RATE
    pad = (np.sin(2 * np.pi * 98.0 * t) + 0.6 * np.sin(2 * np.pi * 146.8 * t) + 0.3 * np.sin(2 * np.pi * 196.0 * t))
    pad_env = np.clip(t / 6.0, 0, 1) * np.clip((seconds - t) / 8.0, 0, 1)
    return melody + db_rms(pad * pad_env, -34)


def phrase(melody, tempo: float = 1.35):
    """기억 장면마다 휘파람 한 소절(장면표 2-2, 3-1, 4-3, 5-4). 주제 선율의 조각이다."""
    def f(rng):
        seconds = sum(b for _, b in melody) * tempo + 2.0
        out = np.zeros(n_samples(seconds))
        whistle(rng, melody, tempo, 0.4, out)
        t = np.arange(len(out)) / RATE
        return db_rms(out, -22) * np.clip((seconds - t) / 1.2, 0, 1)
    return f


THEME_A1 = [(67, .6), (69, .6), (72, .9), (74, .6), (76, 1.2)]
THEME_A2 = [(74, .6), (72, .6), (69, 1.5)]
THEME_A3 = [(67, .6), (72, .6), (69, .9), (67, .6), (64, 1.2), (67, 2.0)]
THEME_B1 = [(74, .8), (76, .8), (79, 1.2), (76, .8), (74, .8), (72, 1.2)]


# ---------------------------------------------------------------- 발소리·효과음(한 번)


def one_shot(rng, seconds, shape, attack, decay, extra=None):
    n = n_samples(seconds)
    x = shaped_noise(rng, seconds, shape)[:n] * env_ad(n, attack, decay)
    if extra is not None:
        x = x + extra(n)
    return x


def ring(freqs, decay):
    def f(n):
        t = np.arange(n) / RATE
        return sum(np.sin(2 * np.pi * fr * t) * np.exp(-t / decay) * a for fr, a in freqs)
    return f


def woof(rng, count: int) -> np.ndarray:
    """개가 짧게 짖는다: 내려가는 음높이의 배음 + 숨소리, count번."""
    x = np.zeros(n_samples(1.2))
    pos = 0.05
    for _ in range(count):
        dur = rng.uniform(0.16, 0.22)
        n = n_samples(dur)
        t = np.arange(n) / RATE
        f = rng.uniform(420, 520) * (1 - 0.35 * t / dur)
        ph = 2 * np.pi * np.cumsum(f) / RATE
        tone = sum(np.sin(k * ph) / k for k in range(1, 8))
        breath = shaped_noise(rng, dur, band(600, 3000, -3))[:n] * 0.4
        env = np.clip(t / 0.01, 0, 1) * np.exp(-t / (dur * 0.45))
        spec = np.fft.rfft((tone + breath) * env)
        fr = np.fft.rfftfreq(n, 1 / RATE)
        shaped = np.fft.irfft(spec * band(350, 2600)(np.maximum(fr, 1)), n)
        place_event(x, shaped, n_samples(pos), wrap=False)
        pos += dur + rng.uniform(0.12, 0.2)
    return x


STEPS = {
    # 바닥: (모양, 어택, 감쇠, 덧붙임)
    "wood": (band(120, 2500, -4), 0.003, 0.05, ring([(180, 0.6), (420, 0.3)], 0.04)),   # 마루
    "dirt": (band(80, 1800, -5), 0.006, 0.06, None),                                    # 흙길
    "grass": (band(800, 8000, -2), 0.02, 0.09, None),                                    # 억새
    "concrete": (band(300, 5000, -3), 0.002, 0.035, None),                               # 플랫폼
    "soil": (band(60, 1200, -6), 0.008, 0.07, None),                                     # 숲 흙
    "pebble": (band(1500, 9000, -1), 0.001, 0.025, None),                                # 조약돌
    "metal": (band(200, 4000, -3), 0.002, 0.04, ring([(610, 0.5), (1450, 0.35), (2730, 0.2)], 0.25)),  # 철판
    "deck": (band(150, 3000, -4), 0.003, 0.045, ring([(240, 0.4)], 0.06)),               # 나루터 데크
}


def make_steps(rng):
    out = {}
    for name, (shape, a, d, extra) in STEPS.items():
        for i in range(3):
            if name == "pebble":  # 조약돌: 작은 딸깍 여러 개
                x = np.zeros(n_samples(0.25))
                for _ in range(rng.integers(4, 8)):
                    place_event(x, one_shot(rng, 0.04, shape, 0.001, 0.008) * rng.uniform(0.4, 1), int(rng.uniform(0, 0.12) * RATE), wrap=False)
            else:
                x = one_shot(rng, 0.3, shape, a * rng.uniform(0.8, 1.2), d * rng.uniform(0.85, 1.15), extra)
            out[f"step_{name}_{i + 1:02d}"] = db_rms(x, -22)
    for i in range(3):  # 하늘이 발톱(간이역·숲에서만 들린다 — 장면표)
        x = np.zeros(n_samples(0.2))
        for k in range(2):
            place_event(x, one_shot(rng, 0.02, band(2500, 10000), 0.0005, 0.004), int((0.02 + k * rng.uniform(0.03, 0.06)) * RATE), wrap=False)
        out[f"sfx_dog_claw_{i + 1:02d}"] = db_rms(x, -30)
    for i in range(2):  # 잠겨 있다: 나무 서랍·문이 두세 번 덜컹
        x = np.zeros(n_samples(0.45))
        for k in range(int(rng.integers(2, 4))):
            knock = one_shot(rng, 0.12, band(150, 2200, -4), 0.002, 0.03, ring([(210, 0.5), (470, 0.25)], 0.05))
            place_event(x, knock * rng.uniform(0.6, 1.0), int((0.02 + k * rng.uniform(0.09, 0.13)) * RATE), wrap=False)
        out[f"sfx_locked_{i + 1:02d}"] = db_rms(x, -22)
    for i in range(2):  # 작은 열쇠를 집는다: 쇠붙이가 짤랑
        x = np.zeros(n_samples(0.6))
        for k in range(3):
            n = n_samples(0.5)
            t = np.arange(n) / RATE
            f0 = rng.uniform(2600, 3400)
            tone = sum(np.sin(2 * np.pi * f0 * r * t) * a for r, a in ((1.0, 1.0), (1.48, 0.5), (2.31, 0.3))) * env_ad(n, 0.001, 0.08)
            place_event(x, tone * rng.uniform(0.5, 1.0), int((0.01 + k * rng.uniform(0.04, 0.07)) * RATE), wrap=False)
        out[f"sfx_pickup_{i + 1:02d}"] = db_rms(x, -28)
    for i in range(2):  # 개 짖는 소리: 가까이(냄새 맡고 짖을 때), 멀리(3-3 벤치)
        near = woof(rng, 2)
        out[f"sfx_dog_bark_near_{i + 1:02d}"] = db_rms(near, -20)
        far = woof(rng, 2)
        spec = np.fft.rfft(far)
        fr = np.fft.rfftfreq(len(far), 1 / RATE)
        far = np.fft.irfft(spec * band(200, 1400)(np.maximum(fr, 1)), len(far))
        tail = shaped_noise(rng, len(far) / RATE, band(200, 1200, -4))[:len(far)] * 0.15 * np.abs(far).max()
        far = far + tail * np.linspace(0, 1, len(far)) * np.exp(-np.linspace(0, 4, len(far)))
        out[f"sfx_dog_bark_far_{i + 1:02d}"] = db_rms(far, -34)
    x = np.zeros(n_samples(0.5))  # 필름 카메라 셔터: 찰칵 + 감기는 소리
    place_event(x, one_shot(rng, 0.03, band(1500, 9000, -1), 0.0005, 0.006), n_samples(0.01), wrap=False)
    place_event(x, one_shot(rng, 0.05, band(800, 6000, -2), 0.001, 0.012) * 0.8, n_samples(0.09), wrap=False)
    place_event(x, one_shot(rng, 0.25, band(300, 3000, -3), 0.02, 0.08) * 0.25, n_samples(0.2), wrap=False)
    out["sfx_shutter_01"] = db_rms(x, -24)
    for i in range(2):  # 2-3 센 바람: 휘익 부풀었다 빠진다 + 억새가 쓸리는 높은 소리
        n = n_samples(2.2)
        t = np.arange(n) / RATE
        swell = np.sin(np.pi * np.clip(t / 2.0, 0, 1)) ** 1.6
        low = shaped_noise(rng, 2.2, band(150, 1400, -3))[:n]
        hiss = shaped_noise(rng, 2.2, band(2500, 9000, -1))[:n] * 0.35
        flutter = 1 + 0.25 * np.sin(2 * np.pi * rng.uniform(5, 8) * t)
        out[f"sfx_wind_gust_{i + 1:02d}"] = db_rms((low + hiss * flutter) * swell, -24)
    for i in range(2):  # 종이(지도)를 집는다: 바스락 두세 번
        x = np.zeros(n_samples(0.5))
        for k in range(int(rng.integers(2, 4))):
            crinkle = one_shot(rng, 0.09, band(1200, 9000, -1), 0.003, 0.03)
            place_event(x, crinkle * rng.uniform(0.6, 1.0), int((0.01 + k * rng.uniform(0.06, 0.11)) * RATE), wrap=False)
        out[f"sfx_paper_{i + 1:02d}"] = db_rms(x, -26)
    # 2-4 경운기: 한 기통 엔진이 통통통. 지나가는 동안(약 16초) 한 번 튼다. 멀어지는 건 게임이 자리로 만든다.
    secs = 16.0
    n = n_samples(secs)
    t = np.arange(n) / RATE
    rate = 7.5 + 0.4 * np.sin(2 * np.pi * 0.11 * t)
    phase = np.cumsum(rate) / RATE
    pulse = np.clip(np.sin(2 * np.pi * phase), 0, 1) ** 6
    body = shaped_noise(rng, secs, band(50, 700, -4))[:n]
    hum = np.sin(2 * np.pi * 62 * t) * 0.5 + np.sin(2 * np.pi * 124 * t) * 0.2
    rattle = shaped_noise(rng, secs, band(1500, 5000, -2))[:n] * 0.15
    x = (body + hum) * (0.25 + pulse) + rattle * pulse
    edge = np.clip(np.minimum(t / 0.8, (secs - t) / 0.8), 0, 1)
    out["sfx_tractor_01"] = db_rms(x * edge, -22)
    for i in range(2):  # 1-6 감나무 흔들기: 마른 잎이 우수수
        x = np.zeros(n_samples(1.4))
        for k in range(int(rng.integers(14, 22))):
            leaf = one_shot(rng, 0.08, band(1800, 9000, -1), 0.004, 0.025)
            place_event(x, leaf * rng.uniform(0.3, 1.0), int(rng.uniform(0.0, 1.1) * RATE), wrap=False)
        swish = one_shot(rng, 1.2, band(400, 4000, -2), 0.08, 0.35) * 0.6
        place_event(x, swish, 0, wrap=False)
        out[f"sfx_tree_shake_{i + 1:02d}"] = db_rms(x, -26)
    for i in range(2):  # 감이 마당 흙에 툭
        x = one_shot(rng, 0.35, band(60, 900, -5), 0.002, 0.05, ring([(140, 0.5), (230, 0.25)], 0.05))
        out[f"sfx_persimmon_drop_{i + 1:02d}"] = db_rms(x, -22)
    # 0-1 오프닝: 밤 빗소리(약 14초, 한 번). 빗방울 톡톡 + 쏴아 하는 바탕. 사이렌·충돌음은 넣지 않는다.
    secs = 14.0
    n = n_samples(secs)
    t = np.arange(n) / RATE
    hiss = shaped_noise(rng, secs, band(800, 9000, -1))[:n] * 0.5
    low = shaped_noise(rng, secs, band(80, 600, -4))[:n] * 0.3
    x = hiss + low
    for _ in range(500):
        drop = one_shot(rng, 0.03, band(2000, 8000), 0.0005, 0.006) * rng.uniform(0.2, 0.8)
        place_event(x, drop, int(rng.uniform(0, secs - 0.05) * RATE), wrap=False)
    edge = np.clip(np.minimum(t / 2.0, (secs - t) / 2.5), 0, 1)
    out["sfx_rain_01"] = db_rms(x * edge, -24)
    return out


# ---------------------------------------------------------------- 저장

AMBIENCE = {
    "amb_house": amb_house, "amb_field": amb_field, "amb_station": amb_station, "amb_forest": amb_forest,
    "amb_riverside": amb_riverside, "amb_bridge": amb_bridge, "amb_ferry": amb_ferry,
    "pos_house_radio": pos_house_radio, "pos_forest_water": pos_forest_water,
    "amb_crossing": amb_crossing, "mus_theme_full": mus_theme_full,
    "mus_phrase_1": phrase(THEME_A1), "mus_phrase_2": phrase(THEME_A1 + THEME_A2),
    "mus_phrase_3": phrase(THEME_B1), "mus_phrase_4": phrase(THEME_A3),
}


def save_ogg(name: str, x: np.ndarray) -> None:
    peak = np.max(np.abs(x))
    if peak > 0.98:
        x = x * (0.98 / peak)
    pcm = np.clip(np.round(x * 32767), -32768, 32767).astype("<i2")
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = Path(tmp) / "x.wav"
        with wave.open(str(wav_path), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(pcm.tobytes())
        out = OUT / f"{name}.ogg"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path), "-c:a", "libvorbis", "-q:a", "4",
                        "-fflags", "+bitexact", "-flags:a", "+bitexact", "-serial_offset", "1", str(out)], check=True)
    print(f"{out.relative_to(ROOT)}  {len(x) / RATE:.2f}s  {out.stat().st_size // 1024} KB")


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in AMBIENCE.items():
        save_ogg(name, fn(np.random.default_rng(sum(map(ord, name)))))
    for name, x in make_steps(np.random.default_rng(7)).items():
        save_ogg(name, x)
    return 0


if __name__ == "__main__":
    sys.exit(main())
