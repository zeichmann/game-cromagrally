"""Original deterministic vehicle foley; no samples or external dependencies."""
import hashlib
import json
import math
from pathlib import Path
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/audio/driving'
RATE = 22050


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    rng = random.Random(48170)
    bands = [(rng.randint(200, 6700), rng.random() * math.tau) for _ in range(24)]
    files = []
    for name, duration in [('sail_drive', 1), ('flywheel_drive', 1), ('tires', 1),
                           ('rolling', 1), ('impact', .32), ('landing', .27),
                           ('boost', .75), ('pickup', .22)]:
        samples = []
        for frame in range(round(duration * RATE)):
            t = frame / RATE
            noise = sum(math.sin(math.tau * hz * t + phase) for hz, phase in bands) / 8
            if name == 'sail_drive':
                value = .42 * math.sin(math.tau * 76 * t) + .14 * math.sin(math.tau * 152 * t) + noise * .12
            elif name == 'flywheel_drive':
                value = .45 * math.sin(math.tau * 48 * t) + .18 * math.sin(math.tau * 96 * t) + .08 * math.sin(math.tau * 192 * t)
            elif name == 'tires':
                value = noise * .48 + .12 * math.sin(math.tau * 1170 * t) * (1 + .3 * math.sin(math.tau * 13 * t))
            elif name == 'rolling':
                value = noise * .24 + .13 * math.sin(math.tau * 85 * t) * math.sin(math.tau * 7 * t)
            else:
                fade = min(1, t / .004) * (1 - t / duration) ** 2
                if name == 'impact': value = fade * (noise * .75 + .34 * math.sin(math.tau * 130 * t))
                elif name == 'landing': value = fade * (noise * .28 + .56 * math.sin(math.tau * 63 * t))
                elif name == 'boost': value = fade * (noise * .38 + .16 * math.sin(math.tau * (220 * t + 340 * t * t)))
                else: value = fade * (.38 * math.sin(math.tau * 880 * t) + .20 * math.sin(math.tau * 1320 * t))
            samples.append(max(-.92, min(.92, value)))
        path = OUT / (name + '.wav')
        data = struct.pack('<' + 'h' * len(samples), *(round(x * 32767) for x in samples))
        with wave.open(str(path), 'wb') as stream:
            stream.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
            stream.writeframes(data)
        files.append({'path': path.relative_to(ROOT).as_posix(), 'seconds': duration,
                      'peak': max(abs(x) for x in samples),
                      'rms': math.sqrt(sum(x*x for x in samples)/len(samples)),
                      'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    (OUT / 'MANIFEST.json').write_text(json.dumps({'source': 'Original mathematical synthesis; deterministic seed 48170',
        'sample_rate': RATE, 'channels': 1, 'files': files}, indent=2) + '\n', encoding='utf-8', newline='\n')
    print('DRIVING_AUDIO_BUILD PASS:', len(files), 'original mono WAVs')


if __name__ == '__main__':
    build()
