# Конвертация найденных CC0-звуков (OpenGameArt) в sounds/*.wav: обрезка, моно 44.1 кГц, выравнивание громкости, бесшовные петли.
# Пути к скачанным архивам — D (см. CREDITS.md).
import subprocess, numpy as np, wave, sys, os
SR = 44100
D = '/tmp/claude-0/snd/dl/'
OUT = '/home/user/huntergame/sounds/'

def load(path, start=0.0, dur=None):
    cmd = ['ffmpeg', '-v', 'error', '-ss', str(start)] + (['-t', str(dur)] if dur else []) + ['-i', path, '-ac', '1', '-ar', str(SR), '-f', 's16le', '-']
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0

def save(name, x):
    x = np.clip(x, -1, 1)
    with wave.open(OUT + name + '.wav', 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())

def trim_silence(x, thr=0.01):
    idx = np.where(np.abs(x) > thr)[0]
    return x[max(idx[0] - 200, 0):] if len(idx) else x

def fade(x, fin=0.003, fout=0.3):
    n = len(x); a = int(fin * SR); b = min(int(fout * SR), n)
    x = x.copy()
    if a: x[:a] *= np.linspace(0, 1, a)
    if b: x[-b:] *= np.linspace(1, 0, b) ** 2
    return x

def peak(x, db):
    return x / (np.max(np.abs(x)) + 1e-9) * 10 ** (db / 20)

def rms_to(x, db):
    r = np.sqrt(np.mean(x ** 2)) + 1e-9
    y = x / r * 10 ** (db / 20)
    m = np.max(np.abs(y))
    return y / m * 0.95 if m > 0.95 else y

def loopify(x, xf=1.5):
    n = int(xf * SR)
    body = x[n:].copy()
    head = x[:n]
    t = np.linspace(0, 1, n)
    body[-n:] = body[-n:] * np.sqrt(1 - t) + head * np.sqrt(t)
    return body

def one(name, path, start=0.0, dur=None, maxlen=None, fout=0.3, db=-0.9, trim=True):
    x = load(D + path, start, dur)
    if trim: x = trim_silence(x)
    if maxlen: x = x[:int(maxlen * SR)]
    save(name, peak(fade(x, fout=fout), db))
    print(name, round(len(x) / SR, 2))

def loop(name, path, start=0.0, dur=30.0, mean_db=-20.0, xf=1.5):
    x = load(D + path, start, dur + xf)
    save(name, rms_to(loopify(x, xf), mean_db))
    print(name, 'loop', dur)

FA = 'x/firearm/Prepared SFX Library/'
one('shot_small', FA + 'Ruger Mark III/R_35P.wav', maxlen=1.6, fout=0.8)
one('shot_rifle', FA + 'Tikka/W_29P.wav', maxlen=3.0, fout=1.5)
one('shot_big', FA + 'Mosin Nagant/M_21P.wav', maxlen=3.5, fout=1.8)
one('shot_shotgun', FA + 'Nova/O_21P.wav', maxlen=2.8, fout=1.4)
one('reload', 'gunreload1.wav', fout=0.05)
one('pump', 'shotguncock_0.wav', fout=0.05)
one('horn', 'x/car_sound_effects_pack/Car_Horn.ogg', fout=0.05, db=-1.9)
one('door', 'x/car_sound_effects_pack/Car_Door_Close.ogg', fout=0.1)
one('step', 'x/Fantozzi-footsteps/Fantozzi-footsteps/ogg/Fantozzi-SandL1.ogg', maxlen=0.35, fout=0.1, db=-4.4)
one('bear_call', 'x/bear/ogg/bear_01.ogg', fout=0.2)
one('hammer', 'x/workshop/workshop/workshop - metal hammering.wav', maxlen=0.45, fout=0.15)
one('ratchet', 'x/workshop/workshop/workshop - ratchet1.wav', maxlen=0.7, fout=0.1)
one('thud', 'x/100-CC0-wood-metal-SFX/wood_hit_04.ogg', fout=0.1)
one('crash', 'x/100-CC0-wood-metal-SFX/metal_slam_01.ogg', fout=0.3)
one('repair', 'x/workshop/workshop/workshop - tool clatter.wav', maxlen=1.4, fout=0.3)
loop('rain', 'amb_rain_loop_1.wav', 5.0, 30.0, -17.0)
loop('ambience', 'park_ambience_birds.wav', 20.0, 40.0, -24.0)
loop('night', 'crickets_1.mp3', 0.2, 9.5, -26.0)
loop('fire', 'fire.wav', 1.0, 20.0, -21.0, 1.0)
loop('engine', 'x/car_sound_effects_pack/Car_Engine_Loop.ogg', 0.0, 2.5, -12.0, 0.4)
loop('winch', 'x/winch/winch - Region #1.wav', 0.2, 1.2, -16.0, 0.3)
