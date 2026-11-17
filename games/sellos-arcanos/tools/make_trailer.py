"""Monta el tráiler vertical: fotogramas de gameplay real + textos + música
sintetizada + cartel final. Uso:

python3 -I tools/make_trailer.py <fotogramas> <es|en> <salida.mp4> <carpeta_ttf> <cartel.jpg>
"""
import math
import os
import struct
import subprocess
import sys
import wave

FRAMES, LANG, OUT, TTF, CARD = sys.argv[1:6]
FPS = 30
TMP = os.path.splitext(OUT)[0] + "_tmp"
os.makedirs(TMP, exist_ok=True)

TEXTS = {
    "es": [(0.3, 2.4, "COMBATE EN TIEMPO REAL"), (2.6, 4.3, "LIBERA TU DEFINITIVA"), (5.2, 7.2, "TRAZA SU RUNA"), (7.3, 8.9, "¡Y SÉLLALA!"), (9.2, 13.4, "12 PRIMORDIALES TE ESPERAN")],
    "en": [(0.3, 2.4, "REAL-TIME BATTLES"), (2.6, 4.3, "UNLEASH YOUR ULTIMATE"), (5.2, 7.2, "TRACE ITS RUNE"), (7.3, 8.9, "AND SEAL IT!"), (9.2, 13.4, "12 PRIMORDIALS AWAIT")],
}[LANG]

n_frames = len([f for f in os.listdir(FRAMES) if f.endswith(".jpg")])
gameplay_s = n_frames / FPS
card_s = 2.8
total = gameplay_s + card_s


def synth_music(path, seconds, sr=44100):
    """Pad en re menor + bombo y campanas, en la línea del audio del juego."""
    chords = [[50, 53, 57], [46, 50, 53], [43, 46, 50], [45, 49, 52]]
    n = int(seconds * sr)
    buf = [0.0] * n
    note = lambda m: 440 * 2 ** ((m - 69) / 12)
    beat = 0.48
    # pads
    for i in range(int(seconds / (beat * 8)) + 1):
        ch = chords[i % 4]
        t0 = i * beat * 8
        for m in ch:
            f = note(m)
            for det in (-0.004, 0, 0.004):
                ff = f * (1 + det)
                start = int(t0 * sr)
                length = int(beat * 8 * 1.2 * sr)
                for k in range(length):
                    j = start + k
                    if j >= n:
                        break
                    tt = k / sr
                    env = min(1, tt / 1.2) * max(0, 1 - tt / (beat * 9.6))
                    ph = (tt * ff) % 1
                    buf[j] += (2 * ph - 1) * 0.018 * env
    # bombo y campanas
    for b in range(int(seconds / beat)):
        t0 = b * beat
        start = int(t0 * sr)
        if b % 2 == 0:
            for k in range(int(0.25 * sr)):
                j = start + k
                if j >= n:
                    break
                tt = k / sr
                f = 120 * math.exp(-tt * 14) + 40
                buf[j] += math.sin(2 * math.pi * f * tt) * 0.5 * math.exp(-tt * 9)
        if b % 3 == 1:
            m = chords[(b // 8) % 4][b % 3] + 24
            f = note(m)
            for k in range(int(1.2 * sr)):
                j = start + int(beat / 2 * sr) + k
                if j >= n:
                    break
                tt = k / sr
                buf[j] += math.sin(2 * math.pi * f * tt) * 0.09 * math.exp(-tt * 3)
    # golpe final con el cartel
    hit = int(gameplay_s * sr)
    for k in range(int(1.5 * sr)):
        j = hit + k
        if j >= n:
            break
        tt = k / sr
        buf[j] += math.sin(2 * math.pi * (55 + 40 * math.exp(-tt * 6)) * tt) * 0.7 * math.exp(-tt * 2.5)
    peak = max(1e-6, max(abs(x) for x in buf))
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        fade = int(0.6 * sr)
        data = bytearray()
        for i, x in enumerate(buf):
            g = min(1, (n - i) / fade) * min(1, i / (0.05 * sr))
            data += struct.pack("<h", int(max(-1, min(1, x / peak * 0.85 * g)) * 32767))
        w.writeframes(bytes(data))


def esc(s):
    return s.replace("\\", "\\\\").replace(":", "\\:").replace("'", "’").replace("%", "\\%")


font = os.path.join(TTF, "Cinzel-normal-800-latin.ttf")
draw = []
for a, b, txt in TEXTS:
    fade = f"if(lt(t,{a}+0.25),(t-{a})/0.25,if(gt(t,{b}-0.25),({b}-t)/0.25,1))"
    draw.append(
        f"drawtext=fontfile='{font}':text='{esc(txt)}':fontsize=74:fontcolor=white:borderw=0:"
        f"shadowcolor=0x6b3fd0@0.9:shadowx=0:shadowy=0:x=(w-text_w)/2:y=h*0.17:"
        f"enable='between(t,{a},{b})':alpha='{fade}'")
music = os.path.join(TMP, "music.wav")
synth_music(music, total)
gameplay = os.path.join(TMP, "gameplay.mp4")
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", os.path.join(FRAMES, "f%04d.jpg"),
                "-vf", "scale=1080:1920:flags=lanczos," + ",".join(draw) + ",format=yuv420p",
                "-c:v", "libx264", "-preset", "medium", "-crf", "19", "-r", str(FPS), gameplay], check=True)
card = os.path.join(TMP, "card.mp4")
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-loop", "1", "-i", CARD, "-t", str(card_s),
                "-vf", f"scale=1188:2112,zoompan=z='min(1+on*0.0012,1.1)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={int(card_s * FPS)}:s=1080x1920:fps={FPS},fade=t=in:st=0:d=0.35,format=yuv420p",
                "-c:v", "libx264", "-preset", "medium", "-crf", "19", card], check=True)
lst = os.path.join(TMP, "list.txt")
with open(lst, "w") as fh:
    fh.write(f"file '{gameplay}'\nfile '{card}'\n")
joined = os.path.join(TMP, "joined.mp4")
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", joined], check=True)
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", joined, "-i", music, "-c:v", "copy", "-c:a", "aac", "-b:a", "160k",
                "-shortest", "-movflags", "+faststart", OUT], check=True)
print("ok", OUT, round(total, 1), "s")
