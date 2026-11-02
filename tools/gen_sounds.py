#!/usr/bin/env python3
"""Генератор звуков игры (процедурный синтез, без сторонних лицензий).

Запуск:  python3 tools/gen_sounds.py   (нужен numpy)
Файлы пишутся в sounds/*.wav. Любой файл можно заменить своим (CC0 и т.п.)
с тем же именем — игра подхватит его автоматически.
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "sounds")
rng = np.random.default_rng(7)


def t(d):
    return np.arange(int(SR * d)) / SR


def noise(d):
    return rng.uniform(-1, 1, int(SR * d))


def env(n, a=0.005, r=0.2, curve=3.0):
    x = np.arange(n) / SR
    e = np.minimum(1.0, x / max(a, 1e-4))
    total = n / SR
    rel = np.clip((total - x) / max(r, 1e-4), 0, 1)
    return e * rel ** (1.0 / curve) if False else e * np.exp(-x * curve / max(total, 1e-3)) * rel


def lowpass(x, cutoff):
    # однополюсный ФНЧ
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def bandpass(x, lo, hi):
    return lowpass(highpass(x, lo), hi)


def fade(x, fin=0.005, fout=0.02):
    n = len(x)
    i = min(int(SR * fin), n)
    o = min(int(SR * fout), n)
    if i:
        x[:i] *= np.linspace(0, 1, i)
    if o:
        x[-o:] *= np.linspace(1, 0, o)
    return x


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def save(name, x, peak=0.9):
    x = norm(np.asarray(x, dtype=np.float64), peak)
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def exp_decay(d, k):
    return np.exp(-t(d) * k)


def loopify(x, cross=0.25):
    """Бесшовная петля: перекрёстное затухание конца в начало."""
    n = int(SR * cross)
    head = x[:n].copy()
    tail = x[-n:].copy()
    w = np.linspace(0, 1, n)
    x = x[:-n].copy()
    x[:n] = head * w + tail * (1 - w)
    return x


# ------------------------------------------------------------------ выстрелы
def gunshot(d, body_hz, crack, boom, k):
    n = noise(d)
    crack_part = highpass(n, 2500) * exp_decay(d, 60) * crack
    body = lowpass(n, body_hz) * exp_decay(d, k) * 2.0
    thump = np.sin(2 * np.pi * 55 * t(d) * np.exp(-t(d) * 3)) * exp_decay(d, 9) * boom
    tail = lowpass(noise(d), 600) * exp_decay(d, 3.0) * 0.25
    return fade(crack_part + body + thump + tail, 0.0005, 0.1)


os.makedirs(OUT, exist_ok=True)
save("shot_small", gunshot(0.6, 3000, 0.9, 0.1, 25))
save("shot_shotgun", gunshot(1.4, 1400, 0.6, 1.0, 9))
save("shot_rifle", gunshot(1.6, 2000, 1.0, 0.7, 10))
save("shot_big", gunshot(2.2, 1200, 1.0, 1.4, 6))

# механика оружия
clk = lambda f, d=0.03: np.sin(2 * np.pi * f * t(d)) * exp_decay(d, 120) + highpass(noise(d), 3000) * exp_decay(d, 200) * 0.6
reload = np.zeros(int(SR * 1.0))
for pos, f in [(0.05, 2400), (0.35, 1800), (0.42, 2600), (0.8, 3000)]:
    c = clk(f)
    i = int(pos * SR)
    reload[i:i + len(c)] += c
save("reload", reload)
save("dry_fire", np.concatenate([clk(3200), np.zeros(800)]))
save("click", clk(1500, 0.04), 0.5)
save("hitmark", np.sin(2 * np.pi * 1600 * t(0.08)) * exp_decay(0.08, 40), 0.5)
save("ricochet", fade(np.sin(2 * np.pi * (3500 - 2000 * t(0.5)) * t(0.5)) * exp_decay(0.5, 6) * 0.6 + highpass(noise(0.5), 4000) * exp_decay(0.5, 30)))
save("impact", fade(lowpass(noise(0.2), 1500) * exp_decay(0.2, 30)))
save("hit_flesh", fade(lowpass(noise(0.25), 500) * exp_decay(0.25, 18) + np.sin(2 * np.pi * 90 * t(0.25)) * exp_decay(0.25, 20)))

# ------------------------------------------------------------------ шаги, удары
step = lowpass(noise(0.12), 900) * exp_decay(0.12, 40) + highpass(noise(0.12), 3000) * exp_decay(0.12, 60) * 0.3
save("step", fade(step), 0.6)
sp = bandpass(noise(0.5), 300, 3000) * exp_decay(0.5, 7)
save("splash", fade(sp))
save("jump", fade(lowpass(noise(0.15), 600) * exp_decay(0.15, 25)), 0.5)
save("thud", fade(lowpass(noise(0.4), 300) * exp_decay(0.4, 14) + np.sin(2 * np.pi * 70 * t(0.4)) * exp_decay(0.4, 12)))
cr = lowpass(noise(1.2), 2500) * exp_decay(1.2, 5) + highpass(noise(1.2), 3000) * exp_decay(1.2, 9) * 0.6
for i in range(6):
    p = int(rng.uniform(0.0, 0.8) * SR)
    m = np.sin(2 * np.pi * rng.uniform(300, 900) * t(0.3)) * exp_decay(0.3, 12) * 0.4
    cr[p:p + len(m)] += m
save("crash", fade(cr))
save("whoosh", fade(bandpass(noise(0.4), 300, 1500) * np.sin(np.pi * t(0.4) / 0.4)))

# ------------------------------------------------------------------ дом на колёсах
d = 2.0
tt = t(d)
base = 38.0
eng = (np.sign(np.sin(2 * np.pi * base * tt)) * 0.4 + np.sin(2 * np.pi * base * 2 * tt) * 0.4
       + np.sin(2 * np.pi * base * 3 * tt) * 0.2)
eng *= 1 + 0.3 * np.sin(2 * np.pi * 9.5 * tt)
eng = lowpass(eng + lowpass(noise(d), 400) * 0.3, 900)
save("engine", eng, 0.7)
horn = (np.sign(np.sin(2 * np.pi * 330 * t(0.9))) + np.sign(np.sin(2 * np.pi * 415 * t(0.9)))) * 0.5
save("horn", fade(lowpass(horn, 2500), 0.01, 0.08), 0.8)
door = np.concatenate([clk(500, 0.08) * 2, np.zeros(1500), lowpass(noise(0.15), 700) * exp_decay(0.15, 30)])
save("door", door)
fuel = np.zeros(int(SR * 1.6))
for i in range(10):
    p = int(i * 0.15 * SR)
    g = np.sin(2 * np.pi * (180 + 40 * rng.random()) * t(0.12) * (1 + t(0.12) * 3)) * exp_decay(0.12, 20)
    fuel[p:p + len(g)] += g
save("fuel", fuel + lowpass(noise(1.6), 900) * 0.15)
rep = np.zeros(int(SR * 1.4))
for i in range(4):
    p = int(i * 0.32 * SR)
    h = np.sin(2 * np.pi * 2200 * t(0.25)) * exp_decay(0.25, 25) + np.sin(2 * np.pi * 3350 * t(0.25)) * exp_decay(0.25, 30) * 0.6
    h += highpass(noise(0.25), 2000) * exp_decay(0.25, 80)
    rep[p:p + len(h)] += h
save("repair", rep)

# ------------------------------------------------------------------ еда, туалет, быт
eat = np.zeros(int(SR * 1.2))
for i in range(5):
    p = int((0.05 + i * 0.22) * SR)
    c = bandpass(noise(0.1), 800, 4000) * exp_decay(0.1, 35)
    eat[p:p + len(c)] += c
save("eat", eat, 0.7)
drink = np.zeros(int(SR * 1.3))
for i in range(4):
    p = int((0.1 + i * 0.3) * SR)
    g = np.sin(2 * np.pi * (400 - 200 * t(0.15) / 0.15) * t(0.15)) * np.sin(np.pi * t(0.15) / 0.15)
    drink[p:p + len(g)] += g
save("drink", lowpass(drink, 1500), 0.7)
pee = bandpass(noise(2.4), 1500, 5000) * (0.8 + 0.2 * np.sin(2 * np.pi * 3 * t(2.4)))
save("pee", fade(pee, 0.2, 0.4), 0.5)
fl = bandpass(noise(2.0), 200, 2500) * np.concatenate([np.linspace(0, 1, int(SR * 0.3)), np.ones(int(SR * 0.9)), np.linspace(1, 0, int(SR * 0.8))])
save("flush", fl, 0.7)
fart_t = t(1.0)
fart = np.sign(np.sin(2 * np.pi * (85 + 30 * np.sin(2 * np.pi * 3 * fart_t)) * fart_t)) * (1 + 0.5 * noise(1.0))
save("fart", fade(lowpass(fart, 700) * np.exp(-fart_t * 1.5), 0.02, 0.15), 0.8)
strain_t = t(1.4)
strain = np.sin(2 * np.pi * (110 + 15 * strain_t) * strain_t) * (0.5 + 0.5 * np.sin(2 * np.pi * 2 * strain_t) ** 2)
save("strain", fade(lowpass(strain + noise(1.4) * 0.1, 900), 0.1, 0.3), 0.6)
siz = highpass(noise(2.5), 2500) * (0.7 + 0.3 * rng.random(int(SR * 2.5)))
save("sizzle", fade(siz, 0.1, 0.6), 0.5)
save("pop", fade(np.sin(2 * np.pi * (600 - 400 * t(0.1) / 0.1) * t(0.1)) * exp_decay(0.1, 30)), 0.6)
bt = np.zeros(int(SR * 1.5))
for i in range(5):
    p = int(i * 0.28 * SR)
    c = lowpass(noise(0.2), 700) * exp_decay(0.2, 20) + bandpass(noise(0.2), 1000, 3000) * exp_decay(0.2, 30) * 0.4
    bt[p:p + len(c)] += c
save("butcher", bt)
cash = np.zeros(int(SR * 0.8))
for i, f in enumerate([2100, 2800]):
    p = int(i * 0.12 * SR)
    c = (np.sin(2 * np.pi * f * t(0.6)) + 0.5 * np.sin(2 * np.pi * f * 2.7 * t(0.6))) * exp_decay(0.6, 8)
    cash[p:p + len(c)] += c
save("cash", cash, 0.6)
save("zip", fade(bandpass(noise(0.35), 2000, 6000) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 60 * t(0.35))))), 0.5)
lt = np.concatenate([clk(2500, 0.03), np.zeros(1500), bandpass(noise(0.4), 500, 3000) * exp_decay(0.4, 6) * 0.5])
save("lighter", lt, 0.5)
save("pickup", fade(np.sin(2 * np.pi * (500 + 600 * t(0.12) / 0.12) * t(0.12)) * exp_decay(0.12, 15)), 0.4)
save("fire_whoosh", fade(lowpass(noise(0.8), 800) * np.sin(np.pi * t(0.8) / 0.8)))


# ------------------------------------------------------------------ голоса (синтез форманта)
def voice(d, f0_fn, formants, amp_fn):
    tt = t(d)
    phase = 2 * np.pi * np.cumsum(f0_fn(tt)) / SR
    src = sum(np.sin(k * phase) / k for k in range(1, 18))
    out = np.zeros_like(tt)
    for f, g in formants:
        out += bandpass(src, f * 0.8, f * 1.2) * g
    return out * amp_fn(tt)


laugh = voice(1.3, lambda x: 180 + 30 * np.sin(2 * np.pi * 1.5 * x), [(700, 1.0), (1200, 0.6)],
              lambda x: (np.sin(2 * np.pi * 5.5 * x) > 0.1) * np.exp(-x * 1.2))
save("laugh", fade(laugh + bandpass(noise(1.3), 1000, 4000) * 0.15 * (np.sin(2 * np.pi * 5.5 * t(1.3)) > 0.1)), 0.7)
hey = voice(0.45, lambda x: 210 - 60 * x, [(800, 1.0), (1700, 0.7)], lambda x: np.sin(np.pi * x / 0.45))
save("hey", fade(hey), 0.7)
hurt = voice(0.4, lambda x: 160 - 80 * x, [(600, 1.0), (1000, 0.5)], lambda x: np.exp(-x * 6))
save("hurt", fade(hurt), 0.7)

# ------------------------------------------------------------------ звери
rabbit = np.sin(2 * np.pi * (2400 + 600 * np.sin(2 * np.pi * 14 * t(0.25))) * t(0.25)) * np.sin(np.pi * t(0.25) / 0.25)
save("rabbit_call", fade(rabbit), 0.4)
deer = voice(0.9, lambda x: 520 + 80 * np.sin(np.pi * x / 0.9) - 120 * x, [(900, 1.0), (2200, 0.4)], lambda x: np.sin(np.pi * x / 0.9) ** 0.5)
save("deer_call", fade(deer + bandpass(noise(0.9), 1500, 4000) * 0.1))
boar_t = t(0.8)
boar = np.zeros_like(boar_t)
for i in range(4):
    s = int(i * 0.18 * SR)
    g = voice(0.15, lambda x: 90 + 20 * rng.random(), [(400, 1.0), (900, 0.4)], lambda x: np.sin(np.pi * x / 0.15))
    boar[s:s + len(g)] += g
save("boar_call", fade(boar + lowpass(noise(0.8), 500) * 0.15))
bear = voice(1.6, lambda x: 70 + 15 * np.sin(2 * np.pi * 0.7 * x), [(300, 1.0), (650, 0.7), (1100, 0.3)], lambda x: np.sin(np.pi * x / 1.6) ** 0.7)
save("bear_call", fade(bear + lowpass(noise(1.6), 700) * 0.3 * np.sin(np.pi * t(1.6) / 1.6)))

# ------------------------------------------------------------------ петли окружения
d = 6.0
r = bandpass(noise(d), 400, 6000) * 0.6 + lowpass(noise(d), 300) * 0.4
drops = np.zeros(int(SR * d))
for i in range(300):
    p = int(rng.uniform(0, d - 0.05) * SR)
    c = np.sin(2 * np.pi * rng.uniform(1500, 4000) * t(0.02)) * exp_decay(0.02, 200) * rng.uniform(0.2, 0.8)
    drops[p:p + len(c)] += c
save("rain", loopify(r + drops * 0.5), 0.6)

d = 10.0
amb = lowpass(noise(d), 250) * 0.25   # ветер
for i in range(14):
    p = int(rng.uniform(0, d - 1.0) * SR)
    f0 = rng.uniform(2500, 4500)
    n_notes = rng.integers(2, 6)
    for k in range(n_notes):
        dd = rng.uniform(0.06, 0.15)
        x = t(dd)
        chirp = np.sin(2 * np.pi * (f0 + rng.uniform(-800, 800) * x / dd) * x) * np.sin(np.pi * x / dd)
        s = p + int(k * 0.17 * SR)
        amb[s:s + len(chirp)] += chirp * rng.uniform(0.15, 0.4)
save("ambience", loopify(amb, 0.5), 0.5)

d = 6.0
night = lowpass(noise(d), 200) * 0.2
cr_t = t(d)
for f, rate, ph in [(4300, 18, 0.0), (4700, 22, 1.3), (3900, 15, 2.1)]:
    gate = (np.sin(2 * np.pi * rate * cr_t + ph) > 0.6) * (np.sin(2 * np.pi * 0.5 * cr_t + ph) > -0.2)
    night += np.sin(2 * np.pi * f * cr_t) * gate * 0.15
save("night", loopify(night, 0.5), 0.4)

d = 4.0
fire = lowpass(noise(d), 600) * 0.5
for i in range(120):
    p = int(rng.uniform(0, d - 0.03) * SR)
    c = highpass(noise(0.02), 2000) * exp_decay(0.02, 150) * rng.uniform(0.3, 1.0)
    fire[p:p + len(c)] += c
save("fire", loopify(fire, 0.3), 0.6)

print("ok:", sorted(f for f in os.listdir(OUT) if f.endswith(".wav")))
