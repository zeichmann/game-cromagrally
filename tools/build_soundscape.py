"""Deterministic original ambience synthesis; no recordings or third-party samples."""
import array
import hashlib
import json
import math
from pathlib import Path
import random
import wave

ROOT = Path(__file__).resolve().parents[1]
RATE = 44100
DURATION = 8


def create(name, seed):
    rng = random.Random(seed)
    low = 0.0
    mid = 0.0
    values = []
    for i in range(RATE * DURATION):
        t = i / RATE
        noise = rng.random() * 2 - 1
        low = low * .996 + noise * .004
        mid = mid * .83 + noise * .17
        if name == 'brook':
            value = (mid * .60 + noise * .07) * (.82 + .18 * math.sin(t * 1.7))
            value += math.sin(t * 950 + math.sin(t * 17) * 8) * .008
        elif name == 'harbor':
            value = (mid * .28 + low * 1.8) * (.65 + .35 * math.sin(t * .8))
            u = t % 2.7
            value += math.sin(t * (175 + 20 * math.sin(u * 2))) * math.exp(-u * 4) * .09
        else:
            value = low * 1.6 + mid * .04
            for start in [1.1, 3.4, 5.6, 7.1]:
                u = t - start
                if 0 < u < .36:
                    envelope = math.sin(u / .36 * math.pi) ** 2
                    value += math.sin(2 * math.pi * (1900 * u + 1100 * u * u)) * envelope * .055
            if name == 'market':
                for start, frequency in [(1.8, 880), (4.3, 1100), (6.4, 660)]:
                    u = t - start
                    if 0 < u < .9:
                        value += (math.sin(2 * math.pi * frequency * u) + .3 * math.sin(2 * math.pi * frequency * 2.76 * u)) * math.exp(-u * 7) * .055
            if name == 'workshop':
                u = t % .83
                value += (noise * .13 + math.sin(t * 1900) * .04) * math.exp(-u * 65)
        fade = min(1, t / .04, (DURATION - t) / .04)
        values.append(math.tanh(value) * fade)
    mean = sum(values) / len(values)
    pcm = array.array('h', (round(max(-1, min(1, v - mean)) * 32767) for v in values))
    folder = ROOT / 'assets/audio'
    folder.mkdir(exist_ok=True)
    path = folder / (name + '.wav')
    with wave.open(str(path), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())
    return {'path': path.relative_to(ROOT).as_posix(), 'rate': RATE, 'channels': 1,
            'bits': 16, 'seconds': DURATION, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


if __name__ == '__main__':
    assets = [create(name, 44107 + i) for i, name in enumerate(['forest', 'brook', 'harbor', 'market', 'workshop'])]
    target = ROOT / 'assets/audio/MANIFEST.json'
    target.write_text(json.dumps({'source': 'Original deterministic synthesis in tools/build_soundscape.py', 'assets': assets}, indent=2) + '\n')
    print('SOUNDSCAPE_BUILT', len(assets), 'original mono PCM loops')
